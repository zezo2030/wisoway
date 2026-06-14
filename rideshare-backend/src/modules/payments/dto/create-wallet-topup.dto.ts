import {
  IsNumber,
  IsString,
  IsOptional,
  IsIn,
  Min,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateWalletTopupDto {
  @ApiProperty({
    description: 'Amount to add to wallet',
    example: 100,
    minimum: 0.01,
  })
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ApiPropertyOptional({
    description: 'Currency code',
    default: 'JOD',
    maxLength: 5,
  })
  @IsString()
  @IsOptional()
  @MaxLength(5)
  currency?: string;

  @ApiProperty({ description: 'Payment method', enum: ['manual', 'cliq_a2a'] })
  @IsString()
  method: 'manual' | 'cliq_a2a';

  @ApiPropertyOptional({ description: 'Proof image URL (required for manual)' })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  proofImageUrl?: string;

  @ApiPropertyOptional({
    description: 'Wallet number or reference (for manual)',
  })
  @IsString()
  @IsOptional()
  @MaxLength(100)
  walletNumber?: string;

  @ApiPropertyOptional({
    description: 'CliQ alias type (required for cliq_a2a)',
    enum: ['ALIAS', 'MOBL'],
  })
  @IsString()
  @IsOptional()
  @IsIn(['ALIAS', 'MOBL'])
  aliasType?: 'ALIAS' | 'MOBL';

  @ApiPropertyOptional({
    description:
      'CliQ alias value — CliQ alias or mobile number (required for cliq_a2a)',
  })
  @IsString()
  @IsOptional()
  @MaxLength(100)
  aliasValue?: string;
}
