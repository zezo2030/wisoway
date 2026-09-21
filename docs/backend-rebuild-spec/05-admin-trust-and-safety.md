# 05 — Admin, Trust & Safety, Operations

Rebuild-grade specification for the admin/back-office, trust-and-safety and ops surface of the
Wisoway rideshare backend (`d:\work\wisoway\rideshare-backend`, NestJS 11 + TypeORM + PostgreSQL).

Every statement below is grounded in source. Where a claim could not be fully verified, the file and
line are cited with `verify:`.

---

## 1. Domain overview

This domain covers everything an operator (admin) does after users, trips and money exist:

| Area | Modules |
|---|---|
| Admin dashboard API (metrics, users, trips, bookings, payments, wallets, ratings, notifications, chat, reports, pricing) | `src/modules/admin/admin-dashboard.controller.ts` + `admin-dashboard.service.ts` |
| Ban / unban with cascade | `src/modules/admin/admin-ban.*` |
| Account risk flags + device revoke | `src/modules/admin/admin-flags.*` |
| Complaint queue | `src/modules/admin/admin-complaints.controller.ts` + `src/modules/complaints/*` |
| Refund-request queue | `src/modules/admin/admin-refunds.controller.ts` + `src/modules/refunds/*` |
| Driver fines (manual penalties) | `src/modules/admin/admin-fines.*` |
| Driver no-show reports | `src/modules/admin/admin-no-show.*` |
| Admin alerting (web push to admins) | `src/modules/admin/admin-alerts.service.ts` |
| Recurrence ops trigger | `src/modules/admin/admin-recurrence.controller.ts` |
| Ratings | `src/modules/ratings/*` |
| Vehicles + vehicle-type catalog | `src/modules/vehicles/*` |
| Support config | `src/modules/support/*` |
| Health probes | `src/modules/health/*` |
| Structured audit log emitter | `src/common/audit/*` |

**Global API prefix.** `src/main.ts:49` → `app.setGlobalPrefix(process.env.API_PREFIX || 'api/v1')`.
Every path in this document is therefore served at `/{API_PREFIX}/…`, default `/api/v1/…`.
All endpoint tables below list the **full** path including the default prefix.

**Response envelope.** `TransformInterceptor` (`src/common/interceptors/transform.interceptor.ts`,
registered globally in `src/app.module.ts`) wraps every successful handler return value as:

```json
{ "success": true, "data": <handler return value> }
```

Handlers that already return `{ success: true, data: {...} }` (e.g. `DELETE /admin/users/:id`)
are therefore **double-wrapped** into `{success:true,data:{success:true,data:{...}}}`. This is a
real, observable quirk — reproduce it or fix it deliberately.

**Error envelope.** `HttpExceptionFilter` (`src/common/filters/http-exception.filter.ts`, `@Catch()`
— catches everything):

```json
{
  "success": false,
  "error": {
    "code": <HTTP status number, NOT a string code>,
    "message": "<exception.message>",
    "details": <array or string or null>,
    "timestamp": "<ISO>",
    "path": "/api/v1/...",
    "method": "PATCH",
    "debug": "<only when 500 and NODE_ENV!=production>",
    "stack": "<only when 500 and NODE_ENV!=production>"
  }
}
```

Note `error.code` is the numeric HTTP status. The string `ErrorCodes.*` constants
(`src/common/errors/error-codes.ts`) are emitted inside the thrown *object payload* by some guards
(e.g. `ACCOUNT_BANNED`), and land in `error.details` because the filter falls back to `response.message`
— i.e. an object payload without a `message` key yields `details: null`. `verify: src/common/filters/http-exception.filter.ts:66-80`.

**Global validation.** `src/main.ts:36-44` — `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true,
transform: true, transformOptions: { enableImplicitConversion: true } })`. Unknown body/query fields
are rejected with 400. A second `ValidationPipe` is also registered as `APP_PIPE`
(`src/common/pipes/validation.pipe.ts`) — both apply.

**Middleware / security.** `helmet()`, CORS (`origin: ALLOWED_ORIGINS.split(',')` in production, `true`
otherwise, `credentials: true`), static `/uploads` and `/public`, Swagger at `/api/docs`
(not prefixed), throttler at 200 req / 60 s globally.

---

## 2. Admin role & permission matrix

### 2.1 Role model

There is exactly **one** privileged role. There are no sub-roles, no permission table, no scopes.

`PgUserRole` (`src/database/entities/shared.enums.ts:1-5`) — the DB enum on `users.role`:

| Value | Meaning |
|---|---|
| `passenger` | End user booking seats |
| `driver` | End user publishing trips |
| `admin` | Back-office operator — full access to every admin endpoint |

A parallel legacy enum `UserRole` (`src/modules/users/schemas/user.schema.ts:6-10`) has identical
string values (`passenger`/`driver`/`admin`) and is used by the dead Mongoose code path and by
`AdminFlagsController`. Because the values are identical strings, mixing them is harmless.

### 2.2 Guard pipeline

Registered globally in `src/app.module.ts` (order matters — this is the execution order):

1. **`JwtAuthGuard`** (`src/common/guards/jwt-auth.guard.ts`) — Passport `jwt` strategy. Skipped when the
   handler or controller carries `@Public()` (`IS_PUBLIC_KEY`). Throws `401 Invalid or expired token`.
2. **`BanGuard`** (`src/common/guards/ban.guard.ts`) — if `req.user.bannedAt != null`, throws
   `403` with payload `{ code: 'ACCOUNT_BANNED', banReason, supportWhatsApp }`. Public routes and
   unauthenticated requests pass through.
3. **`RolesGuard`** (`src/common/guards/roles.guard.ts`) — reads `ROLES_KEY` metadata via
   `getAllAndOverride([handler, class])`. No metadata ⇒ allow. Missing `user.role` ⇒
   `403 User role not found`. Role mismatch ⇒ `403 Access denied. Required roles: admin`.
4. **`ThrottlerGuard`** — 200 requests / 60 000 ms.

Then interceptors, in order: `TransformInterceptor` → `UploadUrlInterceptor` → `LoggingInterceptor` →
`RestrictedAccountInterceptor` (blocks POST/PUT/PATCH/DELETE for `user.restricted === true` with
`423 Locked` + `{ code: 'ACCOUNT_RESTRICTED' }`; GET/HEAD/OPTIONS pass).

**JWT strategy** (`src/modules/auth/strategies/jwt.strategy.ts`): bearer token, secret from
`JWT_ACCESS_SECRET`, payload `{ sub, email, role, did }`. `validate()` reloads the full `UserEntity`
from the DB, rejects if not found, rejects if `isActive === false`, rejects if `did` is present and
the device session is no longer active, and rejects tokens issued before `user.passwordChangedAt`.
So `req.user` is the **full user entity**, which is why `BanGuard` can read `bannedAt` and
`RestrictedAccountInterceptor` can read `restricted`.

Reimplementation gotcha: the guard chain means **suspending an admin** (`isActive=false`) instantly
invalidates their tokens, and **banning** an admin locks them out at guard #2.

### 2.3 Capability matrix

Legend: `admin` = requires `@Roles('admin')`; `auth` = any authenticated user; `public` = `@Public()`.

| Capability | Endpoint(s) | Access |
|---|---|---|
| Log in as admin | `POST /api/v1/auth/login` (email + password branch) | public |
| Refresh session | `POST /api/v1/auth/refresh` | public |
| Read own profile | `GET /api/v1/users/me` | auth |
| Dashboard KPIs | `GET /api/v1/admin/dashboard/stats` | admin |
| List/search users | `GET /api/v1/admin/users` | admin |
| Confirm user account | `PATCH /api/v1/admin/users/:id/confirm` | admin |
| Approve/reject driver | `PATCH /api/v1/admin/users/:id/approve-driver` | admin |
| Delete user | `DELETE /api/v1/admin/users/:id` | admin |
| Ban user (cascade) | `POST /api/v1/admin/users/:id/ban` | admin |
| Unban user | `POST /api/v1/admin/users/:id/unban` | admin |
| List account flags | `GET /api/v1/admin/account-flags` | admin |
| Resolve flag | `PATCH /api/v1/admin/account-flags/:flagId/resolve` | admin |
| Dismiss flag | `PATCH /api/v1/admin/account-flags/:flagId/dismiss` | admin |
| Revoke a device session | `DELETE /api/v1/admin/devices/:deviceId/revoke` | admin |
| List vehicles | `GET /api/v1/admin/vehicles` | admin |
| Verify/reject vehicle | `PATCH /api/v1/admin/vehicles/:id/verify` | admin |
| List trips | `GET /api/v1/admin/trips` | admin |
| List bookings | `GET /api/v1/admin/bookings` | admin |
| Cancel booking | `PATCH /api/v1/admin/bookings/:id/cancel` | admin |
| Revert settlement | `POST /api/v1/admin/bookings/:id/admin-revert-settlement` | admin |
| Read settlement audit trail | `GET /api/v1/admin/bookings/:id/settlement-audits` | admin |
| List payments / pending payments | `GET /api/v1/admin/payments`, `GET /api/v1/admin/payments/pending` | admin |
| Approve/reject a payment | `PATCH /api/v1/payments/:id/approve`, `.../reject` | (payments module — outside this doc) |
| List wallets, view one, transactions | `GET /api/v1/admin/wallets`, `/:id`, `/:id/transactions` | admin |
| Manual wallet adjustment | `PATCH /api/v1/admin/wallets/:id/adjust` | admin |
| List ratings | `GET /api/v1/admin/ratings` | admin |
| List notifications | `GET /api/v1/admin/notifications` | admin |
| Broadcast notification | `POST /api/v1/admin/notifications/broadcast` | admin |
| Monitor chat rooms / messages | `GET /api/v1/admin/chat/rooms`, `/:id/messages` | admin |
| Generate report | `GET /api/v1/admin/reports` | admin |
| Read/update pricing | `GET`/`PATCH /api/v1/admin/pricing-settings` | admin |
| Complaint queue | `GET /api/v1/admin/complaints`, `PATCH /api/v1/admin/complaints/:id` | admin |
| Refund queue | `GET /api/v1/admin/refund-requests`, `PATCH /api/v1/admin/refund-requests/:id` | admin |
| Driver fines | `GET`/`POST /api/v1/admin/fines`, `PATCH /api/v1/admin/fines/:id/waive` | admin |
| Waive a pending charge | `POST /api/v1/admin/pending-charges/:id/waive` | admin |
| No-show reports | `GET /api/v1/admin/no-show-reports`, `/:tripId` | admin |
| Force recurrence spawn | `POST /api/v1/admin/recurrence-rules/:id/spawn-now` | admin |
| Register dashboard web-push token | `POST`/`DELETE /api/v1/notifications/web-token` | auth |
| Support WhatsApp config | `GET /api/v1/support/config` | public |
| Health | `GET /api/v1/health`, `GET /api/v1/health/db` | public |

### 2.4 Endpoints the dashboard calls that DO NOT EXIST on the live server

The React dashboard (`d:\work\wisoway\rideshare-dashboard\src\api\admin.ts`) calls these; the only
declarations for them are inside the **unregistered** `AdminController` (see F-31). They return **404**:

| Dashboard call | Only declared in |
|---|---|
| `PATCH /admin/users/:id/role` | `admin.controller.ts:110` (dead) |
| `PATCH /admin/users/:id/ban` (body `{isActive}`) | `admin.controller.ts:131` (dead) |
| `DELETE /admin/ratings/:id` | `admin.controller.ts:449` (dead) |
| `GET /admin/alert-preferences` | `admin.controller.ts:497` (dead) |
| `PATCH /admin/alert-preferences` | `admin.controller.ts:504` (dead) |
| `GET /admin/users/:id/devices` | nowhere — no controller declares it |
| `GET /admin/pending-charges` (list) | nowhere — only the `POST .../waive` exists |

When rebuilding, decide explicitly whether to implement these or drop the dashboard pages.

---

## 3. Environment variables read by this domain

| Variable | Default | Read at | Purpose |
|---|---|---|---|
| `API_PREFIX` | `api/v1` | `src/main.ts:49` | Global route prefix |
| `PORT` | `3000` | `src/main.ts:74` | Listen port |
| `HOST` | `0.0.0.0` | `src/main.ts:75` | Bind address |
| `NODE_ENV` | — | `src/main.ts:30`, `http-exception.filter.ts:33` | CORS mode, stack traces in 500s |
| `ALLOWED_ORIGINS` | `https://yourdomain.com` | `src/main.ts:31` | Comma-separated CORS allow-list (production only) |
| `JWT_ACCESS_SECRET` | — (throws if unset) | `jwt.strategy.ts:15`, `auth.service.ts:822` | **Access** token signing/verification. **Not present in `.env.example`** — gotcha |
| `JWT_REFRESH_SECRET` | `your-refresh-secret-change-in-production` | `auth.service.ts:823`, `jwt.config.ts` | Refresh token signing |
| `JWT_SECRET`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN` | see `jwt.config.ts` | `src/config/jwt.config.ts` | Loaded/validated into `jwt.*` config namespace but the auth service hardcodes `15m` / `7d` and uses `JWT_ACCESS_SECRET` instead — effectively inert |
| `SUPPORT_WHATSAPP_E164` | `+962788883007` | `support.controller.ts:34`, `ban.guard.ts:49`, `refunds.service.ts:28` | Support number surfaced to apps, ban screen, refund deep links |
| `MULTI_ACCOUNT_DEVICE_THRESHOLD` | `3` | `account-risk.service.ts:42` | Distinct accounts per device fingerprint in 24 h before auto-restrict + flag |
| `ADMIN_EMAIL` | `admin@rideshare.com` | `admin.seed.ts:15` | **Dead** seed (Mongoose) |
| `ADMIN_PASSWORD` | `Admin@123456` | `admin.seed.ts:16` | **Dead** seed |
| `ADMIN_NAME` | `System Admin` | `admin.seed.ts:17` | **Dead** seed |
| `ADMIN_PHONE` | `+201000000000` | `admin.seed.ts:18` | **Dead** seed |
| `FIREBASE_SERVICE_ACCOUNT_PATH` / `FIREBASE_PROJECT_ID` / `FIREBASE_PRIVATE_KEY` / `FIREBASE_CLIENT_EMAIL` | see `.env.example` | notifications module | FCM Admin SDK — used for admin web push |
| `FIREBASE_WEB_MESSAGING_SENDER_ID` | — | `.env.example` | Dashboard web push sender id |
| `POSTGRES_*`, `REDIS_*` | see `.env.example` | database/redis config | Health `db` probe, BullMQ queue for `recurrence-spawn` |

Dashboard-side (for reference only, not backend): `VITE_API_BASE_URL`, `VITE_WS_URL`,
`VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_MESSAGING_SENDER_ID`,
`VITE_FIREBASE_APP_ID`, `VITE_FIREBASE_VAPID_KEY`.

---

## 4. Full entity column definitions

### 4.1 `complaints` (`ComplaintEntity`)

Source: `src/database/entities/complaint.entity.ts`, migration
`src/database/migrations/1745910000000-008.10-admin-and-support__create-complaints-and-refunds.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK `pk_complaints` |
| `reporterId` | uuid | no | — | FK → `users(id)` ON DELETE **CASCADE** |
| `againstUserId` | uuid | yes | `NULL` | FK → `users(id)` ON DELETE **SET NULL** |
| `tripId` | uuid | yes | `NULL` | FK → `trips(id)` ON DELETE SET NULL |
| `bookingId` | uuid | yes | `NULL` | FK → `bookings(id)` ON DELETE SET NULL |
| `category` | varchar(32) | no | — | `safety` \| `rude_behavior` \| `no_show` \| `payment` \| `vehicle_condition` \| `other` (app-enforced, **not** a DB enum) |
| `body` | text | no | — | Free text, max 2000 chars enforced in DTO |
| `status` | varchar(16) | no | `'open'` | `open` \| `in_review` \| `resolved` \| `rejected` |
| `adminNotes` | text | yes | `NULL` | Max 2000 chars in DTO |
| `resolvedByAdminId` | uuid | yes | `NULL` | No FK constraint |
| `resolvedAt` | timestamptz | yes | `NULL` | |
| `createdAt` | timestamptz | no | `now()` | |
| `updatedAt` | timestamptz | no | `now()` | |

Indexes: `idx_complaints_status_created (status, createdAt)`, `idx_complaints_against_user (againstUserId)`,
`idx_complaints_reporter (reporterId)`.

### 4.2 `refund_requests` (`RefundRequestEntity`)

Source: `src/database/entities/refund-request.entity.ts`, same migration.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `userId` | uuid | no | — | FK → `users(id)` CASCADE |
| `bookingId` | uuid | yes | `NULL` | FK → `bookings(id)` SET NULL |
| `amount` | numeric(10,2) | yes | `NULL` | Stored as string in the entity |
| `currency` | varchar(5) | no | `'JOD'` | DTO restricts to `JOD`\|`USD`\|`EUR` |
| `reason` | text | no | — | Max 1000 chars in DTO |
| `status` | varchar(16) | no | `'open'` | `open` \| `contacted` \| `resolved` \| `rejected` |
| `whatsappContactedAt` | timestamptz | yes | `NULL` | Set to `now()` at creation |
| `resolvedByAdminId` | uuid | yes | `NULL` | |
| `resolvedAt` | timestamptz | yes | `NULL` | |
| `adminNotes` | text | yes | `NULL` | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Index: `idx_refund_requests_status_created (status, createdAt)`.

