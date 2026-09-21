import { ForbiddenException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DriverAvailabilityEntity } from '../../database/entities';
import { VehiclesService } from '../vehicles/vehicles.service';
import { UsersService } from '../users/users.service';
import { WalletService } from '../wallet/wallet.service';
import { SetAvailabilityDto } from './dto/set-availability.dto';
import { ErrorCodes } from '../../common/errors/error-codes';

export type DriverAvailabilityStatus = {
  driverId: string;
  isOnline: boolean;
  acceptsInstant: boolean;
  vehicleId: string | null;
  latitude: number | null;
  longitude: number | null;
  lastSeenAt: Date | null;
};

export type NearbyDriver = {
  driverId: string;
  vehicleId: string | null;
  distanceMeters: number;
};

/** Anonymous, coarse position of an online driver, shown on passenger maps. */
export type NearbyDriverPin = {
  latitude: number;
  longitude: number;
};

@Injectable()
export class DriverAvailabilityService {
  /** Drivers whose heartbeat is older than this are treated as offline. */
  private readonly staleThresholdMs = 60_000;

  constructor(
    @InjectRepository(DriverAvailabilityEntity)
    private readonly repo: Repository<DriverAvailabilityEntity>,
    private readonly vehiclesService: VehiclesService,
    private readonly usersService: UsersService,
    private readonly walletService: WalletService,
  ) {}

  /** Driver goes online/offline (and optionally reports their location). */
  async setAvailability(
    driverId: string,
    dto: SetAvailabilityDto,
  ): Promise<DriverAvailabilityStatus> {
    if (dto.isOnline) {
      const vehicleId = await this.assertCanGoOnline(driverId);
      await this.upsert(driverId, {
        isOnline: true,
        acceptsInstant: dto.acceptsInstant ?? true,
        vehicleId,
        point: this.toPoint(dto.latitude, dto.longitude),
        lastSeenAt: new Date(),
      });
    } else {
      await this.upsert(driverId, {
        isOnline: false,
        currentRequestId: null,
      });
    }
    return this.getStatus(driverId);
  }

  /** Update the driver's idle location while online. */
  async heartbeat(
    driverId: string,
    latitude: number,
    longitude: number,
  ): Promise<DriverAvailabilityStatus> {
    const row = await this.repo.findOne({ where: { driverId } });
    if (!row || !row.isOnline) {
      throw new ForbiddenException(
        'You must go online before sending location',
      );
    }
    await this.repo.update(
      { driverId },
      {
        point: this.toPoint(latitude, longitude),
        lastSeenAt: new Date(),
      },
    );
    return this.getStatus(driverId);
  }

  async getStatus(driverId: string): Promise<DriverAvailabilityStatus> {
    const row = await this.repo.findOne({ where: { driverId } });
    if (!row) {
      return {
        driverId,
        isOnline: false,
        acceptsInstant: true,
        vehicleId: null,
        latitude: null,
        longitude: null,
        lastSeenAt: null,
      };
    }
    return this.toStatus(row);
  }

  /**
   * Find online, unlocked, non-stale drivers within `radiusMeters` of a point,
   * nearest first. Used by Phase 2 dispatch to pick the next driver to offer.
   */
  async findNearbyAvailableDrivers(
    latitude: number,
    longitude: number,
    radiusMeters: number,
    options: { excludeDriverIds?: string[]; limit?: number } = {},
  ): Promise<NearbyDriver[]> {
    const staleCutoff = new Date(Date.now() - this.staleThresholdMs);
    const qb = this.repo
      .createQueryBuilder('a')
      .where('a."isOnline" = true')
      .andWhere('a."acceptsInstant" = true')
      .andWhere('a."currentRequestId" IS NULL')
      .andWhere('a."point" IS NOT NULL')
      .andWhere('a."lastSeenAt" >= :staleCutoff', { staleCutoff })
      .andWhere(
        `ST_DWithin(
          a."point",
          ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
          :radiusMeters
        )`,
        { longitude, latitude, radiusMeters },
      )
      .addSelect(
        `ST_Distance(
          a."point",
          ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography
        )`,
        'distance_meters',
      )
      .orderBy('distance_meters', 'ASC')
      .limit(options.limit ?? 20);

    const excluded = options.excludeDriverIds ?? [];
    if (excluded.length > 0) {
      qb.andWhere('a."driverId" NOT IN (:...excluded)', { excluded });
    }

    const result = await qb.getRawAndEntities();
    const rawRows = result.raw as Array<{ distance_meters?: number | string }>;
    return result.entities.map((row, idx) => ({
      driverId: row.driverId,
      vehicleId: row.vehicleId,
      distanceMeters: Number(rawRows[idx]?.distance_meters ?? 0),
    }));
  }

