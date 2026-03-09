import {
  IsString,
  IsNumber,
  IsEnum,
  IsOptional,
  IsPositive,
  MaxLength,
  IsMongoId,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateCommunicationFeeDto {
  @ApiProperty({
    description: 'Booking ID to pay communication fee for',
    example: '507f1f77bcf86cd799439012',
  })
  @IsString()
  @IsMongoId()
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
