# Phase 1 — Data Model

**Date**: 2026-04-27
**Branch**: `008-platform-completion`

This document is the authoritative entity catalogue for the platform-completion feature. Each entity carries fields, relationships, indexes, state transitions (where applicable), and a migration note. Existing entities are listed only when this feature modifies them.

## Conventions

- Identifiers are `uuid` unless stated.
- All tables carry `createdAt` and `updatedAt` (`timestamptz`) unless explicitly noted.
- Snake-case is used here for clarity but the actual ORM mapping retains the project's existing camelCase column-name pattern where the column is referenced by other modules.
- "M:1 → User (driverId)" means many records per user via the `driverId` foreign key.
- Migrations are sequenced as `008.NN-<branch>__<description>` in `rideshare-backend/src/database/migrations/`.

---

## Modified Entities

### User (`users`) — extended
- `bannedAt: timestamptz | null`
- `banReason: text | null`
- `restricted: boolean DEFAULT false` — set by fake-account heuristics; admin clears via dashboard.
- `hidePhoneNumber: boolean DEFAULT false`
- `lastSocialLoginAt: timestamptz | null` — set on legacy social sign-in for the migration window only; null after phone-link migration completes.
- `pendingPhoneLink: boolean DEFAULT false` — true when a legacy social-only account hits the migration step but has not yet linked a phone.
- Constraint: an account where both `restricted=true` and `bannedAt IS NOT NULL` is treated as banned (ban supersedes restricted in UI).
- Migration: additive; backfill `restricted=false`, `hidePhoneNumber=false`, `pendingPhoneLink` set true for existing users with a social-login `provider` field but no `phoneNumber`.

### Trip (`trips`) — extended
- `status: enum` extended with values `draft`, `published`, `fully_booked`, `in_progress` (in addition to existing `cancelled`, `completed`). Existing `active` rows are migrated to `published`. Existing `hidden` is renamed to `draft` (semantics differ slightly but no current `hidden` rows expected — confirmed by audit).
- `stops: jsonb DEFAULT '[]'` — array of `{ name, address, lat, lng, order, note? }`.
- `notes: text | null`
- `recurrenceRuleId: uuid | null` (FK → `trip_recurrence_rules.id`, nullable, ON DELETE SET NULL)
- `tripStartedAt: timestamptz | null`
- `tripCompletedAt: timestamptz | null`
- `noShowMarkedAt: timestamptz | null` — when driver no-show was determined by the detector job.
- `lastDriverLocationLat: numeric(10,7) | null` — denormalized for fast share-link reads.
- `lastDriverLocationLng: numeric(10,7) | null`
- `lastDriverLocationAt: timestamptz | null`
- Migration: additive enum extension; `active → published` backfill UPDATE; new columns nullable.

### Booking (`bookings`) — restructured for multi-seat
- Drops unique index `idx_bookings_user_trip` (a user can now have multiple seats per trip via companions in *one* booking — but if they want a separate booking later, that should also be allowed; the unique constraint is no longer correct).
- Removes column `seatNumber` (data moved to `BookingSeat`). Backfill: for each existing row, create one `BookingSeat` with `seatNumber` from the old column and `isMainBooker=true`, `displayName=user.fullName`, `gender=user.gender`.
- `status: enum` switches from `varchar` to a real enum with values: `pending`, `confirmed`, `cancelled`, `rejected`, `in_progress`, `completed`, `no_show`. Backfill maps existing string values 1-1.
- `seatCount: int` (computed on insert; equal to `BookingSeat.count`). Stored for convenience and for fast price calc.
- `totalAmount: numeric(10,2)` — sum of `seatPriceAtBooking * seatCount`.
- `settledAt: timestamptz | null` — set when driver presses "Mark paid".
- `settlementGraceUntil: timestamptz | null` — `settledAt + 5 minutes`; after this, settlement is irreversible without admin intervention.
- `passengerPresenceConfirmedAt: timestamptz | null` — passenger answered "yes, driver is here".
- `driverConfirmedPassengerAt: timestamptz | null` — driver confirmed this passenger present.
- `driverMarkedAbsentAt: timestamptz | null` — driver said "no-show" for this booking.
- Migration: child table created with backfill before any old code reads the new shape; `seatNumber` column kept for one release and read by the v1 endpoint shim.

