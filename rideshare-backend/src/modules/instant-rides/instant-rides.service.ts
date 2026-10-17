import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { EntityManager, In, IsNull, MoreThan, Not, Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
  DriverAvailabilityEntity,
  InstantOfferStatus,
  InstantRequestStatus,
  InstantRideOfferEntity,
  InstantRideRequestEntity,
  InstantTerminalReason,
  TripEntity,
  TripStatus,
  TripType,
} from '../../database/entities';
import { UsersService } from '../users/users.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { LocationsService } from '../locations/locations.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  countryForPhone,
  currencyForCountry,
  DEFAULT_CURRENCY,
  knownCurrencyForCountry,
} from '../../common/currency/country-currency';
import { InstantDispatchService } from './instant-dispatch.service';
import { InstantPickupWatchService } from './instant-pickup-watch.service';
import { resolvePaymentChoice } from '../ride-payments/cliq-payer';
import {
  CreateInstantRequestDto,
  QuoteInstantRequestDto,
} from './dto/create-instant-request.dto';
import { OfferResponseType, RespondOfferDto } from './dto/respond-offer.dto';
import {
  dispatchWaveJobId,
  EXPIRE_REQUEST_JOB,
  FALLBACK_ROAD_FACTOR,
  FALLBACK_ROUTE_SPEED_KMH,
  computeFare,
  INITIAL_RADIUS_KM,
  MAX_RADIUS_KM,
  INSTANT_OFFER_TIMEOUT_QUEUE,
  INSTANT_REQUEST_EXPIRY_QUEUE,
  offerTimeoutJobId,
  paymentMethodsFor,
  PICKUP_ETA_SPEED_KMH,
  REQUEST_TTL_SECONDS,
  requestExpiryJobId,
} from './instant-rides.constants';
import {
  buildInstantOfferRouteMetrics,
  haversineKm,
  OfferLocale,
} from './instant-offer-labels';

type LatLng = { latitude: number; longitude: number };

@Injectable()
export class InstantRidesService {
  private readonly logger = new Logger(InstantRidesService.name);

  constructor(
    @InjectRepository(InstantRideRequestEntity)
    private readonly requestRepo: Repository<InstantRideRequestEntity>,
    @InjectRepository(InstantRideOfferEntity)
    private readonly offerRepo: Repository<InstantRideOfferEntity>,
    @InjectRepository(DriverAvailabilityEntity)
    private readonly availabilityRepo: Repository<DriverAvailabilityEntity>,
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    private readonly usersService: UsersService,
    private readonly vehiclesService: VehiclesService,
    private readonly locationsService: LocationsService,
    private readonly notifications: NotificationsService,
    private readonly dispatchService: InstantDispatchService,
    private readonly pickupWatch: InstantPickupWatchService,
    @InjectQueue(INSTANT_OFFER_TIMEOUT_QUEUE)
    private readonly offerTimeoutQueue: Queue,
    @InjectQueue(INSTANT_REQUEST_EXPIRY_QUEUE)
    private readonly requestExpiryQueue: Queue,
  ) {}

  // ── Passenger ──────────────────────────────────────────────────────────────

  /** The fixed, distance-based fare shown before the passenger orders. */
  async getQuote(dto: QuoteInstantRequestDto, passengerId?: string) {
    const quote = await this.computeQuote(dto.from, dto.to, passengerId);
    const fare = quote.fare.toFixed(2);
    return {
      recommendedFare: fare,
      // Kept for older apps that still draw a range: there is none any more.
      minFare: fare,
      maxFare: fare,
      currency: quote.currency,
      /** What the passenger may choose here (CliQ only in Jordan). */
      paymentMethods: paymentMethodsFor(quote.currency),
      distanceKm: Math.round(quote.distanceKm * 10) / 10,
      durationMinutes: Math.round(quote.durationMin),
    };
  }

  /**
   * The passenger's live instant request, or null.
   *
   * ACCEPTED is not a terminal status and nothing ever moves a request out of
   * it — completing the trip only updates the trip. So a request whose trip has
   * already finished would otherwise count as "live" forever, and the passenger
   * could never order a second instant ride ("لديك طلب رحلة نشط بالفعل").
   * An accepted request is therefore only live while its trip still is.
   */
  private async findLiveRequest(
    passengerId: string,
    manager?: EntityManager,
  ): Promise<InstantRideRequestEntity | null> {
    const where = {
      passengerId,
      status: In([
        InstantRequestStatus.SEARCHING,
        InstantRequestStatus.OFFERED,
        InstantRequestStatus.ACCEPTED,
      ]),
    };
    // Newest first: this guard is what stops a second live request existing, so
    // the most recent row is the only one that can still be live.
    const order = { createdAt: 'DESC' as const };
    const request = manager
      ? await manager.findOne(InstantRideRequestEntity, { where, order })
      : await this.requestRepo.findOne({ where, order });

    if (!request) return null;
    if (request.status !== InstantRequestStatus.ACCEPTED) return request;
    if (!request.tripId) return request;

    const trip = manager
      ? await manager.findOne(TripEntity, { where: { id: request.tripId } })
      : await this.tripRepo.findOne({ where: { id: request.tripId } });
    if (!trip) return request;

    const tripFinished =
      trip.status === TripStatus.COMPLETED ||
      trip.status === TripStatus.CANCELLED;
    return tripFinished ? null : request;
  }

  /**
   * The instant ride this user is in the middle of, as driver or passenger.
   * Once a ride is matched both apps stay on its trip screen until it ends, so
   * they ask this on launch / resume to put the user back there.
   */
  async getActiveRide(userId: string): Promise<{
    tripId: string;
    role: 'driver' | 'passenger';
    requestId: string | null;
    /** `ride` while under way; `payment` once arrived, until the driver settles. */
    stage?: 'ride' | 'payment';
  } | null> {
    const live = await this.getLiveRide(userId);
    if (live) return { ...live, stage: 'ride' };
    const unpaid = await this.getRideAwaitingPayment(userId);
    return unpaid ? { ...unpaid, stage: 'payment' } : null;
  }

