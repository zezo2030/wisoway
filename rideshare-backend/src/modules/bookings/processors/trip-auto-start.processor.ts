/**
 * Runs at the scheduled departureTime. If the trip is still PUBLISHED or
 * FULLY_BOOKED, it auto-transitions to IN_PROGRESS — drivers no longer need to
 * press a "Start Trip" button. Confirmed bookings also move to IN_PROGRESS.
 *
 * No fines are issued here. Driver no-show is surfaced to admins purely through
 * passenger reports (booking.passengerReportedDriverAbsentAt) collected during
 * the existing -60m to +30m confirmation window.
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
import {
  computeTripAutoCompleteDelayMs,
  TRIP_AUTO_COMPLETE_JOB_ID_PREFIX,
} from '../../trips/trip-auto-start.util';
import { NotificationsService } from '../../notifications/notifications.service';

const TERMINAL_TRIP_STATUSES: TripStatus[] = [
  TripStatus.COMPLETED,
  TripStatus.CANCELLED,
];

@Processor('trip-auto-start')
export class TripAutoStartProcessor {
  private readonly logger = new Logger(TripAutoStartProcessor.name);

  constructor(
    @InjectRepository(TripEntity) private tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectQueue('trip-auto-complete')
    private readonly autoCompleteQueue: Queue,
    private notificationsService: NotificationsService,
  ) {}

  @Process('enforce')
  async handle(job: Job<{ tripId: string }>): Promise<void> {
    const { tripId } = job.data;
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      this.logger.warn(`trip-auto-start: trip ${tripId} not found`);
      return;
    }

    if (TERMINAL_TRIP_STATUSES.includes(trip.status)) {
      return;
    }
    if (trip.status === TripStatus.IN_PROGRESS) {
      // Already started (legacy path or manual admin intervention)
      await this.scheduleAutoCompleteFallback(trip);
      return;
    }
    if (
      trip.status !== TripStatus.PUBLISHED &&
      trip.status !== TripStatus.FULLY_BOOKED &&
      trip.status !== TripStatus.ACTIVE
    ) {
      this.logger.warn(
        `trip-auto-start: trip ${tripId} in unexpected status ${trip.status}`,
      );
      return;
    }

    const now = new Date();
    trip.status = TripStatus.IN_PROGRESS;
    trip.tripStartedAt = now;
    await this.tripRepo.save(trip);

    const bookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.CONFIRMED },
    });
    for (const booking of bookings) {
      booking.status = BookingStatus.IN_PROGRESS;
      await this.bookingRepo.save(booking);
    }

    this.logger.log(
      `trip-auto-start: trip ${tripId} auto-started at ${now.toISOString()}`,
    );

    // Notify the driver and every confirmed passenger that the trip started,
    // prompting them to share live trip tracking with someone.
    const recipientIds = [trip.driverId, ...bookings.map((b) => b.userId)];
    for (const recipientId of recipientIds) {
      this.notificationsService
        .create({
          userId: recipientId,
          type: 'trip_started',
          title: 'بدأت الرحلة',
          body: `بدأت رحلتك إلى ${trip.toName}. يمكنك مشاركة تتبع الرحلة المباشر مع أحد.`,
          data: { tripId },
        })
        .catch((err: Error) =>
          this.logger.warn(
            `trip-started notify ${recipientId}: ${err.message}`,
          ),
        );
    }

    await this.scheduleAutoCompleteFallback(trip);
  }

  private async scheduleAutoCompleteFallback(trip: TripEntity): Promise<void> {
    const delay = computeTripAutoCompleteDelayMs(new Date(trip.departureTime));
    try {
      await this.autoCompleteQueue.add(
        'enforce',
        { tripId: trip.id },
        {
          delay,
          jobId: `${TRIP_AUTO_COMPLETE_JOB_ID_PREFIX}${trip.id}`,
          removeOnComplete: true,
          attempts: 2,
          backoff: { type: 'exponential', delay: 30000 },
        },
      );
    } catch (err) {
      this.logger.warn(
        `Failed to schedule auto-complete fallback for trip ${trip.id}: ${(err as Error).message}`,
      );
    }
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `trip-auto-start job ${job?.id}: ${error.message}`,
      error.stack,
    );
  }
}
