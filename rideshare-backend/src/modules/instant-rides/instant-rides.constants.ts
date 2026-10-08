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
 * Ceiling for the search. Candidates are always ordered nearest-first, so a
 * wider ring is only reached after the closer ones came back empty; the cost
 * is the pickup wait — at PICKUP_ETA_SPEED_KMH, 20 km is ~50 min of approach.
 * 20 km is the owner's choice: further than that is not an "instant" ride.
 */
export const MAX_RADIUS_KM = envKm('INSTANT_MAX_RADIUS_KM', 20);

/**
 * How long a single driver has to respond to an offer. 25 s proved too short
 * once delivery and reading the card ate into it.
 */
export const OFFER_TTL_SECONDS = 40;
/** Overall window before a request gives up searching. */
export const REQUEST_TTL_SECONDS = 180;
/**
 * When a full radius sweep finds no lockable driver, retry a new dispatch
 * wave after this interval (the request keeps searching until its TTL).
 */
export const DISPATCH_RETRY_SECONDS = 10;
/** Average urban approach speed used for pickup-ETA estimates. */
export const PICKUP_ETA_SPEED_KMH = 25;

// ── Fare ────────────────────────────────────────────────────────────────────
/**
 * Instant fares are fixed by the platform: base + per km + per minute of the
 * driving route, never below the minimum, rounded up to `step`. There is no
 * passenger pricing and no driver counter-offer — the passenger sees the
 * price before ordering and the driver accepts or declines it as-is.
 *
 * Amounts are in the currency of the pickup country, so each market needs its
 * own row; a currency without one uses {@link DEFAULT_FARE_TARIFF}.
 */
export interface FareTariff {
  base: number;
  perKm: number;
  perMin: number;
  minimum: number;
  /** The fare is rounded up to a multiple of this (no 17.43 SAR fares). */
  step: number;
}

export const FARE_TARIFFS: Readonly<Record<string, FareTariff>> = {
  SAR: { base: 6, perKm: 1.4, perMin: 0.3, minimum: 12, step: 1 },
  JOD: { base: 0.5, perKm: 0.28, perMin: 0.04, minimum: 1.25, step: 0.25 },
  AED: { base: 6, perKm: 1.4, perMin: 0.3, minimum: 12, step: 1 },
  QAR: { base: 6, perKm: 1.4, perMin: 0.3, minimum: 12, step: 1 },
  KWD: { base: 0.4, perKm: 0.12, perMin: 0.03, minimum: 1, step: 0.25 },
  BHD: { base: 0.5, perKm: 0.15, perMin: 0.03, minimum: 1, step: 0.25 },
  OMR: { base: 0.5, perKm: 0.15, perMin: 0.03, minimum: 1, step: 0.25 },
  EGP: { base: 15, perKm: 7, perMin: 1.5, minimum: 35, step: 5 },
};

/** Fallback for currencies without their own row (the original defaults). */
export const DEFAULT_FARE_TARIFF: FareTariff = {
  base: 1,
  perKm: 0.5,
  perMin: 0.1,
  minimum: 1.5,
  step: 0.25,
};

export function fareTariffFor(currency: string): FareTariff {
  return FARE_TARIFFS[currency?.toUpperCase()] ?? DEFAULT_FARE_TARIFF;
}

/** The fixed fare for a route of this length and driving time. */
export function computeFare(
  distanceKm: number,
  durationMin: number,
  currency: string,
): number {
  const t = fareTariffFor(currency);
  const raw = Math.max(
    t.minimum,
    t.base + distanceKm * t.perKm + durationMin * t.perMin,
  );
  // Round up to the step; the epsilon keeps 12.000000001 from becoming 13.
  const steps = Math.ceil(raw / t.step - 1e-9);
  return Math.round(steps * t.step * 100) / 100;
}

/**
 * When no routing service answers, the straight line is stretched by this to
 * approximate the road distance, and driven at {@link FALLBACK_ROUTE_SPEED_KMH}.
 */
export const FALLBACK_ROAD_FACTOR = 1.3;
export const FALLBACK_ROUTE_SPEED_KMH = 40;

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