### 4.3 `ratings` (`RatingEntity`)

Source: `src/database/entities/rating.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | generated | PK |
| `fromUserId` | uuid | no | — | FK → `users(id)`, no explicit onDelete (TypeORM default `NO ACTION`) |
| `toUserId` | uuid | no | — | FK → `users(id)` |
| `tripId` | uuid | no | — | FK → `trips(id)` |
| `rating` | int | no | — | 1–5 enforced only in DTO, **no DB check constraint** |
| `comment` | text | yes | — | Max 500 chars in DTO |
| `userRole` | varchar | yes | — | Role of the rater at rating time |
| `ratedRole` | varchar | yes | — | Derived: `userRole === 'driver' ? 'passenger' : 'driver'` |
| `createdAt` / `updatedAt` | timestamp | no | auto | |

Index: `idx_ratings_from_user_trip (fromUserId, tripId)` **UNIQUE** — one rating per rater per trip.
Consequence: on a trip a driver can rate only *one* passenger (see F-17 notes).

### 4.4 `vehicles` (`VehicleEntity`)

Source: `src/database/entities/vehicle.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | generated | PK |
| `driverId` | uuid | no | — | FK → `users(id)` ON DELETE CASCADE |
| `vehicleType` | varchar | no | — | Free string; the catalog values are `sedan`/`suv`/`van`/`truck`/`bus`/`motorcycle` |
| `plateNumber` | varchar(20) | no | — | |
| `model` | varchar(100) | no | — | |
| `seats` | int | no | — | Derived from layout when omitted |
| `seatLayout` | jsonb | yes | `NULL` | `{rows, seatsPerRow, seatsPerRowList?, preventGenderMixing?}` |
| `licenseImageUrl` | text | yes | `NULL` | Driver's licence |
| `vehicleLicenseImageUrl` | text | yes | `NULL` | Vehicle registration |
| `carImageUrl` | text | yes | `NULL` | Required by DTO on create |
| `insuranceImageUrl` | text | yes | `NULL` | Required by driver-registration DTO, optional here |
| `isVerified` | boolean | no | `false` | Admin-controlled |
| `createdAt` / `updatedAt` | timestamp | no | auto | |

Index: `idx_vehicles_driver_id (driverId)` **UNIQUE** — one vehicle per driver.

### 4.5 `admin_alert_preference` (`AdminAlertPreferenceEntity`)

Source: `src/database/entities/admin-alert-preference.entity.ts`, migration
`1746201000000-create-admin-alert-preferences.ts`, enum extended in
`1746700000000-add-trip-live-eta-and-emergency-alert.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `userId` | uuid | no | — | FK → `users(id)` CASCADE |
| `alertType` | enum `admin_alert_preference_alerttype_enum` | no | — | `driver_registration`, `fee_payment`, `trip_emergency` |
| `enabled` | boolean | no | `true` | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Constraints: `admin_alert_preference_user_type_unique UNIQUE(userId, alertType)`,
index `admin_alert_preference_user_idx(userId)`.
The base migration created the enum with only `driver_registration` and `fee_payment`;
`trip_emergency` was appended later via `ALTER TYPE … ADD VALUE` guarded by a `pg_enum` existence check.

### 4.6 `account_flags` (`AccountFlagEntity`)

Source: `src/database/entities/account-flag.entity.ts`, migration
`1745800000000-008.01-auth-hardening__devices-flags-events.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `userId` | uuid | no | — | FK → `users(id)` CASCADE |
| `reason` | varchar(64) | no | — | Machine code: `multi_account_device`, `mock_location_repeated`, `manual_review` |
| `severity` | enum `account_flag_severity_enum` | no | `'medium'` | `low`, `medium`, `high`, `critical` |
| `disposition` | enum `account_flag_disposition_enum` | no | `'open'` | `open`, `resolved`, `dismissed` |
| `notes` | text | yes | `NULL` | System- or admin-authored |
| `resolvedByAdminId` | uuid | yes | `NULL` | No FK |
| `resolvedAt` | timestamptz | yes | `NULL` | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Indexes: `account_flags_user_idx(userId)`, `account_flags_disposition_idx(disposition)`,
`account_flags_created_idx(createdAt)`.

### 4.7 `security_events` (`SecurityEventEntity`)

Source: `src/database/entities/security-event.entity.ts`, same migration + `008.13-cleanup__audit-correlation-id`.
Append-only; nothing in the codebase updates or deletes a row.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `userId` | uuid | yes | `NULL` | FK → `users(id)` ON DELETE SET NULL |
| `eventType` | varchar(64) | no | — | See §9 for the full observed set |
| `deviceId` | uuid | yes | `NULL` | Plain UUID, **no FK** (audit log stays valid after device deletion) |
| `metadata` | jsonb | yes | `NULL` | Free-form |
| `adminActorId` | uuid | yes | `NULL` | Admin who caused the event |
| `correlationId` | varchar | yes | `NULL` | From `X-Request-ID` / trace id |
| `createdAt` | timestamptz | no | `now()` | No `updatedAt` — immutable |

Indexes: `security_events_user_idx(userId)`, `security_events_type_idx(eventType)`,
`security_events_created_idx(createdAt)`.

### 4.8 `pending_charges` (`PendingChargeEntity`) — admin fines reuse this table

Source: `src/database/entities/pending-charge.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | generated | PK |
| `userId` | uuid | no | — | FK → `users(id)` CASCADE |
| `kind` | enum | no | — | `passenger_cancellation`, `driver_no_show`, `passenger_no_show`, `driver_trip_fee` |
| `amount` | numeric(10,2) | no | — | Stored as string |
| `status` | enum | no | `'pending'` | `pending`, `applied`, `waived` |
| `bookingId` | uuid | yes | `NULL` | FK → `bookings(id)` SET NULL |
| `tripId` | uuid | yes | `NULL` | FK → `trips(id)` SET NULL |
| `walletTransactionId` | uuid | yes | `NULL` | Set on immediate collection |
| `appliedToBookingId` | uuid | yes | `NULL` | Set on later sweep collection |
| `waivedByAdminId` | uuid | yes | `NULL` | |
| `waivedAt` | timestamp | yes | `NULL` | |
| `reason` | text | yes | `NULL` | Admin justification for manual fines |
| `createdByAdminId` | uuid | yes | `NULL` | Non-null only for admin-issued fines |
| `correlationId` | varchar | yes | `NULL` | |
| `createdAt` / `updatedAt` | timestamp | no | auto | |

Indexes: `idx_pending_charges_user_status(userId,status)`, `idx_pending_charges_booking(bookingId)`,
plus a `driver_trip_fee` uniqueness index (migration `1747100000000`).

### 4.9 `settlement_audits` (`SettlementAuditEntity`)

Source: `src/database/entities/settlement-audit.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | generated | PK |
| `bookingId` | uuid | no | — | FK → `bookings(id)` CASCADE |
| `action` | varchar | no | — | `mark_paid`, `unmark_paid`, `admin_revert` |
| `actorId` | uuid | no | — | FK → `users(id)` CASCADE |
| `reason` | text | yes | `NULL` | Required in practice for `admin_revert` |
| `correlationId` | varchar | yes | `NULL` | |
| `createdAt` | timestamp | no | auto | Immutable |

Indexes: `idx_settlement_audits_booking(bookingId)`, `idx_settlement_audits_actor(actorId)`.

### 4.10 `communication_fees` (`CommunicationFeeEntity`) — the pricing-settings row

Source: `src/database/entities/communication-fee.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | generated | PK |
| `countryCode` | varchar(5) | no | — | UNIQUE index `idx_communication_fees_country` |
| `feeAmount` | numeric(10,2) | no | — | Legacy flat unlock fee |
| `currency` | varchar(5) | no | — | |
| `isActive` | boolean | no | `true` | |
| `passengerPlatformPercent` | numeric(5,2) | no | `0` | 0–100 |
| `driverUnlockPercent` | numeric(5,2) | no | `0` | 0–100 |
| `lifetimeFreeTripEnabled` | boolean | no | `true` | |
| `createdAt` / `updatedAt` | timestamp | no | auto | |

### 4.11 `device_tokens` (`DeviceTokenEntity`) — carries dashboard web-push tokens

Source: `src/database/entities/device-token.entity.ts`, migration `1746200000000-add-web-platform-to-device-tokens.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | generated | PK |
| `userId` | uuid | no | — | FK → `users(id)` CASCADE |
| `token` | varchar(512) | no | — | UNIQUE index `device_tokens_unique_token_idx` |
| `platform` | varchar(20) | no | `'android'` | `android` \| `ios` \| `web`. **Not a DB enum** — `'web'` needed no enum migration; the migration only added `userAgent` |
| `userAgent` | varchar(255) | yes | `NULL` | Browser UA, for web-token hygiene |
| `isActive` | boolean | no | `true` | Soft-delete on deregister |
| `lastSeenAt` | timestamptz | yes | `NULL` | |
| `createdAt` / `updatedAt` | timestamp | no | auto | |

### 4.12 `users` columns this domain writes

Source: `src/database/entities/user.entity.ts`.

| Column | Type | Default | Written by |
|---|---|---|---|
| `role` | enum `PgUserRole` | `passenger` | (only by the dead `AdminService.changeUserRole`) |
| `isActive` | boolean | `true` | `confirmUser` sets `true` |
| `isPhoneVerified` | boolean | `false` | `confirmUser` sets `true` |
| `isEmailVerified` | boolean | `false` | `confirmUser` sets `true` |
| `isDriverApproved` | boolean | `false` | `approveDriver` |
| `bannedAt` | timestamptz | `NULL` | `banUser` / `unbanUser` |
| `banReason` | text | `NULL` | `banUser` / `unbanUser` |
| `restricted` | boolean | `false` | `AccountRiskService` sets `true`. **Nothing clears it** — see F-08 note |
| `rating` | numeric(3,2) | `0` | `RatingsService.updateUserAverage` |
| `totalRatings` | int | `0` | `RatingsService.updateUserAverage` |
| `passwordHash` | varchar, `select:false` | `NULL` | Admin login reads it via explicit `addSelect` |

---

## 5. Features

---

## F-01: Admin authentication

**What it does:** Admins sign in to the back-office with an email address and a bcrypt-hashed
password through the same `/auth/login` endpoint end users use with a phone number. A short-lived
access token and a refresh token are issued; the dashboard rejects non-admin logins client-side.

**Actors:** `PgUserRole.ADMIN` (`'admin'`). Any user row whose `role = 'admin'` and which has a
`passwordHash`. There is no separate admin table and no MFA.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/login` | public | Password login (email ⇒ admin branch; phoneNumber ⇒ end-user branch) |
| POST | `/api/v1/auth/refresh` | public | Exchange refresh token for a new pair |
| POST | `/api/v1/auth/logout` | auth | Clear stored refresh token |
| GET | `/api/v1/users/me` | auth | Session restore; dashboard checks `role === 'admin'` |

**Request / Response contracts:**

`SignInDto` (`src/modules/auth/dto/sign-in.dto.ts`):

| Field | Type | Rules |
|---|---|---|
| `phoneNumber` | string | Validated **only if** provided or `email` is absent. Trimmed. `@Matches(/^\+[1-9]\d{1,14}$/)` — E.164 |
| `email` | string | Validated **only if** provided or `phoneNumber` is absent. Trimmed + lowercased. `@IsEmail()` |
| `password` | string | `@IsString()`, `@MinLength(1)` — required |

Response (`AuthResponse`, after the global envelope → `data`):

```
{
  user: { id, email, phoneNumber, name, gender, role, photoUrl, rating, totalRatings, ... },
  accessToken: string,   // JWT, HS256, 15m
  refreshToken: string,  // JWT, HS256, 7d
  accountState: 'active' | 'restricted' | 'banned',
  deviceState: null,     // always null on the password path
  pendingPhoneLinkRequired: boolean
}
```

JWT payload: `{ sub: user.id, email, role, did: null }` (`auth.service.ts:815-820`).

**Business rules & validation:**

1. If `email` is present, the user lookup is `LOWER(email) = LOWER(:email) AND role = 'admin'`
   (`auth.service.ts:890-901`). A non-admin with that email is not found ⇒ generic 401.
2. If `email` is absent, the lookup is by phone number (end-user branch).
3. Missing user, missing `passwordHash`, or bcrypt mismatch ⇒ `401 Invalid admin email or password`
   (email branch) / `401 Invalid phone number or password` (phone branch). Identical message for
   "no such user" and "wrong password" — no user enumeration.
4. `isPhoneVerified` is enforced **only** on the phone branch. Admins do not need a verified phone.
5. Ban/restriction are **not** checked at login; the token is issued regardless and the request is
   blocked later by `BanGuard` / `RestrictedAccountInterceptor`. `accountState` reports the state.
6. Refresh tokens are hashed and stored on the user row (`usersService.updateRefreshToken`).
7. Token invalidation levers: `isActive=false` (rejected in `JwtStrategy.validate`), `passwordChangedAt`
   newer than token `iat`, device session revoked when `did` is present (never on the admin path).

**Data model:** reads `users.passwordHash` (declared `select: false`, pulled in via explicit
`addSelect('user.passwordHash')`), `users.role`, `users.email`; writes `users.refreshToken`.

**State machine:** none.

**Side effects:** refresh-token hash persisted.

**External services used:** none (bcrypt is in-process).

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| Unknown email / wrong password (admin branch) | 401 | `Invalid admin email or password` |
| Unknown phone / wrong password | 401 | `Invalid phone number or password` |
| Unverified phone (phone branch only) | 401 | `Phone number must be verified before signing in.` |
| Neither email nor phone supplied | 400 | class-validator message array |
| Expired/invalid bearer on protected routes | 401 | `Invalid or expired token` |

**Notes for reimplementation:**
- The access-token secret env var is `JWT_ACCESS_SECRET`, **not** the `JWT_SECRET` in `.env.example`.
  Startup throws if `JWT_ACCESS_SECRET` is missing.
- TTLs are hardcoded (`15m` / `7d`) in `generateTokens`; `JWT_EXPIRES_IN` / `JWT_REFRESH_EXPIRES_IN`
  are loaded into config but unused on this path.
- `JwtStrategy.validate` hits the DB on **every** request. In a rebuild, either keep that (it makes
  ban/suspend instant) or add a cache with explicit invalidation.
- The dashboard does the "is this an admin?" check client-side only; the server's protection is the
  `RolesGuard` on each endpoint.
- Admin account creation has no live path: the only seeder (`admin.seed.ts`) is Mongoose-based dead
  code. In practice admins are inserted by hand. A rebuild needs a real bootstrap path.

---

## F-02: Dashboard statistics

**What it does:** Returns the nine headline counters shown on the dashboard home page.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/dashboard/stats` | admin | Aggregate platform KPIs |

**Request / Response contracts:** no parameters.

Response `data` (`DashboardStats`, `dto/admin-query.dto.ts:130-140`):

| Field | Type | Computation |
|---|---|---|
| `totalUsers` | number | `COUNT(users)` |
| `totalDrivers` | number | `COUNT(users WHERE role='driver')` |
| `totalPassengers` | number | `COUNT(users WHERE role='passenger')` |
| `activeTrips` | number | `COUNT(trips WHERE status='active')` |
| `completedTrips` | number | `COUNT(trips WHERE status='completed')` |
| `totalRevenue` | number | `SUM(wallet_transactions.amount)` where `type='trip_payment' AND status='posted'` |
| `pendingPayments` | number | `COUNT(payments WHERE status='pending')` |
| `pendingManualTopups` | number | `COUNT(payments WHERE status='pending' AND method='manual' AND paymentType='wallet_topup')` |
| `pendingVehicleVerifications` | number | `COUNT(vehicles WHERE isVerified=false)` |

**Business rules & validation:**

1. All nine counters are computed concurrently (`Promise.all`).
2. `totalRevenue`, `pendingPayments`, `pendingManualTopups` and `pendingVehicleVerifications` each
   swallow errors and return `0` (`try { … } catch { return 0 }`).
3. `activeTrips` counts `TripStatus.ACTIVE = 'active'`, which migration `008.06` converted to
   `'published'`. **This counter therefore reads 0 on any migrated database.** Confirmed dead value:
   `shared.enums.ts:8-15` marks `ACTIVE` `@deprecated` and says all rows were converted.
   `verify: src/modules/admin/admin-dashboard.service.ts:191`.

**Data model:** reads `users`, `trips`, `wallet_transactions`, `payments`, `vehicles`.

**State machine:** n/a. **Side effects:** none. **External services:** none. **Background jobs:** none.

**Errors:** none surfaced — failures degrade to `0`.

**Notes for reimplementation:** Nine independent aggregate queries per page load, no caching. At scale
replace with a materialised view or a periodically refreshed counters table. Fix the `active`/`published`
mismatch.

---

## F-03: User management — search & listing

