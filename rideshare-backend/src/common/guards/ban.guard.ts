import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { ErrorCodes } from '../errors/error-codes';

/**
 * BanGuard — global guard that runs after JwtAuthGuard.
 *
 * If the requesting user's `bannedAt` field is non-null the request is
 * rejected with `403 ACCOUNT_BANNED` and a body containing:
 *   { banReason, supportWhatsApp }
 *
 * Public endpoints (decorated with @Public()) are passed through unchanged.
 * Unauthenticated requests (no `req.user`) are also passed through — the
 * JwtAuthGuard upstream already handles those cases.
 */
@Injectable()
export class BanGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    // Let public endpoints through (e.g. OTP send, share-link public read)
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    // No authenticated user yet — JwtAuthGuard handles this case
    if (!user) {
      return true;
    }

    if (user.bannedAt != null) {
      throw new ForbiddenException({
        code: ErrorCodes.ACCOUNT_BANNED,
        banReason: user.banReason ?? null,
        supportWhatsApp: process.env.SUPPORT_WHATSAPP_E164 ?? '+962788883007',
      });
    }

    return true;
  }
}
