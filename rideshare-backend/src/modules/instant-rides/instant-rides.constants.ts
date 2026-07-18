/**
 * Tunable parameters for instant-ride dispatch and fare estimation.
 *
 * These are the design-doc defaults (specs/010-instant-rides/design.md, §14).
 * Fare amounts are in the trip's local currency (resolved from the pickup
 * country) — adjust per market when real pricing is decided.
 */

// ── Dispatch (sequential matching) ──────────────────────────────────────────
export const INITIAL_RADIUS_KM = 3;
export const RADIUS_STEP_KM = 3;
export const MAX_RADIUS_KM = 10;

/** How long a single driver has to respond to an offer. */
export const OFFER_TTL_SECONDS = 12;
/** Overall window before a request gives up searching. */
export const REQUEST_TTL_SECONDS = 90;

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

export const offerTimeoutJobId = (offerId: string) =>
  `instant-offer:${offerId}`;
export const requestExpiryJobId = (requestId: string) =>
  `instant-request:${requestId}`;
