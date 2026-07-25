import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TripTimeService } from './trip-time.service';
import { PresenceService } from './presence.service';
import { PassengerConfirmDto } from './dto/passenger-confirm.dto';
import { DriverConfirmDto } from './dto/driver-confirm.dto';
import {
  DriverPresenceConfirmDto,
  PassengerDeclareDto,
} from './dto/presence.dto';

@ApiTags('trip-time')
@ApiBearerAuth()
@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class TripTimeController {
  private readonly logger = new Logger(TripTimeController.name);

  constructor(
    private readonly tripTimeService: TripTimeService,
    private readonly presenceService: PresenceService,
  ) {}

  @Post('bookings/:id/passenger-confirm')
  @ApiOperation({ summary: 'Passenger confirms whether driver is present' })
  async passengerConfirm(
    @Param('id') bookingId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: PassengerConfirmDto,
  ) {
    return this.tripTimeService.passengerConfirm(bookingId, userId, dto);
  }

  @Post('bookings/:id/driver-confirm')
  @Roles('driver')
  @ApiOperation({
    summary:
      'Driver confirms one seat (legacy single-seat alias for /trips/:id/presence-confirm)',
  })
  async driverConfirm(
    @Param('id') bookingId: string,
    @CurrentUser('id') driverId: string,
    @Body() dto: DriverConfirmDto,
  ) {
    return this.tripTimeService.driverConfirm(bookingId, driverId, dto);
  }

  // ── Presence confirmation (012-passenger-presence-confirmation) ───────────

  @Get('trips/:id/presence-roster')
  @Roles('driver')
  @ApiOperation({
    summary:
      'Driver reads the seat roster with each occupant’s declared presence and a live fee preview',
  })
  async presenceRoster(
    @Param('id') tripId: string,
    @CurrentUser('id') driverId: string,
  ) {
    return this.presenceService.getRoster(tripId, driverId);
  }

  @Post('trips/:id/presence-confirm')
  @Roles('driver')
  @ApiOperation({
    summary:
      'Driver marks seats present/absent. Seats are billable by default — only an explicit absence exempts one.',
  })
  async presenceConfirm(
    @Param('id') tripId: string,
    @CurrentUser('id') driverId: string,
    @Body() dto: DriverPresenceConfirmDto,
  ) {
    return this.presenceService.driverConfirm(tripId, driverId, dto);
  }

  @Get('bookings/:id/presence-prompt')
  @ApiOperation({
    summary: 'Passenger reads everything the "are you in the vehicle?" screen renders',
  })
  async presencePrompt(
    @Param('id') bookingId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.presenceService.getPresencePrompt(bookingId, userId);
  }

  @Post('bookings/:id/presence-declare')
  @ApiOperation({
    summary: 'Passenger declares whether they are in the vehicle',
  })
  async presenceDeclare(
    @Param('id') bookingId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: PassengerDeclareDto,
  ) {
    return this.presenceService.passengerDeclare(bookingId, userId, dto);
  }
}
