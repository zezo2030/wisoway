import { IsString, IsNotEmpty, IsUUID, IsBoolean, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateBookingDto {
  @ApiProperty({
    description: 'The ID of the trip to book',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @IsString()
  @IsNotEmpty()
  @IsUUID()
  tripId: string;

  @ApiProperty({
    description: 'The seat number to book (format: row-col, e.g., "0-0")',
    example: '0-0',
  })
  @IsString()
  @IsNotEmpty()
  seatNumber: string;

  @ApiPropertyOptional({
    description: 'Whether the passenger wants to share their phone number with the driver immediately',
    example: true,
  })
  @IsBoolean()
  @IsOptional()
  sharePhoneWithDriver?: boolean;
}
