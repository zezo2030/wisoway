import { IsString, Matches, IsNotEmpty } from 'class-validator';
import { Transform } from 'class-transformer';

export class ResetPasswordDto {
  @IsString()
  @IsNotEmpty({ message: 'Reset token is required' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  resetToken: string;

  @IsString()
  @IsNotEmpty({ message: 'New password is required' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/, {
    message:
      'Password must be at least 8 characters with at least one letter and one number',
  })
  newPassword: string;
}
