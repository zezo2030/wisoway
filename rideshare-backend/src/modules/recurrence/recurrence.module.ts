import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TripRecurrenceRuleEntity } from '../../database/entities/trip-recurrence-rule.entity';
import { RecurrenceService } from './recurrence.service';
import { RecurrenceController } from './recurrence.controller';

@Module({
  imports: [TypeOrmModule.forFeature([TripRecurrenceRuleEntity])],
  controllers: [RecurrenceController],
  providers: [RecurrenceService],
  exports: [RecurrenceService],
})
export class RecurrenceModule {}
