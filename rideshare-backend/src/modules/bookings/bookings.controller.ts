import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Request,
  ParseIntPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { CancelBookingDto } from './dto/cancel-booking.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('bookings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  @Roles('passenger', 'driver')
  @ApiOperation({
    summary: 'Create a new booking (Passenger or Driver as rider)',
  })
  @ApiResponse({ status: 201, description: 'Booking created successfully' })
  @ApiResponse({
    status: 400,
    description: 'Seat not available, gender mismatch, or booking own trip',
  })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async create(
    @Body() createBookingDto: CreateBookingDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.bookingsService.create(createBookingDto, userId);
  }

  @Get('my')
  @ApiOperation({ summary: 'Get current user bookings' })
  @ApiResponse({ status: 200, description: 'List of user bookings' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['pending', 'confirmed', 'cancelled', 'completed'],
  })
  async getMyBookings(
    @Query() pagination: PaginationDto,
    @Query('status') status?: string,
    @CurrentUser('id') userId?: string,
  ) {
    return this.bookingsService.findByUser(userId!, {
      page: pagination.page ?? 1,
      limit: pagination.limit ?? 20,
      status,
    });
  }

  @Get('trip/:tripId')
  @Roles('driver')
  @ApiOperation({ summary: 'Get bookings for a trip (Driver only)' })
  @ApiResponse({ status: 200, description: 'List of trip bookings' })
  @ApiResponse({ status: 403, description: 'Not trip owner' })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  async getTripBookings(
    @Param('tripId') tripId: string,
    @Query() pagination: PaginationDto,
    @CurrentUser('id') driverId: string,
  ) {
    return this.bookingsService.findByTrip(tripId, driverId, {
      page: pagination.page ?? 1,
      limit: pagination.limit ?? 20,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get booking by ID' })
  @ApiResponse({ status: 200, description: 'Booking details' })
  @ApiResponse({ status: 403, description: 'Not authorized' })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  async getById(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.bookingsService.findById(id, userId);
  }

  @Patch(':id/confirm')
  @Roles('driver')
  @ApiOperation({ summary: 'Confirm a booking (Driver only)' })
  @ApiResponse({ status: 200, description: 'Booking confirmed' })
  @ApiResponse({ status: 400, description: 'Not pending' })
  @ApiResponse({ status: 403, description: 'Not trip owner' })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  async confirm(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.bookingsService.confirm(id, driverId);
  }

  @Patch(':id/cancel')
  @ApiOperation({ summary: 'Cancel a booking' })
  @ApiResponse({ status: 200, description: 'Booking cancelled' })
  @ApiResponse({ status: 400, description: 'Already cancelled or completed' })
  @ApiResponse({ status: 403, description: 'Not authorized' })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  async cancel(
    @Param('id') id: string,
    @Body() cancelBookingDto: CancelBookingDto,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') userRole: string,
  ) {
    const isDriver = userRole === 'driver';
    return this.bookingsService.cancel(id, userId, cancelBookingDto, isDriver);
  }
}
