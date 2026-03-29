import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { StripeService } from './stripe.service';
import { A2aCliqService } from './a2a-cliq.service';
import { PlatformPricingService } from './platform-pricing.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PaymentEntity,
      CommunicationFeeEntity,
      TripEntity,
      UserEntity,
    ]),
    ConfigModule,
    forwardRef(() => NotificationsModule),
  ],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    StripeService,
    A2aCliqService,
    PlatformPricingService,
  ],
  exports: [
    PaymentsService,
    StripeService,
    A2aCliqService,
    PlatformPricingService,
  ],
})
export class PaymentsModule {}
