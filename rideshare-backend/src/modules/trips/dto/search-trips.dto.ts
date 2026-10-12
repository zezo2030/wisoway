import { PaginationDto } from '../../../common/dto/pagination.dto';
import {
  IsOptional,
  IsNumber,
  IsDateString,
  IsEnum,
  IsString,
  Length,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';

export class SearchTripsDto extends PaginationDto {
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  fromLatitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  fromLongitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  toLatitude?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  toLongitude?: number;

  @IsOptional()
  @IsDateString()
  departureDate?: string;

  /** Only trips leaving at or after this instant (every later day included). */
  @IsOptional()
  @IsDateString()
  departureAfter?: string;

  /**
   * ISO 3166-1 alpha-2 country the trips depart from — matched through the
   * trip's currency, which is resolved from its departure country.
   */
  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  minPrice?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  maxPrice?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Type(() => Number)
  availableSeats?: number;

  @IsOptional()
  @IsEnum(['active', 'hidden', 'completed', 'cancelled', 'expired'])
  status?: string;
}
