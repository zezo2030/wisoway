/**
 * BookingsTimeoutProcessor
 *
 * Consumes jobs from the `bookings-timeout` Bull queue.
 * Each job carries `{ bookingId: string }` and is enqueued with a delay equal
 * to the driver-acceptance window (default 3 h; overridable via
 * BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS for testing).
 *
 * When the job fires, if the booking is still PENDING it is auto-cancelled
 * (the driver did not respond in time).  If it has already been accepted,
 * rejected, or cancelled the job is a no-op.
 *
 * Phase 4 / T078 — 008-platform-completion, US2 / 010-booking-lifecycle.
 */
import { Processor, Process, OnQueueFailed } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
} from '../../../database/entities/booking.entity';
import { BookingsService } from '../bookings.service';
import { TripsService } from '../../trips/trips.service';
import { TripsGateway } from '../../trips/trips.gateway';

@Processor('bookings-timeout')
export class BookingsTimeoutProcessor {
  private readonly logger = new Logger(BookingsTimeoutProcessor.name);

  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @Inject(forwardRef(() => TripsService)) private tripsService: TripsService,
    @Inject(forwardRef(() => TripsGateway)) private tripsGateway: TripsGateway,
  ) {}

  @Process('expire-booking')
  async handleExpire(job: Job<{ bookingId: string }>): Promise<void> {
    const { bookingId } = job.data;
    this.logger.log(`Timeout job fired for booking ${bookingId}`);

    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['seats'],
    });

    if (!booking) {
      this.logger.warn(`Booking ${bookingId} not found — skipping timeout`);
      return;
    }

    if (booking.status !== BookingStatus.PENDING) {
      this.logger.log(
        `Booking ${bookingId} is already ${booking.status} — timeout is a no-op`,
      );
      return;
    }

    // Auto-cancel the booking
    booking.status = BookingStatus.CANCELLED;
    booking.cancellationReason =
      'Driver did not respond within the acceptance window';
    booking.cancelledAt = new Date();
    booking.cancelledBy = 'system';
    await this.bookingRepo.save(booking);

    // Release all seats
    const seatNumbers = (booking.seats ?? []).map((s) => s.seatNumber);
    for (const sn of seatNumbers) {
      await this.tripsService
        .releaseSeat(booking.tripId, sn)
        .catch(() => undefined);
      await this.tripsGateway
        .emitSeatReleased(booking.tripId, sn)
        .catch(() => undefined);
    }

    this.logger.log(
      `Booking ${bookingId} auto-cancelled (timeout) — released ${seatNumbers.length} seat(s)`,
    );
  }

  @OnQueueFailed()
  handleFailed(job: Job, error: Error) {
    this.logger.error(
      `Timeout job ${job.id} failed for booking ${job.data.bookingId}: ${error.message}`,
      error.stack,
    );
  }
}
