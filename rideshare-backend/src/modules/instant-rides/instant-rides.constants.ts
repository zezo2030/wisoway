import { CLIQ_CURRENCIES } from '../ride-payments/cliq-payer';

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
 * The longest a passenger waits on «جاري البحث عن سائق»: the request's hard
 * cap, offers in flight included. The owner asked for 30 s — a longer search
 * just keeps the passenger watching a spinner.
 */
export const REQUEST_TTL_SECONDS = envKm('INSTANT_SEARCH_SECONDS', 30);
/**
 * How long a single driver has to respond to an offer. 25 s proved too short
 * once delivery and reading the card ate into it. Never runs past the
 * request's own end (see {@link offerTtlSeconds}).
 */
export const OFFER_TTL_SECONDS = 40;
/**
 * An offer with less time than this left on the request isn't worth sending:
 * the driver couldn't get the card and answer before the search ends.
 */
export const MIN_OFFER_SECONDS = 8;
/**
 * How long the offer to one driver runs, given the time left on the request
 * ([remainingMs]). Returns 0 when too little is left to make an offer.
 */
export function offerTtlSeconds(remainingMs: number): number {
  const remaining = Math.floor(remainingMs / 1000);
  if (remaining < MIN_OFFER_SECONDS) return 0;
  return Math.min(OFFER_TTL_SECONDS, remaining);
}
/**
 * How long to look for a driver before telling the passenger there is none.
 * The reach widens from [INITIAL_RADIUS_KM] to [MAX_RADIUS_KM] over this
 * window; a sweep at full reach that still finds nobody ends the search
 * rather than leaving the passenger watching a spinner. Kept inside the
 * request's life so the widest sweep happens before it ends.
 */
export const NO_DRIVER_SEARCH_SECONDS = Math.min(
  envKm('INSTANT_NO_DRIVER_SECONDS', 20),
  REQUEST_TTL_SECONDS,
);
/**
 * When a full radius sweep finds no lockable driver, retry a new dispatch
 * wave after this interval (the request keeps searching until its TTL).
 */
export const DISPATCH_RETRY_SECONDS = 10;
/** Average urban approach speed used for pickup-ETA estimates. */
export const PICKUP_ETA_SPEED_KMH = 25;

// ── Late to the pickup ──────────────────────────────────────────────────────
/** Pickup estimate used when the driver's position was unknown at match. */
export const DEFAULT_PICKUP_ETA_SECONDS = 5 * 60;
/** Slack past the pickup estimate before the driver counts as late. */
export const PICKUP_LATE_GRACE_MINUTES = envKm(
  'INSTANT_PICKUP_LATE_GRACE_MINUTES',
  3,
);
/** Gap between «you're late» reminders while the driver still hasn't come. */
export const PICKUP_LATE_REMIND_MINUTES = 3;
/** Reminders per ride; after these the passenger can cancel or call. */
export const PICKUP_LATE_MAX_WARNINGS = 3;
/** Late rides in this window count towards «repeated lateness». */
export const LATE_REPEAT_WINDOW_DAYS = 30;

/**
 * Delay before the [attempt]-th lateness check of a ride whose pickup was
 * estimated at [pickupEtaSeconds]: the estimate plus the grace first, then
 * every [PICKUP_LATE_REMIND_MINUTES].
 */
export function pickupLateDelayMs(
  pickupEtaSeconds: number | null,
  attempt: number,
): number {
  if (attempt > 1) return PICKUP_LATE_REMIND_MINUTES * 60_000;
  const eta = pickupEtaSeconds ?? DEFAULT_PICKUP_ETA_SECONDS;
  return eta * 1000 + PICKUP_LATE_GRACE_MINUTES * 60_000;
}
/**
 * How old an online driver's last location may be and still get offers.
 * The app reports every ~12 s while it runs (screen off included), but once
 * it is swiped away the reports stop while the driver stays online — and the
 * offer push still reaches the closed app. A 60 s cut-off made those drivers
 * invisible, so most requests found nobody. Fresh drivers are still asked
 * first (see DriverAvailabilityService.findNearbyAvailableDrivers).
 */
