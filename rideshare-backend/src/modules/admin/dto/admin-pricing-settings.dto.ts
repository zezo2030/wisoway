import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class AdminPatchPricingSettingsDto {
  @ApiPropertyOptional({ description: 'Legacy flat unlock fee when driverUnlockPercent is 0' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  feeAmount?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(5)
  currency?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({
    description:
      'Passenger: percent of seat price collected by platform online (Stripe). 0 = booking without paymentIntentId (full seat price shown as cash to driver).',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(100)
  passengerPlatformPercent?: number;

  @ApiPropertyOptional({
    description:
      'Driver: percent of (seat price × trip total seats) charged from wallet to unlock passenger data. 0 = use legacy flat feeAmount instead.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(100)
  driverUnlockPercent?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  lifetimeFreeTripEnabled?: boolean;
}
