# 03 — Real-time & Communication (rebuild-grade specification)

Source of truth: `d:\work\wisoway\rideshare-backend` (NestJS 11 / TypeScript 5.7 / TypeORM / PostgreSQL+PostGIS / Redis+Bull / Socket.IO).
Every statement below is grounded in a file path (+ line where useful). Where a claim could not be fully confirmed, it is marked `verify: <file:line>`.

---

## 0. Domain overview

This domain covers five modules and the eight entities that back them:

| Module | Path | Purpose |
|---|---|---|
| Instant rides | `src/modules/instant-rides/` | On-demand ("اطلب الآن") ride hailing: passenger request → sequential driver dispatch → offer / counter-offer negotiation → match → INSTANT trip + confirmed booking. |
| Tracking | `src/modules/tracking/` | Live driver-location ingest over WebSocket, trip location history, live ETA recomputation, nearby-trip spatial search, mock-GPS rejection. |
| Locations | `src/modules/locations/` | Place autocomplete (Photon/OSM), place detail, geocode / reverse-geocode (Google), distance (Google Distance Matrix), route (Google Directions with OSRM fallback). |
| Chat | `src/modules/chat/` | Postgres-backed 1:1 and group trip chat, HTTP REST + Socket.IO `/chat` namespace. Contains a **dead** Mongoose implementation (see §12). |
| Calls | `src/modules/calls/` | Twilio proxy-DID masked calling between the two parties of a booking + Twilio status webhook. |

Backing entities: `instant_ride_requests`, `instant_ride_offers`, `driver_availability`, `driver_locations`, `chat_rooms`, `messages`, `call_sessions`, `communication_fees`.

### Global HTTP conventions

* Global prefix: `process.env.API_PREFIX || 'api/v1'` — `src/main.ts:49-50`. **All HTTP paths in this document are written with the `/api/v1` prefix.**
* Global `ValidationPipe` with `{ whitelist: true, forbidNonWhitelisted: true, transform: true, transformOptions: { enableImplicitConversion: true } }` — `src/main.ts:37-46`. Unknown body/query fields ⇒ **400**.
* Global guards, in order: `JwtAuthGuard` → `BanGuard` → `RolesGuard` → `ThrottlerGuard` — `src/app.module.ts:113-131`. Auth is **default-on**; only `@Public()`-decorated handlers are anonymous (`src/common/guards/jwt-auth.guard.ts:16-27`).
* Global throttle: 200 requests / 60 000 ms across all routes — `src/app.module.ts:77-82`.
* Every successful response is wrapped: `{ "success": true, "data": <handler return value> }` — `src/common/interceptors/transform.interceptor.ts:24-29`. **Response shapes in this document describe the inner `data`.**
* Every error is wrapped by `HttpExceptionFilter` (`src/common/filters/http-exception.filter.ts:32-42`):

```json
{ "success": false,
  "error": { "code": <httpStatus:number>, "message": "<string>", "details": <exception body 'message' or null>,
             "timestamp": "<ISO>", "path": "<url>", "method": "<VERB>" } }
```
  Note: `error.code` is the **numeric HTTP status**, not the `ErrorCodes` string. Domain codes (e.g. `INSTANT_REQUEST_NOT_RETRYABLE`) are thrown inside the exception body and surface under `error.details` (an object) — `src/common/filters/http-exception.filter.ts:62-80`.
* CORS: all origins in non-production; `ALLOWED_ORIGINS` (comma-split) in production — `src/main.ts:28-34`.
* Helmet enabled — `src/main.ts:25`.

### End-to-end narrative: instant-ride happy path

1. **Driver goes online.** `POST /api/v1/instant-rides/availability` with `{isOnline:true, latitude, longitude}`. Server checks: driver approved, has a vehicle, vehicle verified, wallet balance ≥ 0 (`driver-availability.service.ts:205-235`). Upserts one `driver_availability` row with `isOnline=true`, `acceptsInstant`, `vehicleId`, `point` (geography Point 4326), `lastSeenAt=now()`.
2. **Driver heartbeats.** `POST /api/v1/instant-rides/availability/heartbeat` refreshes `point` + `lastSeenAt`. A driver whose `lastSeenAt` is older than **60 000 ms** is invisible to matching (`driver-availability.service.ts:36`).
3. **Passenger quotes.** `POST /api/v1/instant-rides/quotes` → distance (Google Distance Matrix, haversine fallback) + `recommendedFare = max(1.5, 1.0 + km*0.5 + min*0.1)`, `minFare = max(1.5, recommended*0.7)`, `maxFare = recommended*2.0`, currency from reverse-geocoding the pickup country.
4. **Passenger requests.** `POST /api/v1/instant-rides/requests`. Rejects (409) if the passenger already has a `searching|offered|accepted` request. Creates a row with `status='searching'`, `radiusKm=3`, `expiresAt=now+180s`, `fareRevision=1`. Enqueues Bull job `expire-request` (jobId `instant-request:<id>`, delay 180 s) and fires `dispatchNext()` **without awaiting it**.
5. **Dispatch.** `dispatchNext` (`instant-dispatch.service.ts:59-122`) reads the request, excludes drivers with an in-flight offer or an offer at the current-or-later `fareRevision`, then loops: PostGIS `ST_DWithin` search at `radiusKm*1000` m, nearest first, limit 20; for each candidate it tries an atomic soft-lock `UPDATE driver_availability SET currentRequestId=:req WHERE driverId=:d AND isOnline=true AND currentRequestId IS NULL`. First winner gets the offer. Otherwise radius grows `3 → 6 → 9 → 10` (capped at `MAX_RADIUS_KM=10`) and the row's `radiusKm` is persisted each step.
6. **Offer.** One `instant_ride_offers` row (`status='offered'`, `expiresAt=now+12s`, `fareRevision` copied), the request flips `searching → offered`, an FCM push `type='instant_offer'` goes to the driver with route metrics, and a Bull job `expire-offer` (jobId `instant-offer:<offerId>`, delay 12 s) is queued.
7. **Driver responds** via `POST /api/v1/instant-rides/offers/:id/respond` with `accept` / `counter` / `decline` (or the dedicated `/accept`, `/decline` routes).
   * **accept** → `finalizeMatch()` in one DB transaction: claim offer (`offered → accepted`), claim request (`offered → accepted`, set `matchedDriverId`, `acceptedFare`, `pickupEtaSeconds`), create a `TripEntity` (`tripType='instant'`, `status='in_progress'`, `isVisible=false`, `availableSeats=0`, `tripStartedAt=now`), create a `BookingEntity` (`status='confirmed'`, `seatPriceAtBooking = fare/seatCount`), write `tripId` back to the request. Then removes the offer-timeout, request-expiry and dispatch-wave jobs. Passenger gets push `instant_matched`.
   * **counter** → offer becomes `countered` with `proposedFare`, offer `expiresAt` restarts at **now+30 s**; passenger gets push `instant_counter_offer` and must accept/decline via `/requests/:rid/offers/:oid/accept|decline`.
   * **decline** → offer `declined`, driver lock released, request `offered → searching`, `dispatchNext()` fires again.
8. **No driver.** A full sweep to 10 km with no lockable driver: the request stays `searching`, a one-shot "raise your fare" nudge push is sent (`nudgedAt` claimed atomically), and a `dispatch-wave` job is scheduled **10 s** later on the request-expiry queue. Waves repeat until the 180 s TTL.
9. **Expiry.** The `expire-request` job cancels any outstanding offer, frees the driver, and calls `finalizeSearch()`, which atomically moves `searching|offered → expired`, records `terminalReason` (`no_eligible_drivers` / `all_declined` / `ttl_expired`) and `endedAt`, and pushes `instant_no_drivers`.
10. **Tracking.** After the match the driver's app connects to Socket.IO namespace `/tracking` with the JWT in the handshake and emits `driver:location:update` with `{tripId, latitude, longitude, …}`. Server appends a `driver_locations` row, stamps `trips.lastDriverLocation*`, recomputes the ETA at most every **45 s** via the routing provider, then broadcasts `trip:tracking:update` to room `trip:<tripId>`. Passengers subscribe with `trip:tracking:subscribe` and receive an immediate snapshot in the ack.
11. **Contact.** Chat (Socket.IO `/chat`, room `room:<chatRoomId>`) and masked calls (`POST /api/v1/bookings/:id/calls/initiate`) are open on `pending|confirmed` bookings (calls also on `in_progress`); **no payment gate** applies any more (§9).
12. **Completion** is owned by the trip-time / bookings domain, not by this one.

---

## 1. Environment variables read by this domain

| Var | Read at | Default | Effect |
|---|---|---|---|
| `API_PREFIX` | `src/main.ts:49` | `api/v1` | Global HTTP prefix (WebSocket namespaces are **not** prefixed). |
| `PORT` / `HOST` | `src/main.ts:76-77` | `3000` / `0.0.0.0` | Listen address. |
| `NODE_ENV`, `ALLOWED_ORIGINS` | `src/main.ts:28-34` | — | CORS origin list in production. |
| `JWT_ACCESS_SECRET` | `ws-auth.guard.ts:29`, `tracking.module.ts:33`, `chat-postgres.module.ts:25` | — | Verifies the WebSocket handshake JWT. |
| `REDIS_HOST` / `REDIS_PORT` | `src/jobs/jobs.module.ts:14-17`, `src/config/redis.config.ts` | `localhost` / `6379` | Bull broker for the two instant-ride queues. |
| `GOOGLE_MAPS_API_KEY` | `locations.service.ts:84` | `''` | Geocode / reverse-geocode / distance matrix / directions. Empty ⇒ routing falls straight to OSRM; geocode & distance then fail. |
| `PHOTON_BASE_URL` | `locations.service.ts:88-91` | `https://photon.komoot.io` | Autocomplete provider base URL (trailing slashes stripped). |
| `GEOCODER_USER_AGENT` | `locations.service.ts:93-95` | `WisowayRideshare/1.0 (+https://wisoway.app)` | `User-Agent` header sent to Photon. |
| `LOCATION_AUTOCOMPLETE_COUNTRIES` | `locations.service.ts:98-104` | `''` (global) | Comma-separated lowercase ISO-2 codes, **max 5**, filters suggestions by `properties.countrycode`. |
| `TWILIO_PROXY_NUMBERS` | `proxy-pool.service.ts:35-39` | `''` | Comma-separated E.164 proxy DID pool. Empty ⇒ every call attempt returns 503. Read straight from `process.env`, **not** via `ConfigService`. |
| `TWILIO_AUTH_TOKEN` | `calls.controller.ts:51-52` (`configService.get('twilio.TWILIO_AUTH_TOKEN')`) | `''` | Validates `X-Twilio-Signature` on the webhook. |
| `TWILIO_ACCOUNT_SID`, `TWILIO_PHONE_NUMBER`, `TWILIO_VERIFY_SERVICE_SID`, `TWILIO_API_KEY_SID`, `TWILIO_API_KEY_SECRET`, `OTP_PROVIDER` | `src/config/twilio.config.ts` | `''` / `local` | Loaded and `validateSync`-checked at boot, but **only the Verify/OTP side is used by the auth domain**; this domain uses only `TWILIO_AUTH_TOKEN` + `TWILIO_PROXY_NUMBERS`. |
| Firebase (`FIREBASE_*`) | `notifications.service.ts` | — | All instant-ride and chat notifications go out as FCM push; if Firebase is not initialised, `sendPush` silently returns `{successCount:0,failureCount:0}` (`notifications.service.ts:228-231`). |

**Documentation drift (report as a bug):** `.env.example` still documents `NOMINATIM_BASE_URL` and `NOMINATIM_USER_AGENT`, but `LocationsService` reads `PHOTON_BASE_URL` and `GEOCODER_USER_AGENT` (`rideshare-backend/.env.example` vs `locations.service.ts:88-95`). `TWILIO_PROXY_NUMBERS` is **absent** from `.env.example` entirely.

---

## 2. Full entity column definitions

### 2.1 `instant_ride_requests` — `src/database/entities/instant-ride-request.entity.ts`, migrations `1746320000000`, `1746500000000`, `1746510000000`, `1746520000000`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `passengerId` | uuid | no | — | FK → `users(id)` ON DELETE CASCADE |
| `fromName` | varchar(160) | no | — | |
| `fromAddress` | text | yes | — | |
| `fromPoint` | geography(Point,4326) | no | — | GIST index `instant_requests_from_point_idx` |
| `toName` | varchar(160) | no | — | |
| `toAddress` | text | yes | — | |
| `toPoint` | geography(Point,4326) | no | — | no index |
| `seatCount` | integer | no | `1` | |
| `status` | varchar(16) | no | `'searching'` | `searching\|offered\|accepted\|no_drivers\|expired\|cancelled` |
| `fareEstimate` | numeric(10,2) | yes | — | mirrors `passengerFare`; TypeORM returns a string |
| `recommendedFare` | numeric(10,2) | yes | — | server recommendation at quote time |
| `passengerFare` | numeric(10,2) | yes | — | the passenger's asking total fare |
| `acceptedFare` | numeric(10,2) | yes | — | immutable, written at match |
| `fareRevision` | integer | no | `1` | bumped on each raise; re-qualifies earlier decliners |
| `nudgedAt` | timestamptz | yes | — | set once after an empty full sweep |
| `pickupEtaSeconds` | integer | yes | — | driver→pickup estimate at match |
| `currency` | varchar(5) | no | `'JOD'` | |
| `radiusKm` | double precision | no | `3` | current search radius, grows while searching |
| `terminalReason` | varchar(32) | yes | — | `no_eligible_drivers\|all_declined\|ttl_expired\|passenger_cancelled` |
| `endedAt` | timestamptz | yes | — | |
| `retryOfRequestId` | uuid | yes | — | FK → self ON DELETE SET NULL |
| `matchedDriverId` | uuid | yes | — | no FK constraint in the migration |
| `tripId` | uuid | yes | — | no FK constraint in the migration |
| `expiresAt` | timestamptz | no | — | `createdAt + 180 s` |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Indexes:
* `instant_requests_passenger_status_idx` on `(passengerId, status)`.
* `instant_requests_from_point_idx` GIST on `fromPoint`.
* `instant_requests_retry_of_uniq` **UNIQUE partial** on `(retryOfRequestId) WHERE retryOfRequestId IS NOT NULL` — makes a double-tapped retry idempotent at DB level.
* `instant_requests_searching_per_passenger_idx` **UNIQUE partial** on `(passengerId) WHERE status IN ('searching','offered')` — one live search per passenger enforced in the database. `accepted` deliberately excluded.

