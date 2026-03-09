import {
  BadRequestException,
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';

@Injectable()
export class WsRateLimitGuard implements CanActivate {
  private readonly windowMs = 60_000;
  private readonly maxEventsPerWindow = 180;
  private readonly buckets = new Map<
    string,
    { count: number; resetAt: number }
  >();

  canActivate(context: ExecutionContext): boolean {
    const client = context.switchToWs().getClient();
    const userId =
      client?.data?.userId ||
      client?.user?.id ||
      client?.handshake?.address ||
      'anonymous';
    const key = String(userId);
    const now = Date.now();
    const current = this.buckets.get(key);

    if (!current || now >= current.resetAt) {
      this.buckets.set(key, { count: 1, resetAt: now + this.windowMs });
      return true;
    }

    current.count += 1;
    if (current.count > this.maxEventsPerWindow) {
      throw new BadRequestException(
        'Too many websocket events, try again shortly',
      );
    }
    return true;
  }
}
