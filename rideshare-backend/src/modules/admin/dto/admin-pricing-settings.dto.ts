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
      'Passenger: percent of seat price collected from rider in-app wallet. 0 = no platform fee online (full seat price to driver as cash).',
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
