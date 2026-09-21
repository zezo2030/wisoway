# Backend Rebuild Spec — 02: Scheduled Trips & Bookings

Source of truth: `d:\work\wisoway\rideshare-backend\src` @ branch `009-platform-refinements`.
Every statement below is grounded in a file/line reference. Where behaviour is ambiguous or a
path appears unreachable, it is labelled explicitly.

Stack being described: NestJS 11 + TypeORM + PostgreSQL (PostGIS) + Redis/Bull (v3 `@nestjs/bull`,
not BullMQ v4 despite `CLAUDE.md`) + Socket.IO + Firebase push. A reimplementation may use any stack,
but the semantics, constants and wire contracts below are load-bearing.

---

## 1. Domain overview

This domain covers the **scheduled carpool** product: a driver publishes a seated trip from A to B at
a future time; passengers search, pick specific seats, and request them; the driver accepts; at the
departure time the trip auto-starts (there is no "Start Trip" button); the driver is charged a single
platform fee at that moment; live location/ETA is streamed while in progress; both sides confirm who
was actually in the vehicle; and the driver marks arrival (or a 24 h fallback job completes the trip).

Out of scope for this document (other domains): instant/on-demand rides (`tripType='instant'`),
wallet/ledger internals, chat, calls, ratings, admin dashboard, auth.

### 1.1 Key design facts (get these wrong and nothing else fits)

1. **Passengers pay no platform fee and no money moves through the app for them.**
   `PlatformPricingService.passengerSeatPricing` hard-returns `platformAmount: 0`,
   `driverAmount = seatPrice`, `requiresOnlinePayment: false`
   (`src/modules/payments/platform-pricing.service.ts:44-62`). The full seat price is cash on meet-up.
2. **The driver pays exactly one platform fee per trip, charged at trip start**, computed on
   `seatPrice x totalSeats x driverUnlockPercent%` — *not* on booked or present seats
   (`src/modules/driver-trip-fee/driver-trip-fee.service.ts:93-111`).
3. **Contact (chat/call/passenger identity) is NOT gated by payment any more.** `hasDriverPaidToContact`
   is now only an audit stamp, and two response paths deliberately force it to `true` for backward
   compatibility with old mobile builds (`bookings.service.ts:503-511`, `:560-575`).
4. **Trip start is automatic**, driven by a delayed Bull job scheduled at publish time
   (`trip-auto-start.util.ts:6-9`, `trips.service.ts:1004-1030`).
5. **Presence confirmation moves no money.** `PresenceService.settleTripPresence` is pure bookkeeping;
   `captured`/`released` are read-back/zero (`presence.service.ts:44-55`, `:497-565`).
6. **Seat state lives in two places**: the denormalised `trips.seats` JSONB array (availability, occupant
   gender) and the `booking_seats` rows (identity, presence, billing overrides). They are kept in sync by
   application code only — no DB constraint links them.

### 1.2 End-to-end happy path

```
DRIVER                                   SYSTEM                                  PASSENGER
------                                   ------                                  ---------
POST /api/v1/trips
  guards: vehicle exists + verified,
  driver approved, profile photo,
  no outstanding charges,
  departureTime > now,
  1 <= availableSeats <= layout seats,
  wallet balance >= expected fee
                                    -> trips row (status=published,
                                       seats[] generated from vehicle layout,
                                       currency from reverse-geocoded country)
                                    -> optional trip_recurrence_rules row
                                    -> enqueue new-trip-fanout (city push)
                                    -> enqueue trip-auto-start @ departureTime
                                                                    GET /api/v1/trips?...        (search)
                                                                    GET /api/v1/trips/nearby      (radius 50 km)
                                                                    GET /api/v1/trips/:id/seats   (seat map)
                                                                    POST /api/v1/v2/bookings
                                                                      { tripId, seats: [{ seatNumber,
                                                                        displayName, gender,
                                                                        isMainBooker }] }
                                    <- pessimistic_write lock on trips row
                                    -> seats[] marked 'booked',
                                       availableSeats -= n
                                    -> bookings row (status=pending,
                                       expiresAt = now + 3 h)
                                    -> booking_seats rows (1 per seat)
                                    -> enqueue bookings-timeout (+3 h)
                                    -> push "new booking" to driver
PATCH /api/v1/v2/bookings/:id/accept
                                    -> booking.status = confirmed
                                    -> remove timeout job
                                    -> push to passenger
                                                                    POST /api/v1/trips/:id/share-link (optional)
   (departure - 60 min)                                             GET  /api/v1/bookings/:id/presence-prompt
                                                                    POST /api/v1/bookings/:id/presence-declare
                                                                      { status: 'in_vehicle' }
   (departure - 30 min)
GET /api/v1/trips/:id/presence-roster
POST /api/v1/trips/:id/presence-confirm
  { entries: [{ bookingId, seatNumber, present }] }

   (departureTime)                  == trip-auto-start job fires ==
                                    -> trip.status = in_progress, tripStartedAt = now
                                    -> confirmed bookings -> in_progress
                                    -> DriverTripFeeService.chargeAtTripStart  (the one debit)
                                    -> push "trip started" to driver + passengers
                                    -> enqueue trip-auto-complete @ departure + 24 h
POST /api/v1/tracking/location  (repeatedly; tracking domain)
                                    -> trips.lastDriverLocation{Lat,Lng,At}
                                    -> every 45 s: Google Directions (OSRM fallback)
                                       -> remainingDistanceKm, remainingDurationSeconds,
                                          etaAt, routeProgressPercent
                                                                    GET /api/v1/tracking/:tripId/latest
                                                                    (anyone) GET /api/v1/share/:token
POST /api/v1/trips/:id/arrived
  { noShowSeats?: [...] }
                                    -> trip.status = completed, tripCompletedAt = now
                                    -> fee reconciliation sweep (if never charged)
                                    -> no-show seats stamped, all-absent bookings -> no_show
                                    -> in_progress bookings -> completed
                                    -> settleTripPresence (bookkeeping)
                                    -> share links expire at now + 30 min
                                    -> remove trip-auto-start / trip-auto-complete jobs
                                    -> push "trip completed" to all passengers
```

---

## 2. Environment variables read by this domain

| Var | Default | Read at | Effect |
|---|---|---|---|
| `API_PREFIX` | `api/v1` | `src/main.ts:47` | Global route prefix. **All paths in this document assume `api/v1`.** No route is excluded from the prefix (the public share endpoint included). |
| `PORT` | `3000` | `main.ts:74` | HTTP port |
| `HOST` | `0.0.0.0` | `main.ts:75` | Bind address |
| `NODE_ENV` | — | `main.ts:26`, `http-exception.filter.ts:33` | Production CORS allowlist; stack traces in 500 bodies |
| `ALLOWED_ORIGINS` | `https://yourdomain.com` | `main.ts:28` | Comma-separated CORS list in production |
| `REDIS_HOST` | `localhost` | `src/jobs/jobs.module.ts:15` | Bull broker |
| `REDIS_PORT` | `6379` | `src/jobs/jobs.module.ts:16` | Bull broker |
| `BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS` | `10800` (3 h) | `bookings.service.ts:764,815` | Driver acceptance window; sets both `bookings.expiresAt` and the Bull job delay |
| `TRIP_AUTO_COMPLETE_FALLBACK_HOURS` | `24` (floored at 1) | `trip-auto-start.util.ts:18-24` | Delay after `departureTime` for forced completion |
| `DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES` | `60` | `driver-trip-fee-reconciliation.job.ts:27,140` | How long past departure before the fee sweep touches an unstamped trip |
| `DRIVER_TRIP_FEE_RECONCILE_LOOKBACK_HOURS` | `72` | same | Oldest departure the sweep will reach back to |
| `DRIVER_TRIP_FEE_RECONCILE_BATCH` | `100` | same | Trips charged per sweep run |
| `JWT_ACCESS_SECRET` | — | `trips.module.ts:33` | Verifies the WS token in `TripsGateway` |
| `JWT_ACCESS_EXPIRES_IN` | `15m` | `trips.module.ts:35` | — |
| `GOOGLE_MAPS_API_KEY` | — | `locations.service.ts:84` | Directions API for live ETA; **absent ⇒ OSRM fallback** |
| `NOMINATIM_BASE_URL` | `https://nominatim.openstreetmap.org` | `.env.example:72` | Reverse geocode of the departure point → country → trip currency |
| `NOMINATIM_USER_AGENT` | `WisowayRideshare/1.0 (...)` | `.env.example:74` | Nominatim politeness header |
| `PHOTON_BASE_URL` | — | `locations.service.ts:89` | Autocomplete provider used by the trip-authoring UI |
| `NO_SHOW_GRACE_OVERRIDE_SECONDS` | documented `1800` | `src/config/configuration.ts:118` | **Declared but unused** — nothing enqueues the `no-show-detector` job (F-23) |
| `PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS` | — | `src/config/configuration.ts:119` | **Declared but unused** — nothing enqueues `pre-trip-confirm` (F-23) |

---

## 3. Cross-cutting request/response conventions

* **Global validation pipe**: `whitelist: true`, `forbidNonWhitelisted: true` (unknown body properties ⇒
  `400`), `transform: true`, `enableImplicitConversion: true` (`main.ts:34-43`). Numeric query params
  therefore coerce from strings automatically.
* **Global guards, in order** (`app.module.ts:112-131`): `JwtAuthGuard` (skipped when the handler carries
  `@Public()`), `BanGuard`, `RolesGuard`, `ThrottlerGuard`. Because `JwtAuthGuard` is global, every
  endpoint here needs `Authorization: Bearer <access token>` unless marked Public.
* **Success envelope** (`TransformInterceptor`): every 2xx body is wrapped as
  `{ "success": true, "data": <handler return value> }`.
* **Error envelope** (`HttpExceptionFilter`):
  ```json
  { "success": false,
    "error": { "code": 400, "message": "...", "details": null,
               "timestamp": "ISO", "path": "/api/v1/...", "method": "POST" } }
  ```
  `error.code` is the **HTTP status number**, not the domain code. Domain codes (e.g.
  `CANCELLATION_WINDOW_CLOSED`) are thrown as an *object* exception body and surface inside
  `error.details` (`http-exception.filter.ts:62-79`). Reimplementations must preserve this shape or the
  mobile clients break.
* **Pagination DTO** (`src/common/dto/pagination.dto.ts`): `page` (int >= 1, default 1), `limit`
  (int 1..100, default 20). Paginated results are
  `{ data: T[], meta: { page, limit, total, totalPages } }`.
* **Roles**: `passenger | driver | admin`. `@Roles('driver')` is enforced by the global `RolesGuard`;
  a missing/mismatched role gives `403 "Access denied. Required roles: driver"`.

---

## 4. Entities / tables

### 4.1 `trips` (`src/database/entities/trip.entity.ts`)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `driverId` | uuid | no | — | FK → `users(id)` `ON DELETE RESTRICT` |
| `driverName` | varchar | yes | — | Denormalised at creation; `null` on recurrence-spawned trips (`recurrence-spawn.processor.ts:160`) |
| `fromName` | varchar(160) | no | — | |
| `fromAddress` | text | yes | — | |
| `toName` | varchar(160) | no | — | |
| `toAddress` | text | yes | — | |
| `fromPoint` | `geography(Point,4326)` | no | — | GeoJSON `{type:'Point',coordinates:[lng,lat]}`; GIST index `trips_from_point_idx` |
| `toPoint` | `geography(Point,4326)` | no | — | GIST index `trips_to_point_idx` |
| `departureTime` | timestamptz | no | — | |
| `price` | numeric(10,2) | no | — | Price **per seat**; a string in TS |
| `currency` | varchar(5) | no | `'JOD'` (initial migration `'EGP'`, migration `1743100000000` re-defaults to JOD) | Derived from departure country at creation |
| `totalSeats` | int | no | `4` | Published seat count (may be < vehicle layout) |
| `availableSeats` | int | no | `4` | Decremented on booking, incremented on release |
| `seatLayout` | jsonb | yes | — | `{rows, seatsPerRow, seatsPerRowList?, preventGenderMixing}` — a per-trip **copy** of the vehicle layout |
| `seats` | jsonb | no | `'[]'` | Array of `{seatNumber,userId,userName,gender,bookedAt,status}` |
| `stops` | jsonb | no | `'[]'` | Up to 5 `{name,address?,lat,lng,order,note?}` |
| `notes` | text | yes | — | Driver free text, <= 2000 chars |
| `status` | enum `trip_status_enum` | no | entity `'published'`, DB default still `'active'` | see §4.6 |
| `tripType` | varchar(16) | no | `'scheduled'` | `scheduled` / `instant`; index `trips_trip_type_idx` |
| `tripStartedAt` | timestamptz | yes | — | Set by the auto-start job |
| `tripCompletedAt` | timestamptz | yes | — | Set by `completeTrip` / auto-complete |
| `noShowMarkedAt` | timestamptz | yes | — | **Never written by any live code path** |
| `lastDriverLocationLat` | float | yes | — | Denormalised from tracking |
| `lastDriverLocationLng` | float | yes | — | |
| `lastDriverLocationAt` | timestamptz | yes | — | |
| `remainingDistanceKm` | double precision | yes | — | Live ETA snapshot |
| `remainingDurationSeconds` | int | yes | — | |
| `etaAt` | timestamptz | yes | — | |
| `routeProgressPercent` | double precision | yes | — | 0–100, one decimal |
| `etaComputedAt` | timestamptz | yes | — | 45 s throttle marker |
| `preTripConfirmSentAt` | timestamptz | yes | — | Idempotency stamp for a job nothing schedules (F-23) |
| `recurrenceRuleId` | uuid | yes | — | FK → `trip_recurrence_rules(id)` `ON DELETE SET NULL` |
| `communicationFeeStatus` | varchar | no | `'not_paid'` | Legacy; set to `'paid'` by `stampTripCharged` |
| `carImageUrl` | text | yes | — | Copied from the vehicle profile at creation |
| `isVisible` | boolean | no | `true` | Search filter |
| `driverWalletChargeApplied` | boolean | no | `false` | Fee idempotency stamp (layer 1) |
| `driverWalletChargeAt` | timestamp | yes | — | |
| `presenceSettledAt` | timestamptz | yes | — | Settlement idempotency stamp |
| `billableSeatCount` | int | yes | — | Frozen at settlement |
| `capturedFeeAmount` | numeric(10,2) | yes | — | Written by `stampTripCharged`, read back by settlement |
| `driverFeeHoldId` | uuid | yes | — | FK → `wallet_holds(id)`; **legacy — holds were removed, never written now** |
| `presenceReviewFlagged` | boolean | no | `false` | Set on presence conflicts or an all-absent roster |
| `createdAt` | timestamptz | no | `now()` | |
| `updatedAt` | timestamptz | no | `now()` | |

Indexes: `trips_driver_idx(driverId)`, `trips_status_departure_idx(status, departureTime)`,
GIST `trips_from_point_idx`, GIST `trips_to_point_idx`, `trips_trip_type_idx(tripType)`,
partial `idx_trips_presence_unsettled(tripCompletedAt) WHERE presenceSettledAt IS NULL AND driverFeeHoldId IS NOT NULL`.