### 2.2 `instant_ride_offers` — `instant-ride-offer.entity.ts`, migrations `1746330000000`, `1746500000000`, `1746510000000`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `requestId` | uuid | no | — | FK → `instant_ride_requests(id)` CASCADE |
| `driverId` | uuid | no | — | FK → `users(id)` CASCADE |
| `vehicleId` | uuid | yes | — | no FK |
| `status` | varchar(16) | no | `'offered'` | `offered\|accepted\|declined\|countered\|rejected\|timed_out\|cancelled` |
| `proposedFare` | numeric(10,2) | yes | — | driver counter-offer amount |
| `fareRevision` | integer | no | `1` | request revision this offer was made at |
| `offeredAt` | timestamptz | no | `now()` | |
| `respondedAt` | timestamptz | yes | — | |
| `expiresAt` | timestamptz | no | — | `+12 s` when offered, reset to `+30 s` on counter |
| `createdAt` | timestamptz | no | `now()` | |

Indexes: `instant_offers_request_idx (requestId)`, `instant_offers_driver_status_idx (driverId, status)`.

### 2.3 `driver_availability` — `driver-availability.entity.ts`, migration `1746300000000`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `driverId` | uuid | no | — | **PK**, FK → `users(id)` CASCADE. One row per driver. |
| `vehicleId` | uuid | yes | — | resolved when going online |
| `isOnline` | boolean | no | `false` | |
| `acceptsInstant` | boolean | no | `true` | |
| `point` | geography(Point,4326) | yes | — | idle location |
| `currentRequestId` | uuid | yes | — | **soft lock**: set while an offer is outstanding |
| `lastSeenAt` | timestamptz | yes | — | heartbeat |
| `updatedAt` | timestamptz | no | `now()` | |

Index: `driver_availability_available_point_idx` — **partial GIST**: `USING GIST (point) WHERE "isOnline" = true AND "currentRequestId" IS NULL`. The matching query's predicates must include those two conditions verbatim for the partial index to be used.

### 2.4 `driver_locations` — `driver-location.entity.ts`, migration `1700000000000-initialize-postgres.ts:139-160`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `driverId` | uuid | no | — | FK → `users(id)` CASCADE |
| `tripId` | uuid | no | — | FK → `trips(id)` CASCADE |
| `point` | geography(Point,4326) | no | — | GIST `driver_locations_point_idx` |
| `speedKph` | numeric(6,2) | yes | — | stored as string by TypeORM |
| `heading` | numeric(6,2) | yes | — | |
| `accuracyMeters` | numeric(6,2) | yes | — | |
| `recordedAt` | timestamptz | no | `now()` | |
| `createdAt` | timestamptz | no | `now()` | |

Indexes: `driver_locations_driver_time_idx (driverId, recordedAt)`, `driver_locations_trip_time_idx (tripId, recordedAt)`, `driver_locations_point_idx` GIST.
**Append-only. No retention/pruning job exists anywhere in the repo** — this table grows unbounded (see §13).

### 2.5 `chat_rooms` — `chat-room.entity.ts`, migrations `1739300000000`, `1739500000000`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `tripId` | uuid | no | — | FK → `trips(id)` CASCADE |
| `passengerId` | uuid | yes | — | FK → `users(id)` CASCADE. **`NULL` = the trip-wide group room**; non-null = the 1:1 driver↔that-passenger room. |
| `participants` | jsonb | no | `'[]'` | `[{ "userId": uuid, "joinedAt": ISO }]` |
| `lastMessage` | text | yes | — | first 100 chars of the newest message |
| `lastMessageTime` | timestamptz | yes | — | entity declares `type:'timestamp'`, migration creates `TIMESTAMPTZ` |
| `lastMessageSenderId` | uuid | yes | — | FK → `users(id)` SET NULL |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Indexes: `idx_chat_rooms_trip_id (tripId)`, `idx_chat_rooms_last_message_time (lastMessageTime)`, and **UNIQUE partial** `idx_chat_rooms_trip_passenger (tripId, passengerId) WHERE passengerId IS NOT NULL`.
Note: no unique index guards the group room (`passengerId IS NULL`) — concurrent first-access can create duplicates (§13).

### 2.6 `messages` — `message.entity.ts`, migration `1739300000000`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `chatRoomId` | uuid | no | — | FK → `chat_rooms(id)` CASCADE |
| `senderId` | uuid | no | — | FK → `users(id)` **RESTRICT** |
| `senderName` | varchar | yes | — | denormalised snapshot of `users.name` |
| `text` | text | no | — | length capped only by the DTO (1–2000) |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Indexes: `idx_messages_chat_room (chatRoomId)`, `idx_messages_created_at_desc (chatRoomId, createdAt DESC)`.
There is **no read-receipt / unread column** anywhere.

### 2.7 `call_sessions` — `call-session.entity.ts`, migration `1745909000000`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `bookingId` | uuid | no | — | FK → `bookings(id)` CASCADE |
| `callerUserId` | uuid | no | — | FK → `users(id)` CASCADE |
| `calleeUserId` | uuid | no | — | FK → `users(id)` CASCADE |
| `proxyNumber` | varchar(20) | no | — | E.164 proxy DID |
| `callerRealNumber` | varchar(20) | yes | — | audit only |
| `calleeRealNumber` | varchar(20) | yes | — | `NULL` when `users.hidePhoneNumber` is true |
| `twilioCallSid` | varchar(64) | yes | — | **UNIQUE**; never written by any code path (§10) |
| `status` | varchar(20) | no | `'initiated'` | CHECK `IN ('initiated','in_progress','completed','failed')` |
| `startedAt` / `endedAt` | timestamptz | yes | — | |
| `durationSeconds` | int | yes | — | |
| `terminationReason` | varchar(40) | yes | — | Twilio `CallStatus` verbatim |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Indexes: `idx_call_sessions_booking (bookingId)`, `idx_call_sessions_twilio_sid (twilioCallSid) WHERE twilioCallSid IS NOT NULL`.

### 2.8 `communication_fees` — `communication-fee.entity.ts`, migrations `1739400000000`, `1739600000000`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `countryCode` | varchar(5) | no | — | **UNIQUE** (`idx_communication_fees_country`) |
| `feeAmount` | decimal(10,2) | no | — | legacy flat unlock fee |
| `currency` | varchar(5) | no | — | |
| `isActive` | boolean | no | `true` | |
| `passengerPlatformPercent` | decimal(5,2) | no | `0` | **dead** — see §9 |
| `driverUnlockPercent` | decimal(5,2) | no | `0` | % of `seatPrice × totalSeats` charged to the driver |
| `lifetimeFreeTripEnabled` | boolean | no | `true` | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

---

## 3. Consolidated WebSocket event table

Transport: Socket.IO mounted on the same HTTP server. **No adapter is configured** — `src/main.ts` never calls `app.useWebSocketAdapter(...)` and there is no Redis Socket.IO adapter anywhere in `src/`. Namespaces are **not** under the API prefix; the Socket.IO handshake path is the default `/socket.io/` (proxied with `Upgrade`/`Connection: upgrade` and 7-day timeouts — `docker/nginx/nginx.conf:120-132`).

Handshake auth for every namespace (`src/common/guards/ws-auth.guard.ts:48-66`), first match wins:
1. `handshake.auth.token`
2. `handshake.query.token`
3. `Authorization: Bearer <token>` header

The token is verified with `JWT_ACCESS_SECRET`; on success `client.user = {...payload, id}` and `client.data.userId = payload.sub || payload.userId || payload.id`. Failure ⇒ `UnauthorizedException('Invalid or expired WebSocket token')`.
**Gotcha:** `WsAuthGuard` is a guard, so it runs on *message* handlers, not on `handleConnection`. `handleConnection` reads `client.data.userId`, which is only populated by the first guarded message — so connection-time room joins based on it are unreliable (§13).

| Namespace | Event | Direction | Payload | Room / target |
|---|---|---|---|---|
| `/tracking` | `trip:tracking:subscribe` | c→s | `{ tripId: string }` | joins `trip:<tripId>`; ack `{success, userId, tripId, snapshot}` |
| `/tracking` | `trip:tracking:unsubscribe` | c→s | `{ tripId: string }` | leaves `trip:<tripId>`; ack `{success, tripId}` |
| `/tracking` | `driver:location:update` | c→s | `UpdateDriverLocationDto` (§6.2) | ack `{success:true, data:<location view>}` |
| `/tracking` | `trip:tracking:update` | s→c | location view (§6.2 response) | room `trip:<tripId>` |
| `/tracking` | `trip:tracking:snapshot` | s→c | latest location view | room `trip:<tripId>` — emitted only by `emitTripTrackingSnapshot()`, which **nothing calls** (dead) |
| `/chat` | `joinRoom` | c→s | `{ chatRoomId: string }` | joins `room:<chatRoomId>`; ack `{event:'joined', chatRoomId}` |
| `/chat` | `leaveRoom` | c→s | `{ chatRoomId: string }` | leaves; ack `{event:'left', chatRoomId}` |
| `/chat` | `sendMessage` | c→s | `{ chatRoomId: string, text: string }` | ack `{event:'messageSent', messageId}` or `{event:'error', message}` |
| `/chat` | `typing` | c→s | `{ chatRoomId: string }` | ack `{event:'typing'}` |
| `/chat` | `stopTyping` | c→s | `{ chatRoomId: string }` | ack `{event:'stoppedTyping'}` |
| `/chat` | `newMessage` | s→c | `{_id, id, chatRoomId, senderId, senderName, text, createdAt}` | room `room:<chatRoomId>` |
| `/chat` | `userTyping` | s→c | `{chatRoomId, userId, userName}` | room `room:<chatRoomId>` |
| `/chat` | `userStopTyping` | s→c | `{chatRoomId, userId}` | room `room:<chatRoomId>` |
| `/chat` | `error` | s→c | `{code: 4403, message}` (settlement) or `{message}` | the joining socket only |
| `/notifications` | `subscribe` | c→s | *(none)* | joins `user:<userId>`; ack `{success:true}` |
| `/notifications` | *(any)* | s→c | arbitrary | `emitToUser(userId, event, data)` → room `user:<userId>` |
| `/trips` | `subscribeTripUpdates` | c→s | `{ tripId }` | joins `trip:<tripId>`; ack `{event:'subscribed', tripId}` |
| `/trips` | `unsubscribeTripUpdates` | c→s | `{ tripId }` | ack `{event:'unsubscribed', tripId}` |
| `/trips` | `tripUpdated` / `seatBooked` / `seatReleased` | s→c | `{tripId, …}` | room `trip:<tripId>` |

`/notifications` and `/trips` are outside this domain's five modules but share the same guards, rooms and auth handshake, and `/trips` uses the **same room key** `trip:<tripId>` as `/tracking` (different namespace, so no collision).

WS rate limit (`src/common/guards/ws-rate-limit.guard.ts`): **180 events / 60 000 ms per user**, keyed on `client.data.userId || client.user.id || handshake.address || 'anonymous'`, in an **in-process `Map`** (per-instance, never evicted). Exceeding it throws `BadRequestException('Too many websocket events, try again shortly')`.

There are **no instant-ride WebSocket events**. Every instant-ride notification is an FCM push; the passenger UI polls `GET /instant-rides/requests/:id` and the driver polls `GET /instant-rides/offers/pending`.

---

## F-01: Driver availability (go online / offline, heartbeat, status)

**What it does:** Lets an approved driver with a verified vehicle declare that they are online and accepting on-demand rides, and keeps their idle position fresh so the matcher can find them.

**Actors:** driver (role-guarded).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/instant-rides/availability` | JWT + role `driver` | Go online/offline |
| POST | `/api/v1/instant-rides/availability/heartbeat` | JWT + role `driver` | Refresh idle location |
| GET | `/api/v1/instant-rides/availability/me` | JWT + role `driver` | Read current availability |

**WebSocket events:** none.

**Request contracts** (`dto/set-availability.dto.ts`):

`SetAvailabilityDto`
| Field | Type | Rules | Req. |
|---|---|---|---|
| `isOnline` | boolean | `@IsBoolean()` | yes |
| `acceptsInstant` | boolean | `@IsOptional() @IsBoolean()` | no (defaults `true` when going online) |
| `latitude` | number | `@IsOptional() @Type(()=>Number) @IsNumber() @Min(-90) @Max(90)` | no |
| `longitude` | number | `@IsOptional() @Type(()=>Number) @IsNumber() @Min(-180) @Max(180)` | no |

`HeartbeatDto`: `latitude` (required, −90..90), `longitude` (required, −180..180).

**Response** (all three endpoints return `DriverAvailabilityStatus`):
```ts
{ driverId: string, isOnline: boolean, acceptsInstant: boolean,
  vehicleId: string | null, latitude: number | null, longitude: number | null,
  lastSeenAt: Date | null }
