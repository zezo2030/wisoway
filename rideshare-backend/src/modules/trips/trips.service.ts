import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Not, Repository } from 'typeorm';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { TripEntity } from '../../database/entities/trip.entity';
import { DriverAvailabilityEntity } from '../../database/entities/driver-availability.entity';
import { TripStatus, TripType } from '../../database/entities/shared.enums';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';
import { SearchTripsDto } from './dto/search-trips.dto';
import { LocationBasedTripsDto } from './dto/location-based-trips.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingsService } from '../bookings/bookings.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { UsersService } from '../users/users.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { TripsGateway } from './trips.gateway';
import { ErrorCodes } from '../../common/errors/error-codes';
import { RecurrenceService } from '../recurrence/recurrence.service';
import { RecurrenceFrequency } from '../../database/entities/trip-recurrence-rule.entity';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import { LocationsService } from '../locations/locations.service';
import { WalletService } from '../wallet/wallet.service';
import {
  currencyForCountry,
  DEFAULT_CURRENCY,
} from '../../common/currency/country-currency';
import {
  computeTripAutoStartDelayMs,
  TRIP_AUTO_START_JOB_ID_PREFIX,
  TRIP_AUTO_COMPLETE_JOB_ID_PREFIX,
} from './trip-auto-start.util';
import {
  resolveVehicleTypeTemplate,
  type SeatLayout,
} from '../vehicles/vehicle-types';

function getFromLatLng(trip: TripEntity): { lat: number; lng: number } {
  const c = trip.fromPoint?.coordinates;
  return c ? { lat: c[1], lng: c[0] } : { lat: 0, lng: 0 };
}

function getToLatLng(trip: TripEntity): { lat: number; lng: number } {
  const c = trip.toPoint?.coordinates;
  return c ? { lat: c[1], lng: c[0] } : { lat: 0, lng: 0 };
}

@Injectable()
export class TripsService {
  private readonly logger = new Logger(TripsService.name);

  constructor(
    @InjectRepository(TripEntity) private tripRepo: Repository<TripEntity>,
    @InjectRepository(DriverAvailabilityEntity)
    private driverAvailabilityRepo: Repository<DriverAvailabilityEntity>,
    private notificationsService: NotificationsService,
    private bookingsService: BookingsService,
    private vehiclesService: VehiclesService,
    private usersService: UsersService,
    private platformPricing: PlatformPricingService,
    private tripsGateway: TripsGateway,
    @InjectQueue('no-show-detector') private noShowQueue: Queue,
    @InjectQueue('trip-auto-start')
    private tripAutoStartQueue: Queue,
    @InjectQueue('trip-auto-complete')
    private tripAutoCompleteQueue: Queue,
    private recurrenceService: RecurrenceService,
    private pendingChargesService: PendingChargesService,
    private locationsService: LocationsService,
    private walletService: WalletService,
  ) {}

  /**
   * Resolve the currency for a trip from its departure point's country, so
   * fares are shown in the local currency of where the ride starts. Falls back
   * to a client-supplied currency, then the platform default, if the country
   * can't be determined (e.g. geocoding is unavailable).
   */
  private async resolveTripCurrency(
    from: { latitude: number; longitude: number },
    fallbackCurrency?: string,
  ): Promise<string> {
    try {
      const { countryCode } = await this.locationsService.reverseGeocode(
        from.latitude,
        from.longitude,
      );
      if (countryCode) {
        return currencyForCountry(countryCode);
      }
    } catch (error) {
      this.logger.warn(
        `Could not resolve trip currency from departure point: ${
          error instanceof Error ? error.message : 'unknown error'
        }`,
      );
    }
    return fallbackCurrency ?? DEFAULT_CURRENCY;
  }

  async getPricingPreview(tripId: string, countryCode: string = 'JO') {
    const trip = await this.findById(tripId);
    return this.platformPricing.pricingPreviewForTrip(trip, countryCode);
  }

