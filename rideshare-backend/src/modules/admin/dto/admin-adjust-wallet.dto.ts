import { IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class AdminAdjustWalletDto {
  @IsNumber()
  @Min(-1000000)
  amount: number;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