**What it does:** Paginated, filterable directory of every account, with a projection that
deliberately excludes secrets.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/users` | admin | Paginated user list with filters |

**Request / Response contracts:**

Query `AdminUsersQueryDto extends PaginationDto` (`dto/admin-users-query.dto.ts`, `common/dto/pagination.dto.ts`):

| Param | Type | Rules | Default |
|---|---|---|---|
| `page` | int | `@IsInt() @Min(1)`, `@Type(()=>Number)` | `1` |
| `limit` | int | `@IsInt() @Min(1) @Max(100)` | `20` |
| `role` | enum | `@IsEnum(PgUserRole)` → `passenger`\|`driver`\|`admin` | — |
| `search` | string | free text | — |
| `isActive` | boolean | `'true'`/`'false'` strings transformed to boolean, then `@IsBoolean()` | — |
| `registeredWithinDays` | int | `@IsInt() @Min(1) @Max(365)` | — |
| `isConfirmed` | boolean | same string transform | — |

Response: `PaginatedResult<UserEntity-projection>`:

```
{ data: [ { id, email, phoneNumber, name, role, isActive, rating, totalRatings,
            isPhoneVerified, isEmailVerified, isDriverApproved, provider,
            walletBalance, walletCurrency, createdAt, updatedAt } ],
  meta: { page, limit, total, totalPages } }
```

**Business rules & validation:**

1. `page` is clamped server-side: `Math.max(1, page ?? 1)`.
2. `limit` is clamped: `Math.min(100, Math.max(1, limit ?? 20))` — belt-and-braces on top of the DTO.
3. `skip = (page - 1) * limit`.
4. Sort is fixed: `createdAt DESC`.
5. `search` matches `name ILIKE %term% OR email ILIKE %term% OR phoneNumber ILIKE %term%`, on the
   trimmed term. Empty/whitespace search is ignored.
6. `registeredWithinDays` adds `createdAt >= now() - days*86 400 000 ms`; ignored when `<= 0` or null.
7. `isConfirmed=true` ⇒ `isPhoneVerified = true AND isEmailVerified = true`;
   `isConfirmed=false` ⇒ `isPhoneVerified = false OR isEmailVerified = false`.
8. The explicit `select([...])` list omits `passwordHash`, `refreshToken`, `fcmToken`, and also omits
   `bannedAt`, `banReason`, `restricted`, `photoUrl`, `city`, `gender`. The list view therefore
   **cannot show who is banned** — a real functional gap to close on rebuild.
9. Unlike most other list methods here, `getUsers` has **no** `try/catch` fallback; a DB error
   propagates as a 500.

**Data model:** reads `users`. Uses index `users_role_idx`. `ILIKE` on three columns is unindexed —
add trigram indexes for a real deployment.

**State machine:** n/a. **Side effects:** none. **External services:** none. **Background jobs:** none.

**Errors:** 400 on DTO violations; 403 without the admin role.

**Notes for reimplementation:** The `search` term is interpolated as a bound parameter (`:term`) —
no injection risk — but `%` and `_` inside the user's search string are **not** escaped and act as
wildcards.

---

## F-04: User account confirmation & deletion

**What it does:** An admin can force-verify an account (activate it and mark phone + email verified),
and can hard-delete a non-admin account.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| PATCH | `/api/v1/admin/users/:id/confirm` | admin | Activate + mark phone/email verified |
| DELETE | `/api/v1/admin/users/:id` | admin | Hard-delete the account |

**Request / Response contracts:**

- `confirm`: no body. Returns the full saved `UserEntity` (note: this response is **not** projected,
  so it exposes every non-`select:false` column, including `bannedAt`, `banReason`, `restricted`).
- `delete`: no body. Returns `{ success: true, data: { message: 'User deleted' } }` — which the global
  interceptor wraps again into `{success:true,data:{success:true,data:{message:'User deleted'}}}`.

**Business rules & validation:**

1. `confirm`: 404 `User not found` if no such id.
2. `confirm` sets `isActive = true`, `isPhoneVerified = true`, `isEmailVerified = true` and saves.
3. `confirm` then creates an in-app notification (see side effects). Failure of the notification is
   **not** caught — it would fail the whole request. `verify: admin-dashboard.service.ts:229-235`.
4. `delete` validates the id against a strict UUID v1–v5 regex
   (`/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i`) and also rejects
   the literal strings `'undefined'` and `'null'` ⇒ `400 Invalid user ID`.
5. `delete` 404s if not found.
6. `delete` refuses when `user.role === 'admin'` ⇒ `400 Cannot delete admin users`.
7. `delete` uses `repo.remove(entity)` — a real `DELETE`, relying on the FK `ON DELETE CASCADE` /
   `SET NULL` rules of every child table (bookings, trips, complaints, flags, device tokens, wallets…).
   No soft delete, no anonymisation, no confirmation step.

**Data model:** writes `users.isActive`, `users.isPhoneVerified`, `users.isEmailVerified`; deletes
`users` rows.

**State machine:** none formal. Confirmation is idempotent.

**Side effects:**
- `confirm` → `notifications.create({ type: 'account_verified', title: 'Account Verified',
  body: 'Your account has been verified by the administrator.',
  data: { isPhoneVerified: true, isEmailVerified: true, isActive: true } })`.
- `delete` → cascading deletes across every child table; no audit row is written, no security event,
  no notification. **Deletion is invisible in the audit trail.**

**External services:** FCM indirectly, via the notifications service.

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| User not found (both) | 404 | `User not found` |
| Malformed id (delete) | 400 | `Invalid user ID` |
| Target is an admin (delete) | 400 | `Cannot delete admin users` |

**Notes for reimplementation:** Add an audit record for deletion. Consider soft-delete: a hard delete
destroys the counterparty's booking/trip history via cascade.

---

## F-05: Driver approval workflow

**What it does:** Gate that lets a driver publish trips. An admin flips `isDriverApproved` after
reviewing the profile and documents; the driver is notified in Arabic either way.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| PATCH | `/api/v1/admin/users/:id/approve-driver` | admin | Approve or reject a driver |

**Request / Response contracts:**

Body `ApproveDriverDto` (`dto/admin-query.dto.ts:113-116`):

| Field | Type | Rules |
|---|---|---|
| `approved` | boolean | `@IsBoolean()` — required |

Response (handler-shaped, then wrapped):
`{ message: 'Driver approval status updated', user: <full UserEntity> }`.

**Business rules & validation:**

1. 404 `User not found`.
2. `400 User is not a driver` when `user.role !== PgUserRole.DRIVER`. Approving a passenger is impossible.
3. **Approval requires a profile photo:** if `approved === true && !user.photoUrl` ⇒
   `400 Driver profile photo is required before approval`. (Related string code
   `ErrorCodes.PROFILE_PHOTO_REQUIRED` exists but is **not** used on this path — the message is plain text.)
4. Rejection (`approved=false`) has no photo precondition and can be applied repeatedly.
5. Vehicle verification is **not** a precondition — a driver can be approved with an unverified vehicle,
   and vice versa. Two independent gates.
6. `isDriverApproved` is set and the user saved; the notification is `await`ed, so a notification
   failure fails the request.

**Data model:** writes `users.isDriverApproved`; reads `users.photoUrl`, `users.role`.

**State machine:**

```
isDriverApproved: false ──approve(approved=true, photoUrl != null)──► true
                   ▲                                                   │
                   └────────────approve(approved=false)────────────────┘
```
Both transitions are freely repeatable; there is no "pending review" state persisted — pending is
simply `role='driver' AND isDriverApproved=false`.

**Side effects:** in-app + push notification to the driver:

| approved | type | title (ar) | body (ar) |
|---|---|---|---|
| `true` | `driver_approved` | `تم قبول حسابك كسائق` | `تهانينا! تم قبول حسابك كسائق. يمكنك الآن إنشاء الرحلات.` |
| `false` | `driver_rejected` | `تم رفض طلب حسابك كسائق` | `تم رفض طلب تسجيلك كسائق. يرجى التواصل مع الدعم لمزيد من المعلومات.` |

`data: { approved }`.

**External services:** Firebase Cloud Messaging (via `NotificationsService`).

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| Not found | 404 | `User not found` |
| Not a driver | 400 | `User is not a driver` |
| Approving without a photo | 400 | `Driver profile photo is required before approval` |

**Notes for reimplementation:**
- There is **no document-review workflow** in the backend. Driver documents live as URL columns on
  `vehicles` (`licenseImageUrl`, `vehicleLicenseImageUrl`, `carImageUrl`, `insuranceImageUrl`) and
  `users.photoUrl`. There is no per-document status, no rejection reason, no expiry, no
  re-submission tracking. Approval is a single boolean. If the rebuild needs real document review,
  it must be designed from scratch.
- No security-event or audit row is written for approve/reject. Only the notification proves it happened.

---

## F-06: Ban and unban with cascade

**What it does:** Banning an account immediately locks the user out of every authenticated endpoint,
cancels their live bookings, cancels the trips they were driving (notifying every affected passenger),
revokes all their device sessions, and appends a security event. Unban only clears the two ban fields.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/admin/users/:id/ban` | admin | Ban with full cascade |
| POST | `/api/v1/admin/users/:id/unban` | admin | Lift the ban |

Both `@HttpCode(200)`. `:id` runs through `ParseUUIDPipe` ⇒ malformed id gives 400 before the handler.

**Request / Response contracts:**

`BanUserDto` (declared inline in `admin-ban.controller.ts:23-28`):

| Field | Type | Rules |
|---|---|---|
| `reason` | string | `@IsString() @IsNotEmpty() @MaxLength(500)` — required |

Unban takes no body.

Response for both: `{ id, bannedAt, banReason }`.

**Business rules & validation:**

1. Ban: 404 `User not found`.
2. Ban: `400 User is already banned` when `bannedAt != null` — bans are not re-appliable, so a reason
   cannot be amended without unbanning first.
3. Ban step 1 — set `bannedAt = now`, `banReason = reason`, save.
4. Ban step 2 — cancel every booking **owned by** the user with status in
   `{pending, confirmed}`: `status='cancelled'`, `cancelledAt=now`, `cancelledBy='admin_ban'`,
   `cancellationReason='Account banned by admin'`. Seats are **not** released and passengers are
   **not** notified on this branch. `verify: admin-ban.service.ts:152-173`.
5. Ban step 3 — cancel every trip **authored by** the user with status in
   `{published, fully_booked}` → `status='cancelled'`. Trips in `in_progress`, `draft` or `hidden`
   are left alone.
6. For each such trip, every booking with status `confirmed` is cancelled with
   `cancelledBy='admin_ban_driver'`, `cancellationReason='Trip cancelled — driver account banned'`,
   and each passenger receives a push
   (`title: 'Trip Cancelled'`, `body: 'Your trip to <toName> has been cancelled'`,
   `type: 'trip_cancelled_by_admin'`, `data: { screen: 'home', tripId }`). Per-passenger push failures
   are caught and logged.
7. Ban step 4 — every `user_devices` row with `status='active'` becomes `status='revoked'`,
   `revokedAt=now`, `revokeReason='account_banned: <reason>'`.
8. Ban step 5 — one `security_events` row: `eventType='account_banned'`, `adminActorId=<admin>`,
   `metadata={ reason, cancelledBookings, cancelledTrips, revokedDevices }`.
9. Ban step 6 — fire-and-forget push to the banned user (`.catch(() => {})`).
10. A structured JSON line is logged: `{event:'admin.ban', userId, adminId, cancelledBookings, cancelledTrips, revokedDevices}`.
11. Unban: 404 if not found; `400 User is not banned` when `bannedAt == null`.
12. Unban clears `bannedAt` and `banReason` **only**. Cancelled bookings and trips are **never**
    restored, revoked devices are **not** reactivated. Documented explicitly at
    `admin-ban.service.ts:34-35`.
13. Unban writes `security_events` with `eventType='account_unbanned'`, `metadata={}`.
14. **No transaction wraps the cascade.** A failure midway leaves a partially-applied ban.

**Data model:** writes `users.bannedAt`, `users.banReason`; `bookings.status/cancelledAt/cancelledBy/cancellationReason`;
`trips.status`; `user_devices.status/revokedAt/revokeReason`; inserts `security_events`.

**State machine (account ban):**

```
        POST /ban {reason}                POST /unban
active ─────────────────────────► banned ─────────────► active
  ▲                                 │
  │  (re-ban rejected: 400)  ───────┘
```

Effect of `bannedAt != null`: `BanGuard` rejects every non-`@Public()` request with 403
`{ code: 'ACCOUNT_BANNED', banReason, supportWhatsApp }`.

**Side effects:** as enumerated in rules 4–9 — booking cancellations, trip cancellations, device
revocation, passenger pushes, banned-user push, one security event, one structured log line.
No wallet or refund effects: money already taken is not returned.

**External services:** Firebase Cloud Messaging.

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| Not found | 404 | `User not found` |
| Already banned | 400 | `User is already banned` |
| Not banned (unban) | 400 | `User is not banned` |
| Malformed UUID | 400 | ParseUUIDPipe message |
| Any request by a banned user | 403 | payload `{code:'ACCOUNT_BANNED', banReason, supportWhatsApp}` |

**Notes for reimplementation:**
- Wrap the cascade in a transaction, or make each step idempotent and retryable.
- Passenger seats are not released for the banned user's own bookings (rule 4) while they *are*
  effectively released for cancelled driver trips — an inconsistency worth resolving.
- `supportWhatsApp` is injected into the 403 body from `SUPPORT_WHATSAPP_E164`, so the mobile ban
  screen can offer a contact route without another API call.
- The dashboard also calls a *different* `PATCH /admin/users/:id/ban` with `{isActive}` (toggle-active
  semantics). That route does not exist on the live server — see §2.4.

---

## F-07: Account risk flags — review queue

**What it does:** Automated heuristics raise flags against accounts (currently: too many accounts from
one device fingerprint). Admins list open flags and either resolve them (account judged safe) or
dismiss them (false positive / already handled). Every decision appends a security event.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/account-flags` | admin | List flags, filterable |
| PATCH | `/api/v1/admin/account-flags/:flagId/resolve` | admin | Mark resolved |
| PATCH | `/api/v1/admin/account-flags/:flagId/dismiss` | admin | Mark dismissed |

Both PATCH handlers are `@HttpCode(200)` and take `:flagId` through `ParseUUIDPipe`.

**Request / Response contracts:**

`GET` query params (raw `@Query()` — **no DTO, no validation**):

| Param | Type | Notes |
|---|---|---|
| `userId` | string | Filter `f."userId" = :userId`. Not UUID-validated ⇒ a malformed value raises a Postgres cast error surfaced as 500 |
| `disposition` | string | Expected `open`\|`resolved`\|`dismissed`; not validated |
| `limit` | number | `Number(limit)`; default `50`; **no upper bound** |
| `offset` | number | `Number(offset)`; default `0`. Note `offset=0` is falsy ⇒ `undefined` ⇒ still 0 — harmless |

Response: `{ flags: AccountFlagEntity[], total: number }` — offset/limit pagination, **not** the
`{data, meta}` shape used everywhere else in the admin API.

`PATCH` body: `{ notes?: string }`, extracted via `@Body('notes')`. **No DTO and no length limit.**

Response: the full saved `AccountFlagEntity`.

**Business rules & validation:**

1. Ordering: `createdAt DESC`.
2. `resolve` ⇒ `disposition='resolved'`, `resolvedByAdminId=<admin>`, `resolvedAt=now`; `notes` overwritten
   **only if truthy** (an empty string leaves the system-written notes intact).
3. `dismiss` ⇒ identical except `disposition='dismissed'`.
4. Neither operation checks the current disposition — a resolved flag can be re-resolved or flipped to
   dismissed indefinitely, each time re-stamping `resolvedAt` and appending another security event.
5. Flag creation (`AccountRiskService.checkMultiAccountThreshold`, called from OTP verification):
   if ≥ `MULTI_ACCOUNT_DEVICE_THRESHOLD` (default 3) distinct user ids share a device fingerprint hash
   within 24 hours, then `users.restricted = true` for the triggering account, an `account_flags` row
   is inserted with `reason='multi_account_device'`, `severity='high'`, `disposition='open'`, and
   `notes='Device fingerprint linked to N accounts within 24 h (threshold: T).'`, plus a
   `security_events` row `eventType='account_restricted_auto'` with metadata
   `{reason, distinctAccountCount, fingerprintHash}`. No-op when the fingerprint hash is null.

**Data model:** `account_flags` (see §4.6), `security_events` (§4.7), `users.restricted`.

**State machine (flag disposition):**

```
                ┌── PATCH /resolve ──► resolved ──┐
   open ────────┤                                 ├── (both re-enterable, no guard)
                └── PATCH /dismiss ──► dismissed ─┘
