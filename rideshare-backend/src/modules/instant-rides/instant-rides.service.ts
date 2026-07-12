import {
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
import { CreateInstantRequestDto } from './dto/create-instant-request.dto';
import {
  EXPIRE_REQUEST_JOB,
  FARE_BASE,
  FARE_MINIMUM,
  FARE_PER_KM,
  FARE_PER_MIN,
  INITIAL_RADIUS_KM,
  INSTANT_OFFER_TIMEOUT_QUEUE,
  INSTANT_REQUEST_EXPIRY_QUEUE,
  offerTimeoutJobId,
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
    const { fare, currency } = await this.estimateFare(dto.from, dto.to);
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
        currency,
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
      where: { requestId: request.id, status: InstantOfferStatus.OFFERED },
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

    const driver = await this.usersService.findById(driverId);
    const vehicle = offer.vehicleId
      ? await this.vehiclesService.findById(offer.vehicleId).catch(() => null)
      : await this.vehiclesService.findByDriver(driverId);

    let tripId = '';
    await this.requestRepo.manager.transaction(async (m) => {
      // Atomic claim — only one driver can win the offer/request.
      const offerClaim = await m.update(
        InstantRideOfferEntity,
        { id: offerId, status: InstantOfferStatus.OFFERED },
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
          matchedDriverId: driverId,
        },
      );
      if (reqClaim.affected !== 1) {
        throw new ConflictException('الطلب لم يعد متاحاً.');
      }

      const now = new Date();
      const trip = m.create(TripEntity, {
        driverId,
        driverName: driver?.name ?? null,
        fromName: request.fromName,
        fromAddress: request.fromAddress,
        toName: request.toName,
        toAddress: request.toAddress,
        fromPoint: request.fromPoint,
        toPoint: request.toPoint,
        departureTime: now,
        price: request.fareEstimate ?? '0',
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

      const fareNum = Number(request.fareEstimate ?? 0);
      const seatPrice =
        request.seatCount > 0
          ? (fareNum / request.seatCount).toFixed(2)
          : (request.fareEstimate ?? '0');
      const booking = m.create(BookingEntity, {
        tripId: savedTrip.id,
        userId: request.passengerId,
        status: BookingStatus.CONFIRMED,
        seatCount: request.seatCount,
        totalAmount: request.fareEstimate ?? '0',
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

    await this.removeJob(this.offerTimeoutQueue, offerTimeoutJobId(offerId));
    await this.removeJob(
      this.requestExpiryQueue,
      requestExpiryJobId(request.id),
    );

    this.notifications
      .sendPush(request.passengerId, {
        title: 'تم العثور على سائق!',
        body: `السائق ${driver?.name ?? ''} في الطريق إليك.`,
        type: 'instant_matched',
        data: { requestId: request.id, tripId, driverId },
      })
      .catch(() => undefined);

    return this.getRequest(request.id, request.passengerId);
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

  private async estimateFare(from: LatLng, to: LatLng) {
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

    const fare = Math.max(
      FARE_MINIMUM,
      FARE_BASE + distanceKm * FARE_PER_KM + durationMin * FARE_PER_MIN,
    );
    return { fare: fare.toFixed(2), currency };
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

  private toRequestView(request: InstantRideRequestEntity) {
    return {
      id: request.id,
      status: request.status,
      from: { name: request.fromName, address: request.fromAddress },
      to: { name: request.toName, address: request.toAddress },
      seatCount: request.seatCount,
      fareEstimate: request.fareEstimate,
      currency: request.currency,
      matchedDriverId: request.matchedDriverId,
      tripId: request.tripId,
      expiresAt: request.expiresAt,
    };
  }

  private toRequestSummary(request: InstantRideRequestEntity) {
    const [fromLng, fromLat] = request.fromPoint.coordinates;
    return {
      id: request.id,
      fromName: request.fromName,
      toName: request.toName,
      fareEstimate: request.fareEstimate,
      currency: request.currency,
      seatCount: request.seatCount,
      pickup: { latitude: fromLat, longitude: fromLng },
    };
  }
}
