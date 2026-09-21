# Instant (On-Demand) Rides — Design & Implementation Plan

**الرحلات المباشرة (مثل أوبر)** — feature design for adding on-demand ride
requests alongside the existing scheduled-carpool model.

- Status: **Backend Phases 1–2 + mobile UI implemented and working end-to-end.**
  Driver online/offline toggle + heartbeat + incoming-offer accept/decline dialog
  (polling); passenger "اطلب الآن" flow (request → searching → matched, polling);
  on match the passenger opens the existing live-tracking screen (`TripDetailsScreen`);
  completing an instant trip frees the driver's availability lock; all UI
  strings are localized (AR/EN) via the app's l10n; core dispatch/availability/
  currency logic has unit tests (16 passing).
  Remaining: realtime socket gateway (currently polling + FCM push), and deeper
  concurrency/integration tests for the matching loop.
- Author: engineering
- Related: `008-platform-completion` (PostGIS, realtime, bookings v2),
  `009-platform-refinements` (vehicle-type catalog, currency-by-country)

---

## 1. Goal

A passenger requests a ride **now**; the system finds the nearest available
online driver, the driver accepts, and a live-tracked trip starts immediately —
without the driver having to pre-publish a scheduled trip.

This runs **alongside** the current model (driver publishes a scheduled trip →
passengers search & book seats). Both share the same trip/booking/tracking
backbone.

## 2. Scope

**MVP (this design targets MVP first):**

- Driver `online/offline` toggle + idle-location streaming while online.
- Passenger "اطلب الآن" request with pickup + destination.
- Server-side matching to the nearest online driver (sequential dispatch).
- Driver receives an offer card with a countdown; accept / decline.
- On accept: create an `INSTANT` trip + a confirmed booking; live tracking
  reuses the existing `/tracking` gateway.
- Cancellation (passenger or driver) and "no drivers found" handling.
- Fare estimate from distance × per-km rate; currency from pickup country.

**Deferred (Phase 2+):**

- Surge pricing, scheduled-instant ("pick me up in 20 min"), shared instant
  pools, in-app instant payment beyond the existing communication-fee flow,
  driver ratings affecting dispatch order, ETA/heatmap analytics.

## 3. Reuse of existing infrastructure

The platform is ~65% ready; we build on what exists rather than rewrite:

| Capability | Existing asset | Reuse |
| --- | --- | --- |
| Spatial search | `trip.entity.ts` geography points; `tracking.service.ts` `ST_DWithin`/`ST_Distance` | Find nearby online drivers |
| Realtime | `tracking.gateway.ts` (`/tracking`), `trips.gateway.ts` (`/trips`) | Offer push + live location |
| Background jobs | BullMQ processors (`bookings-timeout`, `trip-auto-start`, `no-show-detector`) | Offer/request timeouts |
| Notifications | `notifications.service.ts` (FCM + SMS + in-app) | Wake drivers on offer |
| Bookings | bookings v2 (multi-seat, gender adjacency, timeouts) | Confirmed booking on accept |
| Pricing | `platform-pricing.service.ts`, communication-fee per country | Fare + fee on instant trips |
| Currency | `common/currency/country-currency.ts` (added in 009) | Fare currency from pickup country |
| Distance/ETA | `locations.service.getDistance()` | Fare estimate, ETA |

## 4. Data model changes

### 4.1 Driver availability — `driver_availability` (new entity)

Tracks idle (not-on-trip) drivers so we can match them. Keeping this separate
from `driver_locations` (which is trip-scoped) avoids overloading trip tracking.

| Column | Type | Notes |
| --- | --- | --- |
| `driverId` | uuid PK / FK users | one row per driver |
| `vehicleId` | uuid FK vehicles | resolved once when going online |
| `isOnline` | boolean | toggle |
| `acceptsInstant` | boolean | default true |
| `point` | geography(Point,4326) | last idle location |
| `lastSeenAt` | timestamptz | heartbeat; used for stale-offline detection |
| `currentRequestId` | uuid nullable | set while an offer is outstanding (soft lock) |
| `updatedAt` | timestamptz | |

