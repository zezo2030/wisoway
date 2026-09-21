import { IsNumber, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

/** Route endpoints a per-seat price suggestion is requested for. */
export class PriceSuggestionQueryDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  fromLat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  fromLng: number;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  toLat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  toLng: number;
}
