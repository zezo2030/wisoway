/**
 * BookingSeat entity
 *
 * Represents a single seat within a multi-seat booking.  One booking can
 * have 1–N BookingSeat rows.  Exactly one row per booking must have
 * isMainBooker=true (enforced by a partial unique index).
 *
 * Phase 4 / T058 — 008-platform-completion, US2 / 010-booking-lifecycle.
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
import { BookingEntity } from './booking.entity';

@Entity({ name: 'booking_seats' })
@Index('idx_booking_seats_booking', ['bookingId'])
@Index('idx_booking_seats_seat_number', ['bookingId', 'seatNumber'], {
  unique: true,
})
export class BookingSeatEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'bookingId', type: 'uuid' })
  bookingId: string;

  @ManyToOne(() => BookingEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'bookingId' })
  booking: BookingEntity;

  /** Seat identifier in the trip's seat layout (e.g. "0-0" or "1A"). */
  @Column({ type: 'varchar', length: 10 })
  seatNumber: string;

  /**
   * True for the passenger who made the booking (the account holder).
   * A partial unique index in the migration enforces one true per booking.
   */
  @Column({ type: 'boolean', default: false })
  isMainBooker: boolean;

  /**
   * Display name shown to the driver for this seat.
   * For the main booker this is their account name; for companions it is
   * whatever the passenger entered in the companion-picker screen.
   */
  @Column({ type: 'varchar', length: 100 })
  displayName: string;

  /** Gender of the occupant — used for adjacency-rule enforcement. */
  @Column({ type: 'varchar', length: 10 })
  gender: string;

  /**
   * Set by the driver on POST /bookings/:id/driver-confirm when the driver
   * confirms this seat's occupant is present.
   */
  @Column({ type: 'timestamp', nullable: true })
  presenceConfirmedAt: Date | null;

  /**
   * Set by the driver on POST /trips/:id/complete when the driver declares
   * this seat's occupant did not show up (FR-028).
   */
  @Column({ type: 'timestamp', nullable: true })
  markedAbsentAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;
}
