import { Module, forwardRef } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RatingsController } from './ratings.controller';
import { RatingsService } from './ratings.service';
import { Rating, RatingSchema } from './schemas/rating.schema';
import { User, UserSchema } from '../users/schemas/user.schema';
import { Trip, TripSchema } from '../trips/schemas/trip.schema';
import { Booking, BookingSchema } from '../bookings/schemas/booking.schema';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Rating.name, schema: RatingSchema },
      { name: User.name, schema: UserSchema },
      { name: Trip.name, schema: TripSchema },
      { name: Booking.name, schema: BookingSchema },
    ]),
    forwardRef(() => NotificationsModule),
  ],
  controllers: [RatingsController],
  providers: [RatingsService],
  exports: [RatingsService],
})
export class RatingsModule {}