### 4.2 `bookings` (`src/database/entities/booking.entity.ts`)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `tripId` | uuid | no | — | FK → `trips(id)` `ON DELETE CASCADE`; index `idx_bookings_trip` |
| `userId` | uuid | no | — | FK → `users(id)` `ON DELETE CASCADE`; index `idx_bookings_user` |
| `status` | enum `booking_status_enum` | no | `'pending'` | index `idx_bookings_status`; see §4.6 |
| `seatCount` | int | no | `1` | |
| `totalAmount` | decimal(10,2) | **no** (since migration 008.12) | — | `seatCount x seatPriceAtBooking`, `.toFixed(2)` |
| `expiresAt` | timestamp | yes | — | `now + 3 h` at creation; display mirror of the Bull delay |
| `settledAt` | timestamp | yes | — | Legacy settle-and-call; unused here |
| `settlementGraceUntil` | timestamp | yes | — | Legacy; unused here |
| `passengerPresenceConfirmedAt` | timestamp | yes | — | Passenger said driver present / declared `in_vehicle` |
| `driverConfirmedPassengerAt` | timestamp | yes | — | At least one seat confirmed present |
| `driverMarkedAbsentAt` | timestamp | yes | — | **All** seats absent |
| `passengerReportedDriverAbsentAt` | timestamp | yes | — | Driver no-show report |
| `hasDriverPaidToContact` | boolean | no | `false` | Audit stamp only; forced `true` in two response paths |
| `sharePhoneWithDriver` | boolean | no | `false` | |
| `isFamilyBooking` | boolean | no | `false` | Exempts the booking from gender-adjacency rules |
| `cancellationReason` | text | yes | — | |
| `cancelledAt` | timestamp | yes | — | |
| `cancelledBy` | varchar | yes | — | `'passenger' / 'driver' / 'admin' / 'system'` (free-text column, no constraint) |
| `seatPriceAtBooking` | decimal(10,2) | yes | — | |
| `platformAmount` | decimal(10,2) | yes | — | Always `'0'` under current pricing |
| `driverAmount` | decimal(10,2) | yes | — | Equals `seatPriceAtBooking` |
| `passengerPaymentId` | uuid | yes | — | FK → `payments(id)` `ON DELETE SET NULL`; only ever set by the dead v1 `create()` path |
| `createdAt` / `updatedAt` | timestamp | no | `now()` | |

Dropped historically: `seatNumber` (migration 008.11), unique `(userId, tripId)` (migration 008.02).
**There is no DB-level uniqueness preventing two active bookings by the same user on one trip** — only
the application check in the dead `create()` path did that; `createMultiSeat` does **not** re-check
(see F-10 gotchas).

### 4.3 `booking_seats` (`src/database/entities/booking-seat.entity.ts`)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `bookingId` | uuid | no | — | FK → `bookings(id)` `ON DELETE CASCADE` |
| `seatNumber` | varchar(10) | no | — | `"<row>-<col>"`, zero-based |
| `isMainBooker` | boolean | no | `false` | Partial unique `idx_booking_seats_main_booker(bookingId) WHERE isMainBooker` |
| `displayName` | varchar(100) | no | `''` | Companion name typed by the booker |
| `gender` | varchar(10) | no | `''` | `'male' / 'female'` |
| `presenceConfirmedAt` | timestamp | yes | — | Driver said present |
| `markedAbsentAt` | timestamp | yes | — | Driver said absent |
| `passengerSelfConfirmedAt` | timestamptz | yes | — | Passenger declared `in_vehicle` |
| `passengerDeclaredStatus` | varchar(20) | yes | — | CHECK in (`in_vehicle`,`on_my_way`,`not_riding`) |
| `autoFlaggedAbsentAt` | timestamptz | yes | — | Advisory only; never affects billing |
| `absenceReason` | varchar(30) | yes | — | CHECK in (`no_show`,`cancelled_on_site`,`wrong_pickup`,`other`) |
| `billableOverride` | boolean | yes | `NULL` | Three-valued: `null` = default, `false` = driver-absent accepted, `true` = forced billable |
| `presenceDisputedAt` | timestamptz | yes | — | Driver/passenger contradiction |
| `presenceResolvedBy` | uuid | yes | — | FK → `users(id)` `ON DELETE SET NULL` |
| `presenceResolutionNote` | text | yes | — | |
| `presenceUpdatedAt` | timestamptz | yes | — | Last presence write by anyone |
| `createdAt` | timestamp | no | `now()` | |

Indexes: `idx_booking_seats_booking(bookingId)`, unique `idx_booking_seats_seat_number(bookingId, seatNumber)`,
partial unique `idx_booking_seats_main_booker`, `idx_booking_seats_presence(bookingId, billableOverride)`,
partial `idx_booking_seats_disputed(presenceDisputedAt) WHERE presenceDisputedAt IS NOT NULL`.

**Derived property `isBillable`** (`booking-seat.entity.ts:143-147`), used by the roster and settlement:

```
isBillable = (passengerSelfConfirmedAt != null) AND (billableOverride !== false)
```

This contradicts the migration comment that "every accepted seat is billable by default" — the current
code requires explicit passenger self-confirmation. Since settlement no longer moves money the
discrepancy is cosmetic today, but a reimplementation must copy the *code* rule, not the comment.

### 4.4 `trip_recurrence_rules` (`src/database/entities/trip-recurrence-rule.entity.ts`)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `driverId` | uuid | no | — | FK → `users(id)` `ON DELETE CASCADE` |
| `templateJson` | jsonb | no | — | Frozen trip template (see F-08) |
| `frequency` | varchar(10) CHECK in (`daily`,`weekly`) | no | — | Entity declares a TS enum; the DB column is a checked varchar |
| `weekdayMask` | smallint | no | `0` | Bitmask: sun=1, mon=2, tue=4, wed=8, thu=16, fri=32, sat=64 |
| `localTime` | time | no | — | `HH:MM:SS` |
| `timezone` | varchar(40) | no | `'Asia/Amman'` | Stored but **not used** by the spawn maths (F-08 gotchas) |
| `until` | date | yes | — | Inclusive end date |
| `lastSpawnedFor` | date | yes | — | Sweep cursor |
| `isActive` | boolean | no | `true` | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Indexes: `recurrence_rules_driver_active_idx(driverId,isActive)`, `recurrence_rules_spawn_sweep_idx(isActive,lastSpawnedFor)`.

### 4.5 `trip_share_links` (`src/database/entities/trip-share-link.entity.ts`)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `tripId` | uuid | no | — | FK → `trips(id)` `ON DELETE CASCADE` |
| `createdByUserId` | uuid | no | — | FK → `users(id)`; the entity declares `ON DELETE SET NULL` but the migration column is `NOT NULL` — contradictory (verify `src/database/migrations/1745907000000-008.07-trip-time-flow__create-trip-share-links.ts:16-27`) |
| `token` | varchar(64) UNIQUE | no | — | `randomBytes(32).toString('base64url')`, ~43 chars |
| `expiresAt` | timestamptz | no | — | `departureTime + 6 h`; rewritten to `completedAt + 30 min` on completion |
| `createdAt` | timestamptz | no | `now()` | |

### 4.6 Enums (exact values)

```
trip_status_enum       : 'active' | 'hidden' | 'completed' | 'cancelled'         (initial migration)
                       + 'draft' | 'published' | 'fully_booked' | 'in_progress'  (migration 008.06)
booking_status_enum    : 'pending' | 'confirmed' | 'cancelled' | 'rejected'
                       | 'in_progress' | 'completed' | 'no_show'
TripType (varchar)     : 'scheduled' | 'instant'
RecurrenceFrequency    : 'daily' | 'weekly'
PassengerDeclaredStatus: 'in_vehicle' | 'on_my_way' | 'not_riding'
SeatAbsenceReason      : 'no_show' | 'cancelled_on_site' | 'wrong_pickup' | 'other'
trip.seats[].status    : 'available' | 'booked' | 'locked'
```

Live-code reality check on `trip_status_enum`:

* `published` — written by create, `show()`, recurrence spawn.
* `in_progress` — written by the auto-start processor only.
* `completed` — written by `completeTrip` and the auto-complete processor.
* `cancelled` — written by `TripsService.cancel`.
* `hidden` — written by `hide()`.
* `active` — **legacy**; migration 008.06 converted all rows to `published`. Still *read* in three
  places (`trip-auto-start.processor.ts:70`, `pre-trip-confirm.processor.ts:38`,
  `tracking.service.ts:314`). The last one makes `GET /api/v1/tracking/nearby/trips` return nothing.
* `draft`, `fully_booked` — **never written by any code path**; read-only defensive branches.

---

## 5. Features

## F-01: Publish a scheduled trip

**What it does:** A verified driver publishes a seated carpool trip (origin, destination, departure time,
per-seat price, optional intermediate stops, notes and a recurrence rule). The trip becomes searchable
immediately and its lifecycle jobs are scheduled at publish time.

**Actors:** driver (role `driver`, must own an approved vehicle).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/trips` | Bearer, role `driver` | Create + publish a trip |
| GET | `/api/v1/trips/fee-quote?seatPrice=&totalSeats=` | Bearer (any role) | Pre-publish platform-fee quote |

**Request contract — `POST /api/v1/trips`** (`CreateTripDto`, `src/modules/trips/dto/create-trip.dto.ts`):

| Field | Type | Validation | Req |
|---|---|---|---|
| `from` | object | `@ValidateNested` `LocationDto` | yes |
| `from.name` | string | `@MaxLength(255)` | yes |
| `from.latitude` | number | `-90..90`, coerced | yes |
| `from.longitude` | number | `-180..180`, coerced | yes |
| `from.address` | string | `@MaxLength(500)` | no |
| `to` | object | same `LocationDto` shape | yes |
| `departureTime` | string | `@IsDateString()` | yes |
| `price` | number | `@Min(0)`, coerced | yes |
| `currency` | string | `@IsIn(['EGP','JOD','SAR','AED','QAR'])` | no — **ignored unless geocoding fails** |
| `carImageUrl` | string | `@IsUrl()` | no — only a fallback if the vehicle has none |
| `stops` | array | `@ArrayMaxSize(5)` of `StopDto` | no |
| `stops[].name` | string | `@MaxLength(160)` | yes |
| `stops[].address` | string | `@MaxLength(500)` | no |
| `stops[].lat` / `.lng` | number | `-90..90` / `-180..180` | yes |
| `stops[].order` | int | `1..5` | yes |
| `stops[].note` | string | `@MaxLength(500)` | no |
| `notes` | string | `@MaxLength(2000)` | no |
| `recurrence` | object | `RecurrenceDto` | no |
| `recurrence.frequency` | string | `@IsEnum(['daily','weekly'])` | yes |
| `recurrence.weekdays` | string[] | required when `frequency==='weekly'`, `@ArrayMaxSize(7)`; values `sun,mon,tue,wed,thu,fri,sat` | conditional |
| `recurrence.until` | string | `@IsDateString()` | no |
| `availableSeats` | int | `@Min(1)`; service also enforces `<= layout seat count` | no (defaults to full layout) |
| `preventGenderMixing` | boolean | — | no (defaults to the vehicle's setting) |

**Response:** the saved `TripEntity` (all columns of §4.1), wrapped in the success envelope. `201`.

**`GET /api/v1/trips/fee-quote` response** (`DriverTripFeeService.computeExpectedFee`):
```json
{ "amount": 8.00, "seatPrice": 20, "totalSeats": 4, "percent": 10, "currency": "JOD" }
```
Query params are read raw and coerced with `Number(... ?? 0)`; no validation DTO
(`trips.controller.ts:101-109`) — garbage input yields `NaN`-derived output rather than a 400.

**Business rules & validation** (`TripsService.create`, `trips.service.ts:110-296`) — **in this exact order**:

1. Driver must have a vehicle: `VehiclesService.findByDriver(driverId)`; else `403 "You must register and
   get your vehicle approved before creating trips"`.
2. `vehicle.isVerified` must be true; else `403 "Your vehicle is pending admin approval..."`.
3. `user.isDriverApproved !== false`; else `403` (Arabic message: account under review).
4. `user.photoUrl` must exist; else `403 { code: PROFILE_PHOTO_REQUIRED }`.
5. No outstanding pending charges: `PendingChargesService.getOutstandingSummary(driverId).count === 0`;
   else `403 { code: OUTSTANDING_CHARGES, count, totalAmount }`.
6. `departureTime > now`; else `400 "Departure time must be in the future"`.
7. Seat layout resolution: use `vehicle.seatLayout` if present, otherwise the vehicle-type template
   (`resolveVehicleTypeTemplate`, defaults to `sedan`). The trip stores its **own copy**, with
   `preventGenderMixing = dto.preventGenderMixing ?? layout.preventGenderMixing ?? false`. The vehicle
   row is never mutated.
8. Seat generation: row-major from the layout. With `seatsPerRowList` present, row `r` gets
   `seatsPerRowList[r]` seats; otherwise `rows x seatsPerRow`. Seat ids are `"{row}-{col}"`, zero-based.
   Every seat starts `{userId:null,userName:null,gender:null,bookedAt:null,status:'available'}`.
9. `1 <= availableSeats <= layoutSeatCount`; else `400 "availableSeats must be between 1 and N"`.
   The generated array is truncated with `slice(0, requested)`; `totalSeats = availableSeats = requested`.
10. Currency: reverse-geocode `from.latitude/longitude` → ISO country → `currencyForCountry()`
    (`src/common/currency/country-currency.ts`). On any geocoder error, fall back to `dto.currency`, then
    `DEFAULT_CURRENCY = 'JOD'`. Logged as a warning, never fatal.
11. Fee guard (last, because it is the most expensive check):
    `DriverTripFeeService.assertDriverCanCoverTripFee(driverId, {seatPrice: price, totalSeats, currency})`.
    Fee = `round2(seatPrice * totalSeats * driverUnlockPercent / 100)`, or the legacy flat
    `communication_fees.feeAmount` when the percent is 0. If `walletSummary.balance < fee` ⇒
    `403 { code: INSUFFICIENT_BALANCE_FOR_TRIP_FEE, balance, requiredAmount, currency }`.
12. Persist with `status = published`, `isVisible = true`, `communicationFeeStatus='not_paid'`,
    `carImageUrl = vehicle.carImageUrl ?? dto.carImageUrl ?? null`.
13. If `recurrence` present: create a `trip_recurrence_rules` row with
    `localTime = departureTime.toTimeString().slice(0,8)` (**server local time**), timezone hard-coded
    `'Asia/Amman'`, then set `trip.recurrenceRuleId` and re-save.
14. Fire-and-forget `NotificationsService.enqueueCityFanout(tripId)` (queue `new-trip-fanout`,
    3 attempts, 5 s backoff). Failure only logs.
15. Fire-and-forget `scheduleTripAutoStart(tripId, departureTime)`.

