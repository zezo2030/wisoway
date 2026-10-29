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

  @Column({ type: 'varchar', nullable: true, select: false })
  passwordHash: string | null;

  @Column({ type: 'enum', enum: PgUserRole, default: PgUserRole.PASSENGER })
  role: PgUserRole;

  @Column({ type: 'boolean', default: true })
  isActive: boolean;

  @Column({ type: 'varchar', length: 64, nullable: true })
  city: string | null;

  @Column({ type: 'varchar', nullable: true, select: false })
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

  /**
   * The rating passengers gave this user as a driver — what passengers see
   * when booking or ordering. `rating` above mixes every rating received
   * (as driver and as passenger); this one counts only ratedRole = driver.
   */
  @Column({ type: 'decimal', precision: 3, scale: 2, default: 0 })
  driverRating: number;

  @Column({ type: 'int', default: 0 })
  driverTotalRatings: number;

  /**
   * The rating drivers gave this user as a passenger (ratedRole = passenger),
   * scaled by [passengerRatingPenaltyFactor] — what a driver sees on a ride
   * request or a booking.
   */
  @Column({ type: 'decimal', precision: 3, scale: 2, default: 0 })
  passengerRating: number;

  @Column({ type: 'int', default: 0 })
  passengerTotalRatings: number;

  /** Like [ratingPenaltyFactor], for the passenger side (late cancels). */
  @Column({ type: 'decimal', precision: 6, scale: 4, default: 1 })
  passengerRatingPenaltyFactor: number;

  /**
   * Multiplies the average of driver ratings into `driverRating`. Starts at 1;
   * each late instant pickup lowers it by the admin-set percentage
   * (RatingsService.applyRatingPenalty).
   */
  @Column({ type: 'decimal', precision: 6, scale: 4, default: 1 })
  ratingPenaltyFactor: number;

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

  // ── Foundation extensions (008-platform-completion / Phase 2) ─────────────

  /** Set by an admin ban action; non-null means the account is banned. */
  @Column({ type: 'timestamptz', nullable: true, default: null })
  bannedAt: Date | null;

  /** Human-readable reason surfaced to the banned user on app open. */
  @Column({ type: 'text', nullable: true, default: null })
  banReason: string | null;

  /**
   * Set by automated risk heuristics (e.g. multi-account-from-one-device).
   * Write operations are blocked; admin clears via dashboard.
   */
  @Column({ type: 'boolean', default: false })
  restricted: boolean;

  /**
   * User preference: route in-app calls through a Twilio proxy DID so the
   * other party never sees the real phone number.
   */
  @Column({ type: 'boolean', default: false })
  hidePhoneNumber: boolean;

  /**
   * Passengers: their own CliQ alias or mobile (00962…), remembered from the
   * last CliQ-paid ride so the next one is pre-filled.
   */
  @Column({ type: 'varchar', length: 100, nullable: true })
  cliqAlias: string | null;

  /**
   * True for legacy social-login accounts that have not yet linked a phone
   * number.  Cleared once the user completes the phone-link migration flow.
   */
  @Column({ type: 'boolean', default: false })
  pendingPhoneLink: boolean;

  /**
   * Recorded on every legacy social sign-in during the migration window only.
   * Null once the account has completed phone-link migration.
   */
  @Column({ type: 'timestamptz', nullable: true, default: null })
  lastSocialLoginAt: Date | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
