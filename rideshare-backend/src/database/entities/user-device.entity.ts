import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  JoinColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';

export enum UserDeviceStatus {
  ACTIVE = 'active',
  REVOKED = 'revoked',
}

export enum UserDevicePlatform {
  ANDROID = 'android',
  IOS = 'ios',
}

/**
 * Represents a physical device that has been bound to a user account after a
 * successful OTP verification.  The `fingerprintHash` is a SHA-256 hex digest
 * of `platform:deviceId:installSalt` and is the canonical identity key for a
 * device session.
 *
 * Phase 3 (008-platform-completion / US1 — auth hardening):
 *  - Created by DeviceFingerprintService inside verifyOtp (T026).
 *  - Read by AccountRiskService.checkMultiAccountThreshold (T027).
 *  - Revocable by the device owner (logout) and by admins (T034).
 */
@Entity({ name: 'user_devices' })
@Index('user_devices_user_idx', ['userId'])
@Index('user_devices_fingerprint_idx', ['fingerprintHash'])
@Index('user_devices_fingerprint_created_idx', ['fingerprintHash', 'createdAt'])
export class UserDeviceEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: UserEntity;

  /**
   * SHA-256( platform + ':' + deviceId + ':' + installSalt )
   * Stored as 64 hex characters.  Never stores raw device identifiers.
   */
  @Column({ type: 'char', length: 64 })
  fingerprintHash: string;

  @Column({ type: 'enum', enum: UserDevicePlatform })
  platform: UserDevicePlatform;

  /** Human-readable label set by the user (e.g. "My iPhone 14"). */
  @Column({ type: 'varchar', length: 120, nullable: true, default: null })
  label: string | null;

  /** Firebase Cloud Messaging token for push delivery to this device. */
  @Column({ type: 'text', nullable: true, default: null })
  fcmToken: string | null;

  @Column({
    type: 'enum',
    enum: UserDeviceStatus,
    default: UserDeviceStatus.ACTIVE,
  })
  status: UserDeviceStatus;

  /** Set when an admin revokes this device session. */
  @Column({ type: 'timestamptz', nullable: true, default: null })
  revokedAt: Date | null;

  /** Free-text note recorded by the admin who revoked (e.g. "fraud"). */
  @Column({ type: 'text', nullable: true, default: null })
  revokeReason: string | null;

  /** ISO-639-1 locale last reported by the device (e.g. "ar", "en"). */
  @Column({ type: 'varchar', length: 8, nullable: true, default: null })
  locale: string | null;

  /** Last time this device sent any authenticated request. */
  @Column({ type: 'timestamptz', nullable: true, default: null })
  lastSeenAt: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt: Date;
}