### Vehicle (`vehicles`) — light touch
- No schema change. Documentation/fixture update: `seatLayout` jsonb is the source of truth, copied into Trip on creation. Already covered by existing code.

### Wallet (existing `wallet_*` tables) — light touch
- No schema change. New transaction subtype: `ADJUSTMENT` of direction `DEBIT` is the carrier for pending-charge auto-deduction (existing enum value reused). Reference field links back to the `pending_charges.id` via `metadata.pendingChargeId` (existing JSON column).

---

## New Entities

### UserDevice (`user_devices`)
- `id: uuid`
- `userId: uuid` (FK → `users.id` ON DELETE CASCADE)
- `fingerprintHash: varchar(64)` — SHA-256 hex, see R-004
- `platform: enum('ios','android','web')`
- `fcmToken: text | null` — overrides the existing `device_tokens` table; this entity supersedes it. Migration moves rows.
- `firstSeenAt: timestamptz`
- `lastSeenAt: timestamptz`
- `isTrusted: boolean DEFAULT true`
- `revokedAt: timestamptz | null`
- `revokedByAdminId: uuid | null`
- Indexes: `(userId)`, `(fingerprintHash, createdAt)` for the multi-account heuristic.
- Migration `008.01-auth-hardening__create-user-devices`: additive; ports rows from existing `device_tokens` keeping the same FCM tokens.

### AccountFlag (`account_flags`)
- `id: uuid`
- `userId: uuid` (FK → `users.id` CASCADE)
- `reason: enum('multi_account_device','multi_account_ip','geo_mismatch','mock_location','manual')`
- `severity: enum('low','medium','high','critical')`
- `payload: jsonb` — context (which device hash, how many accounts, etc.)
- `disposition: enum('open','cleared','restricted','banned') DEFAULT 'open'`
- `dispositionByAdminId: uuid | null`
- `dispositionAt: timestamptz | null`
- Index: `(disposition, severity, createdAt)` for admin queue ordering.

### SecurityEvent (`security_events`)
- `id: uuid`
- `userId: uuid | null` — null when the event is pre-authenticated.
- `eventType: enum('mock_location_rejected','new_device_login','revoked_device_attempt','otp_rate_limit_hit')`
- `payload: jsonb`
- `requestId: varchar(64)` — propagated from the request log for correlation.
- `createdAt: timestamptz`
- No `updatedAt` — append-only.
- Index: `(userId, createdAt)`, `(eventType, createdAt)`.

### BookingSeat (`booking_seats`)
- `id: uuid`
- `bookingId: uuid` (FK → `bookings.id` CASCADE)
- `seatNumber: varchar(8)` — matches the seat-layout coordinate string (e.g., `2A`).
- `displayName: varchar(120)`
- `gender: enum('male','female','unspecified')`
- `isMainBooker: boolean`
- `presenceConfirmedAt: timestamptz | null` — driver-confirmed-present at the per-seat level (allows partial no-show within one booking).
- `markedAbsentAt: timestamptz | null`
- Constraints:
  - Unique `(bookingId, seatNumber)`
  - Exactly one row per booking has `isMainBooker = true` (enforced by partial unique index).
  - At least one row per booking (enforced at the application layer via transaction).
- Indexes: `(bookingId)`, `(seatNumber)` for trip-wide seat lookups.

