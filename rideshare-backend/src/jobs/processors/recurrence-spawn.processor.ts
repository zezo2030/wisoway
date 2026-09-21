/**
 * Phase 6 / T123 — RecurrenceSpawnProcessor
 *
 * Hourly cron-style BullMQ processor that spawns future Trip rows
 * from active TripRecurrenceRule records.
 *
 * See contracts/recurrence.contract.md "Spawn algorithm".
 */

import { Processor, Process, InjectQueue } from '@nestjs/bull';
import type { Job, Queue } from 'bull';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan, MoreThanOrEqual } from 'typeorm';
import { TripEntity } from '../../database/entities/trip.entity';
import {
  TripRecurrenceRuleEntity,
  RecurrenceFrequency,
} from '../../database/entities/trip-recurrence-rule.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { NotificationsService } from '../../modules/notifications/notifications.service';
import { Logger } from '@nestjs/common';
import {
  computeTripAutoStartDelayMs,
  TRIP_AUTO_START_JOB_ID_PREFIX,
} from '../../modules/trips/trip-auto-start.util';

@Processor('recurrence-spawn')
export class RecurrenceSpawnProcessor {
  private readonly logger = new Logger(RecurrenceSpawnProcessor.name);

  constructor(
    @InjectRepository(TripRecurrenceRuleEntity)
    private ruleRepo: Repository<TripRecurrenceRuleEntity>,
    @InjectRepository(TripEntity)
    private tripRepo: Repository<TripEntity>,
    private notificationsService: NotificationsService,
    @InjectQueue('trip-auto-start')
    private tripAutoStartQueue: Queue,
  ) {}

  @Process('spawn-occurrences')
  async handleSpawn(job: Job<Record<string, never>>) {
    this.logger.log('Recurrence spawn sweep started');

    const rules = await this.ruleRepo.find({
      where: { isActive: true },
    });

    if (rules.length === 0) {
      this.logger.log('No active recurrence rules found');
      return;
    }

    const now = new Date();

    for (const rule of rules) {
      try {
        await this.spawnForRule(rule, now);
      } catch (err) {
        this.logger.error(
          `Failed to spawn for rule ${rule.id}: ${(err as Error).message}`,
        );
      }
    }

    this.logger.log(
      `Recurrence spawn sweep completed for ${rules.length} rules`,
    );
  }

  private async spawnForRule(rule: TripRecurrenceRuleEntity, now: Date) {
    const startDate = rule.lastSpawnedFor
      ? new Date(rule.lastSpawnedFor + 'T00:00:00+03:00')
      : new Date(rule.createdAt);

    const maxEnd = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
    const untilDate = rule.until
      ? new Date(rule.until + 'T23:59:59+03:00')
      : null;

    const endDate = untilDate && untilDate < maxEnd ? untilDate : maxEnd;

    const cursor = new Date(startDate);
    cursor.setDate(cursor.getDate() + 1);

    let spawned = 0;
    let skipped = 0;

    while (cursor <= endDate) {
      const shouldSpawn = this.shouldSpawnForDate(rule, cursor);
      if (shouldSpawn) {
        const departureTime = this.buildDepartureTime(rule, cursor);

        const existing = await this.tripRepo.findOne({
          where: {
            driverId: rule.driverId,
            departureTime,
          },
        });

        if (existing) {
          skipped++;
          this.logger.log(
            `recurrence_skip: rule=${rule.id} driver=${rule.driverId} date=${departureTime.toISOString()}`,
          );
        } else {
          await this.createTripFromRule(rule, departureTime);
          spawned++;
        }
      }

      cursor.setDate(cursor.getDate() + 1);
    }

    const endDay = endDate.toISOString().slice(0, 10);
    rule.lastSpawnedFor = endDay;
    await this.ruleRepo.save(rule);

    this.logger.log(
      `Rule ${rule.id}: spawned=${spawned} skipped=${skipped} lastSpawnedFor=${endDay}`,
    );
  }

