import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsBoolean,
  MaxLength,
  IsObject,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateNotificationDto {
  @ApiProperty({ description: 'User ID to send notification to' })
  @IsString()
  @IsNotEmpty()
  userId: string;

  @ApiProperty({ description: 'Notification type', example: 'booking_new' })
  @IsString()
  @IsNotEmpty()
  type: string;

  @ApiProperty({ description: 'Notification title', example: 'New Booking' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  title: string;

  @ApiPropertyOptional({ description: 'Notification body' })
  @IsString()
  @IsOptional()
  @MaxLength(1000)
  body?: string;

  @ApiPropertyOptional({ description: 'Additional data' })
  @IsObject()
  @IsOptional()
  data?: Record<string, any>;
}

export class NotificationQueryDto {
  @ApiPropertyOptional({ description: 'Filter by read status' })
  @IsBoolean()
  @IsOptional()
  isRead?: boolean;
}
