# Contract — Bookings & Pending Charges (Phase 2: `010-booking-lifecycle`)

Versioning note: the existing `POST /bookings` (single-seat shape) is kept as v1 for one release while the mobile floor rolls forward. New multi-seat work goes under `/v2/bookings`. Both versions live in the same controller file with shared service code; the v1 path translates the legacy single-seat payload into the v2 internal call.

## Modified endpoints

### POST `/v1/bookings` *(legacy — deprecated)*
Existing shape preserved. Server log includes `Deprecation: true`. Removed in a follow-up release.

## New v2 endpoints

### POST `/v2/bookings`
Create a multi-seat booking request.
Request:
```json
{
  "tripId": "uuid",
  "seats": [
    { "seatNumber": "1A", "displayName": "Layla S.", "gender": "female", "isMainBooker": true },
    { "seatNumber": "1B", "displayName": "Sister",   "gender": "female", "isMainBooker": false }
  ],
  "sharePhoneWithDriver": false
}
```
Validation:
- 1 ≤ `seats.length` ≤ trip.availableSeats.
- Exactly one `isMainBooker=true`.
- All `seatNumber` values must exist in the trip seat plan and be currently `available`.
- Adjacency rule applied across the *full* prospective set (existing booked seats + new seats).
Response (201):
```json
{
  "id": "uuid",
  "status": "pending",
  "tripId": "...",
  "seats": [...],
  "totalAmount": "12.00",
  "currency": "JOD",
  "expiresAt": "2026-04-27T14:00:00Z"  // createdAt + 3h
}
```
Errors:
- `409 SEATS_TAKEN` — one or more requested seats were just taken; response includes the conflicting seatNumbers.
- `422 GENDER_ADJACENCY_VIOLATION` — the requested arrangement breaks the trip's gender-mixing rule.
- `422 OUTSTANDING_PENDING_CHARGES_BLOCKING` — only used in the future "block booking" admin policy; not enforced by default.
- `403 DRIVER_REQUIRES_APPROVAL` — for the trip-create reverse case (covered separately under trips.contract).

### POST `/v2/bookings/auto-pick`
Server picks N seats respecting adjacency.
Request:
```json
{
  "tripId": "uuid",
  "seatCount": 2,
  "passengers": [
    { "displayName": "...", "gender": "female", "isMainBooker": true },
    { "displayName": "...", "gender": "female", "isMainBooker": false }
  ],
  "sharePhoneWithDriver": false
}
```
Server assigns seat numbers to each passenger and creates the booking via the same service path. Response identical to `POST /v2/bookings`.
Error: `422 NO_VALID_ARRANGEMENT` when no permutation satisfies adjacency.

### POST `/bookings/:id/accept` *(driver)*
No body. Sets `status=confirmed`, removes the BullMQ timeout job. Notifies passenger.
Errors: `409 ALREADY_DECIDED`, `403 NOT_TRIP_DRIVER`.

### POST `/bookings/:id/reject` *(driver)*
Body: `{ reason? }`. Sets `status=rejected`. Notifies passenger.

### POST `/bookings/:id/cancel`
Body: `{ reason? }`. Cancellation policy enforced by the service:
- If caller is passenger, requires `now < trip.departureTime - 12h`. Else `403 CANCELLATION_WINDOW_CLOSED` with `windowSeconds: <int>` so the client can render a clear "you can no longer cancel" message.
- If caller is driver, requires `now < trip.departureTime - 24h`.
Side effects:
- Releases the seats on the trip.
- If passenger cancellation of a confirmed booking outside-policy attempted: 403 (above).
- If passenger cancellation of a confirmed booking inside-policy: create `pending_charges` row of `kind='passenger_cancellation'`, `amount = totalAmount * 0.05`. Try wallet auto-deduct synchronously (R-006).

### GET `/bookings/:id`
Response shape gains: `seats`, `totalAmount`, `settledAt`, `settlementGraceUntil`, `passengerPresenceConfirmedAt`, `driverConfirmedPassengerAt`, plus a `viewerView` block describing the contact-detail mask state for the requesting user (`{ otherPartyPhone: '+962-***-***-3007' | '+962790000000', chatEnabled: bool, callEnabled: bool }`).

## Pending charges endpoints

### GET `/me/pending-charges`
Returns the caller's outstanding pending-charge rows for in-app awareness.

### POST `/admin/pending-charges/:id/waive` *(admin)*
Body: `{ note }`. Sets `status='waived'`, sets `waivedByAdminId`, `waivedAt`. Notifies the user via push.

## Background jobs (BullMQ — not HTTP, but covered by contract tests)

| Queue | Trigger | Action |
|---|---|---|
| `bookings-timeout` | created with `delay = 3h` on every new pending booking; removed on accept/reject/cancel | If still `pending`, set `status='cancelled'`, `cancelledBy='system_timeout'`; release seats; notify passenger |
| `no-show-detector` | created with `delay = trip.departureTime + 30min - now` on every new published trip; cancelled on `complete-trip` | If trip is not `in_progress`/`completed` and never had a `tripStartedAt`, declare driver no-show and create `pending_charge` of kind `driver_no_show` for 10% of `sum(confirmed bookings totalAmount)` |
| `pending-charge-collect` | enqueued from booking-confirm transaction when the user has any outstanding `pending` charges | Inside the booking-confirmation transaction, attempt wallet auto-deduct again; if still insufficient, mark the charge `appliedToBookingId` so it's added to the next platform-fee invoice |

## Contract tests

Files under `rideshare-backend/test/contract/bookings/`:

- `create-multi-seat.contract.spec.ts`
- `create-conflict.contract.spec.ts` (concurrent creation against the same seats)
- `auto-pick.contract.spec.ts`
- `accept-reject.contract.spec.ts`
- `cancel-windows.contract.spec.ts`
- `timeout.integration.spec.ts` (uses fake-timer driven BullMQ test harness)
- `no-show.integration.spec.ts`
- `pending-charge-collection.integration.spec.ts` (covers wallet-rich and wallet-empty cases plus the carry-forward path)
- `legacy-v1.contract.spec.ts` (parity of v1 behavior with v2 internals through the shim)
