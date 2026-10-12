import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RidePaymentsService } from './ride-payments.service';

export class ConfirmCashDto {
  /** True: the driver was paid. False: the passenger didn't pay. */
  @IsBoolean()
  received: boolean;

  /** Non-payment only: what happened, for the support team. */
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

export class RetryCliqDto {
  /** A corrected alias / mobile, when the first one was wrong. */
  @IsOptional()
  @IsString()
  @MaxLength(100)
  payerCliqAlias?: string;
}

@ApiTags('Ride payments')
@ApiBearerAuth()
@Controller('ride-payments')
@UseGuards(JwtAuthGuard, RolesGuard)
export class RidePaymentsController {
  constructor(private readonly ridePayments: RidePaymentsService) {}

  @Get('trips/:tripId/mine')
  @ApiOperation({ summary: "Passenger: my fare on this trip and its status" })
  @ApiResponse({ status: 200, description: 'Fare and payment status' })
  mine(
    @Param('tripId') tripId: string,
    @CurrentUser('id') passengerId: string,
  ) {
    return this.ridePayments.getMine(tripId, passengerId);
  }

  @Post('bookings/:bookingId/cliq/retry')
  @ApiOperation({ summary: 'Passenger: send the CliQ request again' })
  @ApiResponse({ status: 201, description: 'Request sent' })
  @ApiResponse({ status: 409, description: 'Nothing failed to retry' })
  retry(
    @Param('bookingId') bookingId: string,
    @CurrentUser('id') passengerId: string,
    @Body() dto: RetryCliqDto,
  ) {
    return this.ridePayments.retryCliq(
      bookingId,
      passengerId,
      dto.payerCliqAlias,
    );
  }

  @Post('bookings/:bookingId/switch-to-cash')
  @ApiOperation({ summary: 'Passenger: pay the driver cash instead of CliQ' })
  @ApiResponse({ status: 201, description: 'Switched to cash' })
  switchToCash(
    @Param('bookingId') bookingId: string,
    @CurrentUser('id') passengerId: string,
  ) {
    return this.ridePayments.switchToCash(bookingId, passengerId);
  }

  @Get('trips/:tripId')
  @Roles('driver')
  @ApiOperation({ summary: "Driver: every rider's fare on this trip" })
  @ApiResponse({ status: 200, description: 'Fares and statuses' })
  forTrip(
    @Param('tripId') tripId: string,
    @CurrentUser('id') driverId: string,
  ) {
    return this.ridePayments.getForTrip(tripId, driverId);
  }

  @Post('bookings/:bookingId/cash')
  @Roles('driver')
  @ApiOperation({
    summary:
      'Driver: cash received, or not paid (files a payment complaint)',
  })
  @ApiResponse({ status: 201, description: 'Recorded' })
  @ApiResponse({ status: 409, description: 'Not a cash fare / trip not over' })
  confirmCash(
    @Param('bookingId') bookingId: string,
    @CurrentUser('id') driverId: string,
    @Body() dto: ConfirmCashDto,
  ) {
    return this.ridePayments.confirmCash(bookingId, driverId, dto);
  }
}
