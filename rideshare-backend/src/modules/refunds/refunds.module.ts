import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RefundRequestEntity } from '../../database/entities/refund-request.entity';
import { RefundsController } from './refunds.controller';
import { RefundsService } from './refunds.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([RefundRequestEntity]),
    NotificationsModule,
  ],
  controllers: [RefundsController],
  providers: [RefundsService],
  exports: [RefundsService],
})
export class RefundsModule {}
