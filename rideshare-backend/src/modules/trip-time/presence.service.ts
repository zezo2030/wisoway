import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, In, Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
  canDeclareSeat,
  seatCountsForCommission,
  BookingSeatEntity,
  PassengerDeclaredStatus,
  SeatAbsenceReason,
  TripEntity,
  TripStatus,
  UserEntity,
  VehicleEntity,
  PgUserRole,
} from '../../database/entities';
import { ErrorCodes } from '../../common/errors/error-codes';
import { NotificationsService } from '../notifications/notifications.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { TripStartService } from './trip-start.service';
import {
  DriverPresenceConfirmDto,
  PassengerDeclareDto,
  PresenceEntryDto,
} from './dto/presence.dto';

/** Statuses whose seats participate in billing. */
const BILLABLE_BOOKING_STATUSES: BookingStatus[] = [
  BookingStatus.CONFIRMED,
  BookingStatus.IN_PROGRESS,
  BookingStatus.COMPLETED,
];

/** Driver may edit the roster from 30 min before departure until settlement. */
const DRIVER_WINDOW_OPENS_MS = 30 * 60 * 1000;
/** Passenger self-declaration window, matching the pre-existing confirm window. */
const PASSENGER_WINDOW_BEFORE_MS = 60 * 60 * 1000;
const PASSENGER_WINDOW_AFTER_MS = 30 * 60 * 1000;

export interface SettlementOutcome {
  tripId: string;
  billableSeats: number;
  bookedSeats: number;
  /** Always 0 — kept for API/shape compatibility. The fee is charged once, at trip start. */
  captured: number;
  /** Always 0 — there is nothing left to release; no money is ever reserved. */
  released: number;
  currency: string;
  /** Always false — settlement never moves money any more. */
  applied: boolean;
}

/**
 * Presence confirmation and settlement record-keeping.
 *
 * A seat is billable only after its passenger explicitly confirms they are
 * inside the vehicle — this still drives no-show flags and the operational
 * roster. It no longer drives any wallet movement: the driver's fee is a
 * single debit taken at trip start by `DriverTripFeeService`.
 *
 * 012-passenger-presence-confirmation.
 */
@Injectable()
export class PresenceService {
  private readonly logger = new Logger(PresenceService.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(BookingSeatEntity)
    private readonly seatRepo: Repository<BookingSeatEntity>,
    private readonly notifications: NotificationsService,
    private readonly platformPricing: PlatformPricingService,
    private readonly tripStart: TripStartService,
  ) {}

  private round2(n: number): number {
    return Math.round(n * 100) / 100;
  }

  // ── Roster ────────────────────────────────────────────────────────────────

