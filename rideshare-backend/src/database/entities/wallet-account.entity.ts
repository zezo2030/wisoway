import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';
import { WalletAccountType } from './shared.enums';
import { WalletTransactionEntity } from './wallet-transaction.entity';

@Entity({ name: 'wallet_accounts' })
@Unique('wallet_accounts_user_type_unique', [
  'userId',
  'accountType',
  'currency',
])
@Index('wallet_accounts_user_idx', ['userId'])
export class WalletAccountEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  @Column({ type: 'enum', enum: WalletAccountType })
  accountType: WalletAccountType;

  @Column({ type: 'varchar', length: 5, default: 'JOD' })
  currency: string;

  @Column({ type: 'numeric', precision: 14, scale: 2, default: '0' })
  balance: string;

  /**
   * Funds reserved by active wallet holds. Spendable funds are
   * `balance - reservedBalance`; `balance` itself only moves when a hold is
   * captured (012-passenger-presence-confirmation).
   */
  @Column({ type: 'numeric', precision: 14, scale: 2, default: '0' })
  reservedBalance: string;

  @Column({ type: 'boolean', default: true })
  isActive: boolean;

  @OneToMany(
    () => WalletTransactionEntity,
    (transaction) => transaction.account,
  )
  transactions: WalletTransactionEntity[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
