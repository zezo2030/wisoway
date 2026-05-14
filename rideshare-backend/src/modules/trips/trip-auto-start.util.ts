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
  const fallbackHours = process.env.TRIP_AUTO_COMPLETE_FALLBACK_HOURS
    ? Number(process.env.TRIP_AUTO_COMPLETE_FALLBACK_HOURS)
    : 24;
  const runAtMs =
    new Date(departureTime).getTime() +
    Math.max(1, fallbackHours) * 60 * 60 * 1000;
  return Math.max(0, runAtMs - Date.now());
}

export const TRIP_AUTO_COMPLETE_JOB_ID_PREFIX = 'trip-auto-complete-';
