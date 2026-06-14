import {
  Controller,
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
import { PassengerConfirmDto } from './dto/passenger-confirm.dto';
import { DriverConfirmDto } from './dto/driver-confirm.dto';

@ApiTags('trip-time')
@ApiBearerAuth()
@Controller()
@UseGuards(JwtAuthGuard, RolesGuard)
export class TripTimeController {
  private readonly logger = new Logger(TripTimeController.name);

  constructor(private readonly tripTimeService: TripTimeService) {}

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
  @ApiOperation({ summary: 'Driver confirms per-seat passenger presence' })
  async driverConfirm(
    @Param('id') bookingId: string,
    @CurrentUser('id') driverId: string,
    @Body() dto: DriverConfirmDto,
  ) {
    return this.tripTimeService.driverConfirm(bookingId, driverId, dto);
  }
}
