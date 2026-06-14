import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { TripsService } from './trips.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';
import { SearchTripsDto } from './dto/search-trips.dto';
import { LocationBasedTripsDto } from './dto/location-based-trips.dto';
import { SetSeatLockDto } from './dto/set-seat-lock.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TripTimeService } from '../trip-time/trip-time.service';
import { CompleteTripDto } from '../trip-time/dto/complete-trip.dto';

@ApiTags('trips')
@Controller('trips')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class TripsController {
  constructor(
    private readonly tripsService: TripsService,
    private readonly tripTimeService: TripTimeService,
  ) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Create a new trip' })
  @ApiResponse({ status: 201, description: 'Trip created successfully' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 403, description: 'Not a driver' })
  async create(
    @Body() createTripDto: CreateTripDto,
    @CurrentUser('id') driverId: string,
    @CurrentUser('name') driverName: string,
  ) {
    return this.tripsService.create(createTripDto, driverId, driverName);
  }

  @Get()
  @ApiOperation({ summary: 'Search trips' })
  @ApiResponse({ status: 200, description: 'Trips found' })
  async search(@Query() searchTripsDto: SearchTripsDto) {
    return this.tripsService.search(searchTripsDto);
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Get nearby trips based on passenger location' })
  @ApiResponse({ status: 200, description: 'Nearby trips found' })
  async nearby(@Query() query: LocationBasedTripsDto) {
    return this.tripsService.getNearbyTrips(query);
  }

  @Get('preferred')
  @ApiOperation({ summary: 'Get preferred trips based on passenger location' })
  @ApiResponse({ status: 200, description: 'Preferred trips found' })
  async preferred(@Query() query: LocationBasedTripsDto) {
    return this.tripsService.getPreferredTrips(query);
  }

  @Get('my')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Get current driver trips' })
  @ApiResponse({ status: 200, description: 'Trips found' })
  async getMyTrips(
    @CurrentUser('id') driverId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
    @Query('status') status?: string,
  ) {
    return this.tripsService.findByDriver(driverId, {
      page: page || 1,
      limit: limit || 20,
    });
  }

  @Get(':id/pricing-preview')
  @ApiOperation({
    summary:
      'Passenger/driver platform pricing preview for one seat and driver unlock fee',
  })
  @ApiResponse({ status: 200, description: 'Pricing breakdown' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async pricingPreview(@Param('id') id: string) {
    return this.tripsService.getPricingPreview(id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get trip by ID' })
  @ApiResponse({ status: 200, description: 'Trip found' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async findById(@Param('id') id: string) {
    return this.tripsService.findById(id);
  }

  @Get(':id/seats')
  @ApiOperation({ summary: 'Get trip seats' })
  @ApiResponse({ status: 200, description: 'Seats found' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async getSeats(@Param('id') id: string) {
    return this.tripsService.getSeats(id);
  }

  @Patch(':id/seats/lock')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({
    summary: 'Lock or unlock a seat (e.g. external booking)',
  })
  @ApiResponse({ status: 200, description: 'Trip seats updated' })
  @ApiResponse({ status: 400, description: 'Invalid state or seat' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  async setSeatLock(
    @Param('id') id: string,
    @Body() dto: SetSeatLockDto,
    @CurrentUser('id') driverId: string,
  ) {
    return this.tripsService.setSeatLock(
      id,
      dto.seatNumber,
      dto.locked,
      driverId,
    );
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Update trip' })
  @ApiResponse({ status: 200, description: 'Trip updated successfully' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async update(
    @Param('id') id: string,
    @Body() updateTripDto: UpdateTripDto,
    @CurrentUser('id') driverId: string,
  ) {
    return this.tripsService.update(id, updateTripDto, driverId);
  }

  @Patch(':id/hide')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Hide trip' })
  @ApiResponse({ status: 200, description: 'Trip hidden successfully' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async hide(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.tripsService.hide(id, driverId);
  }

  @Post(':id/arrived')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({
    summary: 'Driver marks arrival at destination (completes the trip)',
  })
  @ApiResponse({ status: 200, description: 'Trip completed' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 403, description: 'Not the driver' })
  async markArrived(
    @Param('id') id: string,
    @CurrentUser('id') driverId: string,
    @Body() dto: CompleteTripDto,
  ) {
    return this.tripTimeService.completeTrip(id, driverId, dto);
  }

  @Post(':id/complete')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Legacy alias for /arrived (kept for clients)' })
  @ApiResponse({ status: 200, description: 'Trip completed' })
  async completeTrip(
    @Param('id') id: string,
    @CurrentUser('id') driverId: string,
    @Body() dto: CompleteTripDto,
  ) {
    return this.tripTimeService.completeTrip(id, driverId, dto);
  }

  @Patch(':id/legacy-complete')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Legacy complete trip (kept for backward compat)' })
  @ApiResponse({ status: 200, description: 'Trip completed successfully' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async complete(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.tripsService.complete(id, driverId);
  }

  @Patch(':id/show')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Show trip' })
  @ApiResponse({ status: 200, description: 'Trip shown successfully' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async show(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.tripsService.show(id, driverId);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Cancel trip' })
  @ApiResponse({ status: 200, description: 'Trip cancelled successfully' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async cancel(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.tripsService.cancel(id, driverId);
  }
}
