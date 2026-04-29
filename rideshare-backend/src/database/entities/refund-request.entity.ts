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

export const RefundRequestStatus = {
  OPEN: 'open',
  CONTACTED: 'contacted',
  RESOLVED: 'resolved',
  REJECTED: 'rejected',
} as const;
export type RefundRequestStatus =
  (typeof RefundRequestStatus)[keyof typeof RefundRequestStatus];

/**
 * A refund request filed by a passenger.  The system records the request and
 * generates a WhatsApp deep-link for the user to contact support directly.
 * The actual refund is handled off-platform via WhatsApp; the record here is
 * for admin tracking only.
 *
 * Phase 8 (008-platform-completion / US6 — admin-and-support):
 *  - Created via POST /refund-requests (T169).
 *  - Managed by admin via PATCH /admin/refund-requests/:id (T170).
 */
@Entity({ name: 'refund_requests' })
@Index('idx_refund_requests_status_created', ['status', 'createdAt'])
export class RefundRequestEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column({ type: 'uuid', nullable: true, default: null })
  bookingId: string | null;

  @ManyToOne(() => BookingEntity, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'bookingId' })
  booking: BookingEntity | null;

  /** Amount the user claims should be refunded (null when only requesting advice). */
  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  amount: string | null;

  @Column({ type: 'varchar', length: 5, default: 'JOD' })
  currency: string;

  @Column({ type: 'text' })
  reason: string;

  @Column({ type: 'varchar', length: 16, default: RefundRequestStatus.OPEN })
  status: RefundRequestStatus;

  /** Timestamp when the deep-link was generated (proxy for "user was sent to WhatsApp"). */
  @Column({ type: 'timestamptz', nullable: true, default: null })
  whatsappContactedAt: Date | null;

  @Column({ type: 'uuid', nullable: true, default: null })
  resolvedByAdminId: string | null;

  @Column({ type: 'timestamptz', nullable: true, default: null })
  resolvedAt: Date | null;

  @Column({ type: 'text', nullable: true, default: null })
  adminNotes: string | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt: Date;
}