```
`GET availability/me` for a driver with no row returns the synthetic default `{isOnline:false, acceptsInstant:true, vehicleId:null, latitude:null, longitude:null, lastSeenAt:null}` without writing anything (`driver-availability.service.ts:91-105`).

**Business rules & validation** (`driver-availability.service.ts:47-89`, `205-235`):
1. Going online requires `users.isDriverApproved !== false` — else 403 `حسابك كسائق قيد المراجعة. لا يمكنك استقبال الرحلات بعد.`
2. Going online requires a registered vehicle (`vehicles.findByDriver`) — else 403 `يجب تسجيل مركبة قبل استقبال الرحلات المباشرة.`
3. That vehicle must have `isVerified === true` — else 403 `مركبتك قيد مراجعة الإدارة…`.
4. Wallet balance must be ≥ 0 (`WalletService.assertNonNegativeDriverBalance`) — else 403 with body `{code:'NEGATIVE_WALLET_BALANCE', message:'رصيد محفظتك سالب. سدد المستحقات قبل تلقي الرحلات المباشرة.'}`.
5. The vehicle id resolved in (2) is stored on the availability row.
6. Going **offline** performs no checks and additionally clears `currentRequestId` (releases any soft lock) but **does not** clear `point` or `lastSeenAt`.
7. Heartbeat requires an existing row with `isOnline === true` — else 403 `You must go online before sending location`.
8. Upsert is a read-then-`merge`-then-`save` (`driver-availability.service.ts:245-257`) because `repo.update()`'s `QueryDeepPartialEntity` mangles the GeoJSON object. This is **not atomic**.
9. Coordinates are stored as GeoJSON `{type:'Point', coordinates:[longitude, latitude]}` — longitude first.

**Data model:** `driver_availability` (§2.3).

**State machine:** `isOnline: false ⇄ true` via the endpoint; `currentRequestId: null → <requestId>` by the dispatcher's atomic lock and back to `null` on decline / timeout / cancel / expiry / go-offline.

**External services:** `UsersService`, `VehiclesService`, `WalletService`. No third-party calls.

**Background jobs:** none. Staleness is evaluated at query time (60 s), never swept.

**Errors:**

| Condition | HTTP | Body |
|---|---|---|
| not approved / no vehicle / unverified vehicle | 403 | Arabic message string |
| negative wallet | 403 | `{code:'NEGATIVE_WALLET_BALANCE', message}` |
| heartbeat while offline | 403 | `You must go online before sending location` |
| non-driver role | 403 | `Access denied. Required roles: driver` |
| missing/invalid JWT | 401 | `Invalid or expired token` |

**Notes for reimplementation:**
* There is **no offline sweep**: a driver who kills the app stays `isOnline=true` forever; the 60 s `lastSeenAt` cut-off in the matcher is the only protection. Mobile must heartbeat more often than every 60 s.
* Going offline while an offer is outstanding clears the lock but leaves the offer row `offered`; it will still be timed out by its Bull job.
* The read-modify-write upsert can lose a concurrent `setAvailability` + `heartbeat`. Prefer a real `INSERT … ON CONFLICT DO UPDATE` in a rebuild.

---

## F-02: Nearby-driver map pins (anonymous)

**What it does:** Returns up to 8 coarse coordinates of the platform's online drivers around a point, so the passenger's map looks populated before they request.

**Actors:** any authenticated user. **The Swagger summary says "Anonymous", but the endpoint is NOT `@Public()`** — the controller-level `JwtAuthGuard` and the global `JwtAuthGuard` both apply, so a JWT is required (`instant-rides.controller.ts:34-35, 74-84`).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/instant-rides/nearby-drivers?latitude=&longitude=` | JWT (any role) | Coarse pins near a point |

**Request** (`dto/nearby-drivers.dto.ts`): `latitude` (number, −90..90, required), `longitude` (number, −180..180, required). Extra query params ⇒ 400 (global `forbidNonWhitelisted`).

**Response:** `Array<{ latitude: number, longitude: number }>` — at most 8 entries, nearest first.

**Business rules** (`driver-availability.service.ts:164-203`):
1. Fixed radius **5 000 m**, fixed limit **8** (hard-coded default parameters; the controller passes neither).
2. Filters: `isOnline = true`, `point IS NOT NULL`, `lastSeenAt >= now() − 60 s`.
3. **Busy drivers are deliberately included** — `currentRequestId` is *not* filtered, unlike the matcher.
4. Ordered by `ST_Distance` ascending.
5. Coordinates are rounded to 3 decimal places (`Math.round(v * 1000)/1000`) ≈ **110 m** granularity, and **no driver id or vehicle id is returned**, so a pin can't be tied to a person.

**Exact SQL** (TypeORM query builder → PostGIS):
```sql
SELECT ST_Y(a."point"::geometry) AS lat,
       ST_X(a."point"::geometry) AS lng,
       ST_Distance(a."point", ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography) AS distance_meters
FROM driver_availability a
WHERE a."isOnline" = true
  AND a."point" IS NOT NULL
  AND a."lastSeenAt" >= :staleCutoff
  AND ST_DWithin(a."point",
                 ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
                 :radiusMeters)
ORDER BY distance_meters ASC
LIMIT 8;
```

**Notes:** because `currentRequestId` is not constrained, this query cannot use the partial GIST index (`… WHERE isOnline AND currentRequestId IS NULL`); it falls back to a full GIST scan on the whole table. Consider a second, unconditional GIST index in a rebuild.

---

## F-03: Instant-ride fare quote

**What it does:** Returns the server's recommended fare and the min/max band a passenger may name for a given A→B, before they submit a request.

**Actors:** any authenticated user (JWT required despite no `@Roles`).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/instant-rides/quotes` | JWT | Distance-based fare recommendation |

**Request** (`QuoteInstantRequestDto`): `{ from: InstantPointDto, to: InstantPointDto }`, both `@ValidateNested`.

`InstantPointDto` (`dto/create-instant-request.dto.ts:13-34`):
| Field | Type | Rules | Req. |
|---|---|---|---|
| `name` | string | `@IsString() @MaxLength(160)` | yes |
| `address` | string | `@IsOptional() @IsString() @MaxLength(500)` | no |
| `latitude` | number | `@Type(()=>Number) @IsNumber() @Min(-90) @Max(90)` | yes |
| `longitude` | number | `@Type(()=>Number) @IsNumber() @Min(-180) @Max(180)` | yes |

**Response** (all money fields are **strings**, `toFixed(2)`):
```ts
{ recommendedFare: "3.25", minFare: "2.28", maxFare: "6.50",
  currency: "JOD", distanceKm: 4.3, durationMinutes: 11 }
```

**Business rules** (`instant-rides.service.ts:934-987`):
1. Distance/duration come from `LocationsService.getDistance` (Google Distance Matrix). On **any** throw, it falls back to the haversine great-circle distance with `durationMin = 0`.
2. Currency comes from `LocationsService.reverseGeocode(from).countryCode` mapped through `COUNTRY_CURRENCY` (`src/common/currency/country-currency.ts`); on any failure or empty code it stays `DEFAULT_CURRENCY = 'JOD'`.
3. `recommendedFare = round2( max(FARE_MINIMUM, FARE_BASE + km*FARE_PER_KM + min*FARE_PER_MIN) )` with **`FARE_BASE=1.0`, `FARE_PER_KM=0.5`, `FARE_PER_MIN=0.1`, `FARE_MINIMUM=1.5`** (`instant-rides.constants.ts:29-32`).
4. `minFare = max(FARE_MINIMUM, round2(recommended * 0.7))` — `PASSENGER_FARE_MIN_FACTOR = 0.7`.
5. `maxFare = round2(recommended * 2.0)` — `PASSENGER_FARE_MAX_FACTOR = 2.0`.
6. `distanceKm` is rounded to 1 decimal, `durationMinutes` to a whole number, in the response only.
7. `round2(x) = Math.round(x*100)/100` throughout.

**External services:** Google Distance Matrix, Google Geocoding (reverse). Both degrade silently.

**Notes:** the fare formula is currency-blind — the same numeric constants are applied whether the resolved currency is JOD, SYP or IQD. Flagged in the constants file as "adjust per market".

---

## F-04: Passenger creates / polls / cancels an instant request

**What it does:** Opens a 3-minute on-demand search for a driver at a passenger-named price, exposes its live state (including the outstanding counter-offer, the raise-fare nudge and the matched driver card), and lets the passenger call it off.

**Actors:** any authenticated user (drivers are not blocked from requesting — no `@Roles` on these routes).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/instant-rides/requests` | JWT | Create a request, start searching |
| GET | `/api/v1/instant-rides/requests/:id` | JWT | Poll status (owner only) |
| PATCH | `/api/v1/instant-rides/requests/:id/fare` | JWT | Raise the offered fare while searching |
| POST | `/api/v1/instant-rides/requests/:id/retry` | JWT | Re-run an exhausted search |
| DELETE | `/api/v1/instant-rides/requests/:id` | JWT | Cancel while searching/offered |

**WebSocket events:** none — the client **polls** `GET requests/:id`.

**Request contracts:**

`CreateInstantRequestDto` (`dto/create-instant-request.dto.ts:36-61`):
| Field | Type | Rules | Req. |
|---|---|---|---|
| `from` | `InstantPointDto` | `@ValidateNested`, `@Type` | yes |
| `to` | `InstantPointDto` | `@ValidateNested`, `@Type` | yes |
| `seatCount` | int | `@IsOptional() @IsInt() @Min(1) @Max(8)` | no (default `1`) |
| `passengerFare` | number | `@IsOptional() @IsNumber({maxDecimalPlaces:2}) @Min(0)` | no (defaults to `recommendedFare`) |

`UpdateFareDto` (`dto/update-fare.dto.ts`): `passengerFare` — `@IsNumber({maxDecimalPlaces:2}) @Min(0)`, required.

`DELETE` and `retry` take no body.

**Response — the "request view"** (`instant-rides.service.ts:1006-1029`), returned by create / get / updateFare / retry / cancel / acceptOffer / accept- and decline-counter-offer:

```ts
{
  id, status,                      // InstantRequestStatus
  terminalReason: string | null,   // InstantTerminalReason
  canRetry: boolean,               // status ∈ {expired, no_drivers}
  retryOfRequestId: string | null,
  endedAt: Date | null,
  from: { name, address },
  to:   { name, address },
  seatCount: number,
  fareEstimate: string|null, recommendedFare: string|null,
  passengerFare: string|null, acceptedFare: string|null,
  currency: string,
  matchedDriverId: string|null, tripId: string|null,
  expiresAt: Date,
  counterOffer: null | {           // only while status === 'offered' and not expired
    id, driverId, driverName, driverRating, driverTotalRatings,
    vehicleModel, plateNumber, proposedFare, currency, expiresAt },
  nudge: null | {                  // only while searching and nudgedAt is set
    suggestedFare, maxFare, currentFare, currency },   // all strings, 2dp
  match: null | {                  // only while status === 'accepted'
    tripId, acceptedFare, currency, pickupEtaSeconds,
    driverName, driverRating, driverTotalRatings,
    vehicleModel, plateNumber, carImageUrl }
}
```

**Business rules & validation:**

*Create* (`instant-rides.service.ts:108-188`)
1. 409 `لديك طلب رحلة نشط بالفعل.` if the caller already owns a request in `searching | offered | accepted`. The DB partial-unique index also enforces the `searching|offered` half.
2. `seatCount` defaults to 1 (1–8).
3. A fresh quote is computed (F-03). If `passengerFare` is supplied it is rounded to 2 dp and must satisfy `minFare ≤ fare ≤ maxFare`, else **400** `السعر خارج الحدود المسموحة (min – max CUR).` Omitted ⇒ `recommendedFare` is used.
4. Persisted with `status='searching'`, `fareEstimate = passengerFare = <chosen>.toFixed(2)`, `recommendedFare`, `currency`, `radiusKm = INITIAL_RADIUS_KM = 3`, `expiresAt = now + REQUEST_TTL_SECONDS (180 s)`, `fareRevision = 1`.
5. Bull `expire-request` job queued with `delay=180000`, `jobId='instant-request:<id>'`, `removeOnComplete/​removeOnFail: true`. **Queue failures are swallowed with a warn log** — the request would then never expire.
6. `dispatchNext(id)` is fired-and-forgotten (`void … .catch(warn)`); the HTTP response does not wait for matching.

*Poll* — 404 `الطلب غير موجود.` if unknown, 403 `غير مصرح.` if `passengerId` ≠ caller.

*Raise fare* (`instant-rides.service.ts:207-254`)
7. Owner-only (403), must exist (404).
8. Status must be exactly `searching` — else **409** `لا يمكن تعديل السعر في حالة الطلب الحالية.` (a request currently `offered` cannot be raised).
9. New amount must be `> currentFare` and `≤ round2(recommendedFare × 2.0)`, else **400** with the bounds in the message.
10. The update is a conditional `UPDATE … WHERE id=? AND status='searching'` setting `passengerFare`, `fareEstimate`, `fareRevision = fareRevision + 1`, `nudgedAt = null`. `affected !== 1` ⇒ 409.
11. `dispatchNext` is re-fired; the revision bump makes drivers who declined/timed out at an older revision eligible again.

*Cancel* (`instant-rides.service.ts:256-314`)
12. Owner-only; status must be `searching` or `offered`, else 409 `لا يمكن إلغاء الطلب في حالته الحالية.`
13. Any outstanding `offered|countered` offer is set to `cancelled` with `respondedAt=now`, the driver's soft lock released, the offer-timeout job removed, and the driver pushed `instant_offer_cancelled`.
14. Request → `status='cancelled'`, `terminalReason='passenger_cancelled'`, `endedAt=now`. The `expire-request` and `dispatch-wave` jobs are removed (best-effort).

