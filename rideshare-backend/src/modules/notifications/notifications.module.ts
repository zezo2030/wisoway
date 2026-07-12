import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { NotificationEntity } from '../../database/entities/notification.entity';
import { DeviceTokenEntity } from '../../database/entities/device-token.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { AdminAlertPreferenceEntity } from '../../database/entities/admin-alert-preference.entity';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationsGateway } from './notifications.gateway';
import { AdminAlertsService } from '../admin/admin-alerts.service';
import { UsersModule } from '../users/users.module';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';
import { NewTripFanoutProcessor } from './processors/new-trip-fanout.processor';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      NotificationEntity,
      DeviceTokenEntity,
      UserEntity,
      AdminAlertPreferenceEntity,
    ]),
    BullModule.registerQueue({ name: 'new-trip-fanout' }),
    UsersModule,
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_ACCESS_SECRET'),
      }),
    }),
  ],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    NotificationsGateway,
    AdminAlertsService,
    NewTripFanoutProcessor,
    WsAuthGuard,
    WsRateLimitGuard,
  ],
  exports: [NotificationsService, AdminAlertsService],
})
export class NotificationsModule {}
