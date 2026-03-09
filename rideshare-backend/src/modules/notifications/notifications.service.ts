import { Injectable, Logger } from '@nestjs/common';
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

  private ensureFirebase() {
    if (this.firebaseReady || this.firebaseUnavailable) {
      return;
    }
    if (admin.apps.length > 0) {
      this.firebaseReady = true;
      return;
    }
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY;
    if (!projectId || !clientEmail || !privateKeyRaw) {
      this.logger.warn(
        'Firebase push is not configured (missing FIREBASE_* variables)',
      );
      this.firebaseUnavailable = true;
      return;
    }

    try {
      const privateKey = privateKeyRaw
        .trim()
        .replace(/^"|"$/g, '')
        .replace(/\\n/g, '\n');

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
    });

    return saved;
  }

  async sendPush(
    userId: string,
    payload: { title: string; body?: string },
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
        data: {
          userId,
        },
      });
    } catch (error) {
      this.logger.error(`Failed to send push notification: ${error.message}`);
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
