# Wisoway Rideshare Backend — Complete Rebuild Specification

> **Purpose of this document set.** This is a stack-independent, feature-by-feature
> specification of the existing NestJS backend (`rideshare-backend/`). It is written
> so that the whole platform can be **rebuilt from scratch in a different language
> or framework** (Go, Java/Spring, .NET, Python/FastAPI, Rails, Elixir…) without
> reading the original TypeScript source.
>
> Everything here is derived from the actual code on branch `009-platform-refinements`.
> Generated 2026-08-21.

---

## Document map

| # | File | Lines | Features | Domain / modules covered |
|---|------|-------|----------|--------------------------|
| 00 | `00-overview-and-index.md` (this file) | 724 | — | System map, endpoint inventory, defect register, rebuild roadmap |
| 01 | `01-identity-and-access.md` | 2,149 | 18 | auth, users, security, uploads |
| 02 | `02-trips-and-bookings.md` | 1,957 | 24 | trips, bookings, seats, recurrence, share-links, trip-time |
| 03 | `03-realtime-and-communication.md` | 1,281 | 10 | instant-rides, tracking, locations, chat, calls |
| 04 | `04-payments-wallet-and-fees.md` | 2,008 | 18 | payments, wallet, pending-charges, refunds, settlement, driver-trip-fee |
| 05 | `05-admin-trust-and-safety.md` | 2,826 | 31 | admin, complaints, support, ratings, vehicles, health |
| 06 | `06-platform-and-infrastructure.md` | 1,187 | 8 | config, common, notifications, jobs, database, deployment |
| | **Total** | **12,132** | **109** | |

> **Read §9b first.** The spec documents 36 verified defects in the current backend,
> including a **critical privilege-escalation hole that is live right now**. Several
> "features" below are scaffolding that never executes. Knowing which is which is the
> difference between rebuilding the product and rebuilding the bugs.

---

## 1. What the product is

**Wisoway** is a two-sided ride-sharing / carpooling platform for the Jordanian market
(default currency **JOD**, Arabic + English UI), with three client surfaces:

| Surface | Tech | Talks to |
|---|---|---|
| Mobile app (passenger + driver in one binary) | Flutter 3.9.2 / Dart 3.x | REST + Socket.IO |
| Admin dashboard | React 19 + Vite 7 + TypeScript 5.9 | REST + FCM web push |
| Backend | NestJS 11 / TypeScript 5.7 | PostgreSQL + PostGIS, Redis |

It supports **two distinct ride products** that share one user, wallet, and chat substrate:

1. **Scheduled trips (carpooling)** — a driver publishes a trip with a route, departure
   time, seat layout, and price per seat. Passengers search, pick specific seats, and
   request a booking; the driver accepts or rejects. Revenue model: the **driver pays a
   platform fee per trip**; the passenger pays the driver directly (cash) or via wallet.
2. **Instant rides (on-demand hailing)** — a passenger requests a ride now; nearby
   available drivers are dispatched in waves and return offers; the passenger accepts one.
   Fare negotiation is supported.

Cross-cutting: OTP-only phone authentication, wallet + pending-charge ledger, in-app
chat and voice calls (both gated and monetized), live GPS tracking, ratings, complaints,
emergency/SOS alerts, and a full admin back office.

---

## 2. Architecture at a glance

```
                    ┌───────────────────────────────────────────┐
   Flutter app ────►│  nginx (TLS, /api → :3000, WS upgrade)     │
   React dashboard ►│                                           │
                    └───────────────────┬───────────────────────┘
                                        │
                        ┌───────────────▼──────────────────┐
                        │  NestJS monolith (28 modules)    │
                        │  REST  /api/v1/*                 │
                        │  WS    /chat /tracking /trips    │
                        │        /notifications            │
                        └───┬───────────┬───────────┬──────┘
                            │           │           │
             ┌──────────────▼─┐   ┌─────▼──────┐  ┌─▼─────────────────┐
             │ PostgreSQL     │   │ Redis      │  │ External services │
             │ + PostGIS      │   │ BullMQ +   │  │ Twilio Verify/SMS │
             │ 34 tables      │   │ Bull v4    │  │ Twilio Voice      │
             │ 52 migrations  │   │            │  │ Firebase FCM      │
             └────────────────┘   └────────────┘  │ AWS S3            │
                                                  │ Google Maps       │
                                                  │ OSRM (fallback)   │
                                                  │ Photon (OSM)      │
                                                  │ Cliq A2A (bank)   │
                                                  └───────────────────┘
```

**Deployment shape:** single API process, one PostgreSQL with the PostGIS extension,
one Redis (**Bull queue broker only — there is no application cache layer**), nginx in
front. In-process cron via `@nestjs/schedule`, deferred work via **Bull v4** queues.

> ⚠️ **Scaling caveat for a rebuild:** the three `@Cron` jobs run *in-process*. With more
> than one API replica they will fire once per replica. A rebuild should move them behind
> a distributed lock or a dedicated scheduler process. See §7.

---

## 3. Global API conventions

| Concern | Behaviour |
|---|---|
| Base path | `/{API_PREFIX}` — default **`api/v1`** (`main.ts:48`) |
| Auth | Bearer JWT in the `Authorization` header. `JwtAuthGuard` is registered **globally**; opt out per-route with a `@Public()` decorator |
| Guard order (global) | `JwtAuthGuard` → `BanGuard` → `RolesGuard` → `ThrottlerGuard` (`app.module.ts:110-127`) |
| Interceptor order (global) | `TransformInterceptor` → `UploadUrlInterceptor` → `LoggingInterceptor` → `RestrictedAccountInterceptor` |
| Validation | Global `ValidationPipe` with `whitelist: true`, `forbidNonWhitelisted: true`, `transform: true`, `enableImplicitConversion: true` — **unknown body fields cause a 400** |
| Rate limit | Single global bucket: **200 requests / 60 s** per client (`ThrottlerModule.forRoot`) |
| Pagination | `?page` (int ≥1, default **1**), `?limit` (int 1–100, default **20**) |
| Errors | Uniform envelope with a stable machine-readable `code` — see the error catalog in doc 06 |
| Security headers | `helmet()` with defaults |
| CORS | Dev: all origins. Prod: `ALLOWED_ORIGINS` (comma-separated). `credentials: true` |
| Static files | `/uploads` → `./uploads` on disk; `/public` → `./public` (share page) |
| API docs | Swagger UI at **`/api/docs`** (note: *not* behind the API prefix) |
| Listen | `HOST` (default `0.0.0.0`) : `PORT` (default `3000`) |

