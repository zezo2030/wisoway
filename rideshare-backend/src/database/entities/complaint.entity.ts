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
import { TripEntity } from './trip.entity';
import { BookingEntity } from './booking.entity';

export const ComplaintCategory = {
  SAFETY: 'safety',
  RUDE_BEHAVIOR: 'rude_behavior',
  NO_SHOW: 'no_show',
  PAYMENT: 'payment',
  VEHICLE_CONDITION: 'vehicle_condition',
  OTHER: 'other',
} as const;
export type ComplaintCategory =
  (typeof ComplaintCategory)[keyof typeof ComplaintCategory];

export const ComplaintStatus = {
  OPEN: 'open',
  IN_REVIEW: 'in_review',
  RESOLVED: 'resolved',
  REJECTED: 'rejected',
} as const;
export type ComplaintStatus =
  (typeof ComplaintStatus)[keyof typeof ComplaintStatus];

/**
 * A complaint filed by a user against another user, a trip, or a booking.
 *
 * Phase 8 (008-platform-completion / US6 — admin-and-support):
 *  - Created via POST /complaints (T167).
 *  - Resolved/rejected by admin via PATCH /admin/complaints/:id (T168).
 */
@Entity({ name: 'complaints' })
@Index('idx_complaints_status_created', ['status', 'createdAt'])
@Index('idx_complaints_against_user', ['againstUserId'])
@Index('idx_complaints_reporter', ['reporterId'])
export class ComplaintEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** User who filed the complaint. */
  @Column({ type: 'uuid' })
  reporterId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporterId' })
  reporter: UserEntity;

  /** User the complaint is against (optional — may target a trip or booking instead). */
  @Column({ type: 'uuid', nullable: true, default: null })
  againstUserId: string | null;

  @ManyToOne(() => UserEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'againstUserId' })
  againstUser: UserEntity | null;

  @Column({ type: 'uuid', nullable: true, default: null })
  tripId: string | null;

  @ManyToOne(() => TripEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity | null;

  @Column({ type: 'uuid', nullable: true, default: null })
  bookingId: string | null;

  @ManyToOne(() => BookingEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'bookingId' })
  booking: BookingEntity | null;

  @Column({ type: 'varchar', length: 32 })
  category: ComplaintCategory;

  @Column({ type: 'text' })
  body: string;

  @Column({ type: 'varchar', length: 16, default: ComplaintStatus.OPEN })
  status: ComplaintStatus;

  @Column({ type: 'text', nullable: true, default: null })
  adminNotes: string | null;

  @Column({ type: 'uuid', nullable: true, default: null })
  resolvedByAdminId: string | null;

  @Column({ type: 'timestamptz', nullable: true, default: null })
  resolvedAt: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt: Date;
}
