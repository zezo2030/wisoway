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

export enum AccountFlagSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

export enum AccountFlagDisposition {
  OPEN = 'open',
  RESOLVED = 'resolved',
  DISMISSED = 'dismissed',
}

/**
 * A risk/safety flag raised against a user account, either automatically by
 * platform heuristics (e.g. multi-account-from-one-device) or manually by an
 * admin reviewer.
 *
 * Phase 3 (008-platform-completion / US1 — auth hardening):
 *  - Written by AccountRiskService (T027) when thresholds are breached.
 *  - Read + managed by admin API (T034–T037).
 *  - Displayed on the Dashboard AccountFlagsPage (T043).
 */
@Entity({ name: 'account_flags' })
@Index('account_flags_user_idx', ['userId'])
@Index('account_flags_disposition_idx', ['disposition'])
@Index('account_flags_created_idx', ['createdAt'])
export class AccountFlagEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  /**
   * Machine-readable reason code.  Examples:
   *  - 'multi_account_device'  — ≥3 accounts linked to the same device fingerprint
   *  - 'mock_location_repeated' — 3rd+ mocked-location event within 30 days
   *  - 'manual_review'          — admin-initiated flag
   */
  @Column({ type: 'varchar', length: 64 })
  reason: string;

  @Column({
    type: 'enum',
    enum: AccountFlagSeverity,
    default: AccountFlagSeverity.MEDIUM,
  })
  severity: AccountFlagSeverity;

  @Column({
    type: 'enum',
    enum: AccountFlagDisposition,
    default: AccountFlagDisposition.OPEN,
  })
  disposition: AccountFlagDisposition;

  /** Free-text context written by the system or the admin. */
  @Column({ type: 'text', nullable: true, default: null })
  notes: string | null;

  /** UUID of the admin user who last changed the disposition (null if system-created). */
  @Column({ type: 'uuid', nullable: true, default: null })
  resolvedByAdminId: string | null;

  @Column({ type: 'timestamptz', nullable: true, default: null })
  resolvedAt: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt: Date;
}
