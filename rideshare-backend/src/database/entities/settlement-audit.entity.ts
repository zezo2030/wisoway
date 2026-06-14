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
import { UserEntity } from './user.entity';

export const SettlementAuditAction = {
  MARK_PAID: 'mark_paid',
  UNMARK_PAID: 'unmark_paid',
  ADMIN_REVERT: 'admin_revert',
} as const;
export type SettlementAuditAction =
  (typeof SettlementAuditAction)[keyof typeof SettlementAuditAction];

@Entity({ name: 'settlement_audits' })
@Index('idx_settlement_audits_booking', ['bookingId'])
@Index('idx_settlement_audits_actor', ['actorId'])
export class SettlementAuditEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  bookingId: string;

  @ManyToOne(() => BookingEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'bookingId' })
  booking: BookingEntity;

  @Column({ type: 'varchar' })
  action: SettlementAuditAction;

  @Column({ type: 'uuid' })
  actorId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'actorId' })
  actor: UserEntity;

  /** Human-readable reason — required for admin_revert, null otherwise. */
  @Column({ type: 'text', nullable: true })
  reason: string | null;

  /**
   * Optional HTTP request / trace correlation ID (Phase 9 / T187).
   * Set from the `X-Request-ID` header (or gateway-assigned trace ID) so a
   * single inbound request can be traced across logs, audit rows, and queues.
   * Nullable: background jobs that create settlement audit rows have no request ID.
   */
  @Column({ type: 'varchar', nullable: true, default: null })
  correlationId: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