### PendingCharge (`pending_charges`)
- `id: uuid`
- `userId: uuid` (FK → `users.id` CASCADE)
- `bookingId: uuid | null` (FK → `bookings.id` SET NULL — the originating booking; null if waived after booking-deletion edge case)
- `tripId: uuid | null` (FK → `trips.id` SET NULL)
- `kind: enum('passenger_cancellation','passenger_no_show','driver_no_show')`
- `amount: numeric(10,2)`
- `currency: varchar(5)` — copied from trip
- `status: enum('pending','applied','waived')`
- `walletTransactionId: uuid | null` — set when auto-deducted from wallet; FK → `wallet_transactions`.
- `appliedToBookingId: uuid | null` — set when carry-forward collected on a later booking; FK → `bookings.id` SET NULL.
- `waivedByAdminId: uuid | null`
- `waivedAt: timestamptz | null`
- `note: text | null`
- Indexes: `(userId, status)` for the carry-forward lookup, `(status, createdAt)` for the admin queue.

### TripRecurrenceRule (`trip_recurrence_rules`)
- `id: uuid`
- `driverId: uuid` (FK → `users.id` CASCADE)
- `templateJson: jsonb` — frozen copy of the trip-creation payload (origin, destination, time-of-day, price, etc.).
- `frequency: enum('daily','weekly')`
- `weekdayMask: smallint` — bitmask Sun=1, Mon=2, …, Sat=64 (only meaningful when `frequency='weekly'`).
- `localTime: time` — the time-of-day to schedule.
- `timezone: varchar(40) DEFAULT 'Asia/Amman'`
- `until: date | null`
- `lastSpawnedFor: date | null` — last date the spawner generated.
- `isActive: boolean DEFAULT true`
- Indexes: `(driverId, isActive)`, `(isActive, lastSpawnedFor)` for the spawner sweep.
- State: a rule is `active` until either `until` is reached or the driver toggles `isActive` off.

### TripShareLink (`trip_share_links`)
- `id: uuid`
- `tripId: uuid` (FK → `trips.id` CASCADE)
- `token: varchar(64)` UNIQUE — opaque hex.
- `createdByUserId: uuid` (FK → `users.id` CASCADE) — must be a confirmed passenger.
- `expiresAt: timestamptz` — set to `trip.departureTime + 6 hours` at creation; refreshed by the trip-completed handler to `tripCompletedAt + 30 minutes` so viewers can see "trip ended" briefly.
- `viewCount: int DEFAULT 0`
- `lastViewedAt: timestamptz | null`
- Index: unique on `token` (already implied), `(tripId)`.

### CallSession (`call_sessions`)
- `id: uuid`
- `bookingId: uuid` (FK → `bookings.id` CASCADE)
- `initiatorUserId: uuid` (FK → `users.id`)
- `recipientUserId: uuid` (FK → `users.id`)
- `proxyNumberE164: varchar(20)` — Twilio number bridging the two real numbers.
- `realCallerNumberE164: varchar(20)` — the real number of `initiatorUserId` (NOT shown to recipient if either side has `hidePhoneNumber`).
- `realRecipientNumberE164: varchar(20)`
- `startedAt: timestamptz`
- `endedAt: timestamptz | null`
- `durationSeconds: int | null`
- `terminationReason: enum('completed','no_answer','busy','failed','expired') | null`
- Index: `(bookingId, startedAt)` for the per-booking call history.

### Complaint (`complaints`)
- `id: uuid`
- `reporterId: uuid` (FK → `users.id` CASCADE)
- `againstUserId: uuid | null` (FK → `users.id` SET NULL)
- `tripId: uuid | null` (FK → `trips.id` SET NULL)
- `bookingId: uuid | null` (FK → `bookings.id` SET NULL)
- `category: enum('safety','rude_behavior','no_show','payment','vehicle_condition','other')`
- `body: text`
- `status: enum('open','in_review','resolved','rejected') DEFAULT 'open'`
- `adminNotes: text | null`
- `resolvedByAdminId: uuid | null`
- `resolvedAt: timestamptz | null`
- Indexes: `(status, createdAt)`, `(againstUserId)`, `(reporterId)`.

