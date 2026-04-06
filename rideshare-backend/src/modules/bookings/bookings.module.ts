import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BookingEntity } from '../../database/entities/booking.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { PendingBookingHoldJob } from './pending-booking-hold.job';
import { TripsModule } from '../trips/trips.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([BookingEntity, TripEntity, PaymentEntity]),
    forwardRef(() => TripsModule),
    UsersModule,
    forwardRef(() => NotificationsModule),
    forwardRef(() => PaymentsModule),
  ],
  controllers: [BookingsController],
  providers: [BookingsService, PendingBookingHoldJob],
  exports: [BookingsService],
})
export class BookingsModule {}
