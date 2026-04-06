import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { WalletEntryDirection } from '../../../database/entities/shared.enums';

export class AdminWalletAdjustDto {
  @ApiProperty({ enum: [WalletEntryDirection.CREDIT, WalletEntryDirection.DEBIT] })
  @IsEnum([WalletEntryDirection.CREDIT, WalletEntryDirection.DEBIT])
  direction: WalletEntryDirection.CREDIT | WalletEntryDirection.DEBIT;

  @ApiProperty({ minimum: 0.01, example: 10 })
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ApiProperty({ required: false, example: 'Manual adjustment by admin' })
  @IsOptional()
  @IsString()
  note?: string;

  @ApiProperty({ required: false, example: 'support-ticket-123' })
  @IsOptional()
  @IsString()
  referenceId?: string;
}

