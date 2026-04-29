import {
  IsString,
  IsOptional,
  IsBoolean,
  MinLength,
  MaxLength,
} from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  photoUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  city?: string;

  /**
   * When true, in-app calls are routed through a Twilio proxy DID so the
   * other party never sees the user's real phone number.
   */
  @IsOptional()
  @IsBoolean()
  hidePhoneNumber?: boolean;
}
