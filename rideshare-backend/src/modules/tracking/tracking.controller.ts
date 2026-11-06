import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PassengerLocationDto } from './dto/passenger-location.dto';
import { UpdateDriverLocationDto } from './dto/update-driver-location.dto';
import { PassengerLocationService } from './passenger-location.service';
import { TrackingGateway } from './tracking.gateway';
import { TrackingService } from './tracking.service';

@ApiTags('tracking')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('tracking')
export class TrackingController {
  constructor(
    private readonly trackingService: TrackingService,
    private readonly trackingGateway: TrackingGateway,
    private readonly passengerLocationService: PassengerLocationService,
  ) {}

  /**
   * The driver's location over HTTP. The socket is the fast path, but it
   * keeps the token it connected with and silently drops updates once that
   * expires; this path refreshes its token, so the passenger keeps seeing
   * the car.
   */
  @Post('location')
  @ApiOperation({ summary: 'Driver location update (socket fallback)' })
  async updateLocation(
    @CurrentUser('id') driverId: string,
    @Body() dto: UpdateDriverLocationDto,
  ) {
    const saved = await this.trackingService.updateDriverLocation(
      driverId,
      dto,
    );
    this.trackingGateway.server
      ?.to(`trip:${dto.tripId}`)
      .emit('trip:tracking:update', saved);
    return saved;
  }

  /**
   * The passenger's position during a shared trip, compared with the car's to
   * prove they rode. The reply tells the app when to stop sending.
   */
  @Post('passenger-location')
  @Throttle({ default: { ttl: 60000, limit: 12 } })
  @ApiOperation({ summary: 'Passenger location check during a trip' })
  async passengerLocation(
    @CurrentUser('id') userId: string,
    @Body() dto: PassengerLocationDto,
  ) {
    return this.passengerLocationService.record(userId, dto);
  }

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
