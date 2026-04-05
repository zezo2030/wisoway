import { IsString, Matches, IsNotEmpty } from 'class-validator';
import { Transform } from 'class-transformer';

export class VerifyResetOtpDto {
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
  @Matches(/^\d{6}$/, { message: 'OTP code must be exactly 6 digits' })
  code: string;
}
