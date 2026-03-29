import {
  IsString,
  IsNumber,
  IsInt,
  IsOptional,
  IsUrl,
  IsBoolean,
  IsIn,
  IsDateString,
  MaxLength,
  Min,
  Max,
  ValidateNested,
  IsArray,
  ArrayMaxSize,
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

export class SeatLayoutDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  rows: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  seatsPerRow: number;

  @IsOptional()
  @IsBoolean()
  preventGenderMixing?: boolean;

  /** Variable seats per row (mobile app custom layout); when set, used to build the seat grid. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(10, { each: true })
  seatsPerRowList?: number[];
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

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  totalSeats: number;

  @ValidateNested()
  @Type(() => SeatLayoutDto)
  seatLayout: SeatLayoutDto;

  @IsOptional()
  @IsUrl()
  carImageUrl?: string;
}
