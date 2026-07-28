import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { BookingEntity } from '../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../database/entities/booking-seat.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripShareLinkEntity } from '../../database/entities/trip-share-link.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { TripTimeService } from './trip-time.service';
import { PresenceService } from './presence.service';
import { TripTimeController } from './trip-time.controller';
import { NotificationsModule } from '../notifications/notifications.module';
import { WalletModule } from '../wallet/wallet.module';
import { PlatformPricingService } from '../payments/platform-pricing.service';

@Module({
  imports: [
    BullModule.registerQueue(
      { name: 'trip-auto-start' },
      { name: 'trip-auto-complete' },
    ),
    TypeOrmModule.forFeature([
      BookingEntity,
      BookingSeatEntity,
      TripEntity,
      TripShareLinkEntity,
      CommunicationFeeEntity,
      UserEntity,
    ]),
    forwardRef(() => NotificationsModule),
    WalletModule,
  ],
  controllers: [TripTimeController],
  providers: [TripTimeService, PresenceService, PlatformPricingService],
  exports: [TripTimeService, PresenceService],
})
export class TripTimeModule {}