  /**
   * A finished ride — instant or shared — whose fare is still open. The
   * passenger returns to their amount-due screen (pending cash, CliQ request
   * out, or CliQ failed); the driver returns to the trip summary only while a
   * cash fare waits for their confirmation (CliQ fares settle without them).
   * Rides older than a day are left to support rather than trapping anyone.
   */
  private async getRideAwaitingPayment(userId: string): Promise<{
    tripId: string;
    role: 'driver' | 'passenger';
    requestId: string | null;
  } | null> {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const bookings = this.tripRepo.manager.getRepository(BookingEntity);

    const driverOwed = await bookings
      .createQueryBuilder('b')
      .innerJoin(TripEntity, 't', 't.id = b."tripId"')
      .where('t."driverId" = :userId', { userId })
      .andWhere('t.status = :done', { done: TripStatus.COMPLETED })
      .andWhere('t."tripCompletedAt" > :since', { since })
      .andWhere('b.status = :completed', { completed: BookingStatus.COMPLETED })
      .andWhere(`b."paymentMethod" = 'cash'`)
      .andWhere(`b."paymentStatus" = 'pending'`)
      .orderBy('t."tripCompletedAt"', 'DESC')
      .select(['b.tripId'])
      .getOne();
    if (driverOwed) {
      const request = await this.requestRepo.findOne({
        where: { tripId: driverOwed.tripId },
        select: ['id'],
      });
      return {
        tripId: driverOwed.tripId,
        role: 'driver',
        requestId: request?.id ?? null,
      };
    }

    const passengerOwes = await bookings
      .createQueryBuilder('b')
      .innerJoin(TripEntity, 't', 't.id = b."tripId"')
      .where('b."userId" = :userId', { userId })
      .andWhere('b.status = :completed', { completed: BookingStatus.COMPLETED })
      .andWhere(`b."paymentStatus" IN ('pending', 'requested', 'failed')`)
      .andWhere('t.status = :done', { done: TripStatus.COMPLETED })
      .andWhere('t."tripCompletedAt" > :since', { since })
      .orderBy('t."tripCompletedAt"', 'DESC')
      .select(['b.tripId'])
      .getOne();
    if (!passengerOwes) return null;
    const request = await this.requestRepo.findOne({
      where: { tripId: passengerOwes.tripId },
      select: ['id'],
    });
    return {
      tripId: passengerOwes.tripId,
      role: 'passenger',
      requestId: request?.id ?? null,
    };
  }

  private async getLiveRide(userId: string): Promise<{
    tripId: string;
    role: 'driver' | 'passenger';
    requestId: string | null;
  } | null> {
    const drivenTrip = await this.tripRepo.findOne({
      where: {
        driverId: userId,
        tripType: TripType.INSTANT,
        status: TripStatus.IN_PROGRESS,
      },
      order: { createdAt: 'DESC' },
    });
    if (drivenTrip) {
      const request = await this.requestRepo.findOne({
        where: { tripId: drivenTrip.id },
        select: ['id'],
      });
      return {
        tripId: drivenTrip.id,
        role: 'driver',
        requestId: request?.id ?? null,
      };
    }

    const request = await this.findLiveRequest(userId);
    if (request?.status !== InstantRequestStatus.ACCEPTED || !request.tripId) {
      return null;
    }
    return { tripId: request.tripId, role: 'passenger', requestId: request.id };
  }

  async createRequest(passengerId: string, dto: CreateInstantRequestDto) {
    const active = await this.findLiveRequest(passengerId);
    if (active?.status === InstantRequestStatus.ACCEPTED) {
      // Mid-ride: a second ride can't start until this one ends.
      throw new ConflictException('لديك طلب رحلة نشط بالفعل.');
    }
    if (active) {
      // A search the passenger walked away from (closed the screen, the app
      // died) would otherwise block every new request until its window ran
      // out. Asking again means they want this one instead.
      await this.withdrawSearch(active);
    }

    const seatCount = dto.seatCount ?? 1;
    // The platform sets the fare; a `passengerFare` sent by an older app is
    // ignored rather than rejected so those apps can still order.
    const quote = await this.computeQuote(dto.from, dto.to, passengerId);
    const fare = quote.fare.toFixed(2);
    const { method: paymentMethod, payerCliqAlias } = resolvePaymentChoice(
      dto.paymentMethod,
      quote.currency,
      dto.payerCliqAlias ??
        (dto.paymentMethod === 'cliq'
          ? await this.savedCliqAlias(passengerId)
          : null),
    );
    if (payerCliqAlias) {
      // Remembered so the next CliQ ride is pre-filled.
      await this.usersService
        .update(passengerId, { cliqAlias: payerCliqAlias })
        .catch(() => undefined);
    }

    const now = new Date();

    const request = await this.requestRepo.save(
      this.requestRepo.create({
        passengerId,
        fromName: dto.from.name,
        fromAddress: dto.from.address ?? null,
        fromPoint: {
          type: 'Point',
          coordinates: [dto.from.longitude, dto.from.latitude],
        },
        toName: dto.to.name,
        toAddress: dto.to.address ?? null,
        toPoint: {
          type: 'Point',
          coordinates: [dto.to.longitude, dto.to.latitude],
        },
        seatCount,
        status: InstantRequestStatus.SEARCHING,
        fareEstimate: fare,
        recommendedFare: fare,
        passengerFare: fare,
        currency: quote.currency,
        paymentMethod,
        payerCliqAlias,
        radiusKm: INITIAL_RADIUS_KM,
        expiresAt: new Date(now.getTime() + REQUEST_TTL_SECONDS * 1000),
      }),
    );

    await this.requestExpiryQueue
      .add(
        EXPIRE_REQUEST_JOB,
        { requestId: request.id },
        {
          delay: REQUEST_TTL_SECONDS * 1000,
          jobId: requestExpiryJobId(request.id),
          removeOnComplete: true,
          removeOnFail: true,
        },
      )
      .catch((err: Error) =>
        this.logger.warn(`Failed to enqueue request expiry: ${err.message}`),
      );

    // Kick off matching without blocking the API response on the full loop.
    void this.dispatchService
      .dispatchNext(request.id)
      .catch((err: Error) =>
        this.logger.warn(`dispatchNext failed: ${err.message}`),
      );

    return this.toRequestView(request);
  }

