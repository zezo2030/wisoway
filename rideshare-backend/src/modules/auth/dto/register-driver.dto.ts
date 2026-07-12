import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsIn,
  IsInt,
  Matches,
  MaxLength,
  MinLength,
  Min,
  Max,
  ValidateNested,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { VerifyOtpDeviceDto } from './verify-otp.dto';

/**
 * `purpose` claim embedded in the short-lived driver-registration JWT. Guards
 * against a registration token ever being accepted as an access token (and vice
 * versa) even though they share the signing secret.
 */
export const DRIVER_REGISTRATION_TOKEN_PURPOSE = 'driver_registration';

/** Lifetime of the driver-registration token (matches OTP-completion window). */
export const DRIVER_REGISTRATION_TOKEN_TTL_SECONDS = 30 * 60;

/**
 * Step 1 of deferred driver registration: confirm phone ownership via OTP
 * WITHOUT creating an account yet. The backend replies with a short-lived
 * registration token that authorizes the final register call (and the
 * registration image uploads).
 */
export class DriverVerifyPhoneDto {
  @IsString()
  @IsNotEmpty({ message: 'Phone number is required' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @Matches(/^\+[1-9]\d{1,14}$/, {
    message: 'Phone number must be in E.164 format (e.g., +201234567890)',
  })
  phoneNumber: string;

  @IsString()
  @IsNotEmpty({ message: 'OTP code is required' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @Matches(/^\d{4,6}$/, { message: 'OTP code must be 4 to 6 digits' })
  code: string;
}

/**
 * Final step of deferred driver registration. Everything needed to create the
 * driver account AND the vehicle arrives here so both rows are persisted in a
 * single transaction. The account does not exist until this call succeeds, so
 * an interrupted onboarding never leaves a half-created driver behind.
 */
export class RegisterDriverDto {
  /** Short-lived token issued by /auth/driver/verify-phone. */
  @IsString()
  @IsNotEmpty({ message: 'Registration token is required' })
  registrationToken: string;

  @IsString()
  @IsNotEmpty({ message: 'Name is required' })
  @MinLength(1)
  @MaxLength(120)
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  name: string;

  @IsOptional()
  @IsString()
  @IsIn(['male', 'female'])
  gender?: string;

  /** Driver profile photo URL (uploaded via /uploads/registration). */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  photoUrl?: string;

  @IsString()
  @MinLength(8)
  @MaxLength(100)
  @Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/, {
    message:
      'Password must be at least 8 characters with at least one letter and one number',
  })
  password: string;

  // ── Vehicle fields ───────────────────────────────────────────────────────
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  vehicleType: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  plateNumber: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  model: string;

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

  @IsString()
  @IsNotEmpty({ message: 'Car photo is required' })
  @MaxLength(500)
  carImageUrl: string;

  /** Optional device binding payload (same shape as verify-otp). */
  @IsOptional()
  @ValidateNested()
  @Type(() => VerifyOtpDeviceDto)
  device?: VerifyOtpDeviceDto;
}