### Response envelope
All successful responses pass through `TransformInterceptor`; all errors through
`HttpExceptionFilter`. The exact shapes are documented in doc 06 §4 — a rebuild **must**
reproduce them byte-for-byte, because the Flutter client and the React dashboard both
parse them.

### Upload URL normalisation
`UploadUrlInterceptor` rewrites stored `/uploads/...` URLs in every response to the host
the client actually connected to, unless `SERVER_BASE_URL` is set. This exists so images
keep resolving when the dev server moves between LAN IPs/ports. In a rebuild behind a
fixed domain or CDN, set `SERVER_BASE_URL` and drop the interceptor.

---

## 4. Complete endpoint inventory

All paths below are relative to **`/api/v1`**. Full contracts (request fields,
validation rules, response shapes, business rules, errors) live in the per-domain documents.

### 4.1 Authentication — `auth/auth.controller.ts` → doc 01

| Method | Path | Purpose |
|---|---|---|
| POST | `/auth/send-otp` | Send phone OTP |
| POST | `/auth/verify-otp` | Verify OTP → tokens (login or signup) |
| POST | `/auth/driver/verify-phone` | Driver-flow phone verification |
| POST | `/auth/driver/register` | Submit driver registration |
| PATCH | `/auth/driver/registration` | Amend a pending driver registration |
| POST | `/auth/refresh` | Exchange refresh token |
| POST | `/auth/logout` | Revoke current session |
| POST | `/auth/link-phone` | Attach a phone to an existing account |
| DELETE | `/auth/delete-account` | Self-service account deletion |
| GET | `/auth/devices` | List the caller's device sessions |
| DELETE | `/auth/devices/:deviceId` | Revoke another device |
| POST | `/auth/register` | **Legacy** email/password registration |
| POST | `/auth/login` | **Legacy** email/password login |
| POST | `/auth/forgot-password` | Start password reset |
| POST | `/auth/verify-reset-otp` | Verify reset OTP |
| POST | `/auth/reset-password` | Complete reset |
| POST | `/auth/change-password` | Change password while logged in |
| POST | `/auth/google` | Google OAuth sign-in |
| POST | `/auth/facebook` | Facebook OAuth sign-in |

### 4.2 Users, uploads, vehicles → docs 01 / 05

| Method | Path | Purpose |
|---|---|---|
| GET | `/users/me` | Current profile |
| PATCH | `/users/me` | Update profile |
| PATCH | `/users/me/role` | Switch passenger ↔ driver |
| PATCH | `/users/me/fcm-token` | Register push token (legacy path) |
| GET | `/users/:id` | Public profile |
| GET | `/users/:id/stats` | Public trip/rating stats |
| POST | `/uploads/registration` | Upload during signup (pre-auth) |
| POST | `/uploads` | Generic upload |
| POST | `/uploads/profile-image` | Avatar |
| POST | `/uploads/license` | Driver licence image |
| POST | `/uploads/vehicle-license` | Vehicle licence image |
| POST | `/uploads/car-image` | Car photo |
| POST | `/uploads/payment-proof` | Manual payment proof |
| DELETE | `/uploads/:key` | Delete an uploaded object |
| GET | `/vehicles/types` | Vehicle-type catalog |
| POST | `/vehicles` | Add a vehicle |
| GET | `/vehicles/my` | My vehicles |
| PATCH | `/vehicles/:id` | Update vehicle |
| DELETE | `/vehicles/:id` | Remove vehicle |

### 4.3 Trips — `trips/`, `recurrence/`, `share-links/` → doc 02

| Method | Path | Purpose |
|---|---|---|
| POST | `/trips` | Publish a trip |
| GET | `/trips` | Search / list trips |
| GET | `/trips/nearby` | PostGIS proximity search |
| GET | `/trips/preferred` | Personalised feed |
| GET | `/trips/my` | Driver's own trips |
| GET | `/trips/fee-quote` | Quote the driver platform fee before publishing |
| GET | `/trips/:id/pricing-preview` | Price breakdown |
| GET | `/trips/:id` | Trip detail |
| GET | `/trips/:id/seats` | Seat map + availability |
| PATCH | `/trips/:id/seats/lock` | Hold seats |
| PATCH | `/trips/:id` | Edit trip |
| PATCH | `/trips/:id/hide` | Hide from search |
| PATCH | `/trips/:id/show` | Unhide |
| POST | `/trips/:id/arrived` | Driver marks arrival |
| POST | `/trips/:id/complete` | Complete the trip |
| DELETE | `/trips/:id` | Cancel/delete trip |
| GET | `/trips/recurrence-rules` | List recurrence rules |
| PATCH | `/trips/recurrence-rules/:id` | Update a rule |
| DELETE | `/trips/recurrence-rules/:id` | Delete a rule |
| POST | `/trips/:id/share-link` | Create a public share link |
| GET | `/share/:token` | **Public** share landing (no auth) |

### 4.4 Bookings — `bookings/` → doc 02

| Method | Path | Purpose |
|---|---|---|
| POST | `/bookings` | **v1** create booking |
| GET | `/bookings/my` | My bookings |
| GET | `/bookings/trip/:tripId` | Bookings on a trip (driver) |
| GET | `/bookings/:id` | Booking detail |
| PATCH | `/bookings/:id/confirm` | Driver confirms |
| PATCH | `/bookings/:id/cancel` | Cancel |
| POST | `/v2/bookings` | **v2** seat-aware booking |
| POST | `/v2/bookings/auto-pick` | Auto seat assignment (gender-adjacency aware) |
| PATCH | `/v2/bookings/:id/accept` | Driver accepts |
| PATCH | `/v2/bookings/:id/reject` | Driver rejects |

