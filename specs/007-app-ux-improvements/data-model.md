# Data Model: App UX Improvements

**Feature**: 007-app-ux-improvements
**Date**: 2026-04-23

Scope: only the entities that this feature adds, extends, or depends on as
invariants. All pre-existing entities not listed here remain unchanged.

---

## 1. `User` (existing entity — extended)

**File**: `rideshare-backend/src/database/entities/user.entity.ts`

**Change in this feature**: add a single column.

| Field | Type | Nullable | Notes |
|-------|------|----------|-------|
| `city` | `varchar(64)` | YES | User's declared current city. Set during onboarding (future flow) or from settings. Trimmed on write. Case-insensitive equality used for fan-out queries. Not exposed via admin serializer unless product approves. |

**Migration strategy** (constitution Governance — Migrations):

1. Migration adds `city` as nullable (`ALTER TABLE users ADD COLUMN city varchar(64) NULL`).
2. No backfill in this feature — existing users have `city = NULL` until they
   set it. They are simply excluded from city fan-out until they do.
3. A follow-up release MAY tighten to `NOT NULL` once onboarding is updated
   and a backfill path exists. That tightening is out of scope here.

**Invariants**:

- `city` IS NULL OR `LENGTH(TRIM(city)) > 0` — empty strings are normalized
  to NULL on write.
- `fcmToken` (existing column) — MUST NOT appear in any API response or
  admin serializer (R7).

**Queries introduced by this feature**:

- `SELECT id FROM users WHERE LOWER(city) = LOWER(:target) AND isActive = true`
  — drives the city fan-out audience. Index: add
  `CREATE INDEX idx_users_lower_city ON users (LOWER(city)) WHERE isActive = true`
  as part of the migration. (Partial + functional index — verify Postgres
  version supports; the repo uses Postgres so this is available.)

---

## 2. `DeviceToken` (existing entity — confirmed, no schema change)

**File**: `rideshare-backend/src/database/entities/device-token.entity.ts`

Fields confirmed by survey: `userId`, `token`, `platform` (enum: android/ios),
`isActive`, `lastSeenAt`. No change in this feature.

**Invariants** (documented here; may already be enforced by existing code —
confirm during implementation):

- `token` is globally unique (`UNIQUE(token)`). If an existing row has the
  same `token` attached to a different `userId` (happens when a device is
  handed off), the existing row's `userId` MUST be updated to the new
  user, and `isActive` re-set to `true`. The old user loses that device.
- One user MAY have many `isActive = true` rows — multi-device delivery is
  the defined semantics (spec FR-008, clarification #5).
- A row MUST be set `isActive = false` (not deleted) when:
  - The user signs out on that device.
  - Firebase Admin reports the token as unregistered (FR-014).
  - The `lastSeenAt` falls outside a reasonable window (janitor policy,
    already handled by existing `notification-cleanup` Bull job — confirm).
- `token` is NEVER serialized to any API response, user-facing or admin
  (R7).

**Lifecycle state transitions**:

```
[ABSENT] ──POST /notifications/devices──▶ [ACTIVE]
[ACTIVE] ──DELETE /notifications/devices/{token}──▶ [INACTIVE]
[ACTIVE] ──FCM reports unregistered──▶ [INACTIVE]
[INACTIVE] ──POST /notifications/devices (same token, user signs back in)──▶ [ACTIVE]
```

---

## 3. `Notification` (existing entity — no change)

No schema change. Usage expanded: the feature adds new triggers that call
the existing `NotificationsService.create(...)` path for per-user targets and
a new `NotificationsService.enqueueCityFanout(...)` path for city broadcasts.

---

## 4. `NotificationTrigger` (conceptual, not persisted)

Not a DB entity. Documents the authoritative mapping between business events
and the `NotificationsService` method that handles them. Enforced by code
review, not by schema.

| Event (source module) | Recipient (clarification) | Service method |
|---|---|---|
| Booking created (`BookingsService`) | Driver who posted the trip | `notifyDriverOfNewBooking(bookingId)` |
| Booking confirmed (`BookingsService`) | Passenger who booked | `notifyPassengerOfBookingDecision(bookingId, 'confirmed')` |
| Booking rejected (`BookingsService`) | Passenger who booked | `notifyPassengerOfBookingDecision(bookingId, 'rejected')` |
| Booking canceled by driver (`BookingsService`) | Passenger who booked | `notifyPassengerOfBookingDecision(bookingId, 'canceled')` |
| Booking canceled by passenger (`BookingsService`) | Driver who posted the trip | `notifyDriverOfBookingCancellation(bookingId)` |
| Trip posted (`TripsService`) | Users whose `city` matches trip origin | `enqueueCityFanout(tripId)` (async) |

Each method MUST:

- Deliver to all `isActive = true` device tokens for the target user(s).
- Embed a `data` payload with a deep-link descriptor (R3 in contracts):
  `{ type, screen, entityId }`.
- Emit a structured dispatch log entry: `trigger`, `recipientUserIds[]`,
  `deviceCount`, `successCount`, `failureCount`, `correlationId`.
- Honor constitution Principle IV: no PII in the notification body beyond
  what's already displayed in the target screen.

---

## 5. `Failure` (Flutter, not persisted)

**File**: `rideshare/lib/core/errors/failure.dart` (NEW)

Not a DB entity — a Dart value type. Captured here for planning completeness
because it is the contract between the mapper and the UI surface.

```text
Failure
  ├─ category:   FailureCategory enum
  │   (network | server | validation | auth | permission | unknown)
  ├─ messageKey: String   (localization key in app_ar.arb / app_en.arb)
  ├─ messageArgs: List<String>?
  ├─ severity:   FailureSeverity enum (info | warning | error)
  ├─ nextAction: FailureAction?   (null | reauthenticate | openSettings | retry)
  └─ developerDetail: String   (original exception class + message — never shown to user)
```

**Invariants**:

- `messageKey` MUST be a key that exists in both `app_ar.arb` and
  `app_en.arb`. Missing keys are a CI failure (add a lint / test).
- `developerDetail` MUST be populated. A `Failure` with empty
  `developerDetail` and `category == unknown` is rejected by the mapper.
- A `Failure` is never rendered as-is — it always flows through
  `error_surface.showFailure(...)` or the BLoC error state.

---

## Relationships summary

```
User (1) ──< DeviceToken (n)
  │
  │ city ── used to compute audience for ──
  │
  └──> NotificationTrigger (new trip posted) ──fan-out──> Notification (n) ──> DeviceToken (n)
```

No new user-to-user or trip-to-trip relationships are introduced.
