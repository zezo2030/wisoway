import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  DeviceTokenEntity,
  DriverLocationEntity,
  NotificationEntity,
  PasswordResetSessionEntity,
  PayoutRequestEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletHoldEntity,
  WalletTransactionEntity,
  PendingRegistrationEntity,
  OtpCodeEntity,
  VehicleEntity,
  RatingEntity,
  BookingEntity,
  PaymentEntity,
  CommunicationFeeEntity,
  ChatRoomEntity,
  MessageEntity,
} from './entities';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get<string>('POSTGRES_HOST', 'localhost'),
        port: Number(config.get<string>('POSTGRES_PORT', '5432')),
        username: config.get<string>('POSTGRES_USER', 'postgres'),
        password: config.get<string>('POSTGRES_PASSWORD', 'postgres'),
        database: config.get<string>('POSTGRES_DB', 'rideshare'),
        ssl:
          config.get<string>('POSTGRES_SSL', 'false') === 'true'
            ? { rejectUnauthorized: false }
            : false,
        entities: [
          UserEntity,
          TripEntity,
          DriverLocationEntity,
          WalletAccountEntity,
          WalletTransactionEntity,
          WalletHoldEntity,
          PayoutRequestEntity,
          NotificationEntity,
          DeviceTokenEntity,
          PendingRegistrationEntity,
          OtpCodeEntity,
          VehicleEntity,
          RatingEntity,
          BookingEntity,
          PaymentEntity,
          CommunicationFeeEntity,
          ChatRoomEntity,
          MessageEntity,
          PasswordResetSessionEntity,
        ],
        synchronize: false,
        autoLoadEntities: true,
      }),
    }),
  ],
})
export class PostgresModule {}