Index: `GIST(point)` **partial** `WHERE "isOnline" = true AND "currentRequestId" IS NULL`
for fast "available drivers near X" queries.

### 4.2 Instant ride request — `instant_ride_requests` (new entity)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid PK | |
| `passengerId` | uuid FK users | |
| `fromName`/`fromAddress` | varchar | |
| `fromPoint` | geography(Point) | pickup |
| `toName`/`toAddress` | varchar | |
| `toPoint` | geography(Point) | destination |
| `seatCount` | int default 1 | |
| `status` | enum `InstantRequestStatus` | see below |
| `fareEstimate` | numeric | locked at request time |
| `currency` | varchar(5) | from pickup country |
| `radiusKm` | numeric | current search radius (expands) |
| `matchedDriverId` | uuid nullable | set on accept |
| `tripId` | uuid nullable | the created INSTANT trip |
| `expiresAt` | timestamptz | overall request deadline |
| `createdAt` | timestamptz | |

### 4.3 Dispatch offers — `instant_ride_offers` (new entity)

One row per (request, driver) offer — supports sequential dispatch, retries,
and analytics.

`id, requestId, driverId, status (OFFERED|ACCEPTED|DECLINED|TIMED_OUT),
offeredAt, respondedAt, expiresAt`.

### 4.4 Trip linkage

Add to `trip.entity.ts` + `shared.enums.ts`:

- `tripType: TripType` enum = `SCHEDULED | INSTANT` (default `SCHEDULED`, so
  existing rows/queries are unaffected).
- Instant trips: `departureTime = now`, `status = IN_PROGRESS` (or a new
  `MATCHED` pre-state), single booking, excluded from the public search/`/trips`
  listing (filter `tripType = SCHEDULED` in search queries).

### 4.5 New enums (`shared.enums.ts`)

```ts
export enum TripType { SCHEDULED = 'scheduled', INSTANT = 'instant' }
export enum InstantRequestStatus {
  SEARCHING = 'searching',
  OFFERED = 'offered',
  ACCEPTED = 'accepted',
  NO_DRIVERS = 'no_drivers',
  EXPIRED = 'expired',
  CANCELLED = 'cancelled',
}
```

## 5. Backend module: `modules/instant-rides`

### 5.1 Endpoints (`instant-rides.controller.ts`)

| Method | Path | Role | Purpose |
| --- | --- | --- | --- |
| `POST` | `/instant-rides/requests` | passenger | Create a request (returns fare estimate + request id) |
| `GET` | `/instant-rides/requests/:id` | passenger | Poll status (fallback to socket) |
| `DELETE` | `/instant-rides/requests/:id` | passenger | Cancel during search |
| `POST` | `/instant-rides/availability` | driver | Go online/offline + set acceptsInstant |
| `POST` | `/instant-rides/offers/:id/accept` | driver | Accept an offer |
| `POST` | `/instant-rides/offers/:id/decline` | driver | Decline |

Driver location while online streams over the **existing** `/tracking` socket
(new event `driver:availability:location`) rather than HTTP, to avoid chatty
requests.

### 5.2 Service responsibilities

- `InstantRidesService`: request lifecycle, fare estimate, accept/decline,
  trip+booking creation on accept.
- `DriverAvailabilityService`: online/offline, heartbeat, nearest-available
  query (`ST_DWithin` + `ST_Distance` ordering, reusing tracking patterns).
- `InstantDispatchService`: the matching loop (below).

### 5.3 Gateway (`instant-rides.gateway.ts`, namespace `/instant`)

Events:
- to driver: `instant:offer` (request summary + countdown), `instant:offer:cancelled`.
- to passenger: `instant:searching`, `instant:matched` (driver+vehicle+ETA),
  `instant:no_drivers`, `instant:driver:enroute` (reuses tracking updates).

