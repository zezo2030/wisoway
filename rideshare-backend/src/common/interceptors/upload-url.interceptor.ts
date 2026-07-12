import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Request } from 'express';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

/**
 * Rewrites the origin (scheme + host) of any stored `/uploads/` or `/public/`
 * URL in the response so it points at the address the client actually used to
 * reach the API.
 *
 * Upload URLs are persisted as absolute URLs at upload time (e.g. baked with
 * `http://localhost:3000`). When the API later runs on a different port/host —
 * or is reached from a mobile emulator (`10.0.2.2`) or a LAN IP — those baked
 * hosts become unreachable and images fail with ERR_CONNECTION_REFUSED. By
 * normalising the origin on every response we keep both pre-existing and new
 * records reachable without a data migration or per-environment config.
 */
@Injectable()
export class UploadUrlInterceptor implements NestInterceptor {
  // Matches an absolute http(s) URL whose path is under /uploads or /public.
  private static readonly ABSOLUTE_UPLOAD_URL =
    /^https?:\/\/[^/]+(\/(?:uploads|public)\/.*)$/i;

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') {
      return next.handle();
    }

    const request = context.switchToHttp().getRequest<Request>();
    const base = this.resolveBaseUrl(request);

    return next
      .handle()
      .pipe(map((data) => this.rewrite(data, base, new WeakSet())));
  }

  private resolveBaseUrl(request: Request): string {
    const proto =
      (request.headers['x-forwarded-proto'] as string)?.split(',')[0]?.trim() ||
      request.protocol ||
      'http';
    const host =
      (request.headers['x-forwarded-host'] as string)?.split(',')[0]?.trim() ||
      request.get('host');
    return host ? `${proto}://${host}` : '';
  }

  private rewrite(value: unknown, base: string, seen: WeakSet<object>): unknown {
    if (!base) {
      return value;
    }
    if (typeof value === 'string') {
      return this.rewriteString(value, base);
    }
    if (Array.isArray(value)) {
      return value.map((item) => this.rewrite(item, base, seen));
    }
    if (value && typeof value === 'object') {
      // Leave non-walkable values (Date, Buffer, etc.) untouched.
      if (value instanceof Date || Buffer.isBuffer(value)) {
        return value;
      }
      // Guard against circular references in TypeORM relation graphs.
      if (seen.has(value)) {
        return value;
      }
      seen.add(value);
      // Mutate in place so TypeORM entity instances keep their shape; only
      // string fields under /uploads or /public are ever changed.
      for (const [key, val] of Object.entries(value)) {
        (value as Record<string, unknown>)[key] = this.rewrite(val, base, seen);
      }
      return value;
    }
    return value;
  }

  private rewriteString(value: string, base: string): string {
    const match = UploadUrlInterceptor.ABSOLUTE_UPLOAD_URL.exec(value);
    if (match) {
      return `${base}${match[1]}`;
    }
    if (value.startsWith('/uploads/') || value.startsWith('/public/')) {
      return `${base}${value}`;
    }
    return value;
  }
}