*Retry* (`instant-rides.service.ts:321-502`)
15. Owner-only (403), must exist (404).
16. Only `expired` or `no_drivers` can be retried — else **409** `{code:'INSTANT_REQUEST_NOT_RETRYABLE'}`.
17. Idempotent: if a child with `retryOfRequestId = :id` already exists it is returned as-is (checked both before and inside the transaction; the partial-unique index is the final backstop).
18. The route is re-quoted. If the previous fare no longer falls inside the **new** `[minFare, maxFare]`, it throws **409** `{statusCode:409, code:'INSTANT_RETRY_FARE_RECONFIRMATION_REQUIRED', message:'تغيّر نطاق السعر؛ راجع السعر ثم أعد الطلب.', quote:{recommendedFare,minFare,maxFare,currency,distanceKm,durationMinutes}}` — the client must re-price and POST a new request.
19. Inside a transaction the original row is locked `pessimistic_write` (serialises concurrent retries), retryability re-asserted, the child re-checked, and a live-request check runs again → **409** `{code:'INSTANT_ACTIVE_REQUEST_EXISTS'}`.
20. The new request copies route, addresses, points, `seatCount` and the previous fare; `recommendedFare` and `currency` come from the **fresh** quote; `radiusKm=3`; new 180 s TTL; `retryOfRequestId = <original>`.
21. Structured PII-free logs: `instant_retry_created {oldRequestId,newRequestId,passengerId}`, `instant_retry_rejected {code}`.

**Data model:** `instant_ride_requests` (§2.1), `instant_ride_offers` (read for the counter-offer/nudge views).

**State machine (request):**

```
                    ┌──────────── raise fare / decline / timeout ─────────┐
                    ▼                                                      │
  (create) ──▶ searching ──makeOffer──▶ offered ──accept(finalizeMatch)──▶ accepted  [terminal]
                  │  │                    │  │
                  │  │                    │  └── counter → still 'offered' (offer='countered')
                  │  │                    └── passenger cancel ──▶ cancelled  [terminal]
                  │  └── passenger cancel ──▶ cancelled  [terminal]
                  └── expire-request job / dispatchNext past expiresAt ──▶ expired  [terminal]
```
`no_drivers` is a **declared but never-assigned** status: no code path writes it; `finalizeSearch` always writes `expired` with a `terminalReason`. It is only read by `canRetry`/`assertRetryable` (`instant-ride-request.entity.ts:26`, `instant-rides.service.ts:488, 1035`).

`terminalReason` is set together with the terminal status: `no_eligible_drivers` (no offer was ever made), `all_declined` (offers existed, none outstanding), `ttl_expired` (an offer was still outstanding when the window closed), `passenger_cancelled`.

**External services:** Google (distance + reverse geocode) via `LocationsService`; Firebase FCM via `NotificationsService`; Redis/Bull.

**Background jobs:** see F-06.

**Errors:**

| Condition | HTTP | Body |
|---|---|---|
| active request exists (create) | 409 | `لديك طلب رحلة نشط بالفعل.` |
| fare out of band (create) | 400 | Arabic bounds message |
| not found | 404 | `الطلب غير موجود.` |
| not owner | 403 | `غير مصرح.` |
| raise fare in wrong state | 409 | `لا يمكن تعديل السعر في حالة الطلب الحالية.` |
| raise fare out of band | 400 | Arabic bounds message |
| cancel in wrong state | 409 | `لا يمكن إلغاء الطلب في حالته الحالية.` |
| retry non-retryable | 409 | `{code:'INSTANT_REQUEST_NOT_RETRYABLE'}` |
| retry with live request | 409 | `{code:'INSTANT_ACTIVE_REQUEST_EXISTS'}` |
| retry needs re-pricing | 409 | `{code:'INSTANT_RETRY_FARE_RECONFIRMATION_REQUIRED', quote:{…}}` |

**Notes for reimplementation:**
* All money is `numeric(10,2)` and crosses the wire as a **2-dp string**, not a number.
* `getNudge` returns `null` when the suggested `min(maxFare, current × 1.15)` is not strictly greater than the current fare (i.e. the passenger is already at the ceiling).
* `getActiveCounterOffer` filters out an offer whose `expiresAt` has passed even though its DB status is still `countered` — the row is only corrected later by the timeout job.
* `PATCH …/fare` refusing while `status='offered'` means a passenger cannot outbid during the 12 s an offer is live; the client must retry after the offer resolves.

---

## F-05: Dispatch & offer negotiation (driver side)

**What it does:** Sequentially offers a live request to the nearest lockable driver, lets that driver accept at the passenger's price, counter with a higher one, or decline, and turns an acceptance into a real trip + confirmed booking.

**Actors:** driver (offer endpoints, `@Roles('driver')`); passenger (counter-offer resolution, no role guard beyond ownership).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/instant-rides/offers/pending` | JWT + `driver` | The driver's currently outstanding offer |
| POST | `/api/v1/instant-rides/offers/:id/accept` | JWT + `driver` | Accept at the passenger's fare |
| POST | `/api/v1/instant-rides/offers/:id/decline` | JWT + `driver` | Decline |
| POST | `/api/v1/instant-rides/offers/:id/respond` | JWT + `driver` | Unified accept / counter / decline |
| POST | `/api/v1/instant-rides/requests/:rid/offers/:oid/accept` | JWT (owner) | Passenger accepts the counter-offer |
| POST | `/api/v1/instant-rides/requests/:rid/offers/:oid/decline` | JWT (owner) | Passenger declines the counter-offer |

**Request contracts:**

`RespondOfferDto` (`dto/respond-offer.dto.ts`):
| Field | Type | Rules | Req. |
|---|---|---|---|
| `responseType` | `'accept'\|'counter'\|'decline'` | `@IsIn(['accept','counter','decline'])` | yes |
| `amount` | number | `@IsOptional() @IsNumber({maxDecimalPlaces:2}) @Min(0)` | required when `responseType='counter'` (else 400 `حدد قيمة العرض.`) |

`/accept`, `/decline` and the passenger counter routes take **no body**.

**Responses:**
* `GET offers/pending` → `{ offer: null }` when idle, otherwise
```ts
{ offer: { id, requestId, expiresAt },
  request: {                      // toRequestSummary()
    id, fromName, toName, fareEstimate, passengerFare, currency,
    seatCount, seatCountLabel,                       // "3 راكب"
    pickup: { latitude, longitude },
    distanceKm: "4.3", durationMinutes: "6",         // strings
    distanceLabel: "4.3 كم", durationLabel: "6 د",
    earningsLabel: "3.25 د.أ", tripTypeLabel: "مباشرة" } }
```
  It queries `status='offered'` ordered by `offeredAt DESC` — a `countered` offer is **not** returned here.
* `POST offers/:id/accept` and both passenger counter routes → the **request view** (F-04).
* `POST offers/:id/decline` → `{ ok: true }`.
* `POST offers/:id/respond` with `counter` → `{ ok: true, status: 'countered', proposedFare: "4.50", expiresAt: Date }`.

**Business rules & validation:**

*Dispatch selection* (`instant-dispatch.service.ts:59-122`)
1. No-ops unless the request exists and `status === 'searching'`.
2. If `expiresAt <= now`, calls `finalizeSearch()` and returns.
3. Exclusion set = drivers with an offer whose status ∈ `{offered, countered, accepted}` **OR** whose `offer.fareRevision >= request.fareRevision`. So a driver who declined at revision *n* becomes eligible again only after the fare is raised to *n+1*.
4. Candidate query at `radiusKm × 1000` metres, **limit 20**, nearest first (SQL below).
5. For each candidate, atomic soft-lock:
   `UPDATE driver_availability SET "currentRequestId"=:requestId WHERE "driverId"=:d AND "isOnline"=true AND "currentRequestId" IS NULL` — `affected === 1` wins; a loser is added to the exclusion list and the loop continues.
6. Radius expansion: `radiusKm = min(radiusKm + RADIUS_STEP_KM(3), MAX_RADIUS_KM(10))`, persisted on the request each step, until `radiusKm >= 10`; then `handleEmptySweep`.
7. `handleEmptySweep`: if `nudgedAt` is null, claim it with `UPDATE … WHERE id=? AND status='searching' AND nudgedAt IS NULL` and (only if `affected===1`) push `instant_raise_fare_nudge` — the nudge fires **exactly once per fare revision** (raising the fare resets `nudgedAt` to null). Then schedule the next wave.
8. `scheduleWave`: removes any existing job with id `instant-wave:<requestId>` then adds `dispatch-wave` with `delay = DISPATCH_RETRY_SECONDS(10) × 1000`, same jobId, `removeOnComplete/removeOnFail`.

*Making the offer* (`instant-dispatch.service.ts:192-260`)
9. Inserts the offer row: `status='offered'`, `fareRevision = request.fareRevision`, `offeredAt = now`, `expiresAt = now + OFFER_TTL_SECONDS (12 s)`.
10. `UPDATE instant_ride_requests SET status='offered' WHERE id=? AND status='searching'` (result not checked).
11. Push to the driver: title `طلب رحلة جديدة`, body = `"رحلة مباشرة بدون توقف\nمن <from> إلى <to>\n<earningsLabel>"`, `type='instant_offer'`, `data = {offerId, requestId, fromName, toName, fareEstimate, passengerFare, currency, expiresAt(ISO), …routeMetrics}`.
12. Bull `expire-offer` job: `delay=12000`, `jobId='instant-offer:<offerId>'`.

*Accept* (`instant-rides.service.ts:541-576`, `finalizeMatch` `778-881`)
13. Offer must exist for that driver (404 `العرض غير موجود.`) and be `offered` (409 `العرض لم يعد متاحاً.`); the request must be `offered` (409 `الطلب لم يعد متاحاً.`).
14. `acceptedFare = request.passengerFare ?? request.fareEstimate ?? '0'`.
15. `pickupEtaSeconds = max(60, round(haversineKm(driverIdlePoint, pickup) / PICKUP_ETA_SPEED_KMH(25) × 3600))`, or `null` if the driver has no stored point.
16. One transaction: conditional offer claim (`offered → accepted`), conditional request claim (`offered → accepted` + `matchedDriverId`, `acceptedFare`, `pickupEtaSeconds`); either `affected !== 1` ⇒ 409 and rollback.
17. Trip created with: `driverId`, `driverName`, from/to names+addresses+points copied, `departureTime = now`, `price = acceptedFare`, `currency`, `totalSeats = seatCount`, `availableSeats = 0`, `seatLayout=null`, `seats=[]`, `stops=[]`, `notes=null`, `status = TripStatus.IN_PROGRESS`, `tripType = TripType.INSTANT`, `tripStartedAt = now`, `isVisible = false`, `communicationFeeStatus = 'not_paid'`, `carImageUrl` from the vehicle.
18. Booking created with: `tripId`, `userId = passengerId`, `status = BookingStatus.CONFIRMED`, `seatCount`, `totalAmount = acceptedFare`, `seatPriceAtBooking = (fare / seatCount).toFixed(2)` (falls back to `acceptedFare` when `seatCount <= 0`), `expiresAt = null`.
19. `instant_ride_requests.tripId` written inside the same transaction.
20. After commit (outside the transaction) the three Bull jobs `instant-offer:<offerId>`, `instant-request:<requestId>`, `instant-wave:<requestId>` are removed best-effort.
21. Passenger push `instant_matched` `{requestId, tripId, driverId}`.
22. **The driver's soft lock is never released on accept** — `currentRequestId` stays pointing at the (now accepted) request until the driver goes offline (§13).

*Counter* (`instant-rides.service.ts:579-668`)
23. `amount` required; offer must be `offered`, request must be `offered`.
24. `proposed = round2(amount)` must satisfy `passengerFare < proposed ≤ round2(passengerFare × COUNTER_FARE_MAX_FACTOR(1.5))`, else 400 with the max in the message.
25. Conditional update `offered → countered` writing `proposedFare`, `respondedAt=now`, `expiresAt = now + COUNTER_TTL_SECONDS (30 s)`; `affected !== 1` ⇒ 409.
26. The 12 s offer-timeout job is removed and re-added with a 30 s delay under the **same jobId**.
27. Passenger push `instant_counter_offer` `{requestId, offerId, proposedFare, currency, expiresAt}`.
28. The **request stays `offered`** during a counter — dispatch is paused, and the passenger cannot raise their fare (rule 8 of F-04).

*Passenger accepts the counter* (`instant-rides.service.ts:672-703`)
29. Ownership + offer must be `countered` (409 `العرض لم يعد متاحاً.`); a wall-clock check rejects an expired counter with 409 `انتهت صلاحية العرض.`
30. `finalizeMatch(expectedOfferStatus='countered')` with `acceptedFare = offer.proposedFare ?? request.passengerFare ?? '0'`; driver push `instant_counter_accepted`.

*Passenger declines the counter* (`instant-rides.service.ts:705-748`)
31. Conditional `countered → rejected`; lock released; offer-timeout job removed; request `offered → searching`; driver push `instant_counter_rejected`; `dispatchNext` re-fired.

*Driver declines* (`instant-rides.service.ts:901-930`)
32. Offer must be `offered`. `offered → declined` (`respondedAt=now`), lock released, request `offered → searching`, timeout job removed, `dispatchNext` re-fired.

**Data model:** `instant_ride_offers` (§2.2), `driver_availability` (lock), `instant_ride_requests`, plus `trips` and `bookings` on match.

**Exact nearby-driver SQL** (`driver-availability.service.ts:111-155` — the matcher):
```sql
SELECT a.*,
       ST_Distance(a."point",
                   ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography) AS distance_meters
FROM driver_availability a
WHERE a."isOnline"        = true
  AND a."acceptsInstant"  = true
  AND a."currentRequestId" IS NULL
  AND a."point"           IS NOT NULL
  AND a."lastSeenAt"      >= :staleCutoff            -- now() - 60s
  AND ST_DWithin(a."point",
                 ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
                 :radiusMeters)
  AND a."driverId" NOT IN (:...excluded)             -- only when the list is non-empty
