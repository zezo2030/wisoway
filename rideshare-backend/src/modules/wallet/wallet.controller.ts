import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WalletService } from './wallet.service';
import { CreateTopupDto } from './dto/create-topup.dto';
import { DriverTripChargeDto } from './dto/driver-trip-charge.dto';
import { CreatePayoutRequestDto } from './dto/create-payout-request.dto';

@ApiTags('wallet')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get wallet summary for current user' })
  async getSummary(
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: string,
  ) {
    return this.walletService.getWalletSummary(userId, role);
  }

  @Get('transactions')
  @ApiOperation({ summary: 'Get wallet transactions for current user' })
  async getTransactions(
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: string,
    @Query('limit') limit?: number,
  ) {
    return this.walletService.getWalletTransactions(userId, role, limit);
  }

  @Post('topup')
  @Roles('admin')
  @ApiOperation({
    summary: 'Instant wallet top-up (admin only)',
    description:
      'Drivers and passengers must use POST /payments/wallet/topup with proof; credit is applied on admin approval.',
  })
  async topup(
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: string,
    @Body() dto: CreateTopupDto,
  ) {
    return this.walletService.createTopup(userId, role, dto);
  }

  @Post('driver/trip-charge')
  @ApiOperation({ summary: 'Charge driver wallet to activate trip' })
  async chargeDriverTrip(
    @CurrentUser('id') driverId: string,
    @Body() dto: DriverTripChargeDto,
  ) {
    return this.walletService.chargeDriverForTrip(driverId, dto);
  }

  @Post('rider/pay-trip')
  @ApiOperation({ summary: 'Pay trip from rider wallet' })
  async payTripFromWallet(
    @CurrentUser('id') riderId: string,
    @Body()
    dto: { tripId: string; amount: number; idempotencyKey?: string },
  ) {
    return this.walletService.payTripFromRiderWallet(
      riderId,
      dto.tripId,
      dto.amount,
      dto.idempotencyKey,
    );
  }

  @Post('driver/payout-requests')
  @ApiOperation({ summary: 'Create manual payout request for driver earnings' })
  async createPayoutRequest(
    @CurrentUser('id') driverId: string,
    @Body() dto: CreatePayoutRequestDto,
  ) {
    return this.walletService.createPayoutRequest(driverId, dto);
  }
}
