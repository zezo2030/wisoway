import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { BookingEntity } from '../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../database/entities/booking-seat.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripShareLinkEntity } from '../../database/entities/trip-share-link.entity';
import { TripTimeService } from './trip-time.service';
import { TripTimeController } from './trip-time.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    BullModule.registerQueue(
      { name: 'trip-auto-start' },
      { name: 'trip-auto-complete' },
    ),
    TypeOrmModule.forFeature([
      BookingEntity,
      BookingSeatEntity,
      TripEntity,
      TripShareLinkEntity,
    ]),
    forwardRef(() => NotificationsModule),
  ],
  controllers: [TripTimeController],
  providers: [TripTimeService],
  exports: [TripTimeService],
})
export class TripTimeModule {}