  private async savedCliqAlias(userId: string): Promise<string | null> {
    try {
      const user = await this.usersService.findById(userId);
      return user?.cliqAlias ?? null;
    } catch {
      return null;
    }
  }

  async getRequest(requestId: string, passengerId: string) {
    const request = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (!request) {
      throw new NotFoundException('الطلب غير موجود.');
    }
    if (request.passengerId !== passengerId) {
      throw new ForbiddenException('غير مصرح.');
    }
    return this.toRequestView(request);
  }

  /**
   * The passenger's request that is still looking for a driver, or null —
   * how the app finds the new search after its driver cancelled.
   */
  async getSearchingRequest(passengerId: string) {
    const request = await this.findLiveRequest(passengerId);
    if (
      !request ||
      (request.status !== InstantRequestStatus.SEARCHING &&
        request.status !== InstantRequestStatus.OFFERED)
    ) {
      return null;
    }
    return this.toRequestView(request);
  }

  async cancelRequest(requestId: string, passengerId: string) {
    const request = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (!request) {
      throw new NotFoundException('الطلب غير موجود.');
    }
    if (request.passengerId !== passengerId) {
      throw new ForbiddenException('غير مصرح.');
    }
    if (
      request.status !== InstantRequestStatus.SEARCHING &&
      request.status !== InstantRequestStatus.OFFERED
    ) {
      throw new ConflictException('لا يمكن إلغاء الطلب في حالته الحالية.');
    }

    await this.withdrawSearch(request);
    return this.getRequest(request.id, passengerId);
  }

  /**
   * Ends a request that is still searching: takes back any outstanding offer
   * (and tells that driver, so their card and ringing stop), frees the driver,
   * and stops the dispatch and expiry jobs.
   */
  private async withdrawSearch(request: InstantRideRequestEntity) {
    const offer = await this.offerRepo.findOne({
      where: {
        requestId: request.id,
        status: In([InstantOfferStatus.OFFERED, InstantOfferStatus.COUNTERED]),
      },
    });
    if (offer) {
      await this.offerRepo.update(
        { id: offer.id },
        { status: InstantOfferStatus.CANCELLED, respondedAt: new Date() },
      );
      await this.freeDriver(offer.driverId, request.id);
      await this.removeJob(this.offerTimeoutQueue, offerTimeoutJobId(offer.id));
      // Socket first: it reaches an open app at once, the push may lag.
      this.notifications.emitRealtime(offer.driverId, 'instantOfferClosed', {
        offerId: offer.id,
        requestId: request.id,
      });
      this.notifications
        .sendPush(offer.driverId, {
          title: 'أُلغي الطلب',
          body: 'ألغى الراكب طلب الرحلة.',
          type: 'instant_offer_cancelled',
          // offerId lets the driver's app take down the ringing notification
          // and the open card for exactly this offer.
          data: { requestId: request.id, offerId: offer.id },
        })
        .catch(() => undefined);
    }

    await this.requestRepo.update(
      { id: request.id },
      {
        status: InstantRequestStatus.CANCELLED,
        terminalReason: InstantTerminalReason.PASSENGER_CANCELLED,
        endedAt: new Date(),
      },
    );
    await this.removeJob(
      this.requestExpiryQueue,
      requestExpiryJobId(request.id),
    );
    await this.removeJob(
      this.requestExpiryQueue,
      dispatchWaveJobId(request.id),
    );
  }