### RefundRequest (`refund_requests`)
- `id: uuid`
- `userId: uuid` (FK → `users.id` CASCADE)
- `bookingId: uuid | null` (FK → `bookings.id` SET NULL)
- `amount: numeric(10,2) | null`
- `currency: varchar(5) DEFAULT 'JOD'`
- `reason: text`
- `status: enum('open','contacted','resolved','rejected') DEFAULT 'open'`
- `whatsappContactedAt: timestamptz | null`
- `resolvedByAdminId: uuid | null`
- `resolvedAt: timestamptz | null`
- Index: `(status, createdAt)`.

### SettlementAudit (`settlement_audits`)
- `id: uuid`
- `bookingId: uuid` (FK → `bookings.id` CASCADE)
- `actorUserId: uuid` — driver who marked paid, or admin who reverted.
- `action: enum('mark_paid','unmark_paid','admin_revert')`
- `reason: text | null`
- `createdAt: timestamptz`
- Append-only. Index: `(bookingId, createdAt)`.

---

## State Transitions

### Booking
```
                       ┌──────────────┐
                       │   Pending    │
                       └──────┬───────┘
                              │
        ─────────────┬────────┼────────┬─────────────
        │            │        │        │             │
   driver-accept  driver-rej  3h-up  passenger-cancel
        │            │        │        │
        ▼            ▼        ▼        ▼
   Confirmed     Rejected  Cancelled  Cancelled
        │
        ├── trip-time approaches ──▶ pre-trip prompts
        │
        ├── driver Start Trip + per-seat presence ──▶ In Progress
        │                                         (or seats marked absent)
        │
        └── trip Cancelled by counterparty ──▶ Cancelled

   In Progress ──▶ Completed (if all seats present)
   In Progress ──▶ Completed AND seat-level No-Show recorded for absent seats
   Pending     ──▶ Cancelled (3h timeout — auto)
   Confirmed   ──▶ Cancelled (passenger > 12h before / driver > 24h before)
   Confirmed   ──▶ No-Show (driver-side, when trip is driver-no-show)
```

### Trip
```
   Draft ──▶ Published ──▶ Fully Booked
                │              │
                └──────┬───────┘
                       │
                  driver Start Trip
                       │
                       ▼
                  In Progress ──▶ Completed
                       │
                       └──▶ Cancelled (any pre-completion state can go to Cancelled)
                       └──▶ Driver No-Show (declared by detector job at departure+30m)
```

### PendingCharge
```
   created ──▶ try wallet auto-deduct
                       │
              ┌────────┴─────────┐
         success            insufficient
              │                  │
              ▼                  ▼
          applied             pending
                                 │
              ┌──────────────────┼─────────────────┐
              │                  │                 │
       next booking      admin waive       (still pending)
              │                  │
              ▼                  ▼
          applied             waived
```

### UserDevice trust
```
   created (trusted=true) ──▶ revoked-by-admin
                       │           │
                       ▼           ▼
                   in use    sessions reject token
```

---

## Validation rules (server-enforced, mirrored by client UX)

- **Phone E.164** — required, normalized at OTP send and at every PII-linkage point.
- **OTP** — 6 numeric digits, 5-minute TTL, max 5 verify attempts per session, 60-second cooldown between sends to the same number (existing).
- **Driver photo** — non-null `users.photoUrl` is a precondition of `users.isDriverApproved=true` and of any trip insert.
- **Booking seats array** — 1 ≤ length ≤ `trip.availableSeats`. Each seat must be a free seat in `trip.seats[*]`. If `trip.preventGenderMixing` is true, no two adjacent occupied seats may have differing `gender` (counting seats just bound by this booking plus seats already booked).
- **Cancellation windows** — driver: `trip.departureTime - now > 24h`; passenger: `trip.departureTime - now > 12h`. Server compares in UTC.
- **Settlement reversal** — `now < booking.settlementGraceUntil` AND no `chat_messages` exist for the booking AND no `call_sessions` exist for the booking.
- **Share-link issuance** — only by a user whose booking on the trip is `confirmed` and whose trip is `published` or `in_progress`.
- **Mocked location** — any driver-authenticated location-bearing endpoint with `isMockLocation=true` is rejected with `403 LOCATION_INTEGRITY_VIOLATION` and writes a `security_events` row.
- **Recurrence guard** — when the spawner would create a trip whose `(driverId, departureTime)` already exists, it skips and writes a `recurrence_skip` log entry but does not fail the rule.

