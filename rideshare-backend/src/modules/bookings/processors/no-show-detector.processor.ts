/**
 * NoShowDetectorProcessor
 *
 * Consumes jobs from the `no-show-detector` Bull queue.
 * Each job carries `{ tripId: string }` and is enqueued by TripsService when a
 * trip is marked in-progress.  It fires after the no-show grace window
 * (default 30 min; overridable via NO_SHOW_GRACE_OVERRIDE_SECONDS for testing).
 *
 * For each confirmed booking on the trip whose passenger never self-declared,
 * the processor records a SOFT flag (`autoFlaggedAbsentAt`) on each seat.
 *
 * IMPORTANT — this flag is advisory only and NEVER affects billing.
 * Presence billing is default-billable: a seat is exempted from the driver's
 * fee only when the DRIVER explicitly marks it absent. If this processor wrote
 * the billing field instead, any driver whose passengers simply never opened
 * the app would get a free trip — so it deliberately does not touch
 * `markedAbsentAt`, `billableOverride`, or `driverMarkedAbsentAt`.
 *
 * Passengers are NEVER auto-charged. Fines are applied manually by admin
 * after investigation via POST /admin/fines.
 *
 * D1 / 012-passenger-presence-confirmation.
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

    let flaggedCount = 0;
    for (const booking of bookings) {
      if (booking.passengerPresenceConfirmedAt) continue;

      const now = new Date();
      const seats = booking.seats ?? [];
      for (const seat of seats) {
        // Only the passenger's silence is recorded. The driver may still mark
        // this seat present or absent, and until they mark it absent it stays
        // billable.
        if (seat.presenceConfirmedAt || seat.markedAbsentAt) continue;
        seat.autoFlaggedAbsentAt = now;
        await this.seatRepo.save(seat);
      }

      flaggedCount++;
      this.logger.log(
        `Booking ${booking.id} flagged: passenger never declared presence (advisory only, still billable)`,
      );
    }

    this.logger.log(
      `No-show detection complete for trip ${tripId}: ${flaggedCount} booking(s) soft-flagged`,
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
