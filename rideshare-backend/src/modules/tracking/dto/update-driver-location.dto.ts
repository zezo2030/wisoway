import { IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpdateDriverLocationDto {
  @IsString()
  tripId: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  speedKph?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(360)
  heading?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  accuracyMeters?: number;
}
