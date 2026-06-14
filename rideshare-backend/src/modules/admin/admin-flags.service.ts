import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  AccountFlagEntity,
  AccountFlagDisposition,
} from '../../database/entities/account-flag.entity';
import { UserDeviceEntity } from '../../database/entities/user-device.entity';
import { SecurityEventEntity } from '../../database/entities/security-event.entity';
import { DeviceFingerprintService } from '../auth/device-fingerprint.service';

export interface ListFlagsQuery {
  userId?: string;
  disposition?: AccountFlagDisposition;
  limit?: number;
  offset?: number;
}

/**
 * Service backing the admin account-flags and device-revoke endpoints
 * (T034–T037 of 008-platform-completion Phase 3).
 */
@Injectable()
export class AdminFlagsService {
  constructor(
    @InjectRepository(AccountFlagEntity)
    private readonly flagRepo: Repository<AccountFlagEntity>,
    @InjectRepository(UserDeviceEntity)
    private readonly deviceRepo: Repository<UserDeviceEntity>,
    @InjectRepository(SecurityEventEntity)
    private readonly securityEventRepo: Repository<SecurityEventEntity>,
    private readonly deviceFingerprintService: DeviceFingerprintService,
  ) {}

  /** T034 — List account flags (optionally filtered by userId and/or disposition). */
  async listFlags(query: ListFlagsQuery) {
    const qb = this.flagRepo
      .createQueryBuilder('f')
      .orderBy('f.createdAt', 'DESC')
      .take(query.limit ?? 50)
      .skip(query.offset ?? 0);

    if (query.userId) {
      qb.andWhere('f."userId" = :userId', { userId: query.userId });
    }
    if (query.disposition) {
      qb.andWhere('f."disposition" = :disposition', {
        disposition: query.disposition,
      });
    }

    const [flags, total] = await qb.getManyAndCount();
    return { flags, total };
  }

  /** T035 — Resolve an account flag (admin decides the account is safe). */
  async resolveFlag(
    flagId: string,
    adminId: string,
    notes?: string,
  ): Promise<AccountFlagEntity> {
    const flag = await this.flagRepo.findOne({ where: { id: flagId } });
    if (!flag) throw new NotFoundException('Account flag not found');

    flag.disposition = AccountFlagDisposition.RESOLVED;
    flag.resolvedByAdminId = adminId;
    flag.resolvedAt = new Date();
    if (notes) flag.notes = notes;

    const saved = await this.flagRepo.save(flag);

    await this.securityEventRepo.save(
      this.securityEventRepo.create({
        userId: flag.userId,
        eventType: 'account_flag_resolved',
        adminActorId: adminId,
        metadata: { flagId, reason: flag.reason },
      }),
    );

    return saved;
  }

  /** T036 — Dismiss an account flag (false positive or already actioned). */
  async dismissFlag(
    flagId: string,
    adminId: string,
    notes?: string,
  ): Promise<AccountFlagEntity> {
    const flag = await this.flagRepo.findOne({ where: { id: flagId } });
    if (!flag) throw new NotFoundException('Account flag not found');

    flag.disposition = AccountFlagDisposition.DISMISSED;
    flag.resolvedByAdminId = adminId;
    flag.resolvedAt = new Date();
    if (notes) flag.notes = notes;

    const saved = await this.flagRepo.save(flag);

    await this.securityEventRepo.save(
      this.securityEventRepo.create({
        userId: flag.userId,
        eventType: 'account_flag_dismissed',
        adminActorId: adminId,
        metadata: { flagId, reason: flag.reason },
      }),
    );

    return saved;
  }

  /** T037 — Admin-revoke a device session and log the action. */
  async revokeDevice(
    deviceId: string,
    adminId: string,
    reason?: string,
  ): Promise<UserDeviceEntity> {
    const device = await this.deviceRepo.findOne({ where: { id: deviceId } });
    if (!device) throw new NotFoundException('Device not found');

    const revoked = await this.deviceFingerprintService.revokeDevice(
      deviceId,
      reason ?? 'admin_revoke',
    );

    await this.securityEventRepo.save(
      this.securityEventRepo.create({
        userId: device.userId,
        eventType: 'device_revoked_by_admin',
        deviceId,
        adminActorId: adminId,
        metadata: { reason: reason ?? null },
      }),
    );

    return revoked;
  }
}
