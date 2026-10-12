import {
  IsString,
  IsOptional,
  IsBoolean,
  IsIn,
  Matches,
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
  @IsIn(['male', 'female'])
  gender?: string;

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

  /**
   * The passenger's own CliQ alias (e.g. ahmad@cliq) or mobile, used for
   * CliQ fare requests; empty clears it.
   */
  @IsOptional()
  @IsString()
  @MaxLength(100)
  @Matches(/^$|^[A-Za-z0-9._@\-+ ]{3,100}$/, {
    message: 'cliqAlias must be a CliQ alias or mobile number',
  })
  cliqAlias?: string;
}