### 5.4 Processors (BullMQ)

- `instant-offer-timeout`: if a driver doesn't respond within N seconds
  (e.g. 12s), mark offer `TIMED_OUT`, free the driver, dispatch to the next.
- `instant-request-expiry`: if no driver accepts within the overall window
  (e.g. 90s) or radius exhausted, mark request `NO_DRIVERS`, notify passenger.

## 6. Matching algorithm (sequential dispatch — MVP)

1. On request: compute fare estimate; set `status=SEARCHING`,
   `radiusKm=initial` (e.g. 3 km), `expiresAt=now+90s`.
2. Query available drivers: `isOnline AND currentRequestId IS NULL AND
   acceptsInstant`, within `radiusKm` of pickup, ordered by distance. Exclude
   drivers who already declined/timed-out on this request.
3. Take the nearest driver, soft-lock (`currentRequestId=requestId`), create an
   `OFFERED` offer, emit `instant:offer` + push, enqueue `instant-offer-timeout`.
4. On **accept** → see §7. On **decline/timeout** → free the driver, go to (2).
5. If no candidates in radius: expand radius (e.g. +3 km up to a max of 10 km).
   If radius maxed or `expiresAt` passed → `NO_DRIVERS`.

**Why sequential first:** simplest correct behavior, no double-booking, easy to
reason about. Broadcast / first-to-accept dispatch is a Phase 2 optimization
(needs an atomic "first accept wins" lock).

**Race safety:** acceptance must be atomic — a single UPDATE that flips the
offer to `ACCEPTED` only if still `OFFERED`, inside a transaction that also sets
the request to `ACCEPTED`. Losers get `instant:offer:cancelled`.

## 7. On accept — trip & booking creation

Inside one transaction:
1. Mark offer `ACCEPTED`, request `ACCEPTED`, set `matchedDriverId`.
2. Create an `INSTANT` `TripEntity` (departureTime=now, from/to from request,
   single seat-occupied, `status=IN_PROGRESS`, `currency` from request,
   `tripType=INSTANT`, not visible in public search).
3. Create a `CONFIRMED` booking for the passenger (reuse bookings v2 path).
4. Clear `currentRequestId` semantics → driver now bound to the trip.
5. Emit `instant:matched` to passenger; start tracking via existing `/tracking`.
6. Apply the communication-fee record as for scheduled trips (per country).

From here the live trip is **identical** to a scheduled trip in progress, so
in-trip tracking, chat, completion, and no-show flows all reuse existing code.

## 8. Mobile UX (Flutter)

**Passenger** (`screens/passenger/`):
- Entry point: a prominent "اطلب رحلة الآن" button on the home/search screen.
- Pickup (defaults to current GPS) + destination via the existing
  `LocationAutocompleteField`.
- Show fare estimate + "تأكيد الطلب".
- Searching state: map with a radar/animation; cancel button.
- Matched state: driver card (name, photo, car, plate, ETA) → live map (reuse
  the existing tracking map widget).
- No-drivers state: retry / switch to scheduled trips.

**Driver** (`screens/driver/` + `driver_home_content.dart`):
- "متصل/غير متصل" toggle; while online, the app streams location over the
  tracking socket (foreground; background is a later hardening step).
- Incoming offer = full-screen/bottom-sheet card with pickup, distance, fare,
  and a countdown ring → "قبول" / "رفض".
- On accept → navigate to the in-trip screen (reused).

New services: `InstantRideService` (passenger requests), extend the tracking
service for the availability location stream.

## 9. Pricing & currency

- Fare estimate = base + (distanceKm × perKmRate) + (durationMin × perMinRate),
  using `locations.service.getDistance()`; clamp to a sensible minimum.
- Rates configured per country (extend the communication-fee/pricing config or
  a new `instant_pricing` table).