ORDER BY distance_meters ASC
LIMIT 20;                                            -- options.limit ?? 20
```

**Offer state machine:**

```
offered ─accept──────────────▶ accepted   [terminal]
   ├── decline ─────────────▶ declined   [terminal]
   ├── counter ─────────────▶ countered ──passenger accept──▶ accepted [terminal]
   │                              ├──passenger decline──────▶ rejected [terminal]
   │                              └──30 s timeout ──────────▶ timed_out [terminal]
   ├── 12 s timeout ────────▶ timed_out  [terminal]
   └── request cancelled / expired ─────▶ cancelled [terminal]
```

**Numeric constants** (`instant-rides.constants.ts`, authoritative):

| Constant | Value |
|---|---|
| `INITIAL_RADIUS_KM` | 3 |
| `RADIUS_STEP_KM` | 3 |
| `MAX_RADIUS_KM` | 10 |
| `OFFER_TTL_SECONDS` | 12 |
| `REQUEST_TTL_SECONDS` | 180 |
| `DISPATCH_RETRY_SECONDS` | 10 |
| `NUDGE_FARE_BUMP_FACTOR` | 1.15 |
| `PICKUP_ETA_SPEED_KMH` | 25 |
| `FARE_BASE` / `FARE_PER_KM` / `FARE_PER_MIN` / `FARE_MINIMUM` | 1.0 / 0.5 / 0.1 / 1.5 |
| `PASSENGER_FARE_MIN_FACTOR` / `PASSENGER_FARE_MAX_FACTOR` | 0.7 / 2.0 |
| `COUNTER_FARE_MAX_FACTOR` | 1.5 |
| `COUNTER_TTL_SECONDS` | 30 |
| stale-heartbeat threshold | 60 000 ms (`driver-availability.service.ts:36`) |
| candidate limit per radius step | 20 |
| `OFFER_TRIP_AVG_SPEED_KMH` (label only) | 50 (`instant-offer-labels.ts:9`) |

**Display-label helpers** (`instant-offer-labels.ts`) — reproduce exactly for UI parity:
* `haversineKm`: R = 6371 km, standard formula, `asin(min(1, sqrt(h)))`.
* `formatDistanceLabel(km)`: round to 1 dp; render as an integer when it is (or is within 0.05 of) a whole number; suffix `" كم"`.
* `formatDurationLabel(min)`: `max(1, round(min))`; `< 60` → `"<n> د"`; whole hours → `"<h> س"`; else `"<h> س <m> د"`.
* `formatEarningsLabel(amount, currency)`: symbol `JOD|د.أ → "د.أ"`, `SAR|ر.س → "ر.س"`, otherwise the raw currency code; amount `toFixed(2)`, or the raw string / `"—"` when not finite.
* `formatSeatCountLabel(n)`: `"<max(1,round(n))> راكب"`.
* `buildInstantOfferRouteMetrics`: straight-line `distanceKm`; `durationMinutes = max(1, round(distanceKm / 50 × 60))`; `tripTypeLabel` is the literal `"مباشرة"`. **These offer-card metrics are haversine-based, not routed** — they will differ from the quote's Google-based distance.

**External services:** Firebase FCM (all four notification types), Redis/Bull, Postgres/PostGIS. Every `sendPush` is `.catch(() => undefined)` — push failure never blocks dispatch.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| offer not found for this driver | 404 | `العرض غير موجود.` |
| offer no longer `offered`/`countered` | 409 | `العرض لم يعد متاحاً.` |
| request no longer `offered` | 409 | `الطلب لم يعد متاحاً.` |
| counter without `amount` | 400 | `حدد قيمة العرض.` |
| counter out of band | 400 | `قيمة العرض يجب أن تكون أعلى من سعر الراكب وبحد أقصى <max> <CUR>.` |
| counter expired (passenger accept) | 409 | `انتهت صلاحية العرض.` |
| non-driver on a driver route | 403 | `Access denied. Required roles: driver` |

**Notes for reimplementation (concurrency):**
* Every state change is a conditional `UPDATE … WHERE id = ? AND status = <expected>` and the caller checks `affected`. This is the optimistic-concurrency scheme throughout; reproduce it or use `SELECT … FOR UPDATE`.
* The driver soft lock is the only mutual exclusion for dispatch; a driver can never hold two offers.
* `dispatchNext` is invoked from four places (create, fare raise, decline, counter-decline) plus the two Bull processors. It is re-entrant-safe only because of the `status='searching'` guard and the atomic lock — two concurrent invocations can still make **two** offers if both observe `searching` before either flips it to `offered` (the flip is not `affected`-checked at `instant-dispatch.service.ts:209-212`). Harden this in a rebuild.
* The offer-timeout jobId is reused across the offer's 12 s and 30 s phases; the processor re-reads the row and accepts both `offered` and `countered`, so a stale job is harmless.
* `dispatchNext`'s radius loop is `for(;;)` and terminates only via the `radiusKm >= MAX_RADIUS_KM` branch — an implementation that forgets the cap will spin forever.

---

## F-06: Instant-ride background jobs (offer timeout, request expiry, dispatch waves)

**What it does:** Enforces the 12 s / 30 s / 180 s clocks and keeps a search alive with periodic re-dispatch waves.

**Actors:** system.

**API Endpoints:** none.

**Queues** (`BullModule.registerQueue` in `instant-rides.module.ts:44-47`, Redis connection from `src/jobs/jobs.module.ts:13-18`):

| Queue | Job name | jobId pattern | Delay | Processor |
|---|---|---|---|---|
| `instant-offer-timeout` | `expire-offer` | `instant-offer:<offerId>` | 12 000 ms (or 30 000 ms after a counter) | `processors/instant-offer-timeout.processor.ts` |
| `instant-request-expiry` | `expire-request` | `instant-request:<requestId>` | 180 000 ms | `processors/instant-request-expiry.processor.ts` |
| `instant-request-expiry` | `dispatch-wave` | `instant-wave:<requestId>` | 10 000 ms | same processor, `handleWave` |

All jobs are added with `removeOnComplete: true, removeOnFail: true`. There are **no cron/`@Cron` tasks** in this domain (`ScheduleModule.forRoot()` exists globally for other domains — `app.module.ts:74`).

**`expire-offer` behaviour** (`instant-offer-timeout.processor.ts:38-65`):
1. Load the offer; return if missing or its status is neither `offered` nor `countered` (covers an unanswered offer **and** an ignored counter-offer).
2. `UPDATE offer SET status='timed_out', respondedAt=now WHERE id=? AND status=<observed>`.
3. Release the driver: `UPDATE driver_availability SET currentRequestId=NULL WHERE driverId=? AND currentRequestId=?`.
4. `UPDATE request SET status='searching' WHERE id=? AND status='offered'`.
5. `await dispatch.dispatchNext(requestId)`.
6. `@OnQueueFailed` logs `Offer-timeout job <id> failed: <msg>` with the stack.

**`expire-request` behaviour** (`instant-request-expiry.processor.ts:46-83`):
1. Load the request; return unless status is `searching` or `offered`.
2. Cancel any `offered|countered` offer (`status='cancelled'`, `respondedAt=now`) and release that driver's lock.
3. `dispatch.finalizeSearch(requestId, offer ? 'ttl_expired' : undefined)` — the forced reason is needed because step 2 already cancelled the outstanding offer, which would otherwise make the inferred reason read `all_declined`.

**`dispatch-wave` behaviour:** simply `await dispatch.dispatchNext(requestId)`.

**`finalizeSearch`** (`instant-dispatch.service.ts:267-318`) — the single place a search ends without a match:
1. Reason = forced, else inferred: no offers ⇒ `no_eligible_drivers`; any offer still `offered|countered` ⇒ `ttl_expired`; otherwise `all_declined`.
2. Atomic claim `UPDATE … SET status='expired', terminalReason=?, endedAt=now WHERE id=? AND status IN ('searching','offered')`; `affected === 0` ⇒ return `false` and **do not notify** (loser of the race stays silent).
3. Structured PII-free log: `instant_search_ended {"requestId","passengerId","terminalReason","offerCount"}` — deliberately no coordinates or addresses.
4. Passenger push `instant_no_drivers`, titled `انتهت مهلة الطلب` when the reason is `ttl_expired`, otherwise `لا يوجد سائق متاح`; data `{requestId, terminalReason}`.

**Notes for reimplementation:**
* Bull `add()` failures are caught and only warn-logged in every producer (`instant-rides.service.ts`, `instant-dispatch.service.ts`) — a Redis outage silently disables all expiry. A rebuild should either fail the request or add a DB-driven sweeper for rows with `expiresAt < now() AND status IN ('searching','offered')`.
* `removeJob` / `scheduleWave` cleanup is wrapped in bare `try {} catch {}` — never let cleanup failures propagate.
* Because jobIds are deterministic, re-adding the same jobId is a no-op in Bull unless the prior job is removed first — `scheduleWave` and the counter path both remove-then-add for exactly that reason.

---

## F-07: Live driver-location tracking

**What it does:** Ingests a driver's GPS stream over WebSocket during a trip, persists a location trail, keeps a live ETA on the trip, and fans the position out to everyone watching the trip.

**Actors:** driver (emits), any authenticated user (subscribes; **no participation check** — see notes).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/tracking/:tripId/latest` | JWT | Latest known trip location + ETA |
| GET | `/api/v1/tracking/:tripId/history?limit=` | JWT | Location trail, newest first |
| GET | `/api/v1/tracking/nearby/trips?latitude=&longitude=&radiusMeters=` | JWT | Nearby visible trips (PostGIS) |

**WebSocket events** (namespace `/tracking`, `cors.origin='*'`, `tracking.gateway.ts:20-23`):

| Event | Direction | Payload | Notes |
|---|---|---|---|
| `trip:tracking:subscribe` | c→s | `{tripId}` (`@IsString`) | joins `trip:<tripId>`; ack includes an immediate `snapshot` |
| `trip:tracking:unsubscribe` | c→s | `{tripId}` | leaves the room |
| `driver:location:update` | c→s | `UpdateDriverLocationDto` | guarded by `LocationGuardInterceptor` |
| `trip:tracking:update` | s→c | location view | broadcast to `trip:<tripId>` |
| `trip:tracking:snapshot` | s→c | location view | **dead** — `emitTripTrackingSnapshot` has no callers |

Room naming: `trip:<tripId>` for trip watchers; `user:<userId>` joined in `handleConnection` (unreliable, see notes).

**Request contract — `UpdateDriverLocationDto`** (`dto/update-driver-location.dto.ts`):
| Field | Type | Rules | Req. |
|---|---|---|---|
| `tripId` | string | `@IsString()` | yes |
| `latitude` | number | `@IsNumber() @Min(-90) @Max(90)` | yes |
| `longitude` | number | `@IsNumber() @Min(-180) @Max(180)` | yes |
| `speedKph` | number | `@IsOptional() @IsNumber() @Min(0)` | no |
| `heading` | number | `@IsOptional() @IsNumber() @Min(0) @Max(360)` | no |
| `accuracyMeters` | number | `@IsOptional() @IsNumber() @Min(0)` | no |
| `isMockLocation` | boolean | `@IsOptional() @IsBoolean()` | no — `true` ⇒ rejection + security event |

**Response shape** (ack `data`, `trip:tracking:update` payload, and `GET :tripId/latest`):
```ts
{ id: string|null, tripId: string, driverId: string|null,
  latitude: number, longitude: number,
  speedKph: number|null, heading: number|null, accuracyMeters: number|null,
  recordedAt: Date,
  remainingDistanceKm: number|null, remainingDurationSeconds: number|null,
  etaAt: Date|null, routeProgressPercent: number|null }
```
`GET :tripId/latest` returns `null` when there is neither a `driver_locations` row nor a `trips.lastDriverLocationLat/Lng`; when only the trip columns exist it returns the same shape with `id=null, driverId=null, speedKph/heading/accuracyMeters=null` (`tracking.service.ts:241-267`).

`GET :tripId/history` → array of `{id, tripId, driverId, latitude, longitude, speedKph, heading, accuracyMeters, recordedAt}` ordered `recordedAt DESC`, `take = min(max(limit,1),500)`, default `limit = 100`.

`GET nearby/trips` → raw `TripEntity[]` (whole rows, no projection).

**Business rules & validation:**
1. `updateDriverLocation` loads the trip with `where: {id: tripId, driverId}` — a caller who is not that trip's driver gets `NotFoundException('Trip not found for this driver')` (surfaces as a `WsException`/ack error over the socket).
2. A `driver_locations` row is inserted for **every** update — there is **no throttling, deduplication or minimum-distance filter** anywhere.
3. `trips.lastDriverLocationLat/Lng/At` are stamped on every update.
4. ETA refresh is rate-limited to at most once per **`ETA_REFRESH_MS = 45 000`** per trip, measured against `trips.etaComputedAt` (`tracking.service.ts:8, 107-113`), plus an **in-process `Set<tripId>`** in-flight guard so two concurrent updates don't both call the routing provider.
5. ETA refresh needs `trip.toPoint.coordinates`; otherwise it is skipped.
6. On success it writes `remainingDistanceKm = round2(distanceMeters/1000)`, `remainingDurationSeconds = max(0, round(durationSeconds))`, `etaAt = now + remainingDurationSeconds`, `routeProgressPercent`, `etaComputedAt = now`.
7. `routeProgressPercent = clamp(0..100, (totalGreatCircle − remainingGreatCircle) / totalGreatCircle × 100)` to 1 dp; `100` when the origin→destination distance is ≤ 0.01 km; `0` when `fromPoint` is missing (`tracking.service.ts:175-203`). It is a straight-line approximation, **not** route-following.
8. Routing errors are caught and warn-logged (`ETA refresh failed for trip <id>: <msg>`); the update still succeeds with the previously stored ETA fields.
9. `getNearbyTrips` defaults `radiusMeters = 5000` and filters on the **legacy** `status = 'active'` — see notes.
10. `LocationGuardInterceptor` (`src/common/interceptors/location-guard.interceptor.ts`) runs before the handler on `driver:location:update` only: if the payload has a truthy `isMockLocation` **and** `client.data.userId` is set, it
   a. writes a `security_events` row `{userId, eventType:'mock_location_rejected', metadata:{tripId, latitude, longitude}}`,
   b. counts `mock_location_rejected` events for that user in the last **30 days**,
   c. at **≥ 3** events creates an open `account_flags` row `{reason:'mock_location_repeated', severity: HIGH, disposition: OPEN, notes:'<n> mock-location events detected within 30 days.'}` (idempotent — skipped if an open flag already exists),
   d. throws `WsException({code:'LOCATION_INTEGRITY_VIOLATION', message:'Mock location detected. Location update rejected.'})`.

