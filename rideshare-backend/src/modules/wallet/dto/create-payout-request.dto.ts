import {
  IsNumber,
  IsOptional,
  IsString,
  Min,
  Matches,
  MaxLength,
} from 'class-validator';

export class CreatePayoutRequestDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(1)
  amount: number;

  @IsOptional()
  @IsString()
  @Matches(/^[A-Z]{3}$/)
  currency?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  bankAccountRef?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  note?: string;
}
