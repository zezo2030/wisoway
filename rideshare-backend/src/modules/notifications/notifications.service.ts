import {
  Injectable,
  Logger,
  NotFoundException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { NotificationEntity } from '../../database/entities/notification.entity';
import { DeviceTokenEntity } from '../../database/entities/device-token.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { NotificationChannel } from '../../database/entities/shared.enums';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { NotificationsGateway } from './notifications.gateway';
import { UsersService } from '../users/users.service';
import { AuditService } from '../../common/audit/audit.service';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseReady = false;
  private firebaseUnavailable = false;

  constructor(
    @InjectRepository(NotificationEntity)
    private notificationRepo: Repository<NotificationEntity>,
    @InjectRepository(DeviceTokenEntity)
    private deviceTokenRepo: Repository<DeviceTokenEntity>,
    private usersService: UsersService,
    private notificationsGateway: NotificationsGateway,
    private auditService: AuditService,
    @InjectQueue('new-trip-fanout')
    private fanoutQueue: Queue,
  ) {}

  private normalizePrivateKey(privateKeyRaw?: string): string | undefined {
    if (!privateKeyRaw) {
      return undefined;
    }

    return privateKeyRaw.trim().replace(/^"|"$/g, '').replace(/\\n/g, '\n');
  }

  private ensureFirebase() {
    if (this.firebaseReady || this.firebaseUnavailable) {
      return;
    }
    if (admin.apps.length > 0) {
      this.firebaseReady = true;
      return;
    }
    const serviceAccountPath =
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH?.trim() ||
      process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
    if (serviceAccountPath) {
      try {
        const resolvedPath = resolve(serviceAccountPath);
        if (!existsSync(resolvedPath)) {
          throw new Error(`service account file not found at ${resolvedPath}`);
        }

        const serviceAccount = JSON.parse(
          readFileSync(resolvedPath, 'utf8'),
        ) as admin.ServiceAccount & {
          project_id?: string;
          client_email?: string;
          private_key?: string;
        };

        const projectId = serviceAccount.projectId ?? serviceAccount.project_id;
        const clientEmail =
          serviceAccount.clientEmail ?? serviceAccount.client_email;
        const privateKey = this.normalizePrivateKey(
          serviceAccount.privateKey ?? serviceAccount.private_key,
        );

        if (!projectId || !clientEmail || !privateKey) {
          throw new Error('service account file is missing required fields');
        }

        admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey,
          }),
        });
        this.firebaseReady = true;
        this.logger.log('Firebase push configured from service account file');
        return;
      } catch (error) {
        const message =
          error instanceof Error ? error.message : 'Unknown Firebase error';
        this.logger.warn(
          `Failed to initialize Firebase from service account file: ${message}`,
        );
      }
    }

    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = this.normalizePrivateKey(
      process.env.FIREBASE_PRIVATE_KEY,
    );
    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn(
        'Firebase push is not configured (missing FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_* variables)',
      );
      this.firebaseUnavailable = true;
      return;
    }

    try {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
      this.firebaseReady = true;
    } catch (error) {
      this.firebaseUnavailable = true;
      this.logger.warn(
        `Firebase push is disabled due to invalid credentials: ${error.message}`,
      );
    }
  }

  private stringifyFcmValue(value: unknown): string {
    if (typeof value === 'string') {
      return value;
    }
    if (
      typeof value === 'number' ||
      typeof value === 'boolean' ||
      typeof value === 'bigint'
    ) {
      return String(value);
    }
    return JSON.stringify(value);
  }

  private resolveCollapseKey(payload: {
    type: string;
    data?: Record<string, unknown>;
  }): string | undefined {
    if (payload.type === 'chat_message') {
      const roomId = payload.data?.chatRoomId;
      if (roomId !== null && roomId !== undefined) {
        return `chat_${String(roomId)}`;
      }
    }
    return undefined;
  }

  private buildFcmData(
    userId: string,
    payload: {
      type: string;
      data?: Record<string, unknown>;
      notificationId?: string;
    },
  ): Record<string, string> {
    const rawData: Record<string, unknown> = {
      userId,
      type: payload.type,
      notificationId: payload.notificationId,
      ...(payload.data ?? {}),
    };

    return Object.fromEntries(
      Object.entries(rawData)
        .filter(([, value]) => value !== null && value !== undefined)
        .map(([key, value]) => [key, this.stringifyFcmValue(value)]),
    );
  }

  async create(
    createNotificationDto: CreateNotificationDto,
  ): Promise<NotificationEntity> {
    const notification = this.notificationRepo.create({
      ...createNotificationDto,
      userId: createNotificationDto.userId,
      channel: NotificationChannel.IN_APP,
    });
    const saved = await this.notificationRepo.save(notification);

    this.notificationsGateway.emitToUser(
      createNotificationDto.userId,
      'newNotification',
      saved,
    );

    this.sendPush(createNotificationDto.userId, {
      title: createNotificationDto.title,
      body: createNotificationDto.body,
      type: createNotificationDto.type,
      data: {
        ...(createNotificationDto.data ?? {}),
        notificationId: saved.id,
      },
    });

    return saved;
  }

  async sendPush(
    userId: string,
    payload: {
      title: string;
      body?: string;
      type: string;
      data?: Record<string, unknown>;
    },
  ): Promise<void> {
    this.ensureFirebase();
    if (!this.firebaseReady) {
      return;
    }

    try {
      const tokens = await this.deviceTokenRepo.find({
        where: { userId, isActive: true },
      });

      if (tokens.length === 0) {
        this.logger.debug(
          `User ${userId} has no active device tokens, skipping push`,
        );
        return;
      }

      const tokenStrings = tokens.map((t) => t.token);
      const data = this.buildFcmData(userId, payload);

      const collapseKey = this.resolveCollapseKey(payload);
      const androidNotification: admin.messaging.AndroidNotification = {
        channelId: 'rideshare_notifications',
      };
      if (collapseKey) {
        androidNotification.tag = collapseKey;
      }
      const apnsHeaders: Record<string, string> = {};
      if (collapseKey) {
        apnsHeaders['apns-collapse-id'] = collapseKey;
      }

      if (tokenStrings.length === 1) {
        await admin.messaging().send({
          token: tokenStrings[0],
          notification: { title: payload.title, body: payload.body },
          data,
          android: {
            priority: 'high',
            ...(collapseKey ? { collapseKey } : {}),
            notification: androidNotification,
          },
          apns: {
            ...(Object.keys(apnsHeaders).length ? { headers: apnsHeaders } : {}),
            payload: { aps: { sound: 'default' } },
          },
        });
      } else {
        await admin.messaging().sendEachForMulticast({
          tokens: tokenStrings,
          notification: { title: payload.title, body: payload.body },
          data,
          android: {
            priority: 'high',
            ...(collapseKey ? { collapseKey } : {}),
            notification: androidNotification,
          },
          apns: {
            ...(Object.keys(apnsHeaders).length ? { headers: apnsHeaders } : {}),
            payload: { aps: { sound: 'default' } },
          },
        });
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to send push notification: ${message}`);
    }
  }

  // ─── Device Token Management (T025, T026) ───

  async registerDevice(
    userId: string,
    dto: RegisterDeviceDto,
  ): Promise<{
    registered: boolean;
    platform: string;
    lastSeenAt: Date;
    isNew: boolean;
  }> {
    const now = new Date();
    let isNew = false;

    let existing = await this.deviceTokenRepo.findOne({
      where: { token: dto.token },
    });

    if (existing) {
      existing.userId = userId;
      existing.platform = dto.platform;
      existing.isActive = true;
      existing.lastSeenAt = now;
      await this.deviceTokenRepo.save(existing);
    } else {
      isNew = true;
      existing = this.deviceTokenRepo.create({
        userId,
        token: dto.token,
        platform: dto.platform,
        isActive: true,
        lastSeenAt: now,
      });
      await this.deviceTokenRepo.save(existing);
    }

    const tokenPrefix =
      dto.token.substring(0, Math.min(8, dto.token.length)) + '…';

    this.auditService.emit({
      action: 'device.register',
      userId,
      platform: dto.platform,
      tokenPrefix,
    });

    this.logger.log(
      JSON.stringify({
        event: 'notification.dispatch',
        trigger: 'device.register',
        userId,
        platform: dto.platform,
        tokenPrefix,
      }),
    );

    return {
      registered: true,
      platform: dto.platform,
      lastSeenAt: now,
      isNew,
    };
  }

  async deregisterDevice(userId: string, token: string): Promise<void> {
    const device = await this.deviceTokenRepo.findOne({
      where: { token },
    });

    if (!device || device.userId !== userId) {
      throw new NotFoundException('Device token not found');
    }

    device.isActive = false;
    await this.deviceTokenRepo.save(device);

    const tokenPrefix = token.substring(0, Math.min(8, token.length)) + '…';

    this.auditService.emit({
      action: 'device.deregister',
      userId,
      platform: device.platform,
      tokenPrefix,
    });

    this.logger.log(
      JSON.stringify({
        event: 'notification.dispatch',
        trigger: 'device.deregister',
        userId,
        platform: device.platform,
        tokenPrefix,
      }),
    );
  }

  // ─── Booking Trigger Methods (T031-T033) ───

  async notifyDriverOfNewBooking(bookingId: string): Promise<void> {
    try {
      const bookingRepo =
        this.notificationRepo.manager.getRepository(BookingEntity);
      const booking = await bookingRepo.findOne({
        where: { id: bookingId },
        relations: ['trip'],
      });
      if (!booking) return;

      const trip = booking.trip;
      if (!trip) return;

      await this.sendPush(trip.driverId, {
        title: 'New Booking',
        body: `A new booking was made on your trip to ${trip.toName}`,
        type: 'booking_created',
        data: {
          type: 'booking_created',
          screen: 'trip_details',
          entityId: trip.id,
          bookingId,
        },
      });

      this.logger.log(
        JSON.stringify({
          event: 'notification.dispatch',
          trigger: 'booking_created',
          recipientUserCount: 1,
          bookingId,
          correlationId: bookingId,
        }),
      );
    } catch (error) {
      this.logger.warn(
        `Failed to notify driver of new booking ${bookingId}: ${error instanceof Error ? error.message : error}`,
      );
    }
  }

  async notifyPassengerOfBookingDecision(
    bookingId: string,
    decision: 'confirmed' | 'rejected' | 'canceled',
  ): Promise<void> {
    try {
      const bookingRepo =
        this.notificationRepo.manager.getRepository(BookingEntity);
      const booking = await bookingRepo.findOne({
        where: { id: bookingId },
      });
      if (!booking) return;

      const titleMap: Record<string, string> = {
        confirmed: 'Booking Confirmed',
        rejected: 'Booking Rejected',
        canceled: 'Booking Cancelled',
      };

      await this.sendPush(booking.userId, {
        title: titleMap[decision] || 'Booking Update',
        body: `Your booking has been ${decision}`,
        type: `booking_${decision}`,
        data: {
          type: `booking_${decision}`,
          screen: 'booking_details',
          entityId: bookingId,
        },
      });

      this.logger.log(
        JSON.stringify({
          event: 'notification.dispatch',
          trigger: `booking_${decision}`,
          recipientUserCount: 1,
          bookingId,
          correlationId: bookingId,
        }),
      );
    } catch (error) {
      this.logger.warn(
        `Failed to notify passenger of booking ${decision} ${bookingId}: ${error instanceof Error ? error.message : error}`,
      );
    }
  }

  async notifyDriverOfBookingCancellation(bookingId: string): Promise<void> {
    try {
      const bookingRepo =
        this.notificationRepo.manager.getRepository(BookingEntity);
      const booking = await bookingRepo.findOne({
        where: { id: bookingId },
        relations: ['trip'],
      });
      if (!booking) return;

      const trip = booking.trip;
      if (!trip) return;

      await this.sendPush(trip.driverId, {
        title: 'Booking Cancelled',
        body: 'A passenger cancelled their booking on your trip',
        type: 'booking_canceled_by_passenger',
        data: {
          type: 'booking_canceled_by_passenger',
          screen: 'trip_details',
          entityId: trip.id,
        },
      });

      this.logger.log(
        JSON.stringify({
          event: 'notification.dispatch',
          trigger: 'booking_canceled_by_passenger',
          recipientUserCount: 1,
          bookingId,
          correlationId: bookingId,
        }),
      );
    } catch (error) {
      this.logger.warn(
        `Failed to notify driver of booking cancellation ${bookingId}: ${error instanceof Error ? error.message : error}`,
      );
    }
  }

  // ─── City Fan-out (T035) ───

  async enqueueCityFanout(tripId: string): Promise<void> {
    await this.fanoutQueue.add(
      'fanout',
      { tripId },
      { attempts: 3, backoff: 5000 },
    );
    this.logger.log(`Enqueued city fanout job for trip ${tripId}`);
  }

  async processCityFanout(tripId: string): Promise<void> {
    this.ensureFirebase();
    if (!this.firebaseReady) return;

    const startMs = Date.now();
    const correlationId = tripId;

    try {
      const tripRepo = this.notificationRepo.manager.getRepository(TripEntity);
      const userRepo = this.notificationRepo.manager.getRepository(UserEntity);

      const trip = await tripRepo.findOne({ where: { id: tripId } });
      if (!trip) {
        this.logger.warn(`City fanout: trip ${tripId} not found`);
        return;
      }

      const originCity = trip.fromName?.split(',')[0]?.trim();
      if (!originCity) {
        this.logger.warn(`City fanout: trip ${tripId} has no origin city`);
        return;
      }

      const recipients = await userRepo
        .createQueryBuilder('user')
        .select(['user.id'])
        .where('LOWER(user.city) = LOWER(:originCity)', { originCity })
        .andWhere('user.isActive = true')
        .andWhere('user.id != :posterId', { posterId: trip.driverId })
        .getMany();

      if (recipients.length === 0) {
        this.logger.log(
          JSON.stringify({
            event: 'notification.dispatch',
            trigger: 'city_fanout',
            originCity,
            recipientUserCount: 0,
            deviceCount: 0,
            successCount: 0,
            failureCount: 0,
            durationMs: Date.now() - startMs,
            correlationId,
          }),
        );
        return;
      }

      const recipientIds = recipients.map((r: any) => r.id);

      const tokens = await this.deviceTokenRepo.find({
        where: { userId: In(recipientIds), isActive: true },
      });

      if (tokens.length === 0) return;

      const data: Record<string, string> = {
        type: 'new_trip_posted',
        screen: 'trip_details',
        entityId: tripId,
      };

      let successCount = 0;
      let failureCount = 0;
      const unregisteredTokens: string[] = [];

      const BATCH_SIZE = 500;
      for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
        const batch = tokens.slice(i, i + BATCH_SIZE);
        const batchTokens = batch.map((t) => t.token);

        try {
          const response = await admin.messaging().sendEachForMulticast({
            tokens: batchTokens,
            notification: {
              title: 'New Trip Posted',
              body: `A new trip to ${trip.toName} is available`,
            },
            data,
            android: {
              priority: 'high',
              notification: { channelId: 'rideshare_notifications' },
            },
            apns: {
              payload: { aps: { sound: 'default' } },
            },
          });

          successCount += response.successCount;
          failureCount += response.failureCount;

          response.responses.forEach((resp, idx) => {
            if (
              !resp.success &&
              resp.error?.code === 'messaging/registration-token-not-registered'
            ) {
              unregisteredTokens.push(batchTokens[idx]);
            }
          });
        } catch (error) {
          failureCount += batchTokens.length;
          this.logger.error(
            `City fanout batch error: ${error instanceof Error ? error.message : error}`,
          );
        }
      }

      if (unregisteredTokens.length > 0) {
        await this.deviceTokenRepo.update(
          { token: In(unregisteredTokens) },
          { isActive: false },
        );
      }

      this.auditService.emit({
        action: 'notification.city_fanout',
        userId: trip.driverId,
        tripId,
        originCity,
        recipientUserCount: recipients.length,
        deviceCount: tokens.length,
        successCount,
        failureCount,
      });

      this.logger.log(
        JSON.stringify({
          event: 'notification.dispatch',
          trigger: 'city_fanout',
          originCity,
          recipientUserCount: recipients.length,
          deviceCount: tokens.length,
          successCount,
          failureCount,
          durationMs: Date.now() - startMs,
          correlationId,
        }),
      );
    } catch (error) {
      this.logger.error(
        `City fanout failed for trip ${tripId}: ${error instanceof Error ? error.message : error}`,
      );
    }
  }

  // ─── Existing Methods ───

  async findByUser(
    userId: string,
    pagination: { page: number; limit: number; isRead?: boolean },
  ): Promise<PaginatedResult<NotificationEntity>> {
    const { page, limit, isRead } = pagination;
    const skip = (page - 1) * limit;

    const qb = this.notificationRepo
      .createQueryBuilder('n')
      .where('n.userId = :userId', { userId });

    if (isRead !== undefined) {
      qb.andWhere('n.isRead = :isRead', { isRead });
    }

    const [data, total] = await Promise.all([
      qb.orderBy('n.createdAt', 'DESC').skip(skip).take(limit).getMany(),
      qb.getCount(),
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

  async getUnreadCount(userId: string): Promise<number> {
    return this.notificationRepo.count({
      where: { userId, isRead: false },
    });
  }

  async markRead(
    notificationId: string,
    userId: string,
  ): Promise<NotificationEntity> {
    const notification = await this.notificationRepo.findOne({
      where: { id: notificationId },
    });
    if (!notification) {
      throw new Error('Notification not found');
    }
    if (notification.userId !== userId) {
      throw new Error('Unauthorized');
    }
    notification.isRead = true;
    return this.notificationRepo.save(notification);
  }

  async markAllRead(userId: string): Promise<number> {
    const result = await this.notificationRepo.update(
      { userId, isRead: false },
      { isRead: true },
    );
    return result.affected ?? 0;
  }

  async delete(notificationId: string, userId: string): Promise<void> {
    const notification = await this.notificationRepo.findOne({
      where: { id: notificationId },
    });
    if (!notification) {
      throw new Error('Notification not found');
    }
    if (notification.userId !== userId) {
      throw new Error('Unauthorized');
    }
    await this.notificationRepo.remove(notification);
  }

  // ─── FR-049 templates: ban, complaint, penalty (T172) ─────────────────────

  /**
   * T172 — Push sent to the user when their account is banned by an admin.
   * The ban screen in the mobile app reads the `banReason` from the 403 body;
   * this push is an additional signal for background/locked devices.
   */
  async notifyUserBanned(userId: string, banReason: string): Promise<void> {
    try {
      await this.sendPush(userId, {
        title: 'Account Suspended',
        body: banReason || 'Your account has been suspended. Tap for details.',
        type: 'account_banned',
        data: { screen: 'banned' },
      });
    } catch (err) {
      this.logger.warn(
        `notifyUserBanned: failed for ${userId}: ${err instanceof Error ? err.message : err}`,
      );
    }
  }

  /**
   * T172 — Push sent to the complaint reporter when the admin resolves or
   * rejects their complaint.
   */
  async notifyComplaintStatusChanged(
    reporterId: string,
    status: 'resolved' | 'rejected',
    complaintId: string,
  ): Promise<void> {
    const isResolved = status === 'resolved';
    try {
      await this.sendPush(reporterId, {
        title: isResolved ? 'Complaint Resolved' : 'Complaint Update',
        body: isResolved
          ? 'Your complaint has been reviewed and resolved.'
          : 'Your complaint could not be actioned at this time.',
        type: `complaint_${status}`,
        data: { screen: 'complaints', complaintId },
      });
    } catch (err) {
      this.logger.warn(
        `notifyComplaintStatusChanged: failed for ${reporterId}: ${err instanceof Error ? err.message : err}`,
      );
    }
  }

  /**
   * T172 — Push sent to a user when an automated penalty charge is applied
   * (e.g. no-show or late cancellation penalty collected from wallet).
   */
  async notifyPenaltyCharged(
    userId: string,
    amountFormatted: string,
    reason: string,
  ): Promise<void> {
    try {
      await this.sendPush(userId, {
        title: 'Penalty Charge Applied',
        body: `A penalty of ${amountFormatted} has been charged: ${reason}`,
        type: 'penalty_charged',
        data: { screen: 'wallet' },
      });
    } catch (err) {
      this.logger.warn(
        `notifyPenaltyCharged: failed for ${userId}: ${err instanceof Error ? err.message : err}`,
      );
    }
  }
}
