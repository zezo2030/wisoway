import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsIn,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RegisterDeviceDto {
  @ApiProperty({ description: 'FCM registration token' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  token: string;

  @ApiProperty({ description: 'Device platform', enum: ['android', 'ios'] })
  @IsString()
  @IsNotEmpty()
  @IsIn(['android', 'ios'])
  platform: 'android' | 'ios';

  @ApiPropertyOptional({ description: 'App version (semver)' })
  @IsString()
  @IsOptional()
  @MaxLength(32)
  appVersion?: string;
}
