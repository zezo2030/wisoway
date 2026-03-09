import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { ChatPostgresService } from './chat-postgres.service';
import { ChatPostgresController } from './chat-postgres.controller';
import { ChatPostgresGateway } from './chat-postgres.gateway';
import { PaymentsModule } from '../payments/payments.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';

@Module({
  imports: [
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_ACCESS_SECRET'),
      }),
    }),
    TypeOrmModule.forFeature([
      ChatRoomEntity,
      MessageEntity,
      TripEntity,
      BookingEntity,
      UserEntity,
    ]),
    forwardRef(() => PaymentsModule),
    forwardRef(() => NotificationsModule),
  ],
  controllers: [ChatPostgresController],
  providers: [
    ChatPostgresService,
    ChatPostgresGateway,
    WsAuthGuard,
    WsRateLimitGuard,
  ],
  exports: [ChatPostgresService],
})
export class ChatPostgresModule {}
