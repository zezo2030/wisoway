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

/** What the passenger said about their own presence. */
export const PassengerDeclaredStatus = {
  IN_VEHICLE: 'in_vehicle',
  ON_MY_WAY: 'on_my_way',
  NOT_RIDING: 'not_riding',
} as const;
export type PassengerDeclaredStatus =
  (typeof PassengerDeclaredStatus)[keyof typeof PassengerDeclaredStatus];

/** Why the driver marked a seat absent. */
export const SeatAbsenceReason = {
  NO_SHOW: 'no_show',
  CANCELLED_ON_SITE: 'cancelled_on_site',
  WRONG_PICKUP: 'wrong_pickup',
  OTHER: 'other',
} as const;
export type SeatAbsenceReason =
  (typeof SeatAbsenceReason)[keyof typeof SeatAbsenceReason];

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

  // ── Presence confirmation (012-passenger-presence-confirmation) ───────────

  /** Passenger declared themselves in the vehicle (status = 'in_vehicle'). */
  @Column({ type: 'timestamptz', nullable: true })
  passengerSelfConfirmedAt: Date | null;

  /** Last declaration made by the passenger for this seat. */
  @Column({ type: 'varchar', length: 20, nullable: true })
  passengerDeclaredStatus: PassengerDeclaredStatus | null;

  /**
   * Written by NoShowDetectorProcessor when the passenger never declared
   * anything.  Display and analytics ONLY — this NEVER affects billing, because
   * an unopened app must not hand the driver a free trip.
   */
  @Column({ type: 'timestamptz', nullable: true })
  autoFlaggedAbsentAt: Date | null;

  /** Why the driver marked this seat absent. */
  @Column({ type: 'varchar', length: 30, nullable: true })
  absenceReason: SeatAbsenceReason | null;

  /**
   * Three-valued billing flag. Every accepted seat is billable BY DEFAULT:
   *
   *   null  → default — billable
   *   false → driver explicitly marked absent, passenger did not contradict
   *   true  → forced billable (driver/passenger conflict, or admin resolution)
   */
  @Column({ type: 'boolean', nullable: true })
  billableOverride: boolean | null;

  /** Driver said absent but the passenger had self-confirmed — needs review. */
  @Column({ type: 'timestamptz', nullable: true })
  presenceDisputedAt: Date | null;

  @Column({ type: 'uuid', nullable: true })
  presenceResolvedBy: string | null;

  @Column({ type: 'text', nullable: true })
  presenceResolutionNote: string | null;

  /** Last presence write by anyone (driver, passenger, admin). */
  @Column({ type: 'timestamptz', nullable: true })
  presenceUpdatedAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  /** Passenger confirmation is required; an admin override may still exempt it. */
  get isBillable(): boolean {
    return (
      this.passengerSelfConfirmedAt != null && this.billableOverride !== false
    );
  }
}
