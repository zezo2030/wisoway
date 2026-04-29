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
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../database/entities/booking-seat.entity';
import {
  PendingChargeEntity,
  PendingChargeKind,
  PendingChargeStatus,
} from '../../database/entities/pending-charge.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { CreateBookingDto } from './dto/create-booking.dto';
import { CancelBookingDto } from './dto/cancel-booking.dto';
import {
  CreateMultiSeatBookingDto,
  AutoPickBookingDto,
} from './dto/create-multi-seat-booking.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { TripsGateway } from '../trips/trips.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { UsersService } from '../users/users.service';
import { TripsService } from '../trips/trips.service';
import {
  hasGenderAdjacencyViolation,
  findValidStartPositions,
} from '../seats/gender-adjacency';
import { checkCancellationPolicy } from './helpers/cancellation-policy';

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);

  private getRowSeatCounts(seatLayout: any, seats: any[]): number[] {
    if (
      Array.isArray(seatLayout?.seatsPerRowList) &&
      seatLayout.seatsPerRowList.length
    ) {
      return seatLayout.seatsPerRowList.map(
        (count: unknown) => Number(count) || 0,
      );
    }

    if (
      typeof seatLayout?.rows === 'number' &&
      typeof seatLayout?.seatsPerRow === 'number'
    ) {
      return Array.from(
        { length: seatLayout.rows },
        () => Number(seatLayout.seatsPerRow) || 0,
      );
    }

    const counts = new Map<number, number>();
    for (const seat of seats) {
      const [rowRaw, colRaw] = String(seat?.seatNumber ?? '').split('-');
      const row = Number(rowRaw);
      const col = Number(colRaw);
      if (Number.isNaN(row) || Number.isNaN(col)) continue;
      counts.set(row, Math.max(counts.get(row) ?? 0, col + 1));
    }

    return Array.from(counts.entries())
      .sort(([a], [b]) => a - b)
      .map(([, count]) => count);
  }

  private findSeat(seats: any[], row: number, col: number) {
    return seats.find((seat: any) => seat?.seatNumber === `${row}-${col}`);
  }

  private hasAdjacentGenderConflict(
    seats: any[],
    seatLayout: any,
    seatNumber: string,
    userGender: string,
  ): boolean {
    const [rowRaw, colRaw] = seatNumber.split('-');
    const row = Number(rowRaw);
    const col = Number(colRaw);
    if (Number.isNaN(row) || Number.isNaN(col)) {
      return false;
    }

    const rowSeatCounts = this.getRowSeatCounts(seatLayout, seats);
    const adjacentCoords: Array<[number, number]> = [];

    if (col > 0) {
      adjacentCoords.push([row, col - 1]);
    }

    if (col < (rowSeatCounts[row] ?? 0) - 1) {
      adjacentCoords.push([row, col + 1]);
    }

    if (row > 0 && col < (rowSeatCounts[row - 1] ?? 0)) {
      adjacentCoords.push([row - 1, col]);
    }

    if (row < rowSeatCounts.length - 1 && col < (rowSeatCounts[row + 1] ?? 0)) {
      adjacentCoords.push([row + 1, col]);
    }

    return adjacentCoords.some(([adjacentRow, adjacentCol]) => {
      const adjacentSeat = this.findSeat(seats, adjacentRow, adjacentCol);
      return (
        adjacentSeat?.status === 'booked' &&
        adjacentSeat.gender &&
        adjacentSeat.gender !== userGender
      );
    });
  }

  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(TripEntity) private tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingSeatEntity)
    private bookingSeatRepo: Repository<BookingSeatEntity>,
    @InjectRepository(PendingChargeEntity)
    private pendingChargeRepo: Repository<PendingChargeEntity>,
    private dataSource: DataSource,
    @Inject(forwardRef(() => TripsGateway)) private tripsGateway: TripsGateway,
    @Inject(forwardRef(() => NotificationsService))
    private notificationsService: NotificationsService,
    @Inject(forwardRef(() => PaymentsService))
    private paymentsService: PaymentsService,
    private platformPricing: PlatformPricingService,
    private usersService: UsersService,
    @Inject(forwardRef(() => TripsService)) private tripsService: TripsService,
    @InjectQueue('bookings-timeout') private bookingsTimeoutQueue: Queue,
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
    if (trip.status !== TripStatus.PUBLISHED) {
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

    if (
      trip.seatLayout?.preventGenderMixing &&
      userGender &&
      this.hasAdjacentGenderConflict(
        seats,
        trip.seatLayout,
        seatNumber,
        userGender,
      )
    ) {
      throw new BadRequestException(
        'لا يمكن حجز هذا المقعد لأنه بجوار راكب من جنس مختلف.',
      );
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
        status: 'pending',
        hasDriverPaidToContact: !!tripInTx.driverWalletChargeApplied,
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

      // T034: Send push notification to driver via new multi-device flow
      this.notificationsService
        .notifyDriverOfNewBooking(savedBooking.id)
        .catch((err) =>
          this.logger.warn(
            `Failed to notify driver of new booking: ${err.message}`,
          ),
        );

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

    booking.status = 'confirmed';
    booking.hasDriverPaidToContact = !!trip.driverWalletChargeApplied;
    const saved = await this.bookingRepo.save(booking);

    // T034: Send push notification to passenger via new multi-device flow
    this.notificationsService
      .notifyPassengerOfBookingDecision(bookingId, 'confirmed')
      .catch((err) =>
        this.logger.warn(
          `Failed to notify passenger of booking confirm: ${err.message}`,
        ),
      );

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
      relations: ['trip', 'seats'],
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

    const role = isTripDriver && !isBookingOwner ? 'driver' : 'passenger';
    const departureTime = trip.departureTime
      ? new Date(trip.departureTime)
      : null;

    if (departureTime) {
      const policy = checkCancellationPolicy(
        role,
        departureTime,
        booking.status,
      );
      if (!policy.allowed) {
        // Passenger cancelling a confirmed booking inside the 12-hour window:
        // record a 5% pending charge then proceed with cancellation.
        if (policy.chargeRate !== null) {
          const totalAmount = Number(
            booking.totalAmount ?? booking.seatPriceAtBooking ?? 0,
          );
          const chargeAmount = (totalAmount * policy.chargeRate).toFixed(2);
          const charge = this.pendingChargeRepo.create({
            userId: booking.userId,
            kind: PendingChargeKind.PASSENGER_CANCELLATION,
            amount: chargeAmount,
            status: PendingChargeStatus.PENDING,
            bookingId: booking.id,
            tripId: booking.tripId,
          });
          await this.pendingChargeRepo.save(charge);
          this.logger.log(
            `Pending charge ${chargeAmount} recorded for passenger cancellation inside window (booking ${booking.id})`,
          );
        } else {
          // Driver attempting to cancel inside the 24-hour window — block.
          throw new BadRequestException({
            code: 'CANCELLATION_WINDOW_CLOSED',
            windowSeconds: policy.windowSeconds,
            message: `Cancellation is not allowed within ${policy.windowSeconds / 3600} hours of departure`,
          });
        }
      }
    }

    booking.status = 'cancelled';
    booking.cancellationReason = cancelBookingDto.reason ?? null;
    booking.cancelledAt = new Date();
    booking.cancelledBy =
      isTripDriver && !isBookingOwner ? 'driver' : 'passenger';
    await this.bookingRepo.save(booking);

    const cancelSeats = (booking.seats ?? []).map((s) => s.seatNumber);
    for (const sn of cancelSeats) {
      await this.tripsService.releaseSeat(booking.tripId, sn).catch(() => undefined);
      await this.tripsGateway.emitSeatReleased(booking.tripId, sn).catch(() => undefined);
    }

    // T034: Send push notification based on who cancelled
    if (isBookingOwner) {
      // Passenger cancelled → notify driver
      this.notificationsService
        .notifyDriverOfBookingCancellation(bookingId)
        .catch((err) =>
          this.logger.warn(
            `Failed to notify driver of booking cancellation: ${err.message}`,
          ),
        );
    } else {
      // Driver cancelled → notify passenger
      this.notificationsService
        .notifyPassengerOfBookingDecision(bookingId, 'canceled')
        .catch((err) =>
          this.logger.warn(
            `Failed to notify passenger of booking cancellation: ${err.message}`,
          ),
        );
    }

    this.logger.log(`Booking cancelled: ${bookingId} by ${userId}`);
    return booking;
  }

  /** Admin-only: cancel any booking without ownership check */
  async cancelAsAdmin(bookingId: string): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip', 'seats'],
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

    const cancelSeats = (booking.seats ?? []).map((s) => s.seatNumber);
    for (const sn of cancelSeats) {
      await this.tripsService.releaseSeat(booking.tripId, sn).catch(() => undefined);
      await this.tripsGateway.emitSeatReleased(booking.tripId, sn).catch(() => undefined);
    }

    const trip =
      booking.trip ||
      (await this.tripRepo.findOne({ where: { id: booking.tripId } }));
    if (trip) {
      this.notificationsService
        .notifyPassengerOfBookingDecision(bookingId, 'canceled')
        .catch((err) =>
          this.logger.warn(
            `Failed to notify passenger of admin cancellation: ${err.message}`,
          ),
        );
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
      relations: ['trip', 'seats'],
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

  // ── T065: createMultiSeat ─────────────────────────────────────────────────

  /**
   * Book one or more seats in a single atomic transaction.
   *
   * Steps:
   *  1. Validate trip + user guards (not own trip, trip active, no duplicate)
   *  2. Validate every seat is available + check gender-adjacency rules
   *  3. SELECT FOR UPDATE on the trip inside a transaction
   *  4. Persist BookingEntity + BookingSeatEntity rows
   *  5. Decrement trip.availableSeats and update trip.seats JSON
   *  6. Enqueue a `bookings-timeout` job
   *  7. Notify driver
   */
  async createMultiSeat(
    dto: CreateMultiSeatBookingDto,
    userId: string,
  ): Promise<BookingEntity> {
    const { tripId, seats: seatDtos, sharePhoneWithDriver = false } = dto;

    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.driverId === userId)
      throw new BadRequestException('Cannot book your own trip');
    if (trip.status !== TripStatus.PUBLISHED)
      throw new BadRequestException('Trip is not available for booking');

    // Duplicate booking check — any active booking by this user for this trip
    // Exactly one seat must be the main booker
    const mainSeats = seatDtos.filter((s) => s.isMainBooker);
    if (mainSeats.length !== 1)
      throw new BadRequestException(
        'Exactly one seat must be marked as isMainBooker',
      );

    // Check requested seats are currently available
    const tripSeats: any[] = trip.seats || [];
    for (const sd of seatDtos) {
      const slot = tripSeats.find((s: any) => s.seatNumber === sd.seatNumber);
      if (!slot)
        throw new BadRequestException(`Seat ${sd.seatNumber} does not exist`);
      if (slot.status !== 'available')
        throw new BadRequestException(`Seat ${sd.seatNumber} is not available`);
    }

    // Gender-adjacency check (if enabled on the trip)
    if (trip.seatLayout?.preventGenderMixing) {
      const proposed = seatDtos.map((sd) => ({
        seatNumber: sd.seatNumber,
        gender: sd.gender,
      }));
      if (hasGenderAdjacencyViolation(tripSeats, proposed)) {
        throw new BadRequestException(
          'لا يمكن حجز هذه المقاعد بسبب قواعد الفصل بين الجنسين.',
        );
      }
    }

    // Pricing
    const countryCode = 'JO';
    const feeRow = await this.platformPricing.getActiveFeeRow(countryCode);
    const seatPricing = this.platformPricing.passengerSeatPricing(
      Number(trip.price ?? 0),
      trip.currency ?? 'JOD',
      feeRow,
    );
    const seatCount = seatDtos.length;
    const totalAmount = (Number(seatPricing.seatPrice) * seatCount).toFixed(2);

    // --- Transaction ---
    const qr = this.dataSource.createQueryRunner();
    await qr.connect();
    await qr.startTransaction();
    let savedBooking: BookingEntity;
    try {
      // Lock the trip row
      const tripInTx = await qr.manager.findOne(TripEntity, {
        where: { id: tripId },
        lock: { mode: 'pessimistic_write' },
      } as any);
      if (!tripInTx) throw new NotFoundException('Trip not found');

      const newSeats = [...(tripInTx.seats || [])];

      // Re-validate availability inside the transaction
      for (const sd of seatDtos) {
        const idx = newSeats.findIndex(
          (s: any) => s.seatNumber === sd.seatNumber,
        );
        if (idx === -1 || newSeats[idx].status !== 'available') {
          throw new BadRequestException(
            `Seat ${sd.seatNumber} is no longer available`,
          );
        }
        newSeats[idx] = {
          ...newSeats[idx],
          status: 'booked',
          userId,
          gender: sd.gender,
          bookedAt: new Date(),
        };
      }

      tripInTx.seats = newSeats;
      tripInTx.availableSeats = Math.max(
        0,
        (tripInTx.availableSeats ?? 0) - seatCount,
      );
      await qr.manager.save(TripEntity, tripInTx);

      // Timeout: 3 h default, overridable for testing
      const timeoutSeconds = process.env.BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS
        ? Number(process.env.BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS)
        : 3 * 3600;
      const expiresAt = new Date(Date.now() + timeoutSeconds * 1000);

      const booking = qr.manager.create(BookingEntity, {
        tripId,
        userId,
        seatNumber: seatDtos.find((s) => s.isMainBooker)!.seatNumber, // legacy compat
        status: BookingStatus.PENDING,
        hasDriverPaidToContact: !!tripInTx.driverWalletChargeApplied,
        sharePhoneWithDriver,
        seatCount,
        totalAmount,
        seatPriceAtBooking: String(seatPricing.seatPrice),
        platformAmount: String(seatPricing.platformAmount),
        driverAmount: String(seatPricing.driverAmount),
        expiresAt,
      });
      savedBooking = await qr.manager.save(BookingEntity, booking);

      // Persist individual BookingSeat rows
      const seatEntities = seatDtos.map((sd) =>
        qr.manager.create(BookingSeatEntity, {
          bookingId: savedBooking.id,
          seatNumber: sd.seatNumber,
          displayName: sd.displayName,
          gender: sd.gender,
          isMainBooker: sd.isMainBooker,
        }),
      );
      await qr.manager.save(BookingSeatEntity, seatEntities);

      await qr.commitTransaction();
    } catch (err) {
      await qr.rollbackTransaction();
      this.logger.error(`createMultiSeat failed: ${(err as Error).message}`);
      throw err;
    } finally {
      await qr.release();
    }

    // Enqueue timeout job
    await this.bookingsTimeoutQueue
      .add(
        'expire-booking',
        { bookingId: savedBooking.id },
        {
          delay:
            (process.env.BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS
              ? Number(process.env.BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS)
              : 3 * 3600) * 1000,
          attempts: 3,
          backoff: { type: 'exponential', delay: 5000 },
          jobId: `booking-expire-${savedBooking.id}`,
          removeOnComplete: true,
        },
      )
      .catch((err) =>
        this.logger.warn(
          `Failed to enqueue timeout job: ${(err as Error).message}`,
        ),
      );

    // Notify driver
    this.notificationsService
      .notifyDriverOfNewBooking(savedBooking.id)
      .catch((err) =>
        this.logger.warn(`Failed to notify driver: ${(err as Error).message}`),
      );

    this.logger.log(
      `Multi-seat booking created: ${savedBooking.id} for trip ${tripId} (${seatCount} seats)`,
    );
    return savedBooking;
  }

  // ── T066: autoPick ────────────────────────────────────────────────────────

  /**
   * Auto-select the best available contiguous seats for a group, respecting
   * gender-adjacency rules, then delegate to `createMultiSeat`.
   */
  async autoPick(
    dto: AutoPickBookingDto,
    userId: string,
  ): Promise<BookingEntity> {
    const { tripId, seatCount, passengers, sharePhoneWithDriver } = dto;

    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.status !== TripStatus.PUBLISHED)
      throw new BadRequestException('Trip is not available for booking');
    if ((trip.availableSeats ?? 0) < seatCount)
      throw new BadRequestException('Not enough available seats');

    const seatLayout = trip.seatLayout ?? {
      rows: 1,
      seatsPerRow: trip.totalSeats ?? seatCount,
    };
    const tripSeats: any[] = trip.seats || [];

    const proposedGenders = passengers.map((p) => p.gender);
    const validPositions = findValidStartPositions(
      tripSeats,
      proposedGenders,
      seatLayout,
    );

    if (validPositions.length === 0) {
      throw new BadRequestException(
        'لا توجد مقاعد متاحة تلبي قواعد الفصل بين الجنسين.',
      );
    }

    // Pick the first valid position
    const { row, startCol } = validPositions[0];
    const seats = passengers.map((p, offset) => ({
      seatNumber: `${row}-${startCol + offset}`,
      displayName: p.displayName,
      gender: p.gender,
      isMainBooker: p.isMainBooker,
    }));

    return this.createMultiSeat(
      { tripId, seats, sharePhoneWithDriver },
      userId,
    );
  }

  // ── T070: accept ──────────────────────────────────────────────────────────

  /**
   * Driver accepts (confirms) a pending booking.
   * Charges the driver's wallet for the contact fee, marks the booking
   * confirmed, and cancels the pending timeout job.
   */
  async accept(bookingId: string, driverId: string): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip', 'seats'],
    });
    if (!booking) throw new NotFoundException('Booking not found');

    const trip =
      booking.trip || (await this.tripsService.findById(booking.tripId));
    if (trip.driverId !== driverId)
      throw new ForbiddenException('Only the trip driver can accept bookings');
    if (booking.status !== BookingStatus.PENDING)
      throw new BadRequestException('Only pending bookings can be accepted');

    booking.status = BookingStatus.CONFIRMED;
    booking.hasDriverPaidToContact = !!trip.driverWalletChargeApplied;
    const saved = await this.bookingRepo.save(booking);

    // Cancel the timeout job
    try {
      const job = await this.bookingsTimeoutQueue.getJob(
        `booking-expire-${bookingId}`,
      );
      if (job) await job.remove();
    } catch (err) {
      this.logger.warn(
        `Could not remove timeout job for booking ${bookingId}: ${(err as Error).message}`,
      );
    }

    this.notificationsService
      .notifyPassengerOfBookingDecision(bookingId, 'confirmed')
      .catch((err) =>
        this.logger.warn(
          `Failed to notify passenger of accept: ${(err as Error).message}`,
        ),
      );

    this.logger.log(`Booking accepted: ${bookingId} by driver ${driverId}`);
    return saved;
  }

  // ── T071: reject ──────────────────────────────────────────────────────────

  /**
   * Driver rejects a pending booking.
   * Releases the seat(s) and cancels the timeout job.
   */
  async reject(
    bookingId: string,
    driverId: string,
    reason?: string,
  ): Promise<BookingEntity> {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip', 'seats'],
    });
    if (!booking) throw new NotFoundException('Booking not found');

    const trip =
      booking.trip || (await this.tripsService.findById(booking.tripId));
    if (trip.driverId !== driverId)
      throw new ForbiddenException('Only the trip driver can reject bookings');
    if (booking.status !== BookingStatus.PENDING)
      throw new BadRequestException('Only pending bookings can be rejected');

    booking.status = BookingStatus.REJECTED;
    booking.cancellationReason = reason ?? null;
    booking.cancelledAt = new Date();
    booking.cancelledBy = 'driver';
    await this.bookingRepo.save(booking);

    // Release all seats in this booking
    const seatNumbers = (booking.seats ?? []).map((s) => s.seatNumber);
    for (const sn of seatNumbers) {
      await this.tripsService
        .releaseSeat(booking.tripId, sn)
        .catch(() => undefined);
      await this.tripsGateway
        .emitSeatReleased(booking.tripId, sn)
        .catch(() => undefined);
    }

    // Cancel the timeout job
    try {
      const job = await this.bookingsTimeoutQueue.getJob(
        `booking-expire-${bookingId}`,
      );
      if (job) await job.remove();
    } catch (err) {
      this.logger.warn(
        `Could not remove timeout job for booking ${bookingId}: ${(err as Error).message}`,
      );
    }

    this.notificationsService
      .notifyPassengerOfBookingDecision(bookingId, 'canceled')
      .catch((err) =>
        this.logger.warn(
          `Failed to notify passenger of reject: ${(err as Error).message}`,
        ),
      );

    this.logger.log(`Booking rejected: ${bookingId} by driver ${driverId}`);
    return booking;
  }
}
