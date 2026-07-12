import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { IsBooleanString, IsNumber, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';
import { Roles } from '../../common/decorators/roles.decorator';
import { PgUserRole } from '../../database/entities/shared.enums';
import { AdminNoShowService } from './admin-no-show.service';

export class ListNoShowReportsQueryDto {
  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  page?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  limit?: number;

  @IsBooleanString()
  @IsOptional()
  majorityOnly?: string;

  @IsBooleanString()
  @IsOptional()
  unfinedOnly?: string;
}

@ApiTags('Admin — No-Show Reports')
@ApiBearerAuth()
@Controller('admin/no-show-reports')
@Roles(PgUserRole.ADMIN)
export class AdminNoShowController {
  constructor(private readonly service: AdminNoShowService) {}

  @Get()
  @ApiOperation({
    summary:
      'List trips where one or more passengers reported the driver as absent',
  })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'majorityOnly', required: false })
  @ApiQuery({ name: 'unfinedOnly', required: false })
  @ApiResponse({
    status: 200,
    description: 'Aggregated no-show reports per trip',
  })
  list(@Query() query: ListNoShowReportsQueryDto) {
    return this.service.list({
      page: query.page,
      limit: query.limit,
      majorityOnly: query.majorityOnly === 'true',
      unfinedOnly: query.unfinedOnly === 'true',
    });
  }

  @Get(':tripId')
  @ApiOperation({
    summary: 'Per-booking detail for a single trip no-show report',
  })
  detail(@Param('tripId', ParseUUIDPipe) tripId: string) {
    return this.service.detail(tripId);
  }
}
