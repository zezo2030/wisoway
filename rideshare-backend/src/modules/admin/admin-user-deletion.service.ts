import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, EntityManager, In, MoreThan, Not } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
  ChatRoomEntity,
  InstantRideRequestEntity,
  InstantRequestStatus,
  MessageEntity,
  OtpCodeEntity,
  PasswordResetSessionEntity,
  PaymentEntity,
  PayoutRequestEntity,
  PayoutStatus,
  PendingRegistrationEntity,
  PgUserRole,
  RatingEntity,
  SecurityEventEntity,
  TripEntity,
  TripShareLinkEntity,
  TripStatus,
  UserEntity,
  VehicleEntity,
  WalletAccountEntity,
} from '../../database/entities';
import {
  PRIVATE_DOCUMENT_PREFIX,
  PrivateDocumentsService,
} from '../uploads/private-documents.service';
import { UploadsService } from '../uploads/uploads.service';

/** Each one leaves someone waiting on a ride or on money. */
export type UserDeletionBlocker =
  | 'ACTIVE_TRIP'
  | 'ACTIVE_BOOKING'
  | 'INSTANT_SEARCH'
  | 'WALLET_NOT_EMPTY'
  | 'OPEN_PAYOUT'
  | 'RECENT_PAYMENT';

export interface UserDeletionPreview {
  blockers: UserDeletionBlocker[];
  /** What goes with the account. */
  counts: {
    trips: number;
    otherPassengersBookings: number;
    bookings: number;
    payments: number;
    messages: number;
    ratings: number;
  };
}

const LIVE_BOOKING_STATUSES = [
  BookingStatus.PENDING,
  BookingStatus.CONFIRMED,
  BookingStatus.IN_PROGRESS,
];
const ENDED_TRIP_STATUSES = [TripStatus.COMPLETED, TripStatus.CANCELLED];

/** A CliQ approval can still land this long after the request. */
const PAYMENT_SETTLING_MS = 60 * 60 * 1000;

/**
 * Erases an account and what depends on it. Nothing can restore it, so it is
 * refused while a ride or money is in flight. A ban clears the rides, and a
 * wallet adjustment clears the balance.
 */
@Injectable()
export class AdminUserDeletionService {
  private readonly logger = new Logger(AdminUserDeletionService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly privateDocuments: PrivateDocumentsService,
    private readonly uploads: UploadsService,
  ) {}

  async preview(userId: string): Promise<UserDeletionPreview> {
    const { manager } = this.dataSource;
    await this.findDeletableUser(manager, userId);

    const [
      blockers,
      trips,
      otherPassengersBookings,
      bookings,
      payments,
      messages,
      ratings,
    ] = await Promise.all([
      this.findBlockers(manager, userId),
      manager.count(TripEntity, { where: { driverId: userId } }),
      manager
        .createQueryBuilder(BookingEntity, 'booking')
        .innerJoin('booking.trip', 'trip')
        .where('trip.driverId = :userId', { userId })
        .andWhere('booking.userId != :userId', { userId })
        .getCount(),
      manager.count(BookingEntity, { where: { userId } }),
      manager.count(PaymentEntity, { where: { userId } }),
      manager.count(MessageEntity, { where: { senderId: userId } }),
      manager.count(RatingEntity, {
        where: [{ fromUserId: userId }, { toUserId: userId }],
      }),
    ]);

    return {
      blockers,
      counts: {
        trips,
        otherPassengersBookings,
        bookings,
        payments,
        messages,
        ratings,
      },
    };
  }

  async delete(userId: string, adminId: string): Promise<void> {
    const { files, role } = await this.dataSource.transaction(async (em) => {
      const user = await this.findDeletableUser(em, userId, true);
      const blockers = await this.findBlockers(em, userId);
      if (blockers.length > 0) {
        throw new ConflictException({
          statusCode: 409,
          code: 'USER_DELETE_BLOCKED',
          message: `The account cannot be deleted yet: ${blockers.join(', ')}.`,
          blockers,
        });
      }

      const vehicles = await em.find(VehicleEntity, {
        where: { driverId: userId },
      });

      await this.eraseAccount(em, user);
      await em.save(
        em.create(SecurityEventEntity, {
          userId: null,
          eventType: 'account_deleted',
          adminActorId: adminId,
          metadata: { deletedUserId: userId, role: user.role },
        }),
      );

      return {
        role: user.role,
        files: [
          user.photoUrl,
          ...vehicles.flatMap((vehicle) => [
            vehicle.nationalIdImageUrl,
            vehicle.licenseImageUrl,
            vehicle.vehicleLicenseImageUrl,
            vehicle.carImageUrl,
            vehicle.insuranceImageUrl,
          ]),
        ],
      };
    });

    // After the commit: a rollback must not leave rows pointing at lost files.
    await Promise.all(files.map((file) => this.removeFile(file)));
    this.logger.log(
      JSON.stringify({ event: 'admin.user_deleted', userId, adminId, role }),
    );
  }

