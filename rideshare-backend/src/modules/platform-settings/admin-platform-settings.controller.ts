import { Body, Controller, Get, Patch } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiPropertyOptional,
  ApiTags,
} from '@nestjs/swagger';
import { IsNumber, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  PLATFORM_SETTINGS,
  PlatformSettingsService,
} from './platform-settings.service';

export class AdminPatchPlatformSettingsDto {
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(100)
  instantCommissionPercent?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(100)
  sharedCommissionPercent?: number;

  @ApiPropertyOptional({
    description:
      'Rating cut (%) for each instant ride the driver reaches the passenger late; 0 = warn only',
    minimum: PLATFORM_SETTINGS.lateRatingPenaltyPercent.min,
    maximum: PLATFORM_SETTINGS.lateRatingPenaltyPercent.max,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(PLATFORM_SETTINGS.lateRatingPenaltyPercent.min)
  @Max(PLATFORM_SETTINGS.lateRatingPenaltyPercent.max)
  lateRatingPenaltyPercent?: number;

  @ApiPropertyOptional({
    description:
      'Rating cut (%) for cancelling an instant ride after it was accepted (driver or passenger); 0 = off',
    minimum: PLATFORM_SETTINGS.cancelRatingPenaltyPercent.min,
    maximum: PLATFORM_SETTINGS.cancelRatingPenaltyPercent.max,
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(PLATFORM_SETTINGS.cancelRatingPenaltyPercent.min)
  @Max(PLATFORM_SETTINGS.cancelRatingPenaltyPercent.max)
  cancelRatingPenaltyPercent?: number;
}

@ApiTags('Admin')
@ApiBearerAuth()
@Controller('admin/platform-settings')
@Roles('admin')
export class AdminPlatformSettingsController {
  constructor(private readonly settings: PlatformSettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Operational settings editable from the dashboard' })
  get() {
    return this.settings.getAll();
  }

  @Patch()
  @ApiOperation({ summary: 'Update operational settings' })
  patch(@Body() dto: AdminPatchPlatformSettingsDto) {
    return this.settings.update(dto);
  }
}
