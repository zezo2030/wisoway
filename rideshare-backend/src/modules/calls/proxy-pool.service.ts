import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Not, Repository } from 'typeorm';
import {
  CallSessionEntity,
  CallSessionStatus,
} from '../../database/entities/call-session.entity';
import { ErrorCodes } from '../../common/errors/error-codes';

/**
 * ProxyPoolService — manages the pool of Twilio proxy DIDs.
 *
 * Pool is loaded from `TWILIO_PROXY_NUMBERS` environment variable
 * (comma-separated list of E.164 numbers, e.g. "+962790000001,+962790000002").
 *
 * Allocation strategy:
 *  1. If the booking already has a proxy number (from a prior session) → reuse it.
 *  2. Otherwise pick the first number that has no currently active session
 *     for a *different* booking.
 *  3. If every number in the pool is locked by another active booking → 503.
 */
@Injectable()
export class ProxyPoolService {
  private readonly logger = new Logger(ProxyPoolService.name);
  private readonly pool: string[];

  constructor(
    @InjectRepository(CallSessionEntity)
    private callSessionRepo: Repository<CallSessionEntity>,
  ) {
    const raw = process.env.TWILIO_PROXY_NUMBERS ?? '';
    this.pool = raw
      .split(',')
      .map((n) => n.trim())
      .filter(Boolean);

    if (this.pool.length === 0) {
      this.logger.warn(
        'TWILIO_PROXY_NUMBERS is empty — in-app calling will always return 503',
      );
    }
  }

  /**
   * Allocate a proxy number for the given booking.
   * Reuses the same number on subsequent calls for the same booking.
   */
  async allocate(bookingId: string): Promise<string> {
    if (this.pool.length === 0) {
      throw new ServiceUnavailableException({
        statusCode: 503,
        code: ErrorCodes.NO_PROXY_NUMBERS_AVAILABLE,
        message: 'No proxy numbers are configured',
      });
    }

    // Reuse if a prior session for this booking already has a proxy number.
    const prior = await this.callSessionRepo.findOne({
      where: { bookingId },
      order: { createdAt: 'ASC' },
    });
    if (prior) return prior.proxyNumber;

    // Find numbers currently in an active session for a *different* booking.
    const activeSessions = await this.callSessionRepo.find({
      where: {
        status: Not(
          CallSessionStatus.COMPLETED,
        ) as unknown as CallSessionStatus,
        bookingId: Not(bookingId) as unknown as string,
      },
      select: ['proxyNumber'],
    });
    const lockedNumbers = new Set(activeSessions.map((s) => s.proxyNumber));

    const available = this.pool.find((n) => !lockedNumbers.has(n));
    if (!available) {
      throw new ServiceUnavailableException({
        statusCode: 503,
        code: ErrorCodes.NO_PROXY_NUMBERS_AVAILABLE,
        message:
          'All proxy numbers are currently in use — please try again shortly',
      });
    }

    return available;
  }
}
