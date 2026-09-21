import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { AdminFinesService } from './admin-fines.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { PgUserRole } from '../../database/entities/shared.enums';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PendingChargeStatus } from '../../database/entities/pending-charge.entity';

export class CreateFineDto {
  @IsUUID()
  driverId: string;

  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  amount: number;

  @IsString()
  @MaxLength(2000)
  reason: string;

  @IsUUID()
  @IsOptional()
  tripId?: string;

  @IsUUID()
  @IsOptional()
  bookingId?: string;
}

export class ListFinesQueryDto {
  @IsEnum(PendingChargeStatus)
  @IsOptional()
  status?: PendingChargeStatus;

  @IsUUID()
  @IsOptional()
  driverId?: string;

  @IsString()
  @IsOptional()
  from?: string;

  @IsString()
  @IsOptional()
  to?: string;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  page?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  limit?: number;
}

@ApiTags('Admin — Fines')
@ApiBearerAuth()
@Controller('admin/fines')
@Roles(PgUserRole.ADMIN)
export class AdminFinesController {
  constructor(private readonly service: AdminFinesService) {}

  @Get()
  @ApiOperation({ summary: 'List driver fines (admin queue)' })
  @ApiQuery({ name: 'status', required: false, enum: PendingChargeStatus })
  @ApiQuery({ name: 'driverId', required: false })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Paginated list of fines' })
  list(@Query() query: ListFinesQueryDto) {
    return this.service.list(query);
  }

  @Post()
  @ApiOperation({ summary: 'Issue a manual fine to a driver' })
  @ApiResponse({ status: 201, description: 'Fine created' })
  create(@Body() dto: CreateFineDto, @CurrentUser() admin: { id: string }) {
    return this.service.create(admin.id, dto);
  }

  @Patch(':id/waive')
  @ApiOperation({ summary: 'Waive a fine' })
  @ApiResponse({ status: 200, description: 'Fine waived' })
  @ApiResponse({ status: 400, description: 'Fine is not pending' })
  @ApiResponse({ status: 404, description: 'Fine not found' })
  waive(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() admin: { id: string },
  ) {
    return this.service.waive(id, admin.id);
  }
}
