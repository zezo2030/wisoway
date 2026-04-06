import {
  ArrayUnique,
  IsString,
  IsNotEmpty,
  IsUUID,
  IsBoolean,
  IsOptional,
  IsArray,
  MaxLength,
} from 'class-validator';
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
    description:
      'List of seat numbers for multi-seat booking (format: ["0-0", "0-1"])',
    example: ['0-0', '0-1'],
    type: [String],
  })
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsNotEmpty({ each: true })
  seatNumbers?: string[];

  @ApiPropertyOptional({
    description: 'Whether the passenger wants to share their phone number with the driver immediately',
    example: true,
  })
  @IsBoolean()
  @IsOptional()
  sharePhoneWithDriver?: boolean;

  @ApiPropertyOptional({
    description:
      'Idempotency key for wallet debit when a platform fee applies (recommended for retries)',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  @IsOptional()
  @IsString()
  @MaxLength(128)
  walletIdempotencyKey?: string;
}
