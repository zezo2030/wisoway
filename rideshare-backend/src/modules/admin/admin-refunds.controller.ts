import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiParam,
  ApiQuery,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { RefundsService } from '../refunds/refunds.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { PgUserRole } from '../../database/entities/shared.enums';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

export class AdminUpdateRefundBodyDto {
  @IsString()
  @IsIn(['contacted', 'resolved', 'rejected'])
  status: 'contacted' | 'resolved' | 'rejected';

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  adminNotes?: string;
}

/**
 * AdminRefundsController — T170 (Phase 8 / US6)
 *
 * GET   /admin/refund-requests       — admin queue listing
 * PATCH /admin/refund-requests/:id   — update status
 */
@ApiTags('Admin — Refunds')
@ApiBearerAuth()
@Controller('admin/refund-requests')
@Roles(PgUserRole.ADMIN)
export class AdminRefundsController {
  constructor(private readonly refundsService: RefundsService) {}

  @Get()
  @ApiOperation({ summary: 'List refund requests (admin queue)' })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'offset', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Refund requests listed' })
  async list(@Query() query: Record<string, string>) {
    return this.refundsService.listForAdmin({
      status: query.status,
      limit: query.limit ? parseInt(query.limit, 10) : undefined,
      offset: query.offset ? parseInt(query.offset, 10) : undefined,
    });
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update refund request status' })
  @ApiParam({ name: 'id', description: 'Refund request UUID' })
  @ApiResponse({ status: 200, description: 'Refund request updated' })
  @ApiResponse({ status: 404, description: 'Refund request not found' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AdminUpdateRefundBodyDto,
    @CurrentUser() admin: { id: string },
  ) {
    return this.refundsService.adminUpdate(id, admin.id, dto);
  }
}
