import { Processor, Process } from '@nestjs/bull';
import type { Job } from 'bull';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TripEntity } from '../../database/entities/trip.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { BookingStatus } from '../../database/entities/booking.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { NotificationsService } from '../../modules/notifications/notifications.service';
import { Logger } from '@nestjs/common';

@Processor('pre-trip-confirm')
export class PreTripConfirmProcessor {
  private readonly logger = new Logger(PreTripConfirmProcessor.name);

  constructor(
    @InjectRepository(TripEntity)
    private tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    private notificationsService: NotificationsService,
  ) {}

  @Process('send-prompts')
  async handlePreTripConfirm(job: Job<{ tripId: string }>) {
    const { tripId } = job.data;
    this.logger.log(`Processing pre-trip confirm for trip ${tripId}`);

    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      this.logger.warn(`Trip ${tripId} not found, skipping pre-trip confirm`);
      return;
    }

    if (
      trip.status !== TripStatus.PUBLISHED &&
      trip.status !== TripStatus.FULLY_BOOKED &&
      trip.status !== TripStatus.ACTIVE
    ) {
      this.logger.log(
        `Trip ${tripId} status is ${trip.status}, skipping pre-trip confirm`,
      );
      return;
    }

    if (trip.preTripConfirmSentAt) {
      this.logger.log(
        `Pre-trip confirm already sent for trip ${tripId}, skipping`,
      );
      return;
    }

    const bookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.CONFIRMED },
    });

    if (bookings.length === 0) {
      this.logger.log(`No confirmed bookings for trip ${tripId}, skipping`);
      return;
    }

    for (const booking of bookings) {
      await this.notificationsService
        .create({
          userId: booking.userId,
          type: 'pre_trip_confirm',
          title: 'Is the driver here?',
          body: `Your trip to ${trip.toName} departs soon. Please confirm the driver is present.`,
          data: { tripId, bookingId: booking.id },
        })
        .catch((err: Error) =>
          this.logger.warn(
            `Failed to send pre-trip prompt to passenger ${booking.userId}: ${err.message}`,
          ),
        );
    }

    await this.notificationsService
      .create({
        userId: trip.driverId,
        type: 'pre_trip_driver_prompt',
        title: 'Confirm passenger presence',
        body: `Your trip to ${trip.toName} departs soon. Please confirm each passenger is present.`,
        data: { tripId },
      })
      .catch((err: Error) =>
        this.logger.warn(
          `Failed to send pre-trip prompt to driver: ${err.message}`,
        ),
      );

    trip.preTripConfirmSentAt = new Date();
    await this.tripRepo.save(trip);

    this.logger.log(`Pre-trip confirm prompts sent for trip ${tripId}`);
  }
}
