import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bull';
import { InjectRepository } from '@nestjs/typeorm';
import type { Queue } from 'bull';
import { In, LessThan, Repository } from 'typeorm';
import { TripEntity } from '../database/entities/trip.entity';
import { TripStatus, TripType } from '../database/entities/shared.enums';
import {
  TRIP_AUTO_COMPLETE_JOB_ID_PREFIX,
  TRIP_AUTO_START_JOB_ID_PREFIX,
  tripAutoCompleteFallbackMs,
} from '../modules/trips/trip-auto-start.util';

/** How late a lifecycle job may be before the sweep steps in. */
export const TRIP_LIFECYCLE_SWEEP_GRACE_MS = 2 * 60 * 1000;

/**
 * Safety net for the per-trip `trip-auto-start` / `trip-auto-complete` jobs.
 *
 * Those are one-shot delayed Bull jobs scheduled when a trip is created. If a
 * job is lost (Redis restarted or evicted it) or exhausted its attempts, the
 * trip stays "published" forever: it keeps showing as current on the driver's
 * home, can never be rated, and can't be deleted. Shared trips past their time
 * were found in production in exactly that state.
 *
 * The sweep only re-queues (or retries) the same jobs, so the start/complete
 * logic stays in one place — the processors.
 */
@Injectable()
export class TripLifecycleSweepJob {
  private readonly logger = new Logger(TripLifecycleSweepJob.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectQueue('trip-auto-start') private readonly autoStartQueue: Queue,
    @InjectQueue('trip-auto-complete')
    private readonly autoCompleteQueue: Queue,
  ) {}

  @Cron(CronExpression.EVERY_5_MINUTES)
  async sweep(now: Date = new Date()): Promise<number> {
    const startCutoff = new Date(now.getTime() - TRIP_LIFECYCLE_SWEEP_GRACE_MS);
    const overdueStarts = await this.tripRepo.find({
      where: {
        tripType: TripType.SCHEDULED,
        status: In([
          TripStatus.PUBLISHED,
          TripStatus.FULLY_BOOKED,
          TripStatus.ACTIVE,
        ]),
        departureTime: LessThan(startCutoff),
      },
      select: ['id'],
    });

    const completeCutoff = new Date(
      startCutoff.getTime() - tripAutoCompleteFallbackMs(),
    );
    const overdueCompletes = await this.tripRepo.find({
      where: {
        tripType: TripType.SCHEDULED,
        status: TripStatus.IN_PROGRESS,
        departureTime: LessThan(completeCutoff),
      },
      select: ['id'],
    });

    let requeued = 0;
    for (const { id } of overdueStarts) {
      if (
        await this.ensureJob(
          this.autoStartQueue,
          `${TRIP_AUTO_START_JOB_ID_PREFIX}${id}`,
          id,
        )
      )
        requeued++;
    }
    for (const { id } of overdueCompletes) {
      if (
        await this.ensureJob(
          this.autoCompleteQueue,
          `${TRIP_AUTO_COMPLETE_JOB_ID_PREFIX}${id}`,
          id,
        )
      )
        requeued++;
    }
    if (requeued > 0) {
      this.logger.warn(`Re-queued ${requeued} overdue trip lifecycle job(s)`);
    }
    return requeued;
  }

  /**
   * Makes sure the trip's job will run now. A job still waiting, delayed or
   * running is left alone; a failed one is retried; a missing one is added
   * (Bull ignores adding a jobId that still exists, hence the lookup).
   * Returns whether anything was (re-)queued.
   */
  private async ensureJob(
    queue: Queue,
    jobId: string,
    tripId: string,
  ): Promise<boolean> {
    try {
      const job = await queue.getJob(jobId);
      if (job) {
        const state = await job.getState();
        if (state === 'failed') {
          await job.retry();
          return true;
        }
        if (state !== 'completed') return false;
        await job.remove();
      }
      await queue.add(
        'enforce',
        { tripId },
        {
          jobId,
          removeOnComplete: true,
          attempts: 2,
          backoff: { type: 'exponential', delay: 15000 },
        },
      );
      return true;
    } catch (err) {
      this.logger.warn(
        `Could not re-queue ${jobId}: ${(err as Error).message}`,
      );
      return false;
    }
  }
}
