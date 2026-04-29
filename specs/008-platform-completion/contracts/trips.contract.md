# Contract — Trips, Stops, Notes, and Recurrence (Phase 4: `012-trip-authoring`)

## Modified endpoints

### POST `/trips` *(existing — extended)*
Request shape gains:
```json
{
  "fromName": "...",
  "fromAddress": "...",
  "fromPoint": { "lat": 31.95, "lng": 35.92 },
  "toName": "...",
  "toAddress": "...",
  "toPoint": { "lat": 32.55, "lng": 35.85 },
  "departureTime": "2026-05-01T08:00:00+03:00",
  "price": "5.00",
  "currency": "JOD",
  "stops": [
    { "name": "Zarqa fuel stop", "address": "...", "lat": ..., "lng": ..., "order": 1, "note": "I stop for 5 minutes" }
  ],
  "notes": "No smoking please.",
  "recurrence": {
    "frequency": "weekly",
    "weekdays": ["sun","tue","thu"],
    "until": "2026-08-01"
  } | null
}
```
- `stops` and `notes` are optional.
- `recurrence`, when provided, also creates a `trip_recurrence_rules` row. The first generated occurrence is the trip being inserted. Subsequent occurrences are spawned by the `recurrence-spawn` job (see below).
Validation:
- Driver must have `isDriverApproved=true` AND `photoUrl IS NOT NULL` AND `bannedAt IS NULL` AND `restricted=false`.
- `stops.length` ≤ 5 to keep the route map sane.

Errors:
- `403 DRIVER_REQUIRES_APPROVAL`
- `422 PROFILE_PHOTO_REQUIRED`
- `403 ACCOUNT_BANNED`

### PATCH `/trips/:id` *(existing — extended)*
Allows editing `notes`, `stops`, and `departureTime` (latter only when the trip has zero confirmed bookings or > 24h before). Editing the recurrence rule is a separate endpoint.

### DELETE `/trips/:id` *(existing — policy added)*
- If `trip.departureTime - now <= 24h`: `403 CANCELLATION_WINDOW_CLOSED` with `windowSeconds`.
- Else: cancel the trip; release all bookings (each booking gets `cancelledBy='trip_cancelled_by_driver'`); notify passengers; if recurrence rule is the source, do NOT deactivate the rule (FR-014).

## New endpoints

### GET `/trips/recurrence-rules` *(driver)*
Lists the caller's recurrence rules.

### PATCH `/trips/recurrence-rules/:id`
Toggle `isActive`, change `until`, change `weekdays`.

### DELETE `/trips/recurrence-rules/:id`
Sets `isActive=false`. Future occurrences will not be spawned. Existing already-spawned trips are untouched.

## Background job

`recurrence-spawn` queue runs hourly (cron-style). Each tick:
- Find every active rule.
- For each rule, compute the next 7 occurrence dates from `lastSpawnedFor` (or rule creation date if null) up to the smaller of `now + 14 days` or `rule.until`.
- For each missing occurrence, attempt to insert a new `Trip` from `templateJson` with `departureTime` shifted to the local-time / weekday slot. If a trip with the same `(driverId, departureTime)` already exists, log `recurrence_skip` and continue.
- Update `rule.lastSpawnedFor`.

## Contract tests

- `create-with-stops.contract.spec.ts`
- `create-with-recurrence.contract.spec.ts` (and the integration test that the spawner produces the expected dates)
- `cancel-window.contract.spec.ts`
- `recurrence-rule-toggle.contract.spec.ts`
- `spawn-skip-conflict.integration.spec.ts`
