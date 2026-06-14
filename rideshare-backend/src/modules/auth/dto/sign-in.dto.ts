import { IsEmail, IsString, Matches, MinLength, ValidateIf } from 'class-validator';
import { Transform } from 'class-transformer';

export class SignInDto {
  @ValidateIf((object, value) => value !== undefined || !object.email)
  @IsString()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @Matches(/^\+[1-9]\d{1,14}$/, {
    message: 'Phone number must be in E.164 format (e.g., +201234567890)',
  })
  phoneNumber?: string;

  @ValidateIf((object, value) => value !== undefined || !object.phoneNumber)
  @IsString()
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail({}, { message: 'Email must be a valid email address' })
  email?: string;

  @IsString()
  @MinLength(1)
  password: string;
}