export const DISPATCH_STALE_MINUTES = envKm(
  'INSTANT_DISPATCH_STALE_MINUTES',
  30,
);

/**
 * SQL: the driver's `currentRequestId` (column [col]) holds no live claim.
 * A lock is taken per offer and kept through an accepted ride, but nothing
 * cleared it when that ride ended — the driver then never got another offer
 * until they went offline and back. So a lock only counts while its request
 * is still searching / offered, or accepted with its trip not yet over —
 * and for at most 12 hours: an instant ride never runs that long, and one
 * left open (an abandoned test ride) must not bench its driver for good.
 */
export function lockIsFreeSql(col: string): string {
  return `(${col} IS NULL OR NOT EXISTS (
    SELECT 1 FROM instant_ride_requests lr
    LEFT JOIN trips lt ON lt.id = lr."tripId"
    WHERE lr.id = ${col}
      AND (
        lr.status IN ('searching', 'offered')
        OR (lr.status = 'accepted'
            AND (lt.id IS NULL OR lt.status NOT IN ('completed', 'cancelled'))
            AND lr."createdAt" > now() - interval '12 hours')
      )
  ))`;
}

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
/** Past this length the fallback assumes highway driving, not city streets. */
export const FALLBACK_INTERCITY_KM = 30;
export const FALLBACK_INTERCITY_SPEED_KMH = 80;
/**
 * A fallback route longer than the straight line × this is taken for a
 * detour of the routing service, and the stretched straight line is used.
 */
export const MAX_ROUTE_DETOUR_FACTOR = 1.6;

/**
 * Road distance and driving time estimated from the straight line, when no
 * routing service gave a usable answer. Within a city the stretched line is
 * driven at city speed; between cities at highway speed — else AlUla →
 * Tabuk came out at over 7 hours.
 */
export function straightLineRoute(straightKm: number): {
  distanceKm: number;
  durationMin: number;
} {
  const distanceKm = straightKm * FALLBACK_ROAD_FACTOR;
  const speed =
    distanceKm > FALLBACK_INTERCITY_KM
      ? FALLBACK_INTERCITY_SPEED_KMH
      : FALLBACK_ROUTE_SPEED_KMH;
  return { distanceKm, durationMin: Math.ceil((distanceKm / speed) * 60) };
}

// ── Payment ───────────────────────────────────────────────────────────────────
/** CliQ (Jordan only) is offered where the fare is in JOD; elsewhere cash. */
export function paymentMethodsFor(currency: string): Array<'cash' | 'cliq'> {
  return CLIQ_CURRENCIES.includes(currency?.toUpperCase())
    ? ['cash', 'cliq']
    : ['cash'];
}

// ── Queue names ─────────────────────────────────────────────────────────────
export const INSTANT_OFFER_TIMEOUT_QUEUE = 'instant-offer-timeout';
export const INSTANT_REQUEST_EXPIRY_QUEUE = 'instant-request-expiry';
export const EXPIRE_OFFER_JOB = 'expire-offer';
export const EXPIRE_REQUEST_JOB = 'expire-request';
/** Delayed re-dispatch wave (runs on the request-expiry queue). */
export const DISPATCH_WAVE_JOB = 'dispatch-wave';
/** «Is the driver at the pickup yet?» check (runs on the request-expiry queue). */
export const PICKUP_LATE_CHECK_JOB = 'pickup-late-check';

export const offerTimeoutJobId = (offerId: string) =>
  `instant-offer:${offerId}`;
export const requestExpiryJobId = (requestId: string) =>
  `instant-request:${requestId}`;
export const dispatchWaveJobId = (requestId: string) =>
  `instant-wave:${requestId}`;
export const pickupLateJobId = (tripId: string, attempt: number) =>
  `instant-late:${tripId}:${attempt}`;
