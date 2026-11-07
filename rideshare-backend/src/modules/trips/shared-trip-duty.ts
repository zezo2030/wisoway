/**
 * A driver is on duty for a shared trip while it is under way, and from its
 * departure (or [leadMinutes] before it) while it still waits for riders who
 * have a confirmed booking. A due trip with nobody confirmed is cancelled at
 * departure, and one nobody boards for six hours is left alone.
 *
 * SQL condition on the trips row aliased [alias].
 */
export function sharedTripDutySql(alias: string, leadMinutes = 0): string {
  const lead = Math.max(0, Math.floor(leadMinutes));
  return `(${alias}."tripType" = 'scheduled' AND (${alias}.status = 'in_progress'
    OR (${alias}.status IN ('active', 'published', 'fully_booked')
      AND ${alias}."departureTime" BETWEEN now() - interval '6 hours'
        AND now() + interval '${lead} minutes'
      AND EXISTS (SELECT 1 FROM bookings duty_b
        WHERE duty_b."tripId" = ${alias}.id AND duty_b.status = 'confirmed'))))`;
}

/** Instant offers stop this long before a driver's shared trip leaves. */
export const INSTANT_FREE_BEFORE_SHARED_MIN = 30;
