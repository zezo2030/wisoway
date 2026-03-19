import {
  Controller,
  Get,
  Patch,
  Delete,
  Query,
  Param,
  Body,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
  ApiParam,
} from '@nestjs/swagger';
import { AdminDashboardService } from './admin-dashboard.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { PgUserRole } from '../../database/entities/shared.enums';
import { AdminUsersQueryDto } from './dto/admin-users-query.dto';
import { AdminPaymentsQueryDto } from './dto/admin-payments-query.dto';
import { AdminVehiclesQueryDto } from './dto/admin-vehicles-query.dto';
import { AdminTripsQueryDto } from './dto/admin-trips-query.dto';
import { AdminBookingsQueryDto } from './dto/admin-bookings-query.dto';
import { AdminRatingsQueryDto } from './dto/admin-ratings-query.dto';
import { AdminNotificationsQueryDto } from './dto/admin-notifications-query.dto';
import { AdminChatQueryDto } from './dto/admin-chat-query.dto';
import { AdminReportsQueryDto } from './dto/admin-reports-query.dto';
import {
  ApproveDriverDto,
  VerifyVehicleDto,
} from './dto/admin-query.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@Controller('admin')
@Roles('admin')
export class AdminDashboardController {
  constructor(private readonly adminDashboardService: AdminDashboardService) {}

