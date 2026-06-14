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

@Processor('trip-auto-complete')
export class TripAutoCompleteProcessor {
  private readonly logger = new Logger(TripAutoCompleteProcessor.name);

  constructor(
    @InjectRepository(TripEntity) private tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    private notificationsService: NotificationsService,
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

    const activeBookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.IN_PROGRESS },
    });
    for (const booking of activeBookings) {
      booking.status = BookingStatus.COMPLETED;
      await this.bookingRepo.save(booking);
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
