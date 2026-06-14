# Contract — Settlement, Data Reveal & Calls (Phase 5: `013-settle-and-call`)

## Settlement

### POST `/bookings/:id/mark-paid` *(driver)*
Effects:
- `booking.settledAt = now`
- `booking.settlementGraceUntil = now + 5min`
- Insert `settlement_audits` row with `action='mark_paid'`.
- Notify passenger ("driver confirmed cash payment").
- After this point, the booking-detail response unmasks contact details and `chat_enabled`/`call_enabled` flip to true for both parties.

Errors: `409 ALREADY_SETTLED`, `403 NOT_TRIP_DRIVER`, `409 BOOKING_NOT_CONFIRMED`.

### POST `/bookings/:id/unmark-paid` *(driver, within grace)*
Preconditions: `now < booking.settlementGraceUntil` AND no chat messages exist for the booking AND no call sessions exist. Reverts `settledAt`, `settlementGraceUntil`. Inserts `settlement_audits` row with `action='unmark_paid'`. Errors: `409 GRACE_EXPIRED`, `409 CONTACT_ALREADY_USED`.

### POST `/admin/bookings/:id/admin-revert-settlement`
Admin override — reverses `settledAt` outside grace. Body: `{ reason }`. Always succeeds (idempotent). Inserts `settlement_audits` row with `action='admin_revert'`.

## Data reveal — middleware applied to ALL booking-bearing serializers

Conceptually a `BookingViewerSerializer` reads `(booking.settledAt IS NOT NULL)` and applies:
- If unsettled: passenger fields `displayName, phone, photoUrl` are masked; driver fields `phone` is masked; chat/call disabled flags returned.
- If settled: full reveal.

Affected serializers (verified during contract testing): trip detail, my-trips list, my-bookings list, chat preview, notifications payload, admin views (admin sees raw values regardless).

## Calls

### POST `/bookings/:id/calls/initiate` *(authenticated; settled bookings only)*
Body: `{ from: 'self' }` (placeholder; reserved for future "call group" expansion).
Preconditions:
- Booking is settled.
- Caller is either the booking's main booker or the trip driver.
Effects:
- Allocate or reuse a Twilio proxy number from the pool.
- Create a `call_sessions` row.
- Configure the Twilio TwiML route to bridge caller's real number → recipient's real number.
Response:
```json
{ "callSessionId": "...", "proxyNumberE164": "+962790000001", "expiresAt": "..." }
```
The mobile app dials `proxyNumberE164` via the system dialer.

Errors:
- `403 BOOKING_NOT_SETTLED`
- `503 NO_PROXY_NUMBERS_AVAILABLE` — alert ops; this should only happen if the pool is exhausted.

### POST `/calls/twilio-webhook` *(public, signed)*
Twilio status callback. Updates `call_sessions.endedAt`, `durationSeconds`, `terminationReason`. Validates Twilio signature header.

### GET `/bookings/:id/calls`
List `call_sessions` for a booking (the caller must be a participant). Response includes neither real number when the other party has `hidePhoneNumber=true`.

## User profile

### PATCH `/me`
Adds optional `hidePhoneNumber: boolean`. Stored on `users.hidePhoneNumber`. Effect propagates immediately to subsequent serializer responses.

## Chat gating

The existing `/chat/...` endpoints and the WebSocket gateway gain a precondition: the underlying booking (1-1 chat) or trip with at least one settled booking on it (group chat) must be settled. Otherwise `403 BOOKING_NOT_SETTLED` for REST, and the WebSocket connection is closed with code `4403` (custom).

## Contract tests

- `mark-paid.contract.spec.ts` (happy + double-mark error)
- `unmark-paid.contract.spec.ts` (within grace, after grace, after contact)
- `admin-revert.contract.spec.ts`
- `viewer-mask.contract.spec.ts` (sweeps the affected serializers and asserts pre/post settlement shapes)
- `calls-initiate.contract.spec.ts` (proxy allocation, exhausted pool, hide-phone preference)
- `calls-twilio-webhook.contract.spec.ts` (signature validation, status update)
- `chat-gating.contract.spec.ts` (REST + WS)
