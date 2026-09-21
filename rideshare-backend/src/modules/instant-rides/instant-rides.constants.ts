/**
 * Tunable parameters for instant-ride dispatch and fare estimation.
 *
 * These are the design-doc defaults (specs/010-instant-rides/design.md, §14).
 * Fare amounts are in the trip's local currency (resolved from the pickup
 * country) — adjust per market when real pricing is decided.
 */

// ── Dispatch (sequential matching) ──────────────────────────────────────────
/**
 * Read a positive number from the environment, falling back when the variable
 * is unset or not a usable number. Deployments differ enough between a dense
 * city and a rural governorate that these have to be tunable per market
 * without a rebuild.
 */
function envKm(name: string, fallback: number): number {
  const parsed = Number(process.env[name]);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

/** Radius of the first sweep — keeps dense-city matches close. */
export const INITIAL_RADIUS_KM = envKm('INSTANT_INITIAL_RADIUS_KM', 3);
/**
 * Ceiling for the search. Raising this never worsens a city match: candidates
 * are always ordered nearest-first, so a wider ring is only ever reached after
 * the closer ones came back empty. It does raise the worst-case pickup wait,
 * which is the real trade-off — at PICKUP_ETA_SPEED_KMH, 25 km is roughly an
 * hour of approach.
 */
export const MAX_RADIUS_KM = envKm('INSTANT_MAX_RADIUS_KM', 25);

/** How long a single driver has to respond to an offer. */
export const OFFER_TTL_SECONDS = 25;
/** Overall window before a request gives up searching. */
export const REQUEST_TTL_SECONDS = 180;
/**
 * When a full radius sweep finds no lockable driver, retry a new dispatch
 * wave after this interval (the request keeps searching until its TTL).
 */
export const DISPATCH_RETRY_SECONDS = 10;
/** Suggested raise in the "no drivers — raise your fare" nudge (+15%). */
export const NUDGE_FARE_BUMP_FACTOR = 1.15;
/** Average urban approach speed used for pickup-ETA estimates. */
export const PICKUP_ETA_SPEED_KMH = 25;

// ── Fare estimate ───────────────────────────────────────────────────────────
export const FARE_BASE = 1.0;
export const FARE_PER_KM = 0.5;
export const FARE_PER_MIN = 0.1;
export const FARE_MINIMUM = 1.5;

// ── Passenger-priced fares + driver counter-offers ──────────────────────────
/** Lowest passenger fare accepted, as a fraction of the recommendation. */
export const PASSENGER_FARE_MIN_FACTOR = 0.7;
/** Highest passenger fare accepted, as a multiple of the recommendation. */
export const PASSENGER_FARE_MAX_FACTOR = 2.0;
/** A driver's counter-offer may exceed the passenger's fare by at most +50%. */
export const COUNTER_FARE_MAX_FACTOR = 1.5;
/** How long the passenger has to accept/decline a driver's counter-offer. */
export const COUNTER_TTL_SECONDS = 30;

// ── Queue names ─────────────────────────────────────────────────────────────
export const INSTANT_OFFER_TIMEOUT_QUEUE = 'instant-offer-timeout';
export const INSTANT_REQUEST_EXPIRY_QUEUE = 'instant-request-expiry';
export const EXPIRE_OFFER_JOB = 'expire-offer';
export const EXPIRE_REQUEST_JOB = 'expire-request';
/** Delayed re-dispatch wave (runs on the request-expiry queue). */
export const DISPATCH_WAVE_JOB = 'dispatch-wave';

export const offerTimeoutJobId = (offerId: string) =>
  `instant-offer:${offerId}`;
export const requestExpiryJobId = (requestId: string) =>
  `instant-request:${requestId}`;
export const dispatchWaveJobId = (requestId: string) =>
  `instant-wave:${requestId}`;