```
Trigger for `open`: `AccountRiskService` heuristic (automatic) or a manual insert
(`reason='manual_review'` is documented as a value but no code path writes it).

**Side effects:**
- `resolve` → `security_events` row `eventType='account_flag_resolved'`, `adminActorId`,
  `metadata={ flagId, reason: flag.reason }`.
- `dismiss` → same with `eventType='account_flag_dismissed'`.
- **Neither clears `users.restricted`.** Nothing anywhere in `src/` sets `restricted = false`
  (verified by grep). The documented event type `account_unrestricted_admin`
  (`security-event.entity.ts:28`) is never emitted. An auto-restricted account is therefore
  **permanently write-locked** with no admin remedy short of direct SQL. This is the single most
  important gap in this domain — a rebuild must add an "unrestrict" action.

**External services:** none.

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| Flag not found | 404 | `Account flag not found` |
| Malformed flag UUID | 400 | ParseUUIDPipe message |
| Malformed `userId` query value | 500 | Postgres cast error (unvalidated) |

**Notes for reimplementation:** Add DTO validation on the query and on `notes`; cap `limit`; return the
standard `{data, meta}` pagination shape; add an unrestrict action; consider forbidding transitions
out of a terminal disposition.

---

## F-08: Device session revocation (admin)

**What it does:** Admin kills a specific device session so the bound refresh/access tokens stop working.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| DELETE | `/api/v1/admin/devices/:deviceId/revoke` | admin | Revoke a `user_devices` session |

`@HttpCode(200)` (not 204). `:deviceId` via `ParseUUIDPipe`.

**Request / Response contracts:**

Body: `{ reason?: string }` via `@Body('reason')` — no DTO, no length limit. A `DELETE` with a body is
unusual but supported.

Response: the revoked `UserDeviceEntity`.

**Business rules & validation:**

1. 404 `Device not found` when the id does not exist.
2. Revocation is delegated to `DeviceFingerprintService.revokeDevice(deviceId, reason ?? 'admin_revoke')`.
3. A `security_events` row is written: `eventType='device_revoked_by_admin'`, `deviceId`,
   `adminActorId`, `metadata={ reason: reason ?? null }`.
4. No re-revocation guard: revoking an already-revoked device succeeds and logs again.
5. Effect: `JwtStrategy.validate` rejects any token whose `did` claim points at a non-active device
   ⇒ `401 Device session is no longer active`. Tokens issued **without** a `did` (the admin
   email/password path) are unaffected.

**Data model:** `user_devices.status/revokedAt/revokeReason` (enum `user_device_status_enum`:
`active`, `revoked`); inserts `security_events`.

**State machine:** `active → revoked`. One-way; no un-revoke endpoint.

**Side effects:** one security event. No notification to the user.

**External services:** none. **Background jobs:** none.

**Errors:** 404 `Device not found`; 400 on malformed UUID.

**Notes for reimplementation:** The dashboard expects a `GET /admin/users/:id/devices` listing to drive
this action; that endpoint does not exist (§2.4). Implement it, or the revoke button has nothing to
enumerate.

---

## F-09: Vehicle management and verification

**What it does:** Drivers register exactly one vehicle with photos of the vehicle and its documents;
admins mark it verified or rejected, which gates trip publication.

**Actors:** `driver` (own vehicle CRUD), `admin` (verification, listing).

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/vehicles/types` | auth (any role) | Vehicle-type catalog + seat layouts |
| POST | `/api/v1/vehicles` | driver | Create the driver's vehicle |
| GET | `/api/v1/vehicles/my` | driver | Read own vehicle |
| PATCH | `/api/v1/vehicles/:id` | driver | Update own vehicle |
| DELETE | `/api/v1/vehicles/:id` | driver | Delete own vehicle |
| GET | `/api/v1/admin/vehicles` | admin | Paginated vehicle list |
| PATCH | `/api/v1/admin/vehicles/:id/verify` | admin | Verify / reject |

`VehiclesController` also declares `@UseGuards(JwtAuthGuard, RolesGuard)` on the class — harmless
duplication of the global guards.

**Request / Response contracts:**

`CreateVehicleDto` (`vehicles/dto/create-vehicle.dto.ts`):

| Field | Type | Rules | Required |
|---|---|---|---|
| `vehicleType` | string | `@IsString() @MaxLength(100)` | yes |
| `plateNumber` | string | `@IsString() @MaxLength(20)` | yes |
| `model` | string | `@IsString() @MaxLength(100)` | yes |
| `seats` | int | `@IsInt() @Min(1) @Max(50)` | no — derived when absent |
| `seatLayout` | object | `@ValidateNested()` → `VehicleSeatLayoutDto` | no — derived when absent |
| `licenseImageUrl` | string | `@MaxLength(500)` | no |
| `vehicleLicenseImageUrl` | string | `@MaxLength(500)` | no |
| `carImageUrl` | string | `@IsString() @MaxLength(500)` | **yes** |
| `insuranceImageUrl` | string | `@MaxLength(500)` | no here; required by the driver-registration DTO |

`VehicleSeatLayoutDto`: `rows` int 1–10 (required), `seatsPerRow` int 1–10 (required),
`preventGenderMixing` boolean (optional), `seatsPerRowList` int[] with `@ArrayMaxSize(10)` and each
element int 1–10 (optional).

`UpdateVehicleDto = PartialType(CreateVehicleDto)` — every field optional.

Admin list query `AdminVehiclesQueryDto extends PaginationDto`: `page`, `limit` (≤100),
`isVerified` (string→boolean transform), `driverId` (string, not UUID-validated).

Admin verify body `VerifyVehicleDto`: `{ isVerified: boolean }` (`@IsBoolean()`, required).

Admin list response: `PaginatedResult<VehicleEntity>` with the `driver` relation eagerly joined
(`leftJoinAndSelect('v.driver','driver')` — the full user row, minus `select:false` columns).

**Business rules & validation:**

1. **One vehicle per driver.** `create` first looks for an existing row by `driverId`; found ⇒
   `409 Driver already has a vehicle`. Also enforced by the unique index `idx_vehicles_driver_id`.
2. When `seatLayout` is omitted, it is resolved from the vehicle-type catalog
   (`resolveVehicleTypeTemplate`). Unknown types fall back to `sedan` and log a warning
   (`Vehicle type "<x>" has no seat layout template; using sedan`).
3. When `seats` is omitted it is computed by `countSeatsInLayout`:
   `sum(seatsPerRowList)` if that array is non-empty, else `rows * seatsPerRow`.
4. `update` and `delete` require `vehicle.driverId === callerId` ⇒ else `403 You are not the owner of
   this vehicle`. Note: an **admin cannot** edit or delete a vehicle — only verify it.
5. `update` uses `repo.merge` — a partial patch. It does **not** recompute `seats` when `seatLayout`
   changes, so seat count and layout can drift out of sync via `PATCH /vehicles/:id`.
   `verify: src/modules/vehicles/vehicles.service.ts:89`.
6. `update` does **not** reset `isVerified` to `false`. A driver can get verified and then swap the
   plate number, model and all document images while keeping the verified badge. Significant
   trust-and-safety hole. `verify: src/modules/vehicles/vehicles.service.ts:80-91`.
7. Admin `verify` 404s with `Vehicle not found`; otherwise sets `isVerified` and saves.
8. Admin list clamps `page`/`limit` like F-03 and orders by `createdAt DESC`. Wrapped in
   `try/catch` that returns an **empty page** (`{data:[],meta:{page,limit,total:0,totalPages:0}}`)
   on any DB error — errors are silently swallowed.
9. `GET /vehicles/types` requires authentication but no particular role.

**Data model:** `vehicles` (§4.4).

**State machine (verification):**

```
isVerified: false ──PATCH /admin/vehicles/:id/verify {isVerified:true}──► true
                ▲                                                          │
                └───────────{isVerified:false}─────────────────────────────┘
```
Freely repeatable in both directions. No "pending"/"rejected" distinction is persisted — rejected and
never-reviewed are the same state (`false`), which is why `pendingVehicleVerifications` in F-02 counts
both.

**Side effects:** admin `verify` creates a notification to `vehicle.driverId`:

| isVerified | type | title | body |
|---|---|---|---|
| `true` | `vehicle_verified` | `Vehicle Verified` | `Your vehicle has been verified. You can now create trips.` |
| `false` | `vehicle_rejected` | `Vehicle Rejected` | `Your vehicle verification was rejected. Please check details and resubmit.` |

`data: { vehicleId, isVerified }`. Also logs `Vehicle <id> verification status changed to <bool>`.
These strings are English while driver-approval strings are Arabic — inconsistent localisation.

**External services:** FCM (push), S3/local uploads (the image URLs are produced by the uploads module;
this module only stores strings).

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| Second vehicle for a driver | 409 | `Driver already has a vehicle` |
| Vehicle not found | 404 | `Vehicle not found` |
| Not the owner (update/delete) | 403 | `You are not the owner of this vehicle` |
| DTO violation | 400 | class-validator messages |

**Notes for reimplementation:** Reset `isVerified` on any material edit; recompute `seats` when the
layout changes; give rejection a reason field; do not swallow list errors.

---

## F-10: Vehicle type catalog

**What it does:** Static, code-defined catalog of supported vehicle types with bilingual labels,
default seat counts and default seat layouts. Drives seat-map rendering and the auto-derived layout
in F-09.

**Actors:** any authenticated user.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/vehicles/types` | auth | Return the catalog |

**Request / Response contracts:** no parameters. Response `data` = `{ types: VehicleTypeTemplate[] }`,
each `{ type, label: {en, ar}, seats, layout: {rows, seatsPerRow, seatsPerRowList?, preventGenderMixing?} }`.

**Business rules & validation:** `SUPPORTED_VEHICLE_TYPES` ordering is preserved; every template is
deep-cloned before being returned so callers cannot mutate the module-level constant.

**Data model:** none — pure constants in `src/modules/vehicles/vehicle-types.ts`. `DEFAULT_VEHICLE_TYPE = 'sedan'`.

Exact catalog:

| type | label.en | label.ar | seats | rows | seatsPerRow | seatsPerRowList | preventGenderMixing |
|---|---|---|---|---|---|---|---|
| `sedan` | Sedan | سيدان | 4 | 2 | 3 | `[1,3]` | false |
| `suv` | SUV | دفع رباعي | 5 | 2 | 3 | `[2,3]` | false |
| `van` | Van | فان | 7 | 3 | 3 | `[2,3,2]` | false |
| `truck` | Truck | شاحنة | 2 | 1 | 2 | — | false |
| `bus` | Bus | حافلة | 20 | 5 | 4 | `[4,4,4,4,4]` | false |
| `motorcycle` | Motorcycle | دراجة نارية | 1 | 1 | 1 | — | false |

Note `sedan.seats = 4` but `sum([1,3]) = 4` ✔; `suv.seats = 5` vs `sum([2,3]) = 5` ✔;
`van.seats = 7` vs `sum([2,3,2]) = 7` ✔; `bus.seats = 20` vs `sum([4,4,4,4,4]) = 20` ✔.
All consistent.

**State machine / side effects / external services / background jobs:** none.

**Errors:** none.

**Notes for reimplementation:** CLAUDE.md contemplates a seed table for this catalog; today it is a
hardcoded constant. `resolveVehicleTypeTemplate` lowercases and trims the incoming type before lookup
and never throws — unknown types silently become `sedan`.

---

## F-11: Trip oversight

**What it does:** Read-only paginated view of every trip with its driver, for support and moderation.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/trips` | admin | Paginated trip list |

**Request / Response contracts:**

`AdminTripsQueryDto extends PaginationDto`:

| Param | Type | Rules |
|---|---|---|
| `page` / `limit` | int | 1+, ≤100, defaults 1/20 |
| `status` | string | `@IsEnum(['active','hidden','completed','cancelled'])` |
| `driverId` | string | any string |

Response: `PaginatedResult<TripEntity>` with `driver` joined, ordered `createdAt DESC`.

**Business rules & validation:**

1. The allowed `status` values are **out of sync with the real `TripStatus` enum**. The DTO accepts
   `active` (a dead value post-migration) and rejects `published`, `draft`, `fully_booked`,
   `in_progress`. So an admin cannot filter for the statuses that actually exist.
   `verify: src/modules/admin/dto/admin-trips-query.dto.ts:6`.
2. Full `TripStatus` enum for reference (`shared.enums.ts:7-22`): `active` (deprecated),
   `draft`, `published`, `fully_booked`, `in_progress`, `hidden`, `completed`, `cancelled`.
3. Errors are swallowed → empty page.
4. There is **no** admin endpoint to cancel, hide or edit a trip. Trip cancellation only happens as a
   side effect of banning the driver (F-06).

**Data model:** reads `trips` + `users` (driver).

**State machine:** n/a here. **Side effects:** none. **External services:** none. **Background jobs:** none.

**Errors:** 400 on an out-of-list `status`.

**Notes for reimplementation:** Fix the status list; add trip moderation actions if operators need them.

---

## F-12: Booking oversight and admin cancellation

**What it does:** Paginated bookings view with passenger, trip and seat detail, plus an admin
force-cancel that releases the seats and notifies the passenger.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/bookings` | admin | Paginated bookings |
| PATCH | `/api/v1/admin/bookings/:id/cancel` | admin | Force-cancel a booking |

**Request / Response contracts:**

`AdminBookingsQueryDto extends PaginationDto`:

| Param | Type | Rules |
|---|---|---|
| `page` / `limit` | int | 1+, ≤100 |
| `status` | string | `@IsEnum(['pending','confirmed','cancelled','completed'])` |
| `userId` | string | passenger filter (`b.userId`) |
| `tripId` | string | trip filter |
| `driverId` | string | filters on the joined `trip.driverId` |

Response `data[]` — a hand-built, Mongo-flavoured shape (note the `_id` aliases, kept for the legacy
dashboard):

```
{
  _id, id, status,
  seatNumber: null,               // always null — legacy field, column dropped by migration 008.11
  seatCount, totalAmount: number,
  seats: [ { id, bookingId, seatNumber, displayName, gender, isMainBooker, markedAbsentAt, createdAt } ],
  hasDriverPaidToContact, sharePhoneWithDriver,
  cancellationReason, cancelledAt, cancelledBy,
  createdAt, updatedAt,
  userId: { _id, name, email, phoneNumber } | { _id, name:'User not found', email:'' } | <raw id>,
  tripId: { _id, id, fromName, toName, from:{name}, to:{name}, departureTime, price, currency, seatLayout } | <raw id>
}
```

Cancel: no body; returns the saved `BookingEntity`.

**Business rules & validation:**

1. Same page/limit clamping and `createdAt DESC` ordering; errors swallowed → empty page.
2. When the `user` relation fails to hydrate, a second lookup batches the missing passenger ids via
   `In(...)`; still-missing users render as `{_id, name:'User not found', email:''}` rather than
   failing the row. Same fallback pattern is used for payments, ratings, notifications and wallets.
3. `totalAmount` is coerced with `Number(b.totalAmount ?? 0)`.
4. `PATCH .../cancel` delegates to `BookingsService.cancelAsAdmin`:
   - 404 `Booking not found`;
   - `400 Booking is already cancelled` when `status === 'cancelled'`;
   - `400 Cannot cancel a completed booking` when `status === 'completed'`;
   - otherwise sets `status='cancelled'`, `cancellationReason='Cancelled by admin'`,
     `cancelledAt=now`, `cancelledBy='admin'`;
   - releases each held seat via `tripsService.releaseSeat(tripId, seatNumber)` and emits
     `emitSeatReleased` over the trips WebSocket gateway — both `.catch(() => undefined)`, i.e.
     failures are ignored;
   - notifies the passenger via `notifyPassengerOfBookingDecision(bookingId, 'canceled')`
     (fire-and-forget, warning logged on failure);
   - logs `Booking cancelled by admin: <id>`.
5. **No refund and no wallet reversal** happens on admin cancellation. Money already collected stays.
6. No audit/security-event row is written for an admin booking cancellation — only the log line and
   the `cancelledBy='admin'` marker on the row.

**Data model:** `bookings.status/cancellationReason/cancelledAt/cancelledBy`; reads
`booking_seats`, `trips`, `users`. `cancelledBy` observed values across the codebase: `'admin'`,
`'admin_ban'`, `'admin_ban_driver'`, plus non-admin values written elsewhere.

**State machine (booking, admin-relevant subset):**

```
pending ─┐
         ├── PATCH /admin/bookings/:id/cancel ──► cancelled   (seats released, passenger notified)
confirmed┘
completed ── cancel ──► 400
cancelled ── cancel ──► 400
```
`BookingStatus` also includes `in_progress` and `no_show`, which the admin filter DTO does not expose.

**Side effects:** seat release, `seatReleased` socket event, passenger push, log line.

**External services:** FCM; Socket.IO (trips gateway).

**Background jobs:** none.

**Errors:** 404 `Booking not found`; 400 `Booking is already cancelled`; 400 `Cannot cancel a completed booking`.

**Notes for reimplementation:** Decide the refund policy explicitly — today an admin cancel leaves the
passenger charged. Add an audit row.

---

## F-13: Settlement revert (admin override)

**What it does:** Undoes a driver's "mark as paid" on a booking, outside the normal 5-minute grace
window, and exposes the settlement audit trail for that booking.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/admin/bookings/:id/admin-revert-settlement` | admin | Clear `settledAt` + write an audit row |
| GET | `/api/v1/admin/bookings/:id/settlement-audits` | admin | Full audit trail for the booking |

Declared in `src/modules/settlement/settlement.controller.ts` on a prefix-less `@Controller()`.

**Request / Response contracts:**

`AdminRevertDto`: `{ reason?: string }` — `@IsOptional() @IsString() @MaxLength(500)`.
Omitted ⇒ the service stores `'No reason provided'`.

Revert response: the saved `BookingEntity`.
Audits response: `SettlementAuditEntity[]` ordered `createdAt ASC`, with the `actor` relation joined.

**Business rules & validation:**

1. 404 `Booking not found`.
2. Sets `booking.settledAt = null` and `booking.settlementGraceUntil = null`. No status change, no
   money movement.
3. Inserts `settlement_audits` with `action='admin_revert'`, `actorId=<admin id>`, `reason`.
4. Logs `Booking <id> settlement reverted by admin <adminId>: <reason>`.
5. No idempotency guard — reverting an already-unsettled booking succeeds and adds another audit row.
6. `:id` is **not** run through `ParseUUIDPipe` here (unlike most other admin routes) — a malformed id
   surfaces as a Postgres error / 500.

