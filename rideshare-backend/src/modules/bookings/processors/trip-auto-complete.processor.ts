/**
 * Runs once the trip's estimated time plus a margin has passed. If it is still
 * IN_PROGRESS — the driver never pressed "Arrived" — force COMPLETED so nobody
 * stays held on the trip screen. A car still driving towards a distant
 * destination gets more time, up to the fallback after departure.
 */
import { Processor, Process, OnQueueFailed, InjectQueue } from '@nestjs/bull';
import type { Job, Queue } from 'bull';
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
import { hasBoarded } from '../../trip-time/trip-time.service';
import { DriverTripFeeService } from '../../driver-trip-fee/driver-trip-fee.service';
import { RidePaymentsService } from '../../ride-payments/ride-payments.service';
import {
  TRIP_AUTO_COMPLETE_JOB_ID_PREFIX,
  tripAutoCompleteFallbackMs,
} from '../../trips/trip-auto-start.util';

const STILL_DRIVING_FIX_MS = 10 * 60 * 1000;
const STILL_DRIVING_KM = 3;
const RECHECK_MS = 15 * 60 * 1000;

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
    private readonly ridePayments: RidePaymentsService,
    @InjectQueue('trip-auto-complete')
    private readonly queue: Queue,
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
    if (this.stillDriving(trip, now)) {
      // A job can't re-add its own id while it runs, hence the time in it.
      await this.queue.add(
        'enforce',
        { tripId },
        {
          delay: RECHECK_MS,
          jobId: `${TRIP_AUTO_COMPLETE_JOB_ID_PREFIX}${tripId}-${now.getTime()}`,
          removeOnComplete: true,
          attempts: 2,
          backoff: { type: 'exponential', delay: 30000 },
        },
      );
      return;
    }

    trip.status = TripStatus.COMPLETED;
    trip.tripCompletedAt = now;
    await this.tripRepo.save(trip);

    const activeBookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.IN_PROGRESS },
      relations: ['seats'],
    });
    // Same rule as the driver's «تم الوصول»: only those who rode completed it.
    for (const booking of activeBookings) {
      booking.status = hasBoarded(booking)
        ? BookingStatus.COMPLETED
        : BookingStatus.NO_SHOW;
      await this.bookingRepo.save(booking);
    }

    await this.ridePayments.openForTrip(tripId);

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

  private stillDriving(trip: TripEntity, now: Date): boolean {
    const deadline =
      new Date(trip.departureTime).getTime() + tripAutoCompleteFallbackMs();
    const fixAt = trip.lastDriverLocationAt
      ? new Date(trip.lastDriverLocationAt).getTime()
      : 0;
    return (
      now.getTime() < deadline &&
      now.getTime() - fixAt <= STILL_DRIVING_FIX_MS &&
      (trip.remainingDistanceKm ?? 0) > STILL_DRIVING_KM
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
