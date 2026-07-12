import { Controller, Get, Param, Query, Req, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { LocationsService } from './locations.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { LocationAutocompleteQueryDto } from './dto/location-autocomplete.dto';

@ApiTags('locations')
@Controller('locations')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class LocationsController {
  constructor(private readonly locationsService: LocationsService) {}

  @Get('autocomplete')
  @ApiOperation({
    summary: 'Autocomplete places through the server-side Places proxy',
  })
  @ApiResponse({ status: 200, description: 'Place suggestions loaded' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 502, description: 'Places provider failed' })
  async autocomplete(
    @Query() query: LocationAutocompleteQueryDto,
    @Req() req: { user?: { id?: string; sub?: string } },
  ) {
    const userId = req.user?.id ?? req.user?.sub ?? 'unknown';
    return this.locationsService.autocomplete(query, userId);
  }

  @Get('place/:id')
  @ApiOperation({ summary: 'Resolve a place suggestion to coordinates' })
  @ApiResponse({ status: 200, description: 'Place details loaded' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  @ApiResponse({ status: 404, description: 'Place not found' })
  @ApiResponse({ status: 502, description: 'Places provider failed' })
  async placeDetail(@Param('id') placeId: string) {
    // Coordinates are encoded in the placeId, so no sessionToken is needed.
    return this.locationsService.placeDetail(placeId);
  }

  @Get('geocode')
  @ApiOperation({ summary: 'Geocode address to coordinates' })
  @ApiResponse({ status: 200, description: 'Coordinates found' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 404, description: 'Address not found' })
  async geocode(@Query('address') address: string) {
    return this.locationsService.geocode(address);
  }

  @Get('reverse-geocode')
  @ApiOperation({ summary: 'Reverse geocode coordinates to address' })
  @ApiResponse({ status: 200, description: 'Address found' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  async reverseGeocode(
    @Query('latitude') latitude: number,
    @Query('longitude') longitude: number,
  ) {
    return this.locationsService.reverseGeocode(latitude, longitude);
  }

  @Get('distance')
  @ApiOperation({ summary: 'Calculate distance between two points' })
  @ApiResponse({ status: 200, description: 'Distance calculated' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  async getDistance(
    @Query('fromLatitude') fromLatitude: number,
    @Query('fromLongitude') fromLongitude: number,
    @Query('toLatitude') toLatitude: number,
    @Query('toLongitude') toLongitude: number,
  ) {
    return this.locationsService.getDistance(
      fromLatitude,
      fromLongitude,
      toLatitude,
      toLongitude,
    );
  }

  @Get('route')
  @ApiOperation({ summary: 'Get driving route between two points' })
  @ApiResponse({ status: 200, description: 'Route loaded successfully' })
  @ApiResponse({ status: 400, description: 'Failed to load route' })
  async getRoute(
    @Query('fromLatitude') fromLatitude: number,
    @Query('fromLongitude') fromLongitude: number,
    @Query('toLatitude') toLatitude: number,
    @Query('toLongitude') toLongitude: number,
  ) {
    return this.locationsService.getRoute(
      fromLatitude,
      fromLongitude,
      toLatitude,
      toLongitude,
    );
  }
}