- `currency` = `currencyForCountry(pickupCountry)` (reuse 009's map). The
  pickup country is reverse-geocoded once at request creation (same approach as
  scheduled-trip currency).
- Fee handling mirrors scheduled trips (communication-fee per country).

## 10. Edge cases & failure handling

- **No drivers / all decline / radius exhausted** → `NO_DRIVERS`, passenger
  prompted to retry or browse scheduled trips.
- **Passenger cancels mid-search** → cancel outstanding offer, free driver.
- **Driver goes offline / app killed after accept** → trip falls back to the
  existing no-show / cancellation flow; heartbeat staleness marks idle drivers
  offline (`lastSeenAt` older than threshold excluded from matching).
- **Double accept** → atomic offer transition (only one wins).
- **Location spoofing** → reuse the existing `LocationGuard` interceptor.
- **Passenger has an active request already** → reject a second concurrent
  request (one `SEARCHING/OFFERED/ACCEPTED` per passenger).
- **Outstanding driver charges** → same guard as scheduled trips (block
  going online or accepting if unsettled fees, reuse `pendingChargesService`).

## 11. Security & abuse

- Rate-limit `POST /requests` per passenger.
- Driver must be `isDriverApproved` + have a verified vehicle to go online.
- One active request per passenger; one outstanding offer per driver.

## 12. Migrations

1. `create_driver_availability` (+ partial GIST index).
2. `create_instant_ride_requests` (+ GIST on `fromPoint`).
3. `create_instant_ride_offers`.
4. `add_trip_type_to_trips` (enum + column, default `scheduled`; backfill
   existing rows to `scheduled`).
5. Update public trip-search queries to filter `tripType = 'scheduled'`.

## 13. Phased rollout / task breakdown

- **Phase 0 — Design** (this document). ✅
- **Phase 1 — Availability** (backend ✅): `driver_availability` entity +
  migration, online/offline + heartbeat endpoints, nearest-driver query.
  Driver toggle UI still pending.
- **Phase 2 — Request & dispatch** (backend ✅): request/offer entities +
  migrations, `tripType` on trips, fare estimate, sequential dispatch with
  radius expansion + soft-locking, offer-timeout & request-expiry processors,
  accept/decline, instant trip + confirmed booking on accept. Driver push +
  client polling stand in for the realtime gateway.
- **Phase 3 — Realtime UX**: passenger searching/matched/no-driver screens,
  driver offer card, live tracking wiring (+ optional `/instant` socket gateway).
- **Phase 4 — Pricing & fees**: per-country instant rates, fee integration.
- **Phase 5 — Hardening**: cancellation matrix, stale-offline detection, abuse
  limits, background location, tests (unit + e2e for matching/race).

## 14. Open questions (decide before Phase 1)

1. **Dispatch strategy:** sequential (MVP, recommended) vs broadcast first-to-accept?
2. **Fare model:** fixed estimate locked at request, or final fare recomputed on
   completion from actual distance?
3. **Instant seats:** single passenger only, or allow `seatCount > 1` /
   shared instant pools?
4. **Search bounds:** initial radius, max radius, overall timeout, per-offer
   timeout — exact values.
5. **Fees/payment:** does the existing communication-fee model apply unchanged to
   instant trips, or do instant rides need a different fee/commission?
6. **Offline detection:** heartbeat interval and stale threshold.
7. **Geography:** which countries/cities launch instant first (affects driver
   liquidity and the `LOCATION_AUTOCOMPLETE_COUNTRIES` scope)?

## 15. Rough effort estimate

| Phase | Backend | Mobile | Notes |
| --- | --- | --- | --- |
| 1 Availability | M | S | new entity + query + toggle |
| 2 Request & dispatch | L | M | matching loop + processors + race safety |
| 3 Realtime UX | S | L | new screens + socket wiring |
| 4 Pricing & fees | M | S | per-country rates |
| 5 Hardening | M | M | tests, edge cases, background loc |

(S/M/L = small/medium/large.) Phase 2 is the critical, highest-risk piece
(concurrency + matching correctness) and should carry the most test coverage.
