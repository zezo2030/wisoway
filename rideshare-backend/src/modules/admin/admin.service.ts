import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { seedAdminUser } from './seeds/admin.seed';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument, UserRole } from '../users/schemas/user.schema';
import { Trip, TripDocument } from '../trips/schemas/trip.schema';
import { Payment, PaymentDocument } from '../payments/schemas/payment.schema';
import { Vehicle, VehicleDocument } from '../vehicles/schemas/vehicle.schema';
import { Booking, BookingDocument } from '../bookings/schemas/booking.schema';
import { Rating, RatingDocument } from '../ratings/schemas/rating.schema';
import { ChatRoom, ChatRoomDocument } from '../chat/schemas/chat-room.schema';
import { Message, MessageDocument } from '../chat/schemas/message.schema';
import {
  Notification,
  NotificationDocument,
} from '../notifications/schemas/notification.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
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
  DashboardStats,
  ReportResponse,
} from './dto/admin-query.dto';

@Injectable()
export class AdminService implements OnModuleInit {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Trip.name) private tripModel: Model<TripDocument>,
    @InjectModel(Payment.name) private paymentModel: Model<PaymentDocument>,
    @InjectModel(Vehicle.name) private vehicleModel: Model<VehicleDocument>,
    @InjectModel(Booking.name) private bookingModel: Model<BookingDocument>,
    @InjectModel(Rating.name) private ratingModel: Model<RatingDocument>,
    @InjectModel(ChatRoom.name)
    private chatRoomModel: Model<ChatRoomDocument>,
    @InjectModel(Message.name) private messageModel: Model<MessageDocument>,
    @InjectModel(Notification.name)
    private notificationModel: Model<NotificationDocument>,
    private notificationsService: NotificationsService,
  ) {}

  async onModuleInit() {
    this.logger.log('Checking for admin user...');
    try {
      const result = await seedAdminUser(this.userModel);
      this.logger.log(result.message);
    } catch (error) {
      this.logger.error('Failed to seed admin user', error.stack);
    }
  }

  /**
   * Get dashboard statistics
   */
  async getDashboardStats(): Promise<DashboardStats> {
    // Get user counts by role
    const userCounts = await this.userModel.aggregate([
      {
        $group: {
          _id: '$role',
          count: { $sum: 1 },
        },
      },
    ]);

    const userCountMap = userCounts.reduce(
      (acc, item) => {
        acc[item._id] = item.count;
        return acc;
      },
      {} as Record<string, number>,
    );

    // Get trip counts by status
    const tripCounts = await this.tripModel.aggregate([
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
        },
      },
    ]);

    const tripCountMap = tripCounts.reduce(
      (acc, item) => {
        acc[item._id] = item.count;
        return acc;
      },
      {} as Record<string, number>,
    );

    // Get total revenue from approved payments
    const revenueResult = await this.paymentModel.aggregate([
      {
        $match: { status: 'approved' },
      },
      {
        $group: {
          _id: null,
          total: { $sum: '$amount' },
        },
      },
    ]);

    const totalRevenue = revenueResult.length > 0 ? revenueResult[0].total : 0;

    // Get pending payments count
    const pendingPayments = await this.paymentModel.countDocuments({
      status: 'pending',
    });

    // Get pending vehicle verifications
    const pendingVehicleVerifications = await this.vehicleModel.countDocuments({
      isVerified: false,
    });

    return {
      totalUsers:
        (userCountMap['passenger'] || 0) +
        (userCountMap['driver'] || 0) +
        (userCountMap['admin'] || 0),
      totalDrivers: userCountMap['driver'] || 0,
      totalPassengers: userCountMap['passenger'] || 0,
      activeTrips: tripCountMap['active'] || 0,
      completedTrips: tripCountMap['completed'] || 0,
      totalRevenue,
      pendingPayments,
      pendingVehicleVerifications,
    };
  }

  /**
   * Get paginated users with filters
   */
  async getUsers(query: AdminUserQueryDto): Promise<PaginatedResult<User>> {
    const { page = 1, limit = 20, role, search, isActive } = query;
    const skip = (page - 1) * limit;

    const queryFilter: any = {};

    if (role) {
      queryFilter.role = role;
    }

    if (isActive !== undefined) {
      queryFilter.isActive = isActive;
    }

    if (search) {
      queryFilter.$or = [
        { name: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
      ];
    }

    const [data, total] = await Promise.all([
      this.userModel
        .find(queryFilter)
        .select('-passwordHash -refreshToken')
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.userModel.countDocuments(queryFilter).exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Change user role
   */
  async changeUserRole(userId: string, role: UserRole): Promise<User> {
    const user = await this.userModel.findById(userId).exec();
    if (!user) {
      throw new NotFoundException('User not found');
    }

    user.role = role;
    await user.save();

    // Notify user of role change
    await this.notificationsService.create({
      userId: userId,
      type: 'role_changed',
      title: 'Role Updated',
      body: `Your role has been changed to ${role}`,
      data: { newRole: role },
    });

    this.logger.log(`User ${userId} role changed to ${role}`);

    return user;
  }

  /**
   * Toggle user ban status
   */
  async toggleBan(userId: string, isActive: boolean): Promise<User> {
    const user = await this.userModel
      .findByIdAndUpdate(userId, { isActive }, { new: true })
      .select('-passwordHash -refreshToken')
      .exec();

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Notify user of ban/unban
    await this.notificationsService.create({
      userId: userId,
      type: isActive ? 'account_unbanned' : 'account_banned',
      title: isActive ? 'Account Unbanned' : 'Account Banned',
      body: isActive
        ? 'Your account has been unbanned. You can now use the platform.'
        : 'Your account has been banned. Please contact support for assistance.',
      data: { isActive },
    });

    this.logger.log(
      `User ${userId} ban status changed to isActive=${isActive}`,
    );

    return user;
  }

  /**
   * Confirm user account (activate + mark phone/email as verified)
   */
  async confirmUser(userId: string): Promise<User> {
    const user = await this.userModel
      .findByIdAndUpdate(
        userId,
        {
          isActive: true,
          isPhoneVerified: true,
          isEmailVerified: true,
        },
        { new: true },
      )
      .select('-passwordHash -refreshToken')
      .exec();

    if (!user) {
      throw new NotFoundException('User not found');
    }

    await this.notificationsService.create({
      userId,
      type: 'account_verified',
      title: 'Account Verified',
      body: 'Your account has been verified by the administrator.',
      data: { isPhoneVerified: true, isEmailVerified: true, isActive: true },
    });

    this.logger.log(`User ${userId} account confirmed by admin`);

    return user;
  }

  /**
   * Delete a user account
   */
  async deleteUser(userId: string): Promise<void> {
    const user = await this.userModel.findById(userId).exec();
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Keep at least one admin account in the system.
    if (user.role === UserRole.ADMIN) {
      throw new BadRequestException('Cannot delete admin users');
    }

    await this.userModel.findByIdAndDelete(userId).exec();
    this.logger.log(`User ${userId} deleted by admin`);
  }

  /**
   * Get paginated trips with filters
   */
  async getTrips(query: AdminTripQueryDto): Promise<PaginatedResult<Trip>> {
    const { page = 1, limit = 20, status, driverId } = query;
    const skip = (page - 1) * limit;

    const queryFilter: any = {};

    if (status) {
      queryFilter.status = status;
    }

    if (driverId) {
      queryFilter.driverId = driverId;
    }

    const [data, total] = await Promise.all([
      this.tripModel
        .find(queryFilter)
        .populate('driverId', 'name email phoneNumber')
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.tripModel.countDocuments(queryFilter).exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get pending payments (for admin approval queue)
   */
  async getPendingPayments(
    query: AdminPaymentQueryDto,
  ): Promise<PaginatedResult<Payment>> {
    const { page = 1, limit = 20 } = query;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.paymentModel
        .find({ status: 'pending' })
        .populate('userId', 'name email phoneNumber')
        .populate('tripId', 'from to departureTime')
        .populate('bookingId', 'seatNumber')
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.paymentModel.countDocuments({ status: 'pending' }).exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get all payments with filters
   */
  async getAllPayments(
    query: AdminPaymentQueryDto,
  ): Promise<PaginatedResult<Payment>> {
    const {
      page = 1,
      limit = 20,
      status,
      method,
      paymentType,
      walletOnly,
    } = query;
    const skip = (page - 1) * limit;

    const queryFilter: any = {};

    if (status) {
      queryFilter.status = status;
    }

    if (method) {
      queryFilter.method = method;
    }

    if (walletOnly) {
      queryFilter.paymentType = {
        $in: ['wallet_topup', 'wallet_trip_charge'],
      };
    } else if (paymentType) {
      queryFilter.paymentType = paymentType;
    }

    const [data, total] = await Promise.all([
      this.paymentModel
        .find(queryFilter)
        .populate('userId', 'name email phoneNumber')
        .populate('tripId', 'from to departureTime')
        .populate('bookingId', 'seatNumber')
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.paymentModel.countDocuments(queryFilter).exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get paginated vehicles with filters
   */
  async getVehicles(
    query: AdminVehicleQueryDto,
  ): Promise<PaginatedResult<Vehicle>> {
    const { page = 1, limit = 20, isVerified, driverId } = query;
    const skip = (page - 1) * limit;

    const queryFilter: any = {};

    if (isVerified !== undefined) {
      queryFilter.isVerified = isVerified;
    }

    if (driverId) {
      queryFilter.driverId = driverId;
    }

    const [data, total] = await Promise.all([
      this.vehicleModel
        .find(queryFilter)
        .populate('driverId', 'name email phoneNumber')
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.vehicleModel.countDocuments(queryFilter).exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Verify or reject vehicle
   */
  async verifyVehicle(
    vehicleId: string,
    isVerified: boolean,
  ): Promise<Vehicle> {
    const vehicle = await this.vehicleModel
      .findByIdAndUpdate(vehicleId, { isVerified }, { new: true })
      .populate('driverId', 'name email phoneNumber')
      .exec();

    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    // Notify driver of verification result
    await this.notificationsService.create({
      userId: (vehicle.driverId as any)._id.toString(),
      type: isVerified ? 'vehicle_verified' : 'vehicle_rejected',
      title: isVerified ? 'Vehicle Verified' : 'Vehicle Rejected',
      body: isVerified
        ? 'Your vehicle has been verified. You can now create trips.'
        : 'Your vehicle verification was rejected. Please check details and resubmit.',
      data: { vehicleId, isVerified },
    });

    this.logger.log(
      `Vehicle ${vehicleId} verification status changed to ${isVerified}`,
    );

    return vehicle;
  }

  /**
   * Approve or reject driver
   */
  async approveDriver(userId: string, approved: boolean): Promise<User> {
    const user = await this.userModel.findById(userId).exec();

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Validate user is a driver
    if (user.role !== UserRole.DRIVER) {
      throw new BadRequestException('User is not a driver');
    }

    // Update driver approval status
    user.isDriverApproved = approved;
    await user.save();

    // Notify driver of approval result
    await this.notificationsService.create({
      userId,
      type: approved ? 'driver_approved' : 'driver_rejected',
      title: approved ? 'Driver Approved' : 'Driver Rejected',
      body: approved
        ? 'Congratulations! Your driver account has been approved. You can now create trips.'
        : 'Your driver account has been rejected. Please contact support for more information.',
      data: { approved },
    });

    this.logger.log(`Driver ${userId} approval status changed to ${approved}`);

    return user;
  }

  /**
   * Generate report (revenue, users, or trips)
   */
  async generateReport(query: ReportQueryDto): Promise<ReportResponse> {
    const { type, startDate, endDate } = query;

    const start = new Date(startDate);
    const end = new Date(endDate);

    // Validate date range
    if (start > end) {
      throw new BadRequestException('Start date must be before end date');
    }

    // Set end date to end of day
    end.setHours(23, 59, 59, 999);

    let summary = { total: 0, count: 0 };
    let breakdown: Array<{ date: string; amount?: number; count: number }> = [];

    switch (type) {
      case 'revenue':
        const revenueData = await this.paymentModel.aggregate([
          {
            $match: {
              status: 'approved',
              createdAt: { $gte: start, $lte: end },
            },
          },
          {
            $group: {
              _id: {
                $dateToString: { format: '%Y-%m-%d', date: '$createdAt' },
              },
              amount: { $sum: '$amount' },
              count: { $sum: 1 },
            },
          },
          {
            $sort: { _id: 1 },
          },
        ]);

        summary = revenueData.reduce(
          (acc, item) => {
            acc.total += item.amount;
            acc.count += item.count;
            return acc;
          },
          { total: 0, count: 0 },
        );

        breakdown = revenueData.map((item) => ({
          date: item._id,
          amount: item.amount,
          count: item.count,
        }));
        break;

      case 'users':
        const userData = await this.userModel.aggregate([
          {
            $match: {
              createdAt: { $gte: start, $lte: end },
            },
          },
          {
            $group: {
              _id: {
                $dateToString: { format: '%Y-%m-%d', date: '$createdAt' },
              },
              count: { $sum: 1 },
            },
          },
          {
            $sort: { _id: 1 },
          },
        ]);

        summary = userData.reduce(
          (acc, item) => {
            acc.count += item.count;
            return acc;
          },
          { total: 0, count: 0 },
        );

        breakdown = userData.map((item) => ({
          date: item._id,
          count: item.count,
        }));
        break;

      case 'trips':
        const tripData = await this.tripModel.aggregate([
          {
            $match: {
              createdAt: { $gte: start, $lte: end },
            },
          },
          {
            $group: {
              _id: {
                $dateToString: { format: '%Y-%m-%d', date: '$createdAt' },
              },
              count: { $sum: 1 },
            },
          },
          {
            $sort: { _id: 1 },
          },
        ]);

        summary = tripData.reduce(
          (acc, item) => {
            acc.count += item.count;
            return acc;
          },
          { total: 0, count: 0 },
        );

        breakdown = tripData.map((item) => ({
          date: item._id,
          count: item.count,
        }));
        break;
    }

    return {
      type,
      period: {
        start: startDate,
        end: endDate,
      },
      summary,
      breakdown,
    };
  }

  // ============= BOOKINGS MANAGEMENT =============

  /**
   * Get paginated bookings with filters
   */
  async getBookings(
    query: AdminBookingQueryDto,
  ): Promise<PaginatedResult<Booking>> {
    const { page = 1, limit = 20, status, userId, tripId } = query;
    const skip = (page - 1) * limit;

    const queryFilter: any = {};

    if (status) {
      queryFilter.status = status;
    }

    if (userId) {
      queryFilter.userId = userId;
    }

    if (tripId) {
      queryFilter.tripId = tripId;
    }

    const [data, total] = await Promise.all([
      this.bookingModel
        .find(queryFilter)
        .populate('userId', 'name email phoneNumber')
        .populate('tripId', 'from to departureTime price')
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.bookingModel.countDocuments(queryFilter).exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Cancel a booking as admin
   */
  async cancelBooking(bookingId: string): Promise<Booking> {
    const booking = await this.bookingModel.findById(bookingId).exec();

    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    if (booking.status === 'cancelled' || booking.status === 'completed') {
      throw new BadRequestException(
        `Cannot cancel a ${booking.status} booking`,
      );
    }

    booking.status = 'cancelled' as any;
    booking.cancellationReason = 'Cancelled by admin';
    booking.cancelledAt = new Date() as any;
    booking.cancelledBy = 'system' as any;
    await booking.save();

    // Notify user
    await this.notificationsService.create({
      userId: booking.userId.toString(),
      type: 'booking_cancelled',
      title: 'Booking Cancelled',
      body: 'Your booking has been cancelled by the administrator.',
      data: { bookingId },
    });

    this.logger.log(`Booking ${bookingId} cancelled by admin`);

    return booking;
  }

  // ============= RATINGS MANAGEMENT =============

  /**
   * Get paginated ratings with filters
   */
  async getRatings(
    query: AdminRatingQueryDto,
  ): Promise<PaginatedResult<Rating>> {
    const { page = 1, limit = 20, userId, tripId, minRating } = query;
    const skip = (page - 1) * limit;

    const queryFilter: any = {};

    if (userId) {
      queryFilter.$or = [{ fromUserId: userId }, { toUserId: userId }];
    }

    if (tripId) {
      queryFilter.tripId = tripId;
    }

    if (minRating) {
      queryFilter.rating = { $gte: minRating };
    }

    const [data, total] = await Promise.all([
      this.ratingModel
        .find(queryFilter)
        .populate('fromUserId', 'name email')
        .populate('toUserId', 'name email')
        .populate('tripId', 'from to departureTime')
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.ratingModel.countDocuments(queryFilter).exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Delete a rating
   */
  async deleteRating(ratingId: string): Promise<void> {
    const rating = await this.ratingModel.findById(ratingId).exec();

    if (!rating) {
      throw new NotFoundException('Rating not found');
    }

    await this.ratingModel.deleteOne({ _id: ratingId });

    this.logger.log(`Rating ${ratingId} deleted by admin`);
  }

  // ============= NOTIFICATIONS MANAGEMENT =============

  /**
   * Get all notifications (admin view)
   */
  async getNotifications(
    query: AdminNotificationQueryDto,
  ): Promise<PaginatedResult<Notification>> {
    const { page = 1, limit = 20, type } = query;
    const skip = (page - 1) * limit;

    const queryFilter: any = {};

    if (type) {
      queryFilter.type = type;
    }

    const [data, total] = await Promise.all([
      this.notificationModel
        .find(queryFilter)
        .populate('userId', 'name email')
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.notificationModel.countDocuments(queryFilter).exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Broadcast notification to users
   */
  async broadcastNotification(
    dto: BroadcastNotificationDto,
  ): Promise<{ sent: number }> {
    const { title, body, targetRole } = dto;

    const userFilter: any = { isActive: true };
    if (targetRole) {
      userFilter.role = targetRole;
    }

    const users = await this.userModel.find(userFilter).select('_id').exec();

    let sent = 0;
    for (const user of users) {
      try {
        await this.notificationsService.create({
          userId: user._id.toString(),
          type: 'admin_broadcast',
          title,
          body,
          data: { broadcast: true, targetRole: targetRole || 'all' },
        });
        sent++;
      } catch (error) {
        this.logger.error(
          `Failed to send notification to user ${user._id}: ${error.message}`,
        );
      }
    }

    this.logger.log(
      `Broadcast notification sent to ${sent} users (target: ${targetRole || 'all'})`,
    );

    return { sent };
  }

  // ============= CHAT MONITORING =============

  /**
   * Get all chat rooms (admin view)
   */
  async getChatRooms(
    query: AdminChatQueryDto,
  ): Promise<PaginatedResult<ChatRoom>> {
    const { page = 1, limit = 20 } = query;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.chatRoomModel
        .find()
        .populate('tripId', 'from to departureTime driverName')
        .populate('participants.userId', 'name email')
        .skip(skip)
        .limit(limit)
        .sort({ lastMessageTime: -1 })
        .exec(),
      this.chatRoomModel.countDocuments().exec(),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Get messages for a chat room (admin view - no participant check)
   */
  async getChatMessages(
    roomId: string,
    query: { page?: number; limit?: number },
  ): Promise<PaginatedResult<Message>> {
    const { page = 1, limit = 50 } = query;
    const skip = (page - 1) * limit;

    const room = await this.chatRoomModel.findById(roomId).exec();
    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    const [data, total] = await Promise.all([
      this.messageModel
        .find({ chatRoomId: new Types.ObjectId(roomId) })
        .skip(skip)
        .limit(limit)
        .sort({ createdAt: -1 })
        .exec(),
      this.messageModel
        .countDocuments({ chatRoomId: new Types.ObjectId(roomId) })
        .exec(),
    ]);

    return {
      data: data.reverse(),
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
