/**
 * NoShowDetectorProcessor
 *
 * Consumes jobs from the `no-show-detector` Bull queue.
 * Each job carries `{ tripId: string }` and is enqueued by TripsService when a
 * trip is marked in-progress.  It fires after the no-show grace window
 * (default 30 min; overridable via NO_SHOW_GRACE_OVERRIDE_SECONDS for testing).
 *
 * For each confirmed booking on the trip that has NOT been marked as present
 * (passengerPresenceConfirmedAt is null), the processor:
 *  1. Marks every BookingSeat in that booking as absent (markedAbsentAt)
 *  2. Sets booking.driverMarkedAbsentAt
 *
 * Passengers are NEVER auto-charged. Fines are applied manually by admin
 * after investigation via POST /admin/fines.
 */
import { Processor, Process, OnQueueFailed } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
} from '../../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../../database/entities/booking-seat.entity';

@Processor('no-show-detector')
export class NoShowDetectorProcessor {
  private readonly logger = new Logger(NoShowDetectorProcessor.name);

  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(BookingSeatEntity)
    private seatRepo: Repository<BookingSeatEntity>,
  ) {}

  @Process('detect-no-shows')
  async handleDetect(job: Job<{ tripId: string }>): Promise<void> {
    const { tripId } = job.data;
    this.logger.log(`No-show detection starting for trip ${tripId}`);

    const bookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.CONFIRMED },
      relations: ['seats'],
    });

    let noShowCount = 0;
    for (const booking of bookings) {
      if (booking.passengerPresenceConfirmedAt) continue;

      const now = new Date();
      booking.driverMarkedAbsentAt = now;
      await this.bookingRepo.save(booking);

      const seats = booking.seats ?? [];
      for (const seat of seats) {
        seat.markedAbsentAt = now;
        await this.seatRepo.save(seat);
      }

      noShowCount++;
      this.logger.log(`Booking ${booking.id} marked as no-show`);
    }

    this.logger.log(
      `No-show detection complete for trip ${tripId}: ${noShowCount} no-show(s) recorded`,
    );
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `No-show detector job ${job.id} failed for trip ${job.data.tripId}: ${error.message}`,
      error.stack,
    );
  }
}