  /**
   * Approximate map pins of our online drivers near a point, for the
   * passenger's instant-ride map. Deliberately anonymous: no driver ids, and
   * coordinates rounded to ~110 m so a pin can't be tracked back to a specific
   * driver. Busy drivers (locked on a request) are included — they are still
   * real drivers of ours on the road nearby.
   */
  async findNearbyDriverPins(
    latitude: number,
    longitude: number,
    radiusMeters = 5_000,
    limit = 8,
  ): Promise<NearbyDriverPin[]> {
    const staleCutoff = new Date(Date.now() - this.staleThresholdMs);
    const rows: Array<{ lat: string | number; lng: string | number }> =
      await this.repo
        .createQueryBuilder('a')
        .select('ST_Y(a."point"::geometry)', 'lat')
        .addSelect('ST_X(a."point"::geometry)', 'lng')
        .where('a."isOnline" = true')
        .andWhere('a."point" IS NOT NULL')
        .andWhere('a."lastSeenAt" >= :staleCutoff', { staleCutoff })
        .andWhere(
          `ST_DWithin(
            a."point",
            ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
            :radiusMeters
          )`,
          { longitude, latitude, radiusMeters },
        )
        .addSelect(
          `ST_Distance(
            a."point",
            ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography
          )`,
          'distance_meters',
        )
        .orderBy('distance_meters', 'ASC')
        .limit(limit)
        .getRawMany();

    const round = (value: number) => Math.round(value * 1_000) / 1_000;
    return rows.map((row) => ({
      latitude: round(Number(row.lat)),
      longitude: round(Number(row.lng)),
    }));
  }

  private async assertCanGoOnline(driverId: string): Promise<string> {
    const driver = await this.usersService.findById(driverId);
    if (driver?.isDriverApproved === false) {
      throw new ForbiddenException(
        'حسابك كسائق قيد المراجعة. لا يمكنك استقبال الرحلات بعد.',
      );
    }
    const vehicle = await this.vehiclesService.findByDriver(driverId);
    if (!vehicle) {
      throw new ForbiddenException(
        'يجب تسجيل مركبة قبل استقبال الرحلات المباشرة.',
      );
    }
    if (!vehicle.isVerified) {
      throw new ForbiddenException(
        'مركبتك قيد مراجعة الإدارة. لا يمكنك استقبال الرحلات حتى يتم التحقق منها.',
      );
    }
    try {
      await this.walletService.assertNonNegativeDriverBalance(driverId);
    } catch (error) {
      if (error instanceof ForbiddenException) {
        throw new ForbiddenException({
          code: ErrorCodes.NEGATIVE_WALLET_BALANCE,
          message: 'رصيد محفظتك سالب. سدد المستحقات قبل تلقي الرحلات المباشرة.',
        });
      }
      throw error;
    }
    return vehicle.id;
  }

  private toPoint(latitude?: number, longitude?: number) {
    if (latitude == null || longitude == null) return undefined;
    return {
      type: 'Point' as const,
      coordinates: [longitude, latitude] as [number, number],
    };
  }

  private async upsert(
    driverId: string,
    patch: Partial<DriverAvailabilityEntity>,
  ): Promise<void> {
    const existing = await this.repo.findOne({ where: { driverId } });
    // merge() takes DeepPartial, so it accepts the GeoPoint object cleanly
    // (repo.update's QueryDeepPartialEntity does not). save() then upserts.
    const entity = this.repo.merge(
      existing ?? this.repo.create({ driverId }),
      patch,
    );
    await this.repo.save(entity);
  }

  private toStatus(row: DriverAvailabilityEntity): DriverAvailabilityStatus {
    const coords = row.point?.coordinates;
    return {
      driverId: row.driverId,
      isOnline: row.isOnline,
      acceptsInstant: row.acceptsInstant,
      vehicleId: row.vehicleId,
      latitude: coords ? coords[1] : null,
      longitude: coords ? coords[0] : null,
      lastSeenAt: row.lastSeenAt,
    };
  }
}
