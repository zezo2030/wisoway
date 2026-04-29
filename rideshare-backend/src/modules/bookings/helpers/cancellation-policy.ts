/**
 * CancellationPolicyHelper
 *
 * Pure-function helper that determines whether a cancellation request is
 * within policy and what penalty charge applies.
 *
 * Rules (from spec FR-015, FR-025):
 *  - Passenger: may cancel up to 12 hours before departure (window = 43 200 s)
 *    - Within window on a confirmed booking: 5% penalty
 *    - Within window on a pending booking: blocked (no charge) — driver should
 *      simply reject instead
 *  - Driver: may cancel up to 24 hours before departure (window = 86 400 s)
 *    - Within window: blocked (no charge for driver)
 *
 * Phase 4 / T072 / 010-booking-lifecycle
 */

export type CancellationRole = 'passenger' | 'driver';

export interface CancellationPolicyResult {
  /** Whether the cancellation is within the allowed time window. */
  allowed: boolean;
  /** The window size in seconds (used in the CANCELLATION_WINDOW_CLOSED error body). */
  windowSeconds: number;
  /**
   * Penalty rate to apply to totalAmount.
   * null when no charge applies (driver cancellations, or pending-booking passenger cancellations).
   */
  chargeRate: number | null;
}

const PASSENGER_WINDOW_SECONDS = 12 * 3600; // 12 hours
const DRIVER_WINDOW_SECONDS = 24 * 3600; // 24 hours
const PASSENGER_CHARGE_RATE = 0.05; // 5% of totalAmount

export function checkCancellationPolicy(
  role: CancellationRole,
  departureTime: Date,
  bookingStatus: string,
  now: Date = new Date(),
): CancellationPolicyResult {
  const msUntilDeparture = departureTime.getTime() - now.getTime();
  const windowSeconds =
    role === 'driver' ? DRIVER_WINDOW_SECONDS : PASSENGER_WINDOW_SECONDS;
  const windowMs = windowSeconds * 1000;

  const allowed = msUntilDeparture >= windowMs;

  // Charge only for passengers cancelling a confirmed booking inside the window
  const chargeRate =
    !allowed && role === 'passenger' && bookingStatus === 'confirmed'
      ? PASSENGER_CHARGE_RATE
      : null;

  return { allowed, windowSeconds, chargeRate };
}
