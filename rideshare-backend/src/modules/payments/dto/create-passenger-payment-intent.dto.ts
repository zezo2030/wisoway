import { IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreatePassengerPaymentIntentDto {
  @ApiProperty({ example: '123e4567-e89b-12d3-a456-426614174000' })
  @IsUUID()
  @IsNotEmpty()
  tripId: string;

  @ApiProperty({ example: '0-0' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(32)
  seatNumber: string;

  @ApiPropertyOptional({ example: 'EG', description: 'Pricing region' })
  @IsOptional()
  @IsString()
  @MaxLength(5)
  countryCode?: string;
}