**Exact nearby-trips SQL** (`tracking.service.ts:307-326`):
```sql
SELECT trip.* FROM trips trip
WHERE trip.status = 'active'
  AND trip."isVisible" = true
  AND ST_DWithin(trip."fromPoint",
                 ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
                 :radiusMeters);
```

**Data model:** `driver_locations` (§2.4) plus these `trips` columns: `lastDriverLocationLat`, `lastDriverLocationLng`, `lastDriverLocationAt`, `remainingDistanceKm`, `remainingDurationSeconds`, `etaAt`, `routeProgressPercent`, `etaComputedAt`, `fromPoint`, `toPoint`, `isVisible`, `status` (`src/database/entities/trip.entity.ts:105-171`).

**State machine:** none of its own; it reads/writes trip ETA fields.

**External services:** `LocationsService.getRoute` → Google Directions with OSRM fallback (F-08). Redis is not used. No Socket.IO adapter, so broadcasts are **per-process only**.

**Background jobs:** none.

**Errors:**

| Condition | Surface | Code/message |
|---|---|---|
| trip not owned by the emitting driver | WS ack error | `Trip not found for this driver` (404 semantics) |
| mock GPS | `WsException` | `{code:'LOCATION_INTEGRITY_VIOLATION', message:'Mock location detected. Location update rejected.'}` |
| > 180 WS events/min | `BadRequestException` | `Too many websocket events, try again shortly` |
| bad/missing handshake token | `UnauthorizedException` | `WebSocket authentication token not found` / `Invalid or expired WebSocket token` |

**Notes for reimplementation:**
1. **Authorisation hole:** `trip:tracking:subscribe` performs **no** check that the caller is the driver or a passenger of the trip — any authenticated user who knows a `tripId` can watch it live and receive the snapshot. Add a participation check.
2. **Unbounded writes:** every ping is a row. At a 3-second cadence that is ~1 200 rows per hour per active trip with no retention job. Consider batching, a minimum-displacement filter, or a TTL/partitioned table.
3. `getNearbyTrips` filters `status = 'active'`, which migration 008.06 converted to `'published'` (`shared.enums.ts:7-22` marks `ACTIVE` `@deprecated`). This endpoint therefore returns **nothing** on a migrated database — a live bug. `verify: src/modules/tracking/tracking.service.ts:314`.
4. The ETA in-flight `Set` and the WS rate-limit `Map` are per-process; they do not coordinate across replicas.
5. `handleConnection` joins `user:<userId>` from `client.data.userId`, which `WsAuthGuard` only sets when a *message* handler runs — so at connection time it is normally `undefined` and the join is skipped. The `user:` room in `/tracking` is effectively unused. `verify: src/modules/tracking/tracking.gateway.ts:31-36`.
6. There is no Socket.IO Redis adapter: with more than one backend instance, a passenger connected to instance A will not receive updates emitted on instance B. This is the single biggest scaling blocker in the domain.
7. `driver_locations.speedKph/heading/accuracyMeters` are `numeric` and come back from TypeORM as **strings**; the service converts them with `Number(...)` on read.

---

## F-08: Location services (autocomplete, place detail, geocode, distance, route)

**What it does:** Server-side proxy for all map/place lookups so no provider key ever reaches the client, with a free OSM-based type-ahead and a graceful routing fallback.

**Actors:** any authenticated user (`LocationsController` is `@UseGuards(JwtAuthGuard)`; nothing is `@Public()`).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/locations/autocomplete?q=&lang=&sessionToken=&lat=&lng=` | JWT | Place type-ahead (Photon) |
| GET | `/api/v1/locations/place/:id` | JWT | Resolve a suggestion to coordinates |
| GET | `/api/v1/locations/geocode?address=` | JWT | Address → coordinates (Google) |
| GET | `/api/v1/locations/reverse-geocode?latitude=&longitude=` | JWT | Coordinates → address + country code (Google) |
| GET | `/api/v1/locations/distance?fromLatitude=&fromLongitude=&toLatitude=&toLongitude=` | JWT | Distance Matrix (Google) |
| GET | `/api/v1/locations/route?fromLatitude=&fromLongitude=&toLatitude=&toLongitude=` | JWT | Driving route polyline (Google → OSRM) |

**Request contracts:**

`LocationAutocompleteQueryDto` (`dto/location-autocomplete.dto.ts`):
| Field | Type | Rules | Req. |
|---|---|---|---|
| `q` | string | `@IsString()` | yes |
| `lang` | `'ar'\|'en'` | `@IsOptional() @IsIn(['ar','en'])` | no (default `ar`) |
| `sessionToken` | string | `@IsOptional() @IsString()` | no (server mints a `randomUUID()`) |
| `lat` | numeric string | `@IsOptional() @IsNumberString()` | no (result bias) |
| `lng` | numeric string | `@IsOptional() @IsNumberString()` | no |

The other five endpoints take **raw `@Query()` params with no DTO and no validation** (`locations.controller.ts:45-99`) — `latitude`/`longitude` are typed `number` and rely on the global `enableImplicitConversion`; garbage in ⇒ `NaN` forwarded to the provider.
`PlaceDetailQueryDto` exists but is **never referenced** by the controller (dead — `dto/place-detail.dto.ts:3-7`, `locations.controller.ts:40-43`).

**Response shapes:**
```ts
// autocomplete
{ sessionToken: string,
  suggestions: [{ placeId: string, primaryText: string, secondaryText: string, description: string }] }
// place/:id
{ placeId: string, label: string, lat: number, lng: number }
// geocode
{ latitude, longitude, formattedAddress, placeId }
// reverse-geocode
{ address, city, country, countryCode }     // countryCode = ISO-3166-1 alpha-2, e.g. "JO"
// distance
{ distanceKm: number, distanceText: string, durationMinutes: number, durationText: string }
// route
{ overviewPolyline: string, distanceText: string, durationText: string,
  distanceMeters: number|null, durationSeconds: number|null }
```

**Business rules & validation** (`locations.service.ts`):
1. Autocomplete short-circuits with `{sessionToken, suggestions: []}` when `q.trim().length < 2` — **before** the rate-limit check.
2. **Per-user rate limit: 60 requests / 60 000 ms**, in an in-process `Map` keyed by `req.user.id ?? req.user.sub ?? 'unknown'`; over the limit ⇒ **429** `Too many location requests` (`locations.service.ts:79-81, 569-584`). The window is a fixed window, not sliding, and the map is never evicted.
3. **In-process response cache, TTL 60 000 ms**, key `"<q.toLowerCase()>|<lang>|<countries>|<lat,lng | 'none'>"` (`locations.service.ts:79, 121-130, 600-618`). Cache hits still return a session token but skip the provider. Unbounded map.
4. Photon call: `GET {PHOTON_BASE_URL}/api/?q=&limit=6&lang=&lat=&lon=`, header `User-Agent: <GEOCODER_USER_AGENT>`, `timeout: 8000` ms. **`lang` is sent only for `en`** — for Arabic it is omitted so Photon returns native place names (`locations.service.ts:141-146`).
5. Country filter: only applied when `LOCATION_AUTOCOMPLETE_COUNTRIES` is non-empty; a feature with **no** `countrycode` passes the filter (`locations.service.ts:171-175`).
6. Suggestion mapping (`toSuggestion`, `locations.service.ts:198-244`): requires `geometry.coordinates` of length ≥ 2 with finite numbers, and a non-empty `primaryText = properties.name ?? properties.street`. `secondaryText` is built from `street, district, city, county, state, country`, de-duplicated against each other and against `primaryText`, joined with the Arabic comma `"، "`. `description = primaryText + "، " + secondaryParts`. Results are truncated to **6**.
7. **`placeId` encodes the coordinates**: `"osm:" + base64url(JSON.stringify({lat, lng, label}))` — so `GET /locations/place/:id` is a **pure local decode with no network call** (`locations.service.ts:177-192, 246-276`). Any id not starting with `osm:`, or whose payload does not decode to finite `lat`/`lng`, ⇒ **404** `Place not found`. This means place ids are **client-forgeable** — treat the coordinates as untrusted input.
8. `geocode` / `reverseGeocode` / `getDistance` call Google with `key = GOOGLE_MAPS_API_KEY`; a provider `status !== 'OK'` (or any throw) ⇒ **400** with `Address not found` / `Location not found` / `Failed to calculate distance` / `Failed to geocode address` / `Failed to reverse geocode location`. **There is no fallback for these three** — with no Google key they always 400.
9. `reverseGeocode` picks `city` as the first component whose `types` include **both** `locality` and `administrative_area_level_2` (`types.every(...)`), which is rare in practice; `countryCode` is the `country` component's `short_name`. `verify: src/modules/locations/locations.service.ts:337-350`.
10. `getRoute` (`locations.service.ts:400-487`): no API key ⇒ straight to OSRM. Otherwise `GET /directions/json?origin=&destination=&key=&language=ar`; falls back to OSRM when `status !== 'OK'`, when the payload lacks a route/leg/`overview_polyline`, or on any unexpected error. Each fallback is warn/error-logged.
11. OSRM fallback: `GET https://router.project-osrm.org/route/v1/driving/{fromLng},{fromLat};{toLng},{toLat}?overview=full&geometries=polyline&steps=false`. `code !== 'Ok'` ⇒ **400** `Failed to load route: OSRM <code> - <message>`; missing geometry ⇒ 400 `Failed to load route: OSRM empty route payload`; any other error ⇒ 400 `Failed to load route`.
12. OSRM distance/duration text is formatted server-side: `≥ 10 km → "<n> كم"` (0 dp) else `"<n.n> كم"`; duration `max(1, round(sec/60))`, `< 60 → "<n> دقيقة"`, whole hours `"<h> ساعة"`, else `"<h> ساعة <m> دقيقة"`.

**External services:**

| Provider | Base URL | Used for | Failure behaviour |
|---|---|---|---|
| Photon (OSM) | `PHOTON_BASE_URL` (default `https://photon.komoot.io`) | autocomplete | **502** `Places provider unavailable` |
| Google Geocoding | `https://maps.googleapis.com/maps/api/geocode/json` | geocode, reverse-geocode | 400 |
| Google Distance Matrix | `.../distancematrix/json` | distance | 400 (callers of `computeQuote` fall back to haversine) |
| Google Directions | `.../directions/json` | route | falls back to OSRM |
| OSRM (public demo) | `https://router.project-osrm.org` | route fallback | 400 |

`googleMapsBaseUrl` and `osrmBaseUrl` are **hard-coded** (`locations.service.ts:55-56`) — not configurable.

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| > 60 location requests/min per user | 429 | `Too many location requests` |
| Photon unreachable / non-2xx | 502 | `Places provider unavailable` |
| unknown or malformed `placeId` | 404 | `Place not found` |
| Google geocode/distance failure | 400 | per-endpoint message above |
| routing failure after fallback | 400 | `Failed to load route[: OSRM …]` |

**Notes for reimplementation:**
* The public Photon and OSRM instances have their own rate limits and no SLA; self-host both for production.
* `sessionToken` is accepted, echoed and otherwise **ignored** — it is a Google-Places-style vestige with no billing semantics here.
* The caches and rate-limit buckets are per-process `Map`s — move to Redis when running more than one instance.
* Preserve the `osm:`-prefixed base64url placeId encoding if you want the mobile client to keep working unchanged; otherwise validate decoded coordinates server-side.

---

## F-09: Trip chat (rooms, messages, live delivery)

**What it does:** Gives a trip's driver and passengers a text channel — a 1:1 room per driver↔passenger pair and one trip-wide group room — over REST plus a Socket.IO namespace, with an FCM push to every other participant on each message.

**Actors:** driver and passengers of a trip (participation-checked). Admins have no special path.

