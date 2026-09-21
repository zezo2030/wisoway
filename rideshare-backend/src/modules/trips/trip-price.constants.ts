/**
 * Inputs for the per-seat price suggestion shown to a driver while publishing
 * a trip (create-trip wizard, step 2).
 *
 * These are deliberately separate from the instant-ride `FARE_*` constants:
 * an instant fare buys the whole car, while these price a single carpool seat.
 */

/** Trips further apart than this from the requested route are ignored. */
export const PRICE_SUGGESTION_RADIUS_M = 5_000;

/** How far back the historical sample reaches. */
export const PRICE_SUGGESTION_LOOKBACK_DAYS = 180;

/** Below this many comparable trips the historical sample is not trusted. */
export const PRICE_SUGGESTION_MIN_SAMPLE = 5;

/** Fixed part of the distance-based fallback estimate. */
export const SEAT_PRICE_BASE = 0.5;

/** Marginal cost per kilometre for the fallback estimate. */
export const SEAT_PRICE_PER_KM = 0.18;

/** Floor applied to the fallback estimate before the band is applied. */
export const SEAT_PRICE_MINIMUM = 1;

/** Half-width of the suggested band around the fallback estimate (±15%). */
export const SEAT_PRICE_BAND = 0.15;
