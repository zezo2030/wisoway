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
import { In, Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
  DriverAvailabilityEntity,
  InstantOfferStatus,
  InstantRequestStatus,
  InstantRideOfferEntity,
  InstantRideRequestEntity,
  TripEntity,
  TripStatus,
  TripType,
} from '../../database/entities';
import { UsersService } from '../users/users.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { LocationsService } from '../locations/locations.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  currencyForCountry,
  DEFAULT_CURRENCY,
} from '../../common/currency/country-currency';
import { InstantDispatchService } from './instant-dispatch.service';
import {
  CreateInstantRequestDto,
  QuoteInstantRequestDto,
} from './dto/create-instant-request.dto';
import { OfferResponseType, RespondOfferDto } from './dto/respond-offer.dto';
import { UpdateFareDto } from './dto/update-fare.dto';
import {
  COUNTER_FARE_MAX_FACTOR,
  COUNTER_TTL_SECONDS,
  dispatchWaveJobId,
  EXPIRE_OFFER_JOB,
  EXPIRE_REQUEST_JOB,
  FARE_BASE,
  FARE_MINIMUM,
  FARE_PER_KM,
  FARE_PER_MIN,
  INITIAL_RADIUS_KM,
  INSTANT_OFFER_TIMEOUT_QUEUE,
  INSTANT_REQUEST_EXPIRY_QUEUE,
  NUDGE_FARE_BUMP_FACTOR,
  offerTimeoutJobId,
  PASSENGER_FARE_MAX_FACTOR,
  PASSENGER_FARE_MIN_FACTOR,
  PICKUP_ETA_SPEED_KMH,
  REQUEST_TTL_SECONDS,
  requestExpiryJobId,
} from './instant-rides.constants';

type LatLng = { latitude: number; longitude: number };