  private shouldSpawnForDate(
    rule: TripRecurrenceRuleEntity,
    date: Date,
  ): boolean {
    if (rule.frequency === RecurrenceFrequency.DAILY) return true;

    const dayOfWeek = date.getDay();
    const bit = 1 << dayOfWeek;
    return (rule.weekdayMask & bit) !== 0;
  }

  private buildDepartureTime(rule: TripRecurrenceRuleEntity, date: Date): Date {
    const [h, m, s] = rule.localTime.split(':').map(Number);
    const dt = new Date(date);
    dt.setHours(h, m, s || 0, 0);
    return dt;
  }

  private async createTripFromRule(
    rule: TripRecurrenceRuleEntity,
    departureTime: Date,
  ): Promise<TripEntity> {
    const tpl = rule.templateJson;

    // The template layout describes the full vehicle shape, but the driver may
    // have published fewer seats than the layout allows (CreateTripDto.availableSeats).
    // Clamp so seats.length always matches totalSeats on spawned instances.
    const layoutSeats = this.generateSeatsFromLayout(tpl.seatLayout);
    const seats =
      tpl.totalSeats > 0 && tpl.totalSeats < layoutSeats.length
        ? layoutSeats.slice(0, tpl.totalSeats)
        : layoutSeats;
    const totalSeats = seats.length || tpl.totalSeats;

    const trip = this.tripRepo.create({
      driverId: rule.driverId,
      driverName: null,
      fromName: tpl.fromName,
      fromAddress: tpl.fromAddress ?? null,
      toName: tpl.toName,
      toAddress: tpl.toAddress ?? null,
      fromPoint: {
        type: 'Point' as const,
        coordinates: [tpl.fromPoint.lng, tpl.fromPoint.lat] as [number, number],
      },
      toPoint: {
        type: 'Point' as const,
        coordinates: [tpl.toPoint.lng, tpl.toPoint.lat] as [number, number],
      },
      departureTime,
      price: tpl.price,
      currency: tpl.currency ?? 'JOD',
      totalSeats,
      availableSeats: totalSeats,
      seatLayout: tpl.seatLayout,
      seats,
      stops: tpl.stops ?? [],
      notes: tpl.notes ?? null,
      status: TripStatus.PUBLISHED,
      isVisible: true,
      communicationFeeStatus: 'not_paid',
      carImageUrl: tpl.carImageUrl ?? null,
      recurrenceRuleId: rule.id,
    });

    const saved = await this.tripRepo.save(trip);

    this.notificationsService
      .enqueueCityFanout(saved.id)
      .catch((err) =>
        this.logger.warn(
          `Failed to enqueue city fanout for spawned trip ${saved.id}: ${err.message}`,
        ),
      );

    const delay = computeTripAutoStartDelayMs(saved.departureTime);
    this.tripAutoStartQueue
      .add(
        'enforce',
        { tripId: saved.id },
        {
          delay,
          jobId: `${TRIP_AUTO_START_JOB_ID_PREFIX}${saved.id}`,
          removeOnComplete: true,
          attempts: 2,
          backoff: { type: 'exponential', delay: 15000 },
        },
      )
      .catch((err) =>
        this.logger.warn(
          `trip-auto-start spawn failed ${saved.id}: ${(err as Error).message}`,
        ),
      );

    return saved;
  }

  private generateSeatsFromLayout(layout: any): any[] {
    if (!layout) return [];
    const list = layout.seatsPerRowList;
    if (list && list.length > 0) {
      const seats: any[] = [];
      for (let row = 0; row < list.length; row++) {
        for (let col = 0; col < list[row]; col++) {
          seats.push({
            seatNumber: `${row}-${col}`,
            userId: null,
            userName: null,
            gender: null,
            bookedAt: null,
            status: 'available',
          });
        }
      }
      return seats;
    }
    const seats: any[] = [];
    for (let row = 0; row < (layout.rows || 0); row++) {
      for (let col = 0; col < (layout.seatsPerRow || 0); col++) {
        seats.push({
          seatNumber: `${row}-${col}`,
          userId: null,
          userName: null,
          gender: null,
          bookedAt: null,
          status: 'available',
        });
      }
    }
    return seats;
  }
}
