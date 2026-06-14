import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { UserEntity } from '../../database/entities/user.entity';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import {
  UserDeviceEntity,
  UserDeviceStatus,
} from '../../database/entities/user-device.entity';
import { SecurityEventEntity } from '../../database/entities/security-event.entity';
import { NotificationsService } from '../notifications/notifications.service';

/**
 * AdminBanService — T164 (Phase 8 / US6)
 *
 * Implements the full ban cascade per FR-042:
 *  1. Set `bannedAt` / `banReason` on the user.
 *  2. Cancel every pending + confirmed booking owned by the user.
 *  3. Cancel every published / fully-booked trip authored by the user
 *     and push a notification to each confirmed passenger.
 *  4. Revoke all `user_devices` rows for the user.
 *  5. Append a `security_events` row (type: `account_banned`).
 *
 * Unban is the inverse: clear `bannedAt` / `banReason` only.  Previously
 * cancelled bookings / trips are NOT restored.
 */
@Injectable()
export class AdminBanService {
  private readonly logger = new Logger(AdminBanService.name);

  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,

    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,

    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,

    @InjectRepository(UserDeviceEntity)
    private readonly deviceRepo: Repository<UserDeviceEntity>,

    @InjectRepository(SecurityEventEntity)
    private readonly securityEventRepo: Repository<SecurityEventEntity>,

    private readonly notificationsService: NotificationsService,
  ) {}

  // ── Ban ─────────────────────────────────────────────────────────────────────

  async banUser(
    userId: string,
    reason: string,
    adminId: string,
  ): Promise<UserEntity> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.bannedAt != null)
      throw new BadRequestException('User is already banned');

    const now = new Date();

    // ── 1. Mark user as banned ────────────────────────────────────────────────
    user.bannedAt = now;
    user.banReason = reason;
    await this.userRepo.save(user);

    // ── 2. Cancel pending + confirmed bookings owned by this user ─────────────
    const cancelledBookingCount = await this._cancelUserBookings(userId, now);

    // ── 3. Cancel published/fully-booked trips authored by this user ──────────
    const cancelledTripCount = await this._cancelDriverTrips(userId, now);

    // ── 4. Revoke all devices ─────────────────────────────────────────────────
    const revokedDeviceCount = await this._revokeUserDevices(
      userId,
      now,
      reason,
    );

    // ── 5. Security event audit ───────────────────────────────────────────────
    await this.securityEventRepo.save(
      this.securityEventRepo.create({
        userId,
        eventType: 'account_banned',
        adminActorId: adminId,
        metadata: {
          reason,
          cancelledBookings: cancelledBookingCount,
          cancelledTrips: cancelledTripCount,
          revokedDevices: revokedDeviceCount,
        },
      }),
    );

    // Push notification to the banned user (background/locked device signal)
    this.notificationsService.notifyUserBanned(userId, reason).catch(() => {});

    this.logger.log(
      JSON.stringify({
        event: 'admin.ban',
        userId,
        adminId,
        cancelledBookings: cancelledBookingCount,
        cancelledTrips: cancelledTripCount,
        revokedDevices: revokedDeviceCount,
      }),
    );

    return user;
  }

  // ── Unban ────────────────────────────────────────────────────────────────────

  async unbanUser(userId: string, adminId: string): Promise<UserEntity> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.bannedAt == null)
      throw new BadRequestException('User is not banned');

    user.bannedAt = null;
    user.banReason = null;
    await this.userRepo.save(user);

    await this.securityEventRepo.save(
      this.securityEventRepo.create({
        userId,
        eventType: 'account_unbanned',
        adminActorId: adminId,
        metadata: {},
      }),
    );

    this.logger.log(JSON.stringify({ event: 'admin.unban', userId, adminId }));

    return user;
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  private async _cancelUserBookings(
    userId: string,
    now: Date,
  ): Promise<number> {
    const bookings = await this.bookingRepo.find({
      where: {
        userId,
        status: In([BookingStatus.PENDING, BookingStatus.CONFIRMED]),
      },
    });

    if (bookings.length === 0) return 0;

    for (const booking of bookings) {
      booking.status = BookingStatus.CANCELLED;
      booking.cancelledAt = now;
      booking.cancelledBy = 'admin_ban';
      booking.cancellationReason = 'Account banned by admin';
    }
    await this.bookingRepo.save(bookings);
    return bookings.length;
  }

  private async _cancelDriverTrips(userId: string, now: Date): Promise<number> {
    const trips = await this.tripRepo.find({
      where: {
        driverId: userId,
        status: In([TripStatus.PUBLISHED, TripStatus.FULLY_BOOKED]),
      },
    });

    if (trips.length === 0) return 0;

    for (const trip of trips) {
      trip.status = TripStatus.CANCELLED;

      // Notify all confirmed passengers on each cancelled trip
      await this._notifyTripPassengers(trip.id, trip.toName);
    }

    await this.tripRepo.save(trips);
    return trips.length;
  }

  private async _notifyTripPassengers(
    tripId: string,
    tripToName: string,
  ): Promise<void> {
    // Find confirmed bookings for this trip
    const confirmedBookings = await this.bookingRepo.find({
      where: {
        tripId,
        status: BookingStatus.CONFIRMED,
      },
      select: ['id', 'userId'],
    });

    // Cancel those bookings too
    if (confirmedBookings.length > 0) {
      const now = new Date();
      for (const booking of confirmedBookings) {
        booking.status = BookingStatus.CANCELLED;
        booking.cancelledAt = now;
        booking.cancelledBy = 'admin_ban_driver';
        booking.cancellationReason = 'Trip cancelled — driver account banned';
      }
      await this.bookingRepo.save(confirmedBookings);

      // Push notification to each passenger
      for (const booking of confirmedBookings) {
        try {
          await this.notificationsService.sendPush(booking.userId, {
            title: 'Trip Cancelled',
            body: `Your trip to ${tripToName} has been cancelled`,
            type: 'trip_cancelled_by_admin',
            data: {
              screen: 'home',
              tripId,
            },
          });
        } catch (err) {
          this.logger.warn(
            `Failed to notify passenger ${booking.userId} of trip cancellation: ${
              err instanceof Error ? err.message : err
            }`,
          );
        }
      }
    }
  }

  private async _revokeUserDevices(
    userId: string,
    now: Date,
    reason: string,
  ): Promise<number> {
    const devices = await this.deviceRepo.find({
      where: { userId, status: UserDeviceStatus.ACTIVE },
    });

    if (devices.length === 0) return 0;

    for (const device of devices) {
      device.status = UserDeviceStatus.REVOKED;
      device.revokedAt = now;
      device.revokeReason = `account_banned: ${reason}`;
    }
    await this.deviceRepo.save(devices);
    return devices.length;
  }
}
