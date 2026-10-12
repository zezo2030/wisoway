import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

/**
 * Honours "hide my phone number": blanks the phone of every user in a
 * response who switched it on, unless that user is the one asking (or an
 * admin).
 *
 * Phones reach other users through whole user records attached to bookings,
 * trips and rides rather than through one field, so this is enforced once on
 * the way out instead of in each endpoint. A user record is recognised by
 * carrying both `id` and `hidePhoneNumber`, which every load of `UserEntity`
 * does.
 */
@Injectable()
export class HiddenPhoneInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();

    const viewer = context.switchToHttp().getRequest<{
      user?: { id?: string; role?: string };
    }>().user;
    if (viewer?.role === 'admin') return next.handle();

    return next
      .handle()
      .pipe(map((data) => scrubHiddenPhones(data, viewer?.id ?? null)));
  }
}

/** Blanks hidden phones in place; exported for tests. */
export function scrubHiddenPhones<T>(data: T, viewerId: string | null): T {
  walk(data, viewerId, new WeakSet());
  return data;
}

function walk(value: unknown, viewerId: string | null, seen: WeakSet<object>) {
  if (!value || typeof value !== 'object') return;
  if (value instanceof Date || Buffer.isBuffer(value)) return;
  if (seen.has(value)) return;
  seen.add(value);

  if (Array.isArray(value)) {
    for (const item of value) walk(item, viewerId, seen);
    return;
  }

  const record = value as Record<string, unknown>;
  if (
    record.hidePhoneNumber === true &&
    typeof record.id === 'string' &&
    record.id !== viewerId
  ) {
    if ('phoneNumber' in record) record.phoneNumber = null;
    if ('phone' in record) record.phone = null;
  }
  for (const key of Object.keys(record)) walk(record[key], viewerId, seen);
}
