import {
  IsString,
  IsNumber,
  IsInt,
  IsBoolean,
  IsOptional,
  IsUrl,
  IsIn,
  IsDateString,
  MaxLength,
  Min,
  Max,
  ValidateNested,
  IsArray,
  ArrayMaxSize,
  IsEnum,
  ValidateIf,
} from 'class-validator';
import { Type } from 'class-transformer';

export class LocationDto {
  @IsString()
  @MaxLength(255)
  name: string;

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  address?: string;
}

export class StopDto {
  @IsString()
  @MaxLength(160)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  address?: string;

  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  order: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class RecurrenceDto {
  @IsEnum(['daily', 'weekly'])
  frequency: 'daily' | 'weekly';

  @ValidateIf((o) => o.frequency === 'weekly')
  @IsArray()
  @ArrayMaxSize(7)
  @IsString({ each: true })
  weekdays?: string[];

  @IsOptional()
  @IsDateString()
  until?: string;
}

export class CreateTripDto {
  @ValidateNested()
  @Type(() => LocationDto)
  from: LocationDto;

  @ValidateNested()
  @Type(() => LocationDto)
  to: LocationDto;

  @IsDateString()
  departureTime: string;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  price: number;

  @IsOptional()
  @IsIn(['EGP', 'JOD', 'SAR', 'AED', 'QAR'])
  currency?: string;

  @IsOptional()
  @IsUrl()
  carImageUrl?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => StopDto)
  stops?: StopDto[];

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => RecurrenceDto)
  recurrence?: RecurrenceDto;

  /**
   * Number of seats the driver wants to publish for this trip. Defaults to
   * every seat in the vehicle layout; must stay within 1..layout seat count.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  availableSeats?: number;

  /**
   * Per-trip gender-mixing rule. Overrides the vehicle default for this trip
   * only — the vehicle's own setting is never mutated.
   */
  @IsOptional()
  @IsBoolean()
  preventGenderMixing?: boolean;
}
