import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DriverLocationEntity, TripEntity } from '../../database/entities';
import { UpdateDriverLocationDto } from './dto/update-driver-location.dto';
import { LocationsService } from '../locations/locations.service';

const ETA_REFRESH_MS = 45_000;

@Injectable()
export class TrackingService {
  private readonly logger = new Logger(TrackingService.name);
  private readonly etaInFlight = new Set<string>();

  constructor(
    @InjectRepository(DriverLocationEntity)
    private readonly locationRepo: Repository<DriverLocationEntity>,
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    private readonly locationsService: LocationsService,
  ) {}

  async updateDriverLocation(driverId: string, dto: UpdateDriverLocationDto) {
    const trip = await this.tripRepo.findOne({
      where: { id: dto.tripId, driverId },
      select: [
        'id',
        'driverId',
        'toPoint',
        'fromPoint',
        'etaComputedAt',
        'remainingDistanceKm',
        'remainingDurationSeconds',
        'etaAt',
        'routeProgressPercent',
      ],
    });
    if (!trip) {
      throw new NotFoundException('Trip not found for this driver');
    }

    const entity = this.locationRepo.create({
      driverId,
      tripId: dto.tripId,
      point: {
        type: 'Point',
        coordinates: [dto.longitude, dto.latitude],
      },
      speedKph: dto.speedKph?.toString() ?? null,
      heading: dto.heading?.toString() ?? null,
      accuracyMeters: dto.accuracyMeters?.toString() ?? null,
      recordedAt: new Date(),
    });
    const saved = await this.locationRepo.save(entity);

    await this.tripRepo.update(
      { id: dto.tripId },
      {
        lastDriverLocationLat: dto.latitude,
        lastDriverLocationLng: dto.longitude,
        lastDriverLocationAt: new Date(),
      },
    );

    const eta = await this.maybeRefreshEta(trip, dto.latitude, dto.longitude);

    return {
      id: saved.id,
      tripId: saved.tripId,
      driverId: saved.driverId,
      latitude: dto.latitude,
      longitude: dto.longitude,
      speedKph: dto.speedKph ?? null,
      heading: dto.heading ?? null,
      accuracyMeters: dto.accuracyMeters ?? null,
      recordedAt: saved.recordedAt,
      remainingDistanceKm:
        eta?.remainingDistanceKm ?? trip.remainingDistanceKm ?? null,
      remainingDurationSeconds:
        eta?.remainingDurationSeconds ??
        trip.remainingDurationSeconds ??
        null,
      etaAt: eta?.etaAt ?? trip.etaAt ?? null,
      routeProgressPercent:
        eta?.routeProgressPercent ?? trip.routeProgressPercent ?? null,
    };
  }

  private async maybeRefreshEta(
    trip: Pick<
      TripEntity,
      | 'id'
      | 'toPoint'
      | 'fromPoint'
      | 'etaComputedAt'
      | 'remainingDistanceKm'
      | 'remainingDurationSeconds'
      | 'etaAt'
      | 'routeProgressPercent'
    >,
    latitude: number,
    longitude: number,
  ): Promise<{
    remainingDistanceKm: number;
    remainingDurationSeconds: number;
    etaAt: Date;
    routeProgressPercent: number;
  } | null> {
    const now = Date.now();
    const last = trip.etaComputedAt
      ? new Date(trip.etaComputedAt).getTime()
      : 0;
    if (last && now - last < ETA_REFRESH_MS) {
      return null;
    }
    if (this.etaInFlight.has(trip.id)) {
      return null;
    }

    const dest = trip.toPoint?.coordinates;
    if (!dest || dest.length < 2) {
      return null;
    }

    this.etaInFlight.add(trip.id);
    try {
      const route = await this.locationsService.getRoute(
        latitude,
        longitude,
        dest[1],
        dest[0],
      );

      const distanceMeters = route.distanceMeters;
      const durationSeconds = route.durationSeconds;
      if (distanceMeters == null || durationSeconds == null) {
        return null;
      }

      const remainingDistanceKm = Number((distanceMeters / 1000).toFixed(2));
      const remainingDurationSeconds = Math.max(0, Math.round(durationSeconds));
      const etaAt = new Date(now + remainingDurationSeconds * 1000);
      const routeProgressPercent = this.computeProgressPercent(
        trip.fromPoint?.coordinates,
        dest,
        [longitude, latitude],
      );

      await this.tripRepo.update(
        { id: trip.id },
        {
          remainingDistanceKm,
          remainingDurationSeconds,
          etaAt,
          routeProgressPercent,
          etaComputedAt: new Date(now),
        },
      );

      return {
        remainingDistanceKm,
        remainingDurationSeconds,
        etaAt,
        routeProgressPercent,
      };
    } catch (error) {
      this.logger.warn(
        `ETA refresh failed for trip ${trip.id}: ${(error as Error).message}`,
      );
      return null;
    } finally {
      this.etaInFlight.delete(trip.id);
    }
  }

