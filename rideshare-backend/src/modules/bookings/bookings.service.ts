import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { randomUUID } from 'crypto';
import { BookingEntity } from '../../database/entities/booking.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { CreateBookingDto } from './dto/create-booking.dto';
import { CancelBookingDto } from './dto/cancel-booking.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { TripsGateway } from '../trips/trips.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { UsersService } from '../users/users.service';
import { TripsService } from '../trips/trips.service';
import { areSeatsContiguousBlock } from './utils/seat-contiguity.util';

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(TripEntity) private tripRepo: Repository<TripEntity>,
    private dataSource: DataSource,
    @Inject(forwardRef(() => TripsGateway)) private tripsGateway: TripsGateway,
    @Inject(forwardRef(() => NotificationsService))
    private notificationsService: NotificationsService,
    @Inject(forwardRef(() => PaymentsService))
    private paymentsService: PaymentsService,
    private platformPricing: PlatformPricingService,
    private usersService: UsersService,
    @Inject(forwardRef(() => TripsService)) private tripsService: TripsService,
  ) {}

  private toAmount(value: string | null | undefined): number {
    const n = Number(value ?? 0);
    return Number.isFinite(n) ? n : 0;
  }

  private aggregateBookingGroup(bookings: BookingEntity[]) {
    const sorted = [...bookings].sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
    );
    const first = sorted[0];
    const platformAmountTotal = sorted.reduce(
      (sum, b) => sum + this.toAmount(b.platformAmount),
      0,
    );
    const driverAmountTotal = sorted.reduce(
      (sum, b) => sum + this.toAmount(b.driverAmount),
      0,
    );
    const totalAmount = platformAmountTotal + driverAmountTotal;
    const statusPriority = ['pending', 'confirmed', 'completed', 'cancelled'];
    const status =
      statusPriority.find((s) => sorted.some((b) => b.status === s)) ??
      first.status;

    return {
      bookingGroupId: first.bookingGroupId ?? first.id,
      bookingIds: sorted.map((b) => b.id),
      tripId: first.tripId,
      userId: first.userId,
      trip: first.trip,
      seatNumbers: sorted.map((b) => b.seatNumber),
      status,
      bookings: sorted,
      totals: {
        platformAmount: Number(platformAmountTotal.toFixed(2)),
        driverAmount: Number(driverAmountTotal.toFixed(2)),
        totalAmount: Number(totalAmount.toFixed(2)),
        currency: first.trip?.currency ?? 'JOD',
      },
      createdAt: sorted[sorted.length - 1].createdAt,
      updatedAt: first.updatedAt,
    };
  }

  async create(
    createBookingDto: CreateBookingDto,
    userId: string,
  ): Promise<BookingEntity | Record<string, unknown>> {
    const {
      tripId,
      seatNumber,
      seatNumbers,
      sharePhoneWithDriver = false,
      walletIdempotencyKey,
    } = createBookingDto;
    const normalizedSeatNumbers = Array.from(
      new Set(
        (seatNumbers && seatNumbers.length > 0 ? seatNumbers : [seatNumber])
          .filter((s): s is string => !!s)
          .map((s) => s.trim()),
      ),
    );
    if (!normalizedSeatNumbers.length) {
      throw new BadRequestException('At least one seat must be selected');
    }

    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }
    if (trip.driverId === userId) {
      throw new BadRequestException('Cannot book your own trip');
    }
    if (trip.status !== TripStatus.ACTIVE) {
      throw new BadRequestException('Trip is not available for booking');
    }

    const existingOnTrip = await this.bookingRepo
      .createQueryBuilder('b')
      .where('b.userId = :userId', { userId })
      .andWhere('b.tripId = :tripId', { tripId })
      .andWhere('b.status != :cancelled', { cancelled: 'cancelled' })
      .getCount();
    if (existingOnTrip > 0) {
      throw new BadRequestException(
        'You already have a booking for this trip. Only one booking per trip is allowed; select all seats in that single booking.',
      );
    }

    const seats = trip.seats || [];
    for (const s of normalizedSeatNumbers) {
      const seatIndex = seats.findIndex((seat: any) => seat.seatNumber === s);
      if (seatIndex === -1) {
        throw new BadRequestException(`Invalid seat number: ${s}`);
      }
      const seat = seats[seatIndex];
      if (seat.status !== 'available') {
        throw new BadRequestException(`Seat is not available: ${s}`);
      }
    }

    if (
      normalizedSeatNumbers.length > 1 &&
      !areSeatsContiguousBlock(
        normalizedSeatNumbers,
        trip.seatLayout ?? null,
      )
    ) {
      throw new BadRequestException(
        'Selected seats must be adjacent (one connected block). Book all seats you need in this single booking.',
      );
    }

    const user = await this.usersService.findById(userId);
    const userGender = user.gender ?? null;

    if (trip.seatLayout?.preventGenderMixing && userGender) {
      for (const s of normalizedSeatNumbers) {
        const rowPrefix = s.split('-')[0] + '-';
        // مقاعد الراكب نفسه في الصف لا تُطبَّق عليها قاعدة عدم الاختلاط
        const rowSeats = seats.filter(
          (seat: any) =>
            seat.seatNumber.startsWith(rowPrefix) &&
            seat.status === 'booked' &&
            String(seat.userId ?? '') !== String(userId),
        );
        const hasGenderMismatch = rowSeats.some(
          (seat: any) => seat.gender && seat.gender !== userGender,
        );
        if (hasGenderMismatch) {
          throw new BadRequestException(
            `Cannot book seat ${s} due to gender mixing prevention rules`,
          );
        }
      }
    }

    const countryCode = 'JO';
    const feeRow = await this.platformPricing.getActiveFeeRow(countryCode);
    const seatPricing = this.platformPricing.passengerSeatPricing(
      Number(trip.price ?? 0),
      trip.currency ?? 'JOD',
      feeRow,
    );

    const bookingGroupId = randomUUID();
    const qr = this.dataSource.createQueryRunner();
    await qr.connect();
    await qr.startTransaction();
    try {
      const tripInTx = await qr.manager.findOne(TripEntity, {
        where: { id: tripId },
      });
      if (!tripInTx) throw new NotFoundException('Trip not found');
      const newSeats = [...(tripInTx.seats || [])];

      for (const selectedSeat of normalizedSeatNumbers) {
        const idx = newSeats.findIndex(
          (seat: any) => seat.seatNumber === selectedSeat,
        );
        if (idx === -1 || newSeats[idx].status !== 'available') {
          throw new BadRequestException(
            `Seat is no longer available: ${selectedSeat}`,
          );
        }
      }

      for (const selectedSeat of normalizedSeatNumbers) {
        const idx = newSeats.findIndex(
          (seat: any) => seat.seatNumber === selectedSeat,
        );
        newSeats[idx] = {
          seatNumber: selectedSeat,
          userId,
          userName: user.name,
          gender: userGender,
          bookedAt: new Date(),
          status: 'booked',
        };
      }
      tripInTx.seats = newSeats;
      tripInTx.availableSeats = Math.max(
        0,
        (tripInTx.availableSeats ?? 0) - normalizedSeatNumbers.length,
      );
      await qr.manager.save(TripEntity, tripInTx);

      const savedBookings: BookingEntity[] = [];
      for (const selectedSeat of normalizedSeatNumbers) {
        const booking = qr.manager.create(BookingEntity, {
          tripId,
          userId,
          seatNumber: selectedSeat,
          bookingGroupId,
          status: 'pending',
          hasDriverPaidToContact: false,
          sharePhoneWithDriver,
          seatPriceAtBooking: String(seatPricing.seatPrice),
          platformAmount: String(seatPricing.platformAmount),
          driverAmount: String(seatPricing.driverAmount),
          passengerPaymentId: null,
        });
        const saved = await qr.manager.save(BookingEntity, booking);

        if (seatPricing.requiresOnlinePayment) {
          const idem = walletIdempotencyKey
            ? `${walletIdempotencyKey}-${saved.id}`
            : `passenger-hold:${saved.id}`;
          const { payment } =
            await this.paymentsService.holdPassengerWalletPaymentInTransaction(
              qr.manager,
              {
                userId,
                tripId,
                bookingId: saved.id,
                platformAmount: seatPricing.platformAmount,
                currency: seatPricing.currency,
                idempotencyKey: idem,
              },
            );
          saved.passengerPaymentId = payment.id;
          await qr.manager.save(BookingEntity, saved);
        }

        savedBookings.push(saved);
      }

      await qr.commitTransaction();

      for (const selectedSeat of normalizedSeatNumbers) {
        await this.tripsGateway.emitSeatBooked(tripId, selectedSeat, 'booked');
      }

      await this.notificationsService.create({
        userId: trip.driverId,
        type: 'booking_new',
        title: 'New Booking',
        body: `${user.name} booked ${normalizedSeatNumbers.length} seat(s) on your trip to ${trip.toName}`,
        data: { tripId, bookingGroupId, seatNumbers: normalizedSeatNumbers },
      });

      this.logger.log(
        `Booking group created: ${bookingGroupId} for trip ${tripId}, seats ${normalizedSeatNumbers.join(', ')}`,
      );

      if (savedBookings.length === 1) {
        return savedBookings[0];
      }

      const totalPlatformAmount = Number(
        (seatPricing.platformAmount * savedBookings.length).toFixed(2),
      );
      const totalDriverAmount = Number(
        (seatPricing.driverAmount * savedBookings.length).toFixed(2),
      );
      return {
        bookingGroupId,
        tripId,
        userId,
        seatNumbers: normalizedSeatNumbers,
        bookings: savedBookings,
        totals: {
          platformAmount: totalPlatformAmount,
          driverAmount: totalDriverAmount,
          totalAmount: Number((totalPlatformAmount + totalDriverAmount).toFixed(2)),
          currency: trip.currency ?? 'JOD',
        },
      };
    } catch (err) {
      await qr.rollbackTransaction();
      this.logger.error(`Booking failed: ${(err as Error).message}`);
      throw err;
    } finally {
      await qr.release();
    }
  }

  async confirm(bookingId: string, driverId: string): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip'],
    });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    const trip =
      booking.trip || (await this.tripsService.findById(booking.tripId));
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('Only the trip driver can confirm bookings');
    }
    if (booking.status !== 'pending') {
      throw new BadRequestException('Only pending bookings can be confirmed');
    }

    await this.paymentsService.chargeDriverWalletForTrip(driverId, trip.id);

    if (booking.passengerPaymentId) {
      await this.paymentsService.capturePassengerHoldForPaymentId(
        booking.passengerPaymentId,
      );
    }

    await this.bookingRepo
      .createQueryBuilder()
      .update(BookingEntity)
      .set({ hasDriverPaidToContact: true })
      .where('tripId = :tripId', { tripId: trip.id })
      .andWhere('status IN (:...statuses)', {
        statuses: ['pending', 'confirmed'],
      })
      .execute();

    booking.status = 'confirmed';
    booking.hasDriverPaidToContact = true;
    const saved = await this.bookingRepo.save(booking);

    await this.notificationsService.create({
      userId: booking.userId,
      type: 'booking_confirmed',
      title: 'Booking Confirmed',
      body: `Your booking for seat ${booking.seatNumber} has been confirmed`,
      data: { tripId: trip.id, bookingId },
    });

    return saved;
  }

  async cancel(
    bookingId: string,
    userId: string,
    cancelBookingDto: CancelBookingDto,
    isDriver: boolean = false,
  ): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip'],
    });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    const trip =
      booking.trip || (await this.tripsService.findById(booking.tripId));

    const isBookingOwner = booking.userId === userId;
    const isTripDriver = trip.driverId === userId;
    if (!isBookingOwner && !isTripDriver) {
      throw new ForbiddenException(
        'You are not authorized to cancel this booking',
      );
    }
    if (booking.status === 'cancelled') {
      throw new BadRequestException('Booking is already cancelled');
    }
    if (booking.status === 'completed') {
      throw new BadRequestException('Cannot cancel a completed booking');
    }

    if (booking.passengerPaymentId && booking.status === 'pending') {
      await this.paymentsService.releasePassengerHoldForPaymentId(
        booking.passengerPaymentId,
      );
    }

    booking.status = 'cancelled';
    booking.cancellationReason = cancelBookingDto.reason ?? null;
    booking.cancelledAt = new Date();
    booking.cancelledBy =
      isTripDriver && !isBookingOwner ? 'driver' : 'passenger';
    await this.bookingRepo.save(booking);

    await this.tripsService.releaseSeat(booking.tripId, booking.seatNumber);

    await this.tripsGateway.emitSeatReleased(
      booking.tripId,
      booking.seatNumber,
    );

    const userToNotify = isBookingOwner ? trip.driverId : booking.userId;
    await this.notificationsService.create({
      userId: userToNotify,
      type: 'booking_cancelled',
      title: 'Booking Cancelled',
      body: `Booking for seat ${booking.seatNumber} has been cancelled`,
      data: { tripId: booking.tripId, bookingId },
    });

    this.logger.log(`Booking cancelled: ${bookingId} by ${userId}`);
    return booking;
  }

  /** Admin-only: cancel any booking without ownership check */
  async cancelAsAdmin(bookingId: string): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip'],
    });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    if (booking.status === 'cancelled') {
      throw new BadRequestException('Booking is already cancelled');
    }
    if (booking.status === 'completed') {
      throw new BadRequestException('Cannot cancel a completed booking');
    }

    if (booking.passengerPaymentId && booking.status === 'pending') {
      await this.paymentsService.releasePassengerHoldForPaymentId(
        booking.passengerPaymentId,
      );
    }

    booking.status = 'cancelled';
    booking.cancellationReason = 'Cancelled by admin';
    booking.cancelledAt = new Date();
    booking.cancelledBy = 'admin';
    await this.bookingRepo.save(booking);

    await this.tripsService.releaseSeat(booking.tripId, booking.seatNumber);

    await this.tripsGateway.emitSeatReleased(
      booking.tripId,
      booking.seatNumber,
    );

    const trip = booking.trip || (await this.tripRepo.findOne({ where: { id: booking.tripId } }));
    if (trip) {
      await this.notificationsService.create({
        userId: booking.userId,
        type: 'booking_cancelled',
        title: 'Booking Cancelled',
        body: `Your booking for seat ${booking.seatNumber} has been cancelled by admin`,
        data: { tripId: booking.tripId, bookingId },
      });
    }

    this.logger.log(`Booking cancelled by admin: ${bookingId}`);
    return booking;
  }

  /**
   * Pending bookings on trips whose departure time has passed: refund wallet hold and cancel.
   */
  async releasePassengerHoldsForDepartedTrips(): Promise<number> {
    const now = new Date();
    const stale = await this.bookingRepo
      .createQueryBuilder('b')
      .innerJoinAndSelect('b.trip', 't')
      .where('b.status = :st', { st: 'pending' })
      .andWhere('t.departureTime < :now', { now })
      .getMany();

    let n = 0;
    for (const booking of stale) {
      try {
        await this.cancelPendingBookingAfterDeparture(booking.id);
        n++;
      } catch (e) {
        this.logger.warn(
          `releasePassengerHoldsForDepartedTrips: ${booking.id} ${(e as Error).message}`,
        );
      }
    }
    if (n > 0) {
      this.logger.log(
        `releasePassengerHoldsForDepartedTrips: refunded/cancelled ${n} booking(s)`,
      );
    }
    return n;
  }

  private async cancelPendingBookingAfterDeparture(
    bookingId: string,
  ): Promise<void> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip'],
    });
    if (!booking || booking.status !== 'pending') {
      return;
    }

    if (booking.passengerPaymentId) {
      await this.paymentsService.releasePassengerHoldForPaymentId(
        booking.passengerPaymentId,
      );
    }

    booking.status = 'cancelled';
    booking.cancellationReason =
      'انتهى وقت المغادرة دون تأكيد السائق؛ تم إرجاع المبلغ المحجوز للمحفظة';
    booking.cancelledAt = new Date();
    booking.cancelledBy = 'system';
    await this.bookingRepo.save(booking);

    await this.tripsService.releaseSeat(booking.tripId, booking.seatNumber);
    await this.tripsGateway.emitSeatReleased(
      booking.tripId,
      booking.seatNumber,
    );

    const trip = booking.trip;
    if (trip) {
      await this.notificationsService.create({
        userId: booking.userId,
        type: 'booking_cancelled',
        title: 'تم إلغاء الحجز',
        body: `تم إلغاء حجز المقعد ${booking.seatNumber} لأن الرحلة غادرت دون تأكيد السائق. أي مبلغ محجوز أُعيد لمحفظتك.`,
        data: { tripId: booking.tripId, bookingId },
      });
    }
  }

  async findByUser(
    userId: string,
    options: { page: number; limit: number; status?: string },
  ): Promise<PaginatedResult<BookingEntity>> {
    const { page = 1, limit = 20, status } = options;
    const skip = (page - 1) * limit;

    const qb = this.bookingRepo
      .createQueryBuilder('b')
      .leftJoinAndSelect('b.trip', 'trip')
      .where('b.userId = :userId', { userId })
      .orderBy('b.createdAt', 'DESC');

    if (status) {
      qb.andWhere('b.status = :status', { status });
    }

    const countQb = qb.clone();
    const [data, total] = await Promise.all([
      qb.skip(skip).take(limit).getMany(),
      countQb.getCount(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findGroupedByUser(
    userId: string,
    options: { page: number; limit: number; status?: string },
  ): Promise<PaginatedResult<any>> {
    const { page = 1, limit = 20, status } = options;
    const qb = this.bookingRepo
      .createQueryBuilder('b')
      .leftJoinAndSelect('b.trip', 'trip')
      .where('b.userId = :userId', { userId })
      .orderBy('b.createdAt', 'DESC');
    if (status) {
      qb.andWhere('b.status = :status', { status });
    }

    const rows = await qb.getMany();
    const grouped = new Map<string, BookingEntity[]>();
    for (const row of rows) {
      const key = row.bookingGroupId ?? row.id;
      const list = grouped.get(key) ?? [];
      list.push(row);
      grouped.set(key, list);
    }

    const allGroups = Array.from(grouped.values()).map((groupRows) =>
      this.aggregateBookingGroup(groupRows),
    );
    allGroups.sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );

    const total = allGroups.length;
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const start = (page - 1) * limit;
    const data = allGroups.slice(start, start + limit);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages,
      },
    };
  }

  async findGroupById(groupId: string, userId: string): Promise<any> {
    const rows = await this.bookingRepo
      .createQueryBuilder('b')
      .leftJoinAndSelect('b.trip', 'trip')
      .leftJoinAndSelect('b.user', 'user')
      .where('b.bookingGroupId = :groupId', { groupId })
      .orWhere('b.id = :groupId', { groupId })
      .orderBy('b.createdAt', 'DESC')
      .getMany();

    if (!rows.length) {
      throw new NotFoundException('Booking group not found');
    }

    const trip = rows[0].trip;
    const isBookingOwner = rows[0].userId === userId;
    const isTripDriver = trip?.driverId === userId;
    if (!isBookingOwner && !isTripDriver) {
      throw new ForbiddenException(
        'You are not authorized to view this booking group',
      );
    }

    return this.aggregateBookingGroup(rows);
  }

  async findByTrip(
    tripId: string,
    driverId: string,
    options: { page: number; limit: number },
  ): Promise<PaginatedResult<BookingEntity>> {
    const { page = 1, limit = 20 } = options;
    const skip = (page - 1) * limit;

    const trip = await this.tripsService.findById(tripId);
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this trip');
    }

    const [data, total] = await Promise.all([
      this.bookingRepo.find({
        where: { tripId },
        relations: ['user'],
        order: { createdAt: 'DESC' },
        skip,
        take: limit,
      }),
      this.bookingRepo.count({ where: { tripId } }),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findById(bookingId: string, userId: string): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip', 'user'],
    });
    if (!booking) {
      throw new NotFoundException('Booking not found');
    }
    const trip =
      booking.trip || (await this.tripsService.findById(booking.tripId));

    const isBookingOwner = booking.userId === userId;
    const isTripDriver = trip.driverId === userId;
    if (!isBookingOwner && !isTripDriver) {
      throw new ForbiddenException(
        'You are not authorized to view this booking',
      );
    }
    return booking;
  }

  async findByIdInternal(bookingId: string): Promise<BookingEntity | null> {
    return this.bookingRepo.findOne({ where: { id: bookingId } });
  }

  async markAsCompleted(tripId: string): Promise<void> {
    await this.bookingRepo.update(
      { tripId, status: 'confirmed' },
      { status: 'completed' },
    );
    this.logger.log(`Bookings for trip ${tripId} marked as completed`);
  }

  async cancelAllForTrip(tripId: string, reason: string): Promise<void> {
    const bookings = await this.bookingRepo
      .createQueryBuilder('b')
      .where('b.tripId = :tripId', { tripId })
      .andWhere('b.status != :status', { status: 'cancelled' })
      .getMany();
    for (const booking of bookings) {
      booking.status = 'cancelled';
      booking.cancellationReason = reason;
      booking.cancelledAt = new Date();
      booking.cancelledBy = 'system';
      await this.bookingRepo.save(booking);
    }
    this.logger.log(`All bookings for trip ${tripId} cancelled`);
  }

  async findByTripInternal(tripId: string): Promise<BookingEntity[]> {
    return this.bookingRepo
      .createQueryBuilder('b')
      .where('b.tripId = :tripId', { tripId })
      .andWhere('b.status != :status', { status: 'cancelled' })
      .getMany();
  }
}
