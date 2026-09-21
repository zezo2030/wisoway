import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';
import { TripStatus, TripType } from './shared.enums';
import { TripShareLinkEntity } from './trip-share-link.entity';
import { TripRecurrenceRuleEntity } from './trip-recurrence-rule.entity';

type GeoPoint = {
  type: 'Point';
  coordinates: [number, number];
};

@Entity({ name: 'trips' })
@Index('trips_driver_idx', ['driverId'])
@Index('trips_status_departure_idx', ['status', 'departureTime'])
export class TripEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  driverId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'driverId' })
  driver: UserEntity;

  @Column({ type: 'varchar', nullable: true })
  driverName: string | null;

  @Column({ type: 'varchar', length: 160 })
  fromName: string;

  @Column({ type: 'text', nullable: true })
  fromAddress: string | null;

  @Column({ type: 'varchar', length: 160 })
  toName: string;

  @Column({ type: 'text', nullable: true })
  toAddress: string | null;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  @Index('trips_from_point_idx', { spatial: true })
  fromPoint: GeoPoint;

  @Column({
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
  })
  @Index('trips_to_point_idx', { spatial: true })
  toPoint: GeoPoint;

  @Column({ type: 'timestamptz' })
  departureTime: Date;

  @Column({ type: 'numeric', precision: 10, scale: 2 })
  price: string;

  @Column({ type: 'varchar', length: 5, default: 'JOD' })
  currency: string;

  @Column({ type: 'int', default: 4 })
  totalSeats: number;

  @Column({ type: 'int', default: 4 })
  availableSeats: number;

  @Column({ type: 'jsonb', nullable: true })
  seatLayout: any;

  @Column({ type: 'jsonb', default: [] })
  seats: any[];

  // ── Phase 5 additions (T097) ────────────────────────────────────────────────

  /** Intermediate stops along the route (phase 6 / US4). */
  @Column({ type: 'jsonb', default: [] })
  stops: any[];

  /** Free-text driver notes visible to passengers (phase 6 / US4). */
  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @Column({ type: 'enum', enum: TripStatus, default: TripStatus.PUBLISHED })
  status: TripStatus;

  /**
   * Scheduled (driver-published carpool) vs instant (on-demand). Instant trips
   * are created on instant-ride acceptance and are excluded from public search.
   */
  @Column({ type: 'varchar', length: 16, default: TripType.SCHEDULED })
  tripType: TripType;

  /** When the driver pressed "Start Trip". */
  @Column({ type: 'timestamptz', nullable: true })
  tripStartedAt: Date | null;

  /** When the driver pressed "Complete Trip". */
  @Column({ type: 'timestamptz', nullable: true })
  tripCompletedAt: Date | null;

  /** Set by NoShowDetectorProcessor when driver does not start the trip. */
  @Column({ type: 'timestamptz', nullable: true })
  noShowMarkedAt: Date | null;

  /** Denormalized from the most recent successful POST /tracking/location. */
  @Column({ type: 'float', nullable: true })
  lastDriverLocationLat: number | null;

  @Column({ type: 'float', nullable: true })
  lastDriverLocationLng: number | null;

  @Column({ type: 'timestamptz', nullable: true })
  lastDriverLocationAt: Date | null;

  /** Live ETA snapshot (recomputed from Directions/OSRM while in progress). */
  @Column({ type: 'float', nullable: true })
  remainingDistanceKm: number | null;

  @Column({ type: 'int', nullable: true })
  remainingDurationSeconds: number | null;

  @Column({ type: 'timestamptz', nullable: true })
  etaAt: Date | null;

  /** 0–100 progress along the planned origin→destination great-circle. */
  @Column({ type: 'float', nullable: true })
  routeProgressPercent: number | null;

  @Column({ type: 'timestamptz', nullable: true })
  etaComputedAt: Date | null;

  /** Pre-trip confirmation push sent timestamp (idempotency guard). */
  @Column({ type: 'timestamptz', nullable: true })
  preTripConfirmSentAt: Date | null;

  /** FK to the recurrence rule that spawned this trip, null for one-off trips. */
  @Column({ type: 'uuid', nullable: true })
  recurrenceRuleId: string | null;

  @ManyToOne(() => TripRecurrenceRuleEntity, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'recurrenceRuleId' })
  recurrenceRule: TripRecurrenceRuleEntity | null;

  @OneToMany(() => TripShareLinkEntity, (sl) => sl.trip)
  shareLinks: TripShareLinkEntity[];

  // ── Legacy columns (kept for backward compatibility) ─────────────────────

  @Column({ type: 'varchar', default: 'not_paid' })
  communicationFeeStatus: string;

  @Column({ type: 'text', nullable: true })
  carImageUrl: string | null;

  @Column({ type: 'boolean', default: true })
  isVisible: boolean;

  @Column({ type: 'boolean', default: false })
  driverWalletChargeApplied: boolean;

  @Column({ type: 'timestamp', nullable: true })
  driverWalletChargeAt: Date | null;

  // ── Presence settlement (012-passenger-presence-confirmation) ─────────────

  /** Idempotency guard — settlement runs exactly once per trip. */
  @Column({ type: 'timestamptz', nullable: true })
  presenceSettledAt: Date | null;

  /** Seats actually charged for, frozen at settlement. */
  @Column({ type: 'int', nullable: true })
  billableSeatCount: number | null;

  /** Fee captured from the hold at settlement. */
  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  capturedFeeAmount: string | null;

  /** The wallet hold placed at contact-unlock and settled at trip end. */
  @Column({ type: 'uuid', nullable: true })
  driverFeeHoldId: string | null;

  /** Driver marked every seat absent, or a presence dispute exists. */
  @Column({ type: 'boolean', default: false })
  presenceReviewFlagged: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
