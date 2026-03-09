import { PaginationDto } from '../../../common/dto/pagination.dto';
import { IsNumber, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class LocationBasedTripsDto extends PaginationDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  longitude: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(300)
  @Type(() => Number)
  radiusKm?: number;
}
