import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { UserEntity } from '../../database/entities/user.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { WalletTransactionEntity } from '../../database/entities/wallet-transaction.entity';
import { WalletAccountEntity } from '../../database/entities/wallet-account.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { RatingEntity } from '../../database/entities/rating.entity';
import { NotificationEntity } from '../../database/entities/notification.entity';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import {
  PgUserRole,
  TripStatus,
  WalletAccountType,
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
import { WalletService } from '../wallet/wallet.service';

export interface AdminUsersQuery {
  page?: number;
  limit?: number;
  role?: PgUserRole;
  search?: string;
  isActive?: boolean;
  registeredWithinDays?: number;
  isConfirmed?: boolean;
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
  driverId?: string;
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

export interface AdminWalletsQuery {
  page?: number;
  limit?: number;
  accountType?: WalletAccountType;
  search?: string;
  minBalance?: number;
  maxBalance?: number;
  isActive?: boolean;
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
    @InjectRepository(WalletAccountEntity)
    private walletAccountRepo: Repository<WalletAccountEntity>,
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
    private walletService: WalletService,
  ) {}

  private readonly logger = new Logger(AdminDashboardService.name);

  async getPlatformPricingSettings(countryCode: string = 'JO') {
    let row = await this.communicationFeeRepo.findOne({
      where: { countryCode },
    });
    if (!row) {
      row = this.communicationFeeRepo.create({
        countryCode,
        feeAmount: 0,
        currency: 'JOD',
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
      pendingManualTopups,
      pendingVehicleVerifications,
    ] = await Promise.all([
      this.userRepo.count(),
      this.userRepo.count({ where: { role: PgUserRole.DRIVER } }),
      this.userRepo.count({ where: { role: PgUserRole.PASSENGER } }),
      this.tripRepo.count({ where: { status: TripStatus.ACTIVE } }),
      this.tripRepo.count({ where: { status: TripStatus.COMPLETED } }),
      this.getTotalRevenue(),
      this.getPendingPaymentsCount(),
      this.getPendingManualTopupsCount(),
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
      pendingManualTopups,
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

    await this.notificationsService.create({
      userId,
      type: 'account_verified',
      title: 'Account Verified',
      body: 'Your account has been verified by the administrator.',
      data: { isPhoneVerified: true, isEmailVerified: true, isActive: true },
    });

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
    if (approved && !user.photoUrl) {
      throw new BadRequestException(
        'Driver profile photo is required before approval',
      );
    }
    user.isDriverApproved = approved;
    await this.userRepo.save(user);

    await this.notificationsService.create({
      userId,
      type: approved ? 'driver_approved' : 'driver_rejected',
      title: approved ? 'تم قبول حسابك كسائق' : 'تم رفض طلب حسابك كسائق',
      body: approved
        ? 'تهانينا! تم قبول حسابك كسائق. يمكنك الآن إنشاء الرحلات.'
        : 'تم رفض طلب تسجيلك كسائق. يرجى التواصل مع الدعم لمزيد من المعلومات.',
      data: { approved },
    });

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
    if (query.registeredWithinDays != null && query.registeredWithinDays > 0) {
      const since = new Date(
        Date.now() - query.registeredWithinDays * 24 * 60 * 60 * 1000,
      );
      qb.andWhere('user.createdAt >= :since', { since });
    }
    if (query.isConfirmed !== undefined) {
      if (query.isConfirmed) {
        qb.andWhere(
          '(user.isPhoneVerified = true AND user.isEmailVerified = true)',
        );
      } else {
        qb.andWhere(
          '(user.isPhoneVerified = false OR user.isEmailVerified = false)',
        );
      }
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
  ): Promise<PaginatedResult<Record<string, unknown>>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.paymentRepo
        .createQueryBuilder('p')
        // Avoid SQL alias "user" — reserved in PostgreSQL and can break the join.
        .leftJoinAndSelect('p.user', 'payer')
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

      const [entities, total] = await qb.getManyAndCount();

      const missingUserIds = [
        ...new Set(
          entities
            .filter((p) => !p.user && typeof p.userId === 'string' && p.userId)
            .map((p) => p.userId as string),
        ),
      ];
      const payerById = new Map<string, UserEntity>();
      if (missingUserIds.length > 0) {
        const payers = await this.userRepo.find({
          where: { id: In(missingUserIds) },
        });
        for (const u of payers) {
          payerById.set(u.id, u);
        }
      }

      const data = entities.map((p) => {
        const payer =
          p.user ??
          (typeof p.userId === 'string' ? payerById.get(p.userId) : undefined);
        const userSummary = payer
          ? {
              _id: payer.id,
              name: payer.name,
              email: payer.email ?? '',
              phoneNumber: payer.phoneNumber ?? undefined,
            }
          : typeof p.userId === 'string'
            ? { _id: p.userId, name: 'User not found', email: '' }
            : p.userId;

        const trip = p.trip;
        const tripSummary = trip
          ? {
              _id: trip.id,
              id: trip.id,
              fromName: trip.fromName,
              toName: trip.toName,
              from: { name: trip.fromName },
              to: { name: trip.toName },
              departureTime: trip.departureTime,
            }
          : p.tripId;

        return {
          _id: p.id,
          id: p.id,
          userId: userSummary,
          tripId: tripSummary,
          bookingId: p.bookingId,
          amount: Number(p.amount),
          currency: p.currency,
          method: p.method,
          paymentType: p.paymentType,
          status: p.status,
          direction: p.direction,
          proofImageUrl: p.proofImageUrl,
          walletNumber: p.walletNumber,
          transactionId: p.transactionId,
          paymentGatewayRef: p.paymentGatewayRef,
          adminNote: p.adminNote,
          recipientAliasType: p.recipientAliasType,
          recipientAliasValue: p.recipientAliasValue,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
        };
      });

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
  ): Promise<PaginatedResult<Record<string, unknown>>> {
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
        .leftJoinAndSelect('b.user', 'passenger')
        .leftJoinAndSelect('b.trip', 'trip')
        .leftJoinAndSelect('b.seats', 'seats')
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
      if (query.driverId) {
        qb.andWhere('trip.driverId = :driverId', { driverId: query.driverId });
      }
      const [entities, total] = await qb.getManyAndCount();

      const missingPassengerIds = [
        ...new Set(
          entities
            .filter((b) => !b.user && typeof b.userId === 'string' && b.userId)
            .map((b) => b.userId as string),
        ),
      ];
      const passengerById = new Map<string, UserEntity>();
      if (missingPassengerIds.length > 0) {
        const passengers = await this.userRepo.find({
          where: { id: In(missingPassengerIds) },
        });
        for (const u of passengers) {
          passengerById.set(u.id, u);
        }
      }

      const data = entities.map((b) => {
        const passenger =
          b.user ??
          (typeof b.userId === 'string'
            ? passengerById.get(b.userId)
            : undefined);
        return {
        _id: b.id,
        id: b.id,
        status: b.status,
        seatNumber: null,
        seatCount: b.seatCount,
        totalAmount: Number(b.totalAmount ?? 0),
        seats: (b.seats ?? []).map((seat) => ({
          id: seat.id,
          bookingId: seat.bookingId,
          seatNumber: seat.seatNumber,
          displayName: seat.displayName,
          gender: seat.gender,
          isMainBooker: seat.isMainBooker,
          markedAbsentAt: seat.markedAbsentAt,
          createdAt: seat.createdAt,
        })),
        hasDriverPaidToContact: b.hasDriverPaidToContact,
        sharePhoneWithDriver: b.sharePhoneWithDriver,
        cancellationReason: b.cancellationReason,
        cancelledAt: b.cancelledAt,
        cancelledBy: b.cancelledBy,
        createdAt: b.createdAt,
        updatedAt: b.updatedAt,
        userId: passenger
          ? {
              _id: passenger.id,
              name: passenger.name,
              email: passenger.email ?? '',
              phoneNumber: passenger.phoneNumber ?? undefined,
            }
          : typeof b.userId === 'string'
            ? {
                _id: b.userId,
                name: 'User not found',
                email: '',
              }
            : b.userId,
        tripId: b.trip
          ? {
              _id: b.trip.id,
              id: b.trip.id,
              fromName: b.trip.fromName,
              toName: b.trip.toName,
              from: { name: b.trip.fromName },
              to: { name: b.trip.toName },
              departureTime: b.trip.departureTime,
              price: b.trip.price,
              currency: b.trip.currency,
              seatLayout: b.trip.seatLayout ?? undefined,
            }
          : b.tripId,
        };
      });
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
  ): Promise<PaginatedResult<Record<string, unknown>>> {
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
      const [entities, total] = await qb.getManyAndCount();

      const missingUserIds = new Set<string>();
      for (const r of entities) {
        if (!r.fromUser && typeof r.fromUserId === 'string') {
          missingUserIds.add(r.fromUserId);
        }
        if (!r.toUser && typeof r.toUserId === 'string') {
          missingUserIds.add(r.toUserId);
        }
      }
      const userById = new Map<string, UserEntity>();
      if (missingUserIds.size > 0) {
        const users = await this.userRepo.find({
          where: { id: In([...missingUserIds]) },
        });
        for (const u of users) {
          userById.set(u.id, u);
        }
      }

      const toUserSummary = (
        rel: UserEntity | undefined,
        rawId: string,
      ): Record<string, unknown> => {
        const u = rel ?? userById.get(rawId);
        if (u) {
          return {
            _id: u.id,
            name: u.name,
            email: u.email ?? '',
            phoneNumber: u.phoneNumber ?? undefined,
          };
        }
        return { _id: rawId, name: 'User not found', email: '' };
      };

      const data = entities.map((r) => {
        const trip = r.trip;
        return {
          _id: r.id,
          id: r.id,
          fromUserId: toUserSummary(r.fromUser, r.fromUserId),
          toUserId: toUserSummary(r.toUser, r.toUserId),
          tripId: trip
            ? {
                _id: trip.id,
                id: trip.id,
                fromName: trip.fromName,
                toName: trip.toName,
                from: { name: trip.fromName },
                to: { name: trip.toName },
                departureTime: trip.departureTime,
              }
            : r.tripId,
          rating: r.rating,
          comment: r.comment,
          userRole: r.userRole,
          ratedRole: r.ratedRole,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        };
      });

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
  ): Promise<PaginatedResult<Record<string, unknown>>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;
    try {
      const qb = this.notificationRepo
        .createQueryBuilder('n')
        .leftJoinAndSelect('n.user', 'notifUser')
        .orderBy('n.createdAt', 'DESC')
        .skip(skip)
        .take(limit);
      if (query.type) {
        qb.andWhere('n.type = :type', { type: query.type });
      }
      const [entities, total] = await qb.getManyAndCount();

      const missingIds = [
        ...new Set(
          entities
            .filter((n) => !n.user && typeof n.userId === 'string' && n.userId)
            .map((n) => n.userId as string),
        ),
      ];
      const userById = new Map<string, UserEntity>();
      if (missingIds.length > 0) {
        const users = await this.userRepo.find({
          where: { id: In(missingIds) },
        });
        for (const u of users) {
          userById.set(u.id, u);
        }
      }

      const data = entities.map((n) => {
        const u = n.user ?? userById.get(n.userId);
        const userSummary = u
          ? {
              _id: u.id,
              name: u.name,
              email: u.email ?? '',
              phoneNumber: u.phoneNumber ?? undefined,
            }
          : typeof n.userId === 'string'
            ? { _id: n.userId, name: 'User not found', email: '' }
            : n.userId;

        return {
          _id: n.id,
          id: n.id,
          userId: userSummary,
          type: n.type,
          title: n.title,
          body: n.body,
          channel: n.channel,
          isRead: n.isRead,
          data: n.data,
          expiresAt: n.expiresAt,
          createdAt: n.createdAt,
          updatedAt: n.updatedAt,
        };
      });

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
    tripId?: string;
  }): Promise<
    PaginatedResult<
      ChatRoomEntity & {
        passenger: { id: string; name: string; email: string | null } | null;
      }
    >
  > {
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
      if (query.tripId) {
        qb.andWhere('c.tripId = :tripId', { tripId: query.tripId });
      }
      const [rooms, total] = await qb.getManyAndCount();

      const passengerIds = Array.from(
        new Set(
          rooms
            .map((r) => r.passengerId)
            .filter((id): id is string => typeof id === 'string'),
        ),
      );
      const passengerById = new Map<
        string,
        { id: string; name: string; email: string | null }
      >();
      if (passengerIds.length > 0) {
        const users = await this.userRepo
          .createQueryBuilder('u')
          .select(['u.id', 'u.name', 'u.email'])
          .whereInIds(passengerIds)
          .getMany();
        for (const u of users) {
          passengerById.set(u.id, {
            id: u.id,
            name: u.name,
            email: u.email ?? null,
          });
        }
      }

      const data = rooms.map((r) => ({
        ...r,
        passenger: r.passengerId
          ? (passengerById.get(r.passengerId) ?? null)
          : null,
      }));

      return {
        data,
        meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
      };
    } catch {
      return { data: [], meta: { page, limit, total: 0, totalPages: 0 } };
    }
  }

  async getChatRoomMessages(
    roomId: string,
    query: { page?: number; limit?: number },
  ): Promise<PaginatedResult<MessageEntity>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(200, Math.max(1, query.limit ?? 50));
    const skip = (page - 1) * limit;

    const room = await this.chatRoomRepo.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('Chat room not found');
    }

    const [raw, total] = await this.messageRepo.findAndCount({
      where: { chatRoomId: roomId },
      order: { createdAt: 'ASC' },
      skip,
      take: limit,
    });

    return {
      data: raw,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
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

  async getWallets(
    query: AdminWalletsQuery,
  ): Promise<PaginatedResult<Record<string, unknown>>> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;

    const qb = this.walletAccountRepo
      .createQueryBuilder('wa')
      .leftJoinAndSelect('wa.user', 'walletUser')
      .select([
        'wa.id',
        'wa.userId',
        'wa.accountType',
        'wa.currency',
        'wa.balance',
        'wa.isActive',
        'wa.createdAt',
        'wa.updatedAt',
        'walletUser.id',
        'walletUser.name',
        'walletUser.email',
        'walletUser.phoneNumber',
        'walletUser.role',
      ])
      .orderBy('wa.updatedAt', 'DESC')
      .skip(skip)
      .take(limit);

    if (query.accountType) {
      qb.andWhere('wa.accountType = :accountType', {
        accountType: query.accountType,
      });
    }
    if (query.isActive !== undefined) {
      qb.andWhere('wa.isActive = :isActive', { isActive: query.isActive });
    }
    if (query.search?.trim()) {
      const term = `%${query.search.trim()}%`;
      qb.andWhere(
        '(walletUser.name ILIKE :term OR walletUser.email ILIKE :term OR walletUser.phoneNumber ILIKE :term)',
        { term },
      );
    }
    if (query.minBalance !== undefined) {
      qb.andWhere('CAST(wa.balance AS DECIMAL) >= :minBalance', {
        minBalance: query.minBalance,
      });
    }
    if (query.maxBalance !== undefined) {
      qb.andWhere('CAST(wa.balance AS DECIMAL) <= :maxBalance', {
        maxBalance: query.maxBalance,
      });
    }

    const [entities, total] = await qb.getManyAndCount();

    const missingOwnerIds = [
      ...new Set(
        entities
          .filter((wa) => !wa.user && typeof wa.userId === 'string' && wa.userId)
          .map((wa) => wa.userId as string),
      ),
    ];
    const ownerById = new Map<string, UserEntity>();
    if (missingOwnerIds.length > 0) {
      const owners = await this.userRepo.find({
        where: { id: In(missingOwnerIds) },
      });
      for (const u of owners) {
        ownerById.set(u.id, u);
      }
    }

    const data = entities.map((wa) => this.mapWalletToAdminDto(wa, ownerById));

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  private mapWalletToAdminDto(
    wa: WalletAccountEntity,
    ownerById: Map<string, UserEntity>,
  ): Record<string, unknown> {
    const owner =
      wa.user ??
      (typeof wa.userId === 'string' ? ownerById.get(wa.userId) : undefined);
    const userSummary = owner
      ? {
          _id: owner.id,
          name: owner.name,
          email: owner.email ?? '',
          phoneNumber: owner.phoneNumber ?? undefined,
        }
      : typeof wa.userId === 'string'
        ? { _id: wa.userId, name: 'User not found', email: '' }
        : wa.userId;

    return {
      id: wa.id,
      userId: userSummary,
      accountType: wa.accountType,
      currency: wa.currency,
      balance: String(wa.balance),
      isActive: wa.isActive,
      createdAt: wa.createdAt,
      updatedAt: wa.updatedAt,
    };
  }

  async getWalletById(walletId: string): Promise<Record<string, unknown>> {
    const wallet = await this.walletAccountRepo.findOne({
      where: { id: walletId },
      relations: ['user'],
    });
    if (!wallet) {
      throw new NotFoundException('Wallet account not found');
    }

    const ownerById = new Map<string, UserEntity>();
    if (!wallet.user && typeof wallet.userId === 'string') {
      const owner = await this.userRepo.findOne({
        where: { id: wallet.userId },
      });
      if (owner) {
        ownerById.set(owner.id, owner);
      }
    }

    return this.mapWalletToAdminDto(wallet, ownerById);
  }

  async getWalletTransactions(
    walletId: string,
    query: { page?: number; limit?: number },
  ): Promise<PaginatedResult<WalletTransactionEntity>> {
    const wallet = await this.walletAccountRepo.findOne({
      where: { id: walletId },
    });
    if (!wallet) {
      throw new NotFoundException('Wallet account not found');
    }

    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));
    const skip = (page - 1) * limit;

    const [data, total] = await this.walletTxRepo.findAndCount({
      where: { accountId: walletId },
      order: { createdAt: 'DESC' },
      skip,
      take: limit,
    });

    const mapped = data.map((tx) => ({
      ...tx,
      amount: Number(tx.amount),
    })) as (WalletTransactionEntity & { amount: number })[];

    return {
      data: mapped,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async adjustWalletBalance(
    walletId: string,
    params: {
      amount: number;
      note?: string;
      currency?: string;
      adminId: string;
    },
  ): Promise<Record<string, unknown>> {
    const wallet = await this.walletAccountRepo.findOne({
      where: { id: walletId },
      relations: ['user'],
    });
    if (!wallet) {
      throw new NotFoundException('Wallet account not found');
    }

    await this.walletService.adjustBalanceByAdmin({
      accountId: wallet.id,
      amount: params.amount,
      note: params.note,
      currency: params.currency ?? wallet.currency,
      adminId: params.adminId,
    });

    const refreshed = await this.walletAccountRepo.findOne({
      where: { id: walletId },
      relations: ['user'],
    });
    if (!refreshed) {
      throw new NotFoundException('Wallet account not found');
    }

    // ── Push notification to the wallet owner (credits only) ────────────────
    if (params.amount > 0) {
      const currency = refreshed.currency ?? 'JOD';
      const formatted = params.amount.toFixed(2);
      const newBalance = Number(refreshed.balance).toFixed(2);

      try {
        await this.notificationsService.create({
          userId: wallet.userId,
          type: 'wallet_credited',
          title: 'تم إضافة رصيد إلى محفظتك',
          body: `تمت إضافة ${formatted} ${currency} إلى محفظتك. رصيدك الحالي: ${newBalance} ${currency}.`,
          data: {
            walletId: refreshed.id,
            amount: formatted,
            newBalance,
            currency,
          },
        });
      } catch (err) {
        this.logger.warn(
          `Failed to send wallet_credited notification to user ${wallet.userId}: ${err?.message}`,
        );
      }
    }

    const ownerById = new Map<string, UserEntity>();
    if (!refreshed.user && typeof refreshed.userId === 'string') {
      const owner = await this.userRepo.findOne({
        where: { id: refreshed.userId },
      });
      if (owner) {
        ownerById.set(owner.id, owner);
      }
    }

    return this.mapWalletToAdminDto(refreshed, ownerById);
  }

  private async getPendingManualTopupsCount(): Promise<number> {
    try {
      return await this.paymentRepo.count({
        where: {
          status: 'pending',
          method: 'manual',
          paymentType: 'wallet_topup',
        },
      });
    } catch {
      return 0;
    }
  }
}
