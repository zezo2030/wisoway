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
import { WalletAccountEntity } from './wallet-account.entity';

/**
 * Lifecycle of a hold: active → captured | released.
 * Only one `active` hold may exist per (referenceType, referenceId) — enforced
 * by a partial unique index in migration 1746600000000.
 */
export const WalletHoldStatus = {
  ACTIVE: 'active',
  CAPTURED: 'captured',
  RELEASED: 'released',
} as const;
export type WalletHoldStatus =
  (typeof WalletHoldStatus)[keyof typeof WalletHoldStatus];

@Entity({ name: 'wallet_holds' })
@Index('wallet_holds_account_idx', ['accountId'])
@Index('wallet_holds_status_idx', ['status'])
export class WalletHoldEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  accountId: string;

  @ManyToOne(() => WalletAccountEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'accountId' })
  account: WalletAccountEntity;

  @Column({ type: 'numeric', precision: 14, scale: 2 })
  amount: string;

  @Column({ type: 'varchar', length: 5, default: 'JOD' })
  currency: string;

  @Column({ type: 'varchar', default: 'pending' })
  status: string;

  @Column({ type: 'varchar', nullable: true })
  referenceType: string | null;

  @Column({ type: 'varchar', nullable: true })
  referenceId: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  expiresAt: Date | null;

  // ── Capture / release bookkeeping (012-passenger-presence-confirmation) ───

  /** Portion of `amount` actually taken from the balance at settlement. */
  @Column({ type: 'numeric', precision: 14, scale: 2, nullable: true })
  capturedAmount: string | null;

  /** Portion of `amount` returned to spendable balance at settlement. */
  @Column({ type: 'numeric', precision: 14, scale: 2, nullable: true })
  releasedAmount: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  settledAt: Date | null;

  /** Snapshot of the pricing inputs so a mid-trip percent change cannot alter capture. */
  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, unknown> | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
