import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  Notification,
  NotificationDocument,
} from '../modules/notifications/schemas/notification.schema';

@Injectable()
export class NotificationCleanupJob {
  private readonly logger = new Logger(NotificationCleanupJob.name);

  constructor(
    @InjectModel(Notification.name)
    private notificationModel: Model<NotificationDocument>,
  ) {}

  @Cron('0 2 * * *')
  async handleNotificationCleanup(): Promise<any> {
    this.logger.log('Running notification cleanup job...');

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const result = await this.notificationModel.deleteMany({
      createdAt: { $lt: thirtyDaysAgo },
    });

    if (result.deletedCount > 0) {
      this.logger.log(`Deleted ${result.deletedCount} old notifications`);
    }

    return result;
  }
}