**API Endpoints** (`chat-postgres.controller.ts`, `@Controller('chat')`):

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/chat/rooms?page=&limit=` | JWT | The caller's rooms, newest activity first |
| GET | `/api/v1/chat/rooms/trip/:tripId/passenger/:passengerId` | JWT (driver of trip) | Get/create the 1:1 room |
| GET | `/api/v1/chat/rooms/trip/:tripId/group` | JWT (participant) | Get/create the trip group room |
| GET | `/api/v1/chat/rooms/:idOrTripId` | JWT | Room by room-id, or (passenger) get/create the 1:1 room by trip-id |
| GET | `/api/v1/chat/rooms/:id/messages?page=&limit=` | JWT (participant) | Message page, oldest-first within the page |
| POST | `/api/v1/chat/rooms/:id/messages` | JWT (participant) | Send a message (201) |

Route-order caveat: `rooms/trip/...` and `rooms/:idOrTripId` share a prefix; the specific routes are declared first, so they win. Keep that order in a rebuild.

**WebSocket events** (namespace `/chat`, `cors.origin='*'` — `chat-postgres.gateway.ts:20-23`): see §3. Room key `room:<chatRoomId>`.

**Request contracts:**
* `SendMessageDto` (`dto/send-message.dto.ts`): `text` — `@IsString() @IsNotEmpty() @MinLength(1) @MaxLength(2000)`, required.
* `PaginationDto` — `page`, `limit` (`src/common/dto/pagination.dto.ts`). Defaults applied in the service: rooms `page=1, limit=20`; messages `page=1, limit=50` (the controller also forces `limit || 50`).
* WS `sendMessage` payload `{chatRoomId, text}` is **not** DTO-validated — no `ValidationPipe` is applied to the gateway, so the 1–2000 char rule is bypassed over the socket (§13).
* `CreateChatRoomDto` (`dto/create-chat-room.dto.ts`) is **dead** — no controller references it.

**Response shapes:**
* Room: the raw `ChatRoomEntity` (`id, tripId, passengerId, participants[], lastMessage, lastMessageTime, lastMessageSenderId, createdAt, updatedAt`), with `trip` eagerly joined on some paths.
* `GET rooms` → `{ data: ChatRoomEntity[], meta: { page, limit, total, totalPages } }`.
* `GET rooms/:id/messages` → `{ data: MessageEntity[], meta: {...} }` — fetched `createdAt DESC` then **`.reverse()`**d, so within a page messages are ascending while pages walk backwards in time.
* `POST rooms/:id/messages` → the saved `MessageEntity`, HTTP **201**.

**Business rules & validation** (`chat-postgres.service.ts`):
1. **1:1 room, driver-initiated** (`getOrCreateRoomForDriverPassenger`, :39-81): trip must exist (404); caller must be `trip.driverId` (403 `You are not the driver of this trip`); the named passenger must hold a booking on that trip with status ∈ `{pending, confirmed}` (403 `Passenger must have a pending or confirmed booking for this trip`). Lookup key `{tripId, passengerId}`; on create, `participants = [{driverId, now}, {passengerId, now}]`.
2. **1:1 room, passenger-initiated** (`getOrCreateRoom`, :84-119): the driver calling it gets **400** `Driver must use trip+passenger endpoint to open 1:1 chat`. Passenger must have a `pending|confirmed` booking (403 `You must have a pending or confirmed booking to access this chat`).
3. **Group room** (`getOrCreateGroupRoom`, :128-189): the group room is the row with `passengerId IS NULL`. The driver always has access; a passenger needs a `pending|confirmed` booking. Membership is **reconciled lazily on every access**: eligible set = `[trip.driverId, ...distinct passengerIds with pending|confirmed bookings]`; any eligible member missing from `participants` is appended with `joinedAt = now` and the row re-saved. Members are **never removed** — a cancelled passenger keeps read/write access.
4. **Sending** (`sendMessage`, :250-321): room must exist (404); the sender must appear in `participants` (403 `You are not a participant in this chat room`); if `room.trip.status ∈ {'completed','cancelled'}` ⇒ **400** `{statusCode:400, code:'CHAT_CLOSED_TRIP_ENDED', message:'This trip has ended, so you can no longer send messages'}`. The sender user must exist (404).
5. On send: insert the message with `senderName` snapshotted from `users.name`; update the room's `lastMessage = text.substring(0,100)`, `lastMessageTime = message.createdAt`, `lastMessageSenderId`.
6. A notification is created for **every participant except the sender** — `type='chat_message'`, title `رسالة جديدة`, body `"<name>: <first 50 chars>[...]"`, data `{chatRoomId, tripId, senderId, senderName, senderRole}`. These are awaited **sequentially in a loop**, so a room with many members slows the send.
7. **Reading** (`getMessages`) requires participation (403). **Listing** (`getRoomsByUser`) selects rooms where the caller's id appears in the `participants` jsonb:
```sql
EXISTS (SELECT 1
        FROM jsonb_array_elements(COALESCE(r.participants, '[]'::jsonb)) elem
        WHERE elem->>'userId' = :userId)
```
   ordered `lastMessageTime DESC NULLS LAST, createdAt DESC`. This predicate cannot use an index — add a GIN index on `participants` or a join table at scale.
8. `getRoomByIdOrTripId` (:416-436): tries the id as a room id first (403 if the caller is not a participant); if no such room exists it treats the argument as a **trip id** and falls through to `getOrCreateRoom` (which 400s for drivers).
9. **Gateway `joinRoom`** (`chat-postgres.gateway.ts:61-101`) calls `getRoomById(chatRoomId, userId)` first. If the thrown error's `response.code === 'BOOKING_NOT_SETTLED'`, it emits `error {code: 4403, message:'Chat is only available after the driver marks the booking as paid'}` and **disconnects the socket**. Any other error emits `error {message}` without disconnecting. **Nothing in `ChatPostgresService` ever throws `BOOKING_NOT_SETTLED`** — the settlement gate was removed, so this branch is unreachable today (§9, §13). `WS_CODE_BOOKING_NOT_SETTLED = 4403`.
10. `sendMessage` over the socket wraps errors: the ack becomes `{event:'error', message}` instead of an exception, and the message is simply not delivered.
11. `addParticipant(roomId, userId)` exists on the service but is **not exposed by any controller or gateway** (dead — `chat-postgres.service.ts:224-248`).

**Data model:** `chat_rooms` (§2.5), `messages` (§2.6); reads `trips` and `bookings`.

**State machine:** rooms have no status column. The only lifecycle rule is the `completed|cancelled` trip-status gate on sending.

**External services:** Firebase FCM via `NotificationsService.create`; Socket.IO. `PaymentsModule` is imported (`forwardRef`) but its only relevant method, `hasUserPaidCommunicationFee`, is a **stub returning `false`** (`payments.service.ts:546-551`) and `ChatPostgresService` never calls it.

**Background jobs:** none.

**Errors:**

| Condition | HTTP / WS | Body |
|---|---|---|
| trip / room / user not found | 404 | `Trip not found` / `Chat room not found` / `User not found` |
| driver calls the passenger-style route | 400 | `Driver must use trip+passenger endpoint to open 1:1 chat` |
| caller is not the trip's driver | 403 | `You are not the driver of this trip` |
| no `pending\|confirmed` booking | 403 | `Passenger must have a pending or confirmed booking for this trip` / `You must have a pending or confirmed booking to access this chat` |
| not in `participants` | 403 | `You are not a participant in this chat room` |
| trip completed/cancelled | 400 | `{code:'CHAT_CLOSED_TRIP_ENDED'}` |
| settlement gate (unreachable) | WS `error` | `{code: 4403, message:'Chat is only available after the driver marks the booking as paid'}` |
| > 180 WS events/min | WS exception | `Too many websocket events, try again shortly` |

**Notes for reimplementation:**
1. **No server-side authorisation on `joinRoom` beyond `getRoomById`** — that check *is* participation-based, so it is sound; but `sendMessage`, `typing` and `stopTyping` over the socket broadcast to `room:<chatRoomId>` **without verifying the sender is in that room** for the typing events (only `sendMessage` re-checks via the service). A user can spam `userTyping` into any room id they can guess (`chat-postgres.gateway.ts:156-188`).
2. Group-room creation is **not** protected by a unique index (only the 1:1 pair is), so two simultaneous first-accesses can create two group rooms for one trip.
3. `participants` is a jsonb array read-modify-written whole — concurrent membership reconciliations can lose an append. A join table would be the correct model.
4. WS `sendMessage` bypasses `SendMessageDto`; enforce length/emptiness in the service, not the DTO.
5. There is no read-receipt, no unread counter, no message editing/deletion, and no attachment support anywhere.
6. `messages.senderId` is `ON DELETE RESTRICT`, so a user with messages cannot be hard-deleted.

---

## F-10: Masked voice calls (Twilio proxy DID)

**What it does:** Hands a booking participant a shared Twilio proxy phone number so the two sides can call each other without exposing their real numbers, and records the call's lifecycle from Twilio's status webhook.

**Actors:** the passenger or the driver on a booking; Twilio (webhook, anonymous but signature-verified).

**API Endpoints** (`calls.controller.ts`, `@Controller()` — no controller-level prefix segment):

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/bookings/:id/calls/initiate` | JWT (participant) | Allocate a proxy number, open a call session (201) |
| POST | `/api/v1/calls/twilio-webhook` | `@Public()` + `X-Twilio-Signature` | Twilio call-status callback (200) |

**Request contracts:**
* `initiate` — **no body**; the booking id comes from the path and the caller from the JWT.
* `twilio-webhook` — Twilio's `application/x-www-form-urlencoded` body, consumed as `Record<string,string>`. Fields used: `CallSid`, `CallStatus`, `CallDuration`.

**Responses:**
```ts
// POST bookings/:id/calls/initiate  → 201
{ callSessionId: string, proxyNumberE164: string, expiresAt: string /* ISO */ }
// POST calls/twilio-webhook → 200
{ received: true }
```

**Business rules & validation:**
1. Booking must exist (404 `Booking not found`); it is loaded with `relations:['trip']`.
2. Caller must be the booking's passenger (`booking.userId`) or the trip's driver (`booking.trip.driverId`) — else 403 `You are not a participant in this booking`.
3. `booking.status` must be in `CALLABLE_BOOKING_STATUSES = [PENDING, CONFIRMED, IN_PROGRESS]` (`calls.service.ts:33-37`) — else 403 `This booking is no longer active, so calls are closed for it`. `IN_PROGRESS` is included deliberately because the auto-start job flips confirmed bookings at departure time, which is exactly when pickup calls happen.
4. Both user rows must exist (404 `User not found`).
5. **Proxy allocation** (`proxy-pool.service.ts:52-91`):
   a. Pool = `TWILIO_PROXY_NUMBERS.split(',').map(trim).filter(Boolean)`. Empty pool ⇒ **503** `{statusCode:503, code:'NO_PROXY_NUMBERS_AVAILABLE', message:'No proxy numbers are configured'}` (a warning is logged at construction).
   b. If **any** prior `call_sessions` row exists for this booking (`order: createdAt ASC`), its `proxyNumber` is reused unconditionally — stable number per booking for the life of the booking.
   c. Otherwise it collects the `proxyNumber` of every session with `status != 'completed'` belonging to a **different** booking, and picks the first pool entry not in that locked set.
   d. All numbers locked ⇒ **503** `{code:'NO_PROXY_NUMBERS_AVAILABLE', message:'All proxy numbers are currently in use — please try again shortly'}`.
6. `expiresAt = now + SESSION_EXPIRY_MINUTES (60) × 60 000 ms` (`calls.service.ts:20, 89`). **It is returned to the client but never persisted** — nothing enforces it server-side.
7. The session row is created with `status='initiated'`, `callerRealNumber = caller.phoneNumber`, and `calleeRealNumber = callee.hidePhoneNumber ? null : callee.phoneNumber` (audit-only fields).
8. **Webhook signature verification** (`calls.controller.ts:44-65`): `twilio.validateRequest(TWILIO_AUTH_TOKEN, req.headers['x-twilio-signature'], `${req.protocol}://${req.get('host')}${req.originalUrl}`, body)`. Invalid ⇒ **403** `Invalid Twilio signature` plus a warn log. Behind a reverse proxy, `req.protocol`/`Host` must match exactly what Twilio signed — `trust proxy` is **not** enabled in `main.ts`, so an HTTPS-terminating proxy will make `req.protocol` read `http` and every signature will fail. `verify: src/main.ts:12-25`.
9. **Webhook handling** (`calls.service.ts:114-160`): missing `CallSid` ⇒ silent return; unknown `CallSid` ⇒ warn `Twilio webhook: unknown CallSid <sid>` and return (idempotent for Twilio retries). `CallStatus === 'in-progress'` ⇒ `status='in_progress'`, `startedAt = now`. `CallStatus ∈ {completed, failed, busy, no-answer, canceled}` ⇒ `status = (CallStatus === 'completed' ? 'completed' : 'failed')`, `endedAt = now`, `durationSeconds = parseInt(CallDuration, 10) || null`, `terminationReason = CallStatus`. Any other status (`queued`, `ringing`, …) leaves the row untouched but still re-saves it.

**Data model:** `call_sessions` (§2.7); reads `bookings`, `trips`, `users` (`phoneNumber`, `hidePhoneNumber`).

**State machine:**
```
initiated ──CallStatus='in-progress'──▶ in_progress ──CallStatus='completed'──▶ completed [terminal]
    │                                        │
    └────────CallStatus ∈ {failed,busy,no-answer,canceled}────────▶ failed  [terminal]
```
Transitions are driven **only** by the webhook; there is no timeout that closes an abandoned `initiated` session.

**External services:** Twilio — **only `twilio.validateRequest` (signature helper) is used**. No Twilio REST call, no TwiML, no Programmable Voice `calls.create`, no Twilio Proxy Service API. `TWILIO_ACCOUNT_SID`, `TWILIO_API_KEY_*`, `TWILIO_PHONE_NUMBER` and `TWILIO_VERIFY_SERVICE_SID` belong to the auth/OTP domain, not here.

**Background jobs:** none. No sweeper closes stale `initiated`/`in_progress` sessions, which means allocation rule 5c can permanently lock a proxy number.

**Errors:**

| Condition | HTTP | Body |
|---|---|---|
| booking missing | 404 | `Booking not found` |
| caller not a participant | 403 | `You are not a participant in this booking` |
| booking not in `pending\|confirmed\|in_progress` | 403 | `This booking is no longer active, so calls are closed for it` |
| user row missing | 404 | `User not found` |
| pool empty | 503 | `{code:'NO_PROXY_NUMBERS_AVAILABLE', message:'No proxy numbers are configured'}` |
| pool exhausted | 503 | `{code:'NO_PROXY_NUMBERS_AVAILABLE', message:'All proxy numbers are currently in use — please try again shortly'}` |
| bad Twilio signature | 403 | `Invalid Twilio signature` |

