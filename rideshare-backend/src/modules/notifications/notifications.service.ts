import { Injectable, Logger } from '@nestjs/common';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { NotificationEntity } from '../../database/entities/notification.entity';
import { NotificationChannel } from '../../database/entities/shared.enums';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { NotificationsGateway } from './notifications.gateway';
import { UsersService } from '../users/users.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseReady = false;
  private firebaseUnavailable = false;

  constructor(
    @InjectRepository(NotificationEntity)
    private notificationRepo: Repository<NotificationEntity>,
    private usersService: UsersService,
    private notificationsGateway: NotificationsGateway,
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
      const user = await this.usersService.findById(userId);
      if (!user.fcmToken) {
        this.logger.debug(`User ${userId} has no FCM token, skipping push`);
        return;
      }

      await admin.messaging().send({
        token: user.fcmToken,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: this.buildFcmData(userId, payload),
        android: {
          priority: 'high',
          notification: {
            channelId: 'rideshare_notifications',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to send push notification: ${message}`);
    }
  }

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
}
