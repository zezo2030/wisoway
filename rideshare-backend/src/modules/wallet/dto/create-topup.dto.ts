import { IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';

export class CreateTopupDto {
  @IsNumber()
  @Min(1)
  @Max(1000000)
  amount: number;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsString()
  idempotencyKey?: string;

  @IsOptional()
  @IsString()
  note?: string;
}
