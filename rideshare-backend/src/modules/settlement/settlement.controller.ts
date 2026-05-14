import {
  Controller,
  Post,
  Param,
  Body,
  HttpCode,
  HttpStatus,
  Get,
} from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SettlementService } from './settlement.service';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminRevertDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

@Controller()
export class SettlementController {
  constructor(private readonly settlementService: SettlementService) {}

  /** POST /admin/bookings/:id/admin-revert-settlement — admin override */
  @Post('admin/bookings/:id/admin-revert-settlement')
  @HttpCode(HttpStatus.OK)
  @Roles('admin')
  async adminRevert(
    @Param('id') id: string,
    @Body() dto: AdminRevertDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.settlementService.adminRevert(
      id,
      actorId,
      dto.reason ?? 'No reason provided',
    );
  }

  /** GET /admin/bookings/:id/settlement-audits — admin audit trail */
  @Get('admin/bookings/:id/settlement-audits')
  @Roles('admin')
  async getAuditTrail(@Param('id') id: string) {
    return this.settlementService.getAuditTrail(id);
  }
}
