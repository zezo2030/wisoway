import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DriverLocationEntity, TripEntity } from '../../database/entities';
import { TrackingController } from './tracking.controller';
import { TrackingGateway } from './tracking.gateway';
import { TrackingService } from './tracking.service';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';

@Module({
  imports: [
    TypeOrmModule.forFeature([DriverLocationEntity, TripEntity]),
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_ACCESS_SECRET'),
      }),
    }),
  ],
  controllers: [TrackingController],
  providers: [TrackingService, TrackingGateway, WsAuthGuard, WsRateLimitGuard],
  exports: [TrackingService, TrackingGateway],
})
export class TrackingModule {}
