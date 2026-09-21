import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class WebTokenDto {
  @ApiProperty({ description: 'FCM web registration token' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  token: string;

  @ApiPropertyOptional({ description: 'Browser user agent for token hygiene' })
  @IsString()
  @IsOptional()
  @MaxLength(255)
  userAgent?: string;
}
