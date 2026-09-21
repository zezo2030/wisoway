import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

export interface RateLimitVerdict {
  allowed: boolean;
  /** Seconds until the window resets, for the `Retry-After` header. */
  retryAfterSeconds: number;
}

type LocalEntry = { windowStartedAt: number; count: number };

/**
 * Per-user request budget for the places endpoints.
 *
 * Counters live in Redis so the limit holds across backend replicas; if Redis
 * is unreachable the limiter degrades to a per-process counter rather than
 * failing requests, since dropping search entirely is worse than an imprecise
 * limit. The Redis client is lazy: no connection is opened until the first
 * search request.
 */
@Injectable()
export class PlacesRateLimiter implements OnModuleDestroy {
  private readonly logger = new Logger(PlacesRateLimiter.name);
  private readonly windowMs: number;
  private readonly limitPerWindow: number;
  private readonly local = new Map<string, LocalEntry>();
  private redis: Redis | null = null;
  private redisUnavailable = false;

  constructor(private readonly configService: ConfigService) {
    this.windowMs =
      Number(this.configService.get('LOCATION_RATE_WINDOW_MS')) || 60_000;
    this.limitPerWindow =
      Number(this.configService.get('LOCATION_RATE_LIMIT')) || 60;
  }

  async consume(userId: string): Promise<RateLimitVerdict> {
    const windowSeconds = Math.ceil(this.windowMs / 1000);
    const redis = this.getRedis();

    if (redis) {
      try {
        const bucket = Math.floor(Date.now() / this.windowMs);
        const key = `places:rl:${userId}:${bucket}`;
        const count = await redis.incr(key);
        if (count === 1) {
          await redis.expire(key, windowSeconds);
        }
        return {
          allowed: count <= this.limitPerWindow,
          retryAfterSeconds: windowSeconds,
        };
      } catch (error) {
        // Fall through to the local counter; log once so a Redis outage is
        // visible without flooding the logs on every request.
        if (!this.redisUnavailable) {
          this.redisUnavailable = true;
          this.logger.warn(
            `Redis rate limiting unavailable, falling back to in-process counters: ${
              (error as Error)?.message ?? 'unknown error'
            }`,
          );
        }
      }
    }

    return this.consumeLocally(userId, windowSeconds);
  }

  private consumeLocally(
    userId: string,
    windowSeconds: number,
  ): RateLimitVerdict {
    const now = Date.now();
    this.pruneLocal(now);

    const current = this.local.get(userId);
    if (!current || now - current.windowStartedAt > this.windowMs) {
      this.local.set(userId, { windowStartedAt: now, count: 1 });
      return { allowed: true, retryAfterSeconds: windowSeconds };
    }

    current.count += 1;
    const elapsed = now - current.windowStartedAt;
    return {
      allowed: current.count <= this.limitPerWindow,
      retryAfterSeconds: Math.max(
        1,
        Math.ceil((this.windowMs - elapsed) / 1000),
      ),
    };
  }

  /** Drop expired buckets so the fallback map cannot grow without bound. */
  private pruneLocal(now: number) {
    if (this.local.size < 5_000) return;
    for (const [key, entry] of this.local) {
      if (now - entry.windowStartedAt > this.windowMs) {
        this.local.delete(key);
      }
    }
  }

  private getRedis(): Redis | null {
    if (this.redisUnavailable) return null;
    if (this.redis) return this.redis;

    try {
      this.redis = new Redis({
        host: this.configService.get<string>('REDIS_HOST') || 'localhost',
        port: Number(this.configService.get('REDIS_PORT')) || 6379,
        password: this.configService.get<string>('REDIS_PASSWORD') || undefined,
        lazyConnect: false,
        maxRetriesPerRequest: 1,
        enableOfflineQueue: false,
      });
      // Without a handler an ECONNREFUSED from ioredis is an unhandled 'error'
      // event, which crashes the process.
      this.redis.on('error', () => {
        if (!this.redisUnavailable) {
          this.redisUnavailable = true;
          this.logger.warn(
            'Redis connection failed; places rate limiting is per-process',
          );
        }
      });
      return this.redis;
    } catch {
      this.redisUnavailable = true;
      return null;
    }
  }

  async onModuleDestroy() {
    if (this.redis) {
      try {
        await this.redis.quit();
      } catch {
        this.redis.disconnect();
      }
      this.redis = null;
    }
  }
}