> Two booking APIs coexist (`/bookings` and `/v2/bookings`). v2 is the seat-level flow.
> A rebuild should implement **v2 only** unless legacy clients must be supported — see doc 02.

### 4.5 Trip execution & safety — `trip-time/` → doc 02

| Method | Path | Purpose |
|---|---|---|
| POST | `/bookings/:id/passenger-confirm` | Passenger confirms presence |
| POST | `/bookings/:id/driver-confirm` | Driver confirms passenger presence |
| GET | `/trips/:id/presence-roster` | Roster of who has confirmed |
| POST | `/trips/:id/presence-confirm` | Bulk presence confirmation |
| GET | `/bookings/:id/presence-prompt` | Should the app prompt now? |
| POST | `/bookings/:id/presence-declare` | Declare presence/absence |
| POST | `/trips/:id/emergency` | **SOS / emergency alert** |

### 4.6 Instant rides — `instant-rides/` → doc 03

| Method | Path | Purpose |
|---|---|---|
| POST | `/instant-rides/availability` | Driver goes online/offline |
| POST | `/instant-rides/availability/heartbeat` | Keep-alive + position |
| GET | `/instant-rides/availability/me` | My availability state |
| GET | `/instant-rides/nearby-drivers` | Drivers near a point |
| POST | `/instant-rides/quotes` | Fare quote |
| POST | `/instant-rides/requests` | Create a ride request |
| GET | `/instant-rides/requests/:id` | Request detail |
| PATCH | `/instant-rides/requests/:id/fare` | Counter-offer the fare |
| POST | `/instant-rides/requests/:id/retry` | Re-dispatch |
| DELETE | `/instant-rides/requests/:id` | Cancel request |
| GET | `/instant-rides/offers/pending` | Driver's pending offers |
| POST | `/instant-rides/offers/:id/accept` | Driver accepts |
| POST | `/instant-rides/offers/:id/decline` | Driver declines |
| POST | `/instant-rides/offers/:id/respond` | Driver responds (counter) |
| POST | `/instant-rides/requests/:rid/offers/:oid/accept` | Passenger accepts an offer |
| POST | `/instant-rides/requests/:rid/offers/:oid/decline` | Passenger declines an offer |

### 4.7 Location services — `locations/` → doc 03

| Method | Path | Purpose |
|---|---|---|
| GET | `/locations/autocomplete` | Place suggestions (Photon/OSM) |
| GET | `/locations/place/:id` | Place detail |
| GET | `/locations/geocode` | Address → coords |
| GET | `/locations/reverse-geocode` | Coords → address |
| GET | `/locations/distance` | Distance matrix |
| GET | `/locations/route` | Route polyline (Google Maps, OSRM fallback) |

### 4.8 Tracking — `tracking/` → doc 03

| Method | Path | Purpose |
|---|---|---|
| GET | `/tracking/:tripId/latest` | Latest driver position |
| GET | `/tracking/:tripId/history` | Breadcrumb trail |
| GET | `/tracking/nearby/trips` | Trips near a point |

### 4.9 Chat & calls — `chat/`, `calls/` → doc 03

| Method | Path | Purpose |
|---|---|---|
| GET | `/chat/rooms` | My chat rooms |
| GET | `/chat/rooms/trip/:tripId/passenger/:passengerId` | 1:1 room for a trip |
| GET | `/chat/rooms/trip/:tripId/group` | Group room for a trip |
| GET | `/chat/rooms/:idOrTripId` | Room detail |
| GET | `/chat/rooms/:id/messages` | Message history |
| POST | `/chat/rooms/:id/messages` | Send message (REST fallback) |
| POST | `/bookings/:id/calls/initiate` | Start a masked voice call |
| POST | `/calls/twilio-webhook` | **Public** Twilio callback |

> `chat.controller.ts` / `chat.gateway.ts` (Mongo-era) and `chat-postgres.*` both exist.
> **`ChatPostgresModule` is the one registered in `app.module.ts`** — the other is dead code.

### 4.10 Money — `payments/`, `wallet/`, `pending-charges/`, `refunds/`, `settlement/` → doc 04

| Method | Path | Purpose |
|---|---|---|
| POST | `/payments` | Record a payment |
| POST | `/payments/communication-fee` | Pay the chat/call unlock fee |
| POST | `/payments/cliq/initiate` | Start a Cliq A2A bank transfer |
| GET | `/payments/my` | My payments |
| GET | `/payments/wallet/me` | Wallet balance (alias) |
| GET | `/payments/wallet/transactions` | Wallet ledger (alias) |
| POST | `/payments/wallet/topup` | Top up (alias) |
| GET | `/payments/:id` | Payment detail |
| GET | `/payments/:id/cliq-status` | Poll Cliq status |
| PATCH | `/payments/:id/approve` | **Admin** approve |
| PATCH | `/payments/:id/reject` | **Admin** reject |
| GET | `/wallet/me` | Wallet balance |
| GET | `/wallet/transactions` | Ledger |
| POST | `/wallet/topup` | Top up |
| POST | `/wallet/rider/pay-trip` | Pay a trip from wallet |
| POST | `/wallet/driver/payout-requests` | Request a payout |
| GET | `/me/pending-charges` | Charges I owe |
| POST | `/me/pending-charges/collect` | Settle them |
| POST | `/admin/pending-charges/:id/waive` | **Admin** waive |
| POST | `/refund-requests` | Request a refund |
| POST | `/admin/bookings/:id/admin-revert-settlement` | **Admin** revert a settlement |
| GET | `/admin/bookings/:id/settlement-audits` | **Admin** settlement audit trail |

### 4.11 Ratings, complaints, support → doc 05

| Method | Path | Purpose |
|---|---|---|
| POST | `/ratings` | Rate a counterpart |
| GET | `/ratings/user/:userId` | Ratings for a user |
| GET | `/ratings/trip/:tripId` | Ratings on a trip |
| GET | `/ratings/my` | My ratings |
| POST | `/complaints` | File a complaint |
| GET | `/me/complaints` | My complaints |
| GET | `/support/config` | Support contact config |

