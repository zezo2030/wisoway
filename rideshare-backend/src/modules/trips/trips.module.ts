import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
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
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';

@Module({
  imports: [
    TypeOrmModule.forFeature([TripEntity]),
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
    VehiclesModule,
    UsersModule,
  ],
  controllers: [TripsController],
  providers: [TripsService, TripsGateway, WsAuthGuard, WsRateLimitGuard],
  exports: [TripsService, TripsGateway],
})
export class TripsModule {}
