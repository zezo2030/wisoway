import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bull';
import { UserEntity } from '../../database/entities/user.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { WalletTransactionEntity } from '../../database/entities/wallet-transaction.entity';
import { WalletAccountEntity } from '../../database/entities/wallet-account.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { RatingEntity } from '../../database/entities/rating.entity';
import { NotificationEntity } from '../../database/entities/notification.entity';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { AccountFlagEntity } from '../../database/entities/account-flag.entity';
import { UserDeviceEntity } from '../../database/entities/user-device.entity';
import { SecurityEventEntity } from '../../database/entities/security-event.entity';
import { TripRecurrenceRuleEntity } from '../../database/entities/trip-recurrence-rule.entity';
import { ComplaintEntity } from '../../database/entities/complaint.entity';
import { RefundRequestEntity } from '../../database/entities/refund-request.entity';
import { PendingChargeEntity } from '../../database/entities/pending-charge.entity';
import { AdminDashboardController } from './admin-dashboard.controller';
import { AdminDashboardService } from './admin-dashboard.service';
import { AdminFlagsController } from './admin-flags.controller';
import { AdminFlagsService } from './admin-flags.service';
import { AdminRecurrenceController } from './admin-recurrence.controller';
import { AdminBanController } from './admin-ban.controller';
import { AdminBanService } from './admin-ban.service';
import { AdminComplaintsController } from './admin-complaints.controller';
import { AdminRefundsController } from './admin-refunds.controller';
import { AdminFinesController } from './admin-fines.controller';
import { AdminFinesService } from './admin-fines.service';
import { AdminNoShowController } from './admin-no-show.controller';
import { AdminNoShowService } from './admin-no-show.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { BookingsModule } from '../bookings/bookings.module';
import { WalletModule } from '../wallet/wallet.module';
import { AuthModule } from '../auth/auth.module';
import { ComplaintsModule } from '../complaints/complaints.module';
import { RefundsModule } from '../refunds/refunds.module';
import { PendingChargesModule } from '../pending-charges/pending-charges.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserEntity,
      TripEntity,
      VehicleEntity,
      PaymentEntity,
      WalletTransactionEntity,
      WalletAccountEntity,
      BookingEntity,
      RatingEntity,
      NotificationEntity,
      ChatRoomEntity,
      MessageEntity,
      CommunicationFeeEntity,
      AccountFlagEntity,
      UserDeviceEntity,
      SecurityEventEntity,
      TripRecurrenceRuleEntity,
      ComplaintEntity,
      RefundRequestEntity,
      PendingChargeEntity,
    ]),
    BullModule.registerQueue({ name: 'recurrence-spawn' }),
    NotificationsModule,
    BookingsModule,
    WalletModule,
    AuthModule,
    ComplaintsModule,
    RefundsModule,
    PendingChargesModule,
  ],
  controllers: [
    AdminDashboardController,
    AdminFlagsController,
    AdminRecurrenceController,
    AdminBanController,
    AdminComplaintsController,
    AdminRefundsController,
    AdminFinesController,
    AdminNoShowController,
  ],
  providers: [
    AdminDashboardService,
    AdminFlagsService,
    AdminBanService,
    AdminFinesService,
    AdminNoShowService,
  ],
  exports: [AdminDashboardService],
})
export class AdminModule {}