  private async findDeletableUser(
    manager: EntityManager,
    userId: string,
    lock = false,
  ): Promise<UserEntity> {
    const user = await manager.findOne(UserEntity, {
      where: { id: userId },
      ...(lock ? { lock: { mode: 'pessimistic_write' as const } } : {}),
    });
    if (!user) throw new NotFoundException('User not found');
    if (user.role === PgUserRole.ADMIN) {
      throw new BadRequestException('Cannot delete admin users');
    }
    return user;
  }

  private async findBlockers(
    manager: EntityManager,
    userId: string,
  ): Promise<UserDeletionBlocker[]> {
    const liveBookings = () =>
      manager
        .createQueryBuilder(BookingEntity, 'booking')
        .innerJoin('booking.trip', 'trip')
        .where('booking.status IN (:...live)', {
          live: LIVE_BOOKING_STATUSES,
        })
        .andWhere('trip.status NOT IN (:...ended)', {
          ended: ENDED_TRIP_STATUSES,
        });

    // One after another: inside a transaction these share a connection.
    const runningTrips = await manager.count(TripEntity, {
      where: { driverId: userId, status: TripStatus.IN_PROGRESS },
    });
    const tripsWithPassengers = await liveBookings()
      .andWhere('trip.driverId = :userId', { userId })
      .getCount();
    const activeBookings = await liveBookings()
      .andWhere('booking.userId = :userId', { userId })
      .getCount();
    const searches = await manager.count(InstantRideRequestEntity, {
      where: {
        passengerId: userId,
        status: In([
          InstantRequestStatus.SEARCHING,
          InstantRequestStatus.OFFERED,
        ]),
      },
    });
    const wallets = await manager.find(WalletAccountEntity, {
      where: { userId },
    });
    const openPayouts = await manager.count(PayoutRequestEntity, {
      where: {
        driverId: userId,
        status: In([PayoutStatus.PENDING, PayoutStatus.APPROVED]),
      },
    });
    const recentPayments = await manager.count(PaymentEntity, {
      where: {
        userId,
        status: 'pending',
        createdAt: MoreThan(new Date(Date.now() - PAYMENT_SETTLING_MS)),
      },
    });

    const blockers: UserDeletionBlocker[] = [];
    if (runningTrips > 0 || tripsWithPassengers > 0) {
      blockers.push('ACTIVE_TRIP');
    }
    if (activeBookings > 0) blockers.push('ACTIVE_BOOKING');
    if (searches > 0) blockers.push('INSTANT_SEARCH');
    if (
      wallets.some(
        (wallet) =>
          Number(wallet.balance) !== 0 || Number(wallet.reservedBalance) !== 0,
      )
    ) {
      blockers.push('WALLET_NOT_EMPTY');
    }
    if (openPayouts > 0) blockers.push('OPEN_PAYOUT');
    if (recentPayments > 0) blockers.push('RECENT_PAYMENT');
    return blockers;
  }

  /** Rows the database will not cascade: refused references, and bare ids. */
  private async eraseAccount(
    em: EntityManager,
    user: UserEntity,
  ): Promise<void> {
    const userId = user.id;

    await em.update(
      ChatRoomEntity,
      { lastMessageSenderId: userId },
      { lastMessage: null },
    );
    await em.delete(MessageEntity, { senderId: userId });
    await em.delete(PaymentEntity, { userId });
    await em.delete(TripShareLinkEntity, { createdByUserId: userId });

    // Another passenger's past request must not name a trip that is gone.
    await em.update(
      InstantRideRequestEntity,
      { matchedDriverId: userId, passengerId: Not(userId) },
      { matchedDriverId: null, tripId: null },
    );
    await em.delete(TripEntity, { driverId: userId });

    if (user.phoneNumber) {
      const { phoneNumber } = user;
      await em.delete(OtpCodeEntity, { phoneNumber });
      await em.delete(PasswordResetSessionEntity, { phoneNumber });
      await em.delete(PendingRegistrationEntity, { phoneNumber });
    }

    await em.delete(UserEntity, { id: userId });
  }

  private async removeFile(reference: string | null): Promise<void> {
    if (!reference) return;
    try {
      if (reference.startsWith(PRIVATE_DOCUMENT_PREFIX)) {
        await this.privateDocuments.remove(reference);
        return;
      }
      const key = reference.match(/\/uploads\/(.+)$/)?.[1];
      if (key) await this.uploads.deleteFile(key, 'admin');
    } catch (error) {
      // The account is already gone, so all that is left is to say so.
      this.logger.error(
        `Could not remove ${reference}: ${(error as Error).message}`,
      );
    }
  }
}
