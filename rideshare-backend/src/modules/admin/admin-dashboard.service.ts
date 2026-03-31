import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserEntity } from '../../database/entities/user.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { WalletTransactionEntity } from '../../database/entities/wallet-transaction.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { RatingEntity } from '../../database/entities/rating.entity';
import { NotificationEntity } from '../../database/entities/notification.entity';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import {
  PgUserRole,
  TripStatus,
  WalletTransactionType,
  WalletTransactionStatus,
} from '../../database/entities/shared.enums';
import type {
  DashboardStats,
  ReportResponse,
  BroadcastNotificationDto,
} from './dto/admin-query.dto';
import type { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingsService } from '../bookings/bookings.service';
import { AdminPatchPricingSettingsDto } from './dto/admin-pricing-settings.dto';

export interface AdminUsersQuery {
  page?: number;
  limit?: number;
  role?: PgUserRole;
  search?: string;
  isActive?: boolean;
}

export interface AdminPaymentsQuery {
  page?: number;
  limit?: number;
  status?: string;
  method?: string;
  paymentType?: string;
  walletOnly?: boolean;
}

export interface AdminVehiclesQuery {
  page?: number;
  limit?: number;
  isVerified?: boolean;
  driverId?: string;
}

export interface AdminTripsQuery {
  page?: number;
  limit?: number;
  status?: string;
  driverId?: string;
}

export interface AdminBookingsQuery {
  page?: number;
  limit?: number;
  status?: string;
  userId?: string;
  tripId?: string;
}

export interface AdminRatingsQuery {
  page?: number;
  limit?: number;
  userId?: string;
  tripId?: string;
  minRating?: number;
}

export interface AdminNotificationsQuery {
  page?: number;
  limit?: number;
  type?: string;
}

export interface AdminReportsQuery {
  type: 'revenue' | 'users' | 'trips';
  startDate: string;
  endDate: string;
}

@Injectable()
export class AdminDashboardService {
  constructor(
    @InjectRepository(UserEntity)
    private userRepo: Repository<UserEntity>,
    @InjectRepository(TripEntity)
    private tripRepo: Repository<TripEntity>,
    @InjectRepository(VehicleEntity)
    private vehicleRepo: Repository<VehicleEntity>,
    @InjectRepository(PaymentEntity)
    private paymentRepo: Repository<PaymentEntity>,
    @InjectRepository(WalletTransactionEntity)
    private walletTxRepo: Repository<WalletTransactionEntity>,
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(RatingEntity)
    private ratingRepo: Repository<RatingEntity>,
    @InjectRepository(NotificationEntity)
    private notificationRepo: Repository<NotificationEntity>,
    @InjectRepository(ChatRoomEntity)
    private chatRoomRepo: Repository<ChatRoomEntity>,
    @InjectRepository(MessageEntity)
    private messageRepo: Repository<MessageEntity>,
    @InjectRepository(CommunicationFeeEntity)
    private communicationFeeRepo: Repository<CommunicationFeeEntity>,
    private notificationsService: NotificationsService,
    private bookingsService: BookingsService,
  ) {}

  private readonly logger = new Logger(AdminDashboardService.name);

  async getPlatformPricingSettings(countryCode: string = 'EG') {
    let row = await this.communicationFeeRepo.findOne({
      where: { countryCode },
    });
    if (!row) {
      row = this.communicationFeeRepo.create({
        countryCode,
        feeAmount: 0,
        currency: 'EGP',
        isActive: true,
        passengerPlatformPercent: 0,
        driverUnlockPercent: 0,
        lifetimeFreeTripEnabled: true,
      });
      await this.communicationFeeRepo.save(row);
    }
    return row;
  }

  async patchPlatformPricingSettings(
    countryCode: string,
    dto: AdminPatchPricingSettingsDto,
  ): Promise<CommunicationFeeEntity> {
    const row = await this.getPlatformPricingSettings(countryCode);
    if (dto.feeAmount !== undefined) row.feeAmount = dto.feeAmount;
    if (dto.currency !== undefined) row.currency = dto.currency;
    if (dto.isActive !== undefined) row.isActive = dto.isActive;
    if (dto.passengerPlatformPercent !== undefined) {
      row.passengerPlatformPercent = dto.passengerPlatformPercent;
    }
    if (dto.driverUnlockPercent !== undefined) {
      row.driverUnlockPercent = dto.driverUnlockPercent;
    }
    if (dto.lifetimeFreeTripEnabled !== undefined) {
      row.lifetimeFreeTripEnabled = dto.lifetimeFreeTripEnabled;
    }
    return this.communicationFeeRepo.save(row);
  }

