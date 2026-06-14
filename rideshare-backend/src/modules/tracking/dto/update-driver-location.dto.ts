import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

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

  /**
   * True when the mobile OS or a third-party app is spoofing GPS coordinates.
   * Detected by the mobile SDK (Android: `Location.isFromMockProvider()`;
   * iOS: check for developer-mode mock routes).
   * Set false when the location is genuine; omit when unknown.
   */
  @IsOptional()
  @IsBoolean()
  isMockLocation?: boolean;
}
