/**
 * PendingCharge entity
 *
 * Records a monetary penalty that has either been deducted from the user's
 * wallet immediately (status='applied') or is being carried forward to the
 * next booking confirmation (status='pending').
 *
 * Three kinds:
 *  - passenger_cancellation  5% of booking totalAmount (FR-015 / FR-025)
 *  - driver_no_show         10% of sum(confirmed bookings totalAmount) (FR-027)
 *  - passenger_no_show       5% of booking totalAmount (FR-028)
 *
 * Phase 4 / T059 — 008-platform-completion, US2 / 010-booking-lifecycle.
 */
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
import { BookingEntity } from './booking.entity';
import { TripEntity } from './trip.entity';

export enum PendingChargeKind {
  PASSENGER_CANCELLATION = 'passenger_cancellation',
  DRIVER_NO_SHOW = 'driver_no_show',
  PASSENGER_NO_SHOW = 'passenger_no_show',
}

export enum PendingChargeStatus {
  PENDING = 'pending',
  APPLIED = 'applied',
  WAIVED = 'waived',
}

@Entity({ name: 'pending_charges' })
@Index('idx_pending_charges_user_status', ['userId', 'status'])
@Index('idx_pending_charges_booking', ['bookingId'])
export class PendingChargeEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** The user who owes the charge (passenger or driver). */
  @Column({ name: 'userId', type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column({
    type: 'enum',
    enum: PendingChargeKind,
  })
  kind: PendingChargeKind;

  /** Charge amount in the trip's currency. */
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount: string;

  @Column({
    type: 'enum',
    enum: PendingChargeStatus,
    default: PendingChargeStatus.PENDING,
  })
  status: PendingChargeStatus;

  /** The booking that triggered this charge (nullable for driver no-show). */
  @Column({ name: 'bookingId', type: 'uuid', nullable: true })
  bookingId: string | null;

  @ManyToOne(() => BookingEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'bookingId' })
  booking: BookingEntity | null;

  /** The trip context (always set). */
  @Column({ name: 'tripId', type: 'uuid', nullable: true })
  tripId: string | null;

  @ManyToOne(() => TripEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity | null;

  /**
   * Set when the charge is successfully deducted from the wallet immediately.
   * References the WalletTransaction that debited the amount.
   */
  @Column({ name: 'walletTransactionId', type: 'uuid', nullable: true })
  walletTransactionId: string | null;

  /**
   * Set when a pending charge is collected at a later booking confirmation.
   * References the booking whose confirmation triggered the collection sweep.
   */
  @Column({ name: 'appliedToBookingId', type: 'uuid', nullable: true })
  appliedToBookingId: string | null;

  /** Set by admin POST /admin/pending-charges/:id/waive */
  @Column({ name: 'waivedByAdminId', type: 'uuid', nullable: true })
  waivedByAdminId: string | null;

  @Column({ type: 'timestamp', nullable: true })
  waivedAt: Date | null;

  /**
   * Optional HTTP request / trace correlation ID (Phase 9 / T187).
   * Set from the `X-Request-ID` header (or gateway-assigned trace ID) so a
   * single inbound request can be traced across logs, audit rows, and queues.
   * Nullable: background jobs (no-show detection, cancellation processor) that
   * create pending charges do not always have an originating HTTP request ID.
   */
  @Column({ type: 'varchar', nullable: true, default: null })
  correlationId: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
