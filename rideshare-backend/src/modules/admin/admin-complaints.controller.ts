import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
  Request,
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
import { ComplaintsService } from '../complaints/complaints.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { PgUserRole } from '../../database/entities/shared.enums';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

export class AdminUpdateComplaintBodyDto {
  @IsString()
  @IsIn(['in_review', 'resolved', 'rejected'])
  status: 'in_review' | 'resolved' | 'rejected';

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  adminNotes?: string;
}

/**
 * AdminComplaintsController — T168 (Phase 8 / US6)
 *
 * GET   /admin/complaints       — filtered queue listing
 * PATCH /admin/complaints/:id   — update status + notify reporter
 */
@ApiTags('Admin — Complaints')
@ApiBearerAuth()
@Controller('admin/complaints')
@Roles(PgUserRole.ADMIN)
export class AdminComplaintsController {
  constructor(private readonly complaintsService: ComplaintsService) {}

  @Get()
  @ApiOperation({ summary: 'List complaints (admin queue)' })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'category', required: false })
  @ApiQuery({ name: 'from', required: false, description: 'ISO date string' })
  @ApiQuery({ name: 'to', required: false, description: 'ISO date string' })
  @ApiQuery({
    name: 'cursor',
    required: false,
    description: 'Complaint UUID for cursor pagination',
  })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Complaints listed' })
  async list(@Query() query: Record<string, string>) {
    return this.complaintsService.listForAdmin({
      status: query.status,
      category: query.category,
      from: query.from,
      to: query.to,
      cursor: query.cursor,
      limit: query.limit ? parseInt(query.limit, 10) : undefined,
    });
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update complaint status' })
  @ApiParam({ name: 'id', description: 'Complaint UUID' })
  @ApiResponse({ status: 200, description: 'Complaint updated' })
  @ApiResponse({ status: 404, description: 'Complaint not found' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AdminUpdateComplaintBodyDto,
    @CurrentUser() admin: { id: string },
  ) {
    return this.complaintsService.adminUpdate(id, admin.id, dto as any);
  }
}
