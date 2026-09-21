import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { In, IsNull, Repository } from 'typeorm';
import {
  DriverAvailabilityEntity,
  InstantOfferStatus,
  InstantRequestStatus,
  InstantRideOfferEntity,
  InstantRideRequestEntity,
  InstantTerminalReason,
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.service';
import {
  DriverAvailabilityService,
  NearbyDriver,
} from './driver-availability.service';
import {
  DISPATCH_RETRY_SECONDS,
  DISPATCH_WAVE_JOB,
  dispatchWaveJobId,
  EXPIRE_OFFER_JOB,
  INSTANT_OFFER_TIMEOUT_QUEUE,
  INITIAL_RADIUS_KM,
  INSTANT_REQUEST_EXPIRY_QUEUE,
  MAX_RADIUS_KM,
  OFFER_TTL_SECONDS,
  offerTimeoutJobId,
} from './instant-rides.constants';
import {
  buildInstantOfferPushText,
  buildInstantOfferRouteMetrics,
} from './instant-offer-labels';

/**
 * Sequential dispatch, inDrive style: offer to the nearest available driver,
 * one at a time. The search reach is a function of how long the passenger has
 * waited — [INITIAL_RADIUS_KM] at first, widening to [MAX_RADIUS_KM] by the
 * end of the window — so nearby drivers always get the first chance and
 * distant ones only come into play after the wait has stretched on.
 *
 * When a wave finds nobody the request stays alive: another wave fires a few
 * seconds later with a wider reach, and the passenger is nudged once to raise
 * the fare.
 */
@Injectable()
export class InstantDispatchService {
  private readonly logger = new Logger(InstantDispatchService.name);

  constructor(
    @InjectRepository(InstantRideRequestEntity)
    private readonly requestRepo: Repository<InstantRideRequestEntity>,
    @InjectRepository(InstantRideOfferEntity)
    private readonly offerRepo: Repository<InstantRideOfferEntity>,
    @InjectRepository(DriverAvailabilityEntity)
    private readonly availabilityRepo: Repository<DriverAvailabilityEntity>,
    private readonly availabilityService: DriverAvailabilityService,
    private readonly notifications: NotificationsService,
    @InjectQueue(INSTANT_OFFER_TIMEOUT_QUEUE)
    private readonly offerTimeoutQueue: Queue,
    @InjectQueue(INSTANT_REQUEST_EXPIRY_QUEUE)
    private readonly requestExpiryQueue: Queue,
  ) {}

  /** Offer the request to the next-nearest available driver, if any. */
  async dispatchNext(requestId: string): Promise<void> {
    const request = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (!request || request.status !== InstantRequestStatus.SEARCHING) {
      return;
    }
    if (request.expiresAt.getTime() <= Date.now()) {
      await this.finalizeSearch(request.id);
      return;
    }

    const [fromLng, fromLat] = request.fromPoint.coordinates;
    const priorOffers = await this.offerRepo.find({
      where: { requestId },
      select: ['driverId', 'status', 'fareRevision'],
    });
    // Skip drivers with an offer in flight — but drivers who declined/timed
    // out at an older fare revision become eligible again after a raise.
    const activeStatuses: string[] = [
      InstantOfferStatus.OFFERED,
      InstantOfferStatus.COUNTERED,
      InstantOfferStatus.ACCEPTED,
    ];
    const excludeDriverIds = [
      ...new Set(
        priorOffers
          .filter(
            (o) =>
              activeStatuses.includes(o.status) ||
              o.fareRevision >= request.fareRevision,
          )
          .map((o) => o.driverId),
      ),
    ];

    // The reach grows with how long the passenger has been waiting, so a
    // driver two streets away still wins the first seconds and a distant one
    // is only considered once nothing closer has turned up.
    const radiusKm = this.radiusForElapsed(request);
    if (radiusKm !== request.radiusKm) {
      await this.requestRepo.update({ id: requestId }, { radiusKm });
      request.radiusKm = radiusKm;
    }

    // One lookup per wave: the query already orders by distance, so a wider
    // circle never costs match quality — it only adds farther fallbacks after
    // the nearest ones. Ring-by-ring stepping would just repeat this query.
    const candidates =
      await this.availabilityService.findNearbyAvailableDrivers(
        fromLat,
        fromLng,
        radiusKm * 1000,
        { excludeDriverIds },
      );

    for (const candidate of candidates) {
      if (await this.tryLockDriver(candidate.driverId, requestId)) {
        await this.makeOffer(request, candidate);
        return;
      }
      // Lost the race for this driver — skip and try the next one.
      excludeDriverIds.push(candidate.driverId);
    }

    await this.handleEmptySweep(request);
  }

  /**
   * How far this request may reach right now: [INITIAL_RADIUS_KM] at the
   * moment it was created, widening linearly to [MAX_RADIUS_KM] by the time
   * the search window closes.
   *
   * Tying the growth to the window rather than a fixed step means the reach
   * always spreads over the whole wait, whatever the TTL is set to.
   */
  private radiusForElapsed(
    request: InstantRideRequestEntity,
    now: number = Date.now(),
  ): number {
    const start = request.createdAt?.getTime();
    const end = request.expiresAt?.getTime();
    if (start == null || end == null || end <= start) {
      return Math.max(request.radiusKm ?? INITIAL_RADIUS_KM, INITIAL_RADIUS_KM);
    }
    const progress = Math.min(1, Math.max(0, (now - start) / (end - start)));
    const grown =
      INITIAL_RADIUS_KM + (MAX_RADIUS_KM - INITIAL_RADIUS_KM) * progress;
    // Never shrink: a raise re-dispatches an already-widened request.
    return Math.round(Math.max(grown, request.radiusKm ?? 0) * 100) / 100;
  }

  /**
   * Nobody reachable up to the max radius: keep the request alive, nudge the
   * passenger to raise the fare (once), and schedule the next retry wave.
   */
  private async handleEmptySweep(
    request: InstantRideRequestEntity,
  ): Promise<void> {
    if (!request.nudgedAt) {
      const marked = await this.requestRepo.update(
        {
          id: request.id,
          status: InstantRequestStatus.SEARCHING,
          nudgedAt: IsNull(),
        },
        { nudgedAt: new Date() },
      );
      if (marked.affected === 1) {
        await this.notifications
          .sendPush(request.passengerId, {
            title: 'لا يوجد سائق قريب حتى الآن',
            body: 'جرّب رفع سعرك لجذب سائق أسرع.',
            type: 'instant_raise_fare_nudge',
            data: { requestId: request.id },
          })
          .catch(() => undefined);
      }
    }
    await this.scheduleWave(request.id);
  }

  /** Queue the next dispatch wave (idempotent per request). */
  async scheduleWave(requestId: string): Promise<void> {
    try {
      const existing = await this.requestExpiryQueue.getJob(
        dispatchWaveJobId(requestId),
      );
      if (existing) await existing.remove();
    } catch {
      // best-effort cleanup
    }
    await this.requestExpiryQueue
      .add(
        DISPATCH_WAVE_JOB,
        { requestId },
        {
          delay: DISPATCH_RETRY_SECONDS * 1000,
          jobId: dispatchWaveJobId(requestId),
          removeOnComplete: true,
          removeOnFail: true,
        },
      )
      .catch((err: Error) =>
        this.logger.warn(`Failed to enqueue dispatch wave: ${err.message}`),
      );
  }

  /** Atomically claim a driver for a request (soft lock). */
  private async tryLockDriver(
    driverId: string,
    requestId: string,
  ): Promise<boolean> {
    const result = await this.availabilityRepo.update(
      { driverId, isOnline: true, currentRequestId: IsNull() },
      { currentRequestId: requestId },
    );
    return result.affected === 1;
  }

  private async makeOffer(
    request: InstantRideRequestEntity,
    candidate: NearbyDriver,
  ): Promise<void> {
    const now = new Date();
    const offer = await this.offerRepo.save(
      this.offerRepo.create({
        requestId: request.id,
        driverId: candidate.driverId,
        vehicleId: candidate.vehicleId,
        status: InstantOfferStatus.OFFERED,
        fareRevision: request.fareRevision,
        offeredAt: now,
        expiresAt: new Date(now.getTime() + OFFER_TTL_SECONDS * 1000),
      }),
    );

    await this.requestRepo.update(
      { id: request.id, status: InstantRequestStatus.SEARCHING },
      { status: InstantRequestStatus.OFFERED },
    );

    // Labels follow the driver's app language (registered with the device).
    const locale = await this.notifications.getPreferredLocale(
      candidate.driverId,
    );
    const routeMetrics = buildInstantOfferRouteMetrics({
      fromPoint: request.fromPoint,
      toPoint: request.toPoint,
      passengerFare: request.passengerFare,
      fareEstimate: request.fareEstimate,
      currency: request.currency,
      seatCount: request.seatCount,
      locale,
      // The sweep already measured this driver's distance to the pickup, so
      // the offer card can show it without a second spatial query.
      pickupDistanceMeters: candidate.distanceMeters,
    });
    const pushText = buildInstantOfferPushText({
      fromName: request.fromName,
      toName: request.toName,
      earningsLabel: routeMetrics.earningsLabel,
      locale,
    });

    await this.notifications
      .sendPush(candidate.driverId, {
        title: pushText.title,
        body: pushText.body,
        type: 'instant_offer',
        data: {
          offerId: offer.id,
          requestId: request.id,
          fromName: request.fromName,
          toName: request.toName,
          fareEstimate: request.fareEstimate ?? '',
          passengerFare: request.passengerFare ?? request.fareEstimate ?? '',
          currency: request.currency,
          expiresAt: offer.expiresAt.toISOString(),
          ...routeMetrics,
        },
      })
      .catch(() => undefined);

    await this.offerTimeoutQueue
      .add(
        EXPIRE_OFFER_JOB,
        { offerId: offer.id },
        {
          delay: OFFER_TTL_SECONDS * 1000,
          jobId: offerTimeoutJobId(offer.id),
          removeOnComplete: true,
          removeOnFail: true,
        },
      )
      .catch((err: Error) =>
        this.logger.warn(`Failed to enqueue offer timeout: ${err.message}`),
      );
  }

  /**
   * The one place a search ends without a match: claims the request, records
   * why and when it ended, and tells the passenger. Returns whether this call
   * is the one that finalized it (safe to call from concurrent paths).
   */
  async finalizeSearch(
    requestId: string,
    forcedReason?: InstantTerminalReason,
  ): Promise<boolean> {
    const reason =
      forcedReason ?? (await this.resolveTerminalReason(requestId));
    const result = await this.requestRepo.update(
      {
        id: requestId,
        status: In([
          InstantRequestStatus.SEARCHING,
          InstantRequestStatus.OFFERED,
        ]),
      },
      {
        status: InstantRequestStatus.EXPIRED,
        terminalReason: reason,
        endedAt: new Date(),
      },
    );
    if (!result.affected) return false;

    const request = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (!request) return false;

    const offerCount = await this.offerRepo.count({ where: { requestId } });
    // Structured, PII-free: no coordinates or addresses.
    this.logger.log(
      `instant_search_ended ${JSON.stringify({
        requestId,
        passengerId: request.passengerId,
        terminalReason: reason,
        offerCount,
      })}`,
    );

    const timedOut = reason === InstantTerminalReason.TTL_EXPIRED;
    await this.notifications
      .sendPush(request.passengerId, {
        title: timedOut ? 'انتهت مهلة الطلب' : 'لا يوجد سائق متاح',
        body: timedOut
          ? 'لم نعثر على سائق متاح. يمكنك المحاولة مرة أخرى.'
          : 'لم نتمكن من إيجاد سائق قريب الآن. يمكنك المحاولة مرة أخرى.',
        type: 'instant_no_drivers',
        data: { requestId, terminalReason: reason },
      })
      .catch(() => undefined);

    return true;
  }

  /**
   * No offer at all → nobody qualified; an offer still outstanding when the
   * window closed → the clock ran out; otherwise every driver said no.
   */
  private async resolveTerminalReason(
    requestId: string,
  ): Promise<InstantTerminalReason> {
    const offers = await this.offerRepo.find({
      where: { requestId },
      select: ['status'],
    });
    if (offers.length === 0) {
      return InstantTerminalReason.NO_ELIGIBLE_DRIVERS;
    }
    const outstanding: string[] = [
      InstantOfferStatus.OFFERED,
      InstantOfferStatus.COUNTERED,
    ];
    return offers.some((o) => outstanding.includes(o.status))
      ? InstantTerminalReason.TTL_EXPIRED
      : InstantTerminalReason.ALL_DECLINED;
  }
}