  /**
   * Start a fresh search from an exhausted request, keeping the same route and
   * seats, at the route's current fare. Idempotent: a double-tap returns the
   * attempt the first tap created instead of piling up requests.
   */
  async retryRequest(requestId: string, passengerId: string) {
    const original = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (!original) {
      throw new NotFoundException('الطلب غير موجود.');
    }
    if (original.passengerId !== passengerId) {
      throw new ForbiddenException('غير مصرح.');
    }
    this.assertRetryable(original.status);

    const existing = await this.requestRepo.findOne({
      where: { retryOfRequestId: requestId },
    });
    if (existing) {
      return this.toRequestView(existing);
    }

    const [fromLng, fromLat] = original.fromPoint.coordinates;
    const [toLng, toLat] = original.toPoint.coordinates;
    const quote = await this.computeQuote(
      { latitude: fromLat, longitude: fromLng },
      { latitude: toLat, longitude: toLng },
      passengerId,
    );

    // The fare is the platform's, so a retry simply uses the current one for
    // the same route — it only moves if the tariff itself changed.
    const fare = quote.fare.toFixed(2);

    const now = new Date();
    let created: InstantRideRequestEntity | null = null;
    let reused: InstantRideRequestEntity | null = null;

    await this.requestRepo.manager.transaction(async (m) => {
      // Serialize concurrent retries of the same request on the old row.
      const locked = await m.findOne(InstantRideRequestEntity, {
        where: { id: requestId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked) {
        throw new NotFoundException('الطلب غير موجود.');
      }
      this.assertRetryable(locked.status);

      const child = await m.findOne(InstantRideRequestEntity, {
        where: { retryOfRequestId: requestId },
      });
      if (child) {
        reused = child;
        return;
      }

      const active = await this.findLiveRequest(passengerId, m);
      if (active) {
        this.logger.log(
          `instant_retry_rejected ${JSON.stringify({
            code: 'INSTANT_ACTIVE_REQUEST_EXISTS',
          })}`,
        );
        throw new ConflictException({
          statusCode: 409,
          code: 'INSTANT_ACTIVE_REQUEST_EXISTS',
          message: 'لديك طلب رحلة نشط بالفعل.',
        });
      }

      created = await m.save(
        m.create(InstantRideRequestEntity, {
          passengerId,
          retryOfRequestId: original.id,
          fromName: original.fromName,
          fromAddress: original.fromAddress,
          fromPoint: original.fromPoint,
          toName: original.toName,
          toAddress: original.toAddress,
          toPoint: original.toPoint,
          seatCount: original.seatCount,
          paymentMethod: original.paymentMethod,
          payerCliqAlias: original.payerCliqAlias,
          status: InstantRequestStatus.SEARCHING,
          fareEstimate: fare,
          recommendedFare: fare,
          passengerFare: fare,
          currency: quote.currency,
          radiusKm: INITIAL_RADIUS_KM,
          expiresAt: new Date(now.getTime() + REQUEST_TTL_SECONDS * 1000),
        }),
      );
    });

    if (reused) {
      return this.toRequestView(reused);
    }
    const request = created as InstantRideRequestEntity | null;
    if (!request) {
      throw new ConflictException({
        statusCode: 409,
        code: 'INSTANT_REQUEST_NOT_RETRYABLE',
        message: 'تعذّر إعادة المحاولة، حدّث الحالة وحاول مجدداً.',
      });
    }

    this.logger.log(
      `instant_retry_created ${JSON.stringify({
        oldRequestId: original.id,
        newRequestId: request.id,
        passengerId,
      })}`,
    );

    await this.requestExpiryQueue
      .add(
        EXPIRE_REQUEST_JOB,
        { requestId: request.id },
        {
          delay: REQUEST_TTL_SECONDS * 1000,
          jobId: requestExpiryJobId(request.id),
          removeOnComplete: true,
          removeOnFail: true,
        },
      )
      .catch((err: Error) =>
        this.logger.warn(`Failed to enqueue request expiry: ${err.message}`),
      );

    void this.dispatchService
      .dispatchNext(request.id)
      .catch((err: Error) =>
        this.logger.warn(`dispatchNext after retry failed: ${err.message}`),
      );

    return this.toRequestView(request);
  }

  /** Only an exhausted search can be retried — not a live or cancelled one. */
  private assertRetryable(status: InstantRequestStatus) {
    if (
      status !== InstantRequestStatus.EXPIRED &&
      status !== InstantRequestStatus.NO_DRIVERS
    ) {
      this.logger.log(
        `instant_retry_rejected ${JSON.stringify({
          code: 'INSTANT_REQUEST_NOT_RETRYABLE',
        })}`,
      );
      throw new ConflictException({
        statusCode: 409,
        code: 'INSTANT_REQUEST_NOT_RETRYABLE',
        message: 'لا يمكن إعادة المحاولة لهذا الطلب.',
      });
    }
  }

  // ── Driver ───────────────────────────────────────────────────────────────

  async getPendingOffer(driverId: string, locale: OfferLocale = 'ar') {
    const offer = await this.offerRepo.findOne({
      where: { driverId, status: InstantOfferStatus.OFFERED },
      order: { offeredAt: 'DESC' },
    });
    if (!offer) {
      return { offer: null };
    }
    const request = await this.requestRepo.findOne({
      where: { id: offer.requestId },
    });
    if (!request) {
      return { offer: null };
    }
    // The details screen names the passenger and says how far the pickup is;
    // both are read here so the card never has to call back for them.
    const [availability, passenger] = await Promise.all([
      this.availabilityRepo.findOne({ where: { driverId } }).catch(() => null),
      this.usersService.findById(request.passengerId).catch(() => null),
    ]);
    return {
      offer: {
        id: offer.id,
        requestId: offer.requestId,
        offeredAt: offer.offeredAt,
        expiresAt: offer.expiresAt,
        // The app counts down against this, not its own clock, so a phone
        // whose clock runs ahead doesn't see the window shrink.
        serverNow: new Date(),
      },
      request: this.toRequestSummary(request, locale, {
        pickupDistanceMeters: this.pickupDistanceMeters(availability, request),
        passengerName: passenger?.name ?? null,
        passengerRating:
          passenger?.rating != null ? Number(passenger.rating) : null,
        passengerTotalRatings: passenger?.totalRatings ?? null,
        passengerPhotoUrl: passenger?.photoUrl ?? null,
      }),
    };
  }

  /** Straight-line metres from a driver's last known point to the pickup. */
  private pickupDistanceMeters(
    availability: { point?: { coordinates: [number, number] } | null } | null,
    request: InstantRideRequestEntity,
  ): number | null {
    const coords = availability?.point?.coordinates;
    if (!coords) return null;
    const [fromLng, fromLat] = request.fromPoint.coordinates;
    return Math.round(
      haversineKm(
        { latitude: coords[1], longitude: coords[0] },
        { latitude: fromLat, longitude: fromLng },
      ) * 1000,
    );
  }

  /**
   * Driver responds to an outstanding offer: accept it at the platform's fare
   * or decline it. Fares are fixed, so there is no counter-offer.
   */
  async respondOffer(offerId: string, driverId: string, dto: RespondOfferDto) {
    if (dto.responseType === OfferResponseType.ACCEPT) {
      return this.acceptOffer(offerId, driverId);
    }
    return this.declineOffer(offerId, driverId);
  }

  async acceptOffer(offerId: string, driverId: string) {
    const offer = await this.offerRepo.findOne({
      where: { id: offerId, driverId },
    });
    if (!offer) {
      throw new NotFoundException('العرض غير موجود.');
    }
    if (offer.status !== InstantOfferStatus.OFFERED) {
      throw new ConflictException('العرض لم يعد متاحاً.');
    }
    const request = await this.requestRepo.findOne({
      where: { id: offer.requestId },
    });
    if (!request || request.status !== InstantRequestStatus.OFFERED) {
      throw new ConflictException('الطلب لم يعد متاحاً.');
    }

    const acceptedFare = request.passengerFare ?? request.fareEstimate ?? '0';
    const { tripId, driverName, pickupEtaSeconds } = await this.finalizeMatch(
      request,
      offer,
      acceptedFare,
    );
    await this.pickupWatch.schedule(tripId, pickupEtaSeconds);

    this.notifications
      .sendPush(request.passengerId, {
        title: 'تم العثور على سائق!',
        body: `السائق ${driverName} في الطريق إليك.`,
        type: 'instant_matched',
        data: { requestId: request.id, tripId, driverId },
      })
      .catch(() => undefined);

    return this.getRequest(request.id, request.passengerId);
  }

  /**
   * One transaction that turns an outstanding offer into a matched ride:
   * claims the offer + request, creates the INSTANT trip and confirmed
   * booking at `acceptedFare`, and links them back to the request.
   */
  private async finalizeMatch(
    request: InstantRideRequestEntity,
    offer: InstantRideOfferEntity,
    acceptedFare: string,
  ): Promise<{
    tripId: string;
    driverName: string;
    pickupEtaSeconds: number | null;
  }> {
    const driver = await this.usersService.findById(offer.driverId);
    const vehicle = offer.vehicleId
      ? await this.vehiclesService.findById(offer.vehicleId).catch(() => null)
      : await this.vehiclesService.findByDriver(offer.driverId);
    const pickupEtaSeconds = await this.estimatePickupEta(
      offer.driverId,
      request,
    );

    let tripId = '';
    await this.requestRepo.manager.transaction(async (m) => {
      // Atomic claim — only one driver can win the offer/request.
      const offerClaim = await m.update(
        InstantRideOfferEntity,
        { id: offer.id, status: InstantOfferStatus.OFFERED },
        { status: InstantOfferStatus.ACCEPTED, respondedAt: new Date() },
      );
      if (offerClaim.affected !== 1) {
        throw new ConflictException('العرض لم يعد متاحاً.');
      }
      const reqClaim = await m.update(
        InstantRideRequestEntity,
        { id: request.id, status: InstantRequestStatus.OFFERED },
        {
          status: InstantRequestStatus.ACCEPTED,
          matchedDriverId: offer.driverId,
          acceptedFare,
          pickupEtaSeconds,
        },
      );
      if (reqClaim.affected !== 1) {
        throw new ConflictException('الطلب لم يعد متاحاً.');
      }

      const now = new Date();
      const trip = m.create(TripEntity, {
        driverId: offer.driverId,
        driverName: driver?.name ?? null,
        fromName: request.fromName,
        fromAddress: request.fromAddress,
        toName: request.toName,
        toAddress: request.toAddress,
        fromPoint: request.fromPoint,
        toPoint: request.toPoint,
        departureTime: now,
        price: acceptedFare,
        currency: request.currency,
        totalSeats: request.seatCount,
        availableSeats: 0,
        seatLayout: null,
        seats: [],
        stops: [],
        notes: null,
        status: TripStatus.IN_PROGRESS,
        tripType: TripType.INSTANT,
        // Not started yet: the driver is only heading to the pickup. It
        // starts when the driver presses «بدء الرحلة» (startRide).
        tripStartedAt: null,
        isVisible: false,
        communicationFeeStatus: 'not_paid',
        carImageUrl: vehicle?.carImageUrl ?? null,
      });
      const savedTrip = await m.save(trip);
      tripId = savedTrip.id;

      const fareNum = Number(acceptedFare);
      const seatPrice =
        request.seatCount > 0
          ? (fareNum / request.seatCount).toFixed(2)
          : acceptedFare;
      const booking = m.create(BookingEntity, {
        tripId: savedTrip.id,
        userId: request.passengerId,
        status: BookingStatus.CONFIRMED,
        seatCount: request.seatCount,
        totalAmount: acceptedFare,
        seatPriceAtBooking: seatPrice,
        expiresAt: null,
        // Settled when the ride ends: cash to the driver, or CliQ to us.
        paymentMethod: request.paymentMethod ?? 'cash',
        payerCliqAlias: request.payerCliqAlias ?? null,
      });
      await m.save(booking);

      await m.update(
        InstantRideRequestEntity,
        { id: request.id },
        { tripId: savedTrip.id },
      );
    });

    await this.removeJob(this.offerTimeoutQueue, offerTimeoutJobId(offer.id));
    await this.removeJob(
      this.requestExpiryQueue,
      requestExpiryJobId(request.id),
    );
    await this.removeJob(
      this.requestExpiryQueue,
      dispatchWaveJobId(request.id),
    );

    return { tripId, driverName: driver?.name ?? '', pickupEtaSeconds };
  }

  // ── Driver: pickup stages ──────────────────────────────────────────────────

  /**
   * The driver has reached the passenger («وصلت إلى الراكب»). Idempotent —
   * pressing it again keeps the first arrival time.
   */
  async markArrivedAtPickup(tripId: string, driverId: string) {
    const trip = await this.liveInstantTripOf(tripId, driverId);
    if (trip.tripStartedAt) return trip;
    if (!trip.driverArrivedAt) {
      trip.driverArrivedAt = new Date();
      await this.tripRepo.save(trip);
      await this.notifyPassenger(trip, {
        title: 'وصل السائق',
        body: 'السائق بانتظارك في نقطة الالتقاء.',
        type: 'instant_driver_arrived',
      });
    }
    return trip;
  }

  /**
   * The passenger is in the car and the ride begins («بدء الرحلة»). Arrival is
   * implied if the driver skipped that step. Idempotent.
   */
  async startRide(tripId: string, driverId: string) {
    const trip = await this.liveInstantTripOf(tripId, driverId);
    if (trip.tripStartedAt) return trip;
    const now = new Date();
    trip.driverArrivedAt ??= now;
    trip.tripStartedAt = now;
    await this.tripRepo.save(trip);
    await this.notifyPassenger(trip, {
      title: 'بدأت الرحلة',
      body: `في الطريق إلى ${trip.toName}.`,
      type: 'instant_ride_started',
    });
    return trip;
  }

  /**
   * The driver backs out of an accepted ride before the passenger is in the
   * car. The trip and booking are cancelled, the driver is freed, and the
   * passenger is put straight back into a search — for the same route and
   * fare, skipping this driver — instead of being left with nothing.
   */
  async cancelByDriver(tripId: string, driverId: string) {
    const trip = await this.liveInstantTripOf(tripId, driverId);
    if (trip.tripStartedAt) {
      throw new ConflictException({
        statusCode: 409,
        code: 'INSTANT_RIDE_ALREADY_STARTED',
        message: 'بدأت الرحلة، لا يمكن إلغاؤها الآن.',
      });
    }
    const request = await this.requestRepo.findOne({ where: { tripId } });
    const now = new Date();

    await this.tripRepo.manager.transaction(async (m) => {
      const claim = await m.update(
        TripEntity,
        { id: tripId, status: TripStatus.IN_PROGRESS, tripStartedAt: IsNull() },
        { status: TripStatus.CANCELLED },
      );
      if (claim.affected !== 1) {
        throw new ConflictException('الرحلة لم تعد جارية.');
      }
      await m.update(
        BookingEntity,
        { tripId, status: BookingStatus.CONFIRMED },
        {
          status: BookingStatus.CANCELLED,
          cancelledAt: now,
          cancelledBy: driverId,
          cancellationReason: 'driver_cancelled',
        },
      );
      if (request) {
        await m.update(
          InstantRideRequestEntity,
          { id: request.id },
          {
            status: InstantRequestStatus.CANCELLED,
            terminalReason: InstantTerminalReason.DRIVER_CANCELLED,
            endedAt: now,
          },
        );
      }
    });
    if (request) await this.freeDriver(driverId, request.id);

    const next = request
      ? await this.searchAgainAfterDriverCancel(request, driverId).catch(
          (err: Error) => {
            this.logger.warn(`Re-search after cancel failed: ${err.message}`);
            return null;
          },
        )
      : null;

    this.logger.log(
      `instant_driver_cancelled ${JSON.stringify({
        tripId,
        driverId,
        requestId: request?.id ?? null,
        nextRequestId: next?.id ?? null,
      })}`,
    );

    if (request) {
      const data = {
        tripId,
        requestId: next?.id ?? request.id,
        searching: next != null,
      };
      this.notifications.emitRealtime(
        request.passengerId,
        'instantDriverCancelled',
        data,
      );
      this.notifications
        .sendPush(request.passengerId, {
          title: 'ألغى السائق الرحلة',
          body: next
            ? 'نبحث لك الآن عن سائق آخر.'
            : 'يمكنك طلب رحلة جديدة الآن.',
          type: 'instant_driver_cancelled',
          data,
        })
        .catch(() => undefined);
    }

    return { cancelled: true, nextRequestId: next?.id ?? null };
  }

  /**
   * A fresh search for a passenger whose driver cancelled: same route, seats,
   * payment and fare they already agreed to. The cancelling driver gets a
   * closed offer on it so the dispatch never picks them again.
   */
  private async searchAgainAfterDriverCancel(
    original: InstantRideRequestEntity,
    cancelledDriverId: string,
  ): Promise<InstantRideRequestEntity | null> {
    const now = new Date();
    const fare =
      original.acceptedFare ?? original.passengerFare ?? original.fareEstimate;
    let created: InstantRideRequestEntity | null = null;

    await this.requestRepo.manager.transaction(async (m) => {
      if (await this.findLiveRequest(original.passengerId, m)) return;
      const request = await m.save(
        m.create(InstantRideRequestEntity, {
          passengerId: original.passengerId,
          retryOfRequestId: original.id,
          fromName: original.fromName,
          fromAddress: original.fromAddress,
          fromPoint: original.fromPoint,
          toName: original.toName,
          toAddress: original.toAddress,
          toPoint: original.toPoint,
          seatCount: original.seatCount,
          paymentMethod: original.paymentMethod,
          payerCliqAlias: original.payerCliqAlias,
          status: InstantRequestStatus.SEARCHING,
          fareEstimate: fare,
          recommendedFare: fare,
          passengerFare: fare,
          currency: original.currency,
          radiusKm: INITIAL_RADIUS_KM,
          expiresAt: new Date(now.getTime() + REQUEST_TTL_SECONDS * 1000),
        }),
      );
      await m.save(
        m.create(InstantRideOfferEntity, {
          requestId: request.id,
          driverId: cancelledDriverId,
          status: InstantOfferStatus.CANCELLED,
          fareRevision: request.fareRevision,
          offeredAt: now,
          respondedAt: now,
          expiresAt: now,
        }),
      );
      created = request;
    });

    const request = created as InstantRideRequestEntity | null;
    if (!request) return null;

    await this.requestExpiryQueue
      .add(
        EXPIRE_REQUEST_JOB,
        { requestId: request.id },
        {
          delay: REQUEST_TTL_SECONDS * 1000,
          jobId: requestExpiryJobId(request.id),
          removeOnComplete: true,
          removeOnFail: true,
        },
      )
      .catch((err: Error) =>
        this.logger.warn(`Failed to enqueue request expiry: ${err.message}`),
      );
    void this.dispatchService
      .dispatchNext(request.id)
      .catch((err: Error) =>
        this.logger.warn(`dispatchNext after cancel failed: ${err.message}`),
      );
    return request;
  }

  private async liveInstantTripOf(tripId: string, driverId: string) {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip || trip.tripType !== TripType.INSTANT) {
      throw new NotFoundException('الرحلة غير موجودة.');
    }
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('هذه الرحلة ليست لك.');
    }
    if (trip.status !== TripStatus.IN_PROGRESS) {
      throw new ConflictException('الرحلة لم تعد جارية.');
    }
    return trip;
  }

