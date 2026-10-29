import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BookingEntity, TripEntity } from '../../database/entities';
import { haversineKm } from './instant-offer-labels';
import { InstantFareTariffService } from './instant-fare-tariff.service';
import { computeFare, waitingCharge } from './instant-rides.constants';

/** GPS fixes worse than this are left out of the driven distance. */
const MAX_FIX_ACCURACY_METERS = 50;

export interface MeteredFare {
  fare: number;
  distanceKm: number;
  durationMin: number;
  waitingCharge: number;
}

/**
 * The instant ride's meter: what the ride actually cost, from the road the
 * driver drove (their tracked path between «بدء الرحلة» and «تم الوصول»),
 * the time it took and the wait at the pickup, priced on the admin's tariff.
 * The price shown before ordering is only the estimate.
 */
@Injectable()
export class InstantMeterService {
  private readonly logger = new Logger(InstantMeterService.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    private readonly tariffs: InstantFareTariffService,
  ) {}

  /**
   * Prices the finished ride and writes it onto the trip and its booking, so
   * the payment that follows asks for the metered amount. A promo discount
   * stays taken off.
   */
  async settle(trip: TripEntity, endedAt: Date): Promise<MeteredFare | null> {
    if (!trip.tripStartedAt) return null;
    const startedAt = new Date(trip.tripStartedAt);
    const meter = await this.measure(trip, startedAt, endedAt);
    const tariff = await this.tariffs.tariffFor(trip.currency);
    const waitedMs = trip.driverArrivedAt
      ? startedAt.getTime() - new Date(trip.driverArrivedAt).getTime()
      : 0;
    const wait = waitingCharge(tariff, waitedMs);
    const fare =
      Math.round(
        (computeFare(
          meter.distanceKm,
          meter.durationMin,
          trip.currency,
          tariff,
        ) +
          wait) *
          100,
      ) / 100;

    const price = fare.toFixed(2);
    trip.price = price;
    await this.tripRepo.update({ id: trip.id }, { price });
    const booking = await this.bookingRepo.findOne({
      where: { tripId: trip.id },
    });
    if (booking) {
      const discount = Number(booking.discountAmount ?? 0);
      await this.bookingRepo.update(
        { id: booking.id },
        {
          originalAmount: price,
          totalAmount: Math.max(0, fare - discount).toFixed(2),
          seatPriceAtBooking: (
            fare / Math.max(1, booking.seatCount ?? 1)
          ).toFixed(2),
        },
      );
    }
    this.logger.log(
      `Trip ${trip.id} metered: ${meter.distanceKm.toFixed(2)} km, ` +
        `${meter.durationMin} min, waiting ${wait} → ${price} ${trip.currency}`,
    );
    return { fare, ...meter, waitingCharge: wait };
  }

  /**
   * Distance along the tracked path, never less than the straight line from
   * its first fix to its last (the app may have missed fixes in the
   * background), and the minutes from start to end.
   */
  private async measure(
    trip: TripEntity,
    startedAt: Date,
    endedAt: Date,
  ): Promise<{ distanceKm: number; durationMin: number }> {
    const durationMin = Math.max(
      0,
      Math.ceil((endedAt.getTime() - startedAt.getTime()) / 60_000 - 1e-9),
    );
    let distanceKm = 0;
    try {
      const rows: { lat: number; lng: number }[] = await this.tripRepo.query(
        `SELECT ST_Y(point::geometry) AS lat, ST_X(point::geometry) AS lng
           FROM driver_locations
          WHERE "tripId" = $1
            AND "recordedAt" BETWEEN $2 AND $3
            AND ("accuracyMeters" IS NULL OR "accuracyMeters" <= $4)
          ORDER BY "recordedAt" ASC`,
        [trip.id, startedAt, endedAt, MAX_FIX_ACCURACY_METERS],
      );
      const fixes = rows.map((r) => ({
        latitude: Number(r.lat),
        longitude: Number(r.lng),
      }));
      for (let i = 1; i < fixes.length; i++) {
        distanceKm += haversineKm(fixes[i - 1], fixes[i]);
      }
      if (fixes.length >= 2) {
        distanceKm = Math.max(
          distanceKm,
          haversineKm(fixes[0], fixes[fixes.length - 1]),
        );
      }
    } catch (err) {
      this.logger.warn(
        `Meter could not read the path of trip ${trip.id}: ${(err as Error).message}`,
      );
    }
    return { distanceKm, durationMin };
  }
}
