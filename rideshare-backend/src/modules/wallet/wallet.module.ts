import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  BookingEntity,
  CommunicationFeeEntity,
  PayoutRequestEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletHoldEntity,
  WalletTransactionEntity,
} from '../../database/entities';
import { WalletController } from './wallet.controller';
import { WalletService } from './wallet.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      WalletAccountEntity,
      WalletTransactionEntity,
      WalletHoldEntity,
      PayoutRequestEntity,
      TripEntity,
      BookingEntity,
      UserEntity,
      CommunicationFeeEntity,
    ]),
  ],
  controllers: [WalletController],
  providers: [WalletService, PlatformPricingService],
  exports: [WalletService],
})
export class WalletModule {}