  async getRoster(tripId: string, driverId: string) {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.driverId !== driverId) {
      throw new ForbiddenException({
        statusCode: 403,
        code: ErrorCodes.NOT_TRIP_DRIVER,
        message: 'Only the trip driver can view the presence roster',
      });
    }
    return this.buildRoster(trip);
  }

  private async buildRoster(trip: TripEntity) {
    const bookings = await this.bookingRepo.find({
      where: { tripId: trip.id, status: In(BILLABLE_BOOKING_STATUSES) },
      relations: ['seats', 'user'],
    });

    const { percent, seatPrice, currency } = await this.pricingFor(trip);

    const seats = bookings.flatMap((booking) =>
      (booking.seats ?? []).map((seat) => {
        const driverState = seat.presenceConfirmedAt
          ? 'present'
          : seat.markedAbsentAt
            ? 'absent'
            : 'unset';
        return {
          bookingId: booking.id,
          seatId: seat.id,
          seatNumber: seat.seatNumber,
          displayName: seat.displayName,
          gender: seat.gender,
          isMainBooker: seat.isMainBooker,
          passengerDeclaredStatus: seat.passengerDeclaredStatus,
          passengerSelfConfirmedAt: seat.passengerSelfConfirmedAt,
          autoFlaggedAbsentAt: seat.autoFlaggedAbsentAt,
          absenceReason: seat.absenceReason,
          driverState,
          /** Passenger vouched for themselves — driver cannot silently zero it. */
          locked: seat.passengerSelfConfirmedAt != null,
          disputed: seat.presenceDisputedAt != null,
          billable: seat.isBillable,
        };
      }),
    );

    const billableSeats = seats.filter((s) => s.billable).length;
    // The fee is now a single fixed debit at trip start, on all seats —
    // there is nothing left to estimate per confirmed seat.
    const maxFee = this.round2(
      seatPrice * (trip.totalSeats ?? 0) * (percent / 100),
    );
    const estimatedFee = maxFee;

    const now = new Date();
    const opensAt = new Date(
      new Date(trip.departureTime).getTime() - DRIVER_WINDOW_OPENS_MS,
    );

    return {
      tripId: trip.id,
      status: trip.status,
      settled: trip.presenceSettledAt != null,
      window: {
        opensAt,
        closesAt: trip.presenceSettledAt,
        isOpen: trip.presenceSettledAt == null && now >= opensAt,
      },
      currency,
      seatPrice: seatPrice.toFixed(2),
      feePercent: percent,
      seats,
      summary: {
        totalSeats: trip.totalSeats ?? 0,
        bookedSeats: seats.length,
        billableSeats,
        estimatedFee: estimatedFee.toFixed(2),
        maxFee: maxFee.toFixed(2),
      },
    };
  }

  /** Pricing inputs for the current fee schedule. */
  private async pricingFor(trip: TripEntity): Promise<{
    percent: number;
    seatPrice: number;
    currency: string;
  }> {
    const row = await this.platformPricing.getFeeRowForCurrency(trip.currency);
    const pricing = this.platformPricing.driverUnlockPricing(trip, row);
    return {
      percent: pricing.driverUnlockPercent,
      seatPrice: pricing.seatPrice,
      currency: pricing.currency,
    };
  }

  // ── Driver confirmation ───────────────────────────────────────────────────

  async driverConfirm(
    tripId: string,
    driverId: string,
    dto: DriverPresenceConfirmDto,
  ) {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.driverId !== driverId) {
      throw new ForbiddenException({
        statusCode: 403,
        code: ErrorCodes.NOT_TRIP_DRIVER,
        message: 'Only the trip driver can confirm passenger presence',
      });
    }
    if (trip.presenceSettledAt) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.PRESENCE_ALREADY_SETTLED,
        message: 'This trip has already been settled — the roster is final',
      });
    }

    const now = new Date();
    const opensAt = new Date(
      new Date(trip.departureTime).getTime() - DRIVER_WINDOW_OPENS_MS,
    );
    if (now < opensAt) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.PRESENCE_WINDOW_CLOSED,
        message:
          'Presence confirmation opens 30 minutes before the departure time',
        opensAt,
      });
    }

    const bookingIds = [...new Set(dto.entries.map((e) => e.bookingId))];
    const bookings = await this.bookingRepo.find({
      where: { id: In(bookingIds), tripId },
      relations: ['seats'],
    });
    const byId = new Map(bookings.map((b) => [b.id, b]));

    const conflicts: BookingSeatEntity[] = [];
    // Seats the driver vouched for that their passenger hadn't confirmed:
    // each booker hears about it, and can report it if they weren't there.
    const vouched = new Map<BookingEntity, BookingSeatEntity[]>();

    for (const entry of dto.entries) {
      const booking = byId.get(entry.bookingId);
      if (!booking) {
        throw new BadRequestException({
          statusCode: 400,
          code: ErrorCodes.PRESENCE_SEAT_NOT_FOUND,
          message: `Booking ${entry.bookingId} is not part of this trip`,
        });
      }
      const seat = (booking.seats ?? []).find(
        (s) => s.seatNumber === entry.seatNumber,
      );
      if (!seat) {
        throw new BadRequestException({
          statusCode: 400,
          code: ErrorCodes.PRESENCE_SEAT_NOT_FOUND,
          message: `Seat ${entry.seatNumber} not found in booking ${entry.bookingId}`,
        });
      }

      const newlyVouched =
        entry.present &&
        seat.presenceConfirmedAt == null &&
        seat.passengerSelfConfirmedAt == null &&
        seat.passengerDeclaredStatus !== PassengerDeclaredStatus.IN_VEHICLE;
      this.applyDriverDecision(seat, entry, now);
      if (newlyVouched) {
        vouched.set(booking, [...(vouched.get(booking) ?? []), seat]);
      }
      if (seat.presenceDisputedAt && !conflicts.includes(seat)) {
        conflicts.push(seat);
      }
      await this.seatRepo.save(seat);
    }

    await this.syncBookingLevelFlags(bookingIds, now);

    if (conflicts.length > 0) {
      trip.presenceReviewFlagged = true;
      await this.tripRepo.save(trip);
      void this.notifyConflicts(trip, conflicts);
    }

    for (const [booking, seats] of vouched) {
      void this.notifyVouched(trip, booking, seats);
    }

    // «معي في السيارة» from the driver counts as boarding: a trip waiting at
    // departure starts, as it would on the passenger's own confirmation.
    if (dto.entries.some((e) => e.present)) {
      await this.tripStart
        .onPassengerBoarded(trip.id, now)
        .catch((err: Error) =>
          this.logger.warn(`start on driver vouch failed: ${err.message}`),
        );
    }

    return this.buildRoster(trip);
  }

  /**
   * The resolution table. Absence only sticks when the passenger has not
   * already vouched for themselves; a contradiction keeps the seat billable
   * and routes it to admin review instead of letting the driver decide alone.
   */
  private applyDriverDecision(
    seat: BookingSeatEntity,
    entry: PresenceEntryDto,
    now: Date,
  ): void {
    seat.presenceUpdatedAt = now;

    if (entry.present) {
      seat.presenceConfirmedAt = now;
      seat.markedAbsentAt = null;
      seat.absenceReason = null;
      // Driver vouching clears any earlier absence, including a passenger's
      // own "not riding" — they evidently boarded after all.
      seat.billableOverride = null;
      return;
    }

    seat.markedAbsentAt = now;
    seat.presenceConfirmedAt = null;
    seat.absenceReason = entry.reason ?? SeatAbsenceReason.NO_SHOW;

    if (seat.passengerSelfConfirmedAt) {
      // Conflict: passenger said "I am in the car". Stays billable.
      seat.presenceDisputedAt = now;
      seat.billableOverride = true;
      return;
    }

    seat.billableOverride = false;
  }

  /** Keeps the legacy booking-level timestamps meaningful for multi-seat bookings. */
  private async syncBookingLevelFlags(
    bookingIds: string[],
    now: Date,
  ): Promise<void> {
    const bookings = await this.bookingRepo.find({
      where: { id: In(bookingIds) },
      relations: ['seats'],
    });

    for (const booking of bookings) {
      const seats = booking.seats ?? [];
      if (seats.length === 0) continue;

      const anyPresent = seats.some((s) => s.presenceConfirmedAt != null);
      const allAbsent = seats.every((s) => s.markedAbsentAt != null);

      booking.driverConfirmedPassengerAt = anyPresent ? now : null;
      booking.driverMarkedAbsentAt = allAbsent ? now : null;
      await this.bookingRepo.save(booking);
    }
  }

  /**
   * Tells a booker the driver said [seats] are in the car. Opens their trip
   * screen, where «الإبلاغ عن مشكلة» reaches the admins if they weren't.
   */
  private async notifyVouched(
    trip: TripEntity,
    booking: BookingEntity,
    seats: BookingSeatEntity[],
  ): Promise<void> {
    try {
      const ar =
        (await this.notifications.getPreferredLocale(booking.userId)) === 'ar';
      const names = seats
        .map((s) => s.displayName?.trim())
        .filter((n): n is string => !!n);
      const forYou = seats.length === 1 && seats[0].isMainBooker;
      const who =
        forYou || names.length === 0 ? null : names.join(ar ? '، ' : ', ');
      await this.notifications.create({
        userId: booking.userId,
        type: 'presence_driver_confirmed',
        title: ar
          ? 'السائق أكّد تواجدك في السيارة'
          : 'The driver confirmed you are in the car',
        body: ar
          ? `${who ? `أكّد السائق أن ${who} معه` : 'أكّد السائق أنك معه'} في الرحلة إلى ${trip.toName}. إذا لم يكن هذا صحيحًا، اضغط «الإبلاغ عن مشكلة» في شاشة الرحلة.`
          : `The driver says ${who ? `${who} ${names.length > 1 ? 'are' : 'is'}` : 'you are'} with them on the trip to ${trip.toName}. If that's not right, tap "Report a problem" on the trip screen.`,
        data: { tripId: trip.id, bookingId: booking.id },
      });
    } catch (err) {
      this.logger.warn(
        `presence_driver_confirmed ${booking.id}: ${(err as Error).message}`,
      );
    }
  }

  private async notifyConflicts(
    trip: TripEntity,
    seats: BookingSeatEntity[],
    message?: string,
  ): Promise<void> {
    try {
      const admins = await this.tripRepo.manager
        .getRepository(UserEntity)
        .find({ where: { role: PgUserRole.ADMIN } });

      for (const admin of admins) {
        await this.notifications
          .create({
            userId: admin.id,
            type: 'presence_conflict_admin',
            title: 'تعارض في تأكيد التواجد',
            body:
              message ??
              `السائق علّم ${seats.length} راكبًا كغائب رغم تأكيدهم التواجد في الرحلة إلى ${trip.toName}.`,
            data: {
              tripId: trip.id,
              driverId: trip.driverId,
              seatIds: seats.map((s) => s.id),
            },
          })
          .catch((err: Error) =>
            this.logger.warn(`presence conflict notify: ${err.message}`),
          );
      }
    } catch (err) {
      this.logger.warn(`notifyConflicts: ${(err as Error).message}`);
    }
  }

  // ── Passenger declaration ────────────────────────────────────────────────

  async passengerDeclare(
    bookingId: string,
    userId: string,
    dto: PassengerDeclareDto,
  ) {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip', 'seats'],
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.userId !== userId) {
      throw new ForbiddenException('You can only declare for your own booking');
    }
    const trip = booking.trip;
    if (trip.presenceSettledAt) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.PRESENCE_ALREADY_SETTLED,
        message: 'This trip has already been settled',
      });
    }

    const now = new Date();
    if (!this.passengerWindow(trip, now.getTime()).isOpen) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.PRESENCE_WINDOW_CLOSED,
        message:
          'Presence declaration is available from 60 minutes before to 30 minutes after departure',
      });
    }

    const bookings = await this.passengerBookingsOnTrip(booking);
    const bookingOfSeat = new Map<BookingSeatEntity, BookingEntity>();
    for (const b of bookings) {
      for (const s of b.seats ?? []) bookingOfSeat.set(s, b);
    }
    const allSeats = [...bookingOfSeat.keys()];
    const targets = dto.seatNumbers?.length
      ? allSeats.filter((s) => dto.seatNumbers!.includes(s.seatNumber))
      : allSeats;

    if (targets.length === 0) {
      throw new BadRequestException({
        statusCode: 400,
        code: ErrorCodes.PRESENCE_SEAT_NOT_FOUND,
        message: 'No matching seats in this booking',
      });
    }

    // Repeating an answer changes nothing: a retry, or a double tap.
    const changing = targets.filter(
      (s) => s.passengerDeclaredStatus !== dto.status,
    );
    if (
      changing.some(
        (s) => !canDeclareSeat(s.passengerDeclaredStatus, dto.status),
      )
    ) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.PRESENCE_SEAT_FINAL,
        message: 'This answer can no longer be changed',
      });
    }

    const raisedConflicts: BookingSeatEntity[] = [];

    for (const seat of changing) {
      seat.passengerDeclaredStatus = dto.status;
      seat.presenceUpdatedAt = now;

      if (dto.status === PassengerDeclaredStatus.IN_VEHICLE) {
        seat.passengerSelfConfirmedAt = now;
        // Contradicts an earlier driver absence → force billable + review.
        if (seat.billableOverride === false) {
          seat.billableOverride = true;
          seat.presenceDisputedAt = now;
          raisedConflicts.push(seat);
        }
      } else {
        seat.passengerSelfConfirmedAt = null;
        // Opting out only zeroes the seat while the driver has not vouched.
        if (
          dto.status === PassengerDeclaredStatus.NOT_RIDING &&
          seat.presenceConfirmedAt == null
        ) {
          seat.billableOverride = false;
          seat.absenceReason = SeatAbsenceReason.CANCELLED_ON_SITE;
        }
      }

      await this.seatRepo.save(seat);
    }

    // One companion's answer must not undo another's on the same booking.
    for (const b of new Set(changing.map((s) => bookingOfSeat.get(s)!))) {
      b.passengerPresenceConfirmedAt = (b.seats ?? []).some(
        (s) => s.passengerSelfConfirmedAt != null,
      )
        ? (b.passengerPresenceConfirmedAt ?? now)
        : null;
      await this.bookingRepo.save(b);
    }

    // Claiming "did not ride" after the location proved otherwise.
    if (dto.status === PassengerDeclaredStatus.NOT_RIDING) {
      const contradicted = changing.filter(
        (s) => bookingOfSeat.get(s)!.locationVerifiedAt != null,
      );
      if (contradicted.length > 0) {
        for (const seat of contradicted) {
          seat.presenceDisputedAt = now;
          await this.seatRepo.save(seat);
        }
        void this.notifyConflicts(
          trip,
          contradicted,
          `موقع الراكب أثبت وجوده مع السائق رغم إعلانه عدم الركوب في ${contradicted.length} مقعد. العمولة ستُحتسب، ويرجى مراجعة الرحلة.`,
        );
      }
    }

    // A trip waiting at departure starts with its first rider on board.
    if (dto.status === PassengerDeclaredStatus.IN_VEHICLE) {
      await this.tripStart
        .onPassengerBoarded(trip.id, now)
        .catch((err: Error) =>
          this.logger.warn(`start on boarding failed: ${err.message}`),
        );
    }

    if (raisedConflicts.length > 0) {
      trip.presenceReviewFlagged = true;
      await this.tripRepo.save(trip);
      void this.notifyConflicts(trip, raisedConflicts);
    }

    void this.notifications
      .create({
        userId: trip.driverId,
        type: 'presence_passenger_declared',
        title: 'تحديث تواجد راكب',
        body: this.declarationBody(dto.status),
        data: { tripId: trip.id, bookingId, status: dto.status },
      })
      .catch((err: Error) =>
        this.logger.warn(`declare notify driver: ${err.message}`),
      );

    return {
      bookingId,
      status: dto.status,
      seatNumbers: targets.map((s) => s.seatNumber),
      declaredAt: now,
    };
  }

  private declarationBody(status: PassengerDeclaredStatus): string {
    switch (status) {
      case PassengerDeclaredStatus.IN_VEHICLE:
        return 'أكّد راكب تواجده داخل السيارة.';
      case PassengerDeclaredStatus.ON_MY_WAY:
        return 'راكب في طريقه إلى نقطة الانطلاق.';
      default:
        return 'راكب أبلغ أنه لن يستقل هذه الرحلة.';
    }
  }

  // ── Settlement ────────────────────────────────────────────────────────────

  /**
   * Record presence settlement for a trip: which seats were confirmed
   * present, which were not, and whether the roster needs admin review.
   *
   * Moves no money. The driver's fee is charged once, at trip start, by
   * `DriverTripFeeService` — this method must never write
   * `trip.capturedFeeAmount`, only read it back for reporting on an
   * already-settled trip.
   *
   * Idempotent by `trip.presenceSettledAt`. Called from `completeTrip`, the
   * auto-complete fallback, and the reconciliation job.
   */
  async settleTripPresence(
    tripId: string,
    manager?: EntityManager,
  ): Promise<SettlementOutcome> {
    const tripRepo = manager
      ? manager.getRepository(TripEntity)
      : this.tripRepo;
    const bookingRepo = manager
      ? manager.getRepository(BookingEntity)
      : this.bookingRepo;

    const trip = await tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    const { currency } = await this.pricingFor(trip);

    if (trip.presenceSettledAt) {
      return {
        tripId,
        billableSeats: trip.billableSeatCount ?? 0,
        bookedSeats: trip.billableSeatCount ?? 0,
        captured: Number(trip.capturedFeeAmount ?? 0),
        released: 0,
        currency,
        applied: false,
      };
    }

    const bookings = await bookingRepo.find({
      where: { tripId, status: In(BILLABLE_BOOKING_STATUSES) },
      relations: ['seats'],
    });
    const seats = bookings.flatMap((b) => b.seats ?? []);

    // The same rule the commission uses, so the summary and the charge agree.
    const billableSeats = bookings.flatMap((b) =>
      (b.seats ?? []).filter((seat) =>
        seatCountsForCommission(seat, b.locationVerifiedAt != null),
      ),
    ).length;

    const now = new Date();
    trip.presenceSettledAt = now;
    trip.billableSeatCount = billableSeats;
    if (seats.length > 0 && billableSeats === 0) {
      // Driver claimed nobody boarded — informational flag for admin review.
      trip.presenceReviewFlagged = true;
    }
    await tripRepo.save(trip);

    this.logger.log(
      `Trip ${tripId} settled: ${billableSeats}/${seats.length} billable seats (no money moved)`,
    );

    void this.notifyAbsentPassengers(trip, bookings);

    return {
      tripId,
      billableSeats,
      bookedSeats: seats.length,
      // Read back, never written here: the fee was already debited at trip
      // start by DriverTripFeeService. Reporting 0 would tell the driver's
      // trip summary the fee was 0.00 on a trip their wallet was just debited
      // for — the summary reads this field ahead of trip.capturedFeeAmount,
      // and 0 is not null, so it would shadow the real value. Matches the
      // already-settled branch above.
      captured: Number(trip.capturedFeeAmount ?? 0),
      released: 0,
      currency,
      applied: false,
    };
  }

  /** Tell anyone marked absent, so they can dispute within 24 h. */
  private async notifyAbsentPassengers(
    trip: TripEntity,
    bookings: BookingEntity[],
  ): Promise<void> {
    for (const booking of bookings) {
      const absent = (booking.seats ?? []).filter(
        (s) => s.billableOverride === false && s.markedAbsentAt != null,
      );
      if (absent.length === 0) continue;

      await this.notifications
        .create({
          userId: booking.userId,
          type: 'presence_marked_absent',
          title: 'تم تسجيل عدم حضورك',
          body: `أبلغ السائق أنك لم تحضر للرحلة إلى ${trip.toName}. إن كان ذلك غير صحيح يمكنك الاعتراض خلال 24 ساعة.`,
          data: {
            tripId: trip.id,
            bookingId: booking.id,
            seatNumbers: absent.map((s) => s.seatNumber),
          },
        })
        .catch((err: Error) =>
          this.logger.warn(`absent notify: ${err.message}`),
        );
    }
  }

  /**
   * [booking] and the passenger's other live bookings on the same trip. A
   * companion's seat is sometimes booked separately, from the same account; it
   * is confirmed with the passenger's own, or it would stay unconfirmed.
   */
  private async passengerBookingsOnTrip(
    booking: BookingEntity,
  ): Promise<BookingEntity[]> {
    const others =
      (await this.bookingRepo.find({
        where: {
          tripId: booking.tripId,
          userId: booking.userId,
          status: In([BookingStatus.CONFIRMED, BookingStatus.IN_PROGRESS]),
        },
        relations: ['seats'],
      })) ?? [];
    return [booking, ...others.filter((b) => b.id !== booking.id)];
  }

  // ── Passenger prompt payload ──────────────────────────────────────────────

  /** The prompt for this passenger's booking on a trip, or null if none. */
  async getPresencePromptForTrip(tripId: string, userId: string) {
    const booking = await this.bookingRepo.findOne({
      where: {
        tripId,
        userId,
        status: In([BookingStatus.CONFIRMED, BookingStatus.IN_PROGRESS]),
      },
      order: { createdAt: 'ASC' },
    });
    return booking ? this.getPresencePrompt(booking.id, userId) : null;
  }

  async getPresencePrompt(bookingId: string, userId: string) {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip', 'trip.driver', 'seats'],
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.userId !== userId) {
      throw new ForbiddenException('You can only view your own booking');
    }

    const trip = booking.trip;
    const driver = (trip as TripEntity & { driver?: UserEntity }).driver;
    const vehicle = await this.tripRepo.manager
      .getRepository(VehicleEntity)
      .findOne({ where: { driverId: trip.driverId } });

    const now = Date.now();
    const departure = new Date(trip.departureTime).getTime();

    return {
      bookingId,
      tripId: trip.id,
      driver: driver
        ? {
            id: driver.id,
            name: driver.name,
            photoUrl: driver.photoUrl ?? null,
            rating: driver.driverRating ?? null,
            ratingCount: driver.driverTotalRatings ?? 0,
          }
        : null,
      vehicle: vehicle
        ? {
            vehicleType: vehicle.vehicleType,
            model: vehicle.model,
            plateNumber: vehicle.plateNumber,
            // How the passenger spots the car; null when the driver gave none.
            color: vehicle.color ?? null,
            carImageUrl: vehicle.carImageUrl ?? trip.carImageUrl ?? null,
          }
        : null,
      pickup: {
        name: trip.fromName,
        address: trip.fromAddress,
        // GeoPoint stores [lng, lat] per GeoJSON.
        lat: trip.fromPoint?.coordinates?.[1] ?? null,
        lng: trip.fromPoint?.coordinates?.[0] ?? null,
      },
      departureTime: trip.departureTime,
      secondsUntilDeparture: Math.max(Math.round((departure - now) / 1000), 0),
      driverLocation:
        trip.lastDriverLocationLat != null && trip.lastDriverLocationLng != null
          ? {
              lat: trip.lastDriverLocationLat,
              lng: trip.lastDriverLocationLng,
              updatedAt: trip.lastDriverLocationAt,
            }
          : null,
      seats: (await this.passengerBookingsOnTrip(booking))
        .flatMap((b) => b.seats ?? [])
        .map((s) => ({
          seatNumber: s.seatNumber,
          displayName: s.displayName,
          isMainBooker: s.isMainBooker,
          declaredStatus: s.passengerDeclaredStatus,
          selfConfirmedAt: s.passengerSelfConfirmedAt,
          /** The driver said «معي في السيارة» for this seat. */
          driverConfirmedAt: s.presenceConfirmedAt,
        })),
      window: this.passengerWindow(trip, now),
    };
  }

  /**
   * When the passenger may say whether they are in the car: from an hour
   * before departure until the trip ends. The trip screen holds them until
   * they answer, so it stays open while the trip is live, shown as 30 min from
   * now.
   */
  private passengerWindow(
    trip: TripEntity,
    now: number,
  ): { opensAt: Date; closesAt: Date; isOpen: boolean } {
    const departure = new Date(trip.departureTime).getTime();
    const opensAt = departure - PASSENGER_WINDOW_BEFORE_MS;
    const live =
      trip.status !== TripStatus.COMPLETED &&
      trip.status !== TripStatus.CANCELLED;
    const closesAt = live
      ? Math.max(departure, now) + PASSENGER_WINDOW_AFTER_MS
      : Math.max(
          departure,
          new Date(trip.tripStartedAt ?? departure).getTime(),
        ) + PASSENGER_WINDOW_AFTER_MS;
    return {
      opensAt: new Date(opensAt),
      closesAt: new Date(closesAt),
      isOpen: now >= opensAt && now <= closesAt,
    };
  }
}
