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
  BookingSeatEntity,
  PassengerDeclaredStatus,
  SeatAbsenceReason,
  TripEntity,
  UserEntity,
  VehicleEntity,
  PgUserRole,
} from '../../database/entities';
import { ErrorCodes } from '../../common/errors/error-codes';
import { NotificationsService } from '../notifications/notifications.service';
import { WalletHoldService } from '../wallet/wallet-hold.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
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
  captured: number;
  released: number;
  currency: string;
  /** False when there was nothing to settle (no hold, or already settled). */
  applied: boolean;
}

/**
 * Presence confirmation and fee settlement.
 *
 * BILLING RULE: a seat is billable only after its passenger explicitly confirms
 * they are inside the vehicle. Silence, "on my way", and "not riding" never
 * charge the driver's wallet.
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
    private readonly walletHolds: WalletHoldService,
    private readonly platformPricing: PlatformPricingService,
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
    const maxFee = this.round2(seatPrice * (trip.totalSeats ?? 0) * (percent / 100));
    const estimatedFee = this.round2(seatPrice * billableSeats * (percent / 100));

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
        estimatedRelease: this.round2(
          Math.max(maxFee - estimatedFee, 0),
        ).toFixed(2),
      },
    };
  }

  /**
   * Pricing inputs. Prefers the snapshot frozen into the hold at unlock so a
   * mid-trip change to `communication_fees` cannot alter what the driver pays.
   */
  private async pricingFor(trip: TripEntity): Promise<{
    percent: number;
    seatPrice: number;
    currency: string;
  }> {
    const hold = await this.walletHolds.getActiveHold('trip', trip.id);
    const snap = (hold?.metadata ?? null) as {
      percent?: number;
      seatPrice?: number;
    } | null;
    if (snap && typeof snap.percent === 'number') {
      return {
        percent: snap.percent,
        seatPrice: Number(snap.seatPrice ?? trip.price ?? 0),
        currency: hold?.currency ?? trip.currency ?? 'JOD',
      };
    }

    const row = await this.platformPricing.getActiveFeeRow('JO');
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

      this.applyDriverDecision(seat, entry, now);
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

  private async notifyConflicts(
    trip: TripEntity,
    seats: BookingSeatEntity[],
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
            body: `السائق علّم ${seats.length} راكبًا كغائب رغم تأكيدهم التواجد في الرحلة إلى ${trip.toName}.`,
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
    const departure = new Date(trip.departureTime).getTime();
    if (
      now.getTime() < departure - PASSENGER_WINDOW_BEFORE_MS ||
      now.getTime() > departure + PASSENGER_WINDOW_AFTER_MS
    ) {
      throw new ConflictException({
        statusCode: 409,
        code: ErrorCodes.PRESENCE_WINDOW_CLOSED,
        message:
          'Presence declaration is available from 60 minutes before to 30 minutes after departure',
      });
    }

    const allSeats = booking.seats ?? [];
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

    const raisedConflicts: BookingSeatEntity[] = [];

    for (const seat of targets) {
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

    booking.passengerPresenceConfirmedAt =
      dto.status === PassengerDeclaredStatus.IN_VEHICLE ? now : null;
    await this.bookingRepo.save(booking);

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
   * Capture the driver's fee for confirmed-present seats and release the rest.
   *
   * Idempotent by `trip.presenceSettledAt`, and safe to call when no hold was
   * ever placed (legacy trips, lifetime-free trips) — it simply records a zero
   * settlement. Called from `completeTrip`, the auto-complete fallback, and the
   * reconciliation job, so a trip can never strand a hold.
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

    const { percent, seatPrice, currency } = await this.pricingFor(trip);

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

    // Passenger confirmation is the sole billing authority.
    const billableSeats = seats.filter((seat) => seat.isBillable).length;

    const capture = this.round2(seatPrice * billableSeats * (percent / 100));

    let result: Awaited<ReturnType<WalletHoldService['settleHold']>> | null;
    try {
      result = await this.walletHolds.settleHold({
        referenceType: 'trip',
        referenceId: tripId,
        captureAmount: capture,
        metadata: {
          billableSeats,
          bookedSeats: seats.length,
          seatPrice,
          percent,
          formula: 'seatPrice * billableSeats * percent%',
        },
        manager,
      });
    } catch (error) {
      if (!(error instanceof NotFoundException)) {
        throw error;
      }
      // No hold: legacy trip, free lifetime trip, or unlock never happened.
      this.logger.log(
        `settleTripPresence ${tripId}: no wallet hold to settle`,
      );
      result = null;
    }

    const now = new Date();
    trip.presenceSettledAt = now;
    trip.billableSeatCount = billableSeats;
    trip.capturedFeeAmount = (result?.captured ?? 0).toFixed(2);
    if (seats.length > 0 && billableSeats === 0) {
      // Driver claimed nobody boarded — informational flag for admin review.
      trip.presenceReviewFlagged = true;
    }
    await tripRepo.save(trip);

    this.logger.log(
      `Trip ${tripId} settled: ${billableSeats}/${seats.length} billable seats, captured ${result?.captured ?? 0} ${currency}`,
    );

    void this.notifyAbsentPassengers(trip, bookings);

    return {
      tripId,
      billableSeats,
      bookedSeats: seats.length,
      captured: result?.captured ?? 0,
      released: result?.released ?? 0,
      currency,
      applied: result?.applied ?? false,
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

  // ── Passenger prompt payload ──────────────────────────────────────────────

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
            rating: driver.rating ?? null,
            ratingCount: driver.totalRatings ?? 0,
          }
        : null,
      vehicle: vehicle
        ? {
            // VehicleEntity has no make/color columns — the mockup's
            // "أبيض • تويوتا كورولا" line is rendered from vehicleType + model.
            vehicleType: vehicle.vehicleType,
            model: vehicle.model,
            plateNumber: vehicle.plateNumber,
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
      seats: (booking.seats ?? []).map((s) => ({
        seatNumber: s.seatNumber,
        displayName: s.displayName,
        isMainBooker: s.isMainBooker,
        declaredStatus: s.passengerDeclaredStatus,
        selfConfirmedAt: s.passengerSelfConfirmedAt,
      })),
      window: {
        opensAt: new Date(departure - PASSENGER_WINDOW_BEFORE_MS),
        closesAt: new Date(departure + PASSENGER_WINDOW_AFTER_MS),
        isOpen:
          now >= departure - PASSENGER_WINDOW_BEFORE_MS &&
          now <= departure + PASSENGER_WINDOW_AFTER_MS,
      },
    };
  }
}