**Data model:** `bookings.settledAt`, `bookings.settlementGraceUntil`; inserts `settlement_audits` (§4.9).

**State machine:** `settled (settledAt != null) → unsettled (settledAt = null)`. The driver-side
`mark_paid` / `unmark_paid` transitions belong to the settlement domain, not this document.

**Side effects:** one `settlement_audits` row; one log line. No notification to driver or passenger.

**External services:** none. **Background jobs:** none.

**Errors:** 404 `Booking not found`.

**Notes for reimplementation:** This is the one admin action with a proper first-class audit table
(`settlement_audits`) rather than the generic `security_events`. Consider unifying.

---

## F-14: Payments oversight

**What it does:** Read-only listing of all payments with a dedicated pending queue for the approval
workflow. (The approve/reject actions themselves live in the payments module, outside this document.)

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/payments` | admin | All payments, filterable |
| GET | `/api/v1/admin/payments/pending` | admin | Shorthand for `status='pending'` |

**Request / Response contracts:**

`AdminPaymentsQueryDto extends PaginationDto`:

| Param | Type | Allowed values (DTO) |
|---|---|---|
| `page` / `limit` | int | 1+, ≤100 |
| `status` | string | `pending`, `approved`, `rejected`, `refunded` |
| `method` | string | `wallet`, `paymob`, `manual`, `communication_fee` |
| `paymentType` | string | `trip`, `communication_fee`, `wallet_topup`, `wallet_trip_charge` |
| `walletOnly` | boolean | string→boolean transform |

**Mismatch:** the Swagger `@ApiQuery` on the controller advertises `method: cliq_a2a` and
`paymentType: trip_platform` in addition, but the DTO's `@IsEnum` does **not** include them, and
`forbidNonWhitelisted`/enum validation rejects those values with 400.
`verify: admin-dashboard.controller.ts:170-188` vs `dto/admin-payments-query.dto.ts:12-18`.

Response `data[]` (hand-built):

```
{ _id, id,
  userId: {_id,name,email,phoneNumber} | {_id,name:'User not found',email:''} | <raw>,
  tripId: {_id,id,fromName,toName,from:{name},to:{name},departureTime} | <raw>,
  bookingId, amount: number, currency, method, paymentType, status, direction,
  proofImageUrl, walletNumber, transactionId, paymentGatewayRef, adminNote,
  recipientAliasType, recipientAliasValue, createdAt, updatedAt }
```

**Business rules & validation:**

1. `walletOnly=true` **overrides** `paymentType`: it forces
   `paymentType IN ('wallet_topup','wallet_trip_charge')` and the `paymentType` filter is ignored.
2. `/payments/pending` is literally `getPayments({...query, status:'pending'})` — any `status` the
   caller passes is overwritten.
3. The payer join is aliased `payer`, not `user`, with an explicit code comment that `user` is a
   reserved word in PostgreSQL and breaks the join.
4. Missing payer relations are back-filled with a batched `In(...)` lookup, then the
   `'User not found'` placeholder.
5. `amount` is coerced to `Number` (DB stores numeric/decimal as string).
6. Whole method wrapped in `try/catch` → empty page on error.

**Data model:** reads `payments`, `users`, `trips`.

**State machine:** payment status `pending → approved | rejected | refunded` — owned by the payments
module.

**Side effects:** none (read-only).

**External services:** none here.

**Background jobs:** none here. Note `CliqPollProcessor` (payments module) calls
`AdminAlertsService.notifyFeePayment` when a communication-fee payment succeeds — see F-22.

**Errors:** 400 on enum violations.

**Notes for reimplementation:** Align the DTO enums with reality (`cliq_a2a`, `trip_platform` are real
values in the system). Stop swallowing errors.

---

## F-15: Wallet oversight and manual balance adjustment

**What it does:** Lists wallet accounts, shows one account with its owner and its transaction ledger,
and lets an admin credit or debit a wallet manually with an audited ledger entry.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/wallets` | admin | Paginated wallet accounts |
| GET | `/api/v1/admin/wallets/:id` | admin | One wallet + owner summary |
| GET | `/api/v1/admin/wallets/:id/transactions` | admin | Ledger for that wallet |
| PATCH | `/api/v1/admin/wallets/:id/adjust` | admin | Manual credit / debit |

**Request / Response contracts:**

`AdminWalletsQueryDto extends PaginationDto`:

| Param | Type | Rules |
|---|---|---|
| `page` / `limit` | int | 1+, ≤100 |
| `accountType` | enum | `@IsEnum(WalletAccountType)` → `driver`, `rider`, `system` |
| `search` | string | matches owner `name`/`email`/`phoneNumber` (ILIKE) |
| `minBalance` / `maxBalance` | number | `@Type(()=>Number) @IsNumber()`; compared as `CAST(balance AS DECIMAL)` |
| `isActive` | boolean | string→boolean transform |

Transactions query: plain `PaginationDto` (`page`, `limit` ≤100).

`AdminAdjustWalletDto` (`dto/admin-adjust-wallet.dto.ts`):

| Field | Type | Rules |
|---|---|---|
| `amount` | number | `@IsNumber() @Min(-1000000)` — **required**; negative = debit. Note there is **no `@Max`**, so an unbounded credit is accepted |
| `currency` | string | `@IsOptional() @IsString()`; defaults to the wallet's currency |
| `note` | string | `@IsOptional() @IsString() @MaxLength(500)` |

Wallet DTO shape returned by list / get / adjust (`mapWalletToAdminDto`):

```
{ id, userId: {_id,name,email,phoneNumber} | {_id,name:'User not found',email:''} | <raw>,
  accountType, currency, balance: string, isActive, createdAt, updatedAt }
```
`balance` is deliberately a **string** (`String(wa.balance)`) to avoid float rounding.

Transactions response: `PaginatedResult<WalletTransactionEntity & {amount:number}>`, ordered
`createdAt DESC`; `amount` coerced to a JS number here (inconsistent with the string above).

**Business rules & validation:**

1. Wallet list sorts by `updatedAt DESC` (all other admin lists sort by `createdAt DESC`).
2. Wallet list is **not** wrapped in a `try/catch` — DB errors surface as 500.
3. `GET /:id` and `GET /:id/transactions` 404 with `Wallet account not found`.
4. `adjust` (`WalletService.adjustBalanceByAdmin`):
   - `400 Adjustment amount must be non-zero` when `amount === 0` or non-finite;
   - `404 Wallet account not found`;
   - `400 Currency does not match wallet currency` if an explicit `currency` differs from the account's;
   - runs inside a DB transaction with `pessimistic_write` lock on the wallet row;
   - `400 Adjustment would make wallet balance negative` if `balance + amount < 0`;
   - writes `balance = (current + amount).toFixed(2)`;
   - inserts a `wallet_transactions` row: `type='adjustment'`,
     `direction = amount > 0 ? 'credit' : 'debit'`, `status='posted'`,
     `amount = Math.abs(amount).toFixed(2)`, `currency = account currency`,
     `metadata = { note, adminId, balanceBefore, balanceAfter }`. **This metadata is the audit record
     for manual adjustments.**
5. After the transaction commits, the controller-side service re-reads the wallet and, **only when
   `amount > 0`**, sends an Arabic notification to the owner:
   `type='wallet_credited'`, title `تم إضافة رصيد إلى محفظتك`,
   body `تمت إضافة {amount} {currency} إلى محفظتك. رصيدك الحالي: {newBalance} {currency}.`,
   `data={walletId, amount, newBalance, currency}`. Debits are silent — the user is not told.
   Notification failure is caught and warn-logged.
6. `adjust` returns the refreshed wallet DTO, not the transaction.

**Data model:** `wallet_accounts.balance`; inserts `wallet_transactions`
(`WalletTransactionType.ADJUSTMENT`, `WalletEntryDirection.CREDIT|DEBIT`, `WalletTransactionStatus.POSTED`).

Enums (`shared.enums.ts`):
- `WalletAccountType`: `driver`, `rider`, `system`
- `WalletTransactionType`: `topup`, `trip_debit`, `trip_payment`, `refund`, `payout`, `adjustment`, `hold`, `release_hold`
- `WalletEntryDirection`: `debit`, `credit`
- `WalletTransactionStatus`: `pending`, `posted`, `failed`, `reversed`
- `PayoutStatus`: `pending`, `approved`, `rejected`, `paid`

**State machine:** none for adjustments — every adjustment is immediately `posted`.

**Side effects:** balance mutation, ledger insert, owner notification on credit only.

**External services:** FCM.

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| Wallet missing | 404 | `Wallet account not found` |
| Zero / non-finite amount | 400 | `Adjustment amount must be non-zero` |
| Currency mismatch | 400 | `Currency does not match wallet currency` |
| Would go negative | 400 | `Adjustment would make wallet balance negative` |

**Notes for reimplementation:**
- **Payout approval does not exist as an endpoint.** `PayoutStatus` (`pending/approved/rejected/paid`)
  is defined in `shared.enums.ts` but no admin controller in this repo exposes a payout queue.
  Manual wallet adjustment is the de-facto payout mechanism. If the product needs payouts,
  design it fresh.
- The refund flow is likewise **not** money-moving: `refund_requests` is a tracking table and the real
  refund happens over WhatsApp (F-19).
- Add a `@Max` on `amount`; consider a four-eyes approval for large adjustments.

---

## F-16: Ratings and rating moderation

**What it does:** Participants rate each other 1–5 with an optional comment after a trip completes;
the rated user's rolling average is recomputed. Admins can list all ratings.

**Actors:** `passenger`, `driver` (create/read); `admin` (list).

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/ratings` | auth | Create a rating |
| GET | `/api/v1/ratings/user/:userId` | auth | Ratings received by a user |
| GET | `/api/v1/ratings/trip/:tripId` | auth | Ratings on a trip |
| GET | `/api/v1/ratings/my` | auth | Ratings the caller gave |
| GET | `/api/v1/admin/ratings` | admin | Paginated moderation list |
| ~~DELETE~~ | ~~`/api/v1/admin/ratings/:id`~~ | — | **Does not exist** — only in the dead controller |

**Route-order gotcha:** `@Get('user/:userId')` and `@Get('trip/:tripId')` are declared before
`@Get('my')` in `ratings.controller.ts`. Because the static segments differ (`user`/`trip` vs `my`),
`/ratings/my` still resolves correctly.

**Request / Response contracts:**

`CreateRatingDto` (`ratings/dto/create-rating.dto.ts`):

| Field | Type | Rules | Required |
|---|---|---|---|
| `toUserId` | string | `@IsString() @IsNotEmpty()` — **not** `@IsUUID` | yes |
| `tripId` | string | `@IsString() @IsNotEmpty()` | yes |
| `rating` | int | `@IsInt() @Min(1) @Max(5)` | yes |
| `comment` | string | `@IsOptional() @IsString() @MaxLength(500)` | no |

`AdminRatingsQueryDto extends PaginationDto`: `page`, `limit` (≤100), `userId` (string),
`tripId` (string), `minRating` (`@IsInt() @Min(1) @Max(5)`).

Admin list response `data[]`:

```
{ _id, id,
  fromUserId: {_id,name,email,phoneNumber} | {_id,name:'User not found',email:''},
  toUserId:   same shape,
  tripId: {_id,id,fromName,toName,from:{name},to:{name},departureTime} | <raw>,
  rating, comment, userRole, ratedRole, createdAt, updatedAt }
```

User-facing list endpoints return `PaginatedResult<RatingEntity>` with relations
(`fromUser`; `fromUser`+`toUser`; `toUser` respectively).

**Business rules & validation:**

1. Self-rating rejected: `fromUserId === toUserId` ⇒ `400 لا يمكنك تقييم نفسك`.
2. Trip must exist ⇒ else `404 الرحلة غير موجودة`.
3. Trip must be `TripStatus.COMPLETED` ⇒ else
   `400 لا يمكن التقييم إلا بعد اكتمال الرحلة. انتظر حتى ينهي السائق الرحلة ثم عُد للتقييم.`
4. The rater must be a participant: either `trip.driverId === fromUserId`, or the rater has a booking
   on that trip with status in `{confirmed, completed, in_progress}` ⇒ else
   `403 أنت لست مشاركاً في هذه الرحلة`.
5. One rating per (rater, trip): an existing `{fromUserId, tripId}` row ⇒
   `400 لقد قمت بالفعل بتقييم هذا المستخدم لهذه الرحلة`. Backed by the unique index
   `idx_ratings_from_user_trip`. **Consequence:** a driver with four passengers can rate only one of
   them per trip. Real product limitation — note it before rebuilding.
6. The target user must exist ⇒ else `404 المستخدم غير موجود`.
7. `ratedRole` is derived, not supplied: `userRole === 'driver' ? 'passenger' : 'driver'`. `userRole`
   comes from `req.user.role || 'passenger'`, so an admin rating anyone would be stored as
   `userRole='admin', ratedRole='driver'`.
8. The rater id is taken from `req.user.sub` (the JWT subject), **not** `req.user.id`, in
   `RatingsController`. Since `JwtStrategy.validate` returns a `UserEntity` (which has `id`, not `sub`),
   `req.user.sub` is `undefined` at runtime and the insert would violate the NOT NULL `fromUserId`.
   **This looks like a live bug on all three `req.user.sub` sites.**
   `verify: src/modules/ratings/ratings.controller.ts:46, 87`.
9. `updateUserAverage(toUserId)` recomputes from scratch:
   `cnt = COUNT(*)`, `sum = COALESCE(SUM(rating),0)` over `toUserId`;
   if `cnt === 0` writes `rating=0, totalRatings=0`;
   else writes `rating = Math.round((sum/cnt) * 10) / 10` (one decimal place) and `totalRatings = cnt`.
10. Admin list filters: `userId` matches `fromUserId OR toUserId`; `minRating` is `>=`.
    Wrapped in `try/catch` → empty page on error.
11. **There is no live moderation action.** Ratings cannot be deleted, hidden or edited through any
    registered route. `admin.controller.ts` declares `DELETE /admin/ratings/:id` and
    `AdminService.deleteRating` exists, but neither is registered (F-31), and
    `AdminDashboardService` has no `deleteRating` at all.

**Data model:** `ratings` (§4.3); writes `users.rating`, `users.totalRatings`.

**State machine:** none — ratings are immutable once written.

**Side effects:** after save, `updateUserAverage`, then a fire-and-forget notification to the rated
user: `type='rating_new'`, title `تقييم جديد`,
body `وصلك تقييم {rating} من 5{ — comment}`, `data={tripId, ratingId}`; failures warn-logged.

**External services:** FCM.

**Background jobs:** none.

**Errors:** see rules 1–6; all messages are Arabic.

**Notes for reimplementation:**
- Decide whether one-rating-per-trip is per-rater (current) or per (rater, ratee) — the latter needs
  the unique index changed to `(fromUserId, toUserId, tripId)`.
- Implement moderation (delete/hide) and recompute the average when a rating is removed.
- Fix the `req.user.sub` vs `req.user.id` mismatch.
- Add a DB `CHECK (rating BETWEEN 1 AND 5)`.

---

## F-17: Complaint handling

**What it does:** Users file complaints against another user, a trip or a booking. Admins work a
filtered queue, set a status and add internal notes; the reporter is pushed a notification on the
final decision.

**Actors:** any authenticated user (file/list own); `admin` (queue).

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/complaints` | auth | File a complaint (201) |
| GET | `/api/v1/me/complaints` | auth | List complaints the caller filed |
| GET | `/api/v1/admin/complaints` | admin | Filtered admin queue |
| PATCH | `/api/v1/admin/complaints/:id` | admin | Set status + notes |

`ComplaintsController` uses a prefix-less `@Controller()` so both `complaints` and `me/complaints`
hang off the global prefix directly.

**Request / Response contracts:**

`CreateComplaintDto` (`complaints/complaints.controller.ts:30-63`):

| Field | Type | Rules |
|---|---|---|
| `againstUserId` | uuid | `@IsUUID() @IsOptional()` |
| `tripId` | uuid | `@IsUUID() @IsOptional()` |
| `bookingId` | uuid | `@IsUUID() @IsOptional()` |
| `category` | string | `@IsString() @IsIn(['safety','rude_behavior','no_show','payment','vehicle_condition','other'])` — required |
| `body` | string | `@IsString() @IsNotEmpty() @MaxLength(2000)` — required |

Admin queue query (raw `@Query() Record<string,string>` — **no DTO, no validation**):

| Param | Type | Notes |
|---|---|---|
| `status` | string | Exact match on `c.status` |
| `category` | string | Exact match |
| `from` | ISO date string | `createdAt >= new Date(from)` |
| `to` | ISO date string | `createdAt <= new Date(to)` |
| `cursor` | complaint UUID | `createdAt < (SELECT "createdAt" FROM complaints WHERE id = :cursor)` |
| `limit` | number | `parseInt(...,10)`, default 50, **no cap** |

`AdminUpdateComplaintBodyDto` (`admin-complaints.controller.ts:25-34`):

| Field | Type | Rules |
|---|---|---|
| `status` | string | `@IsString() @IsIn(['in_review','resolved','rejected'])` — required. Note `'open'` is **not** settable |
| `adminNotes` | string | `@IsOptional() @IsString() @MaxLength(2000)` |

