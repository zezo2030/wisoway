# 011 — Instant Ride (Direct Ride-Request) Redesign: inDrive-Class Experience

**Status:** Agreed plan — ready for implementation
**Date:** 2026-07-13
**Authors:** Claude (Fable 5, orchestrator) + OpenAI Codex (GPT‑5 via Codex CLI, consulted reviewer) — two-round collaboration; all positions below are jointly agreed.
**Reference UX:** inDrive iOS (studied via Mobbin: booking flow, driver-offer flow, best-offer ranking, choose-on-map, matched/arriving states)
**Supersedes/extends:** `specs/010-instant-rides/design.md` (Phases 0–2 shipped; this plan replaces its Phase 3+ roadmap)

---

## 1. Goal

Evolve the current instant-ride MVP (server-priced, sequential dispatch, polling-only, minimal UI)
into an inDrive-class direct ride-request experience:

- **Passenger-priced fares** — the passenger proposes the fare, seeded by a server recommendation.
- **Fast, reliable matching** — realtime delivery (socket + FCM), adaptive dispatch waves, raise-fare nudges.
- **Trust surfaces** — matched driver/vehicle card with rating, plate, ETA, and immediate masked Call/Chat.
- **Driver bidding** (later release) — drivers accept at the passenger's fare or counter-offer; the passenger picks from bid cards.

The scheduled-carpool marketplace is untouched; both flows continue to share trips/bookings/tracking/chat.

---

## 2. Current state (audited 2026-07-13)

What exists and works end-to-end today (spec 010, Phases 0–2):

- **Backend** `rideshare-backend/src/modules/instant-rides/`: `driver_availability` (online toggle,
  heartbeat, PostGIS point, `currentRequestId` soft lock), `instant_ride_requests`
  (`searching → offered → accepted | no_drivers | expired | cancelled`), `instant_ride_offers`
  (12s exclusive offer via BullMQ timeout), sequential nearest-first dispatch with radius expansion
  3→6→10 km, 90s request TTL, server-computed fare `max(1.5, 1.0 + km×0.5 + min×0.1)` with
  currency from pickup country, first-accept-wins transaction creating an `INSTANT` trip
  (`IN_PROGRESS`, `isVisible=false`) + confirmed booking.
- **Mobile** `rideshare/lib/`: passenger `instant_ride_request_screen.dart` (map + sheet, GPS pickup,
  Photon autocomplete, route polyline, searching spinner, 3s polling, match → generic
  `TripDetailsScreen`); driver `driver_availability_card.dart` (online toggle, 12s heartbeat,
  4s offer polling **only while the card is mounted**, 12s-countdown offer dialog).

### Confirmed defects and gaps (both reviewers verified in code)

| # | Issue | Where |
|---|-------|-------|
| D1 | Accepted request stays `accepted` forever; `createRequest` treats `accepted` as active → passenger can never make a second instant request | `instant-rides.service.ts` |
| D2 | Generic driver cancellation rejects instant trips (`departureTime = now` is always inside the 24h scheduled-cancellation window) | `trips.service.ts:666` |
| D3 | Going offline clears `currentRequestId` even during an outstanding offer or accepted assignment | `driver-availability.service.ts` |
| D4 | `EXPIRED` status exists but is never written; expiry is reported as `NO_DRIVERS` | expiry processor |
| D5 | No DB uniqueness constraints for one-active-request-per-passenger or one offer per (request, driver, revision) | migrations |
| D6 | Concurrent `dispatchNext` calls can lock different drivers; `makeOffer` ignores whether the conditional request-status update succeeded | `instant-dispatch.service.ts` |
| D7 | Driver acceptance shows only a toast — no navigation to the trip | `driver_availability_card.dart` |
| D8 | Public trip search excludes instant trips only via `isVisible=false`, not the explicit `tripType='scheduled'` filter required by design 010 §12.5 | `trips.service.ts:415` |
| D9 | No mobile FCM handler for any `instant_*` push type; the entire lifecycle is polling-driven and dies when screens unmount | `rideshare/lib` (absent) |
| D10 | Call/Chat are fee-gated (`booking.hasDriverPaidToContact` / `trip.driverWalletChargeApplied`); the instant match transaction creates neither, so contact would be locked on a matched ride | `calls.service.ts:48`, `chat-postgres.service.ts:61` |
| D11 | No fare shown before submit; passenger cannot influence price; no driver card on match; `seatCount` hardcoded to 1; `acceptsInstant` not exposed; no route-specific rate limits | mobile + backend |

