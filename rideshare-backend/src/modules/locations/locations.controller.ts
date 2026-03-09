import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { LocationsService } from './locations.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('locations')
@Controller('locations')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class LocationsController {
  constructor(private readonly locationsService: LocationsService) {}

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
}
