import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { BullModule } from '@nestjs/bull';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { A2aCliqService } from './a2a-cliq.service';
import { PlatformPricingService } from './platform-pricing.service';
import {
  CliqPollProcessor,
  CLIQ_POLL_QUEUE,
} from './processors/cliq-poll.processor';
import { NotificationsModule } from '../notifications/notifications.module';
import { WalletModule } from '../wallet/wallet.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PaymentEntity,
      CommunicationFeeEntity,
      TripEntity,
      UserEntity,
    ]),
    ConfigModule,
    BullModule.registerQueue({ name: CLIQ_POLL_QUEUE }),
    forwardRef(() => NotificationsModule),
    WalletModule,
  ],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    A2aCliqService,
    PlatformPricingService,
    CliqPollProcessor,
  ],
  exports: [PaymentsService, A2aCliqService, PlatformPricingService],
})
export class PaymentsModule {}
