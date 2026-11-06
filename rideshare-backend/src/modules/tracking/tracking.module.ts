import { forwardRef, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  BookingEntity,
  BookingSeatEntity,
  DriverLocationEntity,
  TripEntity,
  SecurityEventEntity,
  AccountFlagEntity,
  UserEntity,
} from '../../database/entities';
import { TrackingController } from './tracking.controller';
import { TrackingGateway } from './tracking.gateway';
import { TrackingService } from './tracking.service';
import { PassengerLocationService } from './passenger-location.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';
import { LocationGuardInterceptor } from '../../common/interceptors/location-guard.interceptor';
import { LocationsModule } from '../locations/locations.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      BookingEntity,
      BookingSeatEntity,
      DriverLocationEntity,
      TripEntity,
      SecurityEventEntity,
      AccountFlagEntity,
      UserEntity,
    ]),
    ConfigModule,
    LocationsModule,
    forwardRef(() => NotificationsModule),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_ACCESS_SECRET'),
      }),
    }),
  ],
  controllers: [TrackingController],
  providers: [
    TrackingService,
    PassengerLocationService,
    TrackingGateway,
    WsAuthGuard,
    WsRateLimitGuard,
    LocationGuardInterceptor,
  ],
  exports: [TrackingService, TrackingGateway],
})
export class TrackingModule {}
