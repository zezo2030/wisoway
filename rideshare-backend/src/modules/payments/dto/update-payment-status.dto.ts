import { IsString, IsOptional, MaxLength, IsEnum } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class ApprovePaymentDto {
  @ApiPropertyOptional({
    description: 'Admin note for approval',
    example: 'Payment verified and approved',
  })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  adminNote?: string;
}

export class RejectPaymentDto {
  @ApiPropertyOptional({
    description: 'Rejection reason (required)',
    example: 'Invalid payment proof',
  })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  adminNote?: string;
}

export class QueryPaymentsDto {
  @ApiPropertyOptional({ description: 'Page number', default: 1, example: 1 })
  @IsString()
  @IsOptional()
  page?: number;

  @ApiPropertyOptional({
    description: 'Items per page',
    default: 20,
    example: 20,
  })
  @IsString()
  @IsOptional()
  limit?: number;

  @ApiPropertyOptional({
    description: 'Filter by status',
    enum: ['pending', 'approved', 'rejected', 'refunded'],
    example: 'pending',
  })
  @IsEnum(['pending', 'approved', 'rejected', 'refunded'])
  @IsOptional()
  status?: string;

  @ApiPropertyOptional({
    description: 'Filter by payment type',
    enum: ['trip', 'communication_fee'],
    example: 'trip',
  })
  @IsEnum(['trip', 'communication_fee'])
  @IsOptional()
  paymentType?: string;
}