Responses: create/patch return the `ComplaintEntity`; `listMine` returns `ComplaintEntity[]` ordered
`createdAt DESC`; admin list returns `{ complaints: ComplaintEntity[], total: number }`.

**Business rules & validation:**

1. **At least one target required:** `!againstUserId && !tripId && !bookingId` ⇒
   `400 At least one of againstUserId, tripId, or bookingId is required`. This is enforced in the
   service, not by a class-level validator.
2. New complaints are always created with `status = 'open'`.
3. There is **no** authorisation check that `tripId`/`bookingId`/`againstUserId` relate to the reporter.
   Any authenticated user can file a complaint against any user or trip.
4. Admin update 404s with `Complaint not found`.
5. `adminNotes` is written **only if truthy** — you cannot clear notes by sending `""`.
6. When the new status is `resolved` or `rejected` (`isDecision`), `resolvedByAdminId` and `resolvedAt`
   are stamped. Setting `in_review` does not stamp them.
7. The reporter push fires only when `isDecision && prevStatus !== newStatus` — i.e. re-resolving an
   already-resolved complaint updates the row but sends no second push.
8. The push is wrapped in `try {} catch {}` with the explicit comment that a notification failure must
   not roll back the status update.
9. `total` in the admin listing comes from `getManyAndCount()`, so with cursor pagination it counts the
   **filtered remainder**, not the whole queue — a subtle reporting quirk.

**Data model:** `complaints` (§4.1).

**State machine (complaint status):**

```
                    admin PATCH status=in_review
   open ─────────────────────────────────────────► in_review
     │                                                  │
     ├──── admin PATCH status=resolved ────────────────►│──► resolved  (stamps resolvedBy/At, pushes reporter)
     └──── admin PATCH status=rejected ────────────────►│──► rejected  (stamps resolvedBy/At, pushes reporter)
```
Transitions are unguarded: any of the three settable statuses can be applied from any current status,
including moving a `resolved` complaint back to `in_review`. `open` can never be re-set through the API.

**Side effects:** push to the reporter on a *changed* final decision:

| status | title | body | type |
|---|---|---|---|
| `resolved` | `Complaint Resolved` | `Your complaint has been reviewed and resolved.` | `complaint_resolved` |
| `rejected` | `Complaint Update` | `Your complaint could not be actioned at this time.` | `complaint_rejected` |

`data: { screen: 'complaints', complaintId }`.

Note `NotificationsService.notifyComplaintStatusChanged` exists with identical copy but is **not**
called by `ComplaintsService` — the service inlines `sendPush` instead. Duplicate/unused helper.
`verify: src/modules/notifications/notifications.service.ts:937`.

**External services:** FCM.

**Background jobs:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| No target field | 400 | `At least one of againstUserId, tripId, or bookingId is required` |
| Bad category / body too long | 400 | class-validator messages |
| Complaint not found | 404 | `Complaint not found` |
| Malformed complaint UUID | 400 | ParseUUIDPipe message |

**Notes for reimplementation:** Validate the admin query with a DTO and cap `limit`. Add
assignment/ownership, SLA timers and an `open → in_review` guard if the queue needs real workflow.
The service is `exports`-ed by `ComplaintsModule` and consumed by `AdminModule` — that's how the admin
controller reaches it without duplicating the repository.

---

## F-18: Refund request queue

**What it does:** Passengers file a refund request; the backend records it and returns a pre-filled
WhatsApp deep link. The actual refund is handled off-platform over WhatsApp; the admin queue only
tracks the record.

**Actors:** authenticated user (file); `admin` (queue).

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/refund-requests` | auth | File a refund request (201) |
| GET | `/api/v1/admin/refund-requests` | admin | Queue listing |
| PATCH | `/api/v1/admin/refund-requests/:id` | admin | Set status + notes |

**Request / Response contracts:**

`CreateRefundRequestBodyDto` (`refunds/refunds.controller.ts:27-45`):

| Field | Type | Rules |
|---|---|---|
| `bookingId` | uuid | `@IsUUID() @IsOptional()` |
| `amount` | string | `@IsOptional() @IsDecimal()` — a **string**, not a number |
| `currency` | string | `@IsOptional() @IsIn(['JOD','USD','EUR'])`; default `'JOD'` |
| `reason` | string | `@IsString() @IsNotEmpty() @MaxLength(1000)` — required |

Create response: `{ refundRequest: RefundRequestEntity, whatsappDeepLink: string }`.

Admin queue query (raw, unvalidated): `status` (string), `limit` (default 50, uncapped),
`offset` (default 0).
Response: `{ refundRequests: RefundRequestEntity[], total: number }`, ordered `createdAt DESC`.

`AdminUpdateRefundBodyDto` (`admin-refunds.controller.ts:24-33`):

| Field | Type | Rules |
|---|---|---|
| `status` | string | `@IsIn(['contacted','resolved','rejected'])` — required. `'open'` not settable |
| `adminNotes` | string | `@IsOptional() @IsString() @MaxLength(2000)` |

**Business rules & validation:**

1. Creation always sets `status='open'` and `whatsappContactedAt = now()` — "contacted" is assumed at
   link-generation time, before the user actually opens WhatsApp.
2. The deep link is `https://wa.me/{SUPPORT_WHATSAPP_E164 without '+'}?text={urlencoded prefill}`.
   The prefill is the newline-joined, falsy-filtered list:
   - `Hi, I would like to request a refund.`
   - `Booking: {last 8 chars of bookingId}` or `No booking ref`
   - `Amount: {amount} {currency}` (omitted when `amount` is null)
   - `Reason: {reason}`
   - `Ref: {last 6 chars of the user's UUID}`
3. There is **no** validation that `bookingId` belongs to the caller, and no duplicate-request guard.
4. Admin update 404s with `Refund request not found`.
5. `adminNotes` written only if truthy.
6. `resolvedByAdminId` / `resolvedAt` are stamped only for `resolved` and `rejected`; not for `contacted`.
7. **No notification is sent** on any refund status change — unlike complaints. Asymmetry.
8. **No money moves.** `RefundsService` touches only the `refund_requests` table; it has no wallet or
   payment dependency at all.

**Data model:** `refund_requests` (§4.2).

**State machine (refund status):**

```
   open ──► contacted ──┐
     │                  ├──► resolved
     └──────────────────┴──► rejected
```
Unguarded — any of the three settable statuses from any state; `open` never re-settable.

**Side effects:** none beyond the row. No push, no wallet transaction, no payment status change.

**External services:** WhatsApp (only as a generated `wa.me` URL — no API call is made).

**Background jobs:** none.

**Errors:** 404 `Refund request not found`; 400 on DTO violations / malformed UUID.

**Notes for reimplementation:** If refunds should actually move money, this module must be rewritten
against the wallet/payments ledger. Today it is a CRM ticket table with a WhatsApp link.

---

## F-19: Driver fines (manual penalties)

**What it does:** An admin issues a monetary penalty against a driver. The fine is stored as a
`pending_charges` row of kind `driver_no_show` and is collected from the driver's wallet immediately
if the balance allows, otherwise carried forward. Fines can be waived.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/fines` | admin | Paginated fine list |
| POST | `/api/v1/admin/fines` | admin | Issue a fine (201) |
| PATCH | `/api/v1/admin/fines/:id/waive` | admin | Waive a pending fine |

**Request / Response contracts:**

`CreateFineDto` (`admin-fines.controller.ts:34-54`):

| Field | Type | Rules |
|---|---|---|
| `driverId` | uuid | `@IsUUID()` — required |
| `amount` | number | `@Type(()=>Number) @IsNumber() @Min(0.01)` — required |
| `reason` | string | `@IsString() @MaxLength(2000)` — required |
| `tripId` | uuid | `@IsUUID() @IsOptional()` |
| `bookingId` | uuid | `@IsUUID() @IsOptional()` |

`ListFinesQueryDto`:

| Param | Type | Rules |
|---|---|---|
| `status` | enum | `@IsEnum(PendingChargeStatus)` → `pending`, `applied`, `waived` |
| `driverId` | uuid | `@IsUUID() @IsOptional()` |
| `from` / `to` | string | Free string, parsed via `new Date(...)` — **not** `@IsDateString` |
| `page` / `limit` | number | `@IsNumber() @IsOptional()`; no `@Min`; limit capped server-side at 100, default 20, page default 1 |

List response:

```
{ data: [ PendingChargeEntity & { driver: { id, name|null, phone|null } } ],
  meta: { page, limit, total, totalPages } }
```

Create / waive responses: the `PendingChargeEntity`.

**Business rules & validation:**

1. Service-level re-validation: non-finite or `<= 0` amount ⇒ `400 amount must be a positive number`;
   blank/whitespace reason ⇒ `400 reason is required`.
2. `404 Driver not found`; `400 Target user is not a driver` when `role !== 'driver'`.
3. The charge is created via `PendingChargesService.record({ userId, kind: DRIVER_NO_SHOW, amount,
   bookingId, tripId })`, which:
   - inserts with `status='pending'`, `amount = amount.toFixed(2)`;
   - **immediately attempts wallet collection** from the DRIVER wallet inside a transaction with a
     `pessimistic_write` lock; creates the wallet account with balance `0.00` if none exists;
   - on success sets `status='applied'` and `walletTransactionId`;
   - on insufficient balance returns `null` without an exception, leaving `status='pending'` to be
     swept at the driver's next booking confirmation;
   - any thrown error is caught and warn-logged (`… will carry forward`).
4. After `record`, the fine service sets `reason = reason.trim()` and `createdByAdminId = adminId`
   and saves again — **so the reason and admin id are written after the wallet deduction already
   happened**. Ordering matters if you reimplement transactionally.
5. Notification to the driver is fire-and-forget: `type='driver_fine_issued'`, title `تم إصدار غرامة`,
   body `تم إصدار غرامة بقيمة {amount.toFixed(2)}. السبب: {reason}`, `data={fineId, amount}`.
6. Listing is scoped to `kind = 'driver_no_show'` only, ordered `createdAt DESC`, with the `user`
   relation joined and flattened into a `driver` object.
7. `waive`: `404 Fine not found`; `400 Charge is not a driver fine` if the kind differs; then
   delegates to `PendingChargesService.waive`, which rejects non-`pending` charges with
   `400 Charge is already {status} and cannot be waived` — **so an already-collected (`applied`) fine
   cannot be waived or refunded.**
8. `waive` sets `status='waived'`, `waivedByAdminId`, `waivedAt`.

**Data model:** `pending_charges` (§4.8); `wallet_accounts`, `wallet_transactions` indirectly.

**State machine (pending charge):**

```
                     wallet has funds
 (create) ──► pending ────────────────► applied      [terminal]
                │  ▲
                │  └── later sweep at booking confirmation ──► applied
                └── PATCH /waive ──► waived                    [terminal]
```
`applied` and `waived` are terminal; only `pending` can be waived.

**Side effects:** wallet debit (when funded), `wallet_transactions` row, driver notification.
No security-event row is written for issuing or waiving a fine — only `createdByAdminId` /
`waivedByAdminId` on the row itself.

**External services:** FCM.

**Background jobs:** none dedicated. Collection of carried-forward charges happens inline at booking
confirmation (`PendingChargesService.collectOutstanding`) and on the user-triggered
`POST /api/v1/me/pending-charges/collect`.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| Amount ≤ 0 / non-finite | 400 | `amount must be a positive number` |
| Blank reason | 400 | `reason is required` |
| Driver missing | 404 | `Driver not found` |
| Target not a driver | 400 | `Target user is not a driver` |
| Fine missing | 404 | `Fine not found` |
| Wrong kind | 400 | `Charge is not a driver fine` |
| Already applied/waived | 400 | `Charge is already {status} and cannot be waived` |

**Notes for reimplementation:** Reusing `kind='driver_no_show'` for arbitrary manual fines means the
no-show analytics and the manual-fine queue share a bucket. Add a distinct `admin_fine` kind.

---

## F-20: Pending charge waiver (generic)

**What it does:** Waives any single outstanding penalty charge (passenger cancellation, no-show,
driver trip fee), not just driver fines.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/admin/pending-charges/:id/waive` | admin | Waive one pending charge |

Declared on the prefix-less `PendingChargesController` (`@Controller()`), which also carries
`@UseGuards(JwtAuthGuard, RolesGuard)`.

**Request / Response contracts:** no body; `:id` is **not** UUID-piped. Returns the saved
`PendingChargeEntity`.

**Business rules & validation:** identical to F-19 rule 7/8 — `404 Pending charge not found`;
`400 Charge is already {status} and cannot be waived` for non-`pending`; sets `status='waived'`,
`waivedByAdminId = <admin id>`, `waivedAt = now`.

**Data model / state machine / side effects:** see F-19. No notification is sent for a generic waiver.

**Errors:** 404 `Pending charge not found`; 400 `Charge is already {status} and cannot be waived`.

**Notes for reimplementation:** The dashboard calls `GET /admin/pending-charges` to populate the page
this action belongs to; that listing endpoint does not exist (§2.4). Implement it.

---

## F-21: Driver no-show reports

**What it does:** Aggregates per-booking "the driver never showed up" reports into one row per trip so
an admin can decide whether to issue a fine (F-19).

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/no-show-reports` | admin | Aggregated report list |
| GET | `/api/v1/admin/no-show-reports/:tripId` | admin | Per-booking detail for one trip |

**Request / Response contracts:**

`ListNoShowReportsQueryDto`:

| Param | Type | Rules |
|---|---|---|
| `page` / `limit` | number | `@Type(()=>Number) @IsNumber() @IsOptional()`; clamped to `page ≥ 1`, `1 ≤ limit ≤ 100`, default 20 |
| `majorityOnly` | string | `@IsBooleanString()` — the **string** `'true'`/`'false'`; the controller compares `=== 'true'` |
| `unfinedOnly` | string | `@IsBooleanString()` — same |

`ReportRow` (list `data[]`):

| Field | Type | Meaning |
|---|---|---|
| `tripId` | string | |
| `driverId` / `driverName` / `driverPhone` | string / string\|null | |
| `fromName` / `toName` | string | |
| `departureTime` | ISO string | |
| `tripStatus` | string | Raw `TripStatus` value |
| `confirmedPassengers` | number | Bookings with status in `{confirmed, in_progress, completed, no_show}` |
| `reportedAbsenceCount` | number | Bookings with `passengerReportedDriverAbsentAt != null` |
| `confirmedPresenceCount` | number | Bookings with `passengerPresenceConfirmedAt != null` |
| `majorityReached` | boolean | `reporters > 0 && reporters * 2 > confirmedPassengers` — strict majority |
| `earliestReportAt` / `latestReportAt` | ISO string \| null | min / max of report timestamps |
| `reporterBookingIds` | string[] | |
| `fineIssued` | boolean | A `pending_charges` row of kind `driver_no_show` exists for the trip |
| `fineId` | string \| null | |

Detail response: `{ summary: ReportRow, bookings: [{ bookingId, passengerId, passengerName,
passengerPhone, status, reportedAbsentAt, confirmedPresenceAt }] }` — **all** bookings on the trip,
not only the reporters.

**Business rules & validation:**

1. The candidate set is `SELECT tripId, MIN(passengerReportedDriverAbsentAt) FROM bookings
   WHERE passengerReportedDriverAbsentAt IS NOT NULL GROUP BY tripId
   ORDER BY MIN(passengerReportedDriverAbsentAt) DESC`. **The whole result set is loaded into memory**
   and sliced with `Array.slice((page-1)*limit, page*limit)` — pagination is application-side.
   `verify: src/modules/admin/admin-no-show.service.ts:68-78`.
2. `meta.total` is the number of trips **before** the `majorityOnly` / `unfinedOnly` filters, while
   `data` is filtered **after** slicing — so `total` overstates and a page can come back shorter than
   `limit`. Known inconsistency.
3. Trips whose row cannot be loaded are dropped (`null` filter).
4. Detail: `404 Trip not found` if the trip does not exist; `404 No reports found for this trip` if no
   booking on it carries an absence report.
5. `detail()` is very inefficient: it calls `this.list({page:1,limit:1})` (result **discarded** — dead
   line at `admin-no-show.service.ts:185`) and then `this.list({page:1,limit:9999})` to find the one
   summary row.
6. Nothing here issues a fine — the admin reads this, then calls `POST /admin/fines` (F-19).

**Data model:** reads `bookings.passengerReportedDriverAbsentAt`, `bookings.passengerPresenceConfirmedAt`,
`bookings.status`, `trips`, `users`, `pending_charges`.

`BookingStatus` values referenced: `pending`, `confirmed`, `in_progress`, `completed`, `no_show`, `cancelled`.

**State machine:** none — this is a read model.

**Side effects:** none. **External services:** none. **Background jobs:** none.

**Errors:** 404 `Trip not found`; 404 `No reports found for this trip`; 400 on a malformed `:tripId`
(ParseUUIDPipe) or a non-`'true'`/`'false'` boolean string.

**Notes for reimplementation:** Push the aggregation into SQL (`GROUP BY` with
`FILTER (WHERE …)` counts and a `LEFT JOIN LATERAL` for the fine), paginate in the database, and make
`total` reflect the applied filters. Delete the discarded `list()` call.

---

## F-22: Admin alerts and dashboard web push

**What it does:** Fans out operational alerts to every active admin — as an in-app notification row,
a live WebSocket event, and a **web-only** FCM push aimed at the browser dashboard. Each admin can
mute individual alert types.

**Actors:** `admin` (recipients). Triggers are system events raised by other modules.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/notifications/web-token` | auth | Register/refresh a dashboard FCM web token (200) |
| DELETE | `/api/v1/notifications/web-token` | auth | Deactivate a web token (200) |
| ~~GET~~ | ~~`/api/v1/admin/alert-preferences`~~ | — | **Does not exist** — dead controller only |
| ~~PATCH~~ | ~~`/api/v1/admin/alert-preferences`~~ | — | **Does not exist** — dead controller only |

