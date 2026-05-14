/**
 * CancellationPolicyHelper
 *
 * Pure-function helper that determines whether a cancellation request is
 * within policy.
 *
 * Rules:
 *  - Passenger: may cancel up to 12 hours before departure (window = 43 200 s).
 *    Passengers are NEVER charged a cancellation fee — fines are admin-only,
 *    applied via /admin/fines and only against drivers.
 *  - Driver: may cancel up to 24 hours before departure (window = 86 400 s).
 *    Within window: blocked.
 */

export type CancellationRole = 'passenger' | 'driver';

export interface CancellationPolicyResult {
  /** Whether the cancellation is within the allowed time window. */
  allowed: boolean;
  /** The window size in seconds (used in the CANCELLATION_WINDOW_CLOSED error body). */
  windowSeconds: number;
  /** Always null — no automatic charges. Retained for backwards-compatible call sites. */
  chargeRate: number | null;
}

const PASSENGER_WINDOW_SECONDS = 12 * 3600;
const DRIVER_WINDOW_SECONDS = 24 * 3600;

export function checkCancellationPolicy(
  role: CancellationRole,
  departureTime: Date,
  _bookingStatus: string,
  now: Date = new Date(),
): CancellationPolicyResult {
  const msUntilDeparture = departureTime.getTime() - now.getTime();
  const windowSeconds =
    role === 'driver' ? DRIVER_WINDOW_SECONDS : PASSENGER_WINDOW_SECONDS;
  const windowMs = windowSeconds * 1000;

  const allowed = msUntilDeparture >= windowMs;

  return { allowed, windowSeconds, chargeRate: null };
}
