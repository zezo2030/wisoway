import {
  Controller,
  Get,
  Post,
  Patch,
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
  ApiParam,
} from '@nestjs/swagger';
import { PaymentsService } from './payments.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { CreateCommunicationFeeDto } from './dto/create-communication-fee.dto';
import {
  ApprovePaymentDto,
  RejectPaymentDto,
  QueryPaymentsDto,
} from './dto/update-payment-status.dto';
import { CreateWalletTopupDto } from './dto/create-wallet-topup.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('payments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a payment for a trip booking' })
  @ApiResponse({ status: 201, description: 'Payment created successfully' })
  @ApiResponse({
    status: 400,
    description: 'Invalid input or payment already exists',
  })
  @ApiResponse({
    status: 403,
    description: "Cannot create payment for another user's booking",
  })
  @ApiResponse({ status: 404, description: 'Booking or trip not found' })
  async createPayment(
    @Body() createPaymentDto: CreatePaymentDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.paymentsService.createPayment(createPaymentDto, userId);
  }

  @Post('communication-fee')
  @Roles('driver')
  @ApiOperation({ summary: 'Create a communication fee payment (Driver only)' })
  @ApiResponse({
    status: 201,
    description: 'Communication fee payment created successfully',
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid input or fee already paid',
  })
  @ApiResponse({
    status: 403,
    description: 'Not authorized to pay for this trip',
  })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  async createCommunicationFee(
    @Body() createCommunicationFeeDto: CreateCommunicationFeeDto,
    @CurrentUser('id') driverId: string,
  ) {
    return this.paymentsService.createCommunicationFee(
      createCommunicationFeeDto,
      driverId,
    );
  }

  @Post('cliq/initiate')
  @Roles('driver')
  @ApiOperation({
    summary: 'Initiate CliQ A2A communication fee payment (Driver only)',
  })
  @ApiResponse({
    status: 201,
    description: 'CliQ communication fee payment initiated successfully',
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid input or fee already paid',
  })
  @ApiResponse({
    status: 403,
    description: 'Not authorized to pay for this trip',
  })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  async initiateCliqCommunicationFee(
    @Body()
    body: {
      bookingId: string;
      aliasType: 'ALIAS' | 'MOBL';
      aliasValue: string;
    },
    @CurrentUser('id') driverId: string,
  ) {
    return this.paymentsService.initiateCliqCommunicationFee({
      bookingId: body.bookingId,
      driverId,
      aliasType: body.aliasType,
      aliasValue: body.aliasValue,
    });
  }

  @Get('my')
  @ApiOperation({ summary: "Get current user's payments" })
  @ApiResponse({ status: 200, description: "List of user's payments" })
  async getMyPayments(
    @CurrentUser('id') userId: string,
    @Query() query: QueryPaymentsDto,
  ) {
    return this.paymentsService.findByUser(userId, query);
  }

  @Get('wallet/me')
  @Roles('driver')
  @ApiOperation({ summary: 'Get driver wallet balance and free-trip status' })
  @ApiResponse({ status: 200, description: 'Wallet summary' })
  async getWalletMe(@CurrentUser('id') userId: string) {
    return this.paymentsService.getWalletMe(userId);
  }

  @Get('wallet/transactions')
  @Roles('driver')
  @ApiOperation({ summary: 'Get driver wallet transaction history' })
  @ApiResponse({ status: 200, description: 'Paginated wallet transactions' })
  async getWalletTransactions(
    @CurrentUser('id') userId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.paymentsService.getWalletTransactions(userId, {
      page,
      limit,
    });
  }

  @Post('wallet/topup')
  @Roles('driver', 'passenger')
  @ApiOperation({
    summary: 'Create wallet top-up request (pending admin approval)',
  })
  @ApiResponse({ status: 201, description: 'Top-up request created' })
  @ApiResponse({ status: 400, description: 'Proof required for manual top-up' })
  async createWalletTopup(
    @Body() dto: CreateWalletTopupDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.paymentsService.createWalletTopup(userId, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get payment by ID' })
  @ApiParam({ name: 'id', description: 'Payment ID' })
  @ApiResponse({ status: 200, description: 'Payment details' })
  @ApiResponse({
    status: 403,
    description: 'Not authorized to view this payment',
  })
  @ApiResponse({ status: 404, description: 'Payment not found' })
  async getPayment(
    @Param('id') paymentId: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: string,
  ) {
    const isAdmin = role === 'admin';
    return this.paymentsService.findById(paymentId, userId, isAdmin);
  }

  @Get(':id/cliq-status')
  @Roles('driver', 'admin')
  @ApiOperation({
    summary: 'Refresh and get CliQ A2A payment status by payment ID',
  })
  @ApiParam({ name: 'id', description: 'Payment ID' })
  @ApiResponse({ status: 200, description: 'CliQ payment status updated' })
  async getCliqPaymentStatus(@Param('id') paymentId: string) {
    return this.paymentsService.refreshCliqPaymentStatus(paymentId);
  }

  @Patch(':id/approve')
  @Roles('admin')
  @ApiOperation({ summary: 'Approve a payment (Admin only)' })
  @ApiParam({ name: 'id', description: 'Payment ID' })
  @ApiResponse({ status: 200, description: 'Payment approved successfully' })
  @ApiResponse({
    status: 400,
    description: 'Only pending payments can be approved',
  })
  @ApiResponse({ status: 404, description: 'Payment not found' })
  async approvePayment(
    @Param('id') paymentId: string,
    @CurrentUser('id') adminId: string,
    @Body() approveDto: ApprovePaymentDto,
  ) {
    return this.paymentsService.approve(paymentId, adminId, approveDto);
  }

  @Patch(':id/reject')
  @Roles('admin')
  @ApiOperation({ summary: 'Reject a payment (Admin only)' })
  @ApiParam({ name: 'id', description: 'Payment ID' })
  @ApiResponse({ status: 200, description: 'Payment rejected successfully' })
  @ApiResponse({
    status: 400,
    description: 'Only pending payments can be rejected',
  })
  @ApiResponse({ status: 404, description: 'Payment not found' })
  async rejectPayment(
    @Param('id') paymentId: string,
    @CurrentUser('id') adminId: string,
    @Body() rejectDto: RejectPaymentDto,
  ) {
    return this.paymentsService.reject(paymentId, adminId, rejectDto);
  }
}
