/**
 * Delay until the trip should auto-transition from PUBLISHED/FULLY_BOOKED to
 * IN_PROGRESS. Fires at departureTime — drivers no longer have to press a
 * "Start Trip" button; the lifecycle progresses automatically with the clock.
 */
export function computeTripAutoStartDelayMs(departureTime: Date): number {
  const runAtMs = new Date(departureTime).getTime();
  return Math.max(0, runAtMs - Date.now());
}

export const TRIP_AUTO_START_JOB_ID_PREFIX = 'trip-auto-start-';

/**
 * Delay until the trip is auto-completed as a fallback when the driver never
 * presses "Arrived". Defaults to 24h after departure; configurable via env.
 */
export function computeTripAutoCompleteDelayMs(departureTime: Date): number {
  const runAtMs =
    new Date(departureTime).getTime() + tripAutoCompleteFallbackMs();
  return Math.max(0, runAtMs - Date.now());
}

/** How long after departure a trip still in progress is auto-completed. */
export function tripAutoCompleteFallbackMs(): number {
  const fallbackHours = process.env.TRIP_AUTO_COMPLETE_FALLBACK_HOURS
    ? Number(process.env.TRIP_AUTO_COMPLETE_FALLBACK_HOURS)
    : 24;
  return Math.max(1, fallbackHours) * 60 * 60 * 1000;
}

/** Road distance runs longer than the straight line between two points. */
const ROAD_FACTOR = 1.3;
const FALLBACK_SPEED_KMH = 70;
const AUTO_END_MIN_MARGIN_MS = 30 * 60 * 1000;
const AUTO_END_MARGIN_SHARE = 0.25;
const STILL_DRIVING_WINDOWS = 2;

function straightLineKm(
  from: { coordinates: number[] },
  to: { coordinates: number[] },
): number {
  const rad = (deg: number) => (deg * Math.PI) / 180;
  const [fromLng, fromLat] = from.coordinates;
  const [toLng, toLat] = to.coordinates;
  const dLat = rad(toLat - fromLat);
  const dLng = rad(toLng - fromLng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(fromLat)) * Math.cos(rad(toLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

function plannedEstimateMs(trip: {
  fromPoint: { coordinates: number[] };
  toPoint: { coordinates: number[] };
}): number {
  return (
    ((straightLineKm(trip.fromPoint, trip.toPoint) * ROAD_FACTOR) /
      FALLBACK_SPEED_KMH) *
    60 *
    60 *
    1000
  );
}

function withMargin(estimateMs: number): number {
  return (
    estimateMs +
    Math.max(AUTO_END_MIN_MARGIN_MS, estimateMs * AUTO_END_MARGIN_SHARE)
  );
}

/**
 * Delay until a trip that just started is ended for the driver: the estimated
 * time left plus a margin, never past the fallback after departure.
 */
export function computeTripAutoEndDelayMs(trip: {
  departureTime: Date;
  fromPoint: { coordinates: number[] };
  toPoint: { coordinates: number[] };
  remainingDurationSeconds?: number | null;
}): number {
  const estimateMs =
    trip.remainingDurationSeconds != null
      ? trip.remainingDurationSeconds * 1000
      : plannedEstimateMs(trip);
  return Math.min(
    withMargin(estimateMs),
    computeTripAutoCompleteDelayMs(new Date(trip.departureTime)),
  );
}

/**
 * When a started trip is due to end, and the latest a car still driving may
 * hold it open. Built on the planned route, because the live estimate shrinks
 * as the car moves and would keep pulling the due time earlier.
 */
export function tripAutoEndTimes(trip: {
  departureTime: Date;
  tripStartedAt?: Date | null;
  fromPoint: { coordinates: number[] };
  toPoint: { coordinates: number[] };
}): { dueAt: number; lastCallAt: number } {
  const startedAt = new Date(
    trip.tripStartedAt ?? trip.departureTime,
  ).getTime();
  const fallbackAt =
    new Date(trip.departureTime).getTime() + tripAutoCompleteFallbackMs();
  const windowMs = withMargin(plannedEstimateMs(trip));
  return {
    dueAt: Math.min(startedAt + windowMs, fallbackAt),
    lastCallAt: Math.min(
      startedAt + windowMs * STILL_DRIVING_WINDOWS,
      fallbackAt,
    ),
  };
}

export const TRIP_AUTO_COMPLETE_JOB_ID_PREFIX = 'trip-auto-complete-';