Both web-token routes are throttled at 30 requests / 60 s.

**Request / Response contracts:**

`WebTokenDto` (`notifications/dto/web-token.dto.ts`):

| Field | Type | Rules |
|---|---|---|
| `token` | string | `@IsString() @IsNotEmpty() @MaxLength(512)` — required |
| `userAgent` | string | `@IsOptional() @IsString() @MaxLength(255)` |

Both return `{ ok: true }`. `DELETE` takes the token **in the body**.

The (unreachable) preference DTO, `UpdateAlertPreferenceDto` (`dto/alert-preferences.dto.ts`):
`{ alertType: AdminAlertType (@IsEnum), enabled: boolean (@IsBoolean) }`.
Preference read shape: `{ preferences: [{ alertType, enabled }] }`.

**Business rules & validation:**

1. `registerWebToken` is an upsert **by token, not by user**: an existing row with the same token is
   re-pointed to the calling `userId`, forced to `platform='web'`, `isActive=true`, `lastSeenAt=now`,
   and its `userAgent` updated (falling back to the previous value). Otherwise a new row is inserted.
2. `deregisterWebToken` is a scoped soft delete: `UPDATE device_tokens SET isActive=false
   WHERE userId=? AND token=? AND platform='web'`. It never 404s.
3. `AdminAlertsService.getPreferences(userId)` returns one entry for **each** of the three
   `ADMIN_ALERT_TYPES` in fixed order — `driver_registration`, `fee_payment`, `trip_emergency` —
   defaulting `enabled: true` when no row exists (opt-out model).
4. `setPreference` upserts on `(userId, alertType)`.
5. `resolveRecipients(alertType)` = all users with `role='admin' AND isActive=true`, minus those with
   an `admin_alert_preference` row for that type with `enabled=false`. Banned admins are **not**
   excluded (only `isActive` is checked).
6. `dispatch()` runs recipients in parallel (`Promise.all`) and for each one:
   - inserts a `notifications` row (`type`, `title`, `body`, `data`);
   - emits `notificationsGateway.emitToUser(adminId, 'newNotification', <notification>)`;
   - calls `notificationsService.sendPush(adminId, { …, targetPlatforms: ['web'] })`.
7. `targetPlatforms: ['web']` filters the user's active `device_tokens` down to `platform === 'web'`,
   and adds a `webpush` block to the FCM message with `fcmOptions.link = payload.data.link` (when the
   `link` is a string) plus a visible `notification: {title, body}`. Mobile tokens never receive
   admin alerts.
8. If FCM is not initialised or the admin has no active web token, `sendPush` returns
   `{successCount:0, failureCount:0}` and the alert is still stored in-app and emitted over the socket.
9. A structured log line is emitted per dispatch:
   `{"event":"admin.alert.dispatch","alertType":…,"recipientCount":…,"delivered":…,"failed":…}`.

**Alert catalogue:**

| `AdminAlertType` | Trigger | Notification `type` | Title | Body | `data` |
|---|---|---|---|---|---|
| `driver_registration` | `AuthService` after a driver signs up (`auth.service.ts:205`, `:343`). No-op unless `driver.role === 'driver'` | `admin_driver_registration` | `New driver registration` | `{name\|phone\|'New driver'} registered as a driver.` | `{ link: '/users/{driverId}', driverId }` |
| `fee_payment` | `CliqPollProcessor` on a successful payment (`cliq-poll.processor.ts:191`). No-op unless `paymentType === 'communication_fee'` | `admin_fee_payment` | `Communication fee paid` | `A communication fee payment of {amount} {currency} succeeded.` | `{ link: '/payments', paymentId, amount, currency }` |
| `trip_emergency` | `TripTimeService` emergency endpoint (`trip-time.service.ts:460`) | `admin_trip_emergency` | `Trip emergency alert` | `{reporterName} triggered emergency on trip {fromName} → {toName}[ at {lat}, {lng}]` | `{ link: '/trips/{tripId}', tripId, reporterUserId, latitude, longitude }` |

Coordinates are formatted with `toFixed(5)` and the `at …` clause is omitted when either value is null.

Separately (not part of `AdminAlertsService`), `AuthService.notifyAdminsOfNewUser` sends **every**
active admin an in-app notification `type='new_user_registered'`, title `New user registered`,
body `{displayName} just signed up as a {role}.`, `data={newUserId, role, phoneNumber, email}` —
this one ignores alert preferences entirely.

**Data model:** `admin_alert_preference` (§4.5), `notifications`, `device_tokens` (§4.11).

**State machine:** preference `enabled` toggles true/false; default (no row) = enabled.

**Side effects:** notification rows, socket events, FCM web pushes, log lines.

**External services:** Firebase Cloud Messaging (web push via `webpush` config), Socket.IO
(`/notifications` namespace).

**Background jobs:** the `fee_payment` alert originates from the Cliq polling BullMQ processor.

**Errors:** 400 on DTO violations; 429 when the 30/min token throttle trips.

**Notes for reimplementation:**
- **The preference endpoints are unreachable.** Preferences can be written only by direct DB access,
  even though the dashboard has a UI for them. Implement `GET`/`PATCH /admin/alert-preferences` on a
  registered controller.
- Web-push token registration is not admin-scoped — any authenticated user can register a `web`
  platform token.
- `registerWebToken` re-assigns a token to whoever posts it last. A stolen token could be re-pointed;
  in practice FCM tokens are per-browser-installation, but validate this in a rebuild.

---

## F-23: Notification oversight and broadcast

**What it does:** Lists every notification ever created (for support triage) and lets an admin
broadcast an announcement to all active users or to one role.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/notifications` | admin | Paginated notification list |
| POST | `/api/v1/admin/notifications/broadcast` | admin | Fan-out announcement |

Note: `AdminDashboardController.broadcastNotification` has **no** `@HttpCode`, so it returns **201**.
The dead `AdminController` version sets `@HttpCode(200)`. Swagger documents 200 — actual is 201.

**Request / Response contracts:**

`AdminNotificationsQueryDto extends PaginationDto`: `page`, `limit` (≤100), `type` (free string).

Response `data[]`:

```
{ _id, id,
  userId: {_id,name,email,phoneNumber} | {_id,name:'User not found',email:''} | <raw>,
  type, title, body, channel, isRead, data, expiresAt, createdAt, updatedAt }
```

`BroadcastNotificationDto` (`dto/admin-query.dto.ts:206-216`):

| Field | Type | Rules |
|---|---|---|
| `title` | string | `@IsString()` — required, **no length limit** |
| `body` | string | `@IsString()` — required, **no length limit** |
| `targetRole` | enum | `@IsOptional() @IsEnum(UserRole)` → `passenger`\|`driver`\|`admin` |

Broadcast response: `{ sent: number }`.

**Business rules & validation:**

1. Recipient set: `users WHERE isActive = true`, plus `role = targetRole` when supplied.
   Only `u.id` is selected. **Banned users are included** (only `isActive` is filtered).
2. The loop is **sequential** (`for … await`), one `notifications.create` per user. On a large user
   base this is a long-running synchronous HTTP request with no queue and no batching.
3. Per-user failures are caught, logged (`Failed to send notification to user <id>: …`) and **not**
   counted in `sent`.
4. Each notification: `type='admin_broadcast'`, `title`, `body`,
   `data = { broadcast: true, targetRole: targetRole ?? 'all' }`.
5. A summary line is logged: `Broadcast notification sent to <n> users (target: <role|all>)`.
6. `NotificationsService.create` also dispatches the push, so a broadcast is both in-app and push.
7. The listing filters exactly on `type` (no partial match) and swallows errors → empty page.

**Data model:** inserts `notifications` (one row per recipient); reads `users`.

**State machine:** none. **External services:** FCM.

**Background jobs:** none — this should be one.

**Errors:** 400 on DTO violations.

**Notes for reimplementation:** Move the broadcast to a job queue with batched FCM multicast
(FCM accepts 500 tokens per `sendEachForMulticast`), add title/body length caps, exclude banned users,
and return a job id instead of blocking.

---

## F-24: Chat monitoring

**What it does:** Lets an admin browse chat rooms and read the full message history of any room, for
abuse investigation.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/chat/rooms` | admin | Paginated chat rooms |
| GET | `/api/v1/admin/chat/rooms/:id/messages` | admin | Messages in a room |

**Request / Response contracts:**

`AdminChatQueryDto extends PaginationDto` (`dto/admin-chat-query.dto.ts`): `page`, `limit`,
`tripId` (optional string).
Note a **second** `AdminChatQueryDto` exists in `dto/admin-query.dto.ts:201` with no `tripId` — used
only by the dead controller.

Rooms response `data[]` = the full `ChatRoomEntity` spread, plus the joined `trip`, plus
`passenger: { id, name, email } | null`.

Messages response: `PaginatedResult<MessageEntity>`.

**Business rules & validation:**

1. Rooms ordering: `lastMessageTime DESC NULLS LAST`, then `createdAt DESC`.
2. Rooms `limit` clamp: 1–100, default 20. **Messages `limit` clamp is different: 1–200, default 50.**
3. Passenger names are resolved in one batched query selecting only `id, name, email`; unresolved ids
   yield `passenger: null`.
4. Messages: `404 Chat room not found` if the room does not exist; otherwise
   `findAndCount({ chatRoomId }, order: { createdAt: 'ASC' })` — **ascending**, unlike every other
   admin list.
5. The rooms listing swallows errors → empty page; the messages listing does not.
6. Messages are returned raw — no redaction of phone numbers or attachments.

**Data model:** reads `chat_rooms`, `messages`, `users`.

**State machine / side effects / external services / background jobs:** none.

**Errors:** 404 `Chat room not found`.

**Notes for reimplementation:** Reading private conversations is a high-privilege action; consider
writing a `security_events` row for each admin chat read. Today nothing is logged.

---

## F-25: Reports and analytics

**What it does:** Generates a daily time-series breakdown for revenue, user signups or trip creation
over a date range.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/reports` | admin | Daily breakdown report |

**Request / Response contracts:**

`AdminReportsQueryDto` (`dto/admin-reports-query.dto.ts`) — **all three required**:

| Param | Type | Rules |
|---|---|---|
| `type` | string | `@IsEnum(['revenue','users','trips'])` |
| `startDate` | string | `@IsDateString()` |
| `endDate` | string | `@IsDateString()` |

Response `ReportResponse`:

```
{ type, period: { start: <startDate as sent>, end: <endDate as sent> },
  summary: { total: number, count: number },
  breakdown: [ { date: 'YYYY-MM-DD', amount?: number, count: number } ] }
```

**Business rules & validation:**

1. `end.setHours(23,59,59,999)` — the end date is inclusive of the whole day, in **server local time**,
   not UTC. Timezone-sensitive.
2. `revenue`: groups `wallet_transactions` by `DATE("createdAt")` where
   `type='trip_payment' AND status='posted'`, selecting `SUM(CAST(amount AS DECIMAL))` and `COUNT(*)`.
   `summary.total` = sum of daily amounts; `summary.count` = sum of daily counts. `breakdown[].amount`
   is present.
3. `users`: groups `users` by `DATE("createdAt")` with `COUNT(*)`. `summary.total === summary.count`;
   `breakdown[].amount` is absent.
4. `trips`: identical shape over `trips`.
5. Days with no rows are **omitted** — the series is sparse, not zero-filled.
6. Any error (or an unrecognised `type`, which validation should prevent) returns the `emptyReport`:
   `summary {total:0,count:0}`, `breakdown []`.
7. **There is no CSV/XLSX export and no file download anywhere in this domain.** The dashboard renders
   the JSON. If the product needs exports, it must be built.
8. There is no upper bound on the date range — a multi-year `users` report scans the whole table.

**Data model:** reads `wallet_transactions`, `users`, `trips`.

**State machine / side effects / external services / background jobs:** none.

**Errors:** 400 when `type` is not one of the three, or the dates are not ISO date strings.
Everything else degrades to an empty report.

**Notes for reimplementation:** Cast dates in SQL with an explicit timezone; zero-fill the series;
cap the range; add CSV export if operators need it.

---

## F-26: Platform pricing settings

**What it does:** Reads and updates the per-country pricing row that drives the passenger platform fee
and the driver unlock fee.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/pricing-settings?countryCode=JO` | admin | Read (auto-creates the row) |
| PATCH | `/api/v1/admin/pricing-settings?countryCode=JO` | admin | Partial update |

**Request / Response contracts:**

`countryCode` is a bare `@Query('countryCode')` string with **no validation**; it defaults to `'JO'`
when falsy.

`AdminPatchPricingSettingsDto` (`dto/admin-pricing-settings.dto.ts`) — every field optional:

| Field | Type | Rules |
|---|---|---|
| `feeAmount` | number | `@Type(()=>Number) @IsNumber() @Min(0)` — legacy flat unlock fee |
| `currency` | string | `@IsString() @MaxLength(5)` |
| `isActive` | boolean | `@IsBoolean()` |
| `passengerPlatformPercent` | number | `@IsNumber() @Min(0) @Max(100)` |
| `driverUnlockPercent` | number | `@IsNumber() @Min(0) @Max(100)` |
| `lifetimeFreeTripEnabled` | boolean | `@IsBoolean()` |

Both endpoints return the full `CommunicationFeeEntity`.

**Business rules & validation:**

1. `getPlatformPricingSettings(countryCode)` is a **read-or-create**: a missing row is inserted with
   `feeAmount: 0, currency: 'JOD', isActive: true, passengerPlatformPercent: 0,
   driverUnlockPercent: 0, lifetimeFreeTripEnabled: true`. A `GET` therefore mutates the database.
2. Because `countryCode` is unvalidated and the row is auto-created, a typo like `?countryCode=JOO`
   silently creates a junk row (subject to the `varchar(5)` limit).
3. `PATCH` applies each field only when `!== undefined`; there is no "clear to null" path.
4. Semantics (from the DTO docs and the Swagger summary):
   - `passengerPlatformPercent = 0` ⇒ no in-app wallet platform fee on bookings; the full seat price
     goes to the driver as cash.
   - `driverUnlockPercent` is a percent of `seat price × trip total seats`, charged from the driver's
     wallet to unlock passenger contact data. `0` ⇒ fall back to the legacy flat `feeAmount`.
5. No audit record and no notification on a pricing change. Pricing is a money-affecting global
   setting changed with no trail beyond `updatedAt`.

**Data model:** `communication_fees` (§4.10), unique on `countryCode`.

**State machine:** none.

**Side effects:** row creation on read; silent price change affecting all subsequent bookings.

**External services / background jobs:** none.

**Errors:** 400 on DTO violations. A `countryCode` longer than 5 chars would raise a DB error → 500.

**Notes for reimplementation:** Validate `countryCode` (ISO-3166 alpha-2), make `GET` non-mutating,
and write an audit row (who changed which percent, from what to what) — this is the highest-leverage
untracked change in the admin surface.

---

## F-27: Recurrence rule spawn-now (ops)

**What it does:** Ops-debug endpoint that immediately enqueues the recurrence spawn job, bypassing the
hourly cron.

**Actors:** `admin`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| POST | `/api/v1/admin/recurrence-rules/:id/spawn-now` | admin | Enqueue a spawn job |

The controller re-declares `@UseGuards(JwtAuthGuard, RolesGuard)` on top of the global guards.

**Request / Response contracts:** no body; `:id` is a plain string (no UUID pipe).
Response: `{ success: true, message: 'Spawn job enqueued', ruleId, jobId }` (then wrapped by the
global interceptor → `{success:true,data:{success:true,…}}`).

**Business rules & validation:**

1. `404 Recurrence rule not found` when the rule id does not exist.
2. The rule does **not** need to be active — explicit admin override, documented at
   `admin-recurrence.controller.ts:53`.
3. The BullMQ job is added to the `recurrence-spawn` queue with name `spawn-occurrences`, an **empty
   payload `{}`**, `jobId = 'admin-spawn-now-{ruleId}-{Date.now()}'`, `removeOnComplete: true`,
   `attempts: 1`.
4. Because the payload is empty, the processor spawns for **all** due rules, not just this one. The
   `:id` is used only for the existence check and for the job id / log line. Non-obvious and easy to
   get wrong on a rebuild. `verify: src/modules/admin/admin-recurrence.controller.ts:67-75`.
5. Logs `Admin triggered spawn-now for rule <id>: jobId=<jobId>`.

**Data model:** reads `trip_recurrence_rules`. **Queue:** Bull queue `recurrence-spawn` (Redis).

**State machine / side effects:** enqueues a job; the effects belong to the recurrence domain.

**External services:** Redis (BullMQ).

**Background jobs:** the target job normally runs on an hourly cadence (recurrence module).

**Errors:** 404 `Recurrence rule not found`.

