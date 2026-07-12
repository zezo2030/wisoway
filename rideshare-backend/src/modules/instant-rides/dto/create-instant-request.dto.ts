import {
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class InstantPointDto {
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
  latitude: number;

  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;
}

export class CreateInstantRequestDto {
  @ValidateNested()
  @Type(() => InstantPointDto)
  from: InstantPointDto;

  @ValidateNested()
  @Type(() => InstantPointDto)
  to: InstantPointDto;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(8)
  seatCount?: number;
}
