import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { MoreThanOrEqual, Repository } from 'typeorm';
import {
  InstantRideRequestEntity,
  TripEntity,
  TripStatus,
  TripType,
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.service';
import { RatingsService } from '../ratings/ratings.service';
import { PlatformSettingsService } from '../platform-settings/platform-settings.service';
import {
  INSTANT_REQUEST_EXPIRY_QUEUE,
  LATE_REPEAT_WINDOW_DAYS,
  PICKUP_LATE_CHECK_JOB,
  PICKUP_LATE_MAX_WARNINGS,
  pickupLateDelayMs,
  pickupLateJobId,
} from './instant-rides.constants';

export type PickupLateJob = { tripId: string; attempt: number };

/**
 * Keeps a matched driver honest on the way to the passenger: once the pickup
 * estimate plus a grace period has passed and the driver still hasn't pressed
 * «وصلت إلى الراكب», they are told to head there now. The first warning of a
 * ride also lowers their rating by the percentage the admin set on the
 * dashboard (no fines). Reminders repeat a few times per ride.
 */
@Injectable()
export class InstantPickupWatchService {
  private readonly logger = new Logger(InstantPickupWatchService.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(InstantRideRequestEntity)
    private readonly requestRepo: Repository<InstantRideRequestEntity>,
    private readonly notifications: NotificationsService,
    private readonly ratings: RatingsService,
    private readonly settings: PlatformSettingsService,
    @InjectQueue(INSTANT_REQUEST_EXPIRY_QUEUE)
    private readonly queue: Queue,
  ) {}

  /** Queue the [attempt]-th lateness check for a freshly matched ride. */
  async schedule(
    tripId: string,
    pickupEtaSeconds: number | null,
    attempt = 1,
  ): Promise<void> {
    await this.queue
      .add(PICKUP_LATE_CHECK_JOB, { tripId, attempt } satisfies PickupLateJob, {
        delay: pickupLateDelayMs(pickupEtaSeconds, attempt),
        jobId: pickupLateJobId(tripId, attempt),
        removeOnComplete: true,
        removeOnFail: true,
      })
      .catch((err: Error) =>
        this.logger.warn(`Failed to enqueue pickup-late check: ${err.message}`),
      );
  }

  /**
   * The check itself: warns the driver when they still haven't reached the
   * passenger, cuts their rating once per late ride, and lines up the next
   * reminder. A no-op once they arrived, started, or the ride ended.
   */
  async check({ tripId, attempt }: PickupLateJob): Promise<void> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (
      !trip ||
      trip.tripType !== TripType.INSTANT ||
      trip.status !== TripStatus.IN_PROGRESS ||
      trip.driverArrivedAt ||
      trip.tripStartedAt
    ) {
      return;
    }
    const request = await this.requestRepo.findOne({ where: { tripId } });
    if (!request) return;

    const now = new Date();
    const firstWarning = request.lateWarnedAt == null;
    const penaltyPercent = firstWarning
      ? await this.settings.getNumber('lateRatingPenaltyPercent')
      : 0;
    await this.requestRepo.update(
      { id: request.id },
      {
        lateWarningCount: request.lateWarningCount + 1,
        lateWarnedAt: request.lateWarnedAt ?? now,
        ...(penaltyPercent > 0
          ? { ratingPenaltyPercent: penaltyPercent.toFixed(2) }
          : {}),
      },
    );
    if (penaltyPercent > 0) {
      await this.ratings
        .applyRatingPenalty(trip.driverId, penaltyPercent)
        .catch((err: Error) =>
          this.logger.warn(`Rating penalty failed: ${err.message}`),
        );
    }

    // This ride included: how many of the driver's rides ran late lately.
    const lateRides = await this.requestRepo.count({
      where: {
        matchedDriverId: trip.driverId,
        lateWarnedAt: MoreThanOrEqual(
          new Date(now.getTime() - LATE_REPEAT_WINDOW_DAYS * 86_400_000),
        ),
      },
    });

    const locale = await this.notifications.getPreferredLocale(trip.driverId);
    const push = lateWarningText(locale, {
      lateRides,
      firstWarning,
      penaltyPercent,
    });
    this.notifications.emitRealtime(trip.driverId, 'instantPickupLate', {
      tripId,
      lateRides,
    });
    await this.notifications
      .sendPush(trip.driverId, {
        ...push,
        type: 'instant_pickup_late',
        data: { tripId, requestId: request.id, lateRides },
      })
      .catch(() => undefined);

    this.logger.log(
      `instant_pickup_late ${JSON.stringify({
        tripId,
        driverId: trip.driverId,
        attempt,
        lateRides,
        penaltyPercent,
      })}`,
    );

    if (attempt < PICKUP_LATE_MAX_WARNINGS) {
      await this.schedule(tripId, request.pickupEtaSeconds, attempt + 1);
    }
  }
}

/**
 * The driver's warning. The first one of a ride says what it cost (when the
 * admin set a cut) and, from the second late ride within
 * [LATE_REPEAT_WINDOW_DAYS] days, how many there have been; later reminders
 * of the same ride just say to hurry.
 */
export function lateWarningText(
  locale: 'ar' | 'en',
  opts: { lateRides: number; firstWarning: boolean; penaltyPercent: number },
): { title: string; body: string } {
  const { lateRides, firstWarning, penaltyPercent } = opts;
  const pct = Number(penaltyPercent.toFixed(2));
  if (locale === 'en') {
    if (!firstWarning) {
      return {
        title: 'Your passenger is still waiting',
        body: 'Head to the pickup now.',
      };
    }
    const count =
      lateRides > 1
        ? `Late ride #${lateRides} in ${LATE_REPEAT_WINDOW_DAYS} days. `
        : '';
    const cut = pct > 0 ? ` Your rating dropped ${pct}% for being late.` : '';
    return {
      title: 'You are late for your passenger',
      body: `${count}Your passenger is waiting — head to the pickup now.${cut}`,
    };
  }
  if (!firstWarning) {
    return {
      title: 'الراكب ما زال بانتظارك',
      body: 'توجّه فوراً إلى نقطة الانطلاق.',
    };
  }
  const count =
    lateRides > 1
      ? `هذا تأخرك رقم ${lateRides} خلال ${LATE_REPEAT_WINDOW_DAYS} يوماً. `
      : '';
  const cut = pct > 0 ? ` خُفِّض تقييمك ${pct}% بسبب التأخير.` : '';
  return {
    title: 'تأخرت على الراكب',
    body: `${count}الراكب بانتظارك، توجّه فوراً إلى نقطة الانطلاق.${cut}`,
  };
}
