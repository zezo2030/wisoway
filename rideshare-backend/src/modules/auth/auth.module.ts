import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { UsersModule } from '../users/users.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtRefreshStrategy } from './strategies/jwt-refresh.strategy';
import { DeviceFingerprintService } from './device-fingerprint.service';
import { AccountRiskService } from './account-risk.service';
import {
  UserDeviceEntity,
  AccountFlagEntity,
  SecurityEventEntity,
  UserEntity,
  PasswordResetSessionEntity,
} from '../../database/entities';

@Module({
  imports: [
    UsersModule,
    NotificationsModule,
    PassportModule,
    TypeOrmModule.forFeature([
      UserDeviceEntity,
      AccountFlagEntity,
      SecurityEventEntity,
      UserEntity,
      PasswordResetSessionEntity,
    ]),
    ConfigModule,
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    JwtRefreshStrategy,
    DeviceFingerprintService,
    AccountRiskService,
  ],
  exports: [AuthService, DeviceFingerprintService],
})
export class AuthModule {}
