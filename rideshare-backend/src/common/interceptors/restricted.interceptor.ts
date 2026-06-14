import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { ErrorCodes } from '../errors/error-codes';

/** HTTP methods that are considered read-only and pass through unrestricted. */
const READ_ONLY_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

/**
 * RestrictedAccountInterceptor — global interceptor.
 *
 * When the authenticated user has `restricted=true`, any write request
 * (POST, PUT, PATCH, DELETE) is rejected with:
 *   `423 Locked` — `{ code: 'ACCOUNT_RESTRICTED' }`
 *
 * Read-only endpoints (GET, HEAD, OPTIONS) pass through unchanged so the
 * user can still browse trips, check their bookings, etc.
 *
 * Unauthenticated requests and public endpoints are unaffected; if `req.user`
 * is absent the interceptor is a no-op.
 *
 * Note: Ban supersedes restricted — BanGuard (a guard, running before
 * interceptors) will have already blocked banned users before this runs.
 */
@Injectable()
export class RestrictedAccountInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user || !user.restricted) {
      return next.handle();
    }

    const method: string = (request.method as string).toUpperCase();

    if (READ_ONLY_METHODS.has(method)) {
      // Read operations are permitted even for restricted accounts
      return next.handle();
    }

    throw new HttpException(
      {
        code: ErrorCodes.ACCOUNT_RESTRICTED,
        message:
          'Your account is currently restricted. Write operations are not permitted.',
      },
      HttpStatus.LOCKED, // 423
    );
  }
}
