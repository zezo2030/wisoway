import {
  IsString,
  IsNumber,
  IsEnum,
  IsOptional,
  IsPositive,
  MaxLength,
  IsUUID,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateCommunicationFeeDto {
  @ApiProperty({
    description: 'Booking ID to pay communication fee for',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @IsString()
  @IsUUID()
  bookingId: string;

  @ApiProperty({
    description: 'Payment method',
    enum: ['stripe', 'manual'],
    example: 'manual',
  })
  @IsEnum(['stripe', 'manual'])
  method: string;

  @ApiPropertyOptional({
    description: 'Proof image URL (required for manual payments)',
    example: 'https://s3.amazonaws.com/bucket/proof.jpg',
  })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  proofImageUrl?: string;
}
