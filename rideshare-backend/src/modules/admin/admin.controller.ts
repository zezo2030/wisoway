import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Query,
  Param,
  Body,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';
import {
  AdminUserQueryDto,
  AdminTripQueryDto,
  AdminPaymentQueryDto,
  AdminVehicleQueryDto,
  AdminBookingQueryDto,
  AdminRatingQueryDto,
  AdminNotificationQueryDto,
  AdminChatQueryDto,
  BroadcastNotificationDto,
  ChangeRoleDto,
  ToggleBanDto,
  VerifyVehicleDto,
  ApproveDriverDto,
  ReportQueryDto,
} from './dto/admin-query.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@Controller('admin')
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  /**
   * GET /admin/dashboard/stats
   * Get dashboard statistics
   */
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
            totalUsers: { type: 'number', example: 1500 },
            totalDrivers: { type: 'number', example: 300 },
            totalPassengers: { type: 'number', example: 1200 },
            activeTrips: { type: 'number', example: 45 },
            completedTrips: { type: 'number', example: 890 },
            totalRevenue: { type: 'number', example: 125000 },
            pendingPayments: { type: 'number', example: 12 },
            pendingVehicleVerifications: { type: 'number', example: 5 },
          },
        },
      },
    },
  })
  async getDashboardStats() {
    return this.adminService.getDashboardStats();
  }

  /**
   * GET /admin/users
   * Get paginated users with filters
   */
  @Get('users')
  @ApiOperation({ summary: 'Get paginated users with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'role', required: false, enum: UserRole })
  @ApiQuery({ name: 'search', required: false, type: String })
  @ApiQuery({ name: 'isActive', required: false, type: Boolean })
  @ApiResponse({
    status: 200,
    description: 'Users retrieved successfully',
  })
  async getUsers(@Query() query: AdminUserQueryDto) {
    return this.adminService.getUsers(query);
  }

  /**
   * PATCH /admin/users/:id/role
   * Change user role
   */
  @Patch('users/:id/role')
  @ApiOperation({ summary: 'Change user role' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({
    status: 200,
    description: 'User role updated successfully',
  })
  @ApiResponse({
    status: 404,
    description: 'User not found',
  })
  async changeUserRole(
    @Param('id') userId: string,
    @Body() changeRoleDto: ChangeRoleDto,
  ) {
    return this.adminService.changeUserRole(userId, changeRoleDto.role);
  }

  /**
   * PATCH /admin/users/:id/ban
   * Toggle user ban status
   */
  @Patch('users/:id/ban')
  @ApiOperation({ summary: 'Toggle user ban status' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({
    status: 200,
    description: 'User ban status updated successfully',
  })
  @ApiResponse({
    status: 404,
    description: 'User not found',
  })
  async toggleBan(
    @Param('id') userId: string,
    @Body() toggleBanDto: ToggleBanDto,
  ) {
    return this.adminService.toggleBan(userId, toggleBanDto.isActive);
  }

  /**
   * PATCH /admin/users/:id/confirm
   * Confirm user account (activate + mark verified)
   */
  @Patch('users/:id/confirm')
  @ApiOperation({ summary: 'Confirm user account' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({
    status: 200,
    description: 'User confirmed successfully',
  })
  @ApiResponse({
    status: 404,
    description: 'User not found',
  })
  async confirmUser(@Param('id') userId: string) {
    return this.adminService.confirmUser(userId);
  }

  /**
   * DELETE /admin/users/:id
   * Delete user account
   */
  @Delete('users/:id')
  @ApiOperation({ summary: 'Delete user account' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({
    status: 200,
    description: 'User deleted successfully',
  })
  @ApiResponse({
    status: 404,
    description: 'User not found',
  })
  async deleteUser(@Param('id') userId: string) {
    await this.adminService.deleteUser(userId);
    return { success: true, data: { message: 'User deleted' } };
  }

  /**
   * PATCH /admin/users/:id/approve-driver
   * Approve or reject driver
   */
  @Patch('users/:id/approve-driver')
  @ApiOperation({ summary: 'Approve or reject driver' })
  @ApiParam({ name: 'id', description: 'User ID' })
  @ApiResponse({
    status: 200,
    description: 'Driver approval status updated',
    schema: {
      type: 'object',
      properties: {
        message: { type: 'string', example: 'Driver approval status updated' },
        user: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            name: { type: 'string' },
            role: { type: 'string' },
            isDriverApproved: { type: 'boolean' },
          },
        },
      },
    },
  })
  @ApiResponse({
    status: 400,
    description: 'User is not a driver',
  })
  @ApiResponse({
    status: 404,
    description: 'User not found',
  })
  async approveDriver(
    @Param('id') userId: string,
    @Body() approveDriverDto: ApproveDriverDto,
  ) {
    return {
      message: 'Driver approval status updated',
      user: await this.adminService.approveDriver(
        userId,
        approveDriverDto.approved,
      ),
    };
  }

  /**
   * GET /admin/trips
   * Get paginated trips with filters
   */
  @Get('trips')
  @ApiOperation({ summary: 'Get paginated trips with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['active', 'hidden', 'completed', 'cancelled', 'expired'],
  })
  @ApiQuery({ name: 'driverId', required: false, type: String })
  @ApiResponse({
    status: 200,
    description: 'Trips retrieved successfully',
  })
  async getTrips(@Query() query: AdminTripQueryDto) {
    return this.adminService.getTrips(query);
  }

  /**
   * GET /admin/payments/pending
   * Get pending payments for approval queue
   */
  @Get('payments/pending')
  @ApiOperation({ summary: 'Get pending payments for approval queue' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({
    status: 200,
    description: 'Pending payments retrieved successfully',
  })
  async getPendingPayments(@Query() query: AdminPaymentQueryDto) {
    return this.adminService.getPendingPayments(query);
  }

  /**
   * GET /admin/payments
   * Get all payments with filters
   */
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
  @ApiResponse({
    status: 200,
    description: 'Payments retrieved successfully',
  })
  async getAllPayments(@Query() query: AdminPaymentQueryDto) {
    return this.adminService.getAllPayments(query);
  }

  /**
   * GET /admin/vehicles
   * Get paginated vehicles with filters
   */
  @Get('vehicles')
  @ApiOperation({ summary: 'Get paginated vehicles with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'isVerified', required: false, type: Boolean })
  @ApiQuery({ name: 'driverId', required: false, type: String })
  @ApiResponse({
    status: 200,
    description: 'Vehicles retrieved successfully',
  })
  async getVehicles(@Query() query: AdminVehicleQueryDto) {
    return this.adminService.getVehicles(query);
  }

  /**
   * PATCH /admin/vehicles/:id/verify
   * Verify or reject vehicle
   */
  @Patch('vehicles/:id/verify')
  @ApiOperation({ summary: 'Verify or reject vehicle' })
  @ApiParam({ name: 'id', description: 'Vehicle ID' })
  @ApiResponse({
    status: 200,
    description: 'Vehicle verification status updated successfully',
  })
  @ApiResponse({
    status: 404,
    description: 'Vehicle not found',
  })
  async verifyVehicle(
    @Param('id') vehicleId: string,
    @Body() verifyVehicleDto: VerifyVehicleDto,
  ) {
    return this.adminService.verifyVehicle(
      vehicleId,
      verifyVehicleDto.isVerified,
    );
  }

  /**
   * GET /admin/reports
   * Generate report (revenue, users, or trips)
   */
  @Get('reports')
  @ApiOperation({ summary: 'Generate report (revenue, users, or trips)' })
  @ApiQuery({
    name: 'type',
    required: true,
    enum: ['revenue', 'users', 'trips'],
  })
  @ApiQuery({ name: 'startDate', required: true, type: String })
  @ApiQuery({ name: 'endDate', required: true, type: String })
  @ApiResponse({
    status: 200,
    description: 'Report generated successfully',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean', example: true },
        data: {
          type: 'object',
          properties: {
            type: { type: 'string', example: 'revenue' },
            period: {
              type: 'object',
              properties: {
                start: { type: 'string', example: '2026-02-01' },
                end: { type: 'string', example: '2026-02-28' },
              },
            },
            summary: {
              type: 'object',
              properties: {
                total: { type: 'number', example: 50000 },
                count: { type: 'number', example: 150 },
              },
            },
            breakdown: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  date: { type: 'string', example: '2026-02-01' },
                  amount: { type: 'number', example: 5000 },
                  count: { type: 'number', example: 15 },
                },
              },
            },
          },
        },
      },
    },
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid date range',
  })
  async generateReport(@Query() query: ReportQueryDto) {
    return this.adminService.generateReport(query);
  }

  // ============= BOOKINGS MANAGEMENT =============

  /**
   * GET /admin/bookings
   * Get paginated bookings with filters
   */
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
  @ApiResponse({
    status: 200,
    description: 'Bookings retrieved successfully',
  })
  async getBookings(@Query() query: AdminBookingQueryDto) {
    return this.adminService.getBookings(query);
  }

  /**
   * PATCH /admin/bookings/:id/cancel
   * Cancel a booking as admin
   */
  @Patch('bookings/:id/cancel')
  @ApiOperation({ summary: 'Cancel a booking as admin' })
  @ApiParam({ name: 'id', description: 'Booking ID' })
  @ApiResponse({
    status: 200,
    description: 'Booking cancelled successfully',
  })
  @ApiResponse({ status: 404, description: 'Booking not found' })
  @ApiResponse({ status: 400, description: 'Cannot cancel this booking' })
  async cancelBooking(@Param('id') bookingId: string) {
    return this.adminService.cancelBooking(bookingId);
  }

  // ============= RATINGS MANAGEMENT =============

  /**
   * GET /admin/ratings
   * Get paginated ratings with filters
   */
  @Get('ratings')
  @ApiOperation({ summary: 'Get paginated ratings with filters' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'userId', required: false, type: String })
  @ApiQuery({ name: 'tripId', required: false, type: String })
  @ApiQuery({ name: 'minRating', required: false, type: Number })
  @ApiResponse({
    status: 200,
    description: 'Ratings retrieved successfully',
  })
  async getRatings(@Query() query: AdminRatingQueryDto) {
    return this.adminService.getRatings(query);
  }

  /**
   * DELETE /admin/ratings/:id
   * Delete a rating
   */
  @Delete('ratings/:id')
  @ApiOperation({ summary: 'Delete a rating' })
  @ApiParam({ name: 'id', description: 'Rating ID' })
  @ApiResponse({
    status: 200,
    description: 'Rating deleted successfully',
  })
  @ApiResponse({ status: 404, description: 'Rating not found' })
  async deleteRating(@Param('id') ratingId: string) {
    await this.adminService.deleteRating(ratingId);
    return { success: true, data: { message: 'Rating deleted' } };
  }

  // ============= NOTIFICATIONS MANAGEMENT =============

  /**
   * GET /admin/notifications
   * Get all notifications
   */
  @Get('notifications')
  @ApiOperation({ summary: 'Get all notifications' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'type', required: false, type: String })
  @ApiResponse({
    status: 200,
    description: 'Notifications retrieved successfully',
  })
  async getNotifications(@Query() query: AdminNotificationQueryDto) {
    return this.adminService.getNotifications(query);
  }

  /**
   * POST /admin/notifications/broadcast
   * Broadcast notification to users
   */
  @Post('notifications/broadcast')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Broadcast notification to users' })
  @ApiResponse({
    status: 200,
    description: 'Notification broadcast sent successfully',
  })
  async broadcastNotification(@Body() dto: BroadcastNotificationDto) {
    return this.adminService.broadcastNotification(dto);
  }

  // ============= CHAT MONITORING =============

  /**
   * GET /admin/chat/rooms
   * Get all chat rooms
   */
  @Get('chat/rooms')
  @ApiOperation({ summary: 'Get all chat rooms' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({
    status: 200,
    description: 'Chat rooms retrieved successfully',
  })
  async getChatRooms(@Query() query: AdminChatQueryDto) {
    return this.adminService.getChatRooms(query);
  }

  /**
   * GET /admin/chat/rooms/:id/messages
   * Get messages for a chat room
   */
  @Get('chat/rooms/:id/messages')
  @ApiOperation({ summary: 'Get messages for a chat room' })
  @ApiParam({ name: 'id', description: 'Chat room ID' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({
    status: 200,
    description: 'Messages retrieved successfully',
  })
  @ApiResponse({ status: 404, description: 'Chat room not found' })
  async getChatMessages(
    @Param('id') roomId: string,
    @Query() query: AdminChatQueryDto,
  ) {
    return this.adminService.getChatMessages(roomId, query);
  }
}