**Data model:** writes `trips` (all creation columns) and optionally `trip_recurrence_rules`.
Reads `vehicles`, `users`, `pending_charges`, `communication_fees`, `wallet_accounts`.

**State machine:** `(none) -> published`.

**External services:** Nominatim/Photon reverse geocoding via `LocationsService`; Redis/Bull
(`trip-auto-start`, `new-trip-fanout`); Firebase (city fan-out push, async).

**Background jobs:**
* `trip-auto-start`, job name `enforce`, `jobId = "trip-auto-start-<tripId>"`,
  `delay = max(0, departureTime - now)`, `attempts: 2`, exponential backoff 15 000 ms,
  `removeOnComplete: true` (`trips.service.ts:1004-1030`).
* `new-trip-fanout`, job name `fanout`, `attempts: 3`, backoff 5 000 ms.

**Errors:**

| Status | Body code / message |
|---|---|
| 400 | `"Departure time must be in the future"`; `"availableSeats must be between 1 and N"`; class-validator array of messages |
| 403 | vehicle missing / unverified; driver not approved; `PROFILE_PHOTO_REQUIRED`; `OUTSTANDING_CHARGES`; `INSUFFICIENT_BALANCE_FOR_TRIP_FEE`; role mismatch |

**Notes for reimplementation:**
* The check ordering is deliberate and covered by tests (`trips.service.spec.ts`): cheap local validation
  before the geocode, and the wallet read last.
* `currency` from the client is effectively decorative; the departure country wins.
* The recurrence template freezes the **clamped** seat list (`totalSeats`), not the full vehicle layout.
* Nothing is reserved from the wallet at publish time — the guard is a point-in-time balance check only.
* `driverName` is copied from the JWT-resolved user at creation and never refreshed.

---

## F-02: Edit, hide and re-show a trip

**What it does:** The owning driver edits trip details, or toggles its visibility in search.

**Actors:** driver (owner only).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| PATCH | `/api/v1/trips/:id` | Bearer, role `driver` | Update trip fields |
| PATCH | `/api/v1/trips/:id/hide` | Bearer, role `driver` | `status=hidden`, `isVisible=false` |
| PATCH | `/api/v1/trips/:id/show` | Bearer, role `driver` | `status=published`, `isVisible=true` |

**Request contract — PATCH `/trips/:id`:** `UpdateTripDto = PartialType(CreateTripDto)` — every F-01
field, all optional, same validators. Only these are actually applied
(`trips.service.ts:578-650`): `from`, `to`, `departureTime`, `price`, `currency`, `carImageUrl`, `notes`,
`stops`. **`availableSeats`, `preventGenderMixing` and `recurrence` are accepted by validation and then
silently ignored.**

**Response:** the saved `TripEntity`. Hide/show return the saved entity too.

**Business rules:**

1. `trip.driverId === callerId`, else `403 "You are not the owner of this trip"`.
2. If `departureTime` is being changed **and** at least one seat has `status === 'booked'` **and** the new
   departure is <= 24 h away ⇒ `403 { message: 'Cannot change departure time within 24h when bookings
   exist', code: CANCELLATION_WINDOW_CLOSED }`. Note the window is measured against the **new** value, not
   the old one.
3. If `price` is changed and `trip.driverWalletChargeApplied !== true`, re-run
   `assertDriverCanCoverTripFee(driverId, {seatPrice: newPrice, totalSeats: trip.totalSeats, currency:
   trip.currency})`. Once the fee has been charged the amount is final and is never re-guarded.
4. `from`/`to` updates rewrite both the name/address and the geography point. `fromAddress`/`toAddress`
   fall back to the existing value when the DTO omits them.
5. After save, `rescheduleTripAutoStart`: remove both lifecycle jobs by id and re-enqueue `trip-auto-start`
   with the new delay. **A completed or cancelled trip can therefore have a fresh auto-start job queued
   by an edit** — the processor's status guard is what stops it doing damage.
6. `hide()`/`show()` have **no status precondition** — a completed or cancelled trip can be flipped to
   `hidden` or back to `published` (verify `trips.service.ts:652-672`).

**Data model:** `trips`.

**State machine:** `published <-> hidden` (via hide/show); any status -> `hidden`/`published` (unguarded).

**Errors:** `403` not owner / `CANCELLATION_WINDOW_CLOSED` / `INSUFFICIENT_BALANCE_FOR_TRIP_FEE`;
`404 "Trip not found"`.

**Notes:** `update()` loads the trip through `findById()`, which returns an object spread with extra
computed keys (`distanceKm`, `driverPhotoUrl`, `driverRating`, `vehicleModel`, `vehiclePlateNumber`) and
then saves it via `tripRepo.save()` — TypeORM ignores unknown keys, but a reimplementation on a stricter
ORM must strip them.

---

## F-03: Driver cancels a trip

**What it does:** The owning driver cancels a published trip; every non-cancelled booking on it is
cancelled by the system and passengers are notified.

**Actors:** driver (owner).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| DELETE | `/api/v1/trips/:id` | Bearer, role `driver` | Cancel the trip |

**Request:** no body. **Response:** the saved `TripEntity` with `status='cancelled'`.

**Business rules** (`trips.service.ts:687-731`):

1. Owner check ⇒ `403`.
2. `status !== 'completed'`, else `400 "Cannot cancel a completed trip"`.
3. **24 h window**: `hoursUntilDeparture = (departureTime - now) / 3_600_000`. If `<= 24` ⇒
   `403 { message: 'Cannot cancel within 24 hours of departure', code: CANCELLATION_WINDOW_CLOSED,
   windowSeconds }` where
   `windowSeconds = max(0, floor((departureTime - 24h - now) / 1000))` (i.e. seconds until the window
   *closed*, which is 0 once past it).
4. `status = 'cancelled'`, saved.
5. `removeTripLifecycleJobs(tripId)` — removes `trip-auto-start-<id>` and `trip-auto-complete-<id>`.
6. `BookingsService.cancelAllForTrip(tripId, 'Trip cancelled by driver')`: every booking whose status is
   not `cancelled` (**including `completed` and `no_show`**) gets `status='cancelled'`,
   `cancellationReason`, `cancelledAt=now`, `cancelledBy='system'`.
7. For every remaining non-cancelled booking (`findByTripInternal` — which now returns **nothing**, because
   step 6 just cancelled them all), send a `trip_cancelled` notification. **This is a live bug: the
   notification loop iterates an empty set.** Order matters if you reimplement — notify before cancelling.

**Data model:** `trips`, `bookings`, `notifications`.

**State machine:** `published|hidden|in_progress -> cancelled` (driver-triggered). Seats are **not**
released back to `available` and `availableSeats` is not restored — the trip is dead anyway.

**External services:** Redis/Bull job removal; notifications.

**Errors:** `403` not owner / `CANCELLATION_WINDOW_CLOSED`; `400` completed trip; `404` trip not found.

---

## F-04: Trip search (filters + bounding box)

**What it does:** Passenger-facing search over published, visible trips with date, price and seat filters,
plus optional origin/destination proximity.

**Actors:** any authenticated user.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/trips` | Bearer | Search trips |
| GET | `/api/v1/trips/my` | Bearer, role `driver` | The caller's own trips |

**Query contract — `GET /api/v1/trips`** (`SearchTripsDto extends PaginationDto`):

| Field | Type | Validation |
|---|---|---|
| `page` / `limit` | int | `>=1` / `1..100` |
| `fromLatitude` / `fromLongitude` | number | `-90..90` / `-180..180` |
| `toLatitude` / `toLongitude` | number | same |
| `departureDate` | string | `@IsDateString()` |
| `minPrice` / `maxPrice` | number | `@Min(0)` |
| `availableSeats` | number | `@Min(1)` |
| `status` | string | `@IsEnum(['active','hidden','completed','cancelled','expired'])` — **stale list**: it does not accept `published`, and `'active'`/`'expired'` match no rows |

**Response:** `PaginatedResult<TripEntity>`.

**Business rules** (`trips.service.ts:461-543`):

1. Base predicate: `status = (filters.status || 'published') AND isVisible = true`.
2. `departureDate` becomes a `[startDate, startDate + 1 day)` half-open range on `departureTime`
   (interpreted in server timezone via `new Date(dateString)`).
3. `minPrice`/`maxPrice` compare against `trip.price` as **strings** (`price >= :minPrice` with the value
   stringified) — Postgres coerces numerically for a `numeric` column, but a reimplementation should
   compare numerically.
4. `availableSeats` filter is `trip.availableSeats >= :availableSeats`.
5. Ordering is always `departureTime ASC`.
6. **Geo filtering is done in application memory, not SQL.** When either coordinate pair is supplied the
   query takes the first **2000** rows with no offset, then filters in JS with a
   +/- `0.1` degree bounding box (~11 km N/S, less E/W) on `fromPoint` and/or `toPoint`, then
   `total = filtered.length` and the page is `slice(skip, skip+limit)`. Without geo filters the SQL does
   the paging, and **`total` is the size of the current page, not the full result count** — `totalPages`
   is therefore wrong in the non-geo case (`trips.service.ts:531-541`).
7. Trips are **not** filtered by `departureTime >= now` here — past trips still match.
8. `tripType` is **not** filtered, so accepted instant rides can appear in search results (verify
   `trips.service.ts:463-470`; the entity comment claims instant trips are excluded).

**`GET /api/v1/trips/my`:** query `page`, `limit`, `status` — `status` is accepted by the controller
signature and **discarded** (`trips.controller.ts:84-94`). Returns every trip of the driver, any status,
ordered `createdAt DESC`, with a correct `total` from a separate `count()`.

**Data model:** `trips` only.

**Errors:** `400` on validation; `403` on `/my` for non-drivers.

**Notes for reimplementation:** this is the weakest part of the domain. A rebuild should push the geo
predicate into PostGIS (`ST_DWithin(fromPoint, ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography,
:radiusMeters)`) and use a real `COUNT(*)`. Preserve the response shape.

---

## F-05: Nearby and "preferred" trip feeds

**What it does:** Two location-driven home-screen feeds: strict radius-sorted nearby trips, and a
heuristically scored "preferred routes" feed tuned for known intercity corridors.

**Actors:** any authenticated user.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/trips/nearby` | Bearer | Trips departing near the caller (default radius 50 km) |
| GET | `/api/v1/trips/preferred` | Bearer | Scored feed (default radius 80 km) |
| GET | `/api/v1/tracking/nearby/trips` | Bearer | PostGIS `ST_DWithin` variant (**currently returns nothing**) |

**Query contract** (`LocationBasedTripsDto extends PaginationDto`):

| Field | Type | Validation | Req |
|---|---|---|---|
| `latitude` | number | `-90..90` | yes |
| `longitude` | number | `-180..180` | yes |
| `radiusKm` | number | `1..300` | no (nearby: 50, preferred: 80) |
| `page` / `limit` | int | `>=1` / `1..100` | no |

`GET /api/v1/tracking/nearby/trips` takes raw `latitude`, `longitude`, `radiusMeters` (default 5000) with
no DTO validation.

**Response:** `PaginatedResult<TripEntity>` for both trip endpoints; a bare array for the tracking one.

**Business rules — nearby** (`trips.service.ts:751-796`):

1. Load at most **300** candidates: `status='published' AND isVisible=true`, ordered `departureTime ASC`.
2. Keep only `availableSeats > 0 AND departureTime >= now`.
3. Haversine distance (R = 6371 km) from the caller to `fromPoint`; keep `distance <= radiusKm`.
4. Sort ascending by distance; paginate in memory; `total` is the post-filter count.

**Business rules — preferred** (`trips.service.ts:799-869`):

1. Load at most **500** candidates with the same predicate; same availability/time/radius filter (default
   80 km).
2. Compute the applicable known routes: from the in-radius set, take origins within 80 km of the rider,
   normalise Arabic, and keep the `knownRoutes` entries whose `from` keywords match. If none match, all
   known routes apply. Hard-coded corridors (`trips.service.ts:900-916`):
   `جده/jeddah -> مكه/mecca/makkah`, `جده -> المدينه/madinah/medina`, `الطفيله/tafila -> عمان/amman`,
   `جامعه مؤته/مؤته/mu tah/mutah -> عمان`, `الكرك/karak -> عمان`.
3. Score: `score = max(0, 70 - distanceKm)`; `+120` for each matching known route
   (`fromName` contains a `from` keyword AND `toName` contains a `to` keyword).
4. Sort by `score DESC`, then `distanceKm ASC`; paginate in memory.
5. Arabic normalisation (`normalizeArabic`): lowercase, trim, collapse whitespace, `أ|إ|آ -> ا`, `ة -> ه`.

**Spatial query — `GET /api/v1/tracking/nearby/trips`** (`tracking.service.ts:307-326`), the only true
PostGIS search in the domain:

```sql
SELECT trip.* FROM trips trip
WHERE trip.status = 'active'
  AND trip."isVisible" = true
  AND ST_DWithin(
        trip."fromPoint",
        ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
        :radiusMeters
      );
```

`status = 'active'` no longer matches any row (migration 008.06 rewrote them all to `published`), so this
endpoint returns `[]` in practice. **Flagged as a live bug**; the correct predicate is `status = 'published'`.

The only other PostGIS expression in this domain is the trip-distance projection in `findById`:
`ST_Distance(trip."fromPoint", trip."toPoint") / 1000 AS distance_km` (`trips.service.ts:318-324`).

**Data model:** `trips` (+ GIST indexes, which the in-memory paths never exercise).

**Notes:** all three feeds silently cap the candidate set (300 / 500 / unbounded), so results are not
globally correct at scale. A rebuild should replace both in-memory feeds with `ST_DWithin` +
`ORDER BY ST_Distance(...)` and keep the scoring as a SQL `CASE`/scoring expression or a post-filter over
a bounded spatial result.

---

## F-06: Trip detail, seat map and pricing preview

**What it does:** Read a single trip with driver/vehicle decoration, its seat map, and the platform
pricing breakdown.

**Actors:** any authenticated user.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/trips/:id` | Bearer | Trip detail |
| GET | `/api/v1/trips/:id/seats` | Bearer | Seat map |
| GET | `/api/v1/trips/:id/pricing-preview` | Bearer | Passenger + driver-fee breakdown |

**Response — `GET /trips/:id`** (`trips.service.ts:298-345`): the full `TripEntity` plus
```
distanceKm            number|undefined   ST_Distance(fromPoint,toPoint)/1000
driverPhotoUrl        string|null
driverRating          number|null
vehicleModel          string|null
vehiclePlateNumber    string|null
carImageUrl           string|null        trip.carImageUrl ?? vehicle.carImageUrl
```

**Response — `GET /trips/:id/seats`:**
```json
{ "seatLayout": { "rows": 2, "seatsPerRow": 3, "seatsPerRowList": [1,3], "preventGenderMixing": false },
  "seats": [ { "seatNumber": "0-0", "status": "available|booked|locked",
               "gender": "male|female|null", "passengerGender": "male|female|undefined" } ] }
