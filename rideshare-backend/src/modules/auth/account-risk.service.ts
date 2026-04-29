import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserEntity } from '../../database/entities/user.entity';
import {
  AccountFlagEntity,
  AccountFlagSeverity,
  AccountFlagDisposition,
} from '../../database/entities/account-flag.entity';
import { SecurityEventEntity } from '../../database/entities/security-event.entity';
import { DeviceFingerprintService } from './device-fingerprint.service';

/**
 * Runs automated account-risk heuristics after key auth events.
 *
 * Current heuristics
 * ──────────────────
 * 1. Multi-account-from-one-device (checkMultiAccountThreshold)
 *    Triggered inside verifyOtp (T026).  If ≥ MULTI_ACCOUNT_DEVICE_THRESHOLD
 *    distinct user IDs have registered the same fingerprintHash within the
 *    last 24 h, the newest account is marked `restricted=true` and an
 *    account_flags row of severity 'high' is created.
 *
 * Phase 3 / T027 (008-platform-completion, US1 — auth hardening).
 */
@Injectable()
export class AccountRiskService {
  /** Number of distinct accounts from one device within 24 h that triggers the flag. */
  private readonly multiAccountThreshold: number;

  constructor(
    private readonly configService: ConfigService,
    private readonly deviceFingerprintService: DeviceFingerprintService,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(AccountFlagEntity)
    private readonly flagRepo: Repository<AccountFlagEntity>,
    @InjectRepository(SecurityEventEntity)
    private readonly securityEventRepo: Repository<SecurityEventEntity>,
  ) {
    this.multiAccountThreshold = Number(
      this.configService.get<string>('MULTI_ACCOUNT_DEVICE_THRESHOLD') ?? '3',
    );
  }

  /**
   * Checks whether the device that just completed OTP verification has been
   * used by too many distinct accounts in the last 24 hours.
   *
   * When the threshold is breached:
   *  - `users.restricted` is set to `true` for the triggering user
   *  - An `account_flags` row (reason='multi_account_device', severity='high') is created
   *  - A `security_events` row (eventType='account_restricted_auto') is created
   *
   * No-op if `fingerprintHash` is null (device block not active for this request).
   */
  async checkMultiAccountThreshold(
    userId: string,
    fingerprintHash: string | null,
  ): Promise<void> {
    if (!fingerprintHash) return;

    const userIds =
      await this.deviceFingerprintService.countDistinctUsersForFingerprint(
        fingerprintHash,
        24,
      );

    if (userIds.length < this.multiAccountThreshold) return;

    // Restrict the triggering account
    await this.userRepo.update({ id: userId }, { restricted: true });

    // Raise an account flag
    const flag = this.flagRepo.create({
      userId,
      reason: 'multi_account_device',
      severity: AccountFlagSeverity.HIGH,
      disposition: AccountFlagDisposition.OPEN,
      notes: `Device fingerprint linked to ${userIds.length} accounts within 24 h (threshold: ${this.multiAccountThreshold}).`,
    });
    await this.flagRepo.save(flag);

    // Append a security event
    const event = this.securityEventRepo.create({
      userId,
      eventType: 'account_restricted_auto',
      metadata: {
        reason: 'multi_account_device',
        distinctAccountCount: userIds.length,
        fingerprintHash,
      },
    });
    await this.securityEventRepo.save(event);
  }
}
