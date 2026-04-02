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

  async create(
    createBookingDto: CreateBookingDto,
    userId: string,
  ): Promise<BookingEntity> {
    const {
      tripId,
      seatNumber,
      sharePhoneWithDriver = false,
      walletIdempotencyKey,
    } = createBookingDto;

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

    const existingBooking = await this.bookingRepo
      .createQueryBuilder('b')
      .where('b.userId = :userId', { userId })
      .andWhere('b.tripId = :tripId', { tripId })
      .andWhere('b.status != :status', { status: 'cancelled' })
      .getOne();
    if (existingBooking) {
      throw new BadRequestException('You already have a booking for this trip');
    }

    const seats = trip.seats || [];
    const seatIndex = seats.findIndex((s: any) => s.seatNumber === seatNumber);
    if (seatIndex === -1) {
      throw new BadRequestException('Invalid seat number');
    }
    const seat = seats[seatIndex];
    if (seat.status !== 'available') {
      throw new BadRequestException('Seat is not available');
    }

    const user = await this.usersService.findById(userId);
    const userGender = user.gender ?? null;

    if (trip.seatLayout?.preventGenderMixing && userGender) {
      const rowPrefix = seatNumber.split('-')[0] + '-';
      const rowSeats = seats.filter(
        (s: any) => s.seatNumber.startsWith(rowPrefix) && s.status === 'booked',
      );
      const hasGenderMismatch = rowSeats.some(
        (s: any) => s.gender && s.gender !== userGender,
      );
      if (hasGenderMismatch) {
        throw new BadRequestException(
          'Cannot book this seat due to gender mixing prevention rules',
        );
      }
    }

    const countryCode = 'JO';
    const feeRow = await this.platformPricing.getActiveFeeRow(countryCode);
    const seatPricing = this.platformPricing.passengerSeatPricing(
      Number(trip.price ?? 0),
      trip.currency ?? 'JOD',
      feeRow,
    );

    let passengerPaymentId: string | null = null;
    if (seatPricing.requiresOnlinePayment) {
      const resolved =
        await this.paymentsService.resolvePassengerWalletPaymentForBooking({
          userId,
          tripId,
          seatNumber,
          idempotencyKey: walletIdempotencyKey,
          countryCode,
        });
      passengerPaymentId = resolved.payment.id;
    }

    const qr = this.dataSource.createQueryRunner();
    await qr.connect();
    await qr.startTransaction();
    try {
      const tripInTx = await qr.manager.findOne(TripEntity, {
        where: { id: tripId },
      });
      if (!tripInTx) throw new NotFoundException('Trip not found');
      const newSeats = [...(tripInTx.seats || [])];
      const idx = newSeats.findIndex((s: any) => s.seatNumber === seatNumber);
      if (idx === -1 || newSeats[idx].status !== 'available') {
        throw new BadRequestException('Seat is no longer available');
      }
      newSeats[idx] = {
        seatNumber,
        userId,
        userName: user.name,
        gender: userGender,
        bookedAt: new Date(),
        status: 'booked',
      };
      tripInTx.seats = newSeats;
      tripInTx.availableSeats = Math.max(0, (tripInTx.availableSeats ?? 0) - 1);
      await qr.manager.save(TripEntity, tripInTx);

      const booking = qr.manager.create(BookingEntity, {
        tripId,
        userId,
        seatNumber,
        status: 'pending',
        hasDriverPaidToContact: false,
        sharePhoneWithDriver,
        seatPriceAtBooking: String(seatPricing.seatPrice),
        platformAmount: String(seatPricing.platformAmount),
        driverAmount: String(seatPricing.driverAmount),
        passengerPaymentId,
      });
      const savedBooking = await qr.manager.save(BookingEntity, booking);

      if (passengerPaymentId) {
        await qr.manager.update(
          PaymentEntity,
          { id: passengerPaymentId },
          { bookingId: savedBooking.id },
        );
      }

      await qr.commitTransaction();

      await this.tripsGateway.emitSeatBooked(tripId, seatNumber, 'booked');

      await this.notificationsService.create({
        userId: trip.driverId,
        type: 'booking_new',
        title: 'New Booking',
        body: `${user.name} booked seat ${seatNumber} on your trip to ${trip.toName}`,
        data: { tripId, bookingId: savedBooking.id },
      });

      this.logger.log(
        `Booking created: ${savedBooking.id} for trip ${tripId}, seat ${seatNumber}`,
      );

      return savedBooking;
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
