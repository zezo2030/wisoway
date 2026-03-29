import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserEntity } from '../../database/entities/user.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { WalletTransactionEntity } from '../../database/entities/wallet-transaction.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { RatingEntity } from '../../database/entities/rating.entity';
import { NotificationEntity } from '../../database/entities/notification.entity';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminDashboardService } from './admin-dashboard.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { BookingsModule } from '../bookings/bookings.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserEntity,
      TripEntity,
      VehicleEntity,
      PaymentEntity,
      WalletTransactionEntity,
      BookingEntity,
      RatingEntity,
      NotificationEntity,
      ChatRoomEntity,
      MessageEntity,
      CommunicationFeeEntity,
    ]),
    NotificationsModule,
    BookingsModule,
  ],
  controllers: [AdminDashboardController],
  providers: [AdminDashboardService],
  exports: [AdminDashboardService],
})
export class AdminModule {}
