import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { BookingsService } from './bookings.service';

/**
 * Refunds passenger wallet holds when trip departure time passed without driver confirmation.
 */
@Injectable()
export class PendingBookingHoldJob {
  private readonly logger = new Logger(PendingBookingHoldJob.name);

  constructor(private readonly bookingsService: BookingsService) {}

  @Cron('*/5 * * * *')
  async handle(): Promise<void> {
    try {
      await this.bookingsService.releasePassengerHoldsForDepartedTrips();
    } catch (e) {
      this.logger.error((e as Error).message);
    }
  }
}
