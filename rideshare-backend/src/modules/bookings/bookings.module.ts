import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { BookingEntity } from '../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../database/entities/booking-seat.entity';
import { PendingChargeEntity } from '../../database/entities/pending-charge.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { BookingsController } from './bookings.controller';
import { BookingsV2Controller } from './bookings-v2.controller';
import { BookingsService } from './bookings.service';
import { BookingsTimeoutProcessor } from './processors/bookings-timeout.processor';
import { NoShowDetectorProcessor } from './processors/no-show-detector.processor';
import { TripAutoStartProcessor } from './processors/trip-auto-start.processor';
import { TripAutoCompleteProcessor } from './processors/trip-auto-complete.processor';
import { TripsModule } from '../trips/trips.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      BookingEntity,
      BookingSeatEntity,
      PendingChargeEntity,
      TripEntity,
      PaymentEntity,
    ]),
    BullModule.registerQueue(
      { name: 'bookings-timeout' },
      { name: 'no-show-detector' },
      { name: 'trip-auto-start' },
      { name: 'trip-auto-complete' },
    ),
    forwardRef(() => TripsModule),
    UsersModule,
    forwardRef(() => NotificationsModule),
    forwardRef(() => PaymentsModule),
  ],
  controllers: [BookingsController, BookingsV2Controller],
  providers: [
    BookingsService,
    BookingsTimeoutProcessor,
    NoShowDetectorProcessor,
    TripAutoStartProcessor,
    TripAutoCompleteProcessor,
  ],
  exports: [BookingsService],
})
export class BookingsModule {}
