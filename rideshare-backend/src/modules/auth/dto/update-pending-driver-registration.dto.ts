import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsInt,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';

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

  /** May be left out, but a registration's colour can't be cleared. */
  @IsOptional()
  @IsString()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsNotEmpty({ message: 'Vehicle color is required' })
  @MaxLength(40)
  color?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  seats?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  nationalIdImageUrl?: string;

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