  private async notifyPassenger(
    trip: TripEntity,
    push: { title: string; body: string; type: string },
  ) {
    const request = await this.requestRepo.findOne({
      where: { tripId: trip.id },
      select: ['id', 'passengerId'],
    });
    if (!request) return;
    this.notifications
      .sendPush(request.passengerId, {
        ...push,
        data: { requestId: request.id, tripId: trip.id },
      })
      .catch(() => undefined);
  }

  /** Rough driver→pickup travel time from the driver's last known position. */
  private async estimatePickupEta(
    driverId: string,
    request: InstantRideRequestEntity,
  ): Promise<number | null> {
    const availability = await this.availabilityRepo.findOne({
      where: { driverId },
    });
    const coords = availability?.point?.coordinates;
    if (!coords) return null;
    const [fromLng, fromLat] = request.fromPoint.coordinates;
    const distanceKm = haversineKm(
      { latitude: coords[1], longitude: coords[0] },
      { latitude: fromLat, longitude: fromLng },
    );
    return Math.max(60, Math.round((distanceKm / PICKUP_ETA_SPEED_KMH) * 3600));
  }

  async declineOffer(offerId: string, driverId: string) {
    const offer = await this.offerRepo.findOne({
      where: { id: offerId, driverId },
    });
    if (!offer) {
      throw new NotFoundException('العرض غير موجود.');
    }
    if (offer.status !== InstantOfferStatus.OFFERED) {
      throw new ConflictException('العرض لم يعد متاحاً.');
    }

    await this.offerRepo.update(
      { id: offerId, status: InstantOfferStatus.OFFERED },
      { status: InstantOfferStatus.DECLINED, respondedAt: new Date() },
    );
    await this.freeDriver(driverId, offer.requestId);
    await this.requestRepo.update(
      { id: offer.requestId, status: InstantRequestStatus.OFFERED },
      { status: InstantRequestStatus.SEARCHING },
    );
    await this.removeJob(this.offerTimeoutQueue, offerTimeoutJobId(offerId));

    void this.dispatchService
      .dispatchNext(offer.requestId)
      .catch((err: Error) =>
        this.logger.warn(`dispatchNext after decline failed: ${err.message}`),
      );

    return { ok: true };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /** The platform's fixed fare for a route, in the pickup country's currency. */
  private async computeQuote(from: LatLng, to: LatLng, passengerId?: string) {
    const [{ distanceKm, durationMin }, currency] = await Promise.all([
      this.routeDistance(from, to),
      this.currencyAt(from, passengerId),
    ]);
    return {
      fare: computeFare(distanceKm, durationMin, currency),
      currency,
      distanceKm,
      durationMin,
    };
  }

  /**
   * Driving distance and time. The fare is fixed by these, so a straight line
   * is the last resort: Google first, then the route service (which itself
   * falls back to OSRM), and only then the stretched straight line.
   */
  private async routeDistance(
    from: LatLng,
    to: LatLng,
  ): Promise<{ distanceKm: number; durationMin: number }> {
    try {
      const d = await this.locationsService.getDistance(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      return { distanceKm: d.distanceKm, durationMin: d.durationMinutes };
    } catch {
      // try the route service next
    }
    try {
      const r = await this.locationsService.getRoute(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      if (r.distanceMeters != null && r.durationSeconds != null) {
        return {
          distanceKm: r.distanceMeters / 1000,
          durationMin: Math.ceil(r.durationSeconds / 60),
        };
      }
    } catch {
      // fall through to the straight line
    }
    const distanceKm = haversineKm(from, to) * FALLBACK_ROAD_FACTOR;
    return {
      distanceKm,
      durationMin: Math.ceil((distanceKm / FALLBACK_ROUTE_SPEED_KMH) * 60),
    };
  }

  /**
   * Currency of the pickup country. When the lookup fails (Google, then the
   * public Photon instance, both of which do fail in production), the
   * passenger's phone country stands in before the platform default — else a
   * rider in Saudi Arabia was quoted in dinars and offered CliQ.
   */
  private async currencyAt(
    point: LatLng,
    passengerId?: string,
  ): Promise<string> {
    try {
      const geo = await this.locationsService.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      const code = typeof geo.countryCode === 'string' ? geo.countryCode : '';
      if (code) return currencyForCountry(code);
    } catch {
      // fall back to the passenger's phone country
    }
    let phone: string | null | undefined;
    try {
      if (passengerId) {
        phone = (await this.usersService.findById(passengerId))?.phoneNumber;
      }
    } catch {
      // no passenger to go by: the platform default
    }
    return knownCurrencyForCountry(countryForPhone(phone)) ?? DEFAULT_CURRENCY;
  }

  /** Release a driver's soft lock if still held for this request. */
  private async freeDriver(driverId: string, requestId: string) {
    await this.availabilityRepo.update(
      { driverId, currentRequestId: requestId },
      { currentRequestId: null },
    );
  }

  private async removeJob(queue: Queue, jobId: string) {
    try {
      const job = await queue.getJob(jobId);
      if (job) await job.remove();
    } catch {
      // best-effort cleanup
    }
  }

  private async toRequestView(request: InstantRideRequestEntity) {
    return {
      id: request.id,
      status: request.status,
      terminalReason: request.terminalReason ?? null,
      canRetry: this.canRetry(request.status),
      retryOfRequestId: request.retryOfRequestId ?? null,
      endedAt: request.endedAt ?? null,
      from: { name: request.fromName, address: request.fromAddress },
      to: { name: request.toName, address: request.toAddress },
      seatCount: request.seatCount,
      fareEstimate: request.fareEstimate,
      recommendedFare: request.recommendedFare,
      passengerFare: request.passengerFare,
      acceptedFare: request.acceptedFare,
      currency: request.currency,
      paymentMethod: request.paymentMethod ?? 'cash',
      matchedDriverId: request.matchedDriverId,
      tripId: request.tripId,
      expiresAt: request.expiresAt,
      // Older apps cap a fare raise at this; the fare is fixed, so it is the fare.
      maxFare: request.passengerFare ?? request.fareEstimate,
      // How far the search actually reached, so the passenger can be told
      // "no driver within N km" instead of a generic failure.
      searchRadiusKm: request.radiusKm ?? INITIAL_RADIUS_KM,
      maxSearchRadiusKm: MAX_RADIUS_KM,
      ...this.routeMetricsFor(request),
      match: await this.getMatchView(request),
    };
  }

  /**
   * Straight-line distance + duration for the searching sheet. The request
   * stores no route, so this mirrors the quote fallback (haversine at the
   * urban approach speed) — good enough for the "~ km / ~ min" strip.
   */
  private routeMetricsFor(request: InstantRideRequestEntity) {
    const fromCoords = request.fromPoint?.coordinates;
    const toCoords = request.toPoint?.coordinates;
    if (!fromCoords || !toCoords) {
      return { distanceKm: null, durationMinutes: null };
    }
    const [fromLng, fromLat] = fromCoords;
    const [toLng, toLat] = toCoords;
    const distanceKm = haversineKm(
      { latitude: fromLat, longitude: fromLng },
      { latitude: toLat, longitude: toLng },
    );
    return {
      distanceKm: Math.round(distanceKm * 10) / 10,
      durationMinutes: Math.max(
        1,
        Math.round((distanceKm / PICKUP_ETA_SPEED_KMH) * 60),
      ),
    };
  }

  /** A search that ended without a match can be started again as-is. */
  private canRetry(status: InstantRequestStatus) {
    return (
      status === InstantRequestStatus.EXPIRED ||
      status === InstantRequestStatus.NO_DRIVERS
    );
  }

  /** Matched driver/vehicle card data + pickup ETA (inDrive matched state). */
  private async getMatchView(request: InstantRideRequestEntity) {
    if (
      request.status !== InstantRequestStatus.ACCEPTED ||
      !request.matchedDriverId
    ) {
      return null;
    }
    const driver = await this.usersService
      .findById(request.matchedDriverId)
      .catch(() => null);
    const vehicle = await this.vehiclesService
      .findByDriver(request.matchedDriverId)
      .catch(() => null);
    // The passenger's booking on the instant trip — what chat, in-app calls
    // and a post-match cancellation key off.
    const booking = request.tripId
      ? await this.tripRepo.manager
          .findOne(BookingEntity, {
            where: { tripId: request.tripId, userId: request.passengerId },
            select: ['id'],
          })
          .catch(() => null)
      : null;
    return {
      tripId: request.tripId,
      bookingId: booking?.id ?? null,
      acceptedFare: request.acceptedFare,
      currency: request.currency,
      paymentMethod: request.paymentMethod ?? 'cash',
      pickupEtaSeconds: request.pickupEtaSeconds,
      driverId: request.matchedDriverId,
      driverName: driver?.name ?? null,
      driverPhotoUrl: driver?.photoUrl ?? null,
      driverRating: driver?.rating != null ? Number(driver.rating) : null,
      driverTotalRatings: driver?.totalRatings ?? null,
      vehicleModel: vehicle?.model ?? null,
      plateNumber: vehicle?.plateNumber ?? null,
      carImageUrl: vehicle?.carImageUrl ?? null,
    };
  }

  private toRequestSummary(
    request: InstantRideRequestEntity,
    locale: OfferLocale = 'ar',
    extra?: {
      pickupDistanceMeters?: number | null;
      passengerName?: string | null;
      passengerRating?: number | null;
      passengerTotalRatings?: number | null;
      passengerPhotoUrl?: string | null;
    },
  ) {
    const [fromLng, fromLat] = request.fromPoint.coordinates;
    const [toLng, toLat] = request.toPoint.coordinates;
    const routeMetrics = buildInstantOfferRouteMetrics({
      fromPoint: request.fromPoint,
      toPoint: request.toPoint,
      passengerFare: request.passengerFare,
      fareEstimate: request.fareEstimate,
      currency: request.currency,
      seatCount: request.seatCount,
      locale,
      pickupDistanceMeters: extra?.pickupDistanceMeters,
    });
    const pickupKm = Number(routeMetrics.pickupDistanceKm);
    return {
      id: request.id,
      fromName: request.fromName,
      toName: request.toName,
      // Full addresses so the details screen can show the street line under
      // each place name instead of the short label on its own.
      fromAddress: request.fromAddress,
      toAddress: request.toAddress,
      fareEstimate: request.fareEstimate,
      passengerFare: request.passengerFare ?? request.fareEstimate,
      currency: request.currency,
      paymentMethod: request.paymentMethod ?? 'cash',
      seatCount: request.seatCount,
      seatCountLabel: routeMetrics.seatCountLabel,
      pickup: { latitude: fromLat, longitude: fromLng },
      dropoff: { latitude: toLat, longitude: toLng },
      distanceKm: routeMetrics.distanceKm,
      durationMinutes: routeMetrics.durationMinutes,
      distanceLabel: routeMetrics.distanceLabel,
      durationLabel: routeMetrics.durationLabel,
      pickupDistanceKm: routeMetrics.pickupDistanceKm || null,
      pickupDistanceLabel: routeMetrics.pickupDistanceLabel || null,
      pickupEtaMinutes: Number.isFinite(pickupKm)
        ? Math.max(1, Math.round((pickupKm / PICKUP_ETA_SPEED_KMH) * 60))
        : null,
      earningsLabel: routeMetrics.earningsLabel,
      tripType: routeMetrics.tripType,
      tripTypeLabel: routeMetrics.tripTypeLabel,
      passengerName: extra?.passengerName ?? null,
      passengerRating: extra?.passengerRating ?? null,
      passengerTotalRatings: extra?.passengerTotalRatings ?? null,
      passengerPhotoUrl: extra?.passengerPhotoUrl ?? null,
    };
  }
}
