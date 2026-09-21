import { IsNumber, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class NearbyDriversQueryDto {
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