```
`gender` and `passengerGender` are the same value; the duplicate exists for client compatibility.
Occupant `userId`/`userName` are **not** exposed here.

**Response — `GET /trips/:id/pricing-preview`** (`platform-pricing.service.ts:91-107`, country hard-coded
`'JO'`):
```json
{ "tripId": "...",
  "passenger": { "seatPrice": 20, "passengerPlatformPercent": 0, "platformAmount": 0,
                 "driverAmount": 20, "currency": "JOD", "requiresOnlinePayment": false },
  "driverUnlock": { "feeAmount": 8, "currency": "JOD", "driverUnlockPercent": 10,
                    "legacyFlatFeeAmount": 0, "seatPrice": 20, "totalSeats": 4 } }
```

**Business rules:**

1. `findById` throws `404 "Trip not found"` when the id does not exist.
2. Price maths: `driverUnlock.feeAmount = round2(seatPrice * totalSeats * driverUnlockPercent / 100)` when
   `driverUnlockPercent > 0`, else `round2(communication_fees.feeAmount)` (legacy flat).
   `round2(n) = Math.round(n*100)/100`.
3. Passenger side is always zero-fee under current configuration.
4. Route ordering in the controller matters: `nearby`, `preferred`, `my`, `fee-quote` and
   `:id/pricing-preview` are declared **before** `:id`, so they are not swallowed by the id route.

**External services:** none (pricing reads the `communication_fees` table).

---

## F-07: Driver seat lock / unlock

**What it does:** The driver blocks a seat that was sold outside the app (or releases it again).

**Actors:** driver (owner).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| PATCH | `/api/v1/trips/:id/seats/lock` | Bearer, role `driver` | Lock or unlock one seat |

**Request** (`SetSeatLockDto`): `{ "seatNumber": "0-1", "locked": true }` — `seatNumber` `@IsString()`,
`locked` `@IsBoolean()`; both required.

**Response:** the saved `TripEntity`.

**Business rules** (`trips.service.ts:397-457`):

1. Owner check ⇒ `403 "You are not the owner of this trip"`.
2. `trip.status === 'published'`, else `400 "Trip is not active"`.
3. Seat must exist in `trip.seats`, else `400 "Invalid seat number"`.
4. Lock: current status must be exactly `available`, else `400 "Only available seats can be locked (not
   booked or already locked)"`. Sets the seat to `{status:'locked', userId:null, userName:null,
   gender:null, bookedAt:null}` and `availableSeats = max(0, availableSeats - 1)`.
5. Unlock: current status must be exactly `locked`, else `400 "Only locked seats can be unlocked"`. Resets
   to `available` and `availableSeats += 1`.
6. Emits `seatBooked {tripId, seatNumber, status:'locked'}` on lock and `seatReleased {tripId, seatNumber}`
   on unlock, to the Socket.IO room `trip:<tripId>` in namespace `/trips`.

**Notes:** there is **no row lock or transaction** here, so a concurrent booking of the same seat can
race (last write wins on the whole `seats` JSONB array). `createMultiSeat` does take a
`pessimistic_write` lock, but it locks against other bookings only, not against this path.

---

## F-08: Recurring trips

**What it does:** A recurrence rule captures a trip template plus a daily/weekly schedule; a sweep
processor materialises real `trips` rows up to 14 days ahead.

**Actors:** driver (rule owner); admin (manual spawn trigger).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| — | rule creation is a side effect of `POST /api/v1/trips` with `recurrence` | — | see F-01 |
| GET | `/api/v1/trips/recurrence-rules` | Bearer, role `driver` | List the caller's rules |
| PATCH | `/api/v1/trips/recurrence-rules/:id` | Bearer, role `driver` | Update `isActive`, `until`, `weekdays` |
| DELETE | `/api/v1/trips/recurrence-rules/:id` | Bearer, role `driver` | Deactivate (soft) |
| POST | `/api/v1/admin/recurrence-rules/:id/spawn-now` | Bearer, role `admin` | Enqueue an immediate sweep |

**Contracts:**
* `GET` → array of `TripRecurrenceRuleEntity`, ordered `createdAt DESC`.
* `PATCH` body `UpdateRecurrenceRuleDto`: `isActive?: boolean`, `until?: string|null` (`@IsDateString`),
  `weekdays?: string[]` (`@ArrayMaxSize(7)`, each a string). Returns the saved rule.
* `DELETE` → `{ "success": true, "message": "Rule deactivated" }`.
* Admin spawn → `{ "success": true, "message": "Spawn job enqueued", "ruleId": "...", "jobId": "..." }`.
  Note it enqueues a **global** sweep job (payload `{}`), not a per-rule one; the rule id only appears in
  the Bull `jobId` (`admin-recurrence.controller.ts:63-84`).

**`templateJson` shape** (frozen at rule creation, `trips.service.ts:245-268`):
```json
{ "fromName": "...", "fromAddress": "...|null", "fromPoint": { "lat": 0, "lng": 0 },
  "toName": "...", "toAddress": "...|null", "toPoint": { "lat": 0, "lng": 0 },
  "price": "20", "currency": "JOD", "totalSeats": 4,
  "seatLayout": { "rows": 2, "seatsPerRow": 3, "seatsPerRowList": [1,3], "preventGenderMixing": false },
  "stops": [], "notes": "...|null", "carImageUrl": "...|null" }
```

**Business rules:**

1. Weekday bitmask (`recurrence.service.ts:15-44`): `sun=1, mon=2, tue=4, wed=8, thu=16, fri=32, sat=64`.
   `weekdayMask` is only populated for `frequency='weekly'`; daily rules store `0`.
2. Ownership is enforced on update/deactivate ⇒ `403 "You are not the owner of this rule"`;
   missing rule ⇒ `404 "Recurrence rule not found"`.
3. **Spawn algorithm** (`src/jobs/processors/recurrence-spawn.processor.ts`):
   * Load all rules with `isActive = true`.
   * Per rule: `startDate = lastSpawnedFor ? new Date(lastSpawnedFor + 'T00:00:00+03:00') : rule.createdAt`.
   * `maxEnd = now + 14 days`; `untilDate = until ? new Date(until + 'T23:59:59+03:00') : null`;
     `endDate = min(untilDate, maxEnd)`.
   * Cursor starts at `startDate + 1 day` and steps one day at a time while `cursor <= endDate`.
   * `shouldSpawn`: daily ⇒ always; weekly ⇒ `(weekdayMask & (1 << cursor.getDay())) !== 0`
     (JS `getDay()`: Sunday = 0, matching the mask layout).
   * `departureTime = cursor` with `setHours(h, m, s, 0)` from `localTime` — **server local time, the
     rule's `timezone` column is ignored**.
   * Duplicate guard: skip when a trip already exists with the same `(driverId, departureTime)` — this is
     a plain `findOne`, not a unique constraint, and it matches trips from *any* rule or a manual publish.
   * Otherwise create a `trips` row from the template: `status='published'`, `isVisible=true`,
     `driverName=null`, `communicationFeeStatus='not_paid'`, `recurrenceRuleId=rule.id`, seats regenerated
     from `seatLayout` then clamped with `slice(0, tpl.totalSeats)` when the template published fewer seats
     than the layout holds.
   * Post-create: enqueue `new-trip-fanout` and `trip-auto-start` (same options as F-01).
   * After the loop: `rule.lastSpawnedFor = endDate.toISOString().slice(0,10)` and save — **even when
     nothing was spawned**, which permanently advances the cursor past `until`.

**Data model:** `trip_recurrence_rules`, `trips`.

**Background jobs:** queue `recurrence-spawn`, job name `spawn-occurrences`, payload `{}`.
**No cron or repeatable job registers it** — `JobsModule` only registers the queue and the processor.
The only producer is the admin `spawn-now` endpoint (`attempts: 1`, `removeOnComplete: true`). The
docblock claims an hourly cadence; that scheduler does not exist in this codebase. **Verify/restore:**
`src/jobs/jobs.module.ts:19-38`, `src/jobs/processors/recurrence-spawn.processor.ts:41-69`.

**Errors:** `403` not owner / non-driver; `404` rule not found.

**Notes for reimplementation:**
* Spawned trips bypass every publish-time guard in F-01 — no vehicle verification, no profile-photo check,
  no outstanding-charge check and **no wallet balance check**. A driver with an empty wallet keeps
  generating trips.
* The `timezone` column exists but is never applied; DST and server-timezone changes will shift
  departure times. Either honour it or drop it.
* `lastSpawnedFor` advancing on empty sweeps means a rule that is inactive for a while never backfills.

---

## F-09: Public trip share links

**What it does:** A driver or confirmed passenger mints an unguessable link that anyone can open to watch
the trip's live, PII-free status.

**Actors:** driver or confirmed passenger (create); anonymous (read).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/trips/:id/share-link` | Bearer | Mint a share link |
| GET | `/api/v1/share/:token` | **Public** (`@Public()`) | Read-only live trip status |

**Request:** none for either. **Responses:**

`POST` success:
```json
{ "url": "/share/<token>", "token": "<43-char base64url>", "expiresAt": "ISO" }
```
`GET /share/:token` success:
```json
{ "tripStatus": "in_progress",
  "fromName": "...", "toName": "...", "departureTime": "ISO",
  "etaMinutes": 12, "remainingDistanceKm": 8.4, "remainingDurationSeconds": 700,
  "etaAt": "ISO|null", "routeProgressPercent": 64.2,
  "driverLocation": { "lat": 31.9, "lng": 35.9, "capturedAt": "ISO" } }
```

**Business rules** (`src/modules/share-links/share-links.controller.ts`):

1. Creation requires the caller to be `trip.driverId`, or to have a booking on the trip with status
   exactly `confirmed`. `in_progress`/`completed` bookings do **not** qualify (verify `:52-60`).
2. Token: `randomBytes(32).toString('base64url')` (~43 chars), unique index on the column.
3. `expiresAt = departureTime + 6 h` at creation; `TripTimeService.completeTrip` rewrites **all** links of
   the trip to `completedAt + 30 min` (`trip-time.service.ts:368-373`).
4. Read: unknown token ⇒ a `200` body `{statusCode: 404, message: 'Share link not found'}`; expired ⇒
   `{statusCode: 410, message: 'Share link has expired'}`. **These are returned as normal successful
   responses, not HTTP errors** — the same is true of the `404`/`403` shapes on creation
   (`:46`, `:62-68`). A rebuild should use real status codes but must keep the body keys if old clients
   depend on them.
5. `driverLocation` is only populated when `trip.status === 'in_progress'` **and** both denormalised
   coordinates are non-null; otherwise `null`. ETA fields are echoed regardless of status.
6. No PII: no driver name, no passenger data, no phone numbers.
7. There is no rate limiting beyond the global throttler, and no per-trip cap on link count.

**Data model:** `trip_share_links`, read of `trips`, `bookings`.

---

## F-10: Create a multi-seat booking (v2) and the v1 shim

**What it does:** A passenger reserves one or more specific seats on a published trip in a single atomic
transaction, creating a `pending` booking request the driver must accept.

**Actors:** passenger or driver (`@Roles('passenger','driver')` — a driver may book someone else's trip).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/v2/bookings` | Bearer, role `passenger`\|`driver` | Multi-seat booking |
| POST | `/api/v1/bookings` | Bearer, role `passenger`\|`driver` | **Deprecated v1 shim** → maps to the v2 flow |

**Request — `POST /api/v1/v2/bookings`** (`CreateMultiSeatBookingDto`):

| Field | Type | Validation | Req |
|---|---|---|---|
| `tripId` | string | `@IsUUID()` | yes |
| `seats` | array | `@ArrayMinSize(1)`, `@ArrayMaxSize(50)` | yes |
| `seats[].seatNumber` | string | `@IsNotEmpty()` | yes |
| `seats[].displayName` | string | `@IsNotEmpty()`, `@MaxLength(100)` | yes |
| `seats[].gender` | string | `@IsIn(['male','female'])` | yes |
| `seats[].isMainBooker` | boolean | — (service requires exactly one `true`) | yes |
| `sharePhoneWithDriver` | boolean | — | no (default `false`) |
| `isFamilyBooking` | boolean | — | no (default `false`) |

**Request — `POST /api/v1/bookings`** (`CreateBookingDto`, deprecated): `tripId` (UUID), `seatNumber`
(non-empty string), `sharePhoneWithDriver?`, `walletIdempotencyKey?` (`@MaxLength(128)` — **accepted and
discarded**). The controller logs a deprecation warning and calls `createMultiSeat` with a single seat
whose `displayName` is `''` and `gender` is hard-coded `'male'` (`bookings.controller.ts:60-83`).

**Response:** the created booking re-read with `relations: ['trip','seats']`, i.e. the full
`BookingEntity` plus the nested trip and the `booking_seats` array. `201`.

**Business rules** (`BookingsService.createMultiSeat`, `bookings.service.ts:640-845`) — in order:

1. `isFamilyBooking === true` requires `seats.length >= 2`, else `400 "Family booking requires at least 2
   seats"`.
2. Trip must exist ⇒ `404 "Trip not found"`.
3. `trip.driverId !== userId`, else `400 "Cannot book your own trip"`.
4. `trip.status === 'published'`, else `400 "Trip is not available for booking"`.
5. Exactly one seat with `isMainBooker: true`, else `400 "Exactly one seat must be marked as isMainBooker"`.
6. Every requested seat must exist in `trip.seats` (`400 "Seat X does not exist"`) and have
   `status === 'available'` (`400 "Seat X is not available"`).
7. Gender adjacency: when `trip.seatLayout.preventGenderMixing` is truthy **and** not a family booking,
   run `hasGenderAdjacencyViolation(trip.seats, proposed)` (F-12); violation ⇒
   `400 "لا يمكن حجز هذه المقاعد بسبب قواعد الفصل بين الجنسين."`.
8. Pricing: `countryCode` hard-coded `'JO'`; `seatPricing = passengerSeatPricing(trip.price, trip.currency
   ?? 'JOD', feeRow)`; `totalAmount = (seatPricing.seatPrice * seatCount).toFixed(2)`.
9. **Transaction** (`createQueryRunner` + `startTransaction`):
   a. `findOne(TripEntity, {where:{id}, lock:{mode:'pessimistic_write'}})` — `SELECT ... FOR UPDATE`.
   b. Re-validate each seat is still `available`, else `400 "Seat X is no longer available"` (rollback).
   c. Mutate the `seats` JSONB entries to `{...seat, status:'booked', userId, gender, bookedAt: now}`.
      Note `userName` is **not** set on the trip's seat entry by this path (only the dead v1 `create()`
      set it), so the seat map shows a booked seat with a stale/absent `userName`.
   d. `availableSeats = max(0, availableSeats - seatCount)`; save the trip.
   e. Insert the `bookings` row: `status='pending'`, `hasDriverPaidToContact = !!trip.driverWalletChargeApplied`,
      `sharePhoneWithDriver`, `isFamilyBooking`, `seatCount`, `totalAmount`,
      `seatPriceAtBooking`, `platformAmount`, `driverAmount`,
      `expiresAt = now + timeoutSeconds` (default 3 h).
      (It also sets a `seatNumber` property for "legacy compat" — that column no longer exists, so TypeORM
      drops it.)
   f. Insert one `booking_seats` row per requested seat.
   g. Commit; any throw rolls back the whole thing.
