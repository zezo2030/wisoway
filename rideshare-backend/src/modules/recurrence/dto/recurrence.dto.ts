import {
  IsString,
  IsOptional,
  IsBoolean,
  IsEnum,
  IsArray,
  ArrayMaxSize,
  IsDateString,
  ValidateIf,
} from 'class-validator';
import { RecurrenceFrequency } from '../../../database/entities/trip-recurrence-rule.entity';

export class CreateRecurrenceDto {
  @IsEnum(RecurrenceFrequency)
  frequency: RecurrenceFrequency;

  @ValidateIf((o) => o.frequency === 'weekly')
  @IsArray()
  @ArrayMaxSize(7)
  @IsString({ each: true })
  weekdays?: string[];

  @IsOptional()
  @IsDateString()
  until?: string;
}

export class UpdateRecurrenceRuleDto {
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsDateString()
  until?: string | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(7)
  @IsString({ each: true })
  weekdays?: string[];
}
