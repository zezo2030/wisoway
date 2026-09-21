/**
 * Reconciliation sweep for the one platform-fee debit.
 *
 * The fee is charged when a trip flips to IN_PROGRESS, and for shared trips the
 * only thing that performs that flip is a delayed BullMQ job scheduled at
 * publish time. If that job is lost — a Redis restart without persistence, a
 * queue flush, a manual removal — the trip never starts, never completes and is
 * never charged. Both inline sweeps (TripTimeService.completeTrip and
 * TripAutoCompleteProcessor) are gated on the trip already being IN_PROGRESS,
 * so neither of them ever sees such a trip. Nothing else would.
 *
 * This job is the net under that hole: it looks for trips that are past their
 * departure time and still carry no fee stamp, and runs the same idempotent
 * charge. DriverTripFeeService.chargeAtTripStart short-circuits on the trip
 * stamp and on its `trip-fee:<tripId>` audit row, so overlapping with the
 * normal path — or with a previous run of this sweep — cannot double-charge.
 */
import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { DriverTripFeeService } from './driver-trip-fee.service';

/** How long after departureTime a trip has to still be unstamped before we act. */
const DEFAULT_GRACE_MINUTES = 60;

/**
 * How far back the sweep is willing to reach. Deliberately bounded: without a
 * floor, one deploy of this job would retroactively charge every historical
 * trip that was never billed under the old pay-to-unlock model. Anything older
 * than this window is a data question for an admin, not something a cron job
 * should quietly take money for.
 */
const DEFAULT_LOOKBACK_HOURS = 72;

/** Trips charged per run, so one bad window cannot stall the scheduler. */
const DEFAULT_BATCH_SIZE = 100;

/**
 * A cancelled trip never ran, so it is never charged. DRAFT trips were never
 * published and have no bookings; charging them would only write a 0.00 audit
 * row, but there is no reason to touch them at all.
 */
const EXCLUDED_STATUSES: readonly TripStatus[] = [
  TripStatus.CANCELLED,
  TripStatus.DRAFT,
];

export interface ReconciliationOutcome {
  scanned: number;
  recovered: number;
  failed: number;
}

@Injectable()
export class DriverTripFeeReconciliationJob {
  private readonly logger = new Logger(DriverTripFeeReconciliationJob.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    private readonly driverTripFee: DriverTripFeeService,
  ) {}

  /**
   * Every 30 minutes. The window itself is what is tuned in production, via
   * DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES / _LOOKBACK_HOURS / _BATCH — those
   * are read here at call time rather than at decoration time, because
   * decorators are evaluated while the module graph is being built, before
   * ConfigModule has loaded .env.
   */
  @Cron('*/30 * * * *')
  async reconcileUnchargedTrips(): Promise<ReconciliationOutcome> {
    const now = Date.now();
    const graceCutoff = new Date(
      now - this.envNumber('GRACE_MINUTES', DEFAULT_GRACE_MINUTES) * 60 * 1000,
    );
    const lookbackFloor = new Date(
      now -
        this.envNumber('LOOKBACK_HOURS', DEFAULT_LOOKBACK_HOURS) *
          60 *
          60 *
          1000,
    );

    const trips = await this.tripRepo
      .createQueryBuilder('trip')
      .where('trip.driverWalletChargeApplied IS NOT TRUE')
      .andWhere('trip.departureTime < :graceCutoff', { graceCutoff })
      .andWhere('trip.departureTime >= :lookbackFloor', { lookbackFloor })
      .andWhere('trip.status NOT IN (:...excludedStatuses)', {
        excludedStatuses: [...EXCLUDED_STATUSES],
      })
      .orderBy('trip.departureTime', 'ASC')
      .take(this.envNumber('BATCH', DEFAULT_BATCH_SIZE))
      .getMany();

    const outcome: ReconciliationOutcome = {
      scanned: trips.length,
      recovered: 0,
      failed: 0,
    };
    if (trips.length === 0) return outcome;

    this.logger.warn(
      `driver-trip-fee reconciliation: ${trips.length} trip(s) past departure with no fee stamp`,
    );

    for (const trip of trips) {
      try {
        const result = await this.driverTripFee.chargeAtTripStart(trip);
        // applied === false means the charge short-circuited on its own
        // idempotency — the money was already taken, nothing was recovered.
        if (result.applied) {
          outcome.recovered += 1;
          this.logger.log(
            `driver-trip-fee reconciliation: RECOVERED trip ${trip.id} — ` +
              `charged ${result.charged.toFixed(2)} ${result.currency}` +
              (result.pendingRemainder > 0
                ? `, ${result.pendingRemainder.toFixed(2)} recorded as a pending charge`
                : '') +
              (result.reason ? ` (${result.reason})` : ''),
          );
        }
      } catch (err) {
        // One trip must never stop the sweep: the next run picks this trip up
        // again, since a failed charge leaves it unstamped by design.
        outcome.failed += 1;
        this.logger.error(
          `driver-trip-fee reconciliation: trip ${trip.id} failed, will retry next run: ${(err as Error).message}`,
        );
      }
    }

    return outcome;
  }

  private envNumber(suffix: string, fallback: number): number {
    const raw = process.env[`DRIVER_TRIP_FEE_RECONCILE_${suffix}`];
    const parsed = Number(raw);
    return raw != null && raw !== '' && Number.isFinite(parsed) && parsed > 0
      ? parsed
      : fallback;
  }
}
