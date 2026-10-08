import { OmitType } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { RegisterDriverDto } from './register-driver.dto';

/**
 * A signed-in passenger turning their own account into a driver account
 * ("انضم كسائق"). Same driver and vehicle details as a fresh registration,
 * minus what the account already has: the verified phone (registration
 * token), the password and the device binding.
 */
export class BecomeDriverDto extends OmitType(RegisterDriverDto, [
  'registrationToken',
  'password',
  'name',
  'device',
] as const) {
  /** Optional: keeps the account's current name when omitted. */
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MinLength(1)
  @MaxLength(120)
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  name?: string;
}
