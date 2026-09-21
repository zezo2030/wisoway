/**
 * Fallback runs at departureTime + N hours (default 24). If the trip is still
 * IN_PROGRESS — driver never pressed "Arrived" — force COMPLETED so the trip
 * doesn't hang in IN_PROGRESS forever.
 */
import { Processor, Process, OnQueueFailed } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TripEntity } from '../../../database/entities/trip.entity';
import { TripStatus } from '../../../database/entities/shared.enums';
import {
  BookingEntity,
  BookingStatus,
} from '../../../database/entities/booking.entity';
import { NotificationsService } from '../../notifications/notifications.service';
import { PresenceService } from '../../trip-time/presence.service';
import { DriverTripFeeService } from '../../driver-trip-fee/driver-trip-fee.service';

@Processor('trip-auto-complete')
export class TripAutoCompleteProcessor {
  private readonly logger = new Logger(TripAutoCompleteProcessor.name);

  constructor(
    @InjectRepository(TripEntity) private tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    private notificationsService: NotificationsService,
    private presenceService: PresenceService,
    private readonly driverTripFee: DriverTripFeeService,
  ) {}

  @Process('enforce')
  async handle(job: Job<{ tripId: string }>): Promise<void> {
    const { tripId } = job.data;
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) return;

    if (trip.status !== TripStatus.IN_PROGRESS) {
      return;
    }

    const now = new Date();
    trip.status = TripStatus.COMPLETED;
    trip.tripCompletedAt = now;
    await this.tripRepo.save(trip);

    // Net for a debit that failed at trip start (Task 5 deliberately swallows
    // that failure so a ledger problem can never block a trip from starting).
    // chargeAtTripStart is itself idempotent; this guard just avoids a
    // pointless round-trip. A trip is only ever left unstamped on purpose, so
    // this is the recovery path — log loudly when it actually recovers money,
    // and just as loudly when it can't, since nothing else will retry this
    // trip once this job finishes.
    //
    // Runs BEFORE the IN_PROGRESS -> COMPLETED booking pass below, and that
    // ordering is load-bearing. chargeAtTripStart decides whether a fee is owed
    // by counting bookings In([CONFIRMED, IN_PROGRESS]); flipping them first
    // empties that set, so the sweep would take the 'no-bookings' branch, write
    // a 0.00 audit row and stamp the trip — which also hides it from the
    // reconciliation cron, whose query is driverWalletChargeApplied IS NOT
    // TRUE. The rescue path would permanently zero the fee it exists to
    // recover. The fee is charged on totalSeats, so only the existence of
    // bookings matters here and nothing needs their final statuses.
    if (!trip.driverWalletChargeApplied) {
      try {
        const result = await this.driverTripFee.chargeAtTripStart(trip);
        // applied === false means chargeAtTripStart short-circuited on its own
        // idempotency (already charged elsewhere) — nothing was recovered here.
        // charged/pendingRemainder both 0 with applied === true means a real,
        // legitimate no-op (free trip, no bookings) rather than a recovery.
        if (
          result.applied &&
          (result.charged > 0 || result.pendingRemainder > 0)
        ) {
          this.logger.log(
            `trip-auto-complete: RECOVERED fee for trip ${tripId} — charged ${result.charged.toFixed(2)} ${result.currency}` +
              (result.pendingRemainder > 0
                ? `, ${result.pendingRemainder.toFixed(2)} recorded as pending charge`
                : '') +
              ` that trip-start missed`,
          );
        }
      } catch (err) {
        this.logger.error(
          `trip-auto-complete: fee reconciliation failed for trip ${tripId}: ${(err as Error).message}`,
        );
      }
    }

    const activeBookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.IN_PROGRESS },
    });
    for (const booking of activeBookings) {
      booking.status = BookingStatus.COMPLETED;
      await this.bookingRepo.save(booking);
    }

    // The driver never pressed "Arrived", so completeTrip() never ran and the
    // wallet hold would otherwise stay reserved forever. Settle it here on the
    // roster as it stands — seats the driver never marked absent stay billable.
    try {
      const settlement = await this.presenceService.settleTripPresence(tripId);
      this.logger.log(
        `trip-auto-complete: trip ${tripId} settled ${settlement.billableSeats}/${settlement.bookedSeats} seats, captured ${settlement.captured} ${settlement.currency}`,
      );
    } catch (err) {
      this.logger.error(
        `trip-auto-complete: settlement failed for trip ${tripId}: ${(err as Error).message}`,
      );
    }

    this.logger.log(
      `trip-auto-complete: trip ${tripId} auto-completed (fallback) at ${now.toISOString()}`,
    );

    this.notificationsService
      .create({
        userId: trip.driverId,
        type: 'trip_auto_completed',
        title: 'تم إنهاء الرحلة تلقائياً',
        body: `لم يتم تأكيد الوصول لرحلتك إلى ${trip.toName}. تم إنهاؤها تلقائياً.`,
        data: { tripId },
      })
      .catch((err: Error) =>
        this.logger.warn(`auto-complete driver notify: ${err.message}`),
      );
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `trip-auto-complete job ${job?.id}: ${error.message}`,
      error.stack,
    );
  }
}
