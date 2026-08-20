import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  BookingEntity,
  CommunicationFeeEntity,
  PendingChargeEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletTransactionEntity,
} from '../../database/entities';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PendingChargesModule } from '../pending-charges/pending-charges.module';
import { WalletModule } from '../wallet/wallet.module';
import { DriverTripFeeService } from './driver-trip-fee.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      TripEntity,
      BookingEntity,
      UserEntity,
      WalletAccountEntity,
      WalletTransactionEntity,
      CommunicationFeeEntity,
      PendingChargeEntity,
    ]),
    WalletModule,
    PendingChargesModule,
  ],
  providers: [DriverTripFeeService, PlatformPricingService],
  exports: [DriverTripFeeService],
})
export class DriverTripFeeModule {}
