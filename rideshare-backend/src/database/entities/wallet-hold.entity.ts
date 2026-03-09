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

  @Column({ type: 'varchar', length: 5, default: 'EGP' })
  currency: string;

  @Column({ type: 'varchar', default: 'pending' })
  status: string;

  @Column({ type: 'varchar', nullable: true })
  referenceType: string | null;

  @Column({ type: 'varchar', nullable: true })
  referenceId: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  expiresAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
