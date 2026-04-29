import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';
import {
  UserDeviceEntity,
  UserDeviceStatus,
} from '../../database/entities/user-device.entity';
import { UserDevicePlatform } from '../../database/entities/user-device.entity';

export interface RegisterDeviceParams {
  userId: string;
  platform: UserDevicePlatform;
  deviceId: string;
  installSalt: string;
  fcmToken?: string;
  label?: string;
  locale?: string;
}

/**
 * Manages device fingerprinting and device-session lifecycle.
 *
 * The fingerprint is a SHA-256 hex digest of `platform:deviceId:installSalt`.
 * No raw device identifiers are ever stored.
 *
 * Phase 3 / T025 (008-platform-completion, US1 — auth hardening).
 */
@Injectable()
export class DeviceFingerprintService {
  constructor(
    @InjectRepository(UserDeviceEntity)
    private readonly deviceRepo: Repository<UserDeviceEntity>,
  ) {}

  // ---------------------------------------------------------------------------
  // Hashing helpers
  // ---------------------------------------------------------------------------

  /**
   * Deterministically hashes a device's identity triple into a 64-char hex
   * SHA-256 digest that can be stored in `user_devices.fingerprintHash`.
   */
  hash(platform: string, deviceId: string, installSalt: string): string {
    return crypto
      .createHash('sha256')
      .update(`${platform}:${deviceId}:${installSalt}`)
      .digest('hex');
  }

  /**
   * Generates a cryptographically random install-salt (32 bytes → 64 hex chars).
   * The mobile client stores this persistently so the same device always
   * produces the same hash even across app reinstalls that reset `deviceId`.
   */
  issueInstallSalt(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  // ---------------------------------------------------------------------------
  // Device session management
  // ---------------------------------------------------------------------------

  /**
   * Upserts a device record for the given user.  If a device with the same
   * `fingerprintHash` already exists for this user it is reactivated and its
   * `lastSeenAt` / `fcmToken` / `locale` are refreshed.  Otherwise a new row
   * is inserted.
   *
   * Returns the saved entity.
   */
  async registerDevice(
    params: RegisterDeviceParams,
  ): Promise<UserDeviceEntity> {
    const fingerprintHash = this.hash(
      params.platform,
      params.deviceId,
      params.installSalt,
    );

    const existing = await this.deviceRepo.findOne({
      where: { userId: params.userId, fingerprintHash },
    });

    if (existing) {
      existing.status = UserDeviceStatus.ACTIVE;
      existing.revokedAt = null;
      existing.revokeReason = null;
      existing.lastSeenAt = new Date();
      if (params.fcmToken !== undefined)
        existing.fcmToken = params.fcmToken ?? null;
      if (params.locale !== undefined) existing.locale = params.locale ?? null;
      return this.deviceRepo.save(existing);
    }

    const device = this.deviceRepo.create({
      userId: params.userId,
      fingerprintHash,
      platform: params.platform,
      fcmToken: params.fcmToken ?? null,
      label: params.label ?? null,
      locale: params.locale ?? null,
      status: UserDeviceStatus.ACTIVE,
      lastSeenAt: new Date(),
    });

    return this.deviceRepo.save(device);
  }

  /**
   * Looks up an active device by fingerprint hash for a given user.
   * Returns null if not found or revoked.
   */
  async findActiveDevice(
    userId: string,
    fingerprintHash: string,
  ): Promise<UserDeviceEntity | null> {
    return this.deviceRepo.findOne({
      where: { userId, fingerprintHash, status: UserDeviceStatus.ACTIVE },
    });
  }

  async findActiveDeviceById(
    userId: string,
    deviceId: string,
  ): Promise<UserDeviceEntity | null> {
    return this.deviceRepo.findOne({
      where: { id: deviceId, userId, status: UserDeviceStatus.ACTIVE },
    });
  }

  /**
   * Returns all active device sessions for a user (for the /auth/devices list).
   */
  async listActiveDevices(userId: string): Promise<UserDeviceEntity[]> {
    return this.deviceRepo.find({
      where: { userId, status: UserDeviceStatus.ACTIVE },
      order: { lastSeenAt: 'DESC' },
    });
  }

  /**
   * Admin-initiated revoke: marks a device as REVOKED and records reason + time.
   */
  async revokeDevice(
    deviceId: string,
    revokeReason?: string,
  ): Promise<UserDeviceEntity> {
    const device = await this.deviceRepo.findOneOrFail({
      where: { id: deviceId },
    });
    device.status = UserDeviceStatus.REVOKED;
    device.revokedAt = new Date();
    device.revokeReason = revokeReason ?? null;
    return this.deviceRepo.save(device);
  }

  /**
   * Returns the distinct user IDs that have registered the given
   * `fingerprintHash` within the last `withinHours` hours.
   * Used by AccountRiskService to detect multi-account-from-one-device.
   */
  async countDistinctUsersForFingerprint(
    fingerprintHash: string,
    withinHours: number,
  ): Promise<string[]> {
    const since = new Date(Date.now() - withinHours * 60 * 60 * 1000);
    const rows = await this.deviceRepo
      .createQueryBuilder('d')
      .select('DISTINCT d."userId"', 'userId')
      .where('d."fingerprintHash" = :fp', { fp: fingerprintHash })
      .andWhere('d."createdAt" >= :since', { since })
      .getRawMany<{ userId: string }>();
    return rows.map((r) => r.userId);
  }
}