  /**
   * PATCH /admin/users/:id/confirm
   * Confirm user account (activate + mark phone/email as verified)
   */
  @Patch('users/:id/confirm')
  @ApiOperation({ summary: 'Confirm user account' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({ status: 200, description: 'User confirmed successfully' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async confirmUser(@Param('id') userId: string) {
    return this.adminDashboardService.confirmUser(userId);
  }

  /**
   * PATCH /admin/users/:id/approve-driver
   * Approve or reject driver
   */
  @Patch('users/:id/approve-driver')
  @ApiOperation({ summary: 'Approve or reject driver' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({ status: 200, description: 'Driver approval status updated' })
  @ApiResponse({ status: 400, description: 'User is not a driver' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async approveDriver(
    @Param('id') userId: string,
    @Body() approveDriverDto: ApproveDriverDto,
  ) {
    const user = await this.adminDashboardService.approveDriver(
      userId,
      approveDriverDto.approved,
    );
    return {
      message: 'Driver approval status updated',
      user,
    };
  }

  /**
   * DELETE /admin/users/:id
   * Delete user account
   */
  @Delete('users/:id')
  @ApiOperation({ summary: 'Delete user account' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({ status: 200, description: 'User deleted successfully' })
  @ApiResponse({ status: 404, description: 'User not found' })
  @ApiResponse({ status: 400, description: 'Cannot delete admin users' })
  async deleteUser(@Param('id') userId: string) {
    await this.adminDashboardService.deleteUser(userId);
    return { success: true, data: { message: 'User deleted' } };
  }

  @Get('users')
  @ApiOperation({ summary: 'Get paginated users with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'role', required: false, enum: PgUserRole })
  @ApiQuery({ name: 'search', required: false, type: String })
  @ApiQuery({ name: 'isActive', required: false, type: Boolean })
  @ApiResponse({ status: 200, description: 'Users retrieved successfully' })
  async getUsers(@Query() query: AdminUsersQueryDto) {
    return this.adminDashboardService.getUsers({
      page: query.page,
      limit: query.limit,
      role: query.role,
      search: query.search,
      isActive: query.isActive,
    });
  }

  @Get('payments/pending')
  @ApiOperation({ summary: 'Get pending payments queue' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Pending payments retrieved' })
  async getPendingPayments(@Query() query: AdminPaymentsQueryDto) {
    return this.adminDashboardService.getPendingPayments({
      page: query.page,
      limit: query.limit,
    });
  }

  @Get('vehicles')
  @ApiOperation({ summary: 'Get paginated vehicles with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'isVerified', required: false, type: Boolean })
  @ApiQuery({ name: 'driverId', required: false, type: String })
  @ApiResponse({ status: 200, description: 'Vehicles retrieved successfully' })
  async getVehicles(@Query() query: AdminVehiclesQueryDto) {
    return this.adminDashboardService.getVehicles({
      page: query.page,
      limit: query.limit,
      isVerified: query.isVerified,
      driverId: query.driverId,
    });
  }

  @Patch('vehicles/:id/verify')
  @ApiOperation({ summary: 'Verify or reject vehicle' })
  @ApiParam({ name: 'id', description: 'Vehicle ID' })
  @ApiResponse({ status: 200, description: 'Vehicle verification status updated' })
  @ApiResponse({ status: 404, description: 'Vehicle not found' })
  async verifyVehicle(
    @Param('id') vehicleId: string,
    @Body() verifyVehicleDto: VerifyVehicleDto,
  ) {
    return this.adminDashboardService.verifyVehicle(
      vehicleId,
      verifyVehicleDto.isVerified,
    );
  }

  @Get('payments')
  @ApiOperation({ summary: 'Get all payments with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['pending', 'approved', 'rejected', 'refunded'],
  })
  @ApiQuery({
    name: 'method',
    required: false,
    enum: ['stripe', 'paymob', 'manual', 'communication_fee'],
  })
  @ApiQuery({
    name: 'paymentType',
    required: false,
    enum: ['trip', 'communication_fee', 'wallet_topup', 'wallet_trip_charge'],
  })
  @ApiQuery({ name: 'walletOnly', required: false, type: Boolean })
  @ApiResponse({ status: 200, description: 'Payments retrieved successfully' })
  async getPayments(@Query() query: AdminPaymentsQueryDto) {
    return this.adminDashboardService.getPayments({
      page: query.page,
      limit: query.limit,
      status: query.status,
      method: query.method,
      paymentType: query.paymentType,
      walletOnly: query.walletOnly,
    });
  }

  @Get('trips')
  @ApiOperation({ summary: 'Get paginated trips with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['active', 'hidden', 'completed', 'cancelled'],
  })
  @ApiQuery({ name: 'driverId', required: false, type: String })
  @ApiResponse({ status: 200, description: 'Trips retrieved successfully' })
  async getTrips(@Query() query: AdminTripsQueryDto) {
    return this.adminDashboardService.getTrips({
      page: query.page,
      limit: query.limit,
      status: query.status,
      driverId: query.driverId,
    });
  }

  @Patch('bookings/:id/cancel')
  @ApiOperation({ summary: 'Cancel a booking (admin)' })
  @ApiParam({ name: 'id', description: 'Booking ID' })
  @ApiResponse({ status: 200, description: 'Booking cancelled successfully' })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  async cancelBooking(@Param('id') bookingId: string) {
    return this.adminDashboardService.cancelBooking(bookingId);
  }

  @Get('bookings')
  @ApiOperation({ summary: 'Get paginated bookings with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['pending', 'confirmed', 'cancelled', 'completed'],
  })
  @ApiQuery({ name: 'userId', required: false, type: String })
  @ApiQuery({ name: 'tripId', required: false, type: String })
  @ApiResponse({ status: 200, description: 'Bookings retrieved successfully' })
  async getBookings(@Query() query: AdminBookingsQueryDto) {
    return this.adminDashboardService.getBookings({
      page: query.page,
      limit: query.limit,
      status: query.status,
      userId: query.userId,
      tripId: query.tripId,
    });
  }

  @Get('ratings')
  @ApiOperation({ summary: 'Get paginated ratings with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'userId', required: false, type: String })
  @ApiQuery({ name: 'tripId', required: false, type: String })
  @ApiQuery({ name: 'minRating', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Ratings retrieved successfully' })
  async getRatings(@Query() query: AdminRatingsQueryDto) {
    return this.adminDashboardService.getRatings({
      page: query.page,
      limit: query.limit,
      userId: query.userId,
      tripId: query.tripId,
      minRating: query.minRating,
    });
  }

  @Get('notifications')
  @ApiOperation({ summary: 'Get paginated notifications' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'type', required: false, type: String })
  @ApiResponse({
    status: 200,
    description: 'Notifications retrieved successfully',
  })
  async getNotifications(@Query() query: AdminNotificationsQueryDto) {
    return this.adminDashboardService.getNotifications({
      page: query.page,
      limit: query.limit,
      type: query.type,
    });
  }

  @Get('chat/rooms')
  @ApiOperation({ summary: 'Get paginated chat rooms' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({
    status: 200,
    description: 'Chat rooms retrieved successfully',
  })
  async getChatRooms(@Query() query: AdminChatQueryDto) {
    return this.adminDashboardService.getChatRooms({
      page: query.page,
      limit: query.limit,
    });
  }

  @Get('reports')
  @ApiOperation({ summary: 'Generate report (revenue, users, or trips)' })
  @ApiQuery({
    name: 'type',
    required: true,
    enum: ['revenue', 'users', 'trips'],
  })
  @ApiQuery({ name: 'startDate', required: true, type: String })
  @ApiQuery({ name: 'endDate', required: true, type: String })
  @ApiResponse({ status: 200, description: 'Report generated successfully' })
  async generateReport(@Query() query: AdminReportsQueryDto) {
    return this.adminDashboardService.generateReport({
      type: query.type,
      startDate: query.startDate,
      endDate: query.endDate,
    });
  }

  @Get('dashboard/stats')
  @ApiOperation({ summary: 'Get dashboard statistics' })
  @ApiResponse({
    status: 200,
    description: 'Dashboard statistics retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean', example: true },
        data: {
          type: 'object',
          properties: {
            totalUsers: { type: 'number' },
            totalDrivers: { type: 'number' },
            totalPassengers: { type: 'number' },
            activeTrips: { type: 'number' },
            completedTrips: { type: 'number' },
            totalRevenue: { type: 'number' },
            pendingPayments: { type: 'number' },
            pendingVehicleVerifications: { type: 'number' },
          },
        },
      },
    },
  })
  async getDashboardStats() {
    return this.adminDashboardService.getDashboardStats();
  }
}
