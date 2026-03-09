import 'reflect-metadata';
import { DataSource } from 'typeorm';
import {
  DeviceTokenEntity,
  DriverLocationEntity,
  NotificationEntity,
  PayoutRequestEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletHoldEntity,
  WalletTransactionEntity,
} from './entities';

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.POSTGRES_HOST || 'localhost',
  port: Number(process.env.POSTGRES_PORT || 5432),
  username: process.env.POSTGRES_USER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || 'postgres',
  database: process.env.POSTGRES_DB || 'rideshare',
  ssl:
    process.env.POSTGRES_SSL === 'true' ? { rejectUnauthorized: false } : false,
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
  ],
  migrations: ['dist/src/database/migrations/*.js'],
});
