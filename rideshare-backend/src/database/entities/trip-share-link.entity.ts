/**
 * TripShareLink entity
 *
 * A share link lets a confirmed passenger (or the driver) share a
 * public, read-only, PII-free view of the trip's live status.
 *
 * Phase 5 / T094 — 008-platform-completion, US3 / 011-trip-time-flow.
 */
import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { TripEntity } from './trip.entity';
import { UserEntity } from './user.entity';

@Entity({ name: 'trip_share_links' })
@Index('idx_trip_share_links_token', ['token'], { unique: true })
@Index('idx_trip_share_links_trip', ['tripId'])
export class TripShareLinkEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** The trip this share link is for. */
  @Column({ name: 'tripId', type: 'uuid' })
  tripId: string;

  @ManyToOne(() => TripEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity;

  /**
   * The user who created the share link (confirmed passenger or driver).
   * Stored for auditing; the public read endpoint does not expose it.
   */
  @Column({ name: 'createdByUserId', type: 'uuid' })
  createdByUserId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'createdByUserId' })
  createdByUser: UserEntity;

  /**
   * 32-byte URL-safe random token (base64url-encoded, ~43 chars).
   * Unique across the table.
   */
  @Column({ type: 'varchar', length: 64, unique: true })
  token: string;

  /**
   * When the link becomes inactive.
   * Default: trip.departureTime + 6 h.
   * On trip completion, refreshed to completedAt + 30 min (FR-036).
   */
  @Column({ type: 'timestamptz' })
  expiresAt: Date;

  @CreateDateColumn()
  createdAt: Date;
}
