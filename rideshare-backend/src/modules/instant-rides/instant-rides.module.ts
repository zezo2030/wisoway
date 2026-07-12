import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import {
  BookingEntity,
  DriverAvailabilityEntity,
  InstantRideOfferEntity,
  InstantRideRequestEntity,
  TripEntity,
} from '../../database/entities';
import { VehiclesModule } from '../vehicles/vehicles.module';
import { UsersModule } from '../users/users.module';
import { LocationsModule } from '../locations/locations.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { DriverAvailabilityService } from './driver-availability.service';
import { InstantDispatchService } from './instant-dispatch.service';
import { InstantRidesService } from './instant-rides.service';
import { InstantRidesController } from './instant-rides.controller';
import { InstantOfferTimeoutProcessor } from './processors/instant-offer-timeout.processor';
import { InstantRequestExpiryProcessor } from './processors/instant-request-expiry.processor';
import {
  INSTANT_OFFER_TIMEOUT_QUEUE,
  INSTANT_REQUEST_EXPIRY_QUEUE,
} from './instant-rides.constants';

/**
 * Instant (on-demand) rides — "الرحلات المباشرة".
 *
 * Phase 1: driver availability (online/offline + nearest-driver query).
 * Phase 2: passenger request → sequential dispatch → driver accept/decline →
 * instant trip + confirmed booking on accept, with offer/request timeouts.
 * See specs/010-instant-rides/design.md.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([
      DriverAvailabilityEntity,
      InstantRideRequestEntity,
      InstantRideOfferEntity,
      TripEntity,
      BookingEntity,
    ]),
    BullModule.registerQueue(
      { name: INSTANT_OFFER_TIMEOUT_QUEUE },
      { name: INSTANT_REQUEST_EXPIRY_QUEUE },
    ),
    VehiclesModule,
    UsersModule,
    LocationsModule,
    NotificationsModule,
  ],
  controllers: [InstantRidesController],
  providers: [
    DriverAvailabilityService,
    InstantDispatchService,
    InstantRidesService,
    InstantOfferTimeoutProcessor,
    InstantRequestExpiryProcessor,
  ],
  exports: [DriverAvailabilityService],
})
export class InstantRidesModule {}
