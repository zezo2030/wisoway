import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripsService } from './trips.service';
import { TripsController } from './trips.controller';
import { TripsGateway } from './trips.gateway';
import { BookingsModule } from '../bookings/bookings.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { VehiclesModule } from '../vehicles/vehicles.module';
import { UsersModule } from '../users/users.module';
import { PaymentsModule } from '../payments/payments.module';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';
import { TripTimeModule } from '../trip-time/trip-time.module';
import { RecurrenceModule } from '../recurrence/recurrence.module';
import { PendingChargesModule } from '../pending-charges/pending-charges.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([TripEntity]),
    BullModule.registerQueue(
      { name: 'no-show-detector' },
      { name: 'trip-auto-start' },
      { name: 'trip-auto-complete' },
    ),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_ACCESS_SECRET'),
        signOptions: {
          expiresIn: configService.get<any>('JWT_ACCESS_EXPIRES_IN', '15m'),
        },
      }),
      inject: [ConfigService],
    }),
    forwardRef(() => BookingsModule),
    forwardRef(() => NotificationsModule),
    forwardRef(() => PaymentsModule),
    forwardRef(() => TripTimeModule),
    forwardRef(() => RecurrenceModule),
    VehiclesModule,
    UsersModule,
    PendingChargesModule,
  ],
  controllers: [TripsController],
  providers: [TripsService, TripsGateway, WsAuthGuard, WsRateLimitGuard],
  exports: [TripsService, TripsGateway],
})
export class TripsModule {}
