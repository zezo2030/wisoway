import {
  Column,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';

type GeoPoint = {
  type: 'Point';
  coordinates: [number, number];
};

/**
 * Tracks whether a driver is currently online and accepting instant
 * (on-demand) ride requests, plus their last idle location. One row per driver.
 *
 * This is intentionally separate from `driver_locations` (which is trip-scoped):
 * here we track idle drivers who have no active trip but are waiting for an
 * instant request. The partial spatial index used for matching is created in
 * the migration (`1746300000000-create-driver-availability`).
 */
@Entity({ name: 'driver_availability' })
export class DriverAvailabilityEntity {
  @PrimaryColumn({ type: 'uuid' })
  driverId: string;

  @OneToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'driverId' })
  driver: UserEntity;

  /** Vehicle resolved when the driver goes online. */
  @Column({ type: 'uuid', nullable: true })
  vehicleId: string | null;

  @Column({ type: 'boolean', default: false })
  isOnline: boolean;

  @Column({ type: 'boolean', default: true })
  acceptsInstant: boolean;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  point: GeoPoint | null;

  /**
   * Soft lock: set to the request id while an offer is outstanding so the
   * driver isn't offered two requests at once (used by Phase 2 dispatch).
   */
  @Column({ type: 'uuid', nullable: true })
  currentRequestId: string | null;

  /** Heartbeat timestamp; drivers silent past the stale threshold are skipped. */
  @Column({ type: 'timestamptz', nullable: true })
  lastSeenAt: Date | null;

  @UpdateDateColumn()
  updatedAt: Date;
}
