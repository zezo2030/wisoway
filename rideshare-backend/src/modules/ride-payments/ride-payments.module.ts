import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { BookingEntity } from '../../database/entities/booking.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { PaymentsModule } from '../payments/payments.module';
import { WalletModule } from '../wallet/wallet.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ComplaintsModule } from '../complaints/complaints.module';
import {
  RIDE_FARE_CLIQ_QUEUE,
  RidePaymentsService,
} from './ride-payments.service';
import { RidePaymentsController } from './ride-payments.controller';
import { RideFarePollProcessor } from './ride-fare-poll.processor';

/**
 * Ride fares — cash confirmed by the driver, or CliQ collected by the
 * platform and credited to the driver's wallet. Shared by instant rides and
 * shared-trip bookings.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([BookingEntity, PaymentEntity, TripEntity]),
    BullModule.registerQueue({ name: RIDE_FARE_CLIQ_QUEUE }),
    PaymentsModule,
    WalletModule,
    forwardRef(() => NotificationsModule),
    ComplaintsModule,
  ],
  controllers: [RidePaymentsController],
  providers: [RidePaymentsService, RideFarePollProcessor],
  exports: [RidePaymentsService],
})
export class RidePaymentsModule {}