**Notes for reimplementation — read this before trusting the feature:**
1. **The Twilio side is only half-built.** `initiate` allocates a number and returns it for the client to dial; the backend never places a call and never learns the resulting `CallSid`. **Nothing anywhere writes `call_sessions.twilioCallSid`** (grepped: the only reference is the webhook's `where` clause and the schema). Therefore the webhook's session lookup **always misses**, and no session ever leaves `initiated`. A rebuild must either (a) create the call via the Twilio REST API / Proxy Service and store the returned SID, or (b) resolve the session from `From`/`To`/proxy number in the webhook.
2. Because sessions never reach `completed`, `ProxyPoolService.allocate` treats every historical session as "active", so the pool is exhausted by design over time. Rule 5b (reuse per booking) masks this only for repeat calls on the same booking.
3. `ProxyPoolService` reads `process.env.TWILIO_PROXY_NUMBERS` directly in its constructor — the value is snapshotted at boot and is not reloadable, and it bypasses `ConfigService`/`.env` validation.
4. `Not(...)` combined in a single TypeORM `where` object ANDs the two negations (`status != 'completed' AND bookingId != :id`) — that is the intended semantics here, but the double `as unknown as` casts (`proxy-pool.service.ts:71-74`) signal the type-unsafe workaround.
5. `expiresAt` is advisory only; if you need a real session window, persist it and check it.
6. Both parties' real numbers are stored on the session row; treat `call_sessions` as PII and restrict admin access accordingly.

---

## 9. Communication fees — what is actually charged for chat and calls

**Short answer: nothing. Contact is free at the point of use.**

Evidence, in order of authority:

1. `ChatPostgresService` contains **no fee or settlement check** at any of its gates — creation, join, send and read all validate participation and booking status only (`chat-postgres.service.ts:39-321`). The spec file is explicit: `describe('ChatPostgresService — contact is never gated on payment')` with cases such as *"opens a passenger room on an unpaid confirmed booking"* (`chat-postgres.service.spec.ts:27-129`).
2. `CallsService.initiate` gates on participation + booking status only. Its spec asserts *"allows a call on a confirmed booking that was never paid for"* (`calls.service.spec.ts:60`). The code comment states plainly: *"The platform fee no longer gates contact"* (`calls.service.ts:24-32`).
3. The chat gateway still carries a `BOOKING_NOT_SETTLED` → close-code-4403 branch, but no service throws that code any more, so it is unreachable dead code (`chat-postgres.gateway.ts:73-86`).
4. `PaymentsService.hasUserPaidCommunicationFee()` is a **stub that always returns `false`** and has no callers (`payments.service.ts:546-551`). `createCommunicationFee` and `initiateCliqCommunicationFee` are likewise vestigial (`payments.service.ts:82-95`).
5. `PlatformPricingService.passengerSeatPricing()` hard-codes `passengerPlatformPercent: 0, platformAmount: 0, driverAmount: seatPrice, requiresOnlinePayment: false`, ignoring the `communication_fees` row entirely; the comment reads *"Passengers no longer pay any platform fee… the app is not in the rider's payment path at all"* (`platform-pricing.service.ts:44-62`).

**What the `communication_fees` table still drives** — the *driver's* per-trip platform fee, which is a trips/wallet-domain concern, not a chat/call charge (`platform-pricing.service.ts:68-89`):

```
driverUnlockPercent > 0  →  feeAmount = round2(trip.price × trip.totalSeats × driverUnlockPercent / 100)
driverUnlockPercent == 0 →  feeAmount = round2(communication_fees.feeAmount)   // legacy flat fee
currency = communication_fees.currency ?? trip.currency ?? 'JOD'
```
One active row per `countryCode` (`getActiveFeeRow(countryCode)` filters `isActive = true`); the country defaults to `'JO'` in `pricingPreviewForTrip`. `lifetimeFreeTripEnabled` allows a driver's first trip to be free (consumed by the driver-trip-fee domain).
The charge itself is applied by `DriverTripFeeService.chargeAtTripStart` (idempotent via a `trip-fee:<tripId>` audit row) and stamps `trips.communicationFeeStatus = 'paid'` (`driver-trip-fee.service.ts:372`). A second, competing implementation (`PaymentsService.chargeDriverWalletForTrip`) was deliberately deleted — see the tombstone comment at `payments.service.ts:339-346`.

Instant-ride trips are created with `communicationFeeStatus: 'not_paid'` (`instant-rides.service.ts:841`), so they enter the same driver-fee pipeline as scheduled trips.

**Bottom line for a rebuild:** model `communication_fees` as a *driver platform-fee* configuration table, keep the column names for compatibility, and do **not** re-introduce a payment gate on chat or calls unless the product decision changes. `passengerPlatformPercent` can be dropped.

---

## 10. Cross-cutting: notifications emitted by this domain

All are FCM data+notification pushes via `NotificationsService.sendPush(userId, {title, body, type, data})` (`notifications.service.ts:218-231`), except chat, which uses `NotificationsService.create(...)` (persists a `notifications` row **and** pushes).

| `type` | Recipient | Trigger |
|---|---|---|
| `instant_offer` | driver | An offer is made (`instant-dispatch.service.ts:224`) |
| `instant_offer_cancelled` | driver | Passenger cancels while an offer is outstanding |
| `instant_raise_fare_nudge` | passenger | First empty full-radius sweep per fare revision |
| `instant_no_drivers` | passenger | `finalizeSearch` — title varies by `ttl_expired` |
| `instant_matched` | passenger | Driver accepted at the passenger's fare |
| `instant_counter_offer` | passenger | Driver countered |
| `instant_counter_accepted` | driver | Passenger accepted the counter |
| `instant_counter_rejected` | driver | Passenger declined the counter |
| `chat_message` | every participant except the sender | Message sent (REST or WS) |

If Firebase is not configured, `sendPush` returns `{successCount:0, failureCount:0}` and the flow continues unchanged.

---

## 11. Security & guard summary for this domain

| Surface | Auth | Authorisation |
|---|---|---|
| `/instant-rides/availability*` | JWT | `@Roles('driver')` |
| `/instant-rides/offers/*` | JWT | `@Roles('driver')` + `offer.driverId === caller` |
| `/instant-rides/requests/*` | JWT | `request.passengerId === caller` |
| `/instant-rides/nearby-drivers`, `/quotes` | JWT | none (any role) |
| `/locations/*` | JWT | none; per-user 60/min quota |
| `/tracking/*` (HTTP) | JWT | **none** — any authenticated user can read any trip's trail |
| `/tracking` (WS) subscribe | JWT handshake | **none** |
| `/tracking` (WS) location update | JWT handshake | trip must belong to the emitting driver |
| `/chat/*` | JWT | participant / driver / booking-status checks |
| `/bookings/:id/calls/initiate` | JWT | booking participant + callable status |
| `/calls/twilio-webhook` | `@Public()` | Twilio HMAC signature |

Global `BanGuard` blocks banned accounts on every authenticated HTTP request; `RestrictedAccountInterceptor` blocks writes for restricted accounts (`app.module.ts:118-155`). **Neither runs on WebSocket messages** — a banned user with a valid access token can still use `/chat` and `/tracking` until the token expires.

---

## 12. Dead code and legacy paths (explicit list)

| Item | Location | Status |
|---|---|---|
| Mongoose chat stack — `ChatModule`, `ChatService`, `ChatGateway`, `ChatController`, `schemas/chat-room.schema.ts`, `schemas/message.schema.ts` | `src/modules/chat/chat.*.ts`, `schemas/` | **Dead.** `AppModule` imports `ChatPostgresModule` only (`app.module.ts:34, 92`). `ChatModule` is referenced nowhere. It duplicates the same `/chat` namespace and REST paths; if it were ever registered alongside the Postgres module, both gateways would bind `/chat` and both controllers `chat/*`. Delete it in a rebuild. |
| `InstantRequestStatus.NO_DRIVERS` (`'no_drivers'`) | `instant-ride-request.entity.ts:26` | Declared, read by `canRetry`/`assertRetryable`, **never written**. |
| `TrackingGateway.emitTripTrackingSnapshot` / `trip:tracking:snapshot` | `tracking.gateway.ts:92-97` | No callers anywhere. |
| `ChatPostgresService.addParticipant` | `chat-postgres.service.ts:224-248` | Not exposed by controller or gateway. |
| `CreateChatRoomDto` | `chat/dto/create-chat-room.dto.ts` | Unused. |
| `PlaceDetailQueryDto` | `locations/dto/place-detail.dto.ts:3-7` | Unused — the controller takes no query params on `place/:id`. |
| `LocationsService.locationBias()` | `locations.service.ts:586-594` | Only used to build the cache key (`locationBiasKey`); the returned `"lat,lng"` string is never sent to a provider. |
| `BOOKING_NOT_SETTLED` / WS code `4403` branch | `chat-postgres.gateway.ts:73-86` | Unreachable — no service throws that code any more. |
| `payments.hasUserPaidCommunicationFee`, `createCommunicationFee`, `initiateCliqCommunicationFee` | `payments.service.ts:82-95, 546-551` | Stubs; no callers in this domain. |
| `communication_fees.passengerPlatformPercent` | schema | Read once and multiplied by nothing — `passengerSeatPricing` hard-codes 0. |
| `PaymentsService.chargeDriverWalletForTrip` | `payments.service.ts:339-346` | Deleted; the tombstone comment documents why. |
| `TripStatus.ACTIVE` (`'active'`) | `shared.enums.ts:14` | `@deprecated`; still used as the filter in `getNearbyTrips` — an active bug. |
| `.env.example` `NOMINATIM_BASE_URL` / `NOMINATIM_USER_AGENT` | `.env.example` | Stale names; the code reads `PHOTON_BASE_URL` / `GEOCODER_USER_AGENT`. |
| `call_sessions.twilioCallSid` write path | — | Missing entirely; see F-10 note 1. |

---

## 13. Consolidated gotchas, race conditions and scaling notes

**Concurrency / correctness**
1. `dispatchNext` flips `searching → offered` without checking `affected` (`instant-dispatch.service.ts:209-212`). Two concurrent dispatch runs can both pass the `status === 'searching'` read and issue two offers for one request. Every *other* transition in the module is a checked conditional update — fix this one to match.
2. On a successful match, the accepting driver's `driver_availability.currentRequestId` is **never cleared** (`finalizeMatch` releases the Bull jobs but not the lock). The driver stays unmatchable until they toggle offline/online. Clear it on accept.
3. `DriverAvailabilityService.upsert` is read-modify-write, not `INSERT … ON CONFLICT`. Concurrent `setAvailability` and `heartbeat` can clobber each other.
4. `chat_rooms.participants` (jsonb) is rewritten wholesale on every membership reconciliation and every message (`lastMessage*`) — lost updates are possible under concurrency.
5. No unique index guards the group chat room (`passengerId IS NULL`); duplicates are possible on simultaneous first access.
6. `getActiveCounterOffer` hides an expired-but-still-`countered` offer at read time; the DB row is only corrected when the Bull job runs. Any consumer reading the table directly must apply the same wall-clock filter.

**Reliability**
7. Every Bull `add()` and `remove()` in this domain swallows its error (`.catch(warn)` / `try{}catch{}`). A Redis outage silently disables offer timeouts, request expiry and dispatch waves, stranding requests in `searching`/`offered` forever. Add a DB sweeper for `expiresAt < now() AND status IN ('searching','offered')`.
8. `sendPush` failures are always swallowed; the driver may simply never learn about an offer, which then times out after 12 s. The `GET offers/pending` poll is the compensating mechanism.
9. No sweeper closes stale `call_sessions` — combined with the missing `twilioCallSid`, the proxy pool leaks permanently.

**Scaling**
10. **No Socket.IO Redis adapter.** `src/main.ts` sets no custom WS adapter, so rooms are per-process. Horizontal scaling breaks `/tracking`, `/chat`, `/trips` and `/notifications` fan-out. Add `@socket.io/redis-adapter` (Redis is already a dependency).
11. Three separate in-process `Map`s hold state that should be shared: WS rate-limit buckets (`ws-rate-limit.guard.ts:12`), locations rate-limit + response cache (`locations.service.ts:74-81`), and the ETA in-flight set (`tracking.service.ts:13`). None are size-bounded or evicted; all leak slowly and all are per-replica.
12. `chat_rooms` listing uses `jsonb_array_elements` in an `EXISTS` — unindexable. Add a GIN index on `participants` or normalise to a `chat_room_participants` table.
13. `driver_locations` is append-only with no retention. Partition by month or add a purge job.
14. The nearby-**pins** query (F-02) omits `currentRequestId IS NULL`, so it cannot use the partial GIST index that the matcher relies on.

**Data-format traps**
15. GeoJSON coordinates are always `[longitude, latitude]`; the DTOs, the pins response and the tracking payloads are all `latitude`-first. Mixing these up is the single easiest bug to introduce.
16. All `numeric` columns (`fareEstimate`, `speedKph`, `heading`, …) come back from TypeORM as **strings**. Fares cross the API as 2-dp strings; `distanceKm` / `durationMinutes` in the offer-summary payload are strings too, while the same names in the quote response are numbers.
17. `chat_rooms.lastMessageTime` is declared `type:'timestamp'` on the entity but created as `TIMESTAMPTZ` by the migration — a `synchronize:true` run would try to "fix" it.

**Behavioural traps**
18. `/instant-rides/nearby-drivers` and `/quotes` are documented as anonymous but require a JWT.
19. `PATCH /requests/:id/fare` only works while `status='searching'` — never during the 12 s an offer is live.
20. The offer card's distance/duration are **haversine at 50 km/h**, while the quote's are Google-routed. The two will not agree.
21. Twilio webhook signature validation will fail behind a TLS-terminating proxy unless `app.set('trust proxy', …)` is added, because the signed URL is rebuilt from `req.protocol` + `Host`.
22. Guard order on WebSockets: `WsAuthGuard` runs per *message*, so `handleConnection` cannot rely on `client.data.userId`.
23. WS `sendMessage` bypasses `SendMessageDto` validation entirely (no `ValidationPipe` on gateways) — the 1–2000 character rule is REST-only.
