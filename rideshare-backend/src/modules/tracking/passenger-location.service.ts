import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import {
  BookingEntity,
  BookingSeatEntity,
  BookingStatus,
  PassengerDeclaredStatus,
  PgUserRole,
  TripEntity,
  TripStatus,
  TripType,
  UserEntity,
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.service';
import { PassengerLocationDto } from './dto/passenger-location.dto';

/** Closer than this, the passenger is with the car. */
const NEAR_METERS = 250;
/** Farther than this, they are not; between the two, GPS could say either. */
const APART_METERS = 500;
/** A reading less accurate than this proves nothing either way. */
const MAX_ACCURACY_METERS = 100;
/** The car must have moved this far for a reading to count as travel. */
const MIN_STEP_METERS = 100;
const REQUIRED_METERS = 1000;
const REQUIRED_MS = 3 * 60 * 1000;
/** The driver's position has to be this fresh to compare against. */
const DRIVER_FIX_MAX_AGE_MS = 60 * 1000;

export interface PassengerLocationResult {
  /** False once the app has no reason to keep sending. */
  tracking: boolean;
  verified: boolean;
}

function metersBetween(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const rad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(h));
}

/**
 * Proves a passenger rode by comparing their position with the car's while it
 * moves. Only the running result is kept: positions are never stored, and the
 * app stops sending as soon as the proof is complete.
 */
@Injectable()
export class PassengerLocationService {
  private readonly logger = new Logger(PassengerLocationService.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(BookingSeatEntity)
    private readonly seatRepo: Repository<BookingSeatEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    private readonly notifications: NotificationsService,
  ) {}

  async record(
    userId: string,
    dto: PassengerLocationDto,
  ): Promise<PassengerLocationResult> {
    const trip = await this.tripRepo.findOne({ where: { id: dto.tripId } });
    if (
      !trip ||
      trip.status !== TripStatus.IN_PROGRESS ||
      trip.tripType === TripType.INSTANT
    ) {
      return { tracking: false, verified: false };
    }

    const bookings = await this.bookingRepo.find({
      where: {
        tripId: trip.id,
        userId,
        status: In([BookingStatus.CONFIRMED, BookingStatus.IN_PROGRESS]),
      },
      relations: ['seats'],
    });
    if (bookings.length === 0) return { tracking: false, verified: false };
    if (bookings.every((b) => b.locationVerifiedAt)) {
      return { tracking: false, verified: true };
    }

    const driverAt = trip.lastDriverLocationAt
      ? new Date(trip.lastDriverLocationAt).getTime()
      : 0;
    const now = new Date();
    const driverFresh =
      now.getTime() - driverAt <= DRIVER_FIX_MAX_AGE_MS &&
      trip.lastDriverLocationLat != null &&
      trip.lastDriverLocationLng != null;
    const usable =
      driverFresh &&
      dto.isMockLocation !== true &&
      (dto.accuracyMeters ?? 0) <= MAX_ACCURACY_METERS;
    if (!usable) return { tracking: true, verified: false };

    const car = {
      lat: Number(trip.lastDriverLocationLat),
      lng: Number(trip.lastDriverLocationLng),
    };
    const distance = metersBetween(car, {
      lat: dto.latitude,
      lng: dto.longitude,
    });

    let verified = true;
    for (const booking of bookings) {
      if (booking.locationVerifiedAt) continue;
      await this.applyReading(booking, trip, car, distance, now);
      verified = verified && booking.locationVerifiedAt != null;
    }
    return { tracking: !verified, verified };
  }

  private async applyReading(
    booking: BookingEntity,
    trip: TripEntity,
    car: { lat: number; lng: number },
    distance: number,
    now: Date,
  ): Promise<void> {
    if (distance > APART_METERS) {
      if (booking.locationMatchStartedAt) {
        booking.locationMatchStartedAt = null;
        booking.locationMatchLat = null;
        booking.locationMatchLng = null;
        booking.locationMatchMeters = 0;
        await this.bookingRepo.save(booking);
      }
      return;
    }
    if (distance > NEAR_METERS) return;

    if (
      !booking.locationMatchStartedAt ||
      booking.locationMatchLat == null ||
      booking.locationMatchLng == null
    ) {
      booking.locationMatchStartedAt = now;
      booking.locationMatchLat = car.lat;
      booking.locationMatchLng = car.lng;
      booking.locationMatchMeters = 0;
      await this.bookingRepo.save(booking);
      return;
    }

    const step = metersBetween(
      { lat: booking.locationMatchLat, lng: booking.locationMatchLng },
      car,
    );
    if (step < MIN_STEP_METERS) return;

    booking.locationMatchLat = car.lat;
    booking.locationMatchLng = car.lng;
    booking.locationMatchMeters = Number(booking.locationMatchMeters) + step;
    const elapsed =
      now.getTime() - new Date(booking.locationMatchStartedAt).getTime();
    if (
      booking.locationMatchMeters >= REQUIRED_METERS &&
      elapsed >= REQUIRED_MS
    ) {
      booking.locationVerifiedAt = now;
    }
    await this.bookingRepo.save(booking);

    if (booking.locationVerifiedAt) await this.flagContradiction(booking, trip);
  }

  /** The location outweighs a "did not ride"; an admin reviews the charge. */
  private async flagContradiction(
    booking: BookingEntity,
    trip: TripEntity,
  ): Promise<void> {
    const contradicted = (booking.seats ?? []).filter(
      (seat) =>
        seat.passengerDeclaredStatus === PassengerDeclaredStatus.NOT_RIDING ||
        seat.markedAbsentAt != null,
    );
    if (contradicted.length === 0) return;

    const now = new Date();
    for (const seat of contradicted) {
      seat.presenceDisputedAt = now;
      await this.seatRepo.save(seat);
    }

    const admins = await this.userRepo.find({
      where: { role: PgUserRole.ADMIN },
    });
    for (const admin of admins) {
      await this.notifications
        .create({
          userId: admin.id,
          type: 'presence_conflict_admin',
          title: 'تعارض في تأكيد التواجد',
          body: `موقع الراكب أثبت وجوده مع السائق رغم تسجيل ${contradicted.length} مقعد كغياب. العمولة ستُحتسب، ويرجى مراجعة الرحلة.`,
          data: {
            tripId: trip.id,
            driverId: trip.driverId,
            seatIds: contradicted.map((seat) => seat.id),
          },
        })
        .catch((err: Error) =>
          this.logger.warn(`location conflict notify: ${err.message}`),
        );
    }
  }
}
