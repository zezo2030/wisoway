import {
  IsEmail,
  IsString,
  MinLength,
  MaxLength,
  IsOptional,
  IsEnum,
  Matches,
} from 'class-validator';
import { Gender, UserRole } from '../../users/schemas/user.schema';

export class SignUpDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(100)
  password: string;

  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsString()
  @Matches(/^\+[1-9]\d{1,14}$/)
  phoneNumber: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}
