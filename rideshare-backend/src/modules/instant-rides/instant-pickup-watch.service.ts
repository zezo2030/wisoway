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
 * «وصلت إلى الراكب», they are told to head there now — and that repeated
 * lateness is fined. Reminders repeat a few times per ride.
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
   * passenger, and lines up the next reminder. A no-op once they arrived,
   * started, or the ride ended.
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
    await this.requestRepo.update(
      { id: request.id },
      {
        lateWarningCount: request.lateWarningCount + 1,
        lateWarnedAt: request.lateWarnedAt ?? now,
      },
    );

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
    const push = lateWarningText(locale, lateRides);
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
      })}`,
    );

    if (attempt < PICKUP_LATE_MAX_WARNINGS) {
      await this.schedule(tripId, request.pickupEtaSeconds, attempt + 1);
    }
  }
}

/**
 * The driver's warning. A first late ride is a nudge; from the second within
 * [LATE_REPEAT_WINDOW_DAYS] days the count is spelled out.
 */
export function lateWarningText(
  locale: 'ar' | 'en',
  lateRides: number,
): { title: string; body: string } {
  if (locale === 'en') {
    return {
      title: 'You are late for your passenger',
      body:
        lateRides > 1
          ? `Late ride #${lateRides} in ${LATE_REPEAT_WINDOW_DAYS} days. Head to the pickup now — repeated lateness is fined.`
          : 'Your passenger is waiting. Head to the pickup now — repeated lateness is fined.',
    };
  }
  return {
    title: 'تأخرت على الراكب',
    body:
      lateRides > 1
        ? `هذا تأخرك رقم ${lateRides} خلال ${LATE_REPEAT_WINDOW_DAYS} يوماً. توجّه فوراً إلى الراكب، فتكرار التأخير يعرّضك لمخالفة.`
        : 'الراكب بانتظارك. توجّه فوراً إلى نقطة الانطلاق، فتكرار التأخير يعرّضك لمخالفة.',
  };
}
