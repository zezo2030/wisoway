import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DriverLocationEntity, TripEntity } from '../../database/entities';
import { UpdateDriverLocationDto } from './dto/update-driver-location.dto';

@Injectable()
export class TrackingService {
  constructor(
    @InjectRepository(DriverLocationEntity)
    private readonly locationRepo: Repository<DriverLocationEntity>,
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
  ) {}

  async updateDriverLocation(driverId: string, dto: UpdateDriverLocationDto) {
    const trip = await this.tripRepo.findOne({
      where: { id: dto.tripId, driverId },
      select: ['id', 'driverId'],
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
    };
  }

  async getLatestTripLocation(tripId: string) {
    const latest = await this.locationRepo.findOne({
      where: { tripId },
      order: { recordedAt: 'DESC' },
    });

    if (!latest) {
      return null;
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
      .addSelect(
        `ST_Distance(
          trip."fromPoint",
          ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography
        )`,
        'distance_meters',
      )
      .orderBy('distance_meters', 'ASC')
      .limit(100)
      .getRawAndEntities();

    return raw.entities.map((trip, idx) => ({
      id: trip.id,
      driverId: trip.driverId,
      fromName: trip.fromName,
      toName: trip.toName,
      departureTime: trip.departureTime,
      price: Number(trip.price),
      currency: trip.currency,
      availableSeats: trip.availableSeats,
      distanceMeters: Number(raw.raw[idx]?.distance_meters || 0),
    }));
  }
}
