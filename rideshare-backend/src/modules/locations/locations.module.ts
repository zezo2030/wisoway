import { Module } from '@nestjs/common';
import { LocationsService } from './locations.service';
import { LocationsController } from './locations.controller';
import { PlacesRateLimiter } from './places-rate-limiter';

@Module({
  controllers: [LocationsController],
  providers: [LocationsService, PlacesRateLimiter],
  exports: [LocationsService],
})
export class LocationsModule {}