function haversineKm(a: LatLng, b: LatLng): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return R * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
}

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
    @InjectQueue(INSTANT_OFFER_TIMEOUT_QUEUE)
    private readonly offerTimeoutQueue: Queue,
    @InjectQueue(INSTANT_REQUEST_EXPIRY_QUEUE)
    private readonly requestExpiryQueue: Queue,
  ) {}

  // ── Passenger ──────────────────────────────────────────────────────────────

  /** Distance-based fare recommendation shown before the passenger submits. */
  async getQuote(dto: QuoteInstantRequestDto) {
    const quote = await this.computeQuote(dto.from, dto.to);
    return {
      recommendedFare: quote.recommendedFare.toFixed(2),
      minFare: quote.minFare.toFixed(2),
      maxFare: quote.maxFare.toFixed(2),
      currency: quote.currency,
      distanceKm: Math.round(quote.distanceKm * 10) / 10,
      durationMinutes: Math.round(quote.durationMin),
    };
  }

  async createRequest(passengerId: string, dto: CreateInstantRequestDto) {
    const active = await this.requestRepo.findOne({
      where: {
        passengerId,
        status: In([
          InstantRequestStatus.SEARCHING,
          InstantRequestStatus.OFFERED,
          InstantRequestStatus.ACCEPTED,
        ]),
      },
    });
    if (active) {
      throw new ConflictException('لديك طلب رحلة نشط بالفعل.');
    }

    const seatCount = dto.seatCount ?? 1;
    const quote = await this.computeQuote(dto.from, dto.to);

    let passengerFare = quote.recommendedFare;
    if (dto.passengerFare != null) {
      const amount = Math.round(dto.passengerFare * 100) / 100;
      if (amount < quote.minFare || amount > quote.maxFare) {
        throw new BadRequestException(
          `السعر خارج الحدود المسموحة (${quote.minFare.toFixed(2)} – ${quote.maxFare.toFixed(2)} ${quote.currency}).`,
        );
      }
      passengerFare = amount;
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
        fareEstimate: passengerFare.toFixed(2),
        recommendedFare: quote.recommendedFare.toFixed(2),
        passengerFare: passengerFare.toFixed(2),
        currency: quote.currency,
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
   * Passenger raises their fare while searching (inDrive "Raise to X").
   * Bumps `fareRevision` so drivers who declined earlier get re-invited.
   */
  async updateFare(requestId: string, passengerId: string, dto: UpdateFareDto) {
    const request = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (!request) {
      throw new NotFoundException('الطلب غير موجود.');
    }
    if (request.passengerId !== passengerId) {
      throw new ForbiddenException('غير مصرح.');
    }
    if (request.status !== InstantRequestStatus.SEARCHING) {
      throw new ConflictException('لا يمكن تعديل السعر في حالة الطلب الحالية.');
    }

    const current = Number(request.passengerFare ?? request.fareEstimate ?? 0);
    const recommended = Number(request.recommendedFare ?? current);
    const maxFare =
      Math.round(recommended * PASSENGER_FARE_MAX_FACTOR * 100) / 100;
    const amount = Math.round(dto.passengerFare * 100) / 100;
    if (amount <= current || amount > maxFare) {
      throw new BadRequestException(
        `السعر الجديد يجب أن يكون أعلى من ${current.toFixed(2)} وبحد أقصى ${maxFare.toFixed(2)} ${request.currency}.`,
      );
    }

    const claim = await this.requestRepo.update(
      { id: requestId, status: InstantRequestStatus.SEARCHING },
      {
        passengerFare: amount.toFixed(2),
        fareEstimate: amount.toFixed(2),
        fareRevision: request.fareRevision + 1,
        nudgedAt: null,
      },
    );
    if (claim.affected !== 1) {
      throw new ConflictException('لا يمكن تعديل السعر في حالة الطلب الحالية.');
    }

    void this.dispatchService
      .dispatchNext(requestId)
      .catch((err: Error) =>
        this.logger.warn(
          `dispatchNext after fare raise failed: ${err.message}`,
        ),
      );

    return this.getRequest(requestId, passengerId);
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
      this.notifications
        .sendPush(offer.driverId, {
          title: 'أُلغي الطلب',
          body: 'ألغى الراكب طلب الرحلة.',
          type: 'instant_offer_cancelled',
          data: { requestId: request.id },
        })
        .catch(() => undefined);
    }

    await this.requestRepo.update(
      { id: request.id },
      { status: InstantRequestStatus.CANCELLED },
    );
    await this.removeJob(
      this.requestExpiryQueue,
      requestExpiryJobId(request.id),
    );
    await this.removeJob(
      this.requestExpiryQueue,
      dispatchWaveJobId(request.id),
    );

    return this.getRequest(request.id, passengerId);
  }

  // ── Driver ───────────────────────────────────────────────────────────────

  async getPendingOffer(driverId: string) {
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
    return {
      offer: {
        id: offer.id,
        requestId: offer.requestId,
        expiresAt: offer.expiresAt,
      },
      request: request ? this.toRequestSummary(request) : null,
    };
  }

  /**
   * Driver responds to an outstanding offer: accept at the passenger's fare,
   * counter with a higher fare, or decline.
   */
  async respondOffer(offerId: string, driverId: string, dto: RespondOfferDto) {
    if (dto.responseType === OfferResponseType.ACCEPT) {
      return this.acceptOffer(offerId, driverId);
    }
    if (dto.responseType === OfferResponseType.DECLINE) {
      return this.declineOffer(offerId, driverId);
    }
    return this.counterOffer(offerId, driverId, dto.amount);
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
    const { tripId, driverName } = await this.finalizeMatch(
      request,
      offer,
      acceptedFare,
      InstantOfferStatus.OFFERED,
    );

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

  /** Driver proposes a higher fare; the passenger has to accept it. */
  private async counterOffer(
    offerId: string,
    driverId: string,
    amount: number | undefined,
  ) {
    if (amount == null) {
      throw new BadRequestException('حدد قيمة العرض.');
    }
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

    const passengerFare = Number(
      request.passengerFare ?? request.fareEstimate ?? 0,
    );
    const proposed = Math.round(amount * 100) / 100;
    const maxCounter =
      Math.round(passengerFare * COUNTER_FARE_MAX_FACTOR * 100) / 100;
    if (proposed <= passengerFare || proposed > maxCounter) {
      throw new BadRequestException(
        `قيمة العرض يجب أن تكون أعلى من سعر الراكب وبحد أقصى ${maxCounter.toFixed(2)} ${request.currency}.`,
      );
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + COUNTER_TTL_SECONDS * 1000);
    const claim = await this.offerRepo.update(
      { id: offerId, status: InstantOfferStatus.OFFERED },
      {
        status: InstantOfferStatus.COUNTERED,
        proposedFare: proposed.toFixed(2),
        respondedAt: now,
        expiresAt,
      },
    );
    if (claim.affected !== 1) {
      throw new ConflictException('العرض لم يعد متاحاً.');
    }

    // Restart the timeout with the passenger's decision window.
    await this.removeJob(this.offerTimeoutQueue, offerTimeoutJobId(offerId));
    await this.offerTimeoutQueue
      .add(
        EXPIRE_OFFER_JOB,
        { offerId },
        {
          delay: COUNTER_TTL_SECONDS * 1000,
          jobId: offerTimeoutJobId(offerId),
          removeOnComplete: true,
          removeOnFail: true,
        },
      )
      .catch((err: Error) =>
        this.logger.warn(`Failed to enqueue counter timeout: ${err.message}`),
      );

    this.notifications
      .sendPush(request.passengerId, {
        title: 'عرض سعر من سائق',
        body: `عرض السائق ${proposed.toFixed(2)} ${request.currency} لرحلتك.`,
        type: 'instant_counter_offer',
        data: {
          requestId: request.id,
          offerId,
          proposedFare: proposed.toFixed(2),
          currency: request.currency,
          expiresAt: expiresAt.toISOString(),
        },
      })
      .catch(() => undefined);

    return {
      ok: true,
      status: InstantOfferStatus.COUNTERED,
      proposedFare: proposed.toFixed(2),
      expiresAt,
    };
  }

  // ── Passenger: respond to a driver's counter-offer ─────────────────────────

  async acceptCounterOffer(
    requestId: string,
    offerId: string,
    passengerId: string,
  ) {
    const { request, offer } = await this.getCounterPair(
      requestId,
      offerId,
      passengerId,
    );
    if (offer.expiresAt.getTime() <= Date.now()) {
      throw new ConflictException('انتهت صلاحية العرض.');
    }

    const { tripId } = await this.finalizeMatch(
      request,
      offer,
      offer.proposedFare ?? request.passengerFare ?? '0',
      InstantOfferStatus.COUNTERED,
    );

    this.notifications
      .sendPush(offer.driverId, {
        title: 'قبل الراكب عرضك!',
        body: 'توجّه إلى نقطة الانطلاق.',
        type: 'instant_counter_accepted',
        data: { requestId: request.id, tripId },
      })
      .catch(() => undefined);

    return this.getRequest(request.id, passengerId);
  }

  async declineCounterOffer(
    requestId: string,
    offerId: string,
    passengerId: string,
  ) {
    const { request, offer } = await this.getCounterPair(
      requestId,
      offerId,
      passengerId,
    );

    const claim = await this.offerRepo.update(
      { id: offer.id, status: InstantOfferStatus.COUNTERED },
      { status: InstantOfferStatus.REJECTED, respondedAt: new Date() },
    );
    if (claim.affected !== 1) {
      throw new ConflictException('العرض لم يعد متاحاً.');
    }
    await this.freeDriver(offer.driverId, request.id);
    await this.removeJob(this.offerTimeoutQueue, offerTimeoutJobId(offer.id));
    await this.requestRepo.update(
      { id: request.id, status: InstantRequestStatus.OFFERED },
      { status: InstantRequestStatus.SEARCHING },
    );

    this.notifications
      .sendPush(offer.driverId, {
        title: 'لم يُقبل عرضك',
        body: 'رفض الراكب السعر المقترح.',
        type: 'instant_counter_rejected',
        data: { requestId: request.id },
      })
      .catch(() => undefined);

    void this.dispatchService
      .dispatchNext(request.id)
      .catch((err: Error) =>
        this.logger.warn(
          `dispatchNext after counter decline failed: ${err.message}`,
        ),
      );

    return this.getRequest(request.id, passengerId);
  }

  private async getCounterPair(
    requestId: string,
    offerId: string,
    passengerId: string,
  ) {
    const request = await this.requestRepo.findOne({
      where: { id: requestId },
    });
    if (!request) {
      throw new NotFoundException('الطلب غير موجود.');
    }
    if (request.passengerId !== passengerId) {
      throw new ForbiddenException('غير مصرح.');
    }
    const offer = await this.offerRepo.findOne({
      where: { id: offerId, requestId },
    });
    if (!offer || offer.status !== InstantOfferStatus.COUNTERED) {
      throw new ConflictException('العرض لم يعد متاحاً.');
    }
    return { request, offer };
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
    expectedOfferStatus: InstantOfferStatus,
  ): Promise<{ tripId: string; driverName: string }> {
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
        { id: offer.id, status: expectedOfferStatus },
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
        tripStartedAt: now,
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

    return { tripId, driverName: driver?.name ?? '' };
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

  /** Distance-based fare recommendation + the bounds a passenger may pick in. */
  private async computeQuote(from: LatLng, to: LatLng) {
    let distanceKm: number;
    let durationMin = 0;
    try {
      const d = await this.locationsService.getDistance(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      distanceKm = d.distanceKm;
      durationMin = d.durationMinutes;
    } catch {
      distanceKm = haversineKm(from, to);
    }

    let currency = DEFAULT_CURRENCY;
    try {
      const geo = await this.locationsService.reverseGeocode(
        from.latitude,
        from.longitude,
      );
      const code = typeof geo.countryCode === 'string' ? geo.countryCode : '';
      if (code) {
        currency = currencyForCountry(code);
      }
    } catch {
      // keep default currency
    }

    const recommendedFare =
      Math.round(
        Math.max(
          FARE_MINIMUM,
          FARE_BASE + distanceKm * FARE_PER_KM + durationMin * FARE_PER_MIN,
        ) * 100,
      ) / 100;
    const minFare = Math.max(
      FARE_MINIMUM,
      Math.round(recommendedFare * PASSENGER_FARE_MIN_FACTOR * 100) / 100,
    );
    const maxFare =
      Math.round(recommendedFare * PASSENGER_FARE_MAX_FACTOR * 100) / 100;

    return {
      recommendedFare,
      minFare,
      maxFare,
      currency,
      distanceKm,
      durationMin,
    };
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
      from: { name: request.fromName, address: request.fromAddress },
      to: { name: request.toName, address: request.toAddress },
      seatCount: request.seatCount,
      fareEstimate: request.fareEstimate,
      recommendedFare: request.recommendedFare,
      passengerFare: request.passengerFare,
      acceptedFare: request.acceptedFare,
      currency: request.currency,
      matchedDriverId: request.matchedDriverId,
      tripId: request.tripId,
      expiresAt: request.expiresAt,
      counterOffer: await this.getActiveCounterOffer(request),
      nudge: this.getNudge(request),
      match: await this.getMatchView(request),
    };
  }

  /**
   * Server-owned "raise your fare" nudge: present while searching after a
   * full radius sweep found no drivers and there is still room to raise.
   */
  private getNudge(request: InstantRideRequestEntity) {
    if (
      request.status !== InstantRequestStatus.SEARCHING ||
      !request.nudgedAt
    ) {
      return null;
    }
    const current = Number(request.passengerFare ?? request.fareEstimate ?? 0);
    const recommended = Number(request.recommendedFare ?? current);
    const maxFare =
      Math.round(recommended * PASSENGER_FARE_MAX_FACTOR * 100) / 100;
    const suggested =
      Math.round(Math.min(maxFare, current * NUDGE_FARE_BUMP_FACTOR) * 100) /
      100;
    if (suggested <= current) return null;
    return {
      suggestedFare: suggested.toFixed(2),
      maxFare: maxFare.toFixed(2),
      currentFare: current.toFixed(2),
      currency: request.currency,
    };
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
    return {
      tripId: request.tripId,
      acceptedFare: request.acceptedFare,
      currency: request.currency,
      pickupEtaSeconds: request.pickupEtaSeconds,
      driverName: driver?.name ?? null,
      driverRating: driver?.rating ?? null,
      driverTotalRatings: driver?.totalRatings ?? null,
      vehicleModel: vehicle?.model ?? null,
      plateNumber: vehicle?.plateNumber ?? null,
      carImageUrl: vehicle?.carImageUrl ?? null,
    };
  }

  /** The driver's outstanding counter-offer (if any), enriched for the card UI. */
  private async getActiveCounterOffer(request: InstantRideRequestEntity) {
    if (request.status !== InstantRequestStatus.OFFERED) {
      return null;
    }
    const offer = await this.offerRepo.findOne({
      where: { requestId: request.id, status: InstantOfferStatus.COUNTERED },
      order: { offeredAt: 'DESC' },
    });
    if (!offer || offer.expiresAt.getTime() <= Date.now()) {
      return null;
    }

    const driver = await this.usersService
      .findById(offer.driverId)
      .catch(() => null);
    const vehicle = offer.vehicleId
      ? await this.vehiclesService.findById(offer.vehicleId).catch(() => null)
      : await this.vehiclesService
          .findByDriver(offer.driverId)
          .catch(() => null);

    return {
      id: offer.id,
      driverId: offer.driverId,
      driverName: driver?.name ?? null,
      driverRating: driver?.rating ?? null,
      driverTotalRatings: driver?.totalRatings ?? null,
      vehicleModel: vehicle?.model ?? null,
      plateNumber: vehicle?.plateNumber ?? null,
      proposedFare: offer.proposedFare,
      currency: request.currency,
      expiresAt: offer.expiresAt,
    };
  }

  private toRequestSummary(request: InstantRideRequestEntity) {
    const [fromLng, fromLat] = request.fromPoint.coordinates;
    return {
      id: request.id,
      fromName: request.fromName,
      toName: request.toName,
      fareEstimate: request.fareEstimate,
      passengerFare: request.passengerFare ?? request.fareEstimate,
      currency: request.currency,
      seatCount: request.seatCount,
      pickup: { latitude: fromLat, longitude: fromLng },
    };
  }
}