  /** Rough progress: how much of origin→destination great-circle is covered. */
  private computeProgressPercent(
    fromCoords: [number, number] | undefined,
    toCoords: [number, number],
    currentCoords: [number, number],
  ): number {
    if (!fromCoords || fromCoords.length < 2) {
      return 0;
    }
    const total = this.haversineKm(
      fromCoords[1],
      fromCoords[0],
      toCoords[1],
      toCoords[0],
    );
    if (total <= 0.01) {
      return 100;
    }
    const remaining = this.haversineKm(
      currentCoords[1],
      currentCoords[0],
      toCoords[1],
      toCoords[0],
    );
    const done = Math.max(0, Math.min(100, ((total - remaining) / total) * 100));
    return Number(done.toFixed(1));
  }

  private haversineKm(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const toRad = (d: number) => (d * Math.PI) / 180;
    const r = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) *
        Math.cos(toRad(lat2)) *
        Math.sin(dLon / 2) ** 2;
    return 2 * r * Math.asin(Math.sqrt(a));
  }

  async getLatestTripLocation(tripId: string) {
    const latest = await this.locationRepo.findOne({
      where: { tripId },
      order: { recordedAt: 'DESC' },
    });

    const trip = await this.tripRepo.findOne({
      where: { id: tripId },
      select: [
        'id',
        'remainingDistanceKm',
        'remainingDurationSeconds',
        'etaAt',
        'routeProgressPercent',
        'lastDriverLocationLat',
        'lastDriverLocationLng',
        'lastDriverLocationAt',
      ],
    });

    if (!latest && !trip) {
      return null;
    }

    if (!latest) {
      if (
        trip?.lastDriverLocationLat == null ||
        trip?.lastDriverLocationLng == null
      ) {
        return null;
      }
      return {
        id: null,
        tripId,
        driverId: null,
        latitude: trip.lastDriverLocationLat,
        longitude: trip.lastDriverLocationLng,
        speedKph: null,
        heading: null,
        accuracyMeters: null,
        recordedAt: trip.lastDriverLocationAt,
        remainingDistanceKm: trip.remainingDistanceKm,
        remainingDurationSeconds: trip.remainingDurationSeconds,
        etaAt: trip.etaAt,
        routeProgressPercent: trip.routeProgressPercent,
      };
    }

    return {
      id: latest.id,
      tripId: latest.tripId,
      driverId: latest.driverId,
      latitude: latest.point.coordinates[1],
      longitude: latest.point.coordinates[0],
      speedKph: latest.speedKph ? Number(latest.speedKph) : null,
      heading: latest.heading ? Number(latest.heading) : null,
      accuracyMeters: latest.accuracyMeters
        ? Number(latest.accuracyMeters)
        : null,
      recordedAt: latest.recordedAt,
      remainingDistanceKm: trip?.remainingDistanceKm ?? null,
      remainingDurationSeconds: trip?.remainingDurationSeconds ?? null,
      etaAt: trip?.etaAt ?? null,
      routeProgressPercent: trip?.routeProgressPercent ?? null,
    };
  }

  async getTripLocationHistory(tripId: string, limit = 100) {
    const rows = await this.locationRepo.find({
      where: { tripId },
      order: { recordedAt: 'DESC' },
      take: Math.min(Math.max(limit, 1), 500),
    });
    return rows.map((row) => ({
      id: row.id,
      tripId: row.tripId,
      driverId: row.driverId,
      latitude: row.point.coordinates[1],
      longitude: row.point.coordinates[0],
      speedKph: row.speedKph ? Number(row.speedKph) : null,
      heading: row.heading ? Number(row.heading) : null,
      accuracyMeters: row.accuracyMeters ? Number(row.accuracyMeters) : null,
      recordedAt: row.recordedAt,
    }));
  }

  async getNearbyTrips(
    latitude: number,
    longitude: number,
    radiusMeters = 5000,
  ) {
    const raw = await this.tripRepo
      .createQueryBuilder('trip')
      .where('trip.status = :status', { status: 'active' })
      .andWhere('trip."isVisible" = true')
      .andWhere(
        `ST_DWithin(
          trip."fromPoint",
          ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
          :radiusMeters
        )`,
        { longitude, latitude, radiusMeters },
      )
      .getMany();
    return raw;
  }
}