  async create(
    createTripDto: CreateTripDto,
    driverId: string,
    driverName: string,
  ): Promise<TripEntity> {
    const vehicle = await this.vehiclesService.findByDriver(driverId);
    if (!vehicle) {
      throw new ForbiddenException(
        'You must register and get your vehicle approved before creating trips',
      );
    }
    if (!vehicle.isVerified) {
      throw new ForbiddenException(
        'Your vehicle is pending admin approval. You cannot create trips until it is verified.',
      );
    }

    const driver = await this.usersService.findById(driverId);
    if (driver.isDriverApproved === false) {
      throw new ForbiddenException(
        'حسابك كسائق قيد المراجعة. لا يمكنك إنشاء رحلات حتى يتم الموافقة عليه.',
      );
    }

    // T033 — Mandatory driver profile photo guard
    if (!driver.photoUrl) {
      throw new ForbiddenException({
        message: 'يجب إضافة صورة شخصية قبل نشر رحلة.',
        code: ErrorCodes.PROFILE_PHOTO_REQUIRED,
      });
    }

    const outstanding =
      await this.pendingChargesService.getOutstandingSummary(driverId);
    if (outstanding.count > 0) {
      throw new ForbiddenException({
        code: ErrorCodes.OUTSTANDING_CHARGES,
        message: `لا يمكنك نشر رحلة جديدة قبل تسوية الرسوم المستحقة (${outstanding.count}) بإجمالي ${outstanding.totalAmount.toFixed(2)}.`,
        count: outstanding.count,
        totalAmount: outstanding.totalAmount,
      });
    }

    await this.walletService.assertNonNegativeDriverBalance(driverId);

    const departureTime = new Date(createTripDto.departureTime);
    if (departureTime <= new Date()) {
      throw new BadRequestException('Departure time must be in the future');
    }

    const seatLayout = this.resolveVehicleSeatLayout(vehicle);
    const seats = this.generateSeatsFromLayout(seatLayout);
    const totalSeats = seats.length;

    // Currency follows the country of the trip's departure point.
    const currency = await this.resolveTripCurrency(
      createTripDto.from,
      createTripDto.currency,
    );

    const trip = this.tripRepo.create({
      driverId,
      driverName,
      fromName: createTripDto.from.name,
      fromAddress: createTripDto.from.address ?? null,
      toName: createTripDto.to.name,
      toAddress: createTripDto.to.address ?? null,
      fromPoint: {
        type: 'Point' as const,
        coordinates: [
          createTripDto.from.longitude,
          createTripDto.from.latitude,
        ] as [number, number],
      },
      toPoint: {
        type: 'Point' as const,
        coordinates: [
          createTripDto.to.longitude,
          createTripDto.to.latitude,
        ] as [number, number],
      },
      departureTime,
      price: String(createTripDto.price),
      currency,
      totalSeats,
      availableSeats: totalSeats,
      seatLayout,
      seats,
      stops: createTripDto.stops ?? [],
      notes: createTripDto.notes ?? null,
      status: TripStatus.PUBLISHED,
      isVisible: true,
      communicationFeeStatus: 'not_paid',
      // Car photo always comes from the driver's vehicle profile — drivers
      // don't upload it per trip. Fall back to the DTO only if a vehicle row
      // doesn't have one yet (legacy data).
      carImageUrl: vehicle.carImageUrl ?? createTripDto.carImageUrl ?? null,
    });

    const savedTrip = await this.tripRepo.save(trip);

    if (createTripDto.recurrence) {
      const rec = createTripDto.recurrence;
      const localTime = departureTime.toTimeString().slice(0, 8);
      const templateJson = {
        fromName: createTripDto.from.name,
        fromAddress: createTripDto.from.address ?? null,
        fromPoint: {
          lat: createTripDto.from.latitude,
          lng: createTripDto.from.longitude,
        },
        toName: createTripDto.to.name,
        toAddress: createTripDto.to.address ?? null,
        toPoint: {
          lat: createTripDto.to.latitude,
          lng: createTripDto.to.longitude,
        },
        price: String(createTripDto.price),
        currency,
        totalSeats,
        seatLayout,
        stops: createTripDto.stops ?? [],
        notes: createTripDto.notes ?? null,
        carImageUrl: vehicle.carImageUrl ?? createTripDto.carImageUrl ?? null,
      };

      const rule = await this.recurrenceService.createRule(
        driverId,
        templateJson,
        rec.frequency === 'daily'
          ? RecurrenceFrequency.DAILY
          : RecurrenceFrequency.WEEKLY,
        rec.weekdays,
        localTime,
        'Asia/Amman',
        rec.until ?? null,
      );

      savedTrip.recurrenceRuleId = rule.id;
      await this.tripRepo.save(savedTrip);
    }

    // T037: Enqueue city fan-out for the new trip
    this.notificationsService.enqueueCityFanout(savedTrip.id).catch((err) => {
      this.logger.warn(
        `Failed to enqueue city fan-out for trip ${savedTrip.id}: ${err.message}`,
      );
    });

    void this.scheduleTripAutoStart(
      savedTrip.id,
      new Date(savedTrip.departureTime),
    );

    return savedTrip;
  }

