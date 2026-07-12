import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import {
  AdminAlertPreferenceEntity,
  AdminAlertType,
  NotificationEntity,
  PgUserRole,
  UserEntity,
} from '../../database/entities';
import { NotificationsGateway } from '../notifications/notifications.gateway';
import { NotificationsService } from '../notifications/notifications.service';

const ADMIN_ALERT_TYPES = [
  AdminAlertType.DRIVER_REGISTRATION,
  AdminAlertType.FEE_PAYMENT,
] as const;

export interface AdminAlertPreferenceView {
  alertType: AdminAlertType;
  enabled: boolean;
}

@Injectable()
export class AdminAlertsService {
  private readonly logger = new Logger(AdminAlertsService.name);

  constructor(
    @InjectRepository(AdminAlertPreferenceEntity)
    private readonly preferenceRepo: Repository<AdminAlertPreferenceEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(NotificationEntity)
    private readonly notificationRepo: Repository<NotificationEntity>,
    private readonly notificationsGateway: NotificationsGateway,
    private readonly notificationsService: NotificationsService,
  ) {}

  async getPreferences(userId: string): Promise<AdminAlertPreferenceView[]> {
    const rows = await this.preferenceRepo.find({ where: { userId } });
    const byType = new Map(rows.map((row) => [row.alertType, row.enabled]));

    return ADMIN_ALERT_TYPES.map((alertType) => ({
      alertType,
      enabled: byType.get(alertType) ?? true,
    }));
  }

  async setPreference(
    userId: string,
    alertType: AdminAlertType,
    enabled: boolean,
  ): Promise<AdminAlertPreferenceView> {
    let row = await this.preferenceRepo.findOne({
      where: { userId, alertType },
    });

    if (!row) {
      row = this.preferenceRepo.create({ userId, alertType, enabled });
    } else {
      row.enabled = enabled;
    }

    const saved = await this.preferenceRepo.save(row);
    return { alertType: saved.alertType, enabled: saved.enabled };
  }

  async notifyDriverRegistration(driver: UserEntity): Promise<void> {
    if (driver.role !== PgUserRole.DRIVER) {
      return;
    }

    const displayName =
      driver.name?.trim() || driver.phoneNumber || 'New driver';
    await this.dispatch(AdminAlertType.DRIVER_REGISTRATION, {
      title: 'New driver registration',
      body: `${displayName} registered as a driver.`,
      notificationType: 'admin_driver_registration',
      data: {
        link: `/users/${driver.id}`,
        driverId: driver.id,
      },
    });
  }

  async notifyFeePayment(payment: {
    id: string;
    amount: number | string;
    currency?: string | null;
    paymentType?: string | null;
  }): Promise<void> {
    if (payment.paymentType !== 'communication_fee') {
      return;
    }

    await this.dispatch(AdminAlertType.FEE_PAYMENT, {
      title: 'Communication fee paid',
      body: `A communication fee payment of ${payment.amount} ${payment.currency ?? 'JOD'} succeeded.`,
      notificationType: 'admin_fee_payment',
      data: {
        link: '/payments',
        paymentId: payment.id,
        amount: Number(payment.amount),
        currency: payment.currency ?? 'JOD',
      },
    });
  }

  private async dispatch(
    alertType: AdminAlertType,
    payload: {
      title: string;
      body: string;
      notificationType: string;
      data: Record<string, unknown>;
    },
  ): Promise<void> {
    const recipients = await this.resolveRecipients(alertType);
    let delivered = 0;
    let failed = 0;

    await Promise.all(
      recipients.map(async (recipient) => {
        const notification = await this.notificationRepo.save(
          this.notificationRepo.create({
            userId: recipient.id,
            type: payload.notificationType,
            title: payload.title,
            body: payload.body,
            data: payload.data,
          }),
        );
        this.notificationsGateway.emitToUser(
          recipient.id,
          'newNotification',
          notification,
        );

        const result = await this.notificationsService.sendPush(recipient.id, {
          title: payload.title,
          body: payload.body,
          type: payload.notificationType,
          data: {
            ...payload.data,
            notificationId: notification.id,
          },
          targetPlatforms: ['web'],
        });
        delivered += result.successCount;
        failed += result.failureCount;
      }),
    );

    this.logger.log(
      JSON.stringify({
        event: 'admin.alert.dispatch',
        alertType,
        recipientCount: recipients.length,
        delivered,
        failed,
      }),
    );
  }

  private async resolveRecipients(
    alertType: AdminAlertType,
  ): Promise<Array<Pick<UserEntity, 'id'>>> {
    const admins = await this.userRepo.find({
      where: { role: PgUserRole.ADMIN, isActive: true },
      select: ['id'],
    });
    if (admins.length === 0) {
      return [];
    }

    const adminIds = admins.map((admin) => admin.id);
    const disabled = await this.preferenceRepo.find({
      where: { userId: In(adminIds), alertType, enabled: false },
      select: ['userId'],
    });
    const disabledIds = new Set(disabled.map((row) => row.userId));
    const enabledAdmins = admins.filter((admin) => !disabledIds.has(admin.id));
    if (enabledAdmins.length === 0) {
      return [];
    }

    return enabledAdmins;
  }
}
