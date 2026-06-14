# Contract: Notification Triggers (internal, no HTTP)

**Feature**: 007-app-ux-improvements
**Module**: `rideshare-backend/src/modules/notifications/notifications.service.ts`
**Audience**: other backend modules (`BookingsModule`, `TripsModule`)

These are **internal service-method contracts** that the feature introduces
or sharpens. They do not expose HTTP endpoints — they are invoked by other
modules on business events. Captured here because the mapping of "which
event goes to which recipient" is a locked specification decision
(clarification #2).

---

## Method: `notifyDriverOfNewBooking(bookingId: string): Promise<void>`

**Caller**: `BookingsService.create(...)` after a successful booking
insert.

**Behavior**:

1. Load the booking, its trip, and the trip's driver `userId`.
2. Build a data payload:
   ```json
   {
     "type": "booking_created",
     "screen": "trip_details",
     "entityId": "<tripId>",
     "bookingId": "<bookingId>"
   }
   ```
3. Build a localized notification title/body using existing i18n keys
   (add if missing): `notifications.booking_created.title`,
   `.body`.
4. Resolve recipient's active `DeviceToken` rows.
5. Dispatch synchronously via the existing Firebase Admin path + the
   WebSocket gateway (foreground in-app).
6. Emit a structured dispatch log.

**Failure**: any Firebase-admin failure is caught and logged at `warn`. It
MUST NOT fail the calling `BookingsService.create(...)` request; the
booking is the user's primary intent.

---

## Method: `notifyPassengerOfBookingDecision(bookingId, decision): Promise<void>`

`decision ∈ { 'confirmed' | 'rejected' | 'canceled' }`.

**Caller**: `BookingsService.confirm / reject / cancel` methods (or the
equivalent — confirm actual method names at implementation time).

**Behavior**: as above, addressed to `booking.passengerId`. Data payload:

```json
{
  "type": "booking_<decision>",
  "screen": "booking_details",
  "entityId": "<bookingId>"
}
```

Failure handling: identical (logged, not thrown).

---

## Method: `notifyDriverOfBookingCancellation(bookingId): Promise<void>`

**Caller**: `BookingsService.cancel(...)` when the **passenger** is the
actor canceling (FR-010, last branch). Addresses the trip's driver.

Data payload:

```json
{
  "type": "booking_canceled_by_passenger",
  "screen": "trip_details",
  "entityId": "<tripId>"
}
```

---

## Method: `enqueueCityFanout(tripId: string): Promise<void>`

**Caller**: `TripsService.create(...)` after a successful trip insert.

**Behavior**:

1. Enqueue a Bull job `new-trip-fanout` with payload `{ tripId }` (R1 —
   async for large audiences).
2. Return immediately — does NOT block the request.

**Bull worker**:

1. Load trip, extract origin city (from `fromAddress` / city-parse from
   `fromName`, or a dedicated `originCity` field if introduced).
   - **Note**: the survey shows `Trip` has `fromName`, `fromAddress`,
     `fromPoint`, but no explicit city column. Implementation decision:
     compute origin-city via an existing helper (`LocationService`
     mentioned in the survey) or add a persisted `originCity` column on
     `Trip` in a sibling migration. This is an implementation-detail
     choice, not a spec decision — document the chosen approach in the
     PR.
2. Query recipients: `SELECT id FROM users WHERE LOWER(city) = LOWER(:originCity) AND isActive = true AND id <> :posterId` (exclude the poster themselves).
3. For each recipient, resolve active `DeviceToken`s.
4. Batch-dispatch via Firebase Admin (multicast). Break into batches of
   500 tokens (Firebase admin limit).
5. Update any `DeviceToken` rows that Firebase reports as `unregistered`
   or `invalid-argument` to `isActive = false` (FR-014).
6. Emit a single structured dispatch log with aggregate counts
   (`recipientUserCount`, `deviceCount`, `successCount`, `failureCount`,
   `correlationId`).

Data payload per recipient:

```json
{
  "type": "new_trip_posted",
  "screen": "trip_details",
  "entityId": "<tripId>"
}
```

---

## Contract tests

Location: `rideshare-backend/test/notifications/triggers.spec.ts`.

1. **New booking fires driver notification** — mock Firebase admin; call
   `BookingsService.create` and assert `sendEachForMulticast` (or
   equivalent) is invoked with exactly the driver's active tokens.
2. **Booking confirm fires passenger notification** — same pattern.
3. **Passenger cancellation fires driver notification** — same pattern.
4. **`enqueueCityFanout` enqueues a Bull job** — assert queue received
   the payload.
5. **Fan-out worker** — seed 3 users with `city='Amman'`, 2 with
   `city='Irbid'`, 1 with `city='AMMAN'` (case test), and the poster with
   `city='Amman'`. Run the worker for an `Amman` trip. Assert notifications
   go to exactly the 4 `Amman` users minus the poster = 3 recipients.
6. **Fan-out handles Firebase unregistered response** — mock Firebase
   returning `messaging/registration-token-not-registered` for one token;
   assert the corresponding `DeviceToken.isActive` is now `false`.
7. **Dispatch failures do NOT throw into the caller** — force Firebase to
   throw; assert `BookingsService.create` still resolves.

---

## Observability contract

Every dispatch MUST produce one structured log line at `info` with at
least the fields:

```json
{
  "event": "notification.dispatch",
  "trigger": "booking_created" | "booking_confirmed" | …,
  "correlationId": "<uuid>",
  "recipientUserCount": N,
  "deviceCount": N,
  "successCount": N,
  "failureCount": N,
  "durationMs": N
}
```

City fan-out also emits one audit-sink entry
(`action='notification.city_fanout'`, `tripId`, `originCity`, aggregate
counts). Individual per-recipient sends do NOT go to the audit sink — only
the aggregate does, to avoid audit-log floods.
