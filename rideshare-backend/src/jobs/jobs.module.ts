import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { TripExpirationJob } from './trip-expiration.job';
import { NotificationCleanupJob } from './notification-cleanup.job';
import { Trip, TripSchema } from '../modules/trips/schemas/trip.schema';
import {
  Notification,
  NotificationSchema,
} from '../modules/notifications/schemas/notification.schema';
import { MongooseModule } from '@nestjs/mongoose';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Trip.name, schema: TripSchema },
      { name: Notification.name, schema: NotificationSchema },
    ]),
    BullModule.forRoot({
      redis: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
      },
    }),
    BullModule.registerQueue(
      { name: 'trip-expiration' },
      { name: 'notification-cleanup' },
    ),
  ],
  providers: [TripExpirationJob, NotificationCleanupJob],
  exports: [TripExpirationJob, NotificationCleanupJob],
})
export class JobsModule {}
