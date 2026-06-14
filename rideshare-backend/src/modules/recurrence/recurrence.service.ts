import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  TripRecurrenceRuleEntity,
  RecurrenceFrequency,
} from '../../database/entities/trip-recurrence-rule.entity';
import { UpdateRecurrenceRuleDto } from './dto/recurrence.dto';

const WEEKDAY_MAP: Record<string, number> = {
  sun: 1,
  mon: 2,
  tue: 4,
  wed: 8,
  thu: 16,
  fri: 32,
  sat: 64,
};

@Injectable()
export class RecurrenceService {
  private readonly logger = new Logger(RecurrenceService.name);

  constructor(
    @InjectRepository(TripRecurrenceRuleEntity)
    private ruleRepo: Repository<TripRecurrenceRuleEntity>,
  ) {}

  static weekdayMask(weekdays: string[]): number {
    return weekdays.reduce((acc, d) => acc | (WEEKDAY_MAP[d] ?? 0), 0);
  }

  static maskToWeekdays(mask: number): string[] {
    const result: string[] = [];
    for (const [name, bit] of Object.entries(WEEKDAY_MAP)) {
      if (mask & bit) result.push(name);
    }
    return result;
  }

  async createRule(
    driverId: string,
    templateJson: any,
    frequency: RecurrenceFrequency,
    weekdays: string[] | undefined,
    localTime: string,
    timezone: string,
    until: string | null,
  ): Promise<TripRecurrenceRuleEntity> {
    const rule = this.ruleRepo.create({
      driverId,
      templateJson,
      frequency,
      weekdayMask:
        frequency === RecurrenceFrequency.WEEKLY
          ? RecurrenceService.weekdayMask(weekdays ?? [])
          : 0,
      localTime,
      timezone,
      until,
      isActive: true,
    });

    return this.ruleRepo.save(rule);
  }

  async findByDriver(driverId: string): Promise<TripRecurrenceRuleEntity[]> {
    return this.ruleRepo.find({
      where: { driverId },
      order: { createdAt: 'DESC' },
    });
  }

  async findById(ruleId: string): Promise<TripRecurrenceRuleEntity> {
    const rule = await this.ruleRepo.findOne({ where: { id: ruleId } });
    if (!rule) throw new NotFoundException('Recurrence rule not found');
    return rule;
  }

  async update(
    ruleId: string,
    driverId: string,
    dto: UpdateRecurrenceRuleDto,
  ): Promise<TripRecurrenceRuleEntity> {
    const rule = await this.findById(ruleId);
    if (rule.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this rule');
    }

    if (dto.isActive !== undefined) rule.isActive = dto.isActive;
    if (dto.until !== undefined) rule.until = dto.until;
    if (dto.weekdays !== undefined) {
      rule.weekdayMask = RecurrenceService.weekdayMask(dto.weekdays);
    }

    return this.ruleRepo.save(rule);
  }

  async deactivate(ruleId: string, driverId: string): Promise<void> {
    const rule = await this.findById(ruleId);
    if (rule.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this rule');
    }
    rule.isActive = false;
    await this.ruleRepo.save(rule);
  }
}