  async getDashboardStats(): Promise<DashboardStats> {
    const [
      totalUsers,
      totalDrivers,
      totalPassengers,
      activeTrips,
      completedTrips,
      totalRevenue,
      pendingPayments,
      pendingVehicleVerifications,
    ] = await Promise.all([
      this.userRepo.count(),
      this.userRepo.count({ where: { role: PgUserRole.DRIVER } }),
      this.userRepo.count({ where: { role: PgUserRole.PASSENGER } }),
      this.tripRepo.count({ where: { status: TripStatus.ACTIVE } }),
      this.tripRepo.count({ where: { status: TripStatus.COMPLETED } }),
      this.getTotalRevenue(),
      this.getPendingPaymentsCount(),
      this.getPendingVehicleVerificationsCount(),
    ]);

    return {
      totalUsers,
      totalDrivers,
      totalPassengers,
      activeTrips,
      completedTrips,
      totalRevenue,
      pendingPayments,
      pendingVehicleVerifications,
    };
  }

  /**
   * Confirm user account (activate + mark phone/email as verified)
   */
  async confirmUser(userId: string): Promise<UserEntity> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    user.isActive = true;
    user.isPhoneVerified = true;
    user.isEmailVerified = true;
    await this.userRepo.save(user);

    const notification = this.notificationRepo.create({
      userId,
      type: 'account_verified',
      title: 'Account Verified',
      body: 'Your account has been verified by the administrator.',
      data: { isPhoneVerified: true, isEmailVerified: true, isActive: true },
    });
    await this.notificationRepo.save(notification);

