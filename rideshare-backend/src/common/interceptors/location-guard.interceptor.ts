import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Observable } from 'rxjs';
import { WsException } from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { SecurityEventEntity } from '../../database/entities/security-event.entity';
import {
  AccountFlagEntity,
  AccountFlagSeverity,
  AccountFlagDisposition,
} from '../../database/entities/account-flag.entity';
import { ErrorCodes } from '../errors/error-codes';

/**
 * LocationGuardInterceptor
 *
 * Applied to the `driver:location:update` WebSocket message handler (T032).
 *
 * Responsibilities:
 *  1. If the incoming payload contains `isMockLocation: true`, reject the
 *     message with a WsException carrying code LOCATION_INTEGRITY_VIOLATION.
 *  2. Write a `security_events` row for every mock-location rejection.
 *  3. On the 3rd+ mock event within 30 days for the same user, create an
 *     `account_flags` row of severity 'high', reason 'mock_location_repeated'.
 *
 * Phase 3 / T031 (008-platform-completion, US1 — auth hardening).
 */
@Injectable()
export class LocationGuardInterceptor implements NestInterceptor {
  /** Number of mock events within 30 days before escalating to a flag. */
  private static readonly MOCK_FLAG_THRESHOLD = 3;
  private static readonly MOCK_WINDOW_DAYS = 30;

  constructor(
    @InjectRepository(SecurityEventEntity)
    private readonly securityEventRepo: Repository<SecurityEventEntity>,
    @InjectRepository(AccountFlagEntity)
    private readonly flagRepo: Repository<AccountFlagEntity>,
  ) {}

  async intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    // Only applies to WebSocket contexts
    if (context.getType() !== 'ws') {
      return next.handle();
    }

    const client: Socket = context.switchToWs().getClient<Socket>();
    const data = context.switchToWs().getData<Record<string, unknown>>();
    const userId: string | undefined = client.data?.userId;

    if (!data?.isMockLocation || !userId) {
      return next.handle();
    }

    // ── Record the rejection event ─────────────────────────────────────────
    const event = this.securityEventRepo.create({
      userId,
      eventType: 'mock_location_rejected',
      metadata: {
        tripId: data['tripId'] ?? null,
        latitude: data['latitude'] ?? null,
        longitude: data['longitude'] ?? null,
      },
    });
    await this.securityEventRepo.save(event);

    // ── Count mock events in the past 30 days ──────────────────────────────
    const windowStart = new Date(
      Date.now() -
        LocationGuardInterceptor.MOCK_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );

    const mockCount = await this.securityEventRepo
      .createQueryBuilder('e')
      .where('e."userId" = :userId', { userId })
      .andWhere('e."eventType" = :type', { type: 'mock_location_rejected' })
      .andWhere('e."createdAt" >= :since', { since: windowStart })
      .getCount();

    // ── Escalate on threshold breach ───────────────────────────────────────
    if (mockCount >= LocationGuardInterceptor.MOCK_FLAG_THRESHOLD) {
      const existingFlag = await this.flagRepo.findOne({
        where: {
          userId,
          reason: 'mock_location_repeated',
          disposition: AccountFlagDisposition.OPEN,
        },
      });

      if (!existingFlag) {
        const flag = this.flagRepo.create({
          userId,
          reason: 'mock_location_repeated',
          severity: AccountFlagSeverity.HIGH,
          disposition: AccountFlagDisposition.OPEN,
          notes: `${mockCount} mock-location events detected within ${LocationGuardInterceptor.MOCK_WINDOW_DAYS} days.`,
        });
        await this.flagRepo.save(flag);
      }
    }

    // ── Reject the message ─────────────────────────────────────────────────
    throw new WsException({
      code: ErrorCodes.LOCATION_INTEGRITY_VIOLATION,
      message: 'Mock location detected. Location update rejected.',
    });
  }
}
