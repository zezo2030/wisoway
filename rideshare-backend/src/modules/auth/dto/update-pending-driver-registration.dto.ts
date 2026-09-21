import {
  IsString,
  IsOptional,
  IsInt,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Body of `PATCH /auth/driver/registration`. Lets a driver fix their submitted
 * details/documents while the account is still awaiting admin approval. Every
 * field is optional — only the keys present are written.
 */
export class UpdatePendingDriverRegistrationDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  photoUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  vehicleType?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  plateNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  model?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  seats?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  licenseImageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  vehicleLicenseImageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  insuranceImageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  carImageUrl?: string;
}