10. After commit (all fire-and-forget, failures only logged):
    * Enqueue `bookings-timeout` / `expire-booking` with `jobId = "booking-expire-<bookingId>"`,
      `delay = timeoutSeconds * 1000`, `attempts: 3`, exponential backoff 5 000 ms, `removeOnComplete: true`.
    * `NotificationsService.notifyDriverOfNewBooking(bookingId)`.
11. Re-read and return the booking with relations.

**Seat/price maths summary:**
```
seatCount     = seats.length                 (1..50)
seatPrice     = round2(trip.price)
platformAmount= 0
driverAmount  = seatPrice
totalAmount   = (seatPrice * seatCount).toFixed(2)
availableSeats' = max(0, availableSeats - seatCount)
timeoutSeconds  = env BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS ?? 10800
```

**Data model:** `bookings` (insert), `booking_seats` (insert), `trips` (`seats`, `availableSeats`).

**State machine:** `(none) -> pending`.

**External services:** Redis/Bull (`bookings-timeout`), Firebase push via `NotificationsService`.

**Errors:**

| Status | Message |
|---|---|
| 400 | family-booking seat count; own trip; trip not published; main-booker count; seat does not exist / not available / no longer available; gender-adjacency (Arabic) |
| 404 | `"Trip not found"` |
| 403 | role mismatch |

**Notes for reimplementation:**
* **The duplicate-booking guard was lost.** The comment at `bookings.service.ts:659` says "Duplicate
  booking check — any active booking by this user for this trip" but no check follows; the unique
  `(userId,tripId)` constraint was dropped by migration 008.02. A user can hold several concurrent
  bookings on one trip. The dead v1 `create()` still has the check (`:163-172`) — port it if the
  behaviour is wanted.
* `ErrorCodes.SEATS_TAKEN`, `GENDER_ADJACENCY_VIOLATION` and `NO_VALID_ARRANGEMENT` exist in
  `src/common/errors/error-codes.ts` but **are never emitted** — these paths throw plain-string
  `BadRequestException`s. Clients match on message text today.
* The trip row lock serialises concurrent bookings, but F-07 (seat lock) and the release paths do not take
  it — a rebuild should lock uniformly.
* Enqueueing the timeout job happens **after** commit and is not retried; a Redis outage produces a booking
  that never expires. The `expiresAt` column is the only surviving record of the intent.
* `BookingsService.create()` (the v1 single-seat implementation with `resolvePassengerWalletPaymentForBooking`
  and its own transaction) is **dead code** — no controller or service calls it. It is the only writer of
  `bookings.passengerPaymentId` and of `trip.seats[].userName`.

---

## F-11: Auto-pick seats

**What it does:** The passenger asks for N seats without choosing them; the server finds the first
contiguous run in a row that satisfies the gender rules, then books it.

