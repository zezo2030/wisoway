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

  /** POST /bookings/:id/mark-paid — driver marks booking as paid */
  @Post('bookings/:id/mark-paid')
  @HttpCode(HttpStatus.OK)
  async markPaid(@Param('id') id: string, @CurrentUser('id') actorId: string) {
    return this.settlementService.markPaid(id, actorId);
  }

  /** POST /bookings/:id/unmark-paid — driver reverses within grace */
  @Post('bookings/:id/unmark-paid')
  @HttpCode(HttpStatus.OK)
  async unmarkPaid(
    @Param('id') id: string,
    @CurrentUser('id') actorId: string,
  ) {
    return this.settlementService.unmarkPaid(id, actorId);
  }

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
