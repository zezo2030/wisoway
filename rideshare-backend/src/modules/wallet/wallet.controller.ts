import {
  Body,
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
import { PayoutStatus } from '../../database/entities';

class ProcessPayoutDto {
  @IsEnum(PayoutStatus)
  status: PayoutStatus;
  @IsOptional()
  @IsString()
  @MaxLength(255)
  note?: string;
}
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WalletService } from './wallet.service';
import { CreateTopupDto } from './dto/create-topup.dto';
import { CreatePayoutRequestDto } from './dto/create-payout-request.dto';

@ApiTags('wallet')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get('driver/trip-eligibility')
  @Roles('driver')
  @ApiOperation({ summary: 'Check wallet eligibility before opening shared-trip creation' })
  async tripEligibility(
    @CurrentUser('id') id: string,
    @Query('country') country?: string,
  ) {
    const currency = (await this.walletService.resolveLocalCurrency(id, country)) || 'JOD';
    await this.walletService.assertNonNegativeDriverBalance(id, currency);
    return { eligible: true, currency };
  }

  @Get('driver/payout-requests')
  @Roles('driver')
  listMine(@CurrentUser('id') id: string) {
    return this.walletService.listPayouts(id);
  }

  @Get('admin/payout-requests')
  @Roles('admin')
  listPayouts() {
    return this.walletService.listPayouts();
  }

  @Patch('admin/payout-requests/:id')
  @Roles('admin')
  processPayout(
    @Param('id') id: string,
    @CurrentUser('id') adminId: string,
    @Body() dto: ProcessPayoutDto,
  ) {
    return this.walletService.processPayout(id, adminId, dto.status, dto.note);
  }

  @Get('admin/platform-balances')
  @Roles('admin')
  platformBalances() {
    return this.walletService.platformBalances();
  }

  @Get('me')
  @ApiOperation({
    summary: 'Get wallet summary for current user',
    description:
      'An empty wallet is shown in the currency of `country` (ISO alpha-2 of the device location), falling back to the phone number country.',
  })
  @ApiQuery({ name: 'country', required: false, example: 'SA' })
  async getSummary(
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: string,
    @Query('country') country?: string,
  ) {
    const currency = await this.walletService.resolveLocalCurrency(
      userId,
      country,
    );
    return this.walletService.getWalletSummary(userId, role, currency);
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
  @Roles('driver')
  @ApiOperation({ summary: 'Create manual payout request for driver earnings' })
  async createPayoutRequest(
    @CurrentUser('id') driverId: string,
    @Body() dto: CreatePayoutRequestDto,
  ) {
    return this.walletService.createPayoutRequest(driverId, dto);
  }
}