---

## F-28: Support configuration

**What it does:** Serves the platform's WhatsApp support number and a ready-made deep-link base so the
mobile app and dashboard never hardcode it.

**Actors:** anyone — this endpoint is `@Public()`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/support/config` | **public** | WhatsApp support config |

**Request / Response contracts:** no parameters.

```json
{ "whatsappE164": "+962788883007", "whatsappDeepLinkBase": "https://wa.me/962788883007" }
```

**Business rules & validation:**

1. `whatsappE164 = process.env.SUPPORT_WHATSAPP_E164 ?? '+962788883007'`.
2. `whatsappDeepLinkBase = 'https://wa.me/' + e164.replace(/^\+/, '')` — the leading `+` is stripped
   exactly once.
3. Pure function of the environment; no DB access, no caching headers set (the JSDoc calls it
   "cache-friendly" but no `Cache-Control` is emitted).
4. The same fallback number is hardcoded in **three** places: `support.controller.ts:34`,
   `ban.guard.ts:49`, `refunds.service.ts:28`. Centralise it on rebuild.

**Data model / state machine / side effects / external services / background jobs:** none.

**Errors:** none.

---

## F-29: Health checks

**What it does:** Liveness and database-readiness probes for orchestrators and uptime monitors.

**Actors:** anyone — both are `@Public()`.

**API Endpoints:**

| Method | Path | Auth/Role | Purpose |
|---|---|---|---|
| GET | `/api/v1/health` | **public** | Liveness — always reports `app: up` |
| GET | `/api/v1/health/db` | **public** | Readiness — pings PostgreSQL |

Built on `@nestjs/terminus` (`HealthCheckService`, `TypeOrmHealthIndicator`).

**Request / Response contracts:** no parameters. Terminus shape, then wrapped by the global
interceptor:

```json
{ "success": true,
  "data": { "status": "ok", "info": { "postgres": { "status": "up" } },
            "error": {}, "details": { "postgres": { "status": "up" } } } }
```

`/health` returns a static `{ app: { status: 'up' } }` indicator — it does **not** check the DB.

**Business rules & validation:**

1. `/health/db` runs `db.pingCheck('postgres')`; on failure Terminus throws
   `ServiceUnavailableException` ⇒ **503** with `status: 'error'`.
2. `HealthModule` imports `TypeOrmModule.forFeature([])` purely to obtain the default connection.
3. Redis, FCM, S3 and Twilio are **not** probed.

**Data model:** none. **Side effects:** a `SELECT 1` per db probe.

**Errors:** 503 when the database is unreachable.

**Notes for reimplementation:** Note the global prefix — probes are at `/api/v1/health`, not `/health`.
`docker/nginx/nginx.conf` and any k8s manifests must match.

---

## F-30: Structured audit emitter (`AuditService`)

**What it does:** A `@Global()` service that serialises an audit record to the application log as a
single JSON line, with an added timestamp.

**Actors:** internal only — no HTTP surface.

**API Endpoints:** none.

**Request / Response contracts:**

```ts
interface AuditRecord { action: string; userId: string; [key: string]: any }
emit(record: AuditRecord): void   // logs JSON.stringify({...record, timestamp: new Date().toISOString()})
```

**Business rules & validation:**

1. Synchronous, fire-and-forget, no persistence, no queue, no failure mode.
2. `AuditModule` is `@Global()`, so `AuditService` is injectable anywhere without importing the module.
3. Despite the name and the global registration, it is used in exactly **three** places, all in
   `NotificationsService`:

| `action` | Site | Extra fields |
|---|---|---|
| `device.register` | `notifications.service.ts:376` | `platform`, `tokenPrefix` (first ≤8 chars + `…`) |
| `device.deregister` | `notifications.service.ts:456` | `platform`, `tokenPrefix` |
| `notification.city_fanout` | `notifications.service.ts:803` | `tripId`, `originCity`, `recipientUserCount`, `deviceCount`, `successCount`, `failureCount` |

   **No admin action uses it.** Every admin-side audit goes to `security_events`,
   `settlement_audits`, or nowhere.

**Data model:** none — stdout only.

**Notes for reimplementation:** Either persist these records or drop the abstraction. As written it is
a thin wrapper over `Logger.log` with a timestamp the logger already provides.

---

## F-31: Dead code and legacy paths (explicit inventory)

These files are compiled and type-checked but **never executed**. They must not be treated as
requirements for a rebuild — but they must not be mistaken for the live behaviour either.

| Artefact | Lines | Why it is dead | Evidence |
|---|---|---|---|
| `src/modules/admin/admin.controller.ts` | 585 | Not listed in `AdminModule.controllers` — Nest never registers its routes | `admin.module.ts:74-83` lists 8 controllers; `AdminController` is absent |
| `src/modules/admin/admin.service.ts` | 998 | Not listed in `AdminModule.providers`; also Mongoose-based (`@InjectModel`) while `AppModule` never imports `MongooseModule` — it would fail to instantiate | `admin.module.ts:84-90`; `app.module.ts` imports |
| `src/modules/admin/admin.service.spec.ts` | 494 | Tests the dead service against mocked Mongoose models | — |
| `src/modules/admin/seeds/admin.seed.ts` | 164 | Only caller is `AdminService.onModuleInit` (dead). Uses Mongoose + bcrypt(12) and prints the default password to stdout | `admin.service.ts:8, 66` |
| `src/modules/ratings/schemas/rating.schema.ts` | 35 | Mongoose schema superseded by `RatingEntity`; imported only by the dead `AdminService` | — |
| `src/modules/vehicles/schemas/vehicle.schema.ts` | 35 | Same — superseded by `VehicleEntity` | — |
| Most of `src/modules/admin/dto/admin-query.dto.ts` | 240 | Only `ApproveDriverDto`, `VerifyVehicleDto`, `BroadcastNotificationDto`, `DashboardStats` and `ReportResponse` are imported by live code. `AdminUserQueryDto`, `AdminTripQueryDto`, `AdminPaymentQueryDto`, `AdminVehicleQueryDto`, `AdminBookingQueryDto`, `AdminRatingQueryDto`, `AdminNotificationQueryDto`, `AdminChatQueryDto`, `ChangeRoleDto`, `ToggleBanDto`, `ReportQueryDto` are dead duplicates of the per-file DTOs | `admin-dashboard.controller.ts:34-39` |
| `NotificationsService.notifyComplaintStatusChanged` | — | Never called; `ComplaintsService` inlines an equivalent `sendPush` | grep |
| `TripStatus.ACTIVE = 'active'` | — | `@deprecated`; migration 008.06 converted all rows to `published`. Still referenced by `getDashboardStats` and by two admin query DTOs | `shared.enums.ts:8-15` |
| `bookings.seatNumber` | — | Column dropped by migration `008.11`; the admin bookings mapper still emits `seatNumber: null` for legacy clients | `admin-dashboard.service.ts` bookings mapper |
| `security_events.eventType = 'account_unrestricted_admin'` | — | Documented in the entity JSDoc; no code path emits it | grep |
| `PayoutStatus` enum | — | Defined in `shared.enums.ts`; no payout endpoint or table logic in this repo | grep |
| `jwt.config.ts` (`JWT_SECRET`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`) | — | Validated at startup but the auth path uses `JWT_ACCESS_SECRET` and hardcoded TTLs | `auth.service.ts:822-835` |
| `AdminNoShowService.detail` line 185 | 1 | `const list = await this.list({page:1,limit:1});` — result never used | `admin-no-show.service.ts:185` |
| Dashboard-only dead wrappers | — | `getNoShowReportDetail`, `getChatRoomByTripId`, `getChatRooms`, `getChatMessages` in `rideshare-dashboard/src/api/admin.ts` | (front-end, informational) |

**Behavioural differences between the dead `AdminService` and the live `AdminDashboardService`** — do
not port these by accident:

| Aspect | Dead (`AdminService`, Mongo) | Live (`AdminDashboardService`, Postgres) |
|---|---|---|
| Revenue | `SUM(payments.amount)` where `status='approved'` | `SUM(wallet_transactions.amount)` where `type='trip_payment' AND status='posted'` |
| Ban | `toggleBan(userId, isActive)` flipping `users.isActive` | `banUser/unbanUser` writing `bannedAt`/`banReason` with a full cascade |
| Role change | `changeUserRole` exists | **no live equivalent** |
| Rating deletion | `deleteRating` exists | **no live equivalent** |
| Report date validation | throws `BadRequestException` for an invalid range | returns an empty report |
| Driver approval photo check | absent | required |
| Alert preferences | endpoints present | **no live equivalent** |

---

## 6. Audit trail

There is no single audit table. Admin actions are recorded across **four** mechanisms with very
different guarantees.

### 6.1 `security_events` — the primary admin audit table

Append-only (`@CreateDateColumn` only, no `updatedAt`; nothing in `src/` issues an `UPDATE` or
`DELETE` against it). Schema in §4.7.

Event types written anywhere in the codebase:

| `eventType` | Written by | `adminActorId` | `deviceId` | `metadata` |
|---|---|---|---|---|
| `account_banned` | `AdminBanService.banUser` | admin id | — | `{reason, cancelledBookings, cancelledTrips, revokedDevices}` |
| `account_unbanned` | `AdminBanService.unbanUser` | admin id | — | `{}` |
| `account_flag_resolved` | `AdminFlagsService.resolveFlag` | admin id | — | `{flagId, reason}` |
| `account_flag_dismissed` | `AdminFlagsService.dismissFlag` | admin id | — | `{flagId, reason}` |
| `device_revoked_by_admin` | `AdminFlagsService.revokeDevice` | admin id | deviceId | `{reason}` |
| `account_restricted_auto` | `AccountRiskService` | null (system) | — | `{reason, distinctAccountCount, fingerprintHash}` |
| `mock_location_rejected` | `LocationGuardInterceptor` | null | — | coordinates / request context |
| `account_unrestricted_admin` | **nothing** — documented only | — | — | — |

**There is no read endpoint for `security_events`.** No admin controller queries this table.
Investigating an incident requires direct SQL. Adding `GET /admin/security-events` (filterable by
`userId`, `eventType`, date) is a required addition for any real rebuild.

### 6.2 `settlement_audits` — booking settlement trail

Schema in §4.9. Actions: `mark_paid`, `unmark_paid` (driver actions) and `admin_revert` (F-13).
`actorId` is the acting user; `reason` is required in practice for admin reverts.
**Readable** via `GET /api/v1/admin/bookings/:id/settlement-audits`.

### 6.3 Row-level actor stamps (no separate audit row)

| Table | Actor column | Timestamp | Written by |
|---|---|---|---|
| `complaints` | `resolvedByAdminId` | `resolvedAt` | F-17, only on `resolved`/`rejected` |
| `refund_requests` | `resolvedByAdminId` | `resolvedAt` | F-18, only on `resolved`/`rejected` |
| `account_flags` | `resolvedByAdminId` | `resolvedAt` | F-07 |
| `pending_charges` | `createdByAdminId` | `createdAt` | F-19 (fine issuance) |
| `pending_charges` | `waivedByAdminId` | `waivedAt` | F-19 / F-20 |
| `bookings` | `cancelledBy` (`'admin'`, `'admin_ban'`, `'admin_ban_driver'`) | `cancelledAt` | F-06, F-12 — records the *kind* of actor, not *which* admin |
| `wallet_transactions` | `metadata.adminId` (JSONB) | `createdAt` | F-15 — plus `note`, `balanceBefore`, `balanceAfter` |

These stamps are **overwritten** on repeat actions — e.g. re-resolving a complaint replaces the previous
`resolvedByAdminId`/`resolvedAt`. There is no history.

### 6.4 Structured application logs

Two flavours, both stdout-only, both non-durable:

`AuditService.emit` (F-30) — three call sites, none admin-related.

Ad-hoc `logger.log(JSON.stringify({...}))`:

| Event key | Site | Fields |
|---|---|---|
| `admin.ban` | `admin-ban.service.ts:111` | `userId, adminId, cancelledBookings, cancelledTrips, revokedDevices` |
| `admin.unban` | `admin-ban.service.ts:145` | `userId, adminId` |
| `admin.alert.dispatch` | `admin-alerts.service.ts:184` | `alertType, recipientCount, delivered, failed` |
| `trip.emergency` | `trip-time.service.ts:471` (`logger.warn`) | `tripId, userId, latitude, longitude` |

Plus plain-text lines: `Vehicle <id> verification status changed to <bool>`,
`Booking cancelled by admin: <id>`, `Booking <id> settlement reverted by admin <adminId>: <reason>`,
`Broadcast notification sent to <n> users (target: <role|all>)`,
`Admin triggered spawn-now for rule <id>: jobId=<jobId>`.

`LoggingInterceptor` (global) additionally logs every request.

### 6.5 Actions with NO audit trail at all

Enumerated deliberately — these are gaps a rebuild should close:

- User deletion (`DELETE /admin/users/:id`) — no row, no event, no notification.
- Driver approval / rejection — only the notification proves it.
- Vehicle verification / rejection — only the notification proves it.
- Admin booking cancellation — only `cancelledBy='admin'` (no admin id).
- Pricing-settings changes — money-affecting, only `updatedAt`.
- Notification broadcasts — a plain log line, no persisted record of who broadcast what.
- Admin reads of private chat rooms and messages.
- Admin reads of any user's personal data.

### 6.6 Correlation IDs

`security_events`, `settlement_audits` and `pending_charges` each carry a nullable `correlationId`
column (added by migration `008.13`), intended to hold `X-Request-ID`. **No code writes any of these
three columns** — every `correlationId` occurrence outside the entity/migration files is either an
unrelated log-line field in `NotificationsService` (e.g. `correlationId: bookingId` at
`notifications.service.ts:583`) or the Cliq A2A gateway's own `CORRELATION_ID` config
(`a2a-cliq.service.ts:64`). No middleware reads `X-Request-ID` at all. Wire this up in a rebuild if
cross-log tracing matters.

---

## 7. Cross-cutting implementation notes

1. **Pagination is not uniform.** Three shapes coexist:
   - `{data, meta:{page,limit,total,totalPages}}` — the admin dashboard endpoints and fines/no-show;
   - `{flags|complaints|refundRequests, total}` with `limit`/`offset` or `cursor` — flags, complaints, refunds;
   - unbounded arrays — `GET /me/complaints`.
   Pick one for a rebuild.
2. **Error swallowing.** `getPayments`, `getVehicles`, `getTrips`, `getBookings`, `getRatings`,
   `getNotifications`, `getChatRooms`, `generateReport` and all four `getDashboardStats` sub-counters
   catch every exception and return an empty result. Operators see "no data" instead of an error.
   Remove this on rebuild.
3. **Mongo-flavoured response shapes.** `_id` aliases and nested `{_id, name, email}` objects in place
   of foreign keys exist across bookings, payments, ratings, notifications and wallets. They are
   legacy from the Mongoose era and are what the current dashboard parses.
4. **`'User not found'` placeholder.** Every list that joins a user falls back to
   `{_id: <rawId>, name: 'User not found', email: ''}` rather than dropping the row or nulling it.
5. **Guard duplication.** `AdminRecurrenceController`, `VehiclesController`, `RatingsController` and
   `PendingChargesController` re-declare `@UseGuards(JwtAuthGuard, RolesGuard)` on top of the global
   guards. Harmless but redundant.
6. **Two role enums, identical values.** `PgUserRole` and `UserRole` both use `'admin'`, and
   `@Roles('admin')` is also used as a bare string. Any of the three works.
7. **Localisation is inconsistent.** Driver approval, fines, wallet credits and ratings are Arabic;
   vehicle verification, complaints, bans and trip cancellations are English.
8. **No `Retry-After` / rate-limit headers** on the 200/min throttler beyond Nest's defaults.
9. **Scheduled jobs in the repo** (none belong to this domain, listed for completeness):

| Cron | Job | File |
|---|---|---|
| `0 2 * * *` | Notification cleanup | `src/jobs/notification-cleanup.job.ts:19` |
| `*/15 * * * *` | Trip expiration | `src/jobs/trip-expiration.job.ts:14` |
| `*/30 * * * *` | Driver trip-fee reconciliation sweep | `src/modules/driver-trip-fee/driver-trip-fee-reconciliation.job.ts:74` |

   `ScheduleModule.forRoot()` is registered in `app.module.ts` — an in-code comment records that it was
   previously missing, which made every `@Cron` in the repo inert.

---

## 8. Priority gaps for a rebuild

Ordered by risk.

1. **Restricted accounts are unrecoverable** — nothing sets `users.restricted = false` (F-07).
2. **Seven dashboard endpoints return 404** — role change, ban toggle, rating delete, alert
   preferences read/write, user devices list, pending-charges list (§2.4).
3. **No read access to `security_events`** — the primary audit table is write-only (§6.1).
4. **Verified vehicles can be edited without re-verification** (F-09 rule 6).
5. **Pricing changes are untracked** (F-26).
6. **`req.user.sub` is undefined in `RatingsController`** — likely breaks rating creation (F-16 rule 8).
7. **`activeTrips` always reads 0** and the trip status filter offers dead values (F-02, F-11).
8. **Broadcast is a synchronous per-user loop** (F-23).
9. **Ban cascade is not transactional** (F-06 rule 14).
10. **Admin bootstrap has no live path** — the only seeder is dead Mongoose code (F-01).