  async findById(
    tripId: string,
  ): Promise<
    TripEntity & {
      distanceKm?: number;
      driverPhotoUrl?: string | null;
      driverRating?: number | null;
      vehicleModel?: string | null;
      vehiclePlateNumber?: string | null;
    }
  > {
    const result = await this.tripRepo
      .createQueryBuilder('trip')
      .where('trip.id = :id', { id: tripId })
      .addSelect(
        `ST_Distance(trip."fromPoint", trip."toPoint") / 1000`,
        'distance_km',
      )
      .getRawAndEntities();

    const trip = result.entities[0];
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }

    const distanceKm = result.raw[0]?.distance_km;
    const driver = await this.usersService.findById(trip.driverId);
    const vehicle = await this.vehiclesService.findByDriver(trip.driverId);

    return {
      ...trip,
      distanceKm: distanceKm != null ? Number(distanceKm) : undefined,
      driverPhotoUrl: driver?.photoUrl ?? null,
      driverRating:
        driver?.rating != null ? Number(driver.rating) : null,
      vehicleModel: vehicle
        ? `${vehicle.model}`.trim() || null
        : null,
      vehiclePlateNumber: vehicle?.plateNumber ?? null,
      carImageUrl: trip.carImageUrl ?? vehicle?.carImageUrl ?? null,
    };
  }

  /** Internal: book a seat (used by BookingsService in transaction) */
  async bookSeat(
    tripId: string,
    seatNumber: string,
    userId: string,
    userName: string,
    gender: string | null,
  ): Promise<void> {
    const trip = await this.findById(tripId);
    const seatIndex = (trip.seats || []).findIndex(
      (s: any) => s.seatNumber === seatNumber,
    );
    if (seatIndex === -1) throw new BadRequestException('Invalid seat number');
    const seats = [...(trip.seats || [])];
    seats[seatIndex] = {
      seatNumber,
      userId,
      userName,
      gender,
      bookedAt: new Date(),
      status: 'booked',
    };
    trip.seats = seats;
    trip.availableSeats = Math.max(0, (trip.availableSeats ?? 0) - 1);
    await this.tripRepo.save(trip);
  }

  /** Internal: release a seat (used by BookingsService) */
  async releaseSeat(tripId: string, seatNumber: string): Promise<void> {
    const trip = await this.findById(tripId);
    const seatIndex = (trip.seats || []).findIndex(
      (s: any) => s.seatNumber === seatNumber,
    );
    if (seatIndex === -1) return;
    const seats = [...(trip.seats || [])];
    seats[seatIndex] = {
      seatNumber,
      userId: null,
      userName: null,
      gender: null,
      bookedAt: null,
      status: 'available',
    };
    trip.seats = seats;
    trip.availableSeats = (trip.availableSeats ?? 0) + 1;
    await this.tripRepo.save(trip);
  }

  /**
   * Driver locks a seat (e.g. sold outside the app) or unlocks it back to available.
   */
  async setSeatLock(
    tripId: string,
    seatNumber: string,
    locked: boolean,
    driverId: string,
  ): Promise<TripEntity> {
    const trip = await this.findById(tripId);
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this trip');
    }
    if (trip.status !== TripStatus.PUBLISHED) {
      throw new BadRequestException('Trip is not active');
    }

    const seats = [...(trip.seats || [])];
    const seatIndex = seats.findIndex((s: any) => s.seatNumber === seatNumber);
    if (seatIndex === -1) {
      throw new BadRequestException('Invalid seat number');
    }

    const current = seats[seatIndex];

    if (locked) {
      if (current.status !== 'available') {
        throw new BadRequestException(
          'Only available seats can be locked (not booked or already locked)',
        );
      }
      seats[seatIndex] = {
        seatNumber,
        userId: null,
        userName: null,
        gender: null,
        bookedAt: null,
        status: 'locked',
      };
      trip.availableSeats = Math.max(0, (trip.availableSeats ?? 0) - 1);
    } else {
      if (current.status !== 'locked') {
        throw new BadRequestException('Only locked seats can be unlocked');
      }
      seats[seatIndex] = {
        seatNumber,
        userId: null,
        userName: null,
        gender: null,
        bookedAt: null,
        status: 'available',
      };
      trip.availableSeats = (trip.availableSeats ?? 0) + 1;
    }

    trip.seats = seats;
    const saved = await this.tripRepo.save(trip);

    if (locked) {
      await this.tripsGateway.emitSeatBooked(tripId, seatNumber, 'locked');
    } else {
      await this.tripsGateway.emitSeatReleased(tripId, seatNumber);
    }

    return saved;
  }

  async search(
    searchTripsDto: SearchTripsDto,
  ): Promise<PaginatedResult<TripEntity>> {
    const { page = 1, limit = 20, ...filters } = searchTripsDto;
    const skip = (page - 1) * limit;

    const qb = this.tripRepo
      .createQueryBuilder('trip')
      .where('trip.status = :status', {
        status: filters.status || TripStatus.PUBLISHED,
      })
      .andWhere('trip.isVisible = :isVisible', { isVisible: true });

    if (filters.departureDate) {
      const startDate = new Date(filters.departureDate);
      const endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 1);
      qb.andWhere('trip.departureTime >= :startDate', { startDate });
      qb.andWhere('trip.departureTime < :endDate', { endDate });
    }
    if (filters.minPrice !== undefined) {
      qb.andWhere('trip.price >= :minPrice', {
        minPrice: String(filters.minPrice),
      });
    }
    if (filters.maxPrice !== undefined) {
      qb.andWhere('trip.price <= :maxPrice', {
        maxPrice: String(filters.maxPrice),
      });
    }
    if (filters.availableSeats !== undefined) {
      qb.andWhere('trip.availableSeats >= :availableSeats', {
        availableSeats: filters.availableSeats,
      });
    }

    const hasGeoFilter =
      (filters.fromLatitude != null && filters.fromLongitude != null) ||
      (filters.toLatitude != null && filters.toLongitude != null);

    const takeCount = hasGeoFilter ? 2000 : limit;
    const skipCount = hasGeoFilter ? 0 : skip;
    let data = await qb
      .orderBy('trip.departureTime', 'ASC')
      .skip(skipCount)
      .take(takeCount)
      .getMany();

    if (filters.fromLatitude != null && filters.fromLongitude != null) {
      const delta = 0.1;
      data = data.filter((trip) => {
        const { lat, lng } = getFromLatLng(trip);
        return (
          lat >= (filters.fromLatitude ?? 0) - delta &&
          lat <= (filters.fromLatitude ?? 0) + delta &&
          lng >= (filters.fromLongitude ?? 0) - delta &&
          lng <= (filters.fromLongitude ?? 0) + delta
        );
      });
    }
    if (filters.toLatitude != null && filters.toLongitude != null) {
      const delta = 0.1;
      data = data.filter((trip) => {
        const { lat, lng } = getToLatLng(trip);
        return (
          lat >= (filters.toLatitude ?? 0) - delta &&
          lat <= (filters.toLatitude ?? 0) + delta &&
          lng >= (filters.toLongitude ?? 0) - delta &&
          lng <= (filters.toLongitude ?? 0) + delta
        );
      });
    }

    const total = data.length;
    if (hasGeoFilter) {
      data = data.slice(skip, skip + limit);
    }

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findByDriver(
    driverId: string,
    pagination: { page: number; limit: number },
  ): Promise<PaginatedResult<TripEntity>> {
    const { page = 1, limit = 20 } = pagination;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.tripRepo.find({
        where: { driverId },
        order: { createdAt: 'DESC' },
        skip,
        take: limit,
      }),
      this.tripRepo.count({ where: { driverId } }),
    ]);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async update(
    tripId: string,
    updateTripDto: UpdateTripDto,
    driverId: string,
  ): Promise<TripEntity> {
    const trip = await this.findById(tripId);
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this trip');
    }

    const hasBookings = (trip.seats || []).some(
      (seat: any) => seat.status === 'booked',
    );

    if (
      updateTripDto.departureTime != null &&
      hasBookings &&
      (new Date(updateTripDto.departureTime).getTime() - Date.now()) /
        (1000 * 60 * 60) <=
        24
    ) {
      throw new ForbiddenException({
        message: 'Cannot change departure time within 24h when bookings exist',
        code: ErrorCodes.CANCELLATION_WINDOW_CLOSED,
      });
    }

    if (updateTripDto.from) {
      trip.fromName = updateTripDto.from.name;
      trip.fromAddress = updateTripDto.from.address ?? trip.fromAddress;
      trip.fromPoint = {
        type: 'Point',
        coordinates: [
          updateTripDto.from.longitude,
          updateTripDto.from.latitude,
        ] as [number, number],
      };
    }
    if (updateTripDto.to) {
      trip.toName = updateTripDto.to.name;
      trip.toAddress = updateTripDto.to.address ?? trip.toAddress;
      trip.toPoint = {
        type: 'Point',
        coordinates: [
          updateTripDto.to.longitude,
          updateTripDto.to.latitude,
        ] as [number, number],
      };
    }
    if (updateTripDto.departureTime != null)
      trip.departureTime = new Date(updateTripDto.departureTime);
    if (updateTripDto.price != null) trip.price = String(updateTripDto.price);
    if (updateTripDto.currency != null) trip.currency = updateTripDto.currency;
    if (updateTripDto.carImageUrl !== undefined)
      trip.carImageUrl = updateTripDto.carImageUrl ?? null;
    if (updateTripDto.notes !== undefined) trip.notes = updateTripDto.notes;
    if (updateTripDto.stops !== undefined) trip.stops = updateTripDto.stops;

    const saved = await this.tripRepo.save(trip);
    await this.rescheduleTripAutoStart(saved.id, new Date(saved.departureTime));
    return saved;
  }

  async hide(tripId: string, driverId: string): Promise<TripEntity> {
    const trip = await this.findById(tripId);
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this trip');
    }
    trip.status = TripStatus.HIDDEN;
    trip.isVisible = false;
    return this.tripRepo.save(trip);
  }

  async show(tripId: string, driverId: string): Promise<TripEntity> {
    const trip = await this.findById(tripId);
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this trip');
    }
    trip.status = TripStatus.PUBLISHED;
    trip.isVisible = true;
    return this.tripRepo.save(trip);
  }

  async complete(tripId: string, driverId: string): Promise<TripEntity> {
    const trip = await this.findById(tripId);
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this trip');
    }
    if (trip.status === TripStatus.COMPLETED) {
      throw new BadRequestException('Trip is already completed');
    }
    trip.status = TripStatus.COMPLETED;
    const savedTrip = await this.tripRepo.save(trip);

    // Instant trips: release the driver's availability lock so they can take
    // new on-demand requests once this ride is done.
    if (savedTrip.tripType === TripType.INSTANT) {
      await this.driverAvailabilityRepo.update(
        { driverId, currentRequestId: Not(IsNull()) },
        { currentRequestId: null },
      );
    }

    await this.removeTripLifecycleJobs(tripId);

    await this.bookingsService.markAsCompleted(tripId);
    const bookings = await this.bookingsService.findByTripInternal(tripId);
    for (const booking of bookings) {
      await this.notificationsService.create({
        userId: booking.userId,
        type: 'trip_completed',
        title: 'Trip Completed',
        body: `The trip to ${trip.toName} has been completed`,
        data: { tripId },
      });
    }

    // T080: Enqueue no-show detection after the grace window
    const graceSeconds = process.env.NO_SHOW_GRACE_OVERRIDE_SECONDS
      ? Number(process.env.NO_SHOW_GRACE_OVERRIDE_SECONDS)
      : 30 * 60; // 30 minutes default
    this.noShowQueue
      .add(
        'detect-no-shows',
        { tripId },
        {
          delay: graceSeconds * 1000,
          attempts: 2,
          backoff: { type: 'exponential', delay: 10000 },
          jobId: `no-show-${tripId}`,
          removeOnComplete: true,
        },
      )
      .catch((err) =>
        this.logger.warn(
          `Failed to enqueue no-show detector for trip ${tripId}: ${(err as Error).message}`,
        ),
      );

    this.logger.log(`Trip ${tripId} completed`);
    return savedTrip;
  }

  async cancel(tripId: string, driverId: string): Promise<TripEntity> {
    const trip = await this.findById(tripId);
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this trip');
    }
    if (trip.status === TripStatus.COMPLETED) {
      throw new BadRequestException('Cannot cancel a completed trip');
    }

    const hoursUntilDeparture =
      (new Date(trip.departureTime).getTime() - Date.now()) / (1000 * 60 * 60);
    if (hoursUntilDeparture <= 24) {
      const windowSeconds = Math.max(
        0,
        Math.floor(
          (new Date(trip.departureTime).getTime() -
            24 * 60 * 60 * 1000 -
            Date.now()) /
            1000,
        ),
      );
      throw new ForbiddenException({
        message: 'Cannot cancel within 24 hours of departure',
        code: ErrorCodes.CANCELLATION_WINDOW_CLOSED,
        windowSeconds,
      });
    }

    trip.status = TripStatus.CANCELLED;
    const savedTrip = await this.tripRepo.save(trip);

    await this.removeTripLifecycleJobs(tripId);

    await this.bookingsService.cancelAllForTrip(
      tripId,
      'Trip cancelled by driver',
    );
    const bookings = await this.bookingsService.findByTripInternal(tripId);
    for (const booking of bookings) {
      await this.notificationsService.create({
        userId: booking.userId,
        type: 'trip_cancelled',
        title: 'Trip Cancelled',
        body: `The trip to ${trip.toName} has been cancelled by the driver`,
        data: { tripId },
      });
    }
    this.logger.log(`Trip ${tripId} cancelled`);
    return savedTrip;
  }

  async getSeats(tripId: string): Promise<{ seatLayout: any; seats: any[] }> {
    const trip = await this.findById(tripId);
    return {
      seatLayout: trip.seatLayout,
      seats: (trip.seats || []).map((seat: any) => ({
        seatNumber: seat.seatNumber,
        status: seat.status ?? 'available',
        gender: seat.gender,
        passengerGender: seat.gender ?? undefined,
      })),
    };
  }

  async getNearbyTrips(
    query: LocationBasedTripsDto,
  ): Promise<PaginatedResult<TripEntity>> {
    const { page = 1, limit = 20, latitude, longitude } = query;
    const radiusKm = query.radiusKm ?? 50;
    const skip = (page - 1) * limit;
    const now = new Date();

    const candidates = await this.tripRepo.find({
      where: {
        status: TripStatus.PUBLISHED,
        isVisible: true,
      },
      order: { departureTime: 'ASC' },
      take: 300,
    });

    const withDistance = candidates
      .filter(
        (trip) =>
          trip.availableSeats > 0 && new Date(trip.departureTime) >= now,
      )
      .map((trip) => {
        const { lat, lng } = getFromLatLng(trip);
        return {
          trip,
          distanceKm: this.calculateDistanceKm(latitude, longitude, lat, lng),
        };
      })
      .filter((item) => item.distanceKm <= radiusKm)
      .sort((a, b) => a.distanceKm - b.distanceKm);

    const total = withDistance.length;
    const data = withDistance
      .slice(skip, skip + limit)
      .map((item) => item.trip);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async getPreferredTrips(
    query: LocationBasedTripsDto,
  ): Promise<PaginatedResult<TripEntity>> {
    const { page = 1, limit = 20, latitude, longitude } = query;
    const radiusKm = query.radiusKm ?? 80;
    const skip = (page - 1) * limit;
    const now = new Date();

    const candidates = await this.tripRepo.find({
      where: {
        status: TripStatus.PUBLISHED,
        isVisible: true,
      },
      order: { departureTime: 'ASC' },
      take: 500,
    });

    const inRadius = candidates.filter((trip) => {
      if (trip.availableSeats <= 0 || new Date(trip.departureTime) < now)
        return false;
      const { lat, lng } = getFromLatLng(trip);
      return (
        this.calculateDistanceKm(latitude, longitude, lat, lng) <= radiusKm
      );
    });

    const locationRoutes = this.getPreferredRouteKeywords(inRadius, {
      latitude,
      longitude,
    });

    const scoredTrips: Array<{
      trip: TripEntity;
      score: number;
      distanceKm: number;
    }> = [];

    for (const trip of inRadius) {
      const { lat, lng } = getFromLatLng(trip);
      const distanceKm = this.calculateDistanceKm(
        latitude,
        longitude,
        lat,
        lng,
      );
      const fromName = this.normalizeArabic(trip.fromName);
      const toName = this.normalizeArabic(trip.toName);
      let score = Math.max(0, 70 - distanceKm);
      for (const route of locationRoutes) {
        if (
          route.from.some((key) => fromName.includes(key)) &&
          route.to.some((key) => toName.includes(key))
        ) {
          score += 120;
        }
      }
      scoredTrips.push({ trip, score, distanceKm });
    }

    scoredTrips.sort(
      (a, b) => b.score - a.score || a.distanceKm - b.distanceKm,
    );

    const total = scoredTrips.length;
    const data = scoredTrips.slice(skip, skip + limit).map((item) => item.trip);

    return {
      data,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  private calculateDistanceKm(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const toRad = (value: number) => (value * Math.PI) / 180;
    const earthRadiusKm = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  private normalizeArabic(value: string): string {
    return value
      .toLowerCase()
      .trim()
      .replace(/\s+/g, ' ')
      .replace(/أ|إ|آ/g, 'ا')
      .replace(/ة/g, 'ه');
  }

  private getPreferredRouteKeywords(
    trips: TripEntity[],
    rider: { latitude: number; longitude: number },
  ): Array<{ from: string[]; to: string[] }> {
    const knownRoutes: Array<{ from: string[]; to: string[] }> = [
      { from: ['جده', 'jeddah'], to: ['مكه', 'mecca', 'makkah'] },
      { from: ['جده', 'jeddah'], to: ['المدينه', 'madinah', 'medina'] },
      { from: ['الطفيله', 'tafila', 'tafila'], to: ['عمان', 'amman'] },
      {
        from: ['جامعه مؤته', 'مؤته', 'mu tah', 'mutah'],
        to: ['عمان', 'amman'],
      },
      { from: ['الكرك', 'karak'], to: ['عمان', 'amman'] },
    ];

    const nearbyOrigins = trips
      .filter(
        (trip) =>
          this.calculateDistanceKm(
            rider.latitude,
            rider.longitude,
            getFromLatLng(trip).lat,
            getFromLatLng(trip).lng,
          ) <= 80,
      )
      .map((trip) => this.normalizeArabic(trip.fromName));

    const matched = knownRoutes.filter((route) =>
      nearbyOrigins.some((origin) =>
        route.from.some((fromKeyword) => origin.includes(fromKeyword)),
      ),
    );

    return matched.length > 0 ? matched : knownRoutes;
  }

  private resolveVehicleSeatLayout(vehicle: {
    seats: number;
    vehicleType?: string;
    seatLayout: {
      rows: number;
      seatsPerRow: number;
      seatsPerRowList?: number[];
      preventGenderMixing?: boolean;
    } | null;
  }): SeatLayout {
    if (vehicle.seatLayout) {
      return vehicle.seatLayout;
    }
    const template = resolveVehicleTypeTemplate(
      vehicle.vehicleType,
      this.logger,
    );
    return template.layout;
  }

  private generateSeatsFromLayout(layout: {
    rows: number;
    seatsPerRow: number;
    seatsPerRowList?: number[];
  }): any[] {
    const list = layout.seatsPerRowList;
    if (list && list.length > 0) {
      const seats: any[] = [];
      for (let row = 0; row < list.length; row++) {
        const count = list[row];
        for (let col = 0; col < count; col++) {
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
    return this.generateSeatsGrid(layout.rows, layout.seatsPerRow);
  }

  private generateSeatsGrid(rows: number, seatsPerRow: number): any[] {
    const seats: any[] = [];
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < seatsPerRow; col++) {
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

  /** Schedule auto-transition PUBLISHED/FULLY_BOOKED → IN_PROGRESS at departureTime. */
  private async scheduleTripAutoStart(
    tripId: string,
    departureTime: Date,
  ): Promise<void> {
    const delay = computeTripAutoStartDelayMs(departureTime);
    try {
      await this.tripAutoStartQueue.add(
        'enforce',
        { tripId },
        {
          delay,
          jobId: `${TRIP_AUTO_START_JOB_ID_PREFIX}${tripId}`,
          removeOnComplete: true,
          attempts: 2,
          backoff: { type: 'exponential', delay: 15000 },
        },
      );
    } catch (err) {
      this.logger.warn(
        `Failed to schedule trip auto-start for trip ${tripId}: ${(err as Error).message}`,
      );
    }
  }

  async removeTripLifecycleJobs(tripId: string): Promise<void> {
    try {
      const startJob = await this.tripAutoStartQueue.getJob(
        `${TRIP_AUTO_START_JOB_ID_PREFIX}${tripId}`,
      );
      await startJob?.remove();
    } catch (err) {
      this.logger.warn(
        `remove trip-auto-start job ${tripId}: ${(err as Error).message}`,
      );
    }
    try {
      const completeJob = await this.tripAutoCompleteQueue.getJob(
        `${TRIP_AUTO_COMPLETE_JOB_ID_PREFIX}${tripId}`,
      );
      await completeJob?.remove();
    } catch (err) {
      this.logger.warn(
        `remove trip-auto-complete job ${tripId}: ${(err as Error).message}`,
      );
    }
  }

  private async rescheduleTripAutoStart(
    tripId: string,
    departureTime: Date,
  ): Promise<void> {
    await this.removeTripLifecycleJobs(tripId);
    await this.scheduleTripAutoStart(tripId, departureTime);
  }
}
