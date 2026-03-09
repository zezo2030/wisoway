import {
  IsString,
  IsNumber,
  IsEnum,
  IsOptional,
  IsPositive,
  Min,
  MaxLength,
  IsMongoId,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreatePaymentDto {
  @ApiProperty({ description: 'Trip ID', example: '507f1f77bcf86cd799439011' })
  @IsString()
  @IsMongoId()
  @IsOptional()
  tripId?: string;

  @ApiProperty({
    description: 'Booking ID',
    example: '507f1f77bcf86cd799439012',
  })
  @IsString()
  @IsMongoId()
  @IsOptional()
  bookingId?: string;

  @ApiProperty({ description: 'Payment amount', example: 100 })
  @IsNumber()
  @IsPositive()
  amount: number;

  @ApiPropertyOptional({
    description: 'Currency code',
    default: 'EGP',
    example: 'EGP',
  })
  @IsString()
  @IsOptional()
  @MaxLength(5)
  currency?: string;

  @ApiProperty({
    description: 'Payment method',
    enum: ['stripe', 'paymob', 'manual', 'cliq_a2a'],
    example: 'manual',
  })
  @IsEnum(['stripe', 'paymob', 'manual', 'cliq_a2a'])
  method: string;

  @ApiPropertyOptional({
    description: 'Proof image URL (required for manual payments)',
    example: 'https://s3.amazonaws.com/bucket/proof.jpg',
  })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  proofImageUrl?: string;

  @ApiPropertyOptional({
    description: 'Wallet number for manual payment',
    example: '01012345678',
  })
  @IsString()
  @IsOptional()
  @MaxLength(20)
  walletNumber?: string;
}
