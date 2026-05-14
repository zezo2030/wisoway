import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RatingsController } from './ratings.controller';
import { RatingsService } from './ratings.service';
import { RatingEntity } from '../../database/entities/rating.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      RatingEntity,
      UserEntity,
      TripEntity,
      BookingEntity,
    ]),
    NotificationsModule,
  ],
  controllers: [RatingsController],
  providers: [RatingsService],
  exports: [RatingsService],
})
export class RatingsModule {}