---

## 3. inDrive UX reference (Mobbin findings)

The patterns we are adopting, in flow order:

1. **Home entry:** full-screen map with pickup pin + one search field ("Where to & for how much?") + recent destinations.
2. **Route entry:** From/To sheet with autocomplete and **Choose on map** (draggable pin picker + Done).
3. **Offer sheet:** route pinned on map; fare **stepper (− / +)** seeded with "Recommended fare: X";
   auto-accept toggle ("Auto-accept an offer of X up to 5 min away"); primary **Find a driver** CTA.
   (Vehicle classes Ride/Comfort/Moto shown per-class prices — deferred to R3.)
4. **Searching:** map stays live; social proof ("11 drivers viewed your request" + avatars); nudge
   card "Try raising your fare — [Raise to X] [Keep Y]"; Cancel request.
5. **Driver offers:** stacked bid cards over the map — photo, rating + ride count, vehicle, "4 min • 1 km",
   price (your fare or counter-offer), per-card Accept/Decline, ~40s countdown, "best offer" ranking
   (arrival, price, vehicle, rating); tap → driver profile with reviews.
6. **Matched:** "Driver is arriving in ~N min", plate card, Contact driver + Safety, pickup notes, payment row.

Deliberate deviations for our market (agreed):

- **Adaptive micro-batch dispatch instead of full broadcast** — Jordan's early driver pool is small;
  waves of 1–2 drivers give most of the latency benefit without spamming every driver (inDrive itself
  degrades toward auto-accept in low-density markets).
- **Social-proof counts must be real** (actual `viewedAt` records) — never fabricated.
- **Service classes deferred** — the 009 vehicle-type catalog describes physical types (sedan/SUV/van),
  not service tiers; mapping them 1:1 would be wrong. R3 introduces a proper `instant_service_classes` concept.

---

## 4. Target architecture

### 4.1 Request lifecycle (new)

```
searching ──────────────► matched ──► completed
    │        (R2 only)       ▲
    ├──► collecting_bids ────┘
    ├──► cancelled
    └──► expired            terminalReason: no_eligible_drivers | all_declined | passenger_cancelled | ttl_expired
```

- `offered` is **removed** from request status — invitation state lives on the invitations table.
  In R1 (sequential, no visible bids) the request stays `searching` while invitations are outstanding.
- `collecting_bids` activates only with the R2 bidding flag, and means **≥1 active driver bid exists**
  (not merely an invitation).
- "No drivers" is not a status: it is `expired` + `terminalReason=no_eligible_drivers|all_declined`;
  mobile maps these to the "no driver available" UI.
- On trip completion/cancellation the linked request transitions to `completed`/`cancelled` in the
  same workflow (fixes D1).

### 4.2 Schema changes

**`instant_ride_requests`** — add (keep `fareEstimate` temporarily for client compatibility):

| Column | Type | Purpose |
|---|---|---|
| `recommendedFare` | numeric(10,2) | server recommendation at quote time |
| `passengerFare` | numeric(10,2) | current passenger asking fare (TOTAL ride fare) |
| `acceptedFare` | numeric(10,2) NULL | immutable final fare |
| `fareRevision` | int default 1 | re-dispatch + stale-bid protection |
| `quotedDistanceMeters` / `quotedDurationSeconds` | int | auditable route snapshot |
| `pricingVersion` | varchar(32) | pricing config used |
| `serviceClass` | varchar(24) default 'ride' | future tier (R3) |
| `autoAcceptMaxEtaSeconds` | int NULL | NULL = auto-accept off (R2) |
| `matchedBidId` | uuid NULL | selected bid (R2) |
| `bookingId` | uuid NULL | needed for Call/Chat + matched response |
| `version` | int default 1 | optimistic updates / ordered events |
| `terminalReason` | varchar(32) NULL | see §4.1 |
| `acceptedAt` / `cancelledAt` / `completedAt` | timestamptz NULL | lifecycle audit |

```sql
CREATE UNIQUE INDEX uq_instant_requests_passenger_active
ON instant_ride_requests ("passengerId")
WHERE status IN ('searching', 'collecting_bids', 'matched');
```

**`instant_ride_offers`** — reinterpreted as **dispatch invitations**; add `fareRevision`,
`pickupDistanceMeters`, `pickupEtaSeconds`, `viewedAt`, `responseType (accepted_fare|countered|declined)`,
`deliveryChannel (socket|fcm|poll)`, and:

