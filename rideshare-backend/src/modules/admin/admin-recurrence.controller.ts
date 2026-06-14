/**
 * Phase 6 / T124 — Admin endpoint: POST /admin/recurrence-rules/:id/spawn-now
 *
 * Optional ops-debugging endpoint that immediately enqueues a spawn-occurrences
 * job for a specific recurrence rule, bypassing the hourly cron cadence.
 *
 * See contracts/recurrence.contract.md "Spawn triggers".
 */

import {
  Controller,
  Post,
  Param,
  NotFoundException,
  UseGuards,
  Logger,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TripRecurrenceRuleEntity } from '../../database/entities/trip-recurrence-rule.entity';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('admin')
@Controller('admin/recurrence-rules')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@ApiBearerAuth()
export class AdminRecurrenceController {
  private readonly logger = new Logger(AdminRecurrenceController.name);

  constructor(
    @InjectRepository(TripRecurrenceRuleEntity)
    private ruleRepo: Repository<TripRecurrenceRuleEntity>,
    @InjectQueue('recurrence-spawn')
    private recurrenceSpawnQueue: Queue,
  ) {}

  /**
   * POST /admin/recurrence-rules/:id/spawn-now
   *
   * Immediately enqueues a recurrence-spawn job for the given rule.
   * Useful for ops debugging or manually triggering a missed spawn window.
   * Does NOT require the rule to be active (admin override).
   */
  @Post(':id/spawn-now')
  @ApiOperation({
    summary: 'Immediately trigger spawn for a recurrence rule (ops debug)',
  })
  @ApiResponse({ status: 200, description: 'Spawn job enqueued' })
  @ApiResponse({ status: 404, description: 'Rule not found' })
  async spawnNow(@Param('id') id: string) {
    const rule = await this.ruleRepo.findOne({ where: { id } });
    if (!rule) {
      throw new NotFoundException('Recurrence rule not found');
    }

    const job = await this.recurrenceSpawnQueue.add(
      'spawn-occurrences',
      {},
      {
        jobId: `admin-spawn-now-${id}-${Date.now()}`,
        removeOnComplete: true,
        attempts: 1,
      },
    );

    this.logger.log(
      `Admin triggered spawn-now for rule ${id}: jobId=${job.id}`,
    );

    return {
      success: true,
      message: 'Spawn job enqueued',
      ruleId: id,
      jobId: job.id,
    };
  }
}
