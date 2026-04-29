import { IsString, Matches, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class SignInDto {
  @IsString()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @Matches(/^\+[1-9]\d{1,14}$/, {
    message: 'Phone number must be in E.164 format (e.g., +201234567890)',
  })
  phoneNumber: string;

  @IsString()
  @MinLength(1)
  password: string;
}