```sql
CREATE UNIQUE INDEX uq_instant_invitation_driver_revision
ON instant_ride_offers ("requestId", "driverId", "fareRevision");
```

**`instant_ride_bids`** — new table, created in R0 even though bid UI ships in R2:

```
id, requestId, invitationId, driverId, vehicleId,
amount numeric(10,2), currency varchar(5), fareRevision int,
pickupDistanceMeters int, pickupEtaSeconds int,
status active|selected|rejected|withdrawn|expired|cancelled,
expiresAt, createdAt, updatedAt
```

Notes: pickup ETA/distance are **server-computed** from trusted availability data, never
driver-authored. Add missing FKs (`matchedDriverId`, `tripId`, `bookingId`, `vehicleId`, availability
lock) and an **expiry timestamp on the driver lock** so crashed jobs can't reserve drivers forever.

### 4.3 The matching primitive

Extract a single transactional operation used by every match path (R1 driver-accept, R2 passenger
bid-accept, R2 auto-accept):

```
matchRequest(requestId, driverId, vehicleId, acceptedFare, bidId?)
```

One transaction: (1) conditionally claim the open request + available driver; (2) revalidate expiry,
`fareRevision`, vehicle capacity, driver eligibility; (3) create INSTANT trip + booking;
(4) store `acceptedFare`, `matchedBidId`, `bookingId`, timestamps; (5) cancel competing
invitations/bids and release their reservations; (6) apply the contact-unlock record (§4.5);
(7) return the canonical matched view.

### 4.4 API surface

```
POST  /instant-rides/quotes                     → recommendedFare, bounds, route metrics, currency,
                                                  pricingVersion, short-lived signed quoteToken
POST  /instant-rides/requests                   → body includes quoteToken + passengerFare
PATCH /instant-rides/requests/:id/fare          → requires expectedFareRevision; atomically bumps
                                                  revision, invalidates stale bids, schedules new wave
GET   /instant-rides/requests/:id               → canonical state incl. match{} and nudge{} blocks
GET   /instant-rides/requests/:id/bids          → R2
POST  /instant-rides/offers/:id/respond         → { responseType: accepted_fare | countered | declined, amount? }
POST  /instant-rides/requests/:rid/bids/:bid/accept    → R2 (calls matchRequest)
POST  /instant-rides/requests/:rid/bids/:bid/decline   → R2
```

- Quote validation rule (agreed): server always revalidates bounds on request creation; a missing or
  expired `quoteToken` triggers a silent server-side re-quote — but the server **never silently
  changes the fare the passenger authorized**. If revalidation moves `passengerFare`, respond with
  the refreshed quote and `fareAdjusted=true` so the client re-confirms before dispatch.
- Matched payload enriches `GET /requests/:id` (no separate endpoint):
  `match: { tripId, bookingId, acceptedFare, pickupEtaSeconds, driver{...}, vehicle{...} }`.
- Nudge payload is **server-owned** (see §4.6): `nudge: { suggestedFare, reason, fareRevision }`.
- Rate limits (route-specific; a 200 req/min global throttle already exists): ~3 request-creations/min,
  15–20 quotes/min, 6 fare-changes/min, plus idempotency keys on creation/acceptance.

### 4.5 Contact (Call/Chat) policy — resolved product decision

A matched instant ride must **never** have contact locked. `matchRequest()` atomically creates an
idempotent instant communication-fee obligation and unlock record (explicit `contactUnlockedAt`):
debit the driver's wallet immediately when possible; otherwise record the debt (pending-charges
model) and block future availability until settled. Note the existing `pending_charges` table
represents penalties today — the instant fee needs its own obligation/payment path, not a penalty
row. If product later wants instant rides fee-free, that is a config change to the fee amount, not a
flow change. Raw phone numbers stay hidden — masked call + in-app chat only.

### 4.6 Dispatch — adaptive waves (replaces both sequential-only and broadcast-5)

1. Eligible pool = online, `acceptsInstant`, unlocked, fresh heartbeat, `vehicle.seats ≥ seatCount`,
   within current radius (excluding drivers already invited **at this `fareRevision`**).
2. Wave size: 1 driver if pool = 1; micro-batch of 2 if pool ≥ 2. Next wave fires after the
   configured interval if no acceptance (R1) / no bid (R2).
3. Radius expands as today (3→6→10 km) but waves are **scheduled through BullMQ**, not swept
   synchronously — the request stays open until its TTL unless policy says retry is useless.
