# Contract — Trip-Time Flow & Live Tracking (Phase 3: `011-trip-time-flow`)

## New endpoints

### POST `/bookings/:id/passenger-confirm` *(passenger)*
Body: `{ driverPresent: boolean }`. Sets `passengerPresenceConfirmedAt = now` if `driverPresent=true`. If `false`, sets a separate `passengerReportedDriverAbsentAt` and notifies the driver. Available only in the window `[departureTime - 60min, departureTime + 30min]`.

### POST `/bookings/:id/driver-confirm` *(driver)*
Body: `{ seatNumber: string, present: boolean }`. Updates `BookingSeat.presenceConfirmedAt` or `markedAbsentAt` for the named seat. The booking-level `driverConfirmedPassengerAt` is set when at least one of the booking's seats is marked present; `driverMarkedAbsentAt` when *all* of them are marked absent.

### POST `/trips/:id/start` *(driver)*
No body. Preconditions:
- Caller is the driver of the trip.
- `now` is within `[departureTime - 15min, departureTime + 30min]`.
- Driver is not banned, restricted, or otherwise blocked.
- No mocked-location event in the last 5 minutes.
Effects:
- `trip.status='in_progress'`, `tripStartedAt=now`.
- All bookings on the trip currently `confirmed` flip to `in_progress`.
- The `no-show-detector` queue job for this trip is removed.

### POST `/trips/:id/complete` *(driver)*
Body: `{ noShowSeats?: [{ bookingId, seatNumber }] }`. Effects:
- `trip.status='completed'`, `tripCompletedAt=now`.
- For each booking that has any seat in `noShowSeats`, set those `BookingSeat.markedAbsentAt = trip.completedAt`. If *all* of a booking's seats are no-show, set `booking.status='no_show'` and create a `pending_charges` row of kind `passenger_no_show` for 5% of `booking.totalAmount`.
- All other bookings flip from `in_progress` to `completed`.
- Open the rating window for both sides.
- Refresh any active `trip_share_links` to expire 30 minutes from now.

### POST `/trips/:id/share-link` *(passenger or driver)*
Caller must have a confirmed booking on the trip OR be the driver. Generates a new `trip_share_links` row. Response: `{ url: 'https://app.wisoway.example/share/<token>', expiresAt }`.

### GET `/share/:token` *(public, unauthenticated)*
Public read-only endpoint. Response:
```json
{
  "tripStatus": "published" | "in_progress" | "completed" | "cancelled",
  "fromName": "...",
  "toName": "...",
  "departureTime": "...",
  "etaMinutes": 12,                      // null when not in_progress
  "driverLocation": {                    // null when tripStatus != in_progress
    "lat": 31.95, "lng": 35.92, "capturedAt": "..."
  },
  "vehicleSummary": {                    // no PII
    "type": "Sedan", "model": "Hyundai Elantra", "color": "white"
  }
}
```
- No driver name. No passenger names. No phone numbers.
- Rate-limited per token: 1 req/sec, burst 60. Beyond that, 429.

## Modified endpoints

### POST `/tracking/location` *(driver — existing)*
Adds `isMockLocation: boolean` field. Server rejects with `403 LOCATION_INTEGRITY_VIOLATION` when `true` (R-005). On success, also updates `trips.lastDriverLocationLat/Lng/At` denormalized columns for the share-link reader.

## Background jobs

| Queue | Trigger | Action |
|---|---|---|
| `pre-trip-confirm` | scheduled at `departureTime - 30min` for every published trip with at least 1 confirmed booking | Push prompt to each confirmed passenger; push 1 prompt per passenger to driver |

## Contract tests

- `passenger-confirm.contract.spec.ts`
- `driver-confirm.contract.spec.ts`
- `start-trip.contract.spec.ts` (covers timing-window rejection, mocked-location rejection)
- `complete-trip.contract.spec.ts` (covers no-show flagging)
- `share-link.contract.spec.ts` (issuance + public read shape + rate limit + completion behavior)
- `pre-trip-confirm.integration.spec.ts`
- `live-tracking-mock-rejection.integration.spec.ts`
