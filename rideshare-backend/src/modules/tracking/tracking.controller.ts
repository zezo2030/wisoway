import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TrackingService } from './tracking.service';

@ApiTags('tracking')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('tracking')
export class TrackingController {
  constructor(private readonly trackingService: TrackingService) {}

  @Get(':tripId/latest')
  @ApiOperation({ summary: 'Get latest known trip location' })
  async getLatest(@Param('tripId') tripId: string) {
    return this.trackingService.getLatestTripLocation(tripId);
  }

  @Get(':tripId/history')
  @ApiOperation({ summary: 'Get trip location history' })
  async getHistory(
    @Param('tripId') tripId: string,
    @Query('limit') limit?: number,
  ) {
    return this.trackingService.getTripLocationHistory(tripId, limit);
  }

  @Get('nearby/trips')
  @ApiOperation({ summary: 'Find nearby trips using PostGIS ST_DWithin' })
  async getNearbyTrips(
    @Query('latitude') latitude: number,
    @Query('longitude') longitude: number,
    @Query('radiusMeters') radiusMeters?: number,
  ) {
    return this.trackingService.getNearbyTrips(
      latitude,
      longitude,
      radiusMeters,
    );
  }
}
