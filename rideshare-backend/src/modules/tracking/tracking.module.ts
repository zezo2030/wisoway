import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  DriverLocationEntity,
  TripEntity,
  SecurityEventEntity,
  AccountFlagEntity,
} from '../../database/entities';
import { TrackingController } from './tracking.controller';
import { TrackingGateway } from './tracking.gateway';
import { TrackingService } from './tracking.service';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';
import { LocationGuardInterceptor } from '../../common/interceptors/location-guard.interceptor';
import { LocationsModule } from '../locations/locations.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      DriverLocationEntity,
      TripEntity,
      SecurityEventEntity,
      AccountFlagEntity,
    ]),
    ConfigModule,
    LocationsModule,
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
    TrackingGateway,
    WsAuthGuard,
    WsRateLimitGuard,
    LocationGuardInterceptor,
  ],
  exports: [TrackingService, TrackingGateway],
})
export class TrackingModule {}
