import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreatePayoutRequestDto {
  @IsNumber()
  @Min(1)
  amount: number;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsString()
  bankAccountRef?: string;

  @IsOptional()
  @IsString()
  note?: string;
}
