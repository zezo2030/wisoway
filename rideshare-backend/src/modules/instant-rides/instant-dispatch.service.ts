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
} from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.service';
import {
  DriverAvailabilityService,
  NearbyDriver,
} from './driver-availability.service';
import {
  EXPIRE_OFFER_JOB,
  INSTANT_OFFER_TIMEOUT_QUEUE,
  MAX_RADIUS_KM,
  OFFER_TTL_SECONDS,
  RADIUS_STEP_KM,
  offerTimeoutJobId,
} from './instant-rides.constants';

/**
 * Sequential dispatch: pick the nearest available driver, offer the ride, and
 * on decline/timeout move on to the next — expanding the search radius until a
 * driver is found or the request gives up. See specs/010-instant-rides/design.md §6.
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
      await this.finalizeNoDrivers(request.id);
      return;
    }

    const [fromLng, fromLat] = request.fromPoint.coordinates;
    const priorOffers = await this.offerRepo.find({
      where: { requestId },
      select: ['driverId'],
    });
    const excludeDriverIds = [...new Set(priorOffers.map((o) => o.driverId))];

    // Expand the radius until a lockable driver is found or the max is reached.
    let radiusKm = request.radiusKm;
    for (;;) {
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

      if (radiusKm >= MAX_RADIUS_KM) {
        await this.finalizeNoDrivers(request.id);
        return;
      }
      radiusKm = Math.min(radiusKm + RADIUS_STEP_KM, MAX_RADIUS_KM);
      await this.requestRepo.update({ id: requestId }, { radiusKm });
    }
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
        offeredAt: now,
        expiresAt: new Date(now.getTime() + OFFER_TTL_SECONDS * 1000),
      }),
    );

    await this.requestRepo.update(
      { id: request.id, status: InstantRequestStatus.SEARCHING },
      { status: InstantRequestStatus.OFFERED },
    );

    await this.notifications
      .sendPush(candidate.driverId, {
        title: 'طلب رحلة مباشرة جديد',
        body: `من ${request.fromName} إلى ${request.toName}`,
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

  /** No driver could be matched — finalize and notify the passenger. */
  async finalizeNoDrivers(requestId: string): Promise<void> {
    const result = await this.requestRepo.update(
      {
        id: requestId,
        status: In([
          InstantRequestStatus.SEARCHING,
          InstantRequestStatus.OFFERED,
        ]),
      },
      { status: InstantRequestStatus.NO_DRIVERS },
    );
    if (!result.affected) return;

    const request = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (!request) return;
    await this.notifications
      .sendPush(request.passengerId, {
        title: 'لا يوجد سائق متاح',
        body: 'لم نتمكن من إيجاد سائق قريب الآن. يمكنك المحاولة مرة أخرى.',
        type: 'instant_no_drivers',
        data: { requestId },
      })
      .catch(() => undefined);
  }
}
