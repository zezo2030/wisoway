import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  BookingEntity,
  PlatformSettingEntity,
  TripEntity,
} from '../../database/entities';
import { InstantFareTariffService } from './instant-fare-tariff.service';
import { InstantMeterService } from './instant-meter.service';

/**
 * The instant-ride tariff and meter, on their own so trip completion
 * (TripTimeModule) can price a ride without pulling in all of dispatch.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([
      PlatformSettingEntity,
      TripEntity,
      BookingEntity,
    ]),
  ],
  providers: [InstantFareTariffService, InstantMeterService],
  exports: [InstantFareTariffService, InstantMeterService],
})
export class InstantFareModule {}
