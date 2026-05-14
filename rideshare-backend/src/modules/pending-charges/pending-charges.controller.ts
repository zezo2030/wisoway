/**
 * PendingChargesController
 *
 * GET  /me/pending-charges          — passenger views own outstanding charges
 * POST /admin/pending-charges/:id/waive — admin waives a single charge
 *
 * Phase 4 / T076–T077 — 008-platform-completion, US2 / 010-booking-lifecycle.
 */
import { Controller, Get, Post, Param, Query, UseGuards } from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { PendingChargesService } from './pending-charges.service';
import { PendingChargeStatus } from '../../database/entities/pending-charge.entity';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('pending-charges')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class PendingChargesController {
  constructor(private readonly service: PendingChargesService) {}

  // ── T076 ──────────────────────────────────────────────────────────────────

  @Get('me/pending-charges')
  @Roles('passenger', 'driver')
  @ApiOperation({ summary: 'List your outstanding pending charges' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: PendingChargeStatus,
  })
  @ApiResponse({
    status: 200,
    description: 'Paginated list of pending charges',
  })
  async getMyCharges(
    @Query() pagination: PaginationDto,
    @Query('status') status: PendingChargeStatus | undefined,
    @CurrentUser('id') userId: string,
  ) {
    return this.service.findByUser(userId, {
      page: pagination.page ?? 1,
      limit: pagination.limit ?? 20,
      status,
    });
  }

  /**
   * Manually trigger wallet collection of the caller's outstanding (PENDING)
   * pending charges. Returns counts so the client can refresh and show a
   * meaningful message ("paid", "still pending — top up needed").
   */
  @Post('me/pending-charges/collect')
  @Roles('passenger', 'driver')
  @ApiOperation({
    summary: "Settle caller's outstanding pending charges from wallet",
  })
  @ApiResponse({
    status: 200,
    description: 'Collection attempted',
  })
  async collectMyCharges(@CurrentUser('id') userId: string) {
    const { applied, skipped } = await this.service.collectOutstanding(
      userId,
      null,
    );
    return {
      appliedCount: applied.length,
      skippedCount: skipped.length,
      appliedTotal: applied.reduce((s, c) => s + Number(c.amount ?? 0), 0),
      skippedTotal: skipped.reduce((s, c) => s + Number(c.amount ?? 0), 0),
    };
  }

  // ── T077 ──────────────────────────────────────────────────────────────────

  @Post('admin/pending-charges/:id/waive')
  @Roles('admin')
  @ApiOperation({ summary: '[Admin] Waive a pending charge' })
  @ApiResponse({ status: 200, description: 'Charge waived' })
  @ApiResponse({ status: 400, description: 'Charge is not in pending status' })
  @ApiResponse({ status: 404, description: 'Charge not found' })
  async waive(
    @Param('id') chargeId: string,
    @CurrentUser('id') adminId: string,
  ) {
    return this.service.waive(chargeId, adminId);
  }
}