    return user;
  }

  /**
   * Approve or reject a driver
   */
  async approveDriver(userId: string, approved: boolean): Promise<UserEntity> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (user.role !== PgUserRole.DRIVER) {
      throw new BadRequestException('User is not a driver');
    }
    user.isDriverApproved = approved;
    await this.userRepo.save(user);

    const notification = this.notificationRepo.create({
      userId,
      type: approved ? 'driver_approved' : 'driver_rejected',
      title: approved ? 'Driver Approved' : 'Driver Rejected',
      body: approved
        ? 'Congratulations! Your driver account has been approved. You can now create trips.'
        : 'Your driver account application has been rejected.',
      data: { approved },
    });
    await this.notificationRepo.save(notification);

    return user;
  }

  /**
   * Delete a user account
   */
  async deleteUser(userId: string): Promise<void> {
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (
      !userId ||
      userId === 'undefined' ||
      userId === 'null' ||
      !uuidRegex.test(userId)
    ) {
      throw new BadRequestException('Invalid user ID');
    }
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (user.role === PgUserRole.ADMIN) {
      throw new BadRequestException('Cannot delete admin users');
    }
    await this.userRepo.remove(user);
  }

  async getUsers(query: AdminUsersQuery): Promise<PaginatedResult<UserEntity>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;

    const qb = this.userRepo
      .createQueryBuilder('user')
      .select([
        'user.id',
        'user.email',
        'user.phoneNumber',
        'user.name',
        'user.role',
        'user.isActive',
        'user.rating',
        'user.totalRatings',
        'user.isPhoneVerified',
        'user.isEmailVerified',
        'user.isDriverApproved',
        'user.provider',
        'user.walletBalance',
        'user.walletCurrency',
        'user.createdAt',
        'user.updatedAt',
      ])
      .orderBy('user.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    if (query.role) {
      qb.andWhere('user.role = :role', { role: query.role });
    }
    if (query.isActive !== undefined) {
      qb.andWhere('user.isActive = :isActive', { isActive: query.isActive });
    }
    if (query.search?.trim()) {
      const term = `%${query.search.trim()}%`;
      qb.andWhere(
        '(user.name ILIKE :term OR user.email ILIKE :term OR user.phoneNumber ILIKE :term)',
        { term },
      );
    }

    const [data, total] = await qb.getManyAndCount();

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

  async getPayments(
    query: AdminPaymentsQuery,
  ): Promise<PaginatedResult<PaymentEntity>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.paymentRepo
        .createQueryBuilder('p')
        .leftJoinAndSelect('p.user', 'user')
        .leftJoinAndSelect('p.trip', 'trip')
        .orderBy('p.createdAt', 'DESC')
        .skip(skip)
        .take(limit);

      if (query.status) {
        qb.andWhere('p.status = :status', { status: query.status });
      }
      if (query.method) {
        qb.andWhere('p.method = :method', { method: query.method });
      }
      if (query.walletOnly) {
        qb.andWhere('p.paymentType IN (:...types)', {
          types: ['wallet_topup', 'wallet_trip_charge'],
        });
      } else if (query.paymentType) {
        qb.andWhere('p.paymentType = :paymentType', {
          paymentType: query.paymentType,
        });
      }

      const [data, total] = await qb.getManyAndCount();
      return {
        data,
        meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
      };
    } catch {
      return {
        data: [],
        meta: { page, limit, total: 0, totalPages: 0 },
      };
    }
  }

  async getPendingPayments(
    query: AdminPaymentsQuery,
  ): Promise<PaginatedResult<PaymentEntity>> {
    return this.getPayments({ ...query, status: 'pending' });
  }

  async getVehicles(
    query: AdminVehiclesQuery,
  ): Promise<PaginatedResult<VehicleEntity>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.vehicleRepo
        .createQueryBuilder('v')
        .leftJoinAndSelect('v.driver', 'driver')
        .orderBy('v.createdAt', 'DESC')
        .skip(skip)
        .take(limit);

      if (query.isVerified !== undefined) {
        qb.andWhere('v.isVerified = :isVerified', {
          isVerified: query.isVerified,
        });
      }

      if (query.driverId) {
        qb.andWhere('v.driverId = :driverId', {
          driverId: query.driverId,
        });
      }

      const [data, total] = await qb.getManyAndCount();
      return {
        data,
        meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
      };
    } catch {
      return {
        data: [],
        meta: { page, limit, total: 0, totalPages: 0 },
      };
    }
  }

  async verifyVehicle(
    vehicleId: string,
    isVerified: boolean,
  ): Promise<VehicleEntity> {
    const vehicle = await this.vehicleRepo.findOne({
      where: { id: vehicleId },
      relations: ['driver'],
    });
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }

    vehicle.isVerified = isVerified;
    const saved = await this.vehicleRepo.save(vehicle);

    await this.notificationsService.create({
      userId: vehicle.driverId,
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

    return saved;
  }

  async getTrips(query: AdminTripsQuery): Promise<PaginatedResult<TripEntity>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.tripRepo
        .createQueryBuilder('t')
        .leftJoinAndSelect('t.driver', 'driver')
        .orderBy('t.createdAt', 'DESC')
        .skip(skip)
        .take(limit);
      if (query.status) {
        qb.andWhere('t.status = :status', { status: query.status });
      }
      if (query.driverId) {
        qb.andWhere('t.driverId = :driverId', { driverId: query.driverId });
      }
      const [data, total] = await qb.getManyAndCount();
      return {
        data,
        meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
      };
    } catch {
      return { data: [], meta: { page, limit, total: 0, totalPages: 0 } };
    }
  }

  async getBookings(
    query: AdminBookingsQuery,
  ): Promise<PaginatedResult<Record<string, unknown>>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.bookingRepo
        .createQueryBuilder('b')
        .leftJoinAndSelect('b.user', 'user')
        .leftJoinAndSelect('b.trip', 'trip')
        .orderBy('b.createdAt', 'DESC')
        .skip(skip)
        .take(limit);
      if (query.status) {
        qb.andWhere('b.status = :status', { status: query.status });
      }
      if (query.userId) {
        qb.andWhere('b.userId = :userId', { userId: query.userId });
      }
      if (query.tripId) {
        qb.andWhere('b.tripId = :tripId', { tripId: query.tripId });
      }
      const [entities, total] = await qb.getManyAndCount();
      const data = entities.map((b) => ({
        _id: b.id,
        id: b.id,
        seatNumber: b.seatNumber,
        status: b.status,
        hasDriverPaidToContact: b.hasDriverPaidToContact,
        sharePhoneWithDriver: b.sharePhoneWithDriver,
        cancellationReason: b.cancellationReason,
        cancelledAt: b.cancelledAt,
        cancelledBy: b.cancelledBy,
        createdAt: b.createdAt,
        updatedAt: b.updatedAt,
        userId: b.user
          ? {
              _id: b.user.id,
              name: b.user.name,
              email: b.user.email ?? '',
              phoneNumber: b.user.phoneNumber ?? undefined,
            }
          : b.userId,
        tripId: b.trip
          ? {
              _id: b.trip.id,
              fromName: b.trip.fromName,
              toName: b.trip.toName,
              from: { name: b.trip.fromName },
              to: { name: b.trip.toName },
              departureTime: b.trip.departureTime,
              seatLayout: b.trip.seatLayout ?? undefined,
            }
          : b.tripId,
      }));
      return {
        data,
        meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
      };
    } catch {
      return { data: [], meta: { page, limit, total: 0, totalPages: 0 } };
    }
  }

  async cancelBooking(bookingId: string): Promise<BookingEntity> {
    return this.bookingsService.cancelAsAdmin(bookingId);
  }

  async getRatings(
    query: AdminRatingsQuery,
  ): Promise<PaginatedResult<RatingEntity>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.ratingRepo
        .createQueryBuilder('r')
        .leftJoinAndSelect('r.fromUser', 'fromUser')
        .leftJoinAndSelect('r.toUser', 'toUser')
        .leftJoinAndSelect('r.trip', 'trip')
        .orderBy('r.createdAt', 'DESC')
        .skip(skip)
        .take(limit);
      if (query.userId) {
        qb.andWhere('(r.fromUserId = :userId OR r.toUserId = :userId)', {
          userId: query.userId,
        });
      }
      if (query.tripId) {
        qb.andWhere('r.tripId = :tripId', { tripId: query.tripId });
      }
      if (query.minRating != null) {
        qb.andWhere('r.rating >= :minRating', { minRating: query.minRating });
      }
      const [data, total] = await qb.getManyAndCount();
      return {
        data,
        meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
      };
    } catch {
      return { data: [], meta: { page, limit, total: 0, totalPages: 0 } };
    }
  }

  async getNotifications(
    query: AdminNotificationsQuery,
  ): Promise<PaginatedResult<NotificationEntity>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.notificationRepo
        .createQueryBuilder('n')
        .leftJoinAndSelect('n.user', 'user')
        .orderBy('n.createdAt', 'DESC')
        .skip(skip)
        .take(limit);
      if (query.type) {
        qb.andWhere('n.type = :type', { type: query.type });
      }
      const [data, total] = await qb.getManyAndCount();
      return {
        data,
        meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
      };
    } catch {
      return { data: [], meta: { page, limit, total: 0, totalPages: 0 } };
    }
  }

  async broadcastNotification(
    dto: BroadcastNotificationDto,
  ): Promise<{ sent: number }> {
    const { title, body, targetRole } = dto;

    const qb = this.userRepo
      .createQueryBuilder('u')
      .select('u.id')
      .where('u.isActive = :active', { active: true });
    if (targetRole) {
      qb.andWhere('u.role = :role', { role: targetRole });
    }
    const users = await qb.getMany();

    let sent = 0;
    for (const user of users) {
      try {
        await this.notificationsService.create({
          userId: user.id,
          type: 'admin_broadcast',
          title,
          body,
          data: { broadcast: true, targetRole: targetRole ?? 'all' },
        });
        sent++;
      } catch (error) {
        this.logger.error(
          `Failed to send notification to user ${user.id}: ${(error as Error).message}`,
        );
      }
    }

    this.logger.log(
      `Broadcast notification sent to ${sent} users (target: ${targetRole ?? 'all'})`,
    );

    return { sent };
  }

  async getChatRooms(query: {
    page?: number;
    limit?: number;
  }): Promise<PaginatedResult<ChatRoomEntity>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.chatRoomRepo
        .createQueryBuilder('c')
        .leftJoinAndSelect('c.trip', 'trip')
        .orderBy('c.lastMessageTime', 'DESC', 'NULLS LAST')
        .addOrderBy('c.createdAt', 'DESC')
        .skip(skip)
        .take(limit);
      const [data, total] = await qb.getManyAndCount();
      return {
        data,
        meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
      };
    } catch {
      return { data: [], meta: { page, limit, total: 0, totalPages: 0 } };
    }
  }

  async generateReport(query: AdminReportsQuery): Promise<ReportResponse> {
    const start = new Date(query.startDate);
    const end = new Date(query.endDate);
    end.setHours(23, 59, 59, 999);
    const emptyReport: ReportResponse = {
      type: query.type,
      period: { start: query.startDate, end: query.endDate },
      summary: { total: 0, count: 0 },
      breakdown: [],
    };
    try {
      if (query.type === 'revenue') {
        const rows = await this.walletTxRepo
          .createQueryBuilder('wt')
          .select('DATE(wt."createdAt")', 'date')
          .addSelect('SUM(CAST(wt.amount AS DECIMAL))', 'amount')
          .addSelect('COUNT(*)', 'count')
          .where('wt.type = :type', {
            type: WalletTransactionType.TRIP_PAYMENT,
          })
          .andWhere('wt.status = :status', {
            status: WalletTransactionStatus.POSTED,
          })
          .andWhere('wt.createdAt >= :start', { start })
          .andWhere('wt.createdAt <= :end', { end })
          .groupBy('DATE(wt."createdAt")')
          .orderBy('DATE(wt."createdAt")', 'ASC')
          .getRawMany<{ date: string; amount: string; count: string }>();
        const breakdown = rows.map((r) => ({
          date: r.date,
          amount: Number(r.amount),
          count: Number(r.count),
        }));
        const total = breakdown.reduce((s, r) => s + (r.amount ?? 0), 0);
        const count = breakdown.reduce((s, r) => s + r.count, 0);
        return {
          type: 'revenue',
          period: { start: query.startDate, end: query.endDate },
          summary: { total, count },
          breakdown,
        };
      }
      if (query.type === 'users') {
        const rows = await this.userRepo
          .createQueryBuilder('u')
          .select('DATE(u."createdAt")', 'date')
          .addSelect('COUNT(*)', 'count')
          .where('u.createdAt >= :start', { start })
          .andWhere('u.createdAt <= :end', { end })
          .groupBy('DATE(u."createdAt")')
          .orderBy('DATE(u."createdAt")', 'ASC')
          .getRawMany<{ date: string; count: string }>();
        const breakdown = rows.map((r) => ({
          date: r.date,
          count: Number(r.count),
        }));
        const count = breakdown.reduce((s, r) => s + r.count, 0);
        return {
          type: 'users',
          period: { start: query.startDate, end: query.endDate },
          summary: { total: count, count },
          breakdown,
        };
      }
      if (query.type === 'trips') {
        const rows = await this.tripRepo
          .createQueryBuilder('t')
          .select('DATE(t."createdAt")', 'date')
          .addSelect('COUNT(*)', 'count')
          .where('t.createdAt >= :start', { start })
          .andWhere('t.createdAt <= :end', { end })
          .groupBy('DATE(t."createdAt")')
          .orderBy('DATE(t."createdAt")', 'ASC')
          .getRawMany<{ date: string; count: string }>();
        const breakdown = rows.map((r) => ({
          date: r.date,
          count: Number(r.count),
        }));
        const count = breakdown.reduce((s, r) => s + r.count, 0);
        return {
          type: 'trips',
          period: { start: query.startDate, end: query.endDate },
          summary: { total: count, count },
          breakdown,
        };
      }
      return emptyReport;
    } catch {
      return emptyReport;
    }
  }

  private async getTotalRevenue(): Promise<number> {
    try {
      const result = await this.walletTxRepo
        .createQueryBuilder('wt')
        .select('COALESCE(SUM(CAST(wt.amount AS DECIMAL)), 0)', 'total')
        .where('wt.type = :type', {
          type: WalletTransactionType.TRIP_PAYMENT,
        })
        .andWhere('wt.status = :status', {
          status: WalletTransactionStatus.POSTED,
        })
        .getRawOne<{ total: string }>();
      return Number(result?.total ?? 0);
    } catch {
      return 0;
    }
  }

  private async getPendingPaymentsCount(): Promise<number> {
    try {
      return await this.paymentRepo.count({ where: { status: 'pending' } });
    } catch {
      return 0;
    }
  }

  private async getPendingVehicleVerificationsCount(): Promise<number> {
    try {
      return await this.vehicleRepo.count({ where: { isVerified: false } });
    } catch {
      return 0;
    }
  }
}
