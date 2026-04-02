import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { WalletAccountEntity } from './wallet-account.entity';
import {
  WalletEntryDirection,
  WalletTransactionStatus,
  WalletTransactionType,
} from './shared.enums';

@Entity({ name: 'wallet_transactions' })
@Index('wallet_tx_account_created_idx', ['accountId', 'createdAt'])
@Index('wallet_tx_reference_idx', ['referenceId'])
@Index('wallet_tx_idempotency_idx', ['idempotencyKey'], { unique: true })
export class WalletTransactionEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  accountId: string;

  @ManyToOne(() => WalletAccountEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'accountId' })
  account: WalletAccountEntity;

  @Column({ type: 'enum', enum: WalletTransactionType })
  type: WalletTransactionType;

  @Column({ type: 'enum', enum: WalletEntryDirection })
  direction: WalletEntryDirection;

  @Column({
    type: 'enum',
    enum: WalletTransactionStatus,
    default: WalletTransactionStatus.POSTED,
  })
  status: WalletTransactionStatus;

  @Column({ type: 'numeric', precision: 14, scale: 2 })
  amount: string;

  @Column({ type: 'varchar', length: 5, default: 'JOD' })
  currency: string;

  @Column({ type: 'varchar', nullable: true })
  referenceType: string | null;

  @Column({ type: 'varchar', nullable: true })
  referenceId: string | null;

  @Column({ type: 'varchar', nullable: true })
  idempotencyKey: string | null;

  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, unknown> | null;

  @CreateDateColumn()
  createdAt: Date;
}