### 4.12 Notifications → doc 06

| Method | Path | Purpose |
|---|---|---|
| GET | `/notifications` | Inbox |
| GET | `/notifications/unread-count` | Badge count |
| PATCH | `/notifications/:id/read` | Mark read |
| PATCH | `/notifications/read-all` | Mark all read |
| DELETE | `/notifications/:id` | Delete |
| POST | `/notifications/devices` | Register FCM device token |
| DELETE | `/notifications/devices/:token` | Unregister |
| POST | `/notifications/web-token` | Register dashboard web-push token |
| DELETE | `/notifications/web-token` | Unregister web token |

### 4.13 Admin → doc 05

Spread across **9 controllers**: `admin.controller.ts`, `admin-dashboard.controller.ts`,
`admin-ban`, `admin-complaints`, `admin-fines`, `admin-flags`, `admin-no-show`,
`admin-recurrence`, `admin-refunds`.

> ⚠️ **`admin.controller.ts` is dead code — it is registered in no module.** It and
> `admin-dashboard.controller.ts` both declare `@Controller('admin')` with overlapping
> routes, but `AdminModule.controllers` lists only `AdminDashboardController`. Every route
> that exists *only* on `AdminController` therefore **404s** (see §9b #20). The table below
> marks which controller actually serves each route. **A rebuild should implement one
> consolidated admin surface** — see doc 05.

| Method | Path | Purpose |
|---|---|---|
| GET | `/admin/dashboard/stats` | KPI tiles |
| GET | `/admin/users` | User search |
| PATCH | `/admin/users/:id/role` | Change role |
| PATCH · POST | `/admin/users/:id/ban` | Ban |
| POST | `/admin/users/:id/unban` | Unban |
| PATCH | `/admin/users/:id/confirm` | Confirm account |
| PATCH | `/admin/users/:id/approve-driver` | Approve driver |
| DELETE | `/admin/users/:id` | Delete user |
| GET | `/admin/trips` | Trip oversight |
| GET · PATCH | `/admin/bookings`, `/admin/bookings/:id/cancel` | Booking oversight |
| GET | `/admin/payments`, `/admin/payments/pending` | Payment oversight |
| GET | `/admin/wallets`, `/admin/wallets/:id`, `/admin/wallets/:id/transactions` | Wallet oversight |
| PATCH | `/admin/wallets/:id/adjust` | Manual balance adjustment |
| GET · PATCH | `/admin/vehicles`, `/admin/vehicles/:id/verify` | Vehicle verification |
| GET · DELETE | `/admin/ratings`, `/admin/ratings/:id` | Ratings moderation |
| GET · POST | `/admin/notifications`, `/admin/notifications/broadcast` | Broadcast |
| GET · PATCH | `/admin/alert-preferences` | Admin alert subscriptions |
| GET | `/admin/chat/rooms`, `/admin/chat/rooms/:id/messages` | Chat oversight |
| GET | `/admin/reports` | Reports/exports |
| GET · PATCH | `/admin/pricing-settings` | Pricing configuration |
| GET · PATCH | `/admin/complaints`, `/admin/complaints/:id` | Complaint handling |
| GET · PATCH | `/admin/refund-requests`, `/admin/refund-requests/:id` | Refund approval |
| GET · POST · PATCH | `/admin/fines`, `/admin/fines/:id/waive` | Fines |
| GET · PATCH | `/admin/account-flags`, `…/resolve`, `…/dismiss` | Risk flags |
| DELETE | `/admin/devices/:deviceId/revoke` | Force device logout |
| GET | `/admin/no-show-reports`, `/admin/no-show-reports/:tripId` | No-show reports |
| POST | `/admin/recurrence-rules/:id/spawn-now` | Force-spawn recurring trips |

### 4.14 Health

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness |
| GET | `/health/db` | DB connectivity |

---

## 5. WebSocket surface

Four Socket.IO namespaces. Auth handshake details are in the per-domain docs.

| Namespace | Rooms | Client → Server | Server → Client |
|---|---|---|---|
| `/chat` | `room:{chatRoomId}` | `joinRoom`, `leaveRoom`, `sendMessage`, `typing`, `stopTyping` | `newMessage`, `userTyping`, `userStopTyping`, `error` |
| `/tracking` | `trip:{tripId}` | `trip:tracking:subscribe`, `trip:tracking:unsubscribe`, `driver:location:update` | `trip:tracking:update`, `trip:tracking:snapshot` |
| `/trips` | `trip:{tripId}` | `subscribeTripUpdates`, `unsubscribeTripUpdates` | `tripUpdated`, `seatBooked`, `seatReleased` |
| `/notifications` | `user:{userId}` | `subscribe` | dynamic event name per notification type |

---

## 6. Data model — the 34 tables

| Table | Owning domain | Doc |
|---|---|---|
| `users` | identity | 01 |
| `pending_registrations` | identity | 01 |
| `otp_codes` | identity | 01 |
| `password_reset_sessions` | identity | 01 |
| `user_devices` | identity | 01 |
| `device_tokens` | identity / notifications | 01 · 06 |
| `security_events` | identity | 01 |
| `account_flags` | identity / admin | 01 · 05 |
| `trips` | trips (**PostGIS**) | 02 |
| `bookings` | bookings | 02 |
| `booking_seats` | bookings | 02 |
| `trip_recurrence_rules` | recurrence | 02 |
| `trip_share_links` | share-links | 02 |
| `driver_availability` | instant rides | 03 |
| `driver_locations` | tracking (**PostGIS**) | 03 |
| `instant_ride_requests` | instant rides | 03 |
| `instant_ride_offers` | instant rides | 03 |
| `chat_rooms` | chat | 03 |
| `messages` | chat | 03 |
| `call_sessions` | calls | 03 |
| `communication_fees` | calls / chat / money | 03 · 04 |
| `payments` | money | 04 |
| `wallet_accounts` | money | 04 |
| `wallet_transactions` | money | 04 |
| `wallet_holds` | money | 04 |
| `pending_charges` | money | 04 |
| `refund_requests` | money | 04 |
| `payout_requests` | money | 04 |
| `settlement_audits` | money | 04 |
| `vehicles` | ops | 05 |
| `ratings` | ops | 05 |
| `complaints` | ops | 05 |
| `admin_alert_preference` | ops | 05 |
| `notifications` | platform | 06 |

**52 migrations** ship the schema. The full chronological list with each migration's effect
is in doc 06 §3. For a greenfield rebuild you do **not** replay them — build the final
schema directly from the per-entity tables in docs 01–06, and read the migrations only
where a doc flags a non-obvious historical decision.

### 6.1 Shared enums (`database/entities/shared.enums.ts`)

```
PgUserRole              passenger | driver | admin
TripStatus              active(DEPRECATED) | draft | published | fully_booked
                        | in_progress | hidden | completed | cancelled
TripType                scheduled | instant
BookingStatus           pending | confirmed | cancelled | rejected
                        | in_progress | completed | no_show
WalletAccountType       driver | rider | system
WalletTransactionType   topup | trip_debit | trip_payment | refund
                        | payout | adjustment | hold | release_hold
WalletEntryDirection    debit | credit
WalletTransactionStatus pending | posted | failed | reversed
PayoutStatus            pending | approved | rejected | paid
PendingChargeKind       passenger_cancellation | driver_no_show
                        | passenger_no_show | driver_trip_fee
PendingChargeStatus     pending | applied | waived
NotificationChannel     in_app | push
AdminAlertType          driver_registration | fee_payment | trip_emergency
AccountFlagSeverity     low | medium | high | critical
AccountFlagDisposition  open | resolved | dismissed
UserDeviceStatus        active | revoked
UserDevicePlatform      android | ios
RecurrenceFrequency     daily | weekly
Gender                  male | female
AuthProvider            email | google | facebook | phone
```

> `TripStatus.ACTIVE` is **deprecated** — migration `008.06` converted every `active`
> row to `published`. Do not implement it in a rebuild.
>
> `BookingStatus` is a `const` object in TypeScript but a real **PG enum**
> (`booking_status_enum`) in the database (migration `008.04`).

---

## 7. Background work

### 7.1 In-process cron (`@nestjs/schedule`)

Three classes carry `@Cron`. **Only one of them actually runs.**

| Job | Cron | Registered? | What it does | Doc |
|---|---|---|---|---|
| `DriverTripFeeReconciliationJob` | `*/30 * * * *` (every 30 min) | ✅ provided in `driver-trip-fee.module.ts:35` | Charge the driver trip fee for trips the auto-start job never billed | 04 |
| `NotificationCleanupJob` | `0 2 * * *` (02:00 daily) | ❌ **not a provider in any module** | Would purge old notifications — **dead code, never executes** | 06 |
| `TripExpirationJob` | `*/15 * * * *` (every 15 min) | ❌ **not a provider in any module** | Would expire stale trips — **dead code, never executes** | 02 |

> **Two compounding historical bugs — carry both lessons into a rebuild:**
> 1. `ScheduleModule.forRoot()` was missing from `app.module.ts` for a long time, so *every*
>    `@Cron` was inert. It is registered now (`app.module.ts:72`).
> 2. Even with the scheduler live, `NotificationCleanupJob` and `TripExpirationJob` are
>    never listed as providers, so Nest never instantiates them and their `@Cron`
>    decorators are never bound. **Notification retention and trip expiry are therefore
>    unimplemented in production today** — a rebuild must actually wire them.
>
> Add a startup assertion that enumerates registered cron handlers and fails fast if an
> expected job is missing.

### 7.2 Queues — **Bull v4 via `@nestjs/bull`** (not BullMQ)

`package.json` pins `@nestjs/bull ^11.0.4` + `bull ^4.16.5`. Redis connection is configured
inline in `jobs.module.ts` from `REDIS_HOST` / `REDIS_PORT`. **13 queues** are registered.

Ten are declared in `jobs/jobs.module.ts`:

| Queue | Producer | Consumer | Purpose |
|---|---|---|---|
| `bookings-timeout` | `bookings.service` | `bookings-timeout.processor` | Auto-expire un-actioned booking requests |
| `no-show-detector` | bookings | `no-show-detector.processor` | Detect and record no-shows |
| `trip-auto-start` | trips, trip-time, recurrence-spawn | `trip-auto-start.processor` | Move a trip to `in_progress` at departure; **charges the driver trip fee** |
| `trip-auto-complete` | trips, trip-time, trip-auto-start | `trip-auto-complete.processor` | Auto-complete a trip |
| `pre-trip-confirm` | jobs module | `pre-trip-confirm.processor` | Pre-departure presence prompts |
| `recurrence-spawn` | admin-recurrence, jobs | `recurrence-spawn.processor` | Materialise the next trip from a recurrence rule |
| `new-trip-fanout` | notifications | `new-trip-fanout.processor` | Notify matching passengers of a new trip |
| `trip-expiration` | — | **no processor** | Queue declared, nothing consumes it |
| `notification-cleanup` | — | **no processor** | Queue declared, nothing consumes it |
| `pending-charge-collect` | — | **no processor** | Queue declared, nothing consumes it |

Three more are registered by their own modules:

| Queue | Producer | Consumer | Purpose |
|---|---|---|---|
| `instant-offer-timeout` | instant-rides, instant-dispatch | `instant-offer-timeout.processor` | Expire an unanswered driver offer |
| `instant-request-expiry` | instant-rides, instant-dispatch | `instant-request-expiry.processor` | Expire a whole ride request |
| `cliq-poll` | payments | `cliq-poll.processor` | Poll the bank for A2A transfer status |

Exact delays, retry policies, backoff, and idempotency keys are in the per-domain docs.

---

## 8. External services & credentials to provision

Before a rebuilt system can run, these accounts must exist. Per-service integration
detail (endpoints, auth scheme, failure behaviour, dev fallbacks) is in doc 06 §8.

| Service | Used for | Credentials needed | Dev fallback? |
|---|---|---|---|
| **Twilio Verify** | Phone OTP | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`, `TWILIO_API_KEY_SID`, `TWILIO_API_KEY_SECRET` | ✅ `OTP_PROVIDER=local` logs the code instead of sending SMS |
| **Twilio Programmable SMS** | OTP fallback | `TWILIO_PHONE_NUMBER` | ✅ same |
| **Twilio Voice** | Masked in-app calls | same account SID/token + webhook URL + **`TWILIO_PROXY_NUMBERS`** (comma-separated pool; **absent from `.env.example`** — an empty pool makes every call attempt return 503) | see doc 03 |
| **Firebase Cloud Messaging** | Mobile push + dashboard web push | `FIREBASE_SERVICE_ACCOUNT_PATH` (JSON key file) or `FIREBASE_PROJECT_ID` + `FIREBASE_PRIVATE_KEY` + `FIREBASE_CLIENT_EMAIL`; `FIREBASE_WEB_MESSAGING_SENDER_ID` for web | degrades silently |
| ~~**AWS S3**~~ | ~~File storage~~ | `AWS_*` vars are configured but **no S3 SDK is imported anywhere in `src/`** — uploads go to **local disk `./uploads`** only, served statically. Treat S3 as *not implemented*. | n/a |
| **Google Maps** | Routing / distance | `GOOGLE_MAPS_API_KEY` | ✅ falls back to **OSRM** if unset |
| **Photon (OSM geocoder)** | Place autocomplete & geocoding | none — free. **`PHOTON_BASE_URL`**, **`GEOCODER_USER_AGENT`**, `LOCATION_AUTOCOMPLETE_COUNTRIES` (ISO codes) | n/a |
| **Cliq A2A** | In-app bank transfers (Jordan) | see `src/config/a2a-cliq.config.ts`, doc 04 | see doc 04 |
| **Google OAuth** | Social login | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | — |
| **Facebook Login** | Social login | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | — |

> ⚠️ **`.env.example` has drifted from the code.** Verified mismatches:
> - `.env.example` documents `NOMINATIM_BASE_URL` / `NOMINATIM_USER_AGENT`, but
>   `locations.service.ts:89,94` reads **`PHOTON_BASE_URL`** / **`GEOCODER_USER_AGENT`**.
>   The geocoder is **Photon**, not Nominatim. Setting the documented names has no effect.
> - `TWILIO_PROXY_NUMBERS` is read by `proxy-pool.service.ts:35` but is **not in
>   `.env.example`**. Empty pool ⇒ in-app calling always 503s.
>
> Treat the per-domain docs' env tables (derived from code) as authoritative over `.env.example`.

> **`MONGODB_URI` is still in `.env.example` but MongoDB is no longer the store.**
> The system was migrated to PostgreSQL (`POSTGRES_CUTOVER_RUNBOOK.md`). Residual Mongoose
> schemas survive under `modules/users/schemas/`. **Do not port MongoDB into a rebuild** —
> confirm against doc 06 §2.

---

## 9. Known duplication and dead code (read before rebuilding)

A rebuild is the right moment to drop these. Each is confirmed in the per-domain docs.

| # | Item | Recommendation |
|---|---|---|
| 1 | `chat.controller.ts` + `chat.gateway.ts` (Mongo-era) vs `chat-postgres.*` | Only `ChatPostgresModule` is registered. Implement the Postgres flavour only. |
| 2 | `admin.controller.ts` + `admin.service.ts` (Mongoose-based) — **registered in no module**, ~1,580 lines of dead code shadowing `admin-dashboard.controller.ts` | Delete. Build one consolidated admin surface, and re-implement the 7 routes that currently 404 (§9b #20). |
| 3 | `bookings.controller.ts` (v1) vs `bookings-v2.controller.ts` | v2 is the seat-aware flow. Build v2 only. |
| 4 | Wallet endpoints exposed twice: `/wallet/*` and `/payments/wallet/*` | Pick one namespace. |
| 5 | Email/password auth (`/auth/register`, `/auth/login`, bcrypt) alongside OTP-only auth | Product direction is OTP-only; keep passwords for admin login only. Verify in doc 01. |
| 6 | `modules/users/schemas/*.ts` — leftover Mongoose schemas | Drop. |
| 7 | `TripStatus.ACTIVE` | Deprecated by migration 008.06. Drop. |
| 8 | `MONGODB_URI` in config | Drop. |
| 9 | Duplicate driver-fee charging path | Already deleted on this branch (commit `2adf6b6`). Implement one path only. |

---

## 9b. Verified defects in the current backend

These were found while writing this spec and each is confirmed against the code. They are
**bugs in the existing system, not requirements** — a rebuild should implement the
*intended* behaviour, not reproduce these.

### 🔴 Critical — privilege escalation (fix in the current system, not just the rebuild)

**Any authenticated passenger or driver can make themselves an admin.**

```
PATCH /api/v1/users/me/role
Authorization: Bearer <any valid user token>
{ "role": "admin" }
```

The chain, all verified:
- `users.controller.ts:53` guards *who may call* with `@Roles(PASSENGER, DRIVER)` — but never
  validates the **target** role in the body.
- `update-profile.dto.ts:6` validates it with `@IsEnum(UserRole)`, and `UserRole`
  (imported from the otherwise-dead Mongoose schema) **includes `ADMIN = 'admin'`**.
- `users.service.ts:83-87` `updateRole()` assigns `user.role = role` with no check at all.

Every `@Roles('admin')` route in the platform is reachable by any registered user. This
needs a patch to the running system independently of any rebuild — the fix is to reject
any target role outside `{passenger, driver}` in `updateRole`.

### All verified defects

| # | Defect | Evidence | Impact |
|---|---|---|---|
| 0 | **Privilege escalation via `PATCH /users/me/role`** (above). | verified | Full admin takeover from any account. **Critical.** |
| 1 | **`JWT_ACCESS_SECRET` vs `JWT_SECRET` mismatch.** `auth.service.ts:704` and `ws-auth.guard.ts:29` read `JWT_ACCESS_SECRET`; `jwt.config.ts:21` and `.env.example` define `JWT_SECRET`. | verified | The access-token secret resolves to `undefined` — signing/verification falls back to a default or fails. **Security-critical.** |
| 2 | **`HttpExceptionFilter` drops string error codes.** It writes the numeric HTTP status into `error.code` and discards `ACCOUNT_BANNED`, `SEATS_TAKEN`, etc. | doc 06 §4 | The whole 28-entry `ErrorCodes` catalog never reaches clients. Mobile can't localise or branch on errors. |
| 3 | **Notification retention and trip expiry never run.** `NotificationCleanupJob` and `TripExpirationJob` are not providers in any module. | verified | `notifications` grows unbounded; stale trips are never expired. |
| 4 | **Communication fees charge nothing.** Chat and calls are free despite the fee scaffolding. | doc 03, 5 code sites | Lost revenue vs. the intended model. |
| 5 | **`call_sessions.twilioCallSid` is never written.** The Twilio webhook can never match a session. | doc 03 | Proxy numbers leak permanently; no call is ever actually placed. |
| 6 | **`getNearbyTrips` filters `status='active'`**, deprecated by migration 008.06. | doc 03 | Nearby-trips search always returns empty. |
| 7 | **S3 configured but never implemented.** No SDK import in `src/`. | verified | All uploads sit on the API container's local disk — lost on redeploy unless volume-mounted. |
| 8 | **No Socket.IO Redis adapter.** | doc 03 | WebSocket fan-out breaks with more than one replica. |
| 9 | **Nothing runs migrations at deploy.** `synchronize:false`, no `migrationsRun`. | doc 06 §3 | Schema must be migrated by hand. |
| 10 | **`axios` and `uuid` imported but absent from `package.json`.** | doc 06 | Builds rely on transitive hoisting; a clean install can break. |
| 11 | **`.env.example` drift** — `NOMINATIM_*` vs `PHOTON_BASE_URL`/`GEOCODER_USER_AGENT`; `TWILIO_PROXY_NUMBERS` undocumented; `MONGODB_URI` obsolete. | verified | Following the documented config yields a non-working geocoder and permanently 503-ing calls. |
| 12 | **Three queues declared with no processor**: `trip-expiration`, `notification-cleanup`, `pending-charge-collect`. | verified | Jobs enqueued there would accumulate forever. |
| 13 | **Queues with a processor but no scheduler to enqueue them**: `recurrence-spawn`, `no-show-detector`, `pre-trip-confirm`. | doc 02 | Recurring trips never spawn (except via the manual admin endpoint); no-shows are never auto-detected; presence prompts never fire. |
| 14 | **Passenger cancellation window (12 h) is computed but never enforced.** The driver-side 24 h window *is* enforced. | doc 02 F-14 | Passengers can cancel penalty-free at any time. |
| 15 | **Non-geo trip search returns the page size as `total`.** | doc 02 | Client pagination is wrong on the main search. |
| 16 | **`TripsService.cancel` notifies a booking set it has already emptied.** | doc 02 | Passengers are never told their trip was cancelled. |
| 17 | **Share-link endpoints return 404/403/410 bodies inside an HTTP 200.** | doc 02 | Clients can't detect failure by status code. |
| 18 | **`createMultiSeat` never emits `seatBooked`** on the `/trips` WS namespace. | doc 02 | Other passengers' seat maps go stale in real time. |
| 19 | **`draft` and `fully_booked` trip statuses are never written** by any code path. | doc 02 | Two of the eight `TripStatus` values are unreachable. |
| 20 | **`AdminController` (585 lines) + `AdminService` (998 lines, Mongoose-based) are registered in no module.** `AdminModule.controllers` lists only `AdminDashboardController`. | verified | **7 endpoints the React dashboard calls return 404**: `PATCH /admin/users/:id/role`, `PATCH /admin/users/:id/ban`, `DELETE /admin/ratings/:id`, `GET`+`PATCH /admin/alert-preferences`, `GET /admin/users/:id/devices`, `GET /admin/pending-charges`. |
| 21 | **`req.user.sub` does not exist.** `JwtStrategy.validate` returns a `UserEntity` (which has `id`); `ratings.controller.ts:46,87` reads `req.user.sub`. | verified — no `sub` field on `UserEntity` | Rating creation and "my ratings" pass `undefined` as the user id. **Live bug.** |
| 22 | **`users.restricted` is set but never cleared.** Only assignment in `src/` is `account-risk.service.ts:73` → `restricted: true`. | verified | An auto-restricted account is permanently write-locked with **no admin remedy**. |
| 23 | **`security_events` is write-only** — no read endpoint exists. Several admin actions (user deletion, driver approval, vehicle verification, pricing changes, chat reads) emit no audit record at all. | doc 05 | The primary audit table is unusable; key privileged actions are untraceable. |
| 24 | **Verified vehicles can be edited without resetting `isVerified`** (plate, model, document images). `PATCH /vehicles/:id` also lets `seats` drift out of sync with `seatLayout`. | doc 05 | Verification can be bypassed post-approval; seat maps can desync. |
| 25 | **`dashboardStats.activeTrips` counts `TripStatus.ACTIVE`**, dead since migration 008.06. | doc 05 | The KPI always reads 0. |
| 26 | **`POST /wallet/rider/pay-trip` is completely unvalidated.** Its body is an *inline TypeScript type*, not a DTO class (`wallet.controller.ts:57-62`) — the global `ValidationPipe` has no metatype to validate against, so it is skipped entirely. No `@Roles` guard either. | verified | `amount` accepts negatives, strings, anything. **Money-critical.** |
| 27 | **`POST /wallet/driver/payout-requests` has no role guard** (`wallet.controller.ts:66`). | verified | Any authenticated user — passenger included — can file a driver payout request. |
| 28 | **Pending-charge collection has no idempotency key** and can double-debit under concurrent requests. | doc 04 | Users can be charged twice for the same debt. |
| 29 | **Payout requests never debit or reserve funds.** | doc 04 | A driver can request payout of a balance they then spend. |
| 30 | **The configured CliQ `CallBackURL` has no implementing route.** | doc 04 | Bank callbacks 404; settlement relies entirely on the 24 h polling fallback. |
| 31 | **Documented cancellation/no-show penalties (5% / 10%) are not implemented.** `pending-charge.entity.ts` describes them; no code applies them. Passenger platform fee is hard-coded to `0`. | doc 04 | Three of the four `PendingChargeKind` values are never produced. |

| 32 | **Logout invalidates nothing.** A refresh-token hash is stored on the user but never compared on refresh. | doc 01 | Refresh tokens stay valid after logout for their full 7-day TTL. |
| 33 | **Local-mode OTP codes never expire.** No `expiresAt` filter on lookup and no cleanup job (`cleanupExpiredOtpCodes` is unreferenced). | doc 01 | Any previously-issued dev OTP stays valid forever. |
| 34 | **`DELETE /uploads/:key` performs no ownership check.** | doc 01 | Any authenticated user can delete any other user's uploaded file. |
| 35 | **Driver licences and insurance documents are served publicly** from `/uploads/**` with no auth. | doc 01 | Unauthenticated PII/document exposure if the URL is known or guessable. |

> **Only one fee is actually live in the whole platform:** the driver's shared-trip
> platform fee, `round2(seatPrice × totalSeats × driverUnlockPercent / 100)`, debited once
> at trip start. Its three-layer idempotency (`trips.driverWalletChargeApplied` →
> unique audit row `trip-fee:<tripId>` → 23505 convergence) is correct and worth copying
> verbatim. Everything else in the fee catalog is scaffolding.

### Load-bearing ordering (do not "clean up" in a rebuild)

Two sequences are correctness-critical and are backed by existing spec tests:

1. **The driver trip-fee sweep must run *before* booking statuses flip** in both completion
   paths. Reversing the order empties the billable set first, permanently zeroing the fee
   (this is what commit `5869196` fixed).
2. **Trip creation guard order:** local validation → geocode → wallet read. Reordering
   causes billable geocode calls on requests that should have failed validation.

---

## 10. Suggested rebuild order

Each phase is independently shippable and testable.

| Phase | Build | Depends on | Doc |
|---|---|---|---|
| **0** | Platform skeleton: config, DB + PostGIS, Redis, error envelope, validation, auth guard chain, health | — | 06 |
| **1** | Identity: OTP auth, JWT + refresh, devices, profiles, uploads | 0 | 01 |
| **2** | Catalog: vehicles, vehicle types, seat layouts | 1 | 05 |
| **3** | Notifications: FCM, in-app inbox, device tokens | 0, 1 | 06 |
| **4** | Money core: wallet ledger, holds, pending charges | 1 | 04 |
| **5** | Trips: publish, search (incl. PostGIS), seat map | 1, 2 | 02 |
| **6** | Bookings v2: request → accept, seat allocation, cancellation | 4, 5 | 02 |
| **7** | Trip execution: auto-start/complete queues, presence, driver trip fee, settlement | 4, 6 | 02, 04 |
| **8** | Real-time: tracking WS, trips WS, chat WS | 6 | 03 |
| **9** | Comms monetization: communication fees, masked calls | 4, 8 | 03, 04 |
| **10** | Instant rides: availability, dispatch waves, offers, fare negotiation | 4, 8 | 03 |
| **11** | Payments in/out: Cliq A2A, top-ups, payouts, refunds | 4 | 04 |
| **12** | Trust & safety: ratings, complaints, no-show detection, account flags, SOS | 6, 7 | 02, 05 |
| **13** | Admin back office + web push | all | 05 |
| **14** | Extras: recurrence, share links, preferred feed, reports | 5, 13 | 02, 05 |

---

## 11. How to read the per-domain documents

Each feature in docs 01–05 follows the same template:

- **What it does** — business meaning
- **Actors** — who may call it
- **API Endpoints** — method, full path, auth requirement
- **Request / Response contracts** — exact fields, types, validation rules
- **Business rules & validation** — numbered, exhaustive
- **Data model** — columns, types, indexes, FKs, enums
- **State machine** — allowed status transitions and their triggers
- **External services used** — which third party, which API, failure behaviour
- **Background jobs** — cron/queue and semantics
- **Errors** — code, message, HTTP status
- **Notes for reimplementation** — gotchas, races, ordering, transactions

Where a doc says *"verify: file:line"*, the claim was not fully resolvable from the code
alone and should be confirmed against the original source before relying on it.

---

## 12. Security items to fix in the *current* system

Independent of any rebuild, these are exploitable against the running backend today.
Ordered by severity.

| Sev | Item | Fix |
|---|---|---|
| 🔴 Critical | Privilege escalation via `PATCH /users/me/role` (§9b #0) | Reject any target role outside `{passenger, driver}` in `updateRole`. |
| 🔴 Critical | `JWT_ACCESS_SECRET` unset — code reads it, config defines `JWT_SECRET` (§9b #1) | Align the names; fail fast at boot if the secret is missing or default. |
| 🟠 High | `POST /wallet/rider/pay-trip` unvalidated + unguarded (§9b #26) | Replace the inline body type with a DTO class; add `@Roles`. |
| 🟠 High | `POST /wallet/driver/payout-requests` unguarded (§9b #27) | Add `@Roles('driver')`. |
| 🟠 High | Driver licences/insurance served publicly from `/uploads/**` (§9b #35) | Move documents behind an authenticated, ownership-checked route. |
| 🟠 High | `DELETE /uploads/:key` has no ownership check (§9b #34) | Verify the caller owns the object. |
| 🟡 Medium | Logout does not invalidate refresh tokens (§9b #32) | Compare the stored hash on refresh; clear it on logout. |
| 🟡 Medium | `users.restricted` can never be cleared (§9b #22) | Add an admin unrestrict path and emit the audit event. |
| 🟡 Medium | Pending-charge collection can double-debit (§9b #28) | Add an idempotency key. |
| 🟡 Medium | Verified vehicles editable without re-verification (§9b #24) | Reset `isVerified` on any document/plate change. |
| 🟢 Low | Local-mode OTPs never expire (§9b #33) | Filter on `expiresAt`; wire a cleanup job. |
