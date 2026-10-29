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
  PlatformSettingEntity,
} from '../../database/entities';
import { WalletController } from './wallet.controller';
import { WalletService } from './wallet.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PlatformSettingsModule } from '../platform-settings/platform-settings.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { DriverWalletPolicyService } from './driver-wallet-policy.service';

@Module({
  imports: [
    PlatformSettingsModule,
    NotificationsModule,
    TypeOrmModule.forFeature([
      WalletAccountEntity,
      WalletTransactionEntity,
      WalletHoldEntity,
      PayoutRequestEntity,
      TripEntity,
      BookingEntity,
      UserEntity,
      CommunicationFeeEntity,
      PlatformSettingEntity,
    ]),
  ],
  controllers: [WalletController],
  providers: [WalletService, PlatformPricingService, DriverWalletPolicyService],
  exports: [WalletService],
})
export class WalletModule {}
