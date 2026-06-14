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
import { TripEntity } from './trip.entity';
import { BookingSeatEntity } from './booking-seat.entity';

/**
 * Booking status enum values (mirrors booking_status_enum in PostgreSQL).
 *
 * Note: The column keeps type 'varchar' in the entity because the migration
 * (008.04) converts it to a PG enum.  TypeORM will use the string values at
 * runtime; the DB constraint enforces the enum membership.
 */
export const BookingStatus = {
  PENDING: 'pending',
  CONFIRMED: 'confirmed',
  CANCELLED: 'cancelled',
  REJECTED: 'rejected',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  NO_SHOW: 'no_show',
} as const;
export type BookingStatus = (typeof BookingStatus)[keyof typeof BookingStatus];

@Entity({ name: 'bookings' })
// idx_bookings_user_trip dropped by migration 008.02 (seat-level uniqueness)
@Index('idx_bookings_trip', ['tripId'])
@Index('idx_bookings_user', ['userId'])
export class BookingEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'tripId', type: 'uuid' })
  tripId: string;

  @ManyToOne(() => TripEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tripId' })
  trip: TripEntity;

  @Column({ name: 'userId', type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column({ type: 'varchar', default: BookingStatus.PENDING })
  @Index('idx_bookings_status')
  status: BookingStatus;

  // ── Multi-seat fields (Phase 4) ───────────────────────────────────────────

  /** Total number of seats in this booking (1 for legacy v1 bookings). */
  @Column({ type: 'int', default: 1 })
  seatCount: number;

  /**
   * Total charge to the passenger = seatCount × seatPriceAtBooking.
   * NOT NULL after backfill migration 008.12 / Phase 9 (T182).
   */
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  totalAmount: string;

  /** Populated by the booking-timeout BullMQ job delay; useful for display. */
  @Column({ type: 'timestamp', nullable: true })
  expiresAt: Date | null;

  // ── Settlement fields (Phase 7 — reserved here for migration ordering) ────

  @Column({ type: 'timestamp', nullable: true })
  settledAt: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  settlementGraceUntil: Date | null;

  // ── Trip-time confirmation fields (Phase 5) ───────────────────────────────

  @Column({ type: 'timestamp', nullable: true })
  passengerPresenceConfirmedAt: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  driverConfirmedPassengerAt: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  driverMarkedAbsentAt: Date | null;

  /** Set when the passenger reports the driver is absent (via passenger-confirm). */
  @Column({ type: 'timestamp', nullable: true })
  passengerReportedDriverAbsentAt: Date | null;

  // ── Existing fields ────────────────────────────────────────────────────────

  @Column({ type: 'boolean', default: false })
  hasDriverPaidToContact: boolean;

  @Column({ type: 'boolean', default: false })
  sharePhoneWithDriver: boolean;

  @Column({ type: 'text', nullable: true })
  cancellationReason: string | null;

  @Column({ type: 'timestamp', nullable: true })
  cancelledAt: Date | null;

  @Column({ type: 'varchar', nullable: true })
  cancelledBy: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  seatPriceAtBooking: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  platformAmount: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  driverAmount: string | null;

  @Column({ type: 'uuid', nullable: true })
  passengerPaymentId: string | null;

  // ── Relations ──────────────────────────────────────────────────────────────

  @OneToMany(() => BookingSeatEntity, (seat) => seat.booking, { eager: false })
  seats: BookingSeatEntity[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
