import { IsString, IsOptional, IsEnum } from 'class-validator';
import { UserRole } from '../schemas/user.schema';

export class UpdateProfileDto {
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsString()
  fcmToken?: string;
}
