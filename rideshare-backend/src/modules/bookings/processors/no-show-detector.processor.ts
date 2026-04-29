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
 *  3. Records a passenger_no_show PendingCharge (5% of totalAmount)
 *
 * Phase 4 / T079 — 008-platform-completion, US2 / 010-booking-lifecycle.
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
import { BookingSeatEntity } from '../../../database/entities/booking-seat.entity';
import { PendingChargeKind } from '../../../database/entities/pending-charge.entity';
import { PendingChargesService } from '../../pending-charges/pending-charges.service';

const NO_SHOW_CHARGE_RATE = 0.05; // 5% of booking totalAmount

@Processor('no-show-detector')
export class NoShowDetectorProcessor {
  private readonly logger = new Logger(NoShowDetectorProcessor.name);

  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(BookingSeatEntity)
    private seatRepo: Repository<BookingSeatEntity>,
    @Inject(forwardRef(() => PendingChargesService))
    private pendingChargesService: PendingChargesService,
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
      // If passenger already confirmed presence — skip
      if (booking.passengerPresenceConfirmedAt) continue;

      const now = new Date();
      booking.driverMarkedAbsentAt = now;
      await this.bookingRepo.save(booking);

      // Mark all seats in the booking as absent
      const seats = booking.seats ?? [];
      for (const seat of seats) {
        seat.markedAbsentAt = now;
        await this.seatRepo.save(seat);
      }

      // Record the 5% no-show charge
      const totalAmount = Number(
        booking.totalAmount ?? booking.seatPriceAtBooking ?? 0,
      );
      const chargeAmount = totalAmount * NO_SHOW_CHARGE_RATE;
      if (chargeAmount > 0) {
        await this.pendingChargesService
          .record({
            userId: booking.userId,
            kind: PendingChargeKind.PASSENGER_NO_SHOW,
            amount: chargeAmount,
            bookingId: booking.id,
            tripId,
          })
          .catch((err) =>
            this.logger.warn(
              `Failed to record no-show charge for booking ${booking.id}: ${(err as Error).message}`,
            ),
          );
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
