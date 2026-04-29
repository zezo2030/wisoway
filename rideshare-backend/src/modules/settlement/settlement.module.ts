import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BookingEntity } from '../../database/entities/booking.entity';
import { SettlementAuditEntity } from '../../database/entities/settlement-audit.entity';
import { CallSessionEntity } from '../../database/entities/call-session.entity';
import { ChatRoomEntity } from '../../database/entities/chat-room.entity';
import { MessageEntity } from '../../database/entities/message.entity';
import { SettlementService } from './settlement.service';
import { SettlementController } from './settlement.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      BookingEntity,
      SettlementAuditEntity,
      CallSessionEntity,
      ChatRoomEntity,
      MessageEntity,
    ]),
    NotificationsModule,
  ],
  controllers: [SettlementController],
  providers: [SettlementService],
  exports: [SettlementService],
})
export class SettlementModule {}
