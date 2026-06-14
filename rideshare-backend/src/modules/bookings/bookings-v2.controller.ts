import {
  Controller,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
  Logger,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { BookingsService } from './bookings.service';
import {
  CreateMultiSeatBookingDto,
  AutoPickBookingDto,
} from './dto/create-multi-seat-booking.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

/**
 * V2 Bookings Controller
 *
 * Exposes multi-seat booking endpoints under /v2/bookings.
 * The legacy single-seat endpoint (POST /bookings) continues to function
 * via the v1 shim in BookingsController.
 *
 * Phase 4 / T068 — 008-platform-completion, US2 / 010-booking-lifecycle.
 */
@ApiTags('bookings-v2')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('v2/bookings')
export class BookingsV2Controller {
  private readonly logger = new Logger(BookingsV2Controller.name);

  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  @Roles('passenger', 'driver')
  @ApiOperation({
    summary: 'Create a multi-seat booking (v2)',
    description:
      'Book one or more seats in a single atomic transaction. ' +
      'All seat numbers must be available; gender-adjacency rules are enforced. ' +
      'A timeout job is enqueued to auto-expire the booking after 3 hours ' +
      'if the driver does not accept.',
  })
  @ApiResponse({ status: 201, description: 'Booking created' })
  @ApiResponse({
    status: 400,
    description: 'Seat unavailable, adjacency violation, or validation error',
  })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async create(
    @Body() dto: CreateMultiSeatBookingDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.bookingsService.createMultiSeat(dto, userId);
  }

  @Post('auto-pick')
  @Roles('passenger', 'driver')
  @ApiOperation({
    summary: 'Auto-pick the best available seats (v2)',
    description:
      'Finds the first contiguous block of seats that satisfies gender-adjacency ' +
      'rules and delegates to the multi-seat booking flow.',
  })
  @ApiResponse({
    status: 201,
    description: 'Booking created with auto-picked seats',
  })
  @ApiResponse({
    status: 400,
    description: 'No valid seats available or validation error',
  })
  @ApiResponse({ status: 404, description: 'Trip not found' })
  async autoPick(
    @Body() dto: AutoPickBookingDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.bookingsService.autoPick(dto, userId);
  }

  @Patch(':id/accept')
  @Roles('driver')
  @ApiOperation({
    summary: 'Accept (confirm) a pending booking (Driver only)',
    description:
      'Charges the driver wallet for the contact fee, marks the booking confirmed, ' +
      'and cancels the pending timeout job.',
  })
  @ApiResponse({ status: 200, description: 'Booking accepted' })
  @ApiResponse({ status: 400, description: 'Booking is not pending' })
  @ApiResponse({ status: 403, description: 'Not the trip driver' })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  async accept(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.bookingsService.accept(id, driverId);
  }

  @Patch(':id/reject')
  @Roles('driver')
  @ApiOperation({
    summary: 'Reject a pending booking (Driver only)',
    description:
      'Releases the seat(s), marks the booking rejected, and notifies the passenger.',
  })
  @ApiResponse({ status: 200, description: 'Booking rejected' })
  @ApiResponse({ status: 400, description: 'Booking is not pending' })
  @ApiResponse({ status: 403, description: 'Not the trip driver' })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  async reject(
    @Param('id') id: string,
    @Body('reason') reason: string | undefined,
    @CurrentUser('id') driverId: string,
  ) {
    return this.bookingsService.reject(id, driverId, reason);
  }
}
