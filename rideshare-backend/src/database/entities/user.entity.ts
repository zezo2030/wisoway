import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { DeviceTokenEntity } from './device-token.entity';
import { PgUserRole } from './shared.enums';
import { WalletAccountEntity } from './wallet-account.entity';

@Entity({ name: 'users' })
@Index('users_email_idx', ['email'])
@Index('users_phone_idx', ['phoneNumber'])
@Index('users_role_idx', ['role'])
export class UserEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', nullable: true, unique: true })
  email: string | null;

  @Column({ type: 'varchar', nullable: true, unique: true })
  phoneNumber: string | null;

  @Column({ type: 'varchar', length: 120 })
  name: string;

  @Column({ type: 'varchar', nullable: true })
  passwordHash: string | null;

  @Column({ type: 'enum', enum: PgUserRole, default: PgUserRole.PASSENGER })
  role: PgUserRole;

  @Column({ type: 'boolean', default: true })
  isActive: boolean;

  @Column({ type: 'varchar', nullable: true })
  fcmToken: string | null;

  @OneToMany(() => DeviceTokenEntity, (token) => token.user)
  deviceTokens: DeviceTokenEntity[];

  @OneToMany(() => WalletAccountEntity, (wallet) => wallet.user)
  walletAccounts: WalletAccountEntity[];

  @Column({ type: 'varchar', nullable: true })
  gender: string | null;

  @Column({ type: 'text', nullable: true })
  photoUrl: string | null;

  @Column({ type: 'varchar', default: 'email' })
  provider: string;

  @Column({ type: 'varchar', nullable: true })
  providerId: string | null;

  @Column({ type: 'decimal', precision: 3, scale: 2, default: 0 })
  rating: number;

  @Column({ type: 'int', default: 0 })
  totalRatings: number;

  @Column({ type: 'boolean', default: false })
  isPhoneVerified: boolean;

  @Column({ type: 'boolean', default: false })
  isEmailVerified: boolean;

  @Column({ type: 'boolean', default: false })
  isDriverApproved: boolean;

  @Column({ type: 'varchar', nullable: true, select: false })
  refreshToken: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 })
  walletBalance: number;

  @Column({ type: 'varchar', length: 5, default: 'JOD' })
  walletCurrency: string;

  @Column({ type: 'boolean', default: false })
  hasUsedLifetimeFreeTrip: boolean;

  @Column({ type: 'timestamp', nullable: true, default: null })
  passwordChangedAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
