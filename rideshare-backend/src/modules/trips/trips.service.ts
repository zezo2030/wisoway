import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';
import { SearchTripsDto } from './dto/search-trips.dto';
import { LocationBasedTripsDto } from './dto/location-based-trips.dto';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingsService } from '../bookings/bookings.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { UsersService } from '../users/users.service';

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
    private notificationsService: NotificationsService,
    private bookingsService: BookingsService,
    private vehiclesService: VehiclesService,
    private usersService: UsersService,
  ) {}

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

    const departureTime = new Date(createTripDto.departureTime);
    if (departureTime <= new Date()) {
      throw new BadRequestException('Departure time must be in the future');
    }

    const seats = this.generateSeats(
      createTripDto.seatLayout.rows,
      createTripDto.seatLayout.seatsPerRow,
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
      currency: createTripDto.currency ?? 'EGP',
      totalSeats: createTripDto.totalSeats,
      availableSeats: createTripDto.totalSeats,
      seatLayout: createTripDto.seatLayout,
      seats,
      status: TripStatus.ACTIVE,
      isVisible: true,
      communicationFeeStatus: 'not_paid',
      carImageUrl: createTripDto.carImageUrl ?? null,
    });

    return this.tripRepo.save(trip);
  }

  async findById(tripId: string): Promise<TripEntity> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('Trip not found');
    }
    return trip;
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

  async search(
    searchTripsDto: SearchTripsDto,
  ): Promise<PaginatedResult<TripEntity>> {
    const { page = 1, limit = 20, ...filters } = searchTripsDto;
    const skip = (page - 1) * limit;

    const qb = this.tripRepo
      .createQueryBuilder('trip')
      .where('trip.status = :status', {
        status: filters.status || TripStatus.ACTIVE,
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
    if (hasBookings && (updateTripDto.totalSeats || updateTripDto.seatLayout)) {
      throw new BadRequestException(
        'Cannot change seat layout when bookings exist',
      );
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
    if (updateTripDto.totalSeats != null) {
      trip.totalSeats = updateTripDto.totalSeats;
      trip.availableSeats = updateTripDto.totalSeats;
    }
    if (updateTripDto.seatLayout != null) {
      trip.seatLayout = updateTripDto.seatLayout;
      trip.seats = this.generateSeats(
        updateTripDto.seatLayout.rows,
        updateTripDto.seatLayout.seatsPerRow,
      );
    }
    if (updateTripDto.carImageUrl !== undefined)
      trip.carImageUrl = updateTripDto.carImageUrl ?? null;

    return this.tripRepo.save(trip);
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
    trip.status = TripStatus.ACTIVE;
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
    trip.status = TripStatus.CANCELLED;
    const savedTrip = await this.tripRepo.save(trip);

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
        status: seat.status,
        gender: seat.gender,
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
        status: TripStatus.ACTIVE,
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
        status: TripStatus.ACTIVE,
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

  private generateSeats(rows: number, seatsPerRow: number): any[] {
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
}
