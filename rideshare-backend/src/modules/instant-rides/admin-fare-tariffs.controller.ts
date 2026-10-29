import { Body, Controller, Delete, Get, Param, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsNumber, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { Roles } from '../../common/decorators/roles.decorator';
import { InstantFareTariffService } from './instant-fare-tariff.service';

/** Amounts in the currency's main unit (JOD, not qirsh). */
export class AdminPatchFareTariffDto {
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) base?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) perKm?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) perMin?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) waitPerMin?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) freeWaitMin?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) minimum?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0.01) step?: number;
}

@ApiTags('admin')
@ApiBearerAuth()
@Roles('admin')
@Controller('admin/instant-fare-tariffs')
export class AdminFareTariffsController {
  constructor(private readonly tariffs: InstantFareTariffService) {}

  @Get()
  @ApiOperation({ summary: 'Instant-ride tariff per currency' })
  list() {
    return this.tariffs.list();
  }

  @Patch(':currency')
  @ApiOperation({ summary: 'Set the instant-ride tariff for one currency' })
  update(
    @Param('currency') currency: string,
    @Body() dto: AdminPatchFareTariffDto,
  ) {
    return this.tariffs.update(currency, dto);
  }

  @Delete(':currency')
  @ApiOperation({ summary: 'Back to the default tariff for one currency' })
  reset(@Param('currency') currency: string) {
    return this.tariffs.reset(currency);
  }
}
