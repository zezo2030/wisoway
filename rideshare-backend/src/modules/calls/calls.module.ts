import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { BookingEntity } from '../../database/entities/booking.entity';
import { CallSessionEntity } from '../../database/entities/call-session.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { CallsService } from './calls.service';
import { CallsController } from './calls.controller';
import { ProxyPoolService } from './proxy-pool.service';

@Module({
  imports: [
    ConfigModule,
    TypeOrmModule.forFeature([BookingEntity, CallSessionEntity, UserEntity]),
  ],
  controllers: [CallsController],
  providers: [CallsService, ProxyPoolService],
  exports: [CallsService, ProxyPoolService],
})
export class CallsModule {}
