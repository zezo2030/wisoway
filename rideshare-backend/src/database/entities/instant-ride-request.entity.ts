import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';

type GeoPoint = {
  type: 'Point';
  coordinates: [number, number];
};

export const InstantRequestStatus = {
  /** Searching for a driver (no offer outstanding right now). */
  SEARCHING: 'searching',
  /** An offer is outstanding with a driver, awaiting their response. */
  OFFERED: 'offered',
  /** A driver accepted; `tripId`/`matchedDriverId` are set. */
  ACCEPTED: 'accepted',
  /** No driver could be matched within the search window/radius. */
  NO_DRIVERS: 'no_drivers',
  /** The overall request window elapsed. */
  EXPIRED: 'expired',
  /** The passenger cancelled while searching. */
  CANCELLED: 'cancelled',
} as const;
export type InstantRequestStatus =
  (typeof InstantRequestStatus)[keyof typeof InstantRequestStatus];

/** Why a request stopped searching — drives the passenger-facing end screen. */
export const InstantTerminalReason = {
  /** No offer was ever made during the whole search window. */
  NO_ELIGIBLE_DRIVERS: 'no_eligible_drivers',
  /** One or more offers were made and all ended declined/timed out. */
  ALL_DECLINED: 'all_declined',
  /** The TTL elapsed while an offer was still outstanding. */
  TTL_EXPIRED: 'ttl_expired',
  /** The passenger cancelled explicitly. */
  PASSENGER_CANCELLED: 'passenger_cancelled',
} as const;
export type InstantTerminalReason =
  (typeof InstantTerminalReason)[keyof typeof InstantTerminalReason];

/** A passenger's on-demand ("اطلب الآن") ride request. */
@Entity({ name: 'instant_ride_requests' })
@Index('instant_requests_passenger_status_idx', ['passengerId', 'status'])
export class InstantRideRequestEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  passengerId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'passengerId' })
  passenger: UserEntity;

  @Column({ type: 'varchar', length: 160 })
  fromName: string;

  @Column({ type: 'text', nullable: true })
  fromAddress: string | null;

  @Column({ type: 'geography', spatialFeatureType: 'Point', srid: 4326 })
  @Index('instant_requests_from_point_idx', { spatial: true })
  fromPoint: GeoPoint;

  @Column({ type: 'varchar', length: 160 })
  toName: string;

  @Column({ type: 'text', nullable: true })
  toAddress: string | null;

  @Column({ type: 'geography', spatialFeatureType: 'Point', srid: 4326 })
  toPoint: GeoPoint;

  @Column({ type: 'int', default: 1 })
  seatCount: number;

  @Column({
    type: 'varchar',
    length: 16,
    default: InstantRequestStatus.SEARCHING,
  })
  status: InstantRequestStatus;

  /** Fare locked at request time (numeric → string in TypeORM). */
  @Column({ type: 'numeric', precision: 10, scale: 2, nullable: true })
  fareEstimate: string | null;

  /** Server-recommended fare (distance-based) at quote time. */
  @Column({ type: 'numeric', precision: 10, scale: 2, nullable: true })
  recommendedFare: string | null;

  /** The fare the passenger is asking (total ride fare). */
  @Column({ type: 'numeric', precision: 10, scale: 2, nullable: true })
  passengerFare: string | null;

  /** Immutable final fare agreed at match time. */
  @Column({ type: 'numeric', precision: 10, scale: 2, nullable: true })
  acceptedFare: string | null;

  /** Bumped on every fare raise; re-qualifies drivers who declined earlier. */
  @Column({ type: 'int', default: 1 })
  fareRevision: number;

  /** Set once a full radius sweep found no drivers → "raise your fare" nudge. */
  @Column({ type: 'timestamptz', nullable: true })
  nudgedAt: Date | null;

  /** Estimated driver→pickup travel time, computed at match. */
  @Column({ type: 'int', nullable: true })
  pickupEtaSeconds: number | null;

  @Column({ type: 'varchar', length: 5, default: 'JOD' })
  currency: string;

  /** Current search radius in km; expands while searching. */
  @Column({ type: 'double precision', default: 3 })
  radiusKm: number;

  /** Set together with the terminal status; null while the request is live. */
  @Column({ type: 'varchar', length: 32, nullable: true })
  terminalReason: InstantTerminalReason | null;

  /** When searching stopped (matched, gave up, or cancelled). */
  @Column({ type: 'timestamptz', nullable: true })
  endedAt: Date | null;

  /** The request this one is a retry of — audit link, one retry per request. */
  @Column({ type: 'uuid', nullable: true })
  retryOfRequestId: string | null;

  @ManyToOne(() => InstantRideRequestEntity, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'retryOfRequestId' })
  retryOfRequest: InstantRideRequestEntity | null;

  @Column({ type: 'uuid', nullable: true })
  matchedDriverId: string | null;

  @Column({ type: 'uuid', nullable: true })
  tripId: string | null;

  @Column({ type: 'timestamptz' })
  expiresAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
