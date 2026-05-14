import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TripEntity } from '../database/entities/trip.entity';
import { BookingEntity } from '../database/entities/booking.entity';
import { TripRecurrenceRuleEntity } from '../database/entities/trip-recurrence-rule.entity';
import { PreTripConfirmProcessor } from './processors/pre-trip-confirm.processor';
import { RecurrenceSpawnProcessor } from './processors/recurrence-spawn.processor';
import { NotificationsModule } from '../modules/notifications/notifications.module';

@Module({
  imports: [
    BullModule.forRoot({
      redis: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
      },
    }),
    BullModule.registerQueue(
      { name: 'trip-expiration' },
      { name: 'notification-cleanup' },
      { name: 'new-trip-fanout' },
      { name: 'bookings-timeout' },
      { name: 'no-show-detector' },
      { name: 'pre-trip-confirm' },
      { name: 'recurrence-spawn' },
      { name: 'pending-charge-collect' },
      { name: 'trip-auto-start' },
      { name: 'trip-auto-complete' },
    ),
    TypeOrmModule.forFeature([
      TripEntity,
      BookingEntity,
      TripRecurrenceRuleEntity,
    ]),
    NotificationsModule,
  ],
  providers: [PreTripConfirmProcessor, RecurrenceSpawnProcessor],
  exports: [BullModule],
})
export class JobsModule {}
