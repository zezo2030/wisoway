import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Trip, TripDocument } from '../modules/trips/schemas/trip.schema';

@Injectable()
export class TripExpirationJob {
  private readonly logger = new Logger(TripExpirationJob.name);

  constructor(@InjectModel(Trip.name) private tripModel: Model<TripDocument>) {}

  // Run every 15 minutes
  @Cron('*/15 * * * *')
  async handleTripExpiration() {
    this.logger.log('Running trip expiration job...');

    const result = await this.tripModel.updateMany(
      {
        status: 'active',
        departureTime: { $lt: new Date() },
      },
      { status: 'expired' },
    );

    if (result.modifiedCount > 0) {
      this.logger.log(`Expired ${result.modifiedCount} trips`);
    }

    return result;
  }
}