**Actors:** passenger or driver.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/v2/bookings/auto-pick` | Bearer, role `passenger`\|`driver` | Pick + book seats |

**Request** (`AutoPickBookingDto`):

| Field | Type | Validation | Req |
|---|---|---|---|
| `tripId` | string | `@IsUUID()` | yes |
| `seatCount` | int | `1..50` | yes |
| `passengers` | array | `@ArrayMinSize(1)`, `@ArrayMaxSize(50)`, items are `BookingSeatDto` **minus** `seatNumber` | yes |
| `passengers[].displayName` | string | `@MaxLength(100)`, non-empty | yes |
| `passengers[].gender` | string | `@IsIn(['male','female'])` | yes |
| `passengers[].isMainBooker` | boolean | — | yes |
| `sharePhoneWithDriver` | boolean | — | no |
| `isFamilyBooking` | boolean | — | no |

Note the DTO type is `Omit<BookingSeatDto,'seatNumber'>[]` but the `@Type(() => BookingSeatDto)` decorator
still validates against the full class; with `forbidNonWhitelisted` a supplied `seatNumber` is stripped
rather than rejected. `seatCount` and `passengers.length` are **not cross-validated** — the placement uses
`passengers.length` (`bookings.service.ts:875`), while the capacity pre-check uses `seatCount`.

**Response:** identical to F-10 (delegates to `createMultiSeat`).

**Business rules** (`bookings.service.ts:851-902`):

1. Trip must exist ⇒ `404`; `status === 'published'` ⇒ else `400 "Trip is not available for booking"`.
2. `trip.availableSeats >= seatCount`, else `400 "Not enough available seats"`.
3. Layout fallback when `seatLayout` is null: `{rows: 1, seatsPerRow: trip.totalSeats ?? seatCount}`.
4. Candidate positions:
   * family booking ⇒ `findContiguousAvailablePositions` — any run of `count` free seats in one row,
     ignoring gender (`bookings.service.ts:906-931`);
   * otherwise ⇒ `findValidStartPositions(existingSeats, proposedGenders, seatLayout)`
     (`src/modules/seats/gender-adjacency.ts:97-145`): for each row `r` with `rowSize >= count`, for each
     `startCol` in `0..rowSize-count`, require every target seat to be missing-or-`available` and the
     merged seat set to pass `hasGenderAdjacencyViolation`.
5. Empty candidate list ⇒ `400` with `"لا توجد مقاعد متجاورة متاحة تكفي المجموعة."` (family) or
   `"لا توجد مقاعد متاحة تلبي قواعد الفصل بين الجنسين."` (non-family).
6. **The first candidate wins** (`validPositions[0]`) — lowest row, lowest column. Seat numbers become
   `"{row}-{startCol+offset}"` in passenger array order.
7. Delegates to `createMultiSeat`, which re-runs every rule of F-10 under the row lock.

**Notes:** the gender check in `findValidStartPositions` runs unconditionally, even when the trip has
`preventGenderMixing = false` — so auto-pick is stricter than manual seat selection on a mixed-allowed
trip. `getRowSeatCounts` (used by the family path) derives row sizes from `seatsPerRowList`, then
`rows × seatsPerRow`, then by scanning seat numbers (`bookings.service.ts:46-77`).

---

## F-12: Gender-adjacency rules

**What it does:** Enforces that a passenger is not seated horizontally next to a passenger of a different
gender when the trip has `preventGenderMixing` enabled.

**Actors:** system (invoked from F-10, F-11 and the dead v1 create path).

**API Endpoints:** none — it is a rule applied inside booking creation.

**Business rules:**

1. Enabled per trip via `trip.seatLayout.preventGenderMixing`, which comes from
   `CreateTripDto.preventGenderMixing ?? vehicle.seatLayout.preventGenderMixing ?? false`.
2. `isFamilyBooking = true` bypasses it entirely for that booking (F-10 rule 7, F-11 rule 4).
3. **v2 rule** (`hasGenderAdjacencyViolation`, `src/modules/seats/gender-adjacency.ts:39-86`):
   * Build `row -> col -> gender` from all `trip.seats` entries with `status === 'booked'` and a non-null
     gender, then overlay the proposed seats (proposed wins on collision).
   * For each row, sort the occupied column indices and compare **consecutive columns only when they are
     numerically adjacent** (`cols[i+1] === cols[i] + 1`). Any adjacent pair with different genders ⇒
     violation.
   * **Horizontal only** — vertical (front/back) adjacency is not checked, and aisle gaps are not modelled
     (a `seatsPerRowList` of `[1,3]` puts the driver-row seat at `0-0` with no neighbour, which is why the
     sedan layout works).
4. **v1 rule** (`BookingsService.hasAdjacentGenderConflict`, `bookings.service.ts:82-121`) — used only by
   the dead `create()` path — is *different*: it checks left, right, **above and below** the target seat
   against the booking user's own gender. Preserve only the v2 rule in a rebuild unless you resurrect v1.
5. Companions inside the same request never conflict with each other in v2, because the whole proposed set
   is inserted before checking — a male and female companion pair **will** be rejected if they land in
   adjacent columns. The family flag is the intended escape hatch.

**Data model:** reads `trips.seats[].gender`/`status` and `trips.seatLayout`; writes `booking_seats.gender`.

**Notes:** genders are `'male' | 'female'` only. `trip.seats[].gender` is populated from the booking DTO
in v2 (self-reported per seat), from the user profile in dead-v1.

---

## F-13: Driver accepts or rejects a booking

**What it does:** The driver decides on a pending seat request; acceptance confirms the seats, rejection
returns them to the pool.

**Actors:** driver (trip owner).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| PATCH | `/api/v1/v2/bookings/:id/accept` | Bearer, role `driver` | Confirm the booking |
| PATCH | `/api/v1/v2/bookings/:id/reject` | Bearer, role `driver` | Reject and free the seats |
| PATCH | `/api/v1/bookings/:id/confirm` | Bearer, role `driver` | **Legacy** confirm (no timeout-job cleanup) |

**Requests:** accept — none. reject — `{ "reason": "..." }` read via `@Body('reason')`, **unvalidated**
(any type, any length; stored into `cancellationReason`). confirm — none.

**Response:** the saved `BookingEntity`.

**Business rules — accept** (`bookings.service.ts:936-996`):
1. Booking must exist ⇒ `404 "Booking not found"`.
2. `trip.driverId === callerId` ⇒ else `403 "Only the trip driver can accept bookings"`.
3. `booking.status === 'pending'` ⇒ else `400 "Only pending bookings can be accepted"`.
4. `status = 'confirmed'`; `hasDriverPaidToContact = !!trip.driverWalletChargeApplied` (stamp refresh).
5. Remove the Bull job `booking-expire-<bookingId>` (errors only logged).
6. Push `notifyPassengerOfBookingDecision(bookingId, 'confirmed')`.
7. **No money moves** despite the Swagger description claiming "Charges the driver wallet for the contact
   fee" (`bookings-v2.controller.ts:96`) — that text is stale.

**Business rules — reject** (`bookings.service.ts:1002-1050`):
1–3 as above (`"Only the trip driver can reject bookings"` / `"Only pending bookings can be rejected"`).
4. `status='rejected'`, `cancellationReason = reason ?? null`, `cancelledAt = now`, `cancelledBy='driver'`.
5. For each `booking_seats` row: `TripsService.releaseSeat(tripId, seatNumber)` — sets the trip seat back
   to `available` and `availableSeats += 1` — then emit `seatReleased`. Both are `.catch(() => undefined)`.
6. Remove the timeout job; push `notifyPassengerOfBookingDecision(bookingId, 'canceled')`.

**Business rules — legacy confirm** (`bookings.service.ts:296-333`): same guards
(`"Only the trip driver can confirm bookings"`, `"Only pending bookings can be confirmed"`), sets
`confirmed` and the stamp, sends the same push, but **does not remove the timeout job** — so a booking
confirmed through this endpoint still has an `expire-booking` job pending. That job is a no-op because it
re-checks the status (F-16), but the asymmetry matters if you change the processor.

**State machine:** `pending -> confirmed` (accept/confirm) | `pending -> rejected` (reject).

**Notes:** `releaseSeat` reads the trip through `findById()` and saves the whole entity, once per seat, with
no transaction — N sequential read-modify-write cycles on the same JSONB array. Concurrent releases can
lose updates. A rebuild should release all seats of a booking in one locked transaction.

---

## F-14: Cancellations (passenger, driver, admin, system)

**What it does:** Ends a booking before the trip, with different time windows per role.

**Actors:** passenger (booking owner), driver (trip owner), admin, system (timeout job / trip cancel).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| PATCH | `/api/v1/bookings/:id/cancel` | Bearer (any role) | Cancel own booking, or a booking on own trip |
| PATCH | `/api/v1/admin/bookings/:id/cancel` | Bearer, role `admin` | Force-cancel (also on `admin-dashboard.controller.ts:309`) |

**Request** (`CancelBookingDto`): `{ "reason"?: string }`, `@IsString()`, `@MaxLength(500)`, optional.

**Response:** the saved `BookingEntity`.

**Business rules** (`BookingsService.cancel`, `bookings.service.ts:335-424`):

1. Booking must exist ⇒ `404 "Booking not found"`.
2. Caller must be the booking owner **or** the trip driver ⇒ else
   `403 "You are not authorized to cancel this booking"`.
3. `status !== 'cancelled'` (`400 "Booking is already cancelled"`) and `!== 'completed'`
   (`400 "Cannot cancel a completed booking"`). `rejected`, `no_show` and `in_progress` are cancellable.
4. Role resolution: `driver` only when the caller is the trip driver **and not** the booking owner;
   otherwise `passenger` (so a driver cancelling their own booking on someone else's trip is a passenger).
5. **Cancellation policy** (`src/modules/bookings/helpers/cancellation-policy.ts`):
   ```
   PASSENGER_WINDOW_SECONDS = 12 * 3600   (43 200)
   DRIVER_WINDOW_SECONDS    = 24 * 3600   (86 400)
   allowed = (departureTime - now) >= windowSeconds * 1000
   chargeRate = null                       (always — no automatic fees, ever)
   ```
   Only the **driver** is blocked when `!allowed`:
   `400 { code: 'CANCELLATION_WINDOW_CLOSED', windowSeconds, message: 'Cancellation is not allowed within
   24 hours of departure' }`. Passengers are **never blocked and never charged**; the 12 h window is
   computed and discarded. Fines are admin-only via `POST /admin/fines`.
6. Write: `status='cancelled'`, `cancellationReason = reason ?? null`, `cancelledAt = now`,
   `cancelledBy = 'driver' | 'passenger'`.
7. Release every `booking_seats` seat on the trip (`releaseSeat` + `seatReleased` emit), best-effort.
8. Notify: passenger cancelled ⇒ `notifyDriverOfBookingCancellation`; driver cancelled ⇒
   `notifyPassengerOfBookingDecision(..., 'canceled')`.

**Admin cancel** (`cancelAsAdmin`, `:426-471`): no ownership check, same terminal-status guards,
`cancellationReason = 'Cancelled by admin'`, `cancelledBy='admin'`, same seat release, passenger push.

**System cancels:**
* Timeout job (F-16): `cancelledBy='system'`, reason `"Driver did not respond within the acceptance window"`.
* Trip cancellation (F-03): `cancelAllForTrip` sets `cancelledBy='system'` with the supplied reason and
  **does not release seats** (the trip is dead).

**State machine:** `pending|confirmed|in_progress|rejected|no_show -> cancelled`.

**Errors:** `403` not a participant; `400` already cancelled / completed / `CANCELLATION_WINDOW_CLOSED`;
`404` booking not found.

**Notes:** the driver window here (24 h) matches the trip-level cancel window in F-03, and the same
`CANCELLATION_WINDOW_CLOSED` code is reused with different HTTP statuses — `400` here vs `403` in F-02/F-03.
Preserve that if clients branch on status.

---

## F-15: Booking reads

**What it does:** Passenger booking list, driver trip roster, and single-booking detail.

**Actors:** passenger, driver.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/bookings/my?page=&limit=&status=` | Bearer | Caller's bookings |
| GET | `/api/v1/bookings/trip/:tripId?page=&limit=` | Bearer, role `driver` | Roster for the driver's trip |
| GET | `/api/v1/bookings/:id` | Bearer | One booking |

**Query contracts:** `page`/`limit` from `PaginationDto`; `status` is an arbitrary string passed straight
into `WHERE b.status = :status` (Swagger advertises `pending|confirmed|cancelled|completed`, but no
validation is applied — an invalid enum value will make Postgres raise, surfacing as `500`).

**Responses:**
* `/bookings/my` → `PaginatedResult<BookingEntity & {trip, seats}>` ordered `createdAt DESC`, with
  **`hasDriverPaidToContact` forced to `true`** on a shallow copy (never persisted).
* `/bookings/trip/:tripId` → `PaginatedResult<BookingEntity & {user, seats, trip, chatEnabled: true,
  callEnabled: true}>` ordered `createdAt DESC`, also with `hasDriverPaidToContact: true` forced.
* `/bookings/:id` → the raw `BookingEntity` with `trip` and `seats` relations (no forcing).

**Business rules:**
1. `/bookings/trip/:tripId` requires `trip.driverId === callerId` ⇒ else
   `403 "You are not the owner of this trip"`.
2. `/bookings/:id` requires booking owner **or** trip driver ⇒ else
   `403 "You are not authorized to view this booking"`.
3. Both list endpoints use a real `COUNT` (correct `total`, unlike F-04).
4. The forced `hasDriverPaidToContact: true` and `chatEnabled/callEnabled: true` are deliberate
   backward-compatibility shims for mobile builds that gate their UI on the old contact-payment flag
   (`bookings.service.ts:503-511`, `:560-575`; regression tests at `bookings.service.spec.ts`).
   The admin dashboard reads the real stored flag through `admin-dashboard.service.ts` instead.

**Notes:** `BookingViewerSerializer` (`src/modules/bookings/serializers/booking-viewer.serializer.ts`) is a
no-op seam that also forces `chatEnabled`/`callEnabled` and is **not referenced anywhere** — dead code
retained as a hook for a future access rule.

---

## F-16: Booking acceptance timeout

**What it does:** A pending booking the driver never answers is auto-cancelled after the acceptance window
and its seats return to the pool.

**Actors:** system.

**API Endpoints:** none.

**Background job** (`src/modules/bookings/processors/bookings-timeout.processor.ts`):

| Property | Value |
|---|---|
| Queue | `bookings-timeout` |
| Job name | `expire-booking` |
| Payload | `{ bookingId: string }` |
| Job id | `booking-expire-<bookingId>` |
| Delay | `BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS ?? 10800` seconds |
| Attempts | 3, exponential backoff 5 000 ms |
| removeOnComplete | true |
| Producer | `createMultiSeat` (post-commit, fire-and-forget) |
| Cancelled by | `accept()` and `reject()` (not by legacy `confirm()`) |

**Business rules:**
1. Booking missing ⇒ log and return.
2. `status !== 'pending'` ⇒ no-op (this is what makes the legacy-confirm leak harmless).
3. Otherwise: `status='cancelled'`, reason `"Driver did not respond within the acceptance window"`,
   `cancelledAt = now`, `cancelledBy='system'`.
4. Release every seat of the booking (`releaseSeat` + `seatReleased` emit), best-effort.
5. Push `notifyPassengerOfBookingDecision(bookingId, 'canceled')`.
6. `@OnQueueFailed` logs the failure; after 3 attempts the job is dropped and the booking stays `pending`
   with a past `expiresAt` — nothing re-sweeps it. A rebuild should add a periodic reconciliation over
   `status='pending' AND expiresAt < now()`.

**State machine:** `pending -> cancelled` (system).

---

## F-17: Automatic trip start and the platform-fee debit

**What it does:** At `departureTime` the trip flips to `in_progress` on its own, confirmed bookings follow,
the driver's single platform fee is debited, everyone is pushed a "trip started" notice, and the
auto-complete fallback is armed.

**Actors:** system (no endpoint — there is deliberately no "Start Trip" API).

**API Endpoints:** none.

**Background job** (`src/modules/bookings/processors/trip-auto-start.processor.ts`):

| Property | Value |
|---|---|
| Queue | `trip-auto-start` |
| Job name | `enforce` |
| Payload | `{ tripId: string }` |
| Job id | `trip-auto-start-<tripId>` |
| Delay | `max(0, departureTime - now)` |
| Attempts | 2, exponential backoff 15 000 ms |
| Producers | `TripsService.create`, `TripsService.update` (reschedule), `RecurrenceSpawnProcessor` |
| Removed by | `TripsService.cancel`, `TripsService.update` (before re-add), `TripTimeService.completeTrip` |

**Business rules (processing order is load-bearing):**

1. Trip missing ⇒ warn and return.
2. `status in ('completed','cancelled')` ⇒ return.
3. `status === 'in_progress'` ⇒ only (re)arm the auto-complete fallback, then return.
4. `status not in ('published','fully_booked','active')` ⇒ warn "unexpected status" and return.
5. `status = 'in_progress'`, `tripStartedAt = now`, save.
6. Every booking with `status='confirmed'` on the trip ⇒ `in_progress` (saved one by one, no transaction).
7. `DriverTripFeeService.chargeAtTripStart(trip)` — **wrapped in try/catch; a failure never blocks the
   start.** The trip is left with `driverWalletChargeApplied = false`, which is exactly what the
   reconciliation paths key on.
8. Push `trip_started` (Arabic body) to the driver and every booking owner.
9. If `feeCharge.charged > 0`, push `trip_fee_charged` to the driver with the amount and currency.
10. Arm `trip-auto-complete` (F-18).

**Fee algorithm** (`DriverTripFeeService.chargeAtTripStart`, `driver-trip-fee.service.ts:157-355`):

```
quote.amount = driverUnlockPercent > 0
             ? round2(trip.price * trip.totalSeats * driverUnlockPercent / 100)
             : round2(communication_fees.feeAmount)          // legacy flat
```
Three idempotency layers:
1. `trip.driverWalletChargeApplied === true` ⇒ short-circuit, `applied:false, reason:'already-charged'`.
2. A `wallet_transactions` row with `idempotencyKey = "trip-fee:<tripId>"` exists ⇒ converge on it
   (re-record any shortfall, re-stamp the trip).
3. The unique index on that key catches a racing caller; the loser rolls back and converges.

Inside one DB transaction, with `pessimistic_write` on the driver `users` row and on their `DRIVER`
wallet accounts:
* No booking in `('confirmed','in_progress')` ⇒ write a `0.00` audit row, `reason:'no-bookings'`.
* `driver.hasUsedLifetimeFreeTrip === false` ⇒ set it true, write a `0.00` audit row with
  `freeTripApplied: true, discountPercent: 100`, `reason:'free-trip'`.
* No DRIVER wallet account ⇒ log an error and record nothing (so a later sweep can retry safely).
* Otherwise `charged = round2(min(max(balance,0), quote.amount))`, `remainder = quote.amount - charged`;
  debit the account, mirror the legacy user wallet, and write the audit row
  (`type=trip_debit, direction=debit, status=posted, referenceType='trip', referenceId=tripId,
  metadata={seatPrice,totalSeats,percent,formula,feeAmount,shortfall}`) **even when `charged === 0`**.

After the transaction: `settleShortfall` records any remainder as a `pending_charges` row of kind
`driver_trip_fee` (deduped by `uq_pending_charges_trip_driver_fee`); only if that succeeds does
`stampTripCharged` run — bookings in `('pending','confirmed','in_progress')` get
`hasDriverPaidToContact = true` **first**, then the trip gets `driverWalletChargeApplied = true`,
`driverWalletChargeAt = now`, `communicationFeeStatus = 'paid'`, `capturedFeeAmount = charged`.
A stamp failure rolls the in-memory flags back and is swallowed.

**Reconciliation cron** (`src/modules/driver-trip-fee/driver-trip-fee-reconciliation.job.ts`):
`@Cron('*/30 * * * *')` — every 30 minutes:
```sql
SELECT * FROM trips trip
WHERE trip."driverWalletChargeApplied" IS NOT TRUE
  AND trip."departureTime" <  now() - interval '<GRACE_MINUTES> minutes'
  AND trip."departureTime" >= now() - interval '<LOOKBACK_HOURS> hours'
  AND trip.status NOT IN ('cancelled','draft')
ORDER BY trip."departureTime" ASC
LIMIT <BATCH>;
```
and calls `chargeAtTripStart` on each. Defaults: grace 60 min, lookback 72 h, batch 100. It exists because
a lost Bull job means the trip never starts, never completes, and would otherwise never be charged.

**Data model:** `trips`, `bookings`, `wallet_accounts`, `wallet_transactions`, `pending_charges`, `users`.

**State machine:** `published|fully_booked|active -> in_progress`; bookings `confirmed -> in_progress`.

**Notes for reimplementation:**
* The job fires exactly at `departureTime`, not before, and there is no "driver started early" path.
* A trip whose departure was in the past when it was created gets `delay = 0` and starts immediately.
* Editing `departureTime` re-arms the job; cancelling removes it.
* Booking status flips are individual saves — a crash mid-loop leaves a mixed roster, which the fee logic
  tolerates because it only checks for the *existence* of bookings.

---

## F-18: Trip completion (driver arrival) and the 24 h fallback

**What it does:** The driver marks arrival, optionally declaring no-show seats. Bookings finalise, presence
is settled as a record, share links are shortened, and the lifecycle jobs are cleaned up. If the driver
never presses it, a fallback job forces completion.

**Actors:** driver (owner); system (fallback).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/trips/:id/arrived` | Bearer, role `driver` | Complete the trip |
| POST | `/api/v1/trips/:id/complete` | Bearer, role `driver` | Legacy alias — identical handler |

**Request** (`CompleteTripDto`):
```json
{ "noShowSeats": [ { "bookingId": "<uuid>", "seatNumber": "1-2" } ] }
```
`noShowSeats` optional array; `bookingId` `@IsUUID()`, `seatNumber` `@IsString()`.

**Response:** the re-read `TripEntity` with an extra `settlement` object:
```json
{ "tripId": "...", "billableSeats": 2, "bookedSeats": 3,
  "captured": 8.00, "released": 0, "currency": "JOD", "applied": false }
```

**Business rules** (`TripTimeService.completeTrip`, `trip-time.service.ts:226-386`) — **order is
load-bearing and covered by tests**:

1. Trip must exist ⇒ `404 "Trip not found"`.
2. `trip.driverId === callerId` ⇒ else `403 { message: 'Only the trip driver can complete the trip',
   code: NOT_TRIP_DRIVER }`.
3. `trip.status === 'in_progress'` ⇒ else `400 "Trip must be in progress to mark as arrived"`.
4. `status='completed'`, `tripCompletedAt = now`, save.
5. **Fee reconciliation sweep, before any booking status is touched.** If `!driverWalletChargeApplied`,
   call `chargeAtTripStart` in a try/catch. This must run first because the fee logic decides "is a fee
   owed" by counting bookings in `('confirmed','in_progress')` — the passes below empty that set and the
   sweep would write a `0.00` "no-bookings" audit row and stamp the trip, permanently zeroing the fee it
   exists to recover (`trip-time.service.ts:250-294`).
6. No-show pass: for each `bookingId` in `noShowSeats`, load its `booking_seats`, stamp `markedAbsentAt =
   now` on the listed seat numbers; if **every** seat of that booking is listed, set the booking to
   `no_show` with `driverMarkedAbsentAt = now`.
7. All bookings still `in_progress` ⇒ `completed`.
8. `PresenceService.settleTripPresence(tripId)` (F-19) — bookkeeping only.
9. Notify **every** booking on the trip (any status, including cancelled) with `trip_completed`.
10. `UPDATE trip_share_links SET expiresAt = now + 30 min WHERE tripId = :tripId`.
11. Remove `trip-auto-start-<id>` and `trip-auto-complete-<id>` jobs.
12. Re-read the trip so the response carries the settlement columns; attach `settlement`.

**Fallback job** (`src/modules/bookings/processors/trip-auto-complete.processor.ts`):

| Property | Value |
|---|---|
| Queue | `trip-auto-complete` |
| Job name | `enforce` |
| Payload | `{ tripId }` |
| Job id | `trip-auto-complete-<tripId>` |
| Delay | `max(0, departureTime + max(1, TRIP_AUTO_COMPLETE_FALLBACK_HOURS ?? 24) hours - now)` |
| Attempts | 2, exponential backoff 30 000 ms |
| Producer | `TripAutoStartProcessor.scheduleAutoCompleteFallback` |

Its logic: return unless `status === 'in_progress'`; set `completed` + `tripCompletedAt`; run the same
fee reconciliation **before** flipping bookings (same ordering rationale); flip `in_progress` bookings to
`completed`; `settleTripPresence`; push `trip_auto_completed` to the driver. It does **not** shorten share
links and does **not** remove queued jobs.

**State machine:** `in_progress -> completed` (driver or fallback). Bookings: `in_progress -> completed`,
or `-> no_show` when all their seats were declared absent.

**Errors:** `404` trip not found; `403 NOT_TRIP_DRIVER`; `400` not in progress; `400` DTO validation.

**Notes:** `POST /trips/:id/complete` and `/arrived` are the **only** completion paths. A third path
(`PATCH /trips/:id/legacy-complete` + `TripsService.complete`) was deliberately deleted because it had no
status precondition, skipped the fee sweep and removed the auto-start job — a driver could ride free
(`trips.controller.ts:217-222`, `trips.service.ts:674-680`). Do not reintroduce it.

---

## F-19: Presence confirmation (roster, declarations, settlement)

**What it does:** Both sides record who was actually in the vehicle. The driver edits a seat roster from
30 minutes before departure; passengers self-declare from 60 minutes before to 30 minutes after.
Contradictions are flagged for admin review. Settlement freezes the outcome.

**Actors:** driver (roster + confirm), passenger (prompt + declare), system (settlement).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/trips/:id/presence-roster` | Bearer, role `driver` | Seat roster + fee preview |
| POST | `/api/v1/trips/:id/presence-confirm` | Bearer, role `driver` | Record present/absent per seat |
| GET | `/api/v1/bookings/:id/presence-prompt` | Bearer | Everything the passenger prompt screen renders |
| POST | `/api/v1/bookings/:id/presence-declare` | Bearer | Passenger self-declaration |

*(Note: `TripTimeController` has `@Controller()` with no prefix, so these paths sit directly under the
global prefix — `trip-time.controller.ts:27`.)*

**Request — `POST /trips/:id/presence-confirm`** (`DriverPresenceConfirmDto`):

| Field | Type | Validation | Req |
|---|---|---|---|
| `entries` | array | `@ArrayMinSize(1)`, `@ArrayMaxSize(50)` | yes |
| `entries[].bookingId` | string | `@IsUUID()` | yes |
| `entries[].seatNumber` | string | `@IsString()` | yes |
| `entries[].present` | boolean | `@IsBoolean()` | yes |
| `entries[].reason` | string | `@IsIn(['no_show','cancelled_on_site','wrong_pickup','other'])` | no (defaults to `no_show` when `present=false`) |
| `idempotencyKey` | string | `@IsString()` | no — **accepted and never used** |

**Request — `POST /bookings/:id/presence-declare`** (`PassengerDeclareDto`):

| Field | Type | Validation | Req |
|---|---|---|---|
| `status` | string | `@IsIn(['in_vehicle','on_my_way','not_riding'])` | yes |
| `seatNumbers` | string[] | `@IsString({each:true})` | no — omit to apply to every seat in the booking |

**Response — roster / presence-confirm** (`PresenceService.buildRoster`, `presence.service.ts:101-170`):
```json
{ "tripId": "...", "status": "in_progress", "settled": false,
  "window": { "opensAt": "ISO(departure-30m)", "closesAt": null, "isOpen": true },
  "currency": "JOD", "seatPrice": "20.00", "feePercent": 10,
  "seats": [ { "bookingId": "...", "seatId": "...", "seatNumber": "1-0",
               "displayName": "Layla", "gender": "female", "isMainBooker": true,
               "passengerDeclaredStatus": "in_vehicle|on_my_way|not_riding|null",
               "passengerSelfConfirmedAt": "ISO|null", "autoFlaggedAbsentAt": "ISO|null",
               "absenceReason": "no_show|...|null",
               "driverState": "present|absent|unset",
               "locked": true, "disputed": false, "billable": true } ],
  "summary": { "totalSeats": 4, "bookedSeats": 3, "billableSeats": 2,
               "estimatedFee": "8.00", "maxFee": "8.00" } }
```
Roster rows come from bookings whose status is in `('confirmed','in_progress','completed')`
(`BILLABLE_BOOKING_STATUSES`). `locked = passengerSelfConfirmedAt != null`.
`maxFee = estimatedFee = round2(seatPrice * trip.totalSeats * feePercent / 100)` — both are the *full*
trip fee now that presence no longer scales it.

**Response — presence-prompt** (`presence.service.ts:598-671`):
```json
{ "bookingId": "...", "tripId": "...",
  "driver": { "id": "...", "name": "...", "photoUrl": null, "rating": 4.8, "ratingCount": 12 },
  "vehicle": { "vehicleType": "sedan", "model": "Corolla", "plateNumber": "...", "carImageUrl": null },
  "pickup": { "name": "...", "address": "...", "lat": 31.9, "lng": 35.9 },
  "departureTime": "ISO", "secondsUntilDeparture": 1800,
  "driverLocation": { "lat": 31.9, "lng": 35.9, "updatedAt": "ISO" },
  "seats": [ { "seatNumber": "1-0", "displayName": "Layla", "isMainBooker": true,
               "declaredStatus": null, "selfConfirmedAt": null } ],
  "window": { "opensAt": "ISO(departure-60m)", "closesAt": "ISO(departure+30m)", "isOpen": true } }
```

**Response — presence-declare:**
```json
{ "bookingId": "...", "status": "in_vehicle", "seatNumbers": ["1-0","1-1"], "declaredAt": "ISO" }
```

**Business rules:**

Time windows (`presence.service.ts:39-42`):
```
DRIVER_WINDOW_OPENS_MS      = 30 * 60 * 1000   // opens at departure - 30 min, closes at settlement
PASSENGER_WINDOW_BEFORE_MS  = 60 * 60 * 1000
PASSENGER_WINDOW_AFTER_MS   = 30 * 60 * 1000   // departure - 60 min .. departure + 30 min
```

1. Roster read: owner check ⇒ `403 { code: NOT_TRIP_DRIVER }`.
2. Driver confirm: owner check ⇒ `403 NOT_TRIP_DRIVER`; `trip.presenceSettledAt != null` ⇒
   `409 { code: PRESENCE_ALREADY_SETTLED }`; `now < departure - 30 min` ⇒
   `409 { code: PRESENCE_WINDOW_CLOSED, opensAt }`. There is **no upper bound** other than settlement.
3. Each entry must resolve to a booking on this trip (`400 PRESENCE_SEAT_NOT_FOUND`) and to a seat inside
   that booking (`400 PRESENCE_SEAT_NOT_FOUND`).
4. **Driver decision resolution table** (`applyDriverDecision`, `presence.service.ts:277-306`):
   | Input | Effect |
   |---|---|
   | `present = true` | `presenceConfirmedAt = now`, `markedAbsentAt = null`, `absenceReason = null`, `billableOverride = null` (clears any prior absence, including the passenger's own `not_riding`) |
   | `present = false`, passenger had **not** self-confirmed | `markedAbsentAt = now`, `presenceConfirmedAt = null`, `absenceReason = reason ?? 'no_show'`, `billableOverride = false` |
   | `present = false`, passenger **had** self-confirmed | same stamps **plus** `presenceDisputedAt = now`, `billableOverride = true` (stays billable), seat added to the conflict list |
   Every branch sets `presenceUpdatedAt = now`.
5. After the entries: `syncBookingLevelFlags` recomputes per booking —
   `driverConfirmedPassengerAt = anySeatPresent ? now : null`,
   `driverMarkedAbsentAt = allSeatsAbsent ? now : null`.
6. Conflicts ⇒ `trip.presenceReviewFlagged = true` and an in-app `presence_conflict_admin` notification to
   every admin user.
7. Passenger declare: booking ownership ⇒ `403 "You can only declare for your own booking"`;
   `trip.presenceSettledAt` ⇒ `409 PRESENCE_ALREADY_SETTLED`; outside `[departure-60m, departure+30m]` ⇒
   `409 { code: PRESENCE_WINDOW_CLOSED }`; no matching seats ⇒ `400 PRESENCE_SEAT_NOT_FOUND`.
8. Passenger declaration effects per targeted seat:
   * `in_vehicle` ⇒ `passengerSelfConfirmedAt = now`; if `billableOverride === false` (driver had marked
     absent) ⇒ flip to `true`, set `presenceDisputedAt`, raise a conflict.
   * `on_my_way` ⇒ `passengerSelfConfirmedAt = null` only.
   * `not_riding` ⇒ `passengerSelfConfirmedAt = null`; if the driver has **not** vouched
     (`presenceConfirmedAt == null`) ⇒ `billableOverride = false`,
     `absenceReason = 'cancelled_on_site'`.
   All set `passengerDeclaredStatus` and `presenceUpdatedAt`.
9. Booking-level: `passengerPresenceConfirmedAt = (status === 'in_vehicle') ? now : null`.
10. A `presence_passenger_declared` notification goes to the driver with an Arabic body per status.
11. **Settlement** (`settleTripPresence`, called by F-18 and the fallback processor):
    * Idempotent on `trip.presenceSettledAt`; a second call returns the frozen numbers with
      `applied: false`.
    * `billableSeats = seats.filter(isBillable).length` over the bookings in `BILLABLE_BOOKING_STATUSES`.
    * Writes `presenceSettledAt = now`, `billableSeatCount = billableSeats`, and sets
      `presenceReviewFlagged = true` when there were seats but **zero** billable (driver claimed nobody
      boarded).
    * `captured` is **read back** from `trip.capturedFeeAmount` (written by the fee stamp), never written
      here; `released` is always `0`; `applied` is always `false`. This read-back matters: returning `0`
      would shadow the real fee in the driver's trip summary (`presence.service.ts:553-560`).
    * Notifies every passenger with a seat where `billableOverride === false AND markedAbsentAt != null`
      (`presence_marked_absent`, "you can dispute within 24 hours" — the dispute endpoint itself lives in
      the admin domain).

**External services:** notifications only. No wallet calls.

**Errors:** `403 NOT_TRIP_DRIVER` / ownership; `409 PRESENCE_ALREADY_SETTLED`;
`409 PRESENCE_WINDOW_CLOSED`; `400 PRESENCE_SEAT_NOT_FOUND`; `404` trip/booking not found.

**Notes:** none of this is transactional — seats are saved one at a time inside a loop, and the trip flag
is saved afterwards. Two drivers' devices submitting overlapping rosters can interleave. The
`idempotencyKey` field is accepted but ignored, so retries re-apply (idempotent in effect, since every
write is an absolute assignment of `now`).

---

## F-20: Legacy per-booking presence endpoints

**What it does:** The pre-roster confirmation pair: a passenger reports whether the driver showed up, and
the driver confirms a single seat.

**Actors:** passenger (own booking), driver (trip owner).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/bookings/:id/passenger-confirm` | Bearer | Passenger reports driver presence |
| POST | `/api/v1/bookings/:id/driver-confirm` | Bearer, role `driver` | Driver confirms one seat (legacy alias of F-19) |

**Requests:** `PassengerConfirmDto` `{ "driverPresent": boolean }` (`@IsBoolean()`, required);
`DriverConfirmDto` `{ "seatNumber": string, "present": boolean }` (both required).

**Response:** the saved `BookingEntity`.

**Business rules — passenger-confirm** (`trip-time.service.ts:60-123`):
1. Booking must exist ⇒ `404`; `booking.userId === callerId` ⇒ else
   `403 "You can only confirm your own booking"`.
2. `status in ('confirmed','in_progress')` ⇒ else
   `400 "Booking must be confirmed or in progress to confirm presence"`.
3. Window `[departure - 60 min, departure + 30 min]`; outside ⇒
   `400 { code: TIMING_WINDOW, message: 'Passenger confirmation is only available within 60 minutes
   before to 30 minutes after departure' }`.
4. `driverPresent = true` ⇒ `passengerPresenceConfirmedAt = now`;
   `false` ⇒ `passengerReportedDriverAbsentAt = now`, plus a `passenger_reported_driver_absent` push to
   the driver and an `admin_no_show_report` in-app notification to **every** admin (with `tripId`,
   `bookingId`, `driverId`, `reportedAt`, `bookingsOnTrip` = total booking count on the trip).
   Fines stay manual (`POST /admin/fines`).

**Business rules — driver-confirm** (`trip-time.service.ts:168-220`):
1. Booking must exist ⇒ `404`; `trip.driverId === callerId` ⇒ else
   `403 "Only the trip driver can confirm passenger presence"`.
2. `status in ('confirmed','in_progress')` ⇒ else `400 "Booking must be confirmed or in progress"`.
3. Seat must be in the booking ⇒ else `400 "Seat X not found in this booking"`.
4. `present = true` ⇒ `seat.presenceConfirmedAt = now` and `booking.driverConfirmedPassengerAt = now`;
   `false` ⇒ `seat.markedAbsentAt = now`.
5. If every seat of the booking now has `markedAbsentAt`, set `booking.driverMarkedAbsentAt = now`.
6. **Unlike F-19 it has no window check, no settled check, and never touches `billableOverride`,
   `presenceDisputedAt` or `absenceReason`.** A driver using this endpoint can mark a self-confirmed
   passenger absent with no dispute being raised. Prefer F-19 in a rebuild and keep this only as a
   compatibility shim.

---

## F-21: Live ETA and location denormalisation

**What it does:** While the trip is in progress, driver location pings update the trip row and, at most
every 45 seconds, recompute remaining distance/duration/ETA/progress from a routing provider.

**Actors:** driver (location producer), any authenticated user + anonymous share-link viewers (consumers).

**API Endpoints:** (owned by the tracking domain, but they read/write `trips` columns defined here)

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/tracking/location` | Bearer, role `driver` | Push a location ping (see the tracking spec for the DTO) |
| GET | `/api/v1/tracking/:tripId/latest` | Bearer | Latest location + ETA snapshot |
| GET | `/api/v1/tracking/:tripId/history?limit=` | Bearer | Location history (`limit` clamped 1..500, default 100) |
| GET | `/api/v1/share/:token` | Public | ETA subset without PII (F-09) |

**Business rules** (`src/modules/tracking/tracking.service.ts`):

1. The trip must belong to the posting driver (`where: {id: dto.tripId, driverId}`) ⇒ else
   `404 "Trip not found for this driver"`. **There is no trip-status check** — pings are accepted before
   departure and after completion.
2. Every ping writes a `driver_locations` row and updates `trips.lastDriverLocationLat/Lng/At`.
3. ETA refresh is throttled: skip when `now - etaComputedAt < 45 000 ms` (`ETA_REFRESH_MS`), and skip when
   an in-flight refresh for that trip id is already running (an in-process `Set`, so the guard is per
   instance, not cluster-wide).
4. Routing: `LocationsService.getRoute(fromLat, fromLng, toLat, toLng)` → Google Directions
   (`/directions/json`, `language=ar`); on missing API key, non-`OK` status, or an unusable payload it
   falls back to **OSRM**. On any throw, the refresh is skipped and the previous snapshot stands.
5. Writes `remainingDistanceKm = round(distanceMeters/1000, 2)`,
   `remainingDurationSeconds = max(0, round(durationSeconds))`,
   `etaAt = now + remainingDurationSeconds`,
   `routeProgressPercent`, `etaComputedAt = now`.
6. `routeProgressPercent` is a great-circle approximation, **not** route-following:
   `total = haversine(from, to)`; `remaining = haversine(current, to)`;
   `percent = clamp(0, 100, (total - remaining)/total * 100)` rounded to 1 decimal; `100` when
   `total <= 0.01 km` (`tracking.service.ts:167-203`).
7. `GET /:tripId/latest` merges the last `driver_locations` row with the trip's ETA columns; when no
   location row exists it falls back to the denormalised trip coordinates; returns `null` when neither
   exists. **No authorisation check beyond being logged in** — any authenticated user can watch any trip.

**Data model:** writes `driver_locations` (other domain) and the ETA/location columns of `trips`.

**External services:** Google Directions API (`GOOGLE_MAPS_API_KEY`), OSRM fallback.

---

## F-22: Emergency / SOS alert

**What it does:** A driver or confirmed passenger raises an emergency on an active trip; all subscribed
admins get an alert carrying the trip and the reporter's location.

**Actors:** driver, confirmed/in-progress passenger.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/trips/:id/emergency` | Bearer (any role) | Raise the alert |

**Request** (`TripEmergencyDto`): `latitude?` (`-90..90`), `longitude?` (`-180..180`), both optional and
coerced. Omitted values fall back to `trip.lastDriverLocationLat/Lng`, then `null`.

**Response:**
```json
{ "ok": true, "tripId": "...", "notifiedAt": "ISO" }
```

**Business rules** (`trip-time.service.ts:411-485`):

1. Trip must exist ⇒ `404 "Trip not found"`.
2. Caller must be the driver, or have a booking on the trip with status `confirmed` **or** `in_progress`
   (two separate queries) ⇒ else
   `403 "Only the driver or a confirmed passenger can trigger emergency"`.
3. `trip.status in ('in_progress','published')` ⇒ else
   `400 "Emergency is only available for active trips"`. (`hidden` and `fully_booked` are rejected.)
4. Reporter name is read from `users` (`id`, `name`), trimmed, falling back to `"User"`.
5. `AdminAlertsService.notifyTripEmergency({tripId, reporterUserId, reporterName, fromName, toName,
   latitude, longitude})` → dispatches an `admin_trip_emergency` notification (title
   `"Trip emergency alert"`, body `"<name> triggered emergency on trip <from> → <to> at <lat>, <lng>."`,
   `data.link = "/trips/<tripId>"`) to every admin subscribed to the `trip_emergency` alert type
   (`admin_alert_preferences`, enum value added by migration `1746700000000`).
6. A structured warning is logged: `{"event":"trip.emergency","tripId","userId","latitude","longitude"}`.

**Errors:** `404`; `403`; `400`.

**Notes:** the alert is fire-and-once — no acknowledgement, escalation or repeat. Rate limiting is only the
global throttler.

---

## F-23: Dead, dormant and legacy paths (do not port blindly)

These exist in the codebase but are unreachable, unscheduled, or superseded. Listed so a rebuild does not
faithfully reproduce broken behaviour.

| Item | Location | Status |
|---|---|---|
| Mongoose `Trip` / `Seat` schemas | `src/modules/trips/schemas/*.ts` | Dead. A pre-Postgres model with a different status enum (`active/hidden/completed/cancelled/expired`) and `2dsphere` indexes. Nothing imports them except the dead expiration job. |
| `TripExpirationJob` (`@Cron('*/15 * * * *')`, `active -> expired`) | `src/jobs/trip-expiration.job.ts` | Dead — Mongoose-based and **not registered as a provider in any module**. The `expired` status does not exist in Postgres. |
| `NoShowDetectorProcessor` | `src/modules/bookings/processors/no-show-detector.processor.ts` | Registered as a provider, but **nothing ever enqueues `no-show-detector` / `detect-no-shows`**. If revived it stamps `autoFlaggedAbsentAt` on seats of confirmed bookings whose passenger never declared — advisory only, never billing. |
| `PreTripConfirmProcessor` | `src/jobs/processors/pre-trip-confirm.processor.ts` | Same: no producer for `pre-trip-confirm` / `send-prompts`. Would send `presence_prompt` / `presence_driver_prompt` and stamp `trip.preTripConfirmSentAt`. |
| `RecurrenceSpawnProcessor` cron | `src/jobs/processors/recurrence-spawn.processor.ts` | Processor is live but **has no scheduler** — only the admin `spawn-now` endpoint produces jobs (F-08). |
| `BookingsService.create()` (v1 single-seat) | `bookings.service.ts:145-294` | Dead — no caller. Only writer of `passengerPaymentId` and `trip.seats[].userName`; only place with the duplicate-booking guard. |
| `BookingsService.markAsCompleted()` | `bookings.service.ts:582-588` | Dead — no caller. |
| `TripsService.bookSeat()` | `trips.service.ts:347-372` | Dead — no caller (`releaseSeat` is used). |
| `serializeTrip()` | `src/modules/trips/trips.serializer.ts` | Dead — the `published -> active` compat shim was removed; the function is a pass-through nobody calls. |
| `BookingViewerSerializer` | `src/modules/bookings/serializers/booking-viewer.serializer.ts` | Dead — no caller; kept as a seam. |
| `PATCH /trips/:id/legacy-complete` + `TripsService.complete()` | removed; see `trips.controller.ts:217-222` | Deliberately deleted (free-ride exploit). Do not reintroduce. |
| `trip.status = 'active'` reads | `trip-auto-start.processor.ts:70`, `pre-trip-confirm.processor.ts:38`, `tracking.service.ts:314` | Legacy tolerance. The tracking one is a **live bug** (see F-05). |
| `trip.status` values `draft`, `fully_booked` | enum only | Never written. |
| `trip.noShowMarkedAt`, `trip.driverFeeHoldId`, `booking.settledAt`, `booking.settlementGraceUntil` | entities | Columns exist; nothing in this domain writes them. |
| `walletIdempotencyKey` (v1 booking DTO), `idempotencyKey` (driver presence DTO) | DTOs | Accepted, validated, then ignored. |
| `SearchTripsDto.status` enum list | `search-trips.dto.ts:64` | Stale — excludes `published`, includes non-existent `expired`. |
| `GET /trips/my?status=` | `trips.controller.ts:88` | Parameter accepted and discarded. |
| `ErrorCodes.SEATS_TAKEN` / `GENDER_ADJACENCY_VIOLATION` / `NO_VALID_ARRANGEMENT` | `error-codes.ts:38-51` | Defined, never emitted. |

---

## F-24: Real-time seat/trip events (WebSocket)

**What it does:** Clients viewing a trip get live seat availability changes.

**Actors:** any authenticated socket client.

**Transport:** Socket.IO, namespace `/trips`, CORS `origin: '*'`
(`src/modules/trips/trips.gateway.ts:16-20`). Guards: `WsAuthGuard` (JWT from the handshake, verified with
`JWT_ACCESS_SECRET`) and `WsRateLimitGuard`.

**Client → server messages:**

| Event | Payload | Effect |
|---|---|---|
| `subscribeTripUpdates` | `{ tripId }` | Joins room `trip:<tripId>`; acks `{event:'subscribed', tripId}` |
| `unsubscribeTripUpdates` | `{ tripId }` | Leaves the room; acks `{event:'unsubscribed', tripId}` |

**Server → client events** (emitted to `trip:<tripId>`):

| Event | Payload | Emitted by |
|---|---|---|
| `seatBooked` | `{ tripId, seatNumber, status }` | seat lock (`status:'locked'`), dead-v1 booking (`status:'booked'`) |
| `seatReleased` | `{ tripId, seatNumber }` | seat unlock, booking reject/cancel/timeout |
| `tripUpdated` | `{ tripId, ...data }` | method exists (`emitTripUpdated`) but **has no caller** |

**Business rules / gotchas:**
1. **`createMultiSeat` does not emit `seatBooked`.** Only the dead v1 path and the seat-lock path do, so
   live seat maps never see a v2 booking take seats — they only see releases. A rebuild should emit on
   every seat state change.
2. Subscription is unauthenticated at the trip level: any logged-in user may join any trip room.
3. Membership is tracked in an in-process `Map<userId, Set<tripId>>`, so it does not survive a restart and
   does not work across instances without a Socket.IO adapter (Redis).

---

## 6. Queue inventory for this domain

| Queue | Job name | Payload | Delay / schedule | Attempts / backoff | Producer | Consumer |
|---|---|---|---|---|---|---|
| `trip-auto-start` | `enforce` | `{tripId}` | `departureTime - now` | 2 / exp 15 s | trip create, trip update, recurrence spawn | `TripAutoStartProcessor` |
| `trip-auto-complete` | `enforce` | `{tripId}` | `departureTime + 24 h - now` | 2 / exp 30 s | `TripAutoStartProcessor` | `TripAutoCompleteProcessor` |
| `bookings-timeout` | `expire-booking` | `{bookingId}` | 3 h | 3 / exp 5 s | `createMultiSeat` | `BookingsTimeoutProcessor` |
| `new-trip-fanout` | `fanout` | `{tripId}` | none | 3 / 5 s | trip create, recurrence spawn | notifications domain |
| `recurrence-spawn` | `spawn-occurrences` | `{}` | none | 1 | **admin endpoint only** | `RecurrenceSpawnProcessor` |
| `no-show-detector` | `detect-no-shows` | `{tripId}` | — | — | **none** | `NoShowDetectorProcessor` (dormant) |
| `pre-trip-confirm` | `send-prompts` | `{tripId}` | — | — | **none** | `PreTripConfirmProcessor` (dormant) |

Cron jobs (`@nestjs/schedule`, registered via `ScheduleModule.forRoot()`):

| Cron | Class | Purpose |
|---|---|---|
| `*/30 * * * *` | `DriverTripFeeReconciliationJob` | Charge trips past departure that carry no fee stamp (F-17) |
| `*/15 * * * *` | `TripExpirationJob` | **Dead** — never registered (F-23) |

Job ids are deterministic (`trip-auto-start-<tripId>`, `trip-auto-complete-<tripId>`,
`booking-expire-<bookingId>`), which is what makes cancellation/rescheduling possible. Preserve that
scheme, or provide an equivalent lookup.

---

## 7. Consolidated error catalogue

| HTTP | Domain code (in `error.details`) | Message / trigger | Source |
|---|---|---|---|
| 400 | — | `Departure time must be in the future` | `trips.service.ts:154` |
| 400 | — | `availableSeats must be between 1 and N` | `trips.service.ts:186` |
| 400 | — | `Trip is not active` (seat lock on non-published trip) | `trips.service.ts:408` |
| 400 | — | `Invalid seat number` / `Only available seats can be locked...` / `Only locked seats can be unlocked` | `trips.service.ts:413-441` |
| 400 | — | `Cannot cancel a completed trip` | `trips.service.ts:689` |
| 400 | — | `Cannot book your own trip` | `bookings.service.ts:653` |
| 400 | — | `Trip is not available for booking` | `bookings.service.ts:655,858` |
| 400 | — | `Family booking requires at least 2 seats` | `bookings.service.ts:648` |
| 400 | — | `Exactly one seat must be marked as isMainBooker` | `bookings.service.ts:663` |
| 400 | — | `Seat X does not exist` / `is not available` / `is no longer available` | `bookings.service.ts:671-745` |
| 400 | — | `لا يمكن حجز هذه المقاعد بسبب قواعد الفصل بين الجنسين.` | `bookings.service.ts:687` |
| 400 | — | `لا توجد مقاعد متجاورة متاحة تكفي المجموعة.` / `لا توجد مقاعد متاحة تلبي قواعد الفصل بين الجنسين.` | `bookings.service.ts:886-890` |
| 400 | — | `Not enough available seats` | `bookings.service.ts:859` |
| 400 | — | `Only pending bookings can be accepted/rejected/confirmed` | `bookings.service.ts:946,1013,306` |
| 400 | — | `Booking is already cancelled` / `Cannot cancel a completed booking` | `bookings.service.ts:355-360` |
| 400 | `CANCELLATION_WINDOW_CLOSED` | Driver cancelling a booking inside 24 h (`windowSeconds`) | `bookings.service.ts:376-381` |
| 400 | `TIMING_WINDOW` | Passenger confirm outside `[-60m, +30m]` | `trip-time.service.ts:89-93` |
| 400 | `PRESENCE_SEAT_NOT_FOUND` | Unknown booking/seat in a presence payload | `presence.service.ts:237-251,406-410` |
| 400 | — | `Trip must be in progress to mark as arrived` | `trip-time.service.ts:240` |
| 400 | — | `Emergency is only available for active trips` | `trip-time.service.ts:447` |
| 403 | — | `You must register and get your vehicle approved before creating trips` / vehicle pending approval | `trips.service.ts:112-122` |
| 403 | — | Arabic: driver account under review | `trips.service.ts:126` |
| 403 | `PROFILE_PHOTO_REQUIRED` | Publishing without a profile photo | `trips.service.ts:132` |
| 403 | `OUTSTANDING_CHARGES` | Publishing with unpaid pending charges (`count`, `totalAmount`) | `trips.service.ts:141` |
| 403 | `INSUFFICIENT_BALANCE_FOR_TRIP_FEE` | Wallet cannot cover the trip fee (`balance`, `requiredAmount`, `currency`) | `driver-trip-fee.service.ts:128` |
| 403 | `CANCELLATION_WINDOW_CLOSED` | Editing departure inside 24 h with bookings; driver cancelling a trip inside 24 h | `trips.service.ts:597,706` |
| 403 | `NOT_TRIP_DRIVER` | Completing a trip / reading the roster / confirming presence as a non-owner | `trip-time.service.ts:236`, `presence.service.ts:94,199` |
| 403 | — | `You are not the owner of this trip` / `of this rule` | `trips.service.ts`, `recurrence.service.ts` |
| 403 | — | `Only the trip driver can accept/reject/confirm bookings` | `bookings.service.ts:943,1010,303` |
| 403 | — | `You are not authorized to cancel/view this booking` | `bookings.service.ts:352,703` |
| 403 | — | `You can only confirm/declare/view your own booking` | `trip-time.service.ts:71`, `presence.service.ts:375,605` |
| 403 | — | `Only the driver or a confirmed passenger can trigger emergency` | `trip-time.service.ts:438` |
| 403 | — | `Access denied. Required roles: ...` | `roles.guard.ts:31` |
| 404 | — | `Trip not found` / `Booking not found` / `Recurrence rule not found` / `Trip not found for this driver` | various |
| 409 | `PRESENCE_ALREADY_SETTLED` | Presence write after settlement | `presence.service.ts:205,381` |
| 409 | `PRESENCE_WINDOW_CLOSED` | Driver before `departure-30m`; passenger outside `[-60m,+30m]` | `presence.service.ts:217,393` |
| 200 (!) | — | `{statusCode:404\|403\|410, message}` from the share-link endpoints | `share-links.controller.ts` |

---

## 8. Reimplementation checklist (highest-risk items)

1. **Ordering inside `completeTrip` and the auto-complete processor**: fee sweep *before* any booking
   status change. Getting this wrong silently zeroes the platform fee (covered by
   `trip-time.service.spec.ts`).
2. **Fee idempotency**: trip stamp → audit-row read on `trip-fee:<tripId>` → unique index. All three
   layers are required; the 30-minute reconciliation cron is the net for lost Bull jobs.
3. **Seat state is duplicated** between `trips.seats` JSONB and `booking_seats`. Only `createMultiSeat`
   takes a row lock; every release path does read-modify-write without one. A rebuild should either
   normalise seats into a table with a unique `(tripId, seatNumber)` constraint, or lock uniformly.
4. **No duplicate-booking constraint** exists any more (F-10). Decide deliberately.
5. **`hasDriverPaidToContact` must keep being forced `true`** on `/bookings/my` and `/bookings/trip/:id`
   until pre-ungating mobile builds are gone, while the stored column stays honest for the admin audit view.
6. **Windows and constants**: acceptance 3 h; passenger cancel 12 h (never enforced); driver cancel 24 h
   (enforced); trip edit/cancel 24 h; auto-complete +24 h; driver presence window opens −30 min;
   passenger presence/confirm window −60 min … +30 min; ETA refresh 45 s; recurrence horizon 14 days;
   search candidate caps 2000 / 300 / 500; geo box ±0.1°; nearby default radius 50 km, preferred 80 km,
   tracking 5000 m; share link +6 h, then +30 min after completion.
7. **Seat numbering** is `"{row}-{col}"`, zero-based, row-major, generated from `seatsPerRowList` when
   present. Vehicle templates: sedan `[1,3]`, suv `[2,3]`, van `[2,3,2]`, truck `1x2`, bus `[4,4,4,4,4]`,
   motorcycle `1x1` (`src/modules/vehicles/vehicle-types.ts`).
8. **Currency is derived from the departure country**, not the client
   (`src/common/currency/country-currency.ts`, default `JOD`).
9. **Fix on rebuild** (all documented above): the empty notification loop in `TripsService.cancel`; the
   `total`/`totalPages` bug in non-geo search; `status='active'` in the tracking spatial query; missing
   `seatBooked` emission on v2 bookings; missing recurrence-spawn scheduler; missing re-sweep for
   pending bookings whose timeout job was lost.
