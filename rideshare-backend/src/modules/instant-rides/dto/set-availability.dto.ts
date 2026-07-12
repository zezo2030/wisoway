import { IsBoolean, IsNumber, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class SetAvailabilityDto {
  @IsBoolean()
  isOnline: boolean;

  @IsOptional()
  @IsBoolean()
  acceptsInstant?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;
}

export class HeartbeatDto {
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