4. Raising the fare (`fareRevision`++) re-qualifies previously declined/timed-out drivers.
5. All knobs (wave size, interval, invitation TTL, radius steps, request TTL) are config, not code.

**Timing (agreed):** invitation TTL 12s → **20s** (R1 sequential); bid TTL **30–40s** (R2);
request TTL 90s → **120–180s** (configurable).

**Nudge trigger (server-owned):** emitted when (a) ≥1 full wave elapsed with no acceptance/bids, or
(b) all candidates at the current radius/revision are exhausted while request TTL remains. Client
only renders it; nudge actions carry `fareRevision` to reject stale taps.

### 4.7 Realtime delivery (layered)

Polling math that forced this decision: at 4s polling, average detection delay ≈ 2s (17% of a 12s
TTL), worst case ≈ 33% — before HTTP latency and dialog rendering. Drivers effectively get 7–12s to
read a route and decide. Hence:

- **Socket.IO `/instant` namespace** — primary foreground path. Authenticated user rooms +
  authorized request subscriptions. Reuse token validation from the `/tracking` gateway but verify
  handshake auth explicitly (class-level WS guards don't necessarily cover `handleConnection`).
  Events: `instant:request:updated`, `instant:invitation:new`, `instant:invitation:cancelled`,
  `instant:bid:new`, `instant:bid:updated`, `instant:matched`.
- **FCM** — background/terminated wake-up + deep link (driver → offer sheet, passenger → request screen).
- **HTTP GET** — canonical resync on reconnect/app-resume; socket/FCM payloads carry ids + `version`
  and clients fetch the canonical state.
- **Polling** — only while the socket is disconnected; poll immediately on fallback, not after the
  first periodic tick.

**Mobile ownership:** a new app-scoped `InstantRideCoordinator` (Bloc/service above screen level)
owns the socket, FCM events, resume resync, and offer presentation — offers must surface even when
`DriverAvailabilityCard` is unmounted (fixes D9's structural cause).

---

## 5. Releases

### R0 — Correctness + bid-ready foundation (invisible; 0.5–1 sprint)

Backend-only, independently deployable, no visible product change.

- Lifecycle/status migration (§4.1) incl. request `completed`/`cancelled` transitions on trip end (D1).
- Instant-specific cancellation policy — instant trips bypass the 24h scheduled window (D2).
- Availability-lock hygiene: don't clear `currentRequestId` on offline during an active assignment;
  lock expiry timestamp (D3).
- Write `expired` + `terminalReason` correctly (D4).
- Constraints, FKs, idempotency keys, unique active-request and (request, driver, revision) indexes (D5).
- Fix dispatch races: conditional-update results checked, single-flight `dispatchNext` (D6).
- Bid-capable schema (§4.2) including `instant_ride_bids`, fare columns, `fareRevision` — behind the scenes.
- Extract `matchRequest()` (§4.3); current accept endpoint calls it.
- Contact-fee obligation + unlock path (§4.5) behind rollout config (D10).
- `tripType='scheduled'` filter on every public search/nearby path (D8).
- **Release-blocking concurrency E2E tests:** duplicate active request, single winner under
  competing accepts, accept-vs-timeout/cancel races, lock cleanup.

### R1 — Passenger-priced sequential product (~1 sprint, backend + mobile in parallel)

The visible inDrive-parity release (minus bidding):

- `POST /quotes` + fare **stepper** seeded with the recommendation on the request sheet (total-fare
  semantics); distance/duration shown pre-submit.
- `PATCH /fare` + server-driven **raise-fare nudge** UI ("Raise to X / Keep Y").
- Request TTL 120–180s; **scheduled dispatch waves** (sequential or flagged 2-driver micro-batch);
  20s invitations.
- **`/instant` Socket.IO gateway** + FCM deep links + resume reconciliation; app-scoped
  `InstantRideCoordinator` on mobile (replaces per-widget polling).
- **Matched driver sheet**: photo, name, rating, vehicle, plate, pickup ETA, immediate masked
  Call/Chat, then "Track ride" → `TripDetailsScreen`.
- **Driver side:** offer sheet shows the passenger's fare; post-accept navigation to the trip screen
  (D7); `acceptsInstant` toggle; heartbeat/poll ownership moves to the coordinator.
- Party-size selector (1–4) with capacity-aware matching (`vehicle.seats ≥ seatCount`, revalidated
  in `matchRequest`).
- Route-specific throttles, cancel confirmation dialog.
- AR/EN localization for every new string; RTL-checked layouts.

### R2 — Adaptive driver bidding (1–2 sprints)

- Driver **accept-at-fare or counter-offer** UX (`/offers/:id/respond` with `countered` + amount bounds, e.g. ≤ +50%).
- `collecting_bids` status + passenger **bid cards** over the map (photo, rating, rides, vehicle,
  server-computed "N min • X km", price, per-card Accept/Decline, 30–40s countdown) + bid
  details/driver profile view.
- Adaptive micro-batch fan-out at full strength; ranking by ETA, fare, vehicle eligibility, rating
  ("best offer" card + "how we choose" explainer).
- **Auto-accept** toggle: first exact-fare bid within `autoAcceptMaxEtaSeconds` triggers `matchRequest` automatically.
- Real viewed counts (`viewedAt`) for "N drivers viewed your request" — never fabricated.
- Multi-instance socket tests + higher-contention DB tests.

### R3 — Service classes (0.5–1 sprint, optional)

- New `instant_service_classes` (id, label AR/EN, fare multiplier, capacity, eligibility policy) —
  explicitly **not** a 1:1 mapping of the 009 vehicle-type catalog; vehicles map into classes via
  policy (model/year/type/rating).
- Per-class quotes and class-aware dispatch; class picker on the offer sheet (inDrive's
  Ride/Comfort pattern).

---

## 6. Risks (agreed top 5)

| Risk | Mitigation |
|---|---|
| Races → duplicate requests, multiple winners, stranded driver locks | Partial unique indexes, conditional updates in one transaction, lock expiry, idempotency keys, real PostgreSQL/BullMQ concurrency tests (release-blocking in R0) |
| Low liquidity makes bidding look empty / slows matching | Adaptive micro-batches, exact-fare auto-accept, per-city feature flags, rollout metrics (eligible drivers, view rate, response rate, time-to-match, fare revisions) |
| Foreground/background delivery gaps expire offers unseen | App-scoped coordinator, socket-primary + FCM wake + resume fetch, disconnect-triggered immediate poll, longer configurable TTLs |
| Passenger pricing enables baiting / stale bids / inconsistent totals | Server quotes + bounds, decimal money types, `fareRevision`, immutable `acceptedFare`, pricing-version audit, `fareAdjusted` re-confirmation, only `acceptedFare` flows into trip/booking totals |
| Scheduled-trip assumptions break instant cancellation/capacity/contact/safety | Explicit instant lifecycle policy, capacity checks at dispatch and match, atomic contact unlock (§4.5), request updates on trip completion/cancellation, end-to-end matched-journey tests |

---

## 7. Success metrics

- Time-to-match p50/p90; match rate (< 90s vs no-driver rate).
- Invitation response rate (viewed → responded) and offer-expiry-unseen rate (should → ~0 with realtime).
- Fare-revision usage and delta between recommended and accepted fares.
- Passenger repeat usage of instant rides; driver online hours / `acceptsInstant` opt-out rate.
- Zero duplicate-match incidents; zero contact-locked matched rides.

## 8. Open items (deferred, non-blocking)

- Payment methods beyond cash (payment row on matched sheet is display-only for now).
- Pickup-notes-to-driver field (inDrive has it; cheap to add in R1 if desired — needs a `notes`
  column on requests and display in the driver offer sheet).
- Safety button parity (exists in inDrive matched state; our safety surface ships with the shared
  trip screen — revisit after R1).
- Surge/dynamic pricing and scheduled instant rides (city-to-city style) — out of scope (010 §2 deferred list).

---

*Collaboration record: Round 1 — Claude proposed a 3-phase plan (UX parity → broadcast bidding →
vehicle classes); Codex counter-proposed a correctness-first R0, bid-ready schema before bid UI,
adaptive micro-batch fan-out over broadcast, socket-in-R1, and flagged the contact-fee gate and six
lifecycle defects. Round 2 — Claude accepted the counter-proposal with 8 clarified positions
(contact unlock at match, quote revalidation semantics, R0/R1 as separate deployables, `searching`
retained through R1, total-fare semantics, auto-accept in R2, server-owned nudge, coordinator-owned
driver polling); Codex agreed to all with two refinements (never silently adjust an authorized fare
→ `fareAdjusted=true` re-confirmation; driver post-accept navigation in R1). No unresolved
disagreements remain.*