## Index summary (new indexes only)

| Table | Index | Purpose |
|---|---|---|
| `user_devices` | `(userId)` | session lookup |
| `user_devices` | `(fingerprintHash, createdAt)` | multi-account heuristic |
| `account_flags` | `(disposition, severity, createdAt)` | admin queue order |
| `security_events` | `(userId, createdAt)` | per-user audit |
| `security_events` | `(eventType, createdAt)` | event-type forensics |
| `booking_seats` | `(bookingId)` | parent → children |
| `booking_seats` | `(seatNumber)` | trip-wide seat lookup (rarely used; consider dropping after measurement) |
| `pending_charges` | `(userId, status)` | carry-forward lookup at booking time |
| `pending_charges` | `(status, createdAt)` | admin outstanding-charges page |
| `trip_recurrence_rules` | `(driverId, isActive)` | driver's recurrence list |
| `trip_recurrence_rules` | `(isActive, lastSpawnedFor)` | spawner sweep |
| `trip_share_links` | unique `(token)` | public lookup |
| `trip_share_links` | `(tripId)` | per-trip listing |
| `call_sessions` | `(bookingId, startedAt)` | call history per booking |
| `complaints` | `(status, createdAt)` | admin queue |
| `complaints` | `(againstUserId)` | "complaints against me" lookup |
| `refund_requests` | `(status, createdAt)` | admin queue |
| `settlement_audits` | `(bookingId, createdAt)` | per-booking audit |

## Migration order (per branch)

1. **`009-auth-hardening`**:
   - 008.01 create `user_devices`, `account_flags`, `security_events`; add `users.banned*`, `users.restricted`, `users.hidePhoneNumber`, `users.pendingPhoneLink`.
2. **`010-booking-lifecycle`**:
   - 008.02 create `booking_seats`, backfill from `bookings.seatNumber`, drop unique index `idx_bookings_user_trip`.
   - 008.03 add `bookings.seatCount`, `bookings.totalAmount`, `bookings.settledAt`, `bookings.settlementGraceUntil`, `bookings.passengerPresenceConfirmedAt`, `bookings.driverConfirmedPassengerAt`, `bookings.driverMarkedAbsentAt`.
   - 008.04 alter `bookings.status` to enum; backfill values.
   - 008.05 create `pending_charges`.
3. **`011-trip-time-flow`**:
   - 008.06 alter `trips.status` enum: add new values; add `trips.tripStartedAt`, `tripCompletedAt`, `noShowMarkedAt`, `lastDriverLocationLat/Lng/At`.
   - 008.07 create `trip_share_links`.
4. **`012-trip-authoring`**:
   - 008.08 create `trip_recurrence_rules`; add `trips.recurrenceRuleId`, `trips.stops`, `trips.notes`.
5. **`013-settle-and-call`**:
   - 008.09 create `call_sessions`, `settlement_audits`.
6. **`014-admin-and-support`**:
   - 008.10 create `complaints`, `refund_requests`.

All migrations are written additive-safe per the constitution governance section: new columns are nullable on creation; backfills run after the new column exists; tightening to NOT NULL (where applicable, e.g., `bookings.totalAmount`) happens in a follow-up migration after one deploy cycle.
