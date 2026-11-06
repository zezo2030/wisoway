import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class PassengerLocationDto {
  @IsUUID()
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
  accuracyMeters?: number;

  /** Set by the app when the OS reports a spoofed position. */
  @IsOptional()
  @IsBoolean()
  isMockLocation?: boolean;
}
