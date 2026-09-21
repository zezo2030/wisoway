# Backend Rebuild Spec — 01. Identity & Access

> Source of truth: `rideshare-backend/src` @ branch `009-platform-refinements`.
> Every statement below is grounded in the code paths cited. Where the code is
> ambiguous or looks unintentional, the text says so explicitly and cites
> `file:line` to verify.

---

## 1. Domain overview

Identity & Access owns everything about *who a caller is* and *what they are
allowed to do*:

- **Phone-first authentication.** End users (passengers & drivers) authenticate
  with an E.164 phone number + a 6-digit SMS OTP. There is no email/password
  sign-up path for end users. Passwords exist as a *secondary* credential set at
  registration time and used by the `POST /auth/login` fast path.
- **Admin authentication.** Admins log in with **email + password** through the
  same `POST /auth/login` endpoint (the endpoint branches on which field is
  present).
- **Deferred driver registration.** A driver proves phone ownership first, gets a
  30-minute single-purpose registration JWT, uploads documents with it, and only
  then does a single transactional call create the user row *and* the vehicle
  row together. An abandoned onboarding leaves nothing behind.
- **Device binding.** An optional `device` block on OTP verification produces a
  SHA-256 device fingerprint, creates/refreshes a `user_devices` row, and embeds
  that row's UUID in the JWT (`did` claim). Revoking the device invalidates every
  token carrying that `did`.
- **Account safety.** Automated heuristics (multi-account-from-one-device,
  repeated mock-location) raise `account_flags`, may set `users.restricted`, and
  append immutable `security_events`. Admins can ban (with a cascade), unban,
  resolve/dismiss flags and revoke devices.
- **Authorization.** Three global guards (`JwtAuthGuard` → `BanGuard` →
  `RolesGuard`) plus a global `ThrottlerGuard`, and a global
  `RestrictedAccountInterceptor` that blocks writes for restricted accounts.
- **Uploads.** Identity documents (licence, vehicle licence, insurance, car
  photo, profile photo) are stored on the **local filesystem** and served
  statically from `/uploads`. S3 config exists but is not used.

### Runtime / framework facts a reimplementation must match

| Fact | Value | Source |
|---|---|---|
| Global route prefix | `process.env.API_PREFIX` or `api/v1` | `src/main.ts:49-50` |
| Static file mounts | `/uploads` → `<cwd>/uploads`, `/public` → `<cwd>/public` | `src/main.ts:17-22` |
| Helmet enabled | yes, default options | `src/main.ts:25` |
| CORS | prod: `ALLOWED_ORIGINS` (comma-split) else `['https://yourdomain.com']`; non-prod: reflect all origins. `credentials: true` | `src/main.ts:28-34` |
| Global validation | `whitelist:true, forbidNonWhitelisted:true, transform:true, enableImplicitConversion:true` | `src/main.ts:37-46` |
| Second (redundant) validation pipe | `APP_PIPE` → `common/pipes/validation.pipe.ts`, same flags, throws `400 {message:'Validation failed', error:{code:400,details:[...]}}` | `src/app.module.ts:156-159` |
| Swagger | `GET /api/docs` (NOT prefixed) | `src/main.ts:74` |
| Listen | `HOST` (default `0.0.0.0`), `PORT` (default `3000`) | `src/main.ts:76-78` |
| Global rate limit | one bucket: **200 requests / 60 000 ms** | `src/app.module.ts:77-82` |
| Success envelope | every 2xx body is wrapped: `{ success: true, data: <handler return> }` | `common/interceptors/transform.interceptor.ts` |
| Error envelope | `{ success:false, error:{ code:<httpStatus>, message, details, timestamp, path, method } }` (+ `debug`/`stack` when 500 and `NODE_ENV!=='production'`) | `common/filters/http-exception.filter.ts` |
| Upload URL rewriting | every response has absolute `http(s)://host/uploads/...` / `/public/...` URLs rewritten to the host the client actually used | `common/interceptors/upload-url.interceptor.ts` |
| DB | PostgreSQL + PostGIS + `uuid-ossp`, TypeORM, `synchronize: false` (migrations only) | `src/database/postgres.module.ts` |

**Guard execution order** (`src/app.module.ts:112-131`): `JwtAuthGuard` →
`BanGuard` → `RolesGuard` → `ThrottlerGuard`. Interceptors:
`TransformInterceptor` → `UploadUrlInterceptor` → `LoggingInterceptor` →
`RestrictedAccountInterceptor`.

Because `JwtAuthGuard` is registered globally, **every route is authenticated by
default**; a route is anonymous only if decorated with `@Public()`.

---

## 2. Environment variables read by this domain

| Var | Purpose | Default / example | Read at |
|---|---|---|---|
| `API_PREFIX` | Global route prefix | `api/v1` | `main.ts:49`, `config/app.config.ts` |
| `PORT` | HTTP port | `3000` (but `uploads.service.ts` falls back to **`3003`** when composing URLs) | `main.ts:76`, `uploads.service.ts:16` |
| `HOST` | Bind address | `0.0.0.0` | `main.ts:77` |
| `NODE_ENV` | Env switch (CORS, 500 stack traces) | `development` | `main.ts:30`, `http-exception.filter.ts:31` |
| `ALLOWED_ORIGINS` | Comma-separated CORS allowlist (production only) | `https://a.com,https://b.com` | `main.ts:31` |
| **`JWT_ACCESS_SECRET`** | **Signing secret for access tokens AND driver-registration tokens AND WebSocket auth.** Required. | *(no default — throws at boot)* | `strategies/jwt.strategy.ts:16`, `auth.service.ts:704,717,822`, `guards/ws-auth.guard.ts:29`, `uploads.controller.ts:79` |
| `JWT_REFRESH_SECRET` | Signing secret for refresh tokens. Required. | *(no default in the code path that matters)* | `auth.service.ts:823`, `strategies/jwt-refresh.strategy.ts:20` |
| `JWT_SECRET` | **DEAD.** Validated by `config/jwt.config.ts` under namespace `jwt`, never read by any consumer. | `your-jwt-secret-change-in-production` | `config/jwt.config.ts:22` |
| `JWT_EXPIRES_IN` | **DEAD.** Access TTL is hardcoded `'15m'`. | `15m` | `config/jwt.config.ts:23` vs `auth.service.ts:829` |
| `JWT_REFRESH_EXPIRES_IN` | **DEAD.** Refresh TTL is hardcoded `'7d'`. | `7d` | `config/jwt.config.ts:27` vs `auth.service.ts:833` |
| `OTP_PROVIDER` | `local` (store code in DB + log it, no SMS) or `twilio` (Twilio Verify). Lower-cased; anything ≠ `twilio` ⇒ `local`. | `local` | `config/twilio.config.ts:40`, `auth.service.ts:914-922` |
| `TWILIO_ACCOUNT_SID` | Twilio account SID; must start with `AC` to be used | `ACxxxxxxxx…` | `auth.service.ts:925` |
| `TWILIO_AUTH_TOKEN` | Twilio auth token (fallback auth mode) | — | `auth.service.ts:928` |
| `TWILIO_API_KEY_SID` | Twilio API key SID; must start with `SK` | `SKxxxxxxxx…` | `auth.service.ts:931` |
| `TWILIO_API_KEY_SECRET` | Twilio API key secret | — | `auth.service.ts:934` |
| `TWILIO_VERIFY_SERVICE_SID` | Twilio Verify service SID | `VAxxxxxxxx…` | `auth.service.ts:99-101` |
| `TWILIO_PHONE_NUMBER` | Declared in config, **unused by this domain** (Programmable-SMS fallback that is never invoked) | `+1234567890` | `config/twilio.config.ts:36` |
| `MULTI_ACCOUNT_DEVICE_THRESHOLD` | Distinct accounts per device fingerprint within 24 h that triggers auto-restrict | `3` | `account-risk.service.ts:43` |
| `SUPPORT_WHATSAPP_E164` | Support number returned in the `ACCOUNT_BANNED` error body | `+962788883007` | `common/guards/ban.guard.ts:49` |
| `SERVER_BASE_URL` | Origin baked into freshly uploaded file URLs | empty ⇒ `http://localhost:<PORT|3003>` | `uploads.service.ts:14-16` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_S3_BUCKET` / `AWS_REGION` | **DEAD.** `config/s3.config.ts` is loaded and validated, but `UploadsService` is local-filesystem only. | `rideshare-uploads`, `me-south-1` | `config/s3.config.ts` |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` / `GOOGLE_CALLBACK_URL` | Google OAuth strategy config — strategy class exists but is **not registered as a provider**; endpoints return 410. | `dummy_client_id`, … | `strategies/google.strategy.ts:14-22` |
| `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` / `FACEBOOK_CALLBACK_URL` | Same as above for Facebook. | `dummy_facebook_app_id`, … | `strategies/facebook.strategy.ts:14-24` |
| `OTP_DEV_BYPASS` | **DEAD.** Parsed into `platform` config, read by nothing. | `false` | `config/configuration.ts:63,121` |
| `MIN_APP_VERSION` | **DEAD in this domain.** Parsed into `platform` config; no guard/interceptor enforces it. | undefined | `config/configuration.ts:89` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME` / `ADMIN_PHONE` | Bootstrap admin account for the standalone `seed-admin.ts` script | `admin@rideshare.com` / `Admin@123456` / `System Admin` / `+201000000000` | `seed-admin.ts:13-18` |
| `POSTGRES_HOST` / `_PORT` / `_USER` / `_PASSWORD` / `_DB` / `_SSL` | Database connection | `localhost` / `5432` / `postgres` / `postgres` / `rideshare` / `false` | `database/postgres.module.ts:47-56` |

> ⚠ **Gotcha:** `.env.example` documents `JWT_SECRET` but the code requires
> `JWT_ACCESS_SECRET`. The real `.env` in the repo defines `JWT_ACCESS_SECRET`.
> A rebuild should collapse these to one name.

---

## 3. Entities (complete column definitions)

### 3.1 `users` — `src/database/entities/user.entity.ts`

Enum `users_role_enum` = `('passenger','driver','admin')` (`PgUserRole`).

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `email` | varchar | yes | — | **UNIQUE**, index `users_email_idx` |
| `phoneNumber` | varchar | yes | — | **UNIQUE**, index `users_phone_idx` |
| `name` | varchar(120) | no | — | |
| `passwordHash` | varchar | yes | — | TypeORM `select:false` — never returned unless explicitly `addSelect`ed |
| `role` | `users_role_enum` | no | `'passenger'` | index `users_role_idx` |
| `isActive` | boolean | no | `true` | `false` ⇒ 401 on every authenticated request |
| `city` | varchar(64) | yes | — | partial index `idx_users_lower_city ON users(LOWER(city)) WHERE "isActive"=true` |
| `fcmToken` | varchar | yes | — | `select:false`. Legacy single-token push field |
| `gender` | varchar | yes | — | Free varchar in PG; DTOs constrain to `'male'`/`'female'` |
| `photoUrl` | text | yes | — | Required before a driver can be approved |
| `provider` | varchar | no | `'email'` | observed values: `email`, `phone`, `google`, `facebook` |
| `providerId` | varchar | yes | — | social provider user id |
| `rating` | decimal(3,2) | no | `0` | |
| `totalRatings` | int | no | `0` | |
| `isPhoneVerified` | boolean | no | `false` | |
| `isEmailVerified` | boolean | no | `false` | |
| `isDriverApproved` | boolean | no | `false` | admin gate for drivers |
| `refreshToken` | varchar | yes | — | `select:false`. Stores a **bcrypt hash** of the last issued refresh token. **Never verified anywhere.** |
| `walletBalance` | decimal(10,2) | no | `0` | (finance domain) |
| `walletCurrency` | varchar(5) | no | `'JOD'` | migration default was `'EGP'`, later set to JOD |
| `hasUsedLifetimeFreeTrip` | boolean | no | `false` | (finance domain) |
| `passwordChangedAt` | timestamp (no tz) | yes | `null` | access tokens issued before this instant are rejected |
| `bannedAt` | timestamptz | yes | `null` | non-null ⇒ banned |
| `banReason` | text | yes | `null` | shown to the banned user |
| `restricted` | boolean | no | `false` | write operations blocked |
| `hidePhoneNumber` | boolean | no | `false` | route calls through Twilio proxy DID |
| `pendingPhoneLink` | boolean | no | `false` | legacy social account without a phone |
| `lastSocialLoginAt` | timestamptz | yes | `null` | **never written by any code path** |
| `createdAt` | timestamptz | no | `now()` | |
| `updatedAt` | timestamptz | no | `now()` | |

Relations: `1—N device_tokens`, `1—N wallet_accounts`.

Migration backfill (`1745700000000`): `pendingPhoneLink = true` where
`provider NOT IN ('email','phone') AND (phoneNumber IS NULL OR phoneNumber='')`.

### 3.2 `otp_codes` — `src/database/entities/otp-code.entity.ts`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `phoneNumber` | varchar | no | — | composite index `idx_otp_codes_phone_code (phoneNumber, code)` |
| `code` | varchar(6) | no | — | plaintext 6 digits |
| `expiresAt` | timestamp | no | — | index `idx_otp_codes_expires_at` |
| `isUsed` | boolean | no | `false` | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

Only populated when `OTP_PROVIDER=local`.

### 3.3 `pending_registrations` — **DEAD TABLE**

Entity registered with TypeORM (`postgres.module.ts:78`) and created by
migration `1738900000000`, but **no service, controller or repository ever
touches it**. Superseded by the deferred-driver-registration JWT flow (F-03).

| Column | Type | Null | Default |
|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` |
| `phoneNumber` | varchar UNIQUE | no | — |
| `email` | varchar UNIQUE | yes | — |
| `passwordHash` | varchar (`select:false`) | no | — |
| `name` | varchar(100) | no | — |
| `gender` | `pending_registration_gender_enum` (`'male','female'`) | yes | — |
| `role` | `users_role_enum` | no | `'passenger'` |
| `expiresAt` | timestamptz | no | — |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` |

### 3.4 `password_reset_sessions` — `password-reset-session.entity.ts`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK; **doubles as the client-facing `resetToken`** |
| `phoneNumber` | varchar | no | — | index `idx_password_reset_phone` |
| `otpCode` | varchar (`select:false`) | no | — | **holds `randomUUID()`, not the OTP.** Vestigial; never compared against anything (`auth.service.ts:583`) |
| `isVerified` | boolean | no | `false` | |
| `attemptCount` | int | no | `0` | |
| `isLocked` | boolean | no | `false` | set when `attemptCount >= 5` |
| `createdAt` | timestamp | no | `now()` | |
| `expiresAt` | timestamp | no | — | index `idx_password_reset_expires` |

No FK to `users` (keyed by phone number only).

### 3.5 `user_devices` — `user-device.entity.ts`

Enums: `user_device_status_enum = ('active','revoked')`,
`user_device_platform_enum = ('android','ios')`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK; this UUID is the JWT `did` claim |
| `userId` | uuid | no | — | FK → `users(id)` **ON DELETE CASCADE**; index `user_devices_user_idx` |
| `fingerprintHash` | char(64) | no | — | `SHA256(platform + ':' + deviceId + ':' + installSalt)` hex. Indexes: `user_devices_fingerprint_idx`, `user_devices_fingerprint_created_idx (fingerprintHash, createdAt)` |
| `platform` | `user_device_platform_enum` | no | — | |
| `label` | varchar(120) | yes | `null` | user-set device name |
| `fcmToken` | text | yes | `null` | |
| `status` | `user_device_status_enum` | no | `'active'` | |
| `revokedAt` | timestamptz | yes | `null` | |
| `revokeReason` | text | yes | `null` | e.g. `user_self_revoke`, `admin_revoke`, `account_banned: <reason>` |
| `locale` | varchar(8) | yes | `null` | |
| `lastSeenAt` | timestamptz | yes | `null` | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

> There is **no unique constraint** on `(userId, fingerprintHash)` — uniqueness is
> enforced only by an application-level `findOne` before insert
> (`device-fingerprint.service.ts:78-83`). Concurrent OTP verifications from the
> same device can create duplicate rows.

### 3.6 `device_tokens` — `device-token.entity.ts` (push tokens; distinct from `user_devices`)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `uuid_generate_v4()` | PK |
| `userId` | uuid | no | — | FK → `users(id)` ON DELETE CASCADE; index `device_tokens_user_idx` |
| `token` | varchar(512) | no | — | **UNIQUE** (`device_tokens_unique_token_idx`) |
| `platform` | varchar(20) | no | `'android'` | values used: `android`, `ios`, `web` |
| `userAgent` | varchar(255) | yes | — | added by migration `1746200000000`, used for dashboard web tokens |
| `isActive` | boolean | no | `true` | deregistration sets `false` (soft delete) |
| `lastSeenAt` | timestamptz | yes | — | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | |

### 3.7 `account_flags` — `account-flag.entity.ts`

Enums: `account_flag_severity_enum = ('low','medium','high','critical')`,
`account_flag_disposition_enum = ('open','resolved','dismissed')`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `userId` | uuid | no | — | FK → `users(id)` ON DELETE CASCADE; index `account_flags_user_idx` |
| `reason` | varchar(64) | no | — | known values: `multi_account_device`, `mock_location_repeated`, `manual_review` (documented, never written) |
| `severity` | severity enum | no | `'medium'` | both automated writers use `'high'` |
| `disposition` | disposition enum | no | `'open'` | index `account_flags_disposition_idx` |
| `notes` | text | yes | `null` | |
| `resolvedByAdminId` | uuid | yes | `null` | no FK |
| `resolvedAt` | timestamptz | yes | `null` | |
| `createdAt` / `updatedAt` | timestamptz | no | `now()` | index `account_flags_created_idx` |

### 3.8 `security_events` — `security-event.entity.ts` (append-only)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` | PK |
| `userId` | uuid | yes | `null` | FK → `users(id)` **ON DELETE SET NULL**; index `security_events_user_idx` |
| `eventType` | varchar(64) | no | — | index `security_events_type_idx` |
| `deviceId` | uuid | yes | `null` | deliberately **no FK** |
| `metadata` | jsonb | yes | `null` | |
| `adminActorId` | uuid | yes | `null` | no FK |
| `correlationId` | varchar | yes | `null` | added by migration `1745913000000`; **never populated by any code** |
| `createdAt` | timestamptz | no | `now()` | index `security_events_created_idx` |

`eventType` values actually written:

| Value | Written by |
|---|---|
| `account_restricted_auto` | `account-risk.service.ts:83` |
| `mock_location_rejected` | `common/interceptors/location-guard.interceptor.ts:67` |
| `account_banned` | `admin/admin-ban.service.ts:181` |
| `account_unbanned` | `admin/admin-ban.service.ts:224` |
| `account_flag_resolved` | `admin/admin-flags.service.ts:183` |
| `account_flag_dismissed` | `admin/admin-flags.service.ts:211` |
| `device_revoked_by_admin` | `admin/admin-flags.service.ts:237` |

Documented-but-never-written: `multi_account_flag_created`,
`account_unrestricted_admin` (see the JSDoc in the entity — there is **no
un-restrict endpoint anywhere**; once `users.restricted` is set, only a manual
DB update clears it. Verify: the only write to `restricted` is
`account-risk.service.ts:70`).

### 3.9 Mongoose schemas — **ALL DEAD**

`src/modules/users/schemas/{user,otp-code,pending-registration}.schema.ts` are
Mongoose `@Schema()` classes from the pre-Postgres era. No `MongooseModule` is
imported anywhere in `app.module.ts`. They survive only because three enums are
imported from them by live code:

- `UserRole` (`passenger|driver|admin`) — used by `users.controller.ts:25`
  (aliased), `uploads.controller.ts:32`, `admin-flags.controller.ts:22`
- `AuthProvider` (`email|google|facebook|phone`) — used by the (unregistered)
  Google/Facebook strategies
- `Gender` (`male|female`) — used by the (unused) `SignUpDto`

A rebuild should move these three enums to a shared module and delete the schema
files.

---

# Features

---

## F-01: Phone OTP issuance

**What it does:** Sends a 6-digit one-time code by SMS to a phone number so the
owner can prove they control it. In development mode no SMS is sent — the code
is stored in the database and printed to the application log.

**Actors:** anonymous (public endpoint)

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/send-otp` | none (`@Public`) | Issue an OTP to a phone number |

**Request / Response contracts:**

`POST /auth/send-otp` — body `SendOtpDto` (`dto/send-otp.dto.ts`):

| Field | Type | Rules | Required |
|---|---|---|---|
| `phoneNumber` | string | `@IsString`, `@Matches(/^\+[1-9]\d{1,14}$/)` — E.164. Message: `"Phone number must be in E.164 format (e.g., +201234567890)"` | yes |

Response `200`:

```json
{ "success": true, "data": { "message": "OTP sent successfully", "expiresIn": 300 } }
```

**Business rules & validation:**

1. `phoneNumber` must match the E.164 regex `^\+[1-9]\d{1,14}$` exactly (1–15
   digits after `+`, first digit non-zero). No normalisation, no country
   defaulting — the client must send full E.164.
2. Provider is resolved **once at service construction** from
   `OTP_PROVIDER` (flat env → `twilio.OTP_PROVIDER` namespaced → `process.env` →
   `'local'`), lower-cased; `'twilio'` ⇒ Twilio, anything else ⇒ `'local'`
   (`auth.service.ts:914-922`). Changing the env var requires a restart.
3. **Local mode:** generate `String(Math.floor(100000 + Math.random()*900000))`
   — a uniformly-random integer in `[100000, 999999]`, always 6 digits, using
   `Math.random()` (**not** a CSPRNG). Persist via `UsersService.createOtpCode`,
   log at WARN level `OTP for <phone>: <code> (SMS disabled)`.
4. `createOtpCode` first **deletes all rows** for `{phoneNumber, isUsed:false}`,
   then inserts one row with `expiresAt = now + 5 minutes`
   (`users.service.ts:167-175`). Effect: only one live code per phone; requesting
   a new code invalidates the previous one.
5. **Twilio mode:** requires both a constructed Twilio client and a non-empty
   `TWILIO_VERIFY_SERVICE_SID`, else `400 "Twilio Verify is not configured
   correctly"`. Calls
   `twilio.verify.v2.services(SID).verifications.create({ to, channel:'sms' })`.
   Twilio owns code generation, TTL and resend throttling in this mode — nothing
   is stored locally.
6. `expiresIn: 300` is returned **unconditionally**, in both modes, and is not
   derived from Twilio's actual TTL.
7. There is **no per-phone / per-IP OTP rate limit** beyond the global
   200 req/min throttler. No cooldown between consecutive `send-otp` calls.

**Data model:** `otp_codes` (local mode only). Nothing written in Twilio mode.

**State machine:** an `otp_codes` row is `isUsed=false` → `isUsed=true`
(one-way). Rows are also deleted wholesale by the next `createOtpCode` for the
same phone.

**External services used:**

- **Twilio Verify v2** (`twilio` npm SDK). Client construction
  (`auth.service.ts:924-937`), preferring API-key auth:
  - if `TWILIO_ACCOUNT_SID` starts with `AC` **and** `TWILIO_API_KEY_SID` starts
    with `SK` and `TWILIO_API_KEY_SECRET` is set →
    `new Twilio(apiKeySid, apiKeySecret, { accountSid })`
  - else if `TWILIO_ACCOUNT_SID` starts with `AC` and `TWILIO_AUTH_TOKEN` set →
    `new Twilio(accountSid, authToken)`
  - else **no client is created** and every OTP call fails with 400.
  - The client is only constructed when the provider is `twilio`
    (`auth.service.ts:104`).
- **Failure behaviour:** any Twilio exception is `console.error`-logged and
  rethrown as `400 BadRequestException('Failed to send OTP')` — the underlying
  Twilio error is not surfaced.
- **Dev mode:** `OTP_PROVIDER=local` — no external call at all.

**Background jobs / scheduled tasks:** none.
`UsersService.cleanupExpiredOtpCodes()` exists (`users.service.ts:184`) but
**has no caller and no `@Cron`** — expired local OTP rows are never purged.

**Errors:**

| Condition | HTTP | Body |
|---|---|---|
| bad/missing `phoneNumber` | 400 | validation envelope with the E.164 message |
| Twilio not configured (twilio mode) | 400 | `Twilio Verify is not configured correctly` |
| Twilio API error | 400 | `Failed to send OTP` |
| >200 req/min from one IP | 429 | ThrottlerException |

**Notes for reimplementation:**

- The dev-mode code path writes a **plaintext** OTP to the DB and to the log.
- Use a CSPRNG for the code in any rebuild.
- Add per-phone rate limiting/cooldown; the current code has none.
- Consider deriving `expiresIn` from the actual provider TTL.

---

## F-02: OTP verification — sign-in-or-register with optional device binding

**What it does:** Consumes an OTP to prove phone ownership, then either finishes
setting up an existing password-less account or creates a brand-new
passenger/driver account, optionally binds the calling device, runs the
multi-account risk check, and returns an access/refresh token pair plus the
account's health state.

**Actors:** anonymous (public endpoint)

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/verify-otp` | none (`@Public`) | Verify OTP; create-or-complete account; issue tokens |

**Request / Response contracts:**

`POST /auth/verify-otp` — body `VerifyOtpDto` (`dto/verify-otp.dto.ts`):

| Field | Type | Rules | Required |
|---|---|---|---|
| `phoneNumber` | string | trimmed; `@IsNotEmpty("Phone number is required")`; `@Matches(/^\+[1-9]\d{1,14}$/)` | yes |
| `code` | string | trimmed; `@IsNotEmpty("OTP code is required")`; `@Matches(/^\d{6}$/, "OTP code must be exactly 6 digits")` | yes |
| `name` | string | `@MinLength(1)`, `@MaxLength(120)`, trimmed | no |
| `gender` | string | `@IsIn(['male','female'])` | no |
| `role` | string | `@IsIn(['passenger','driver'])` | no |
| `password` | string | `@MinLength(8)`, `@MaxLength(100)`, `@Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/)` — msg `"Password must be at least 8 characters with at least one letter and one number"` | conditionally (see rules) |
| `device` | object `VerifyOtpDeviceDto` | `@ValidateNested`, `@Type` | no |

`VerifyOtpDeviceDto`:

| Field | Type | Rules | Required |
|---|---|---|---|
| `deviceId` | string | `@IsNotEmpty` — raw device id (Android ID / IDFV); **never stored** | yes |
| `installSalt` | string | `@IsNotEmpty` — 64-hex per-install salt from `issueInstallSalt()` | yes |
| `platform` | enum | `@IsEnum(UserDevicePlatform)` ⇒ `'android'` or `'ios'` | yes |
| `fcmToken` | string | optional | no |
| `locale` | string | optional (ISO-639-1, stored in varchar(8)) | no |
| `label` | string | optional | no |
| `isMockLocation` | boolean | optional; **accepted and then completely ignored** by `verifyOtp` | no |

Response `200` (`AuthResponse`, `auth.service.ts:47-71` + `sanitizeUser`):

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid", "email": "", "phoneNumber": "+9627...", "name": "…",
      "gender": "male", "role": "passenger", "photoUrl": null,
      "rating": 0, "totalRatings": 0,
      "isPhoneVerified": true, "isEmailVerified": false, "isDriverApproved": false,
      "isActive": true, "createdAt": "…", "updatedAt": "…"
    },
    "accessToken": "<JWT>",
    "refreshToken": "<JWT>",
    "accountState": "active",
    "deviceState": "active",
    "pendingPhoneLinkRequired": false
  }
}
```

`accountState` ∈ `active | restricted | banned`; `deviceState` ∈
`active | revoked | null`. `sanitizeUser` coerces `email`/`phoneNumber`
`null → ""` and `gender` `null → "male"`, and adds `isActive`/`updatedAt` which
the `AuthResponse` TypeScript interface does not declare
(`auth.service.ts:843-860`).

**Business rules & validation:**

1. The OTP is verified first (`verifyPhoneOtp`, `auth.service.ts:940-981`):
   - **local:** `findOtpCode(phoneNumber, code)` =
     `SELECT … WHERE phoneNumber=? AND code=? AND isUsed=false`. If none →
     `401 "Invalid or expired OTP code"`. On success the row is marked
     `isUsed=true`.
     > ⚠ **Bug:** the lookup does **not** filter on `expiresAt`
     > (`users.service.ts:177-183`), and no job purges expired rows, so in local
     > mode an unused code never actually expires.
   - **twilio:** `verify.v2.services(SID).verificationChecks.create({to, code})`;
     `status !== 'approved'` → `401 "Invalid or expired OTP code"`. Any thrown
     Twilio error is also mapped to that same 401.
2. Look up the user by phone **with** `passwordHash` selected
   (`findUserByPhoneWithPassword`).
3. **Existing user branch:**
   - `!passwordHash && password` → set `passwordHash = bcrypt(password, 12)`,
     `passwordChangedAt = now`, `isPhoneVerified = true`; reload the user.
   - `passwordHash` already set → **`409 Conflict`** `"Phone number is already
     registered. Please sign in with your password."` — i.e. **verify-otp is not
     a login path for fully-registered accounts**; they must use `/auth/login`.
   - `!passwordHash && !password` → `400` `"Password is required to finish
     account setup for this phone number."`
   - Then, if `!isPhoneVerified`, call `linkPhone(user.id, phoneNumber)` and
     reload.
4. **New user branch:**
   - `password` is mandatory → else `400 "Password is required when creating a
     new account."`
   - `role === 'driver'` ⇒ `PgUserRole.DRIVER`, anything else ⇒
     `PgUserRole.PASSENGER` (an admin can never be created here).
   - `name` = trimmed `name` if non-empty, else **the phone number itself**.
   - Created with `provider:'phone'`, `isPhoneVerified:true`, `isActive:true`,
     `gender: gender ?? null`.
   - `UsersService.create` hashes `passwordHash` with bcrypt cost **12** unless
     the value already looks like a bcrypt digest (`$2b$`/`$2a$`/`$2y$` prefix —
     `users.service.ts:192-202`).
   - Two fire-and-forget side effects (errors logged, never propagated):
     `notifyAdminsOfNewUser(user)` and
     `adminAlertsService.notifyDriverRegistration(user)`.
     > Note: `notifyDriverRegistration` is called for **every** new user,
     > passenger or driver (`auth.service.ts:198`).
5. **Device binding** (`bindDeviceForUser`, `auth.service.ts:743-806`) — skipped
   entirely when `device` is absent (`deviceState:null`, `did:null` in the JWT):
   1. `fingerprintHash = SHA256(platform + ':' + deviceId + ':' + installSalt)` hex.
   2. If a row exists for `{userId, fingerprintHash, status:'revoked'}` →
      `401 "This device has been revoked. Please use another trusted device."`
      **Note: the OTP has already been consumed at this point.**
   3. `registerDevice` upserts: existing row for `{userId, fingerprintHash}` →
      set `status:'active'`, `revokedAt:null`, `revokeReason:null`,
      `lastSeenAt:now`, and overwrite `fcmToken`/`locale` **only if the field was
      provided** (`label` is *not* updated on an existing row). Otherwise insert
      a new row with `status:'active'`, `lastSeenAt:now`.
   4. Run the multi-account risk check (see **F-09**) — this may set
      `users.restricted = true`.
   5. Reload the user so `accountState` reflects a freshly-set restriction.
6. `accountState` = `'banned'` if `bannedAt != null`, else `'restricted'` if
   `restricted`, else `'active'`. **Tokens are still issued for banned and
   restricted accounts** — enforcement happens on subsequent requests via
   `BanGuard` / `RestrictedAccountInterceptor`.
7. `pendingPhoneLinkRequired = user.pendingPhoneLink ?? false`.
8. Tokens are generated last (see **F-05**), embedding `did = <user_devices.id>`
   when a device was bound.

**Data model:** reads/writes `users`, `otp_codes` (local mode), `user_devices`;
may write `account_flags` + `security_events` via F-09; writes `notifications`
rows for every admin.

**State machine (account provisioning):**

```
(no row)  --verify-otp with password--> users{isPhoneVerified:true, provider:'phone', passwordHash set}
users{passwordHash NULL}  --verify-otp with password--> passwordHash set + passwordChangedAt
users{passwordHash NOT NULL} --verify-otp--> 409 CONFLICT (must use /auth/login)
```

**External services used:** Twilio Verify (see F-01); Firebase/push indirectly
through `NotificationsService.create` for the admin new-user notification;
`AdminAlertsService.notifyDriverRegistration`.

**Background jobs / scheduled tasks:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| validation failure | 400 | validation envelope |
| invalid/unknown OTP | 401 | `Invalid or expired OTP code` |
| Twilio unconfigured | 400 | `Twilio Verify is not configured correctly` |
| existing account already has a password | 409 | `Phone number is already registered. Please sign in with your password.` |
| password-less account, no password sent | 400 | `Password is required to finish account setup for this phone number.` |
| new account, no password sent | 400 | `Password is required when creating a new account.` |
| device fingerprint revoked for this user | 401 | `This device has been revoked. Please use another trusted device.` |

**Notes for reimplementation:**

- Ordering matters: OTP consumption → account resolution → device binding →
  risk check → user reload → token generation. Restrict/ban state is read
  **after** the risk check so a just-restricted account reports
  `accountState:'restricted'` in the very same response.
- `bindDeviceForUser` reaches into `deviceFingerprintService['deviceRepo']` —
  a private-field escape hatch (`auth.service.ts:766-768`). Expose a proper
  `findRevokedDevice(userId, fingerprintHash)` method in a rebuild.
- Consuming the OTP before the revoked-device check means a user on a revoked
  device burns a code per attempt. Check the device first.
- `isMockLocation` on the device payload is documented as "so the backend can
  immediately record the state" but nothing reads it here — mock-location
  handling only exists on the tracking WebSocket (see F-11).

---

## F-03: Deferred driver registration (phone-first, transactional account+vehicle)

**What it does:** Onboards a driver in three steps — prove the phone, upload the
documents against a short-lived registration token, then create the driver
account and their vehicle atomically. Nothing is persisted about the driver
until the final step succeeds. A driver whose account is still awaiting admin
approval can also correct their submission.

**Actors:** anonymous for steps 1–3; authenticated driver for the correction step.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/driver/verify-phone` | none (`@Public`) | Verify OTP without creating an account; return a registration token |
| POST | `/api/v1/uploads/registration` | registration token in body | Upload a registration document/photo pre-account |
| POST | `/api/v1/auth/driver/register` | none (`@Public`) — authorised by the registration token in the body | Create driver + vehicle in one transaction; issue tokens |
| PATCH | `/api/v1/auth/driver/registration` | Bearer JWT | Amend the pending submission before approval |

**Request / Response contracts:**

**(a) `POST /auth/driver/verify-phone`** — `DriverVerifyPhoneDto`:

| Field | Type | Rules |
|---|---|---|
| `phoneNumber` | string | trimmed, `@IsNotEmpty`, E.164 `^\+[1-9]\d{1,14}$` |
| `code` | string | trimmed, `@IsNotEmpty`, `@Matches(/^\d{4,6}$/, "OTP code must be 4 to 6 digits")` — note the **4–6** range here vs strict **6** in `VerifyOtpDto` |

Response `200`: `{ registrationToken: "<JWT>", expiresIn: 1800 }`

**(b) `POST /uploads/registration`** — `multipart/form-data`:

| Field | Type | Rules |
|---|---|---|
| `registrationToken` | string (form field) | must verify against `JWT_ACCESS_SECRET` and carry `purpose === 'driver_registration'` |
| `file` | file | MIME ∈ `image/jpeg, image/png, image/webp, application/pdf`; ≤ **10 MB** |

Response: `{ url: "http://host/uploads/driver-registration/<uuid><ext>", key: "driver-registration/<uuid><ext>" }`

**(c) `POST /auth/driver/register`** — `RegisterDriverDto`:

| Field | Type | Rules | Required |
|---|---|---|---|
| `registrationToken` | string | `@IsNotEmpty("Registration token is required")` | yes |
| `name` | string | trimmed, `@IsNotEmpty("Name is required")`, `@MinLength(1)`, `@MaxLength(120)` | yes |
| `gender` | string | `@IsIn(['male','female'])` | no |
| `photoUrl` | string | `@MaxLength(500)` | no |
| `password` | string | `@MinLength(8)`, `@MaxLength(100)`, `@Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/)` | yes |
| `vehicleType` | string | `@IsNotEmpty`, `@MaxLength(100)` | yes |
| `plateNumber` | string | `@IsNotEmpty`, `@MaxLength(20)` | yes |
| `model` | string | `@IsNotEmpty`, `@MaxLength(100)` | yes |
| `seats` | number | `@Type(Number)`, `@IsInt`, `@Min(1)`, `@Max(50)` | no (derived from the catalog layout when absent) |
| `licenseImageUrl` | string | `@MaxLength(500)` | no |
| `vehicleLicenseImageUrl` | string | `@MaxLength(500)` | no |
| `carImageUrl` | string | `@IsNotEmpty("Car photo is required")`, `@MaxLength(500)` | **yes** |
| `insuranceImageUrl` | string | `@IsNotEmpty("Insurance image is required")`, `@MaxLength(500)` | **yes** |
| `device` | `VerifyOtpDeviceDto` | `@ValidateNested` | no |

Response `201`: the same `AuthResponse` shape as F-02.

**(d) `PATCH /auth/driver/registration`** — `UpdatePendingDriverRegistrationDto`,
every field optional: `photoUrl` (≤500), `vehicleType` (≤100),
`plateNumber` (≤20), `model` (≤100), `seats` (int 1–50), `licenseImageUrl`
(≤500), `vehicleLicenseImageUrl` (≤500), `insuranceImageUrl` (≤500),
`carImageUrl` (≤500).

Response `200`: `{ user: <sanitizeUser>, vehicle: <VehicleEntity> }`

**Business rules & validation:**

1. **Step 1** verifies the OTP through the same `verifyPhoneOtp` path as F-02
   (consuming the local code / calling Twilio).
2. **Step 1** then rejects an already-registered phone: `findByPhone` non-null →
   `409 "Phone number is already registered. Please sign in instead."`
3. **Registration token** (`signRegistrationToken`, `auth.service.ts:701-712`):
   `jwt.sign({ phone, purpose: 'driver_registration' }, JWT_ACCESS_SECRET, { expiresIn: 1800 })`.
   TTL constant `DRIVER_REGISTRATION_TOKEN_TTL_SECONDS = 30*60 = 1800`
   (`dto/register-driver.dto.ts:25`).
   It shares the **access-token signing secret**, so the `purpose` claim is the
   only thing separating it from a session token.
4. **Verification** (`verifyRegistrationToken`, `auth.service.ts:715-737`):
   signature/expiry failure → `401 "Registration session expired. Please verify
   your phone again."`; decoded payload not an object, or
   `purpose !== 'driver_registration'`, or `typeof phone !== 'string'` →
   `401 "Invalid registration token."`
   > ⚠ The reverse guard is missing: `JwtStrategy` does **not** check that an
   > access token lacks `purpose`, so a registration token is rejected only
   > because it has no `sub`/`email` (`jwt.strategy.ts:32-35`) — accidental, not
   > designed.
5. **Step 3 (register)** re-checks `findByPhone(phone)` → `409` before starting.
6. Seat layout is resolved from the vehicle-type catalog:
   `resolveVehicleTypeTemplate(dto.vehicleType, logger).layout`;
   `seats = dto.seats ?? countSeatsInLayout(layout)`
   (`modules/vehicles/vehicle-types`). The client-supplied `seats` wins if
   present.
7. Password hashed with **bcrypt cost 12** *before* opening the transaction.
8. **Single transaction** (`userRepo.manager.transaction`) creates:
   - `users` row: `phoneNumber` (from the token, not the body),
     `name` = trimmed name or the phone number, `gender ?? null`,
     `photoUrl ?? null`, `passwordHash`, `passwordChangedAt = now`,
     `role='driver'`, `provider='phone'`, `isPhoneVerified=true`,
     `isActive=true`. `isDriverApproved` stays `false`.
   - `vehicles` row: `driverId`, `vehicleType`, `plateNumber`, `model`, `seats`,
     `seatLayout`, `licenseImageUrl ?? null`, `vehicleLicenseImageUrl ?? null`,
     `carImageUrl`, `insuranceImageUrl ?? null`.
9. **Race safety net:** a Postgres unique violation (`err.code === '23505'`) from
   the concurrent-insert race on `users.phoneNumber` is translated to the same
   `409` (`auth.service.ts:281-289`).
10. Post-commit: the two fire-and-forget admin notifications, then device binding
    (identical to F-02), `accountState`, and token generation.
11. **Step 4 (amend)** rules (`updatePendingRegistration`, `auth.service.ts:370-439`):
    - Caller must exist and have `role === 'driver'`, else `403 "Driver account required"`.
    - `isDriverApproved === true` → `403 "Approved drivers cannot update registration via this endpoint"`.
    - Payload must contain at least one non-`undefined`, non-`null` value, else
      `400 "At least one field is required"`.
    - Runs in a transaction. `photoUrl` writes to `users`; everything else writes
      to the driver's single vehicle (`vehicleRepo.findOne({ driverId })`) →
      `404 "Vehicle not found"` if absent.
    - Changing `vehicleType` **re-derives** `seatLayout` from the catalog and
      recomputes `seats` from that layout; a `seats` value in the same payload
      then overrides it (assignment order: `vehicleType` block first,
      `dto.seats` second — `auth.service.ts:410-427`).
    - The account stays pending — nothing here re-triggers approval.

**Data model:** `users`, `vehicles` (driver-owned, other domain), plus the same
device/risk tables as F-02.

**State machine:**

```
 phone unverified
   │ POST /auth/driver/verify-phone (valid OTP, phone unused)
   ▼
 registrationToken (30 min, purpose=driver_registration)
   │ POST /uploads/registration  (0..n times, same token)
   ▼
 POST /auth/driver/register  ── 409 if phone taken ──> abort (nothing persisted)
   │ (transaction: users + vehicles)
   ▼
 driver account, isDriverApproved=false   <── PATCH /auth/driver/registration (loop)
   │ admin PATCH /admin/users/:id/approve-driver {approved:true}
   ▼
 isDriverApproved=true  (registration data frozen for this endpoint)
```

**External services used:** Twilio Verify (step 1); local filesystem for uploads
(F-16); FCM via `NotificationsService`/`AdminAlertsService` for the
new-driver alert.

**Background jobs / scheduled tasks:** none.

**Errors:**

| Condition | HTTP | Message / code |
|---|---|---|
| bad OTP | 401 | `Invalid or expired OTP code` |
| phone already registered (step 1 or 3) | 409 | `Phone number is already registered. Please sign in instead.` |
| expired/invalid registration token | 401 | `Registration session expired. Please verify your phone again.` / `Invalid registration token.` |
| upload: missing token | 401 | `Registration token is required` |
| upload: `JWT_ACCESS_SECRET` unset | 401 | `Server auth is not configured` |
| upload: wrong `purpose` | 401 | `Invalid registration token` |
| upload: no file | 400 | `No file uploaded` |
| upload: bad MIME | 400 | `Invalid file type. Allowed types: image/jpeg, image/png, image/webp, application/pdf` |
| upload: >10 MB | 400 | `File size exceeds maximum allowed size of 10MB` |
| amend: non-driver | 403 | `Driver account required` |
| amend: already approved | 403 | `Approved drivers cannot update registration via this endpoint` |
| amend: empty body | 400 | `At least one field is required` |
| amend: no vehicle row | 404 | `Vehicle not found` |

**Notes for reimplementation:**

- Give the registration token its **own secret** (or at minimum verify the
  `purpose` claim negatively in the session strategy).
- The `phoneNumber` used to create the account comes from the **token**, never
  from the request body — this is what makes the flow safe.
- `insuranceImageUrl` is mandatory at the DTO level (spec'd by
  `dto/register-driver.dto.spec.ts`) but is written as `dto.insuranceImageUrl ?? null`
  — the service tolerates absence when called directly (see the unit test
  "stores a null insurance url when the client omits it").
- The `409` check and the insert are not atomic; the `23505` catch is the real
  guarantee. Keep the unique index on `users.phoneNumber`.

---

## F-04: Password login (users by phone, admins by email)

**What it does:** Exchanges a password for a token pair. End users authenticate
with phone + password; administrators with email + password. One endpoint, two
branches.

**Actors:** anonymous

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/login` | none (`@Public`) | Password sign-in |

**Request / Response contracts:**

`SignInDto` (`dto/sign-in.dto.ts`):

| Field | Type | Rules |
|---|---|---|
| `phoneNumber` | string | `@ValidateIf((o,v) => v !== undefined || !o.email)`; trimmed; E.164 regex |
| `email` | string | `@ValidateIf((o,v) => v !== undefined || !o.phoneNumber)`; trimmed + lower-cased; `@IsEmail` msg `"Email must be a valid email address"` |
| `password` | string | `@IsString`, `@MinLength(1)` — **no complexity check on login** |

Semantics of the `ValidateIf` pair: a field is validated when it is present, or
when the *other* field is absent. Send neither ⇒ both validated ⇒ two errors.
Send both ⇒ both validated, and the **email branch wins** at the service level
(`auth.service.ts:441-443`).

Response `200`: `AuthResponse` with `deviceState: null` (login never binds a
device) and `did: null` in the JWT.

**Business rules & validation:**

1. If `email` is present → `findAdminByEmailWithPassword`:
   `WHERE LOWER(email) = LOWER(:email) AND role = 'admin'`. **Only admins can log
   in by email.** A passenger/driver with an email cannot use this branch.
2. Otherwise → `findUserByPhoneWithPassword(phoneNumber!)` (exact match, no
   normalisation).
3. No user, or user with `passwordHash === null` →
   `401 "Invalid admin email or password"` (email branch) /
   `401 "Invalid phone number or password"` (phone branch).
4. `bcrypt.compare(password, passwordHash)` false → same 401 message
   (no user-enumeration leak between "unknown" and "wrong password").
5. Phone branch only: `!user.isPhoneVerified` → `401 "Phone number must be
   verified before signing in."` The admin/email branch skips this check.
6. `isActive === false` is **not** checked here — an inactive account still
   receives tokens; `JwtStrategy` rejects the subsequent requests with
   `401 "User account is inactive"`.
7. `bannedAt` / `restricted` are **not** blocking here either; they are reported
   in `accountState` and enforced later by `BanGuard` /
   `RestrictedAccountInterceptor`.
8. No failed-attempt counter, no lockout, no per-account rate limit — only the
   global 200 req/min throttler.

**Data model:** reads `users` (with `passwordHash` explicitly `addSelect`ed);
writes `users.refreshToken` via `generateTokens`.

**External services used:** none.

**Background jobs / scheduled tasks:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| validation | 400 | envelope |
| unknown user / no password / wrong password (email branch) | 401 | `Invalid admin email or password` |
| unknown user / no password / wrong password (phone branch) | 401 | `Invalid phone number or password` |
| unverified phone | 401 | `Phone number must be verified before signing in.` |

**Notes for reimplementation:**

- Add brute-force protection; there is none today.
- Admin accounts are created out-of-band (see F-18) — there is no admin sign-up.
- Because `deviceState` is `null` and the JWT has `did: null`, a login-issued
  token is **not** bound to any device and therefore survives device revocation
  (see F-08).

---

## F-05: Token issuance, refresh and logout

**What it does:** Mints the JWT pair that authenticates every subsequent
request, refreshes it, and "logs out". Also defines the token contract
(claims, TTLs, secrets) and the invalidation rules.

**Actors:** any authenticated user for logout; anonymous for refresh (the
refresh token is the credential).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/refresh` | none (`@Public`); refresh token in body | Issue a new token pair |
| POST | `/api/v1/auth/logout` | Bearer JWT | "Log out" the current user |

**Request / Response contracts:**

`POST /auth/refresh` — `RefreshTokenDto`: `{ refreshToken: string }`
(`@IsString`, `@IsNotEmpty`).
Response `200`: `{ accessToken, refreshToken }` (no user object).

`POST /auth/logout` — no body. Response `200`:
`{ message: "Logged out successfully" }`.

**Token contract (`generateTokens`, `auth.service.ts:810-841`):**

| | Access token | Refresh token |
|---|---|---|
| Secret | `JWT_ACCESS_SECRET` | `JWT_REFRESH_SECRET` |
| TTL | **hardcoded `15m`** | **hardcoded `7d`** |
| Algorithm | `jsonwebtoken` default → **HS256** | HS256 |
| Claims | `sub` = user id, `email` (may be `null`), `role`, `did` = `user_devices.id` or `null`, plus `iat`/`exp` | identical payload |

Both tokens carry the same payload — a refresh token is structurally
indistinguishable from an access token except for the signing secret.

**Business rules & validation:**

1. After signing, `usersService.updateRefreshToken(user.id, refreshToken)` stores
   `bcrypt(refreshToken, 12)` in `users.refreshToken`
   (`users.service.ts:88-91`). **Nothing ever reads or compares this hash** —
   `auth.service.ts` uses only `jwt.verify`; `JwtRefreshStrategy.validate`
   explicitly gives up on the check (see its inline comments,
   `strategies/jwt-refresh.strategy.ts:47-70`).
2. `refreshTokens` (`auth.service.ts:481-529`):
   - `jwt.verify(refreshToken, JWT_REFRESH_SECRET)`; missing secret → thrown
     `Error`, caught by the same catch → `401 "Invalid refresh token"`.
   - Resolve the user by `payload.sub`; on failure fall back to
     `findByEmail(payload.email)` (legacy-token support).
   - `!user || !user.isActive` → `401 "User not found or inactive"` (re-mapped by
     the outer catch to `401 "Invalid refresh token"`).
   - If `payload.did` is set, `findActiveDeviceById(user.id, did)` must return a
     row → else `401 "Device session is no longer active"` (also re-mapped).
     > All inner exceptions are swallowed by the outer `try/catch` and re-thrown
     > as `UnauthorizedException('Invalid refresh token')` — the specific
     > messages above are only visible in the `console.error` log line
     > `Refresh token error: <msg>`.
   - Issues a fresh pair carrying the same `did`.
3. `logout` (`auth.service.ts:531-535`) calls
   `updateRefreshToken(userId, '')` → stores `bcrypt('')`. It does **not**
   null the column, does **not** revoke the device, and does **not** blacklist
   the outstanding tokens. **Logout is cosmetic: the previously issued access
   and refresh tokens remain valid until they expire.**
4. Real invalidation levers that do work:
   - `users.passwordChangedAt` — `JwtStrategy` rejects any access token whose
     `iat` predates it (`jwt.strategy.ts:71-76`). Set by password reset
     (F-06), password change (F-07), and initial password assignment (F-02).
   - Device revocation — any token with a `did` pointing at a non-`active`
     device is rejected by `JwtStrategy` and by `refreshTokens`.
   - `users.isActive = false`.
   - `users.bannedAt` (via `BanGuard`, 403 rather than 401).
5. `JwtStrategy.validate` (`strategies/jwt.strategy.ts:31-77`), run for every
   non-`@Public` request:
   1. `!sub && !email` → `401 "Invalid token payload"`.
   2. Load by `sub`; on any error fall back to `findByEmail(email)`.
   3. `!user` → `401 "User not found"`.
   4. `!user.isActive` → `401 "User account is inactive"`.
   5. `did` present → active device required, else
      `401 "Device session is no longer active"`.
   6. `passwordChangedAt` set and `new Date(payload.iat*1000) < passwordChangedAt`
      → `401 "Token expired due to password change"`.
   7. Returns the full `UserEntity` — this becomes `req.user` and is what
      `GET /users/me` returns verbatim.
6. `JwtAuthGuard` short-circuits on `@Public()` metadata (handler or class) and
   otherwise maps any passport failure to
   `401 "Invalid or expired token"` (`common/guards/jwt-auth.guard.ts`).
7. **WebSocket auth** (`common/guards/ws-auth.guard.ts`): token from
   `handshake.auth.token`, `handshake.query.token`, or the
   `Authorization: Bearer …` handshake header; verified with `JWT_ACCESS_SECRET`
   via `JwtService`; `client.user = { ...payload, id: sub||userId||id }` and
   `client.data.userId`. Failure → `UnauthorizedException("Invalid or expired
   WebSocket token")` / `"WebSocket authentication token not found"`.
   **This path performs no DB lookup**, so it does not see `isActive`,
   `bannedAt`, `restricted`, `passwordChangedAt` or device revocation.

**Data model:** `users.refreshToken` (write-only), `user_devices` (read).

**State machine:** none.

**External services used:** none.

**Background jobs / scheduled tasks:** none.

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| any refresh failure | 401 | `Invalid refresh token` |
| missing/invalid access token | 401 | `Invalid or expired token` |
| inactive account | 401 | `User account is inactive` |
| revoked device | 401 | `Device session is no longer active` |
| token older than the last password change | 401 | `Token expired due to password change` |

**Notes for reimplementation:**

- Implement real refresh-token rotation: store a hash, compare it on refresh,
  rotate it, and null it on logout. All the storage already exists — only the
  comparison is missing.
- `JwtRefreshStrategy` (`strategies/jwt-refresh.strategy.ts`) is registered as a
  provider but **no guard uses the `'jwt-refresh'` strategy anywhere** — dead
  code, and its `validate()` body is a half-finished thought preserved in
  comments. Delete it.
- Honour `JWT_EXPIRES_IN` / `JWT_REFRESH_EXPIRES_IN` instead of hardcoding.
- Add the DB-backed checks to the WebSocket guard.

---

## F-06: Password reset via phone OTP

**What it does:** Lets a user who knows their phone number but not their
password reset it: request a code, verify the code to obtain a reset token, then
exchange the token for a new password.

**Actors:** anonymous

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/forgot-password` | none (`@Public`) | Send a reset OTP + open a reset session |
| POST | `/api/v1/auth/verify-reset-otp` | none (`@Public`) | Verify the OTP; return a `resetToken` |
| POST | `/api/v1/auth/reset-password` | none (`@Public`) | Set the new password |

**Request / Response contracts:**

`ForgotPasswordDto`: `{ phoneNumber }` — `@IsString`, E.164 regex.
Response `200`: `{ message: "OTP sent successfully", expiresIn: 300 }`.

`VerifyResetOtpDto`: `{ phoneNumber, code }` — both trimmed and `@IsNotEmpty`;
phone E.164; `code` `@Matches(/^\d{6}$/, "OTP code must be exactly 6 digits")`.
Response `200`: `{ resetToken: "<uuid>" }` — the `password_reset_sessions.id`.

`ResetPasswordDto`: `{ resetToken, newPassword }` — both trimmed and
`@IsNotEmpty` (`"Reset token is required"` / `"New password is required"`);
`newPassword` `@Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/)`.
Response `200`: `{ message: "Password reset successfully" }`.

**Business rules & validation:**

1. `forgotPassword` (`auth.service.ts:564-590`):
   1. `findByPhone(phoneNumber)`; no user → **`404 "No account found for this
      phone number"`** — this **enumerates registered phone numbers**.
   2. Delegates to `sendOtp` (F-01) — same provider, same 5-minute local TTL.
   3. `DELETE FROM password_reset_sessions WHERE phoneNumber = ?` — only one live
      session per phone; re-requesting discards the old one and its attempt
      counter.
   4. `INSERT` a session with `otpCode = randomUUID()` (a placeholder, never
      compared), `isVerified=false`, `attemptCount=0`, `isLocked=false`,
      `expiresAt = now + expiresIn*1000` = **now + 300 s**.
2. `verifyResetOtp` (`auth.service.ts:592-635`):
   1. `SELECT … WHERE phoneNumber = ? AND expiresAt > now() ORDER BY createdAt DESC LIMIT 1`.
   2. No session, or `session.isLocked` → `401 "Password reset session is invalid
      or has expired"`.
   3. Verify the code with the shared `verifyPhoneOtp` (local `otp_codes` table
      or Twilio Verify) — **the session's own `otpCode` column plays no part**.
   4. On failure: `attemptCount += 1`; `isLocked = attemptCount >= 5`; if now
      locked → `401 "Too many attempts. Please request a new reset code."`,
      otherwise rethrow the original `401 "Invalid or expired OTP code"`.
      → **maximum 5 attempts per session.**
   5. On success: `isVerified = true`, `attemptCount += 1`; return
      `{ resetToken: session.id }`.
3. `resetPassword` (`auth.service.ts:637-673`):
   1. `SELECT … WHERE id = :resetToken AND isVerified = true AND isLocked = false
      AND expiresAt > now()`; none → `401 "Reset token is invalid or has
      expired"`.
   2. `findByPhone(session.phoneNumber)`; none → `404 "User not found"`.
   3. `UPDATE users SET passwordHash = bcrypt(newPassword, 12),
      passwordChangedAt = now(), refreshToken = NULL WHERE id = ?`.
   4. `DELETE FROM password_reset_sessions WHERE phoneNumber = ?` — burns every
      session for that phone.
4. **Total window is 5 minutes** from `forgot-password` — `expiresAt` is never
   extended by a successful `verify-reset-otp`, so the whole
   request→verify→reset sequence must complete within 300 s.
5. Setting `passwordChangedAt` immediately invalidates every previously issued
   access token for that user (F-05 rule 5.6).
6. No account lockout, no notification to the user that a reset was requested or
   completed.

**Data model:** `password_reset_sessions` (all columns), `otp_codes` (local
mode), `users.passwordHash` / `passwordChangedAt` / `refreshToken`.

**State machine:**

```
 (none)
   │ POST /auth/forgot-password  [deletes any prior session for the phone]
   ▼
 session{isVerified:false, attemptCount:0, isLocked:false, expiresAt:+300s}
   │ POST /auth/verify-reset-otp
   ├── wrong code ──> attemptCount+1 ──> attemptCount>=5 ──> isLocked:true  (terminal)
   └── right code ──> isVerified:true, attemptCount+1
                          │ POST /auth/reset-password (id + isVerified + !isLocked + not expired)
                          ▼
                      password updated; ALL sessions for the phone DELETED
```

**External services used:** Twilio Verify / local OTP (F-01).

**Background jobs / scheduled tasks:** none. Expired
`password_reset_sessions` rows are never purged (only overwritten per-phone on
the next request, or deleted on successful reset).

**Errors:**

| Condition | HTTP | Message |
|---|---|---|
| unknown phone | 404 | `No account found for this phone number` |
| no/expired/locked session | 401 | `Password reset session is invalid or has expired` |
| wrong code (attempts < 5) | 401 | `Invalid or expired OTP code` |
| 5th wrong attempt | 401 | `Too many attempts. Please request a new reset code.` |
| bad/expired/unverified reset token | 401 | `Reset token is invalid or has expired` |
| user vanished between steps | 404 | `User not found` |

**Notes for reimplementation:**

- `resetToken` **is the session primary key** — a plain UUIDv4. It is
  unguessable but it is also the DB id; prefer an opaque random token stored
  hashed.
- Drop the vestigial `otpCode` column or actually use it.
- Return `200` regardless of whether the phone exists, to stop enumeration.
- Attempt counting is per-session, and a new `forgot-password` resets it to 0 —
  an attacker can bypass the 5-attempt cap by re-requesting a code. Add a
  per-phone counter with a cooldown.

---

## F-07: Change password (authenticated)

**What it does:** Lets a signed-in user rotate their password by proving the
current one.

**Actors:** any authenticated user (passenger / driver / admin)

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/change-password` | Bearer JWT | Change own password |

**Request / Response contracts:**

`ChangePasswordDto` (`dto/change-password.dto.ts`):

| Field | Type | Rules |
|---|---|---|
| `currentPassword` | string | trimmed, `@IsNotEmpty("Current password is required")` |
| `newPassword` | string | trimmed, `@IsNotEmpty("New password is required")`, `@Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/)` |

Response `200`: `{ message: "Password changed successfully" }`.

**Business rules & validation:**

1. Load the caller **with** `passwordHash` (`findUserByIdWithPassword`); missing
   user → `404 "User not found"`.
2. `passwordHash === null` → `400 "No password is set for this account"`.
3. `bcrypt.compare(currentPassword, passwordHash)` false →
   `401 "Current password is incorrect"`.
4. `UPDATE users SET passwordHash = bcrypt(newPassword, 12),
   passwordChangedAt = now(), refreshToken = NULL`.
5. Consequence: every outstanding access token for this user (including the one
   used to make this very call) becomes invalid on the next request. The client
   must re-authenticate.
6. There is **no check that the new password differs from the old one**, and no
   password history.

**Data model:** `users.passwordHash`, `users.passwordChangedAt`,
`users.refreshToken`.

**External services / jobs:** none.

**Errors:** `404 User not found`, `400 No password is set for this account`,
`401 Current password is incorrect`, `400` validation envelope.

**Notes for reimplementation:** the endpoint self-invalidates the caller's
session — surface that to clients, or re-issue a token pair in the response.

---

## F-08: Device sessions (fingerprinting, listing, revocation)

**What it does:** Binds a physical device to an account after OTP verification
without ever storing a raw device identifier, lets users see and revoke their
device sessions, and ties JWTs to a specific device so revocation is immediate.

**Actors:** authenticated user (own devices); admin (any device, see F-11)

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/auth/devices` | Bearer JWT | List the caller's active device sessions |
| DELETE | `/api/v1/auth/devices/:deviceId` | Bearer JWT | Revoke one of the caller's devices |
| DELETE | `/api/v1/admin/devices/:deviceId/revoke` | Bearer JWT + `role=admin` | Admin revoke (see F-11) |

**Request / Response contracts:**

`GET /auth/devices` → `200 { devices: UserDeviceEntity[] }` — full rows
(`id`, `userId`, `fingerprintHash`, `platform`, `label`, `fcmToken`, `status`,
`revokedAt`, `revokeReason`, `locale`, `lastSeenAt`, `createdAt`, `updatedAt`),
filtered to `status='active'`, ordered by `lastSeenAt DESC`.
> Note: the response leaks `fingerprintHash` and `fcmToken` to the client.

`DELETE /auth/devices/:deviceId` → `200 { success: true, deviceId: "<uuid>" }`.
`deviceId` is taken from the path with no `ParseUUIDPipe` (unlike the admin
route).

**Fingerprinting algorithm (`device-fingerprint.service.ts`):**

- `hash(platform, deviceId, installSalt) = sha256("<platform>:<deviceId>:<installSalt>").digest('hex')`
  → 64 lowercase hex chars.
- `issueInstallSalt() = crypto.randomBytes(32).toString('hex')` → 64 hex chars.
  Generated **client-side at first launch** and kept in secure storage; the
  server exposes no endpoint that returns one (no controller calls
  `issueInstallSalt`).

**Business rules & validation:**

1. `registerDevice` upsert semantics (`device-fingerprint.service.ts:70-105`):
   - Key: `(userId, fingerprintHash)`.
   - Existing row → force `status='active'`, clear `revokedAt`/`revokeReason`,
     set `lastSeenAt=now`, overwrite `fcmToken` and `locale` **only when the
     param is not `undefined`**. `label` and `platform` are **not** refreshed.
     > ⚠ Reactivating a revoked row here is a real hole — but it is unreachable
     > from `verifyOtp`, which checks for a revoked row and 401s first
     > (`auth.service.ts:766-781`). Any *other* caller of `registerDevice` would
     > silently un-revoke. Verify: `device-fingerprint.service.ts:85-87`.
   - New row → insert with `status='active'`, `lastSeenAt=now`,
     `fcmToken/label/locale` defaulting to `null`.
2. `findActiveDevice(userId, fingerprintHash)` and
   `findActiveDeviceById(userId, deviceId)` both require `status='active'`.
   The latter backs the `did` check in `JwtStrategy` and `refreshTokens`.
3. `listActiveDevices(userId)` — `status='active'`, `ORDER BY lastSeenAt DESC`.
   Postgres `DESC` implies `NULLS FIRST`, so never-seen devices sort **first**
   (`device-fingerprint.service.ts:130-135`).
4. `revokeDevice(deviceId, reason?)` — `findOneOrFail` (throws TypeORM
   `EntityNotFoundError` → surfaces as **500** if the caller didn't pre-check),
   then `status='revoked'`, `revokedAt=now`, `revokeReason = reason ?? null`.
5. The user-facing controller pre-checks ownership
   (`findOne({ id: deviceId, userId })`) and returns
   `404 { message:'Device not found', code:'NOT_FOUND' }` otherwise, then calls
   `revokeDevice(deviceId, 'user_self_revoke')`
   (`auth.controller.ts:206-235`). It again reaches into the private
   `deviceFingerprintService['deviceRepo']`.
6. **Self-revoke is not actually prevented.** `ErrorCodes.SELF_REVOKE_USE_LOGOUT`
   exists (`common/errors/error-codes.ts:33`) and the controller doc-comment
   claims the refusal, but the code has a TODO admitting the current device id
   isn't available server-side — it just revokes
   (`auth.controller.ts:226-233`). Revoking your own device immediately 401s
   every subsequent request from it.
7. `lastSeenAt` is only updated inside `registerDevice`, i.e. on OTP
   verification / driver registration. It is **not** refreshed per request,
   despite the entity comment saying "Last time this device sent any
   authenticated request".
8. `countDistinctUsersForFingerprint(fingerprintHash, withinHours)` —
   `SELECT DISTINCT "userId" FROM user_devices WHERE "fingerprintHash"=? AND "createdAt" >= now()-interval`.
   Backs F-09.
9. Login (F-04) does not bind a device and mints `did:null` tokens, which are
   **not** subject to the device check. Revoking every device therefore does not
   lock out someone holding a password.

**Data model:** `user_devices` (§3.5).

**State machine:**

```
 (absent) --registerDevice--> active
   active --revokeDevice / admin revoke / ban cascade--> revoked  (revokedAt, revokeReason set)
   revoked --registerDevice (only reachable outside verifyOtp)--> active   [see rule 1 caveat]
   revoked --verifyOtp with same device--> 401 (no transition)
```

**External services used:** none.

**Background jobs / scheduled tasks:** none.

**Errors:**

| Condition | HTTP | Body |
|---|---|---|
| device not owned by caller / missing | 404 | `{ message:'Device not found', code:'NOT_FOUND' }` |
| revoked device attempts OTP verification | 401 | `This device has been revoked. Please use another trusted device.` |
| token whose `did` is no longer active | 401 | `Device session is no longer active` |

**Notes for reimplementation:**

- Add a unique index on `(userId, fingerprintHash)`.
- Never return `fingerprintHash`/`fcmToken` in the list response.
- Have the client send the current `did` (or read it from the JWT) so
  self-revoke can return `SELF_REVOKE_USE_LOGOUT` as designed.
- Update `lastSeenAt` from the auth middleware if the field is to mean anything.

---

## F-09: Automated account risk — multi-account-from-one-device

**What it does:** Detects one physical device being used to create many accounts
and automatically restricts the newest account, raises a high-severity flag for
admin review, and records an audit event.

**Actors:** system (runs inside OTP verification and driver registration)

**API Endpoints:** none directly — triggered by `POST /auth/verify-otp` and
`POST /auth/driver/register` when a `device` block is supplied.

**Business rules & validation** (`account-risk.service.ts`):

1. Threshold = `Number(MULTI_ACCOUNT_DEVICE_THRESHOLD ?? '3')`, read once in the
   constructor. A non-numeric value yields `NaN`, and the comparison
   `userIds.length < NaN` is always `false`, so **every** verification would
   flag (`account-risk.service.ts:42-45`).
2. No-op when `fingerprintHash` is `null` (i.e. no device block).
3. `countDistinctUsersForFingerprint(fingerprintHash, 24)` → distinct `userId`s
   whose `user_devices.createdAt` is within the last **24 hours**.
4. `userIds.length < threshold` → return.
5. Otherwise, in order:
   1. `UPDATE users SET restricted = true WHERE id = <triggering user>` — only
      the account that just authenticated is restricted; the earlier accounts on
      that device are untouched.
   2. `INSERT INTO account_flags` — `reason='multi_account_device'`,
      `severity='high'`, `disposition='open'`,
      `notes='Device fingerprint linked to <n> accounts within 24 h (threshold: <t>).'`
   3. `INSERT INTO security_events` — `eventType='account_restricted_auto'`,
      `metadata={ reason:'multi_account_device', distinctAccountCount:<n>, fingerprintHash }`.
6. **Not idempotent** — every subsequent OTP verification on the same device
   re-runs the check and inserts *another* flag row and *another* security event
   (no "existing open flag" guard, unlike the mock-location path in F-11).
7. The check runs **after** the device row is inserted, so the current
   registration is included in the count.
8. Restriction is enforced by `RestrictedAccountInterceptor`: all
   `POST/PUT/PATCH/DELETE` requests → `423 Locked` `{ code:'ACCOUNT_RESTRICTED',
   message:'Your account is currently restricted. Write operations are not
   permitted.' }`. `GET/HEAD/OPTIONS` pass through.
9. **There is no un-restrict API.** Clearing `users.restricted` requires a direct
   DB update. (`account_unrestricted_admin` is documented in the
   `security_events` JSDoc but never emitted.)

**Data model:** reads `user_devices`; writes `users.restricted`,
`account_flags`, `security_events`.

**State machine:**

```
users.restricted: false --(>= threshold distinct accounts on one fingerprint in 24h)--> true
                  true  --(no API path)--> false   [manual DB edit only]
```

**External services / jobs:** none.

**Errors:** none surfaced — the check runs inline and any DB failure propagates
out of `verifyOtp` as a 500.

**Notes for reimplementation:**

- Guard against duplicate flags (`WHERE reason=? AND disposition='open'`).
- Restricting only the newest account is a deliberate choice; document it.
- Build the un-restrict admin endpoint the audit vocabulary already anticipates.
- Validate the threshold env var (reject `NaN`).

---

## F-10: Ban enforcement and the admin ban cascade

**What it does:** Blocks a banned account from using the platform on every
request, and gives admins a ban action that cascades through the user's
bookings, trips and devices, plus an unban action.

**Actors:** system (guard); admin (ban/unban)

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/admin/users/:id/ban` | Bearer JWT + `role=admin` | Ban with cascade |
| POST | `/api/v1/admin/users/:id/unban` | Bearer JWT + `role=admin` | Clear the ban |

**Request / Response contracts:**

`POST /admin/users/:id/ban` — `:id` validated by `ParseUUIDPipe`.
Body `BanUserDto` (`admin/admin-ban.controller.ts:23-28`):
`{ reason: string }` — `@IsString`, `@IsNotEmpty`, `@MaxLength(500)`.
Response `200`: `{ id, bannedAt, banReason }`.

`POST /admin/users/:id/unban` — no body. Response `200`:
`{ id, bannedAt: null, banReason: null }`.

**Business rules & validation:**

1. **`BanGuard`** (`common/guards/ban.guard.ts`), global, runs immediately after
   `JwtAuthGuard`:
   - `@Public()` handler/class → pass.
   - No `req.user` → pass (JwtAuthGuard already handled it).
   - `user.bannedAt != null` → `403 ForbiddenException` with body
     `{ code: 'ACCOUNT_BANNED', banReason: <string|null>, supportWhatsApp: process.env.SUPPORT_WHATSAPP_E164 ?? '+962788883007' }`.
   - Applies to **reads and writes alike** — a ban is total.
2. **Ban supersedes restriction** — the guard runs before the interceptor.
3. `banUser(userId, reason, adminId)` (`admin/admin-ban.service.ts:147-207`),
   **not wrapped in a transaction**:
   1. `404 "User not found"` if absent; `400 "User is already banned"` if
      `bannedAt != null`.
   2. `users.bannedAt = now`, `users.banReason = reason`.
   3. Cancel every booking of that user with status ∈ `{pending, confirmed}` →
      `status='cancelled'`, `cancelledAt=now`, `cancelledBy='admin_ban'`,
      `cancellationReason='Account banned by admin'`.
   4. Cancel every trip they authored with status ∈ `{published, fully_booked}` →
      `status='cancelled'`; for each such trip, cancel all its **confirmed**
      bookings (`cancelledBy='admin_ban_driver'`,
      `cancellationReason='Trip cancelled — driver account banned'`) and push
      `type='trip_cancelled_by_admin'`, title `Trip Cancelled`, body
      `Your trip to <toName> has been cancelled`, `data:{screen:'home',tripId}`
      to each affected passenger (push failures are warn-logged, not fatal).
   5. Revoke every `user_devices` row with `status='active'` →
      `status='revoked'`, `revokedAt=now`,
      `revokeReason = 'account_banned: <reason>'`.
   6. Append `security_events` — `eventType='account_banned'`,
      `adminActorId=<admin>`, `metadata={reason, cancelledBookings,
      cancelledTrips, revokedDevices}`.
   7. Fire-and-forget `notificationsService.notifyUserBanned(userId, reason)`.
   8. Structured log line `{"event":"admin.ban", …}`.
4. `unbanUser(userId, adminId)`:
   - `404` if absent; `400 "User is not banned"` if `bannedAt == null`.
   - Clears `bannedAt` and `banReason` **only**. Cancelled bookings/trips are
     **not** restored and revoked devices are **not** reactivated.
   - Appends `security_events` `eventType='account_unbanned'`, `metadata={}`.
5. A banned user's tokens are not revoked — they simply 403 on every call.

**Data model:** `users.bannedAt` / `banReason`; `bookings`; `trips`;
`user_devices.status`; `security_events`.

**State machine:**

```
 active --POST /admin/users/:id/ban--> banned  (bannedAt set; bookings+trips cancelled; devices revoked)
 banned --POST /admin/users/:id/unban--> active (bannedAt cleared ONLY — cascade not reversed)
 banned --POST .../ban again--> 400 "User is already banned"
 active --POST .../unban--> 400 "User is not banned"
```

**External services used:** FCM push via `NotificationsService`.

**Background jobs / scheduled tasks:** none.

**Errors:** `403 {code:'ACCOUNT_BANNED', …}` on every request from a banned user;
`404 User not found`; `400 User is already banned` / `User is not banned`;
`400` on a non-UUID `:id` (from `ParseUUIDPipe`).

**Notes for reimplementation:**

- Wrap the cascade in a transaction — today a mid-cascade failure leaves the user
  banned with bookings still live.
- Consider revoking tokens (or bumping `passwordChangedAt`) so the ban takes
  effect on WebSocket connections too — `WsAuthGuard` never reads `bannedAt`.

---

## F-11: Account flags & the security-event audit trail

**What it does:** Maintains a reviewable queue of risk flags raised against
accounts, and an append-only log of security-relevant actions, with admin
endpoints to triage them.

**Actors:** system (writers); admin (readers/triage)

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/account-flags` | Bearer JWT + `role=admin` | List flags (filterable, paginated) |
| PATCH | `/api/v1/admin/account-flags/:flagId/resolve` | admin | Mark a flag resolved |
| PATCH | `/api/v1/admin/account-flags/:flagId/dismiss` | admin | Mark a flag dismissed |
| DELETE | `/api/v1/admin/devices/:deviceId/revoke` | admin | Revoke a device session with audit |

**Request / Response contracts:**

`GET /admin/account-flags?userId=&disposition=&limit=&offset=`

- `userId` — string (no UUID validation)
- `disposition` — `open|resolved|dismissed`
- `limit` — default **50**; `offset` — default **0**
- Response `200`: `{ flags: AccountFlagEntity[], total: number }`, ordered
  `createdAt DESC`.

`PATCH /admin/account-flags/:flagId/resolve` — `:flagId` via `ParseUUIDPipe`;
body `{ notes?: string }` (raw `@Body('notes')`, **no DTO, no validation**).
Sets `disposition='resolved'`, `resolvedByAdminId=<admin>`, `resolvedAt=now`,
and overwrites `notes` only when a truthy `notes` was supplied.
Response `200`: the saved `AccountFlagEntity`.

`PATCH …/dismiss` — identical but `disposition='dismissed'`.

`DELETE /admin/devices/:deviceId/revoke` — `:deviceId` via `ParseUUIDPipe`; body
`{ reason?: string }` (raw). `404 "Device not found"` if absent; otherwise
`revokeDevice(deviceId, reason ?? 'admin_revoke')` and a
`device_revoked_by_admin` security event carrying `deviceId`, `adminActorId` and
`metadata:{reason}`. Response `200`: the revoked `UserDeviceEntity`.

**Business rules & validation:**

1. Flag writers:
   - `AccountRiskService` — `multi_account_device`, severity `high` (F-09), **no
     duplicate guard**.
   - `LocationGuardInterceptor` (`common/interceptors/location-guard.interceptor.ts`)
     — applies only to the WebSocket `driver:location:update` handler:
     - Passes through unless `context.getType()==='ws'`,
       `data.isMockLocation` truthy and `client.data.userId` present.
     - Always appends `security_events` `eventType='mock_location_rejected'`,
       `metadata={tripId, latitude, longitude}`.
     - Counts `mock_location_rejected` events for the user in the last
       **`MOCK_WINDOW_DAYS = 30`** days; if `>= MOCK_FLAG_THRESHOLD = 3` **and**
       no `open` flag with `reason='mock_location_repeated'` already exists,
       inserts one with severity `high` and notes
       `"<n> mock-location events detected within 30 days."`
     - Always throws `WsException({ code:'LOCATION_INTEGRITY_VIOLATION',
       message:'Mock location detected. Location update rejected.' })`.
2. Flag triage is a **one-shot state change**: `resolve`/`dismiss` do not check
   the current disposition, so an already-resolved flag can be re-resolved (each
   time re-stamping `resolvedByAdminId`/`resolvedAt` and appending another
   security event).
3. `security_events` rows are only ever inserted — no update or delete path
   exists in application code.
4. `correlationId` was added for request tracing but **no writer populates it**.

**Data model:** `account_flags` (§3.7), `security_events` (§3.8),
`user_devices` (revoke).

**State machine (`account_flags.disposition`):**

```
        (insert)
           |
           v
         open --resolve--> resolved  --(resolve/dismiss again: allowed)--> ...
           `---dismiss--> dismissed  --(resolve/dismiss again: allowed)--> ...
```

**External services used:** none.

**Background jobs / scheduled tasks:** none — flags are never auto-expired.

**Errors:** `404 Account flag not found`, `404 Device not found`,
`400` on non-UUID params, `403` from `RolesGuard` for non-admins.

**Notes for reimplementation:**

- Give `notes`/`reason` proper DTOs — they are currently unvalidated raw body
  fields going straight into `text` columns.
- Add a disposition precondition (`400 ALREADY_DECIDED` — the code constant
  already exists at `common/errors/error-codes.ts:90`).
- Populate `correlationId` from `X-Request-ID` as the migration intended.

---

## F-12: Authorization primitives (guards, decorators, roles)

**What it does:** Provides the cross-cutting authorisation machinery every other
feature depends on: default-deny authentication, role checks, the public
escape-hatch, the current-user parameter decorator, and rate limiting.

**Actors:** system

**API Endpoints:** none.

**Components:**

| Component | File | Behaviour |
|---|---|---|
| `@Public()` | `common/decorators/public.decorator.ts` | `SetMetadata('isPublic', true)`. Read by `JwtAuthGuard` and `BanGuard` via `reflector.getAllAndOverride(IS_PUBLIC_KEY, [handler, class])` |
| `@Roles(...roles: string[])` | `common/decorators/roles.decorator.ts` | `SetMetadata('roles', roles)` |
| `@CurrentUser(field?)` | `common/decorators/current-user.decorator.ts` | Returns `req.user` (http) or `client.user` (ws). With `'id'` it falls back to `user._id` and stringifies — a Mongoose leftover. With any other key it returns `user[key]` |
| `JwtAuthGuard` | `common/guards/jwt-auth.guard.ts` | Global. Passport `'jwt'`. Public → allow. Failure → `401 "Invalid or expired token"` |
| `BanGuard` | `common/guards/ban.guard.ts` | Global. See F-10 |
| `RolesGuard` | `common/guards/roles.guard.ts` | Global. No `@Roles` metadata (or empty array) → allow. `!user` or `!user.role` → `403 "User role not found"`. Role not in the list → `403 "Access denied. Required roles: <comma-list>"` |
| `ThrottlerGuard` | `@nestjs/throttler` | Global, 200 req / 60 s |
| `WsAuthGuard` | `common/guards/ws-auth.guard.ts` | Opt-in per gateway. See F-05 rule 7 |
| `WsRateLimitGuard` | `common/guards/ws-rate-limit.guard.ts` | In-memory sliding bucket: **180 events / 60 000 ms** keyed by `client.data.userId` → `client.user.id` → `handshake.address` → `'anonymous'`. Over limit → `BadRequestException("Too many websocket events, try again shortly")` |
| `SecurityService` | `modules/security/security.service.ts` | In-memory abuse counter: `registerAction(key, maxPerWindow = 30)` over a **60 000 ms** window, returns `false` once exceeded. **Exported by `SecurityModule` but injected by nobody — dead code.** |
| `RestrictedAccountInterceptor` | `common/interceptors/restricted.interceptor.ts` | Global. See F-09 rule 8 |

**Business rules & validation:**

1. Default-deny: the global `JwtAuthGuard` means an undecorated route requires a
   valid Bearer token.
2. `@Roles` is enforced by a **global** `RolesGuard`, so putting `@Roles('admin')`
   on a controller class is sufficient — `@UseGuards(RolesGuard)` is redundant
   (both styles appear in the codebase).
3. Role comparison is a plain string equality against `user.role`; there is no
   hierarchy (an `admin` does **not** satisfy `@Roles('driver')`).
4. Both the in-memory limiters (`WsRateLimitGuard`, `SecurityService`) are
   per-process `Map`s with **no eviction** — they leak memory over time and do
   not work across replicas.

**Data model:** none.

**Errors:** `401 Invalid or expired token`, `403 User role not found`,
`403 Access denied. Required roles: …`, `423 {code:'ACCOUNT_RESTRICTED'}`,
`403 {code:'ACCOUNT_BANNED'}`, `429` (throttler).

**Notes for reimplementation:**

- Replace the in-memory limiters with Redis-backed ones (Redis is already a
  dependency for BullMQ).
- Delete `SecurityService` and bound `WsRateLimitGuard`'s map.

---

## F-13: User profile read & update

**What it does:** Exposes the caller's own profile, lets them edit it, lets them
switch role, registers a legacy FCM token, and exposes other users' profiles and
(stub) statistics.

**Actors:** any authenticated user

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/users/me` | Bearer JWT | Return the authenticated user |
| PATCH | `/api/v1/users/me` | Bearer JWT (+ throttle 30/min) | Update own profile |
| PATCH | `/api/v1/users/me/role` | Bearer JWT + `@Roles(passenger, driver)` | Change own role |
| PATCH | `/api/v1/users/me/fcm-token` | Bearer JWT | Store a legacy single FCM token |
| GET | `/api/v1/users/:id` | Bearer JWT | Fetch any user by id |
| GET | `/api/v1/users/:id/stats` | Bearer JWT | Fetch user statistics |

**Request / Response contracts:**

`GET /users/me` → returns `req.user` verbatim: the full `UserEntity` minus the
three `select:false` columns (`passwordHash`, `fcmToken`, `refreshToken`).
Includes `bannedAt`, `banReason`, `restricted`, `walletBalance`, etc.

`PATCH /users/me` — `UpdateUserDto` (`users/dto/update-user.dto.ts`), all optional:

| Field | Type | Rules |
|---|---|---|
| `name` | string | `@MinLength(2)`, `@MaxLength(100)` |
| `photoUrl` | string | `@MaxLength(500)` |
| `gender` | string | `@IsIn(['male','female'])` |
| `city` | string | `@MaxLength(64)` |
| `hidePhoneNumber` | boolean | `@IsBoolean` |

Response `200`: the saved `UserEntity`.

`PATCH /users/me/role` and `PATCH /users/me/fcm-token` share
`UpdateProfileDto` (`users/dto/update-profile.dto.ts`):
`{ role?: UserRole, fcmToken?: string }` where `UserRole` is the **Mongoose**
enum `passenger|driver|admin`.

- `me/role`: if `role` present → `updateRole`; else return the current user
  unchanged.
- `me/fcm-token`: if `fcmToken` present → `updateFcmToken` and return
  `{ message: 'FCM token updated' }`; else `400 "FCM token is required"`.

`GET /users/:id` → the full `UserEntity` of **any** user (no relationship check).
`GET /users/:id/stats` → `{ totalTrips: 0, totalBookings: 0, completedTrips: 0,
rating, totalRatings, memberSince }` — **the first three are hardcoded zeros**
(`users.service.ts:126-136`).

**Business rules & validation:**

1. Route order matters: `@Get('me')` is declared before `@Get(':id')`, so `me` is
   not swallowed by the param route.
2. `update` merges the DTO into the loaded entity, except `city`, which is
   normalised: trimmed, and an empty/whitespace string becomes `null`
   (`users.service.ts:66-80`).
3. `updateRole(id, role)` performs a bare `user.role = role as PgUserRole` and
   saves — **no validation that the target role is allowed**.
   > 🔴 **Privilege-escalation bug.** `UpdateProfileDto.role` is
   > `@IsEnum(UserRole)` where `UserRole` includes `'admin'`
   > (`users/schemas/user.schema.ts:6-10`), and `RolesGuard` only checks that the
   > *caller* is a passenger or driver. A passenger can therefore
   > `PATCH /api/v1/users/me/role {"role":"admin"}` and become an administrator.
   > Verify: `users.controller.ts:53-66` + `users.service.ts:82-86` +
   > `users/dto/update-profile.dto.ts:5-7`. A rebuild must restrict this endpoint
   > to `passenger <-> driver`.
4. `GET /users/:id` leaks `phoneNumber`, `email`, `city`, `walletBalance`,
   `bannedAt`, `restricted` … to any authenticated caller. There is no
   serializer.
5. Throttle override: only `PATCH /users/me` narrows the limit
   (`@Throttle({ default: { ttl: 60000, limit: 30 } })`).
6. `updateFcmToken` writes the legacy `users.fcmToken` column, which is separate
   from both `device_tokens` (F-17) and `user_devices.fcmToken` (F-08).

**Data model:** `users`.

**External services / jobs:** none.

**Errors:** `404 "User not found"` (from `findById`),
`400 "FCM token is required"`, `403` from `RolesGuard` on `me/role` for admins
(an admin is neither passenger nor driver), validation `400`s.

**Notes for reimplementation:**

- Fix the role-escalation hole first.
- Add a response serializer for `GET /users/:id`.
- `getUserStats` is a stub — either implement it against `trips`/`bookings` or
  drop it.

---

## F-14: Account self-deletion

**What it does:** Lets a signed-in user permanently delete their account.

**Actors:** any authenticated user

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| DELETE | `/api/v1/auth/delete-account` | Bearer JWT | Hard-delete the caller's account |

**Request / Response contracts:** no body. Response `200`:
`{ message: "Account deleted successfully" }`.

**Business rules & validation:**

1. `usersService.delete(id)` → `userRepo.delete(id)`; `affected === 0` →
   `404 "User not found"` (`users.service.ts:118-123`).
2. **Hard delete** — the row is removed. Cascades follow the FK definitions:
   `device_tokens` (CASCADE), `user_devices` (CASCADE), `account_flags`
   (CASCADE), `security_events.userId` → **SET NULL** (the audit trail survives,
   anonymised).
3. Other domains' FKs decide whether the delete succeeds at all — e.g.
   `trips.driverId` is `ON DELETE RESTRICT` (`1700000000000-initialize-postgres.ts`),
   so a driver with any trip row will get a **500** foreign-key violation rather
   than a clean error.
4. No confirmation step, no password/OTP re-authentication, no grace period, no
   anonymisation of chat/booking history.
5. No notification, no security event, no admin audit row is written.

**Data model:** `users` (delete) + all cascading children.

**External services / jobs:** none.

**Errors:** `404 "User not found"`; unhandled `500` on FK restriction.

**Notes for reimplementation:**

- Require re-authentication (password or fresh OTP).
- Prefer soft-delete/anonymisation given the RESTRICT FKs and the audit
  requirements.
- Emit a `security_events` row for the deletion.

---

## F-15: Legacy social-login phone linking (migration) and removed OAuth

**What it does:** Migrates accounts created through Google/Facebook OAuth onto
the phone-first model by having them verify a phone number and attach it to the
existing account. The OAuth sign-in endpoints themselves are retired.

**Actors:** authenticated legacy social user

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/link-phone` | Bearer JWT | Verify an OTP and attach the phone to the current account |
| POST | `/api/v1/auth/google` | `@Public` | **Gone** — always `410` |
| POST | `/api/v1/auth/facebook` | `@Public` | **Gone** — always `410` |
| POST | `/api/v1/auth/register` | `@Public` | **Gone** — always `410` |

**Request / Response contracts:**

`POST /auth/link-phone` — the controller reads two raw body fields
(`@Body('phoneNumber')`, `@Body('code')`) — **there is no DTO and therefore no
validation**: no E.164 check, no 6-digit check
(`auth.controller.ts:166-172`).
Response `200`: `{ message: "Phone linked successfully", isPhoneVerified: true }`.

`410` endpoints return `{ message: <text>, code: 'ENDPOINT_REMOVED' }`:

- `/auth/register`: `"Registration is completed through OTP verification only. Use /auth/send-otp then /auth/verify-otp."`
- `/auth/google`: `"Google OAuth has been removed for end users."`
- `/auth/facebook`: `"Facebook OAuth has been removed for end users."`

**Business rules & validation:**

1. `verifyPhoneOtp(phoneNumber, code)` — same OTP verification as everywhere
   else; failure → `401 "Invalid or expired OTP code"`.
2. `findByPhone(phoneNumber)`; if it resolves to a **different** user →
   `409 "رقم الهاتف مرتبط بحساب آخر"` (Arabic: "the phone number is linked to
   another account"). This is the only Arabic error message in the auth service.
3. `usersService.linkPhone(userId, phoneNumber)` re-checks the same condition
   (`409 "Phone number already linked to another account"`, English), then sets
   `phoneNumber` and `isPhoneVerified = true`.
4. > ⚠ **The endpoint never clears `users.pendingPhoneLink`**, despite the
   > controller doc-comment claiming "links the phone, and clears
   > pendingPhoneLink". Verify: `auth.service.ts:539-559` and
   > `users.service.ts:93-104` — neither writes `pendingPhoneLink`. So
   > `pendingPhoneLinkRequired` stays `true` in every future auth response for a
   > migrated user. A rebuild must set it to `false` here.
5. `users.lastSocialLoginAt` is likewise never written by any code path.
6. **Dead OAuth infrastructure** (present but unreachable):
   - `strategies/google.strategy.ts`, `strategies/facebook.strategy.ts` — full
     passport strategies that would create/link users via
     `UsersService.findByProviderId` / `linkProvider` / `create`. **Not listed in
     `AuthModule.providers`** (`auth.module.ts:367-373`), so passport never
     registers them.
   - `guards/google-auth.guard.ts`, `guards/facebook-auth.guard.ts` — never used.
   - `dto/social-login.dto.ts` (`{ idToken?, accessToken? }`) — never referenced.
   - `dto/sign-up.dto.ts` (`email/password/name/gender/phoneNumber/role`) —
     never referenced; the email sign-up path it belonged to is the `410`
     `/auth/register` route.
   - `UsersService.findByProviderId` / `linkProvider` are only called by the two
     dead strategies.

**Data model:** `users.phoneNumber`, `users.isPhoneVerified`
(and `pendingPhoneLink`, which *should* be cleared but isn't).

**State machine:**

```
 legacy social account {provider:'google'|'facebook', phoneNumber:NULL, pendingPhoneLink:true}
    | POST /auth/link-phone (valid OTP, phone unused)
    v
 {phoneNumber set, isPhoneVerified:true, pendingPhoneLink STILL true}   <- bug
```

**External services used:** Twilio Verify / local OTP.

**Errors:** `401 Invalid or expired OTP code`;
`409 رقم الهاتف مرتبط بحساب آخر`; `409 Phone number already linked to another
account`; `404 User not found`.

**Notes for reimplementation:**

- Add a DTO to `link-phone` and clear `pendingPhoneLink` inside the same update.
- Delete the OAuth strategies/guards/DTOs or wire them properly; today they only
  add attack surface via dummy default credentials.
- Keep the `410 ENDPOINT_REMOVED` responses if old mobile builds are still in the
  field.

---

## F-16: File uploads (identity documents, profile and vehicle images)

**What it does:** Accepts image/PDF uploads for profile photos, driver licences,
vehicle licences, car photos and payment proofs, stores them on the local disk,
and returns a URL that the API also serves statically.

**Actors:** anonymous with a driver-registration token (`/uploads/registration`);
any authenticated user; drivers only for `/uploads/car-image`.

**API Endpoints:** (all `multipart/form-data`, file field name **`file`**)

| Method | Path | Auth | Folder | Allowed MIME | Max size |
|---|---|---|---|---|---|
| POST | `/api/v1/uploads/registration` | `@Public` + `registrationToken` body field | `driver-registration` | jpeg, png, webp, pdf | 10 MB |
| POST | `/api/v1/uploads` | Bearer JWT | `general` | jpeg, png, webp, pdf | 10 MB |
| POST | `/api/v1/uploads/profile-image` | Bearer JWT | `profile-images` | jpeg, png, webp | 5 MB |
| POST | `/api/v1/uploads/license` | Bearer JWT | `licenses` | jpeg, png, pdf | 10 MB |
| POST | `/api/v1/uploads/vehicle-license` | Bearer JWT | `vehicle-licenses` | jpeg, png, pdf | 10 MB |
| POST | `/api/v1/uploads/car-image` | Bearer JWT + `@Roles('driver')` | `car-images` | jpeg, png, webp | 10 MB |
| POST | `/api/v1/uploads/payment-proof` | Bearer JWT | `payment-proofs` | jpeg, png | 5 MB |
| DELETE | `/api/v1/uploads/:key` | Bearer JWT | — | — | — |

**Request / Response contracts:**

Success `201` (Nest's default for `@Post` without `@HttpCode`) wrapped in the
transform envelope:

```json
{ "success": true, "data": { "url": "http://host/uploads/<folder>/<uuid><ext>", "key": "<folder>/<uuid><ext>" } }
```

`DELETE /uploads/:key` → `200 { message: "File deleted" }`.

**Business rules & validation:**

1. Multer runs in **memory storage** with a hard `fileSize` limit of
   **10 MB** registered on the module (`uploads.module.ts:8-12`), so the 10 MB
   endpoints are also bounded by Multer itself; per-endpoint limits are checked
   again in the service.
2. `uploadFile(file, folder, allowedMimeTypes, maxSizeInBytes)`
   (`uploads.service.ts:27-54`):
   - MIME not in the allowlist → `400 "Invalid file type. Allowed types: <list>"`.
     **The check is on the client-supplied `mimetype`; file content is never
     sniffed.**
   - `file.size > max` → `400 "File size exceeds maximum allowed size of <n>MB"`.
   - Filename = `uuidv4() + path.extname(file.originalname)`; key =
     `<folder>/<filename>`. **The original extension is preserved verbatim** —
     an attacker controls it (e.g. `.php`, `.html`).
   - Writes `file.buffer` to `<cwd>/uploads/<folder>/<filename>`, creating the
     folder recursively; missing buffer → `400 "Failed to save file locally: File
     buffer is empty — Multer must use memory storage for local uploads"`.
   - Returns `{ url: "<SERVER_BASE_URL or http://localhost:<PORT|3003>>/uploads/<key>", key }`.
3. `/uploads/registration` authorisation (`uploads.controller.ts:75-97`):
   token required (`401 "Registration token is required"`), `JWT_ACCESS_SECRET`
   must be configured (`401 "Server auth is not configured"`), signature/expiry
   must verify (`401 "Registration session expired. Please verify your phone
   again."`), and `purpose` must equal `'driver_registration'`
   (`401 "Invalid registration token"`). The `phone` claim is **not** used or
   checked here.
4. `deleteFile(key, userId)` (`uploads.service.ts:89-99`) — the `userId`
   parameter is accepted and **never used**: there is **no ownership check**. Any
   authenticated user can delete any file whose key they can name. It also
   returns `{message:'File deleted'}` when the file does not exist.
   > ⚠ `path.join(this.localUploadPath, key)` with an unsanitised `key` is a
   > **path-traversal sink**; mitigated only accidentally by the fact that
   > `@Param('key')` on the route `:key` cannot match a value containing `/`,
   > which also means the endpoint **cannot delete any real key** (all keys are
   > `folder/file`). Verify: `uploads.controller.ts:288-304`.
5. Uploaded files are served publicly and unauthenticated from
   `/uploads/**` (`main.ts:18`) — driver licences and insurance documents are
   readable by anyone who learns the UUID filename.
6. `UploadUrlInterceptor` rewrites the origin of any `/uploads/…` or `/public/…`
   absolute URL in every response to the host the client used, so stale baked
   hosts still resolve. Pattern:
   `/^https?:\/\/[^/]+(\/(?:uploads|public)\/.*)$/i`.
7. **S3 is not used.** `config/s3.config.ts` is loaded and validated at boot but
   no S3 client exists anywhere in the service. Startup logs
   `📁 Upload mode: LOCAL STORAGE`.

**Data model:** none — the filesystem is the store. URLs are persisted as plain
strings on `users.photoUrl` and the `vehicles` document columns.

**External services used:** none (local disk).

**Background jobs / scheduled tasks:** none — orphaned files are never cleaned
up.

**Errors:** `400 No file uploaded`; `400 Invalid file type…`;
`400 File size exceeds…`; `400 Failed to save file locally: <reason>`;
`400 Failed to delete file`; `401` registration-token errors;
`403` from `RolesGuard` on `/uploads/car-image` for non-drivers.

**Notes for reimplementation:**

- Enforce ownership on delete; derive the extension from a sniffed content type;
  serve identity documents through an authenticated, signed-URL route rather than
  a public static mount.
- Consider object storage (the S3 config is already there).
- Note the `PORT` default mismatch: the app listens on `3000` but URL composition
  falls back to `3003` when `PORT` is unset.

---

## F-17: Push device tokens (FCM registration)

**What it does:** Registers, refreshes and deregisters the Firebase Cloud
Messaging tokens used to push notifications to a user's mobile devices and to the
admin dashboard's browser.

**Actors:** any authenticated user (mobile); admin (dashboard web token)

> These endpoints live in the notifications module but own the `device_tokens`
> table, which belongs to this domain's data model.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/notifications/devices` | Bearer JWT (throttle 30/min) | Register or refresh a mobile FCM token |
| DELETE | `/api/v1/notifications/devices/:token` | Bearer JWT (throttle 30/min) | Deregister on sign-out |
| POST | `/api/v1/notifications/web-token` | Bearer JWT (throttle 30/min) | Register a dashboard web token |
| DELETE | `/api/v1/notifications/web-token` | Bearer JWT (throttle 30/min) | Deregister a dashboard web token |

**Request / Response contracts:**

`POST /notifications/devices` — `RegisterDeviceDto`:

| Field | Type | Rules |
|---|---|---|
| `token` | string | `@IsNotEmpty`, `@MaxLength(512)` |
| `platform` | string | `@IsIn(['android','ios'])` |
| `appVersion` | string | optional, `@MaxLength(32)` — **accepted and discarded** |

Response: **`201`** when a new row was inserted, **`200`** when an existing row
was refreshed (the status is set imperatively on the response object), body
`{ registered: true, platform, lastSeenAt: <ISO8601> }`.

`DELETE /notifications/devices/:token` → **`204 No Content`**, empty body.

`POST|DELETE /notifications/web-token` — `WebTokenDto` `{ token, userAgent? }`
→ `200 { ok: true }`.

**Business rules & validation:**

1. `registerDevice` (`notifications.service.ts:339+`) is keyed on the **token
   alone** (`findOne({ where: { token } })`), which matches the unique index.
   An existing row is **re-assigned to the calling user** (`existing.userId =
   userId`), with `platform`, `isActive=true`, `lastSeenAt=now` refreshed.
   > This is how token hand-over between accounts on one phone is handled: the
   > previous owner silently loses the token.
2. `deregisterDevice` requires the token to exist **and** belong to the caller,
   else `404 "Device token not found"`. It is a **soft delete**
   (`isActive = false`); the row and its unique token remain.
3. `registerWebToken` upserts with `platform='web'` and stores `userAgent`
   (preserving the previous value when the new one is absent).
   `deregisterWebToken` is a scoped soft delete:
   `UPDATE device_tokens SET isActive=false WHERE userId=? AND token=? AND platform='web'`.
4. Both register/deregister emit an audit event via `AuditService`
   (`action: 'device.register' | 'device.deregister'`) and a structured log line,
   both carrying only a **token prefix** (`token.slice(0,8) + '…'`).
5. Three unrelated FCM token stores coexist and are never reconciled:
   `users.fcmToken` (legacy, F-13), `device_tokens.token` (this feature),
   `user_devices.fcmToken` (F-08).

**Data model:** `device_tokens` (§3.6).

**State machine:** `isActive: true <-> false` (register reactivates, deregister
deactivates). Rows are never deleted.

**External services used:** Firebase Cloud Messaging (delivery side, other
domain). Env: `FIREBASE_SERVICE_ACCOUNT_PATH`, `FIREBASE_PROJECT_ID`,
`FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`,
`FIREBASE_WEB_MESSAGING_SENDER_ID`.

**Background jobs / scheduled tasks:** none — stale tokens accumulate.

**Errors:** `404 Device token not found`; validation `400`s; `429` at >30/min.

**Notes for reimplementation:** collapse the three token stores into one;
prune tokens FCM reports as unregistered.

---

## F-18: Admin account provisioning and driver approval

**What it does:** Creates the first administrator out-of-band, and gives admins
the ability to confirm accounts, approve or reject drivers, list users and delete
accounts.

**Actors:** operator (CLI seed); admin (HTTP)

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| PATCH | `/api/v1/admin/users/:id/confirm` | Bearer JWT + `role=admin` | Force-verify an account |
| PATCH | `/api/v1/admin/users/:id/approve-driver` | admin | Approve / reject a driver |
| DELETE | `/api/v1/admin/users/:id` | admin | Delete a user |
| GET | `/api/v1/admin/users` | admin | Paginated user list |

**Request / Response contracts:**

`PATCH /admin/users/:id/confirm` → sets `isActive=true`,
`isPhoneVerified=true`, `isEmailVerified=true`, sends an `account_verified`
notification, returns the `UserEntity`.

`PATCH /admin/users/:id/approve-driver` — body `ApproveDriverDto`
(`admin/dto/admin-query.dto.ts:122-125`): `{ approved: boolean }` (`@IsBoolean`).
Response `200`: `{ message: 'Driver approval status updated', user }`.

`DELETE /admin/users/:id` → `{ success: true, data: { message: 'User deleted' } }`
(double-wrapped by the transform interceptor).

`GET /admin/users?page&limit&role&search&isActive&registeredWithinDays&isConfirmed`
→ paginated, with an explicit column projection that excludes
`passwordHash`/`refreshToken`.

**Business rules & validation:**

1. **Seeding** (`rideshare-backend/seed-admin.ts`, a standalone
   `NestFactory.createApplicationContext` script):
   - No-op if any row with `role='admin'` already exists.
   - Otherwise inserts `email = ADMIN_EMAIL ?? 'admin@rideshare.com'`,
     `passwordHash = bcrypt(ADMIN_PASSWORD ?? 'Admin@123456', 12)`,
     `name = ADMIN_NAME ?? 'System Admin'`,
     `phoneNumber = ADMIN_PHONE ?? '+201000000000'`, `provider='email'`,
     `isEmailVerified=true`, `isPhoneVerified=true`, `isActive=true`,
     `rating=0`, `totalRatings=0`, and prints the credentials to stdout.
2. `approveDriver(userId, approved)`
   (`admin/admin-dashboard.service.ts:247-274`):
   - `404 "User not found"`.
   - `user.role !== 'driver'` → `400 "User is not a driver"`.
   - `approved === true && !user.photoUrl` → `400 "Driver profile photo is
     required before approval"` (the `PROFILE_PHOTO_REQUIRED` error code exists
     but is not attached to this response).
   - Writes `isDriverApproved = approved` and sends an Arabic notification
     (`driver_approved` / `driver_rejected`).
   - Rejection is **not** terminal: it just sets the flag back to `false`; the
     driver can amend via `PATCH /auth/driver/registration` (F-03) and be
     re-approved.
3. `deleteUser` — rejects a non-UUID id
   (`/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i`)
   with `400 "Invalid user ID"`, `404` if absent,
   `400 "Cannot delete admin users"` if `role='admin'`, then `repo.remove(user)`
   (same FK caveats as F-14).
4. `getUsers` clamps `page >= 1` and `limit` to `[1, 100]` (default 20).

**Data model:** `users`, `notifications`.

**State machine (driver approval):**

```
 isDriverApproved:false --approve-driver{approved:true} (requires photoUrl)--> true
 isDriverApproved:true  --approve-driver{approved:false}--> false
```

**External services used:** FCM via `NotificationsService.create`.

**Background jobs / scheduled tasks:** none.

**Errors:** `404 User not found`; `400 User is not a driver`;
`400 Driver profile photo is required before approval`; `400 Invalid user ID`;
`400 Cannot delete admin users`; `403` for non-admins.

**Notes for reimplementation:**

- The seed script prints the default password to stdout — force a rotation on
  first login.
- There is **no admin-specific password reset**: `/auth/forgot-password` is
  phone-keyed, so an admin whose row carries a phone number can use it, but the
  OTP goes to that phone.

---

## 4. Dead / legacy code inventory (explicit)

| Item | Location | Status |
|---|---|---|
| `AdminService` + `AdminController` | `modules/admin/admin.service.ts`, `admin.controller.ts` | **Not registered** in `AdminModule` (`admin.module.ts:76-93`). Entirely Mongoose-based. Its `approveDriver`, `seedAdminUser` bootstrap (`OnModuleInit`) etc. never run. Superseded by `AdminDashboardService`. |
| `seeds/admin.seed.ts` | `modules/admin/seeds/` | Mongoose. Only referenced by the dead `AdminService`. The live equivalent is the root `seed-admin.ts`. |
| Mongoose schemas | `modules/users/schemas/*.ts` | No `MongooseModule` anywhere. Kept only for the `UserRole` / `AuthProvider` / `Gender` enums that live code imports. |
| `PendingRegistrationEntity` + `pending_registrations` table | `database/entities/`, migration `1738900000000` | Registered with TypeORM, **zero repository usage**. Replaced by the registration-JWT flow. |
| `GoogleStrategy`, `FacebookStrategy`, `GoogleAuthGuard`, `FacebookAuthGuard`, `SocialLoginDto` | `modules/auth/strategies/`, `guards/`, `dto/` | Not in `AuthModule.providers`; endpoints return `410`. |
| `SignUpDto` | `modules/auth/dto/sign-up.dto.ts` | Unreferenced; belonged to the removed `/auth/register`. |
| `JwtRefreshStrategy` | `modules/auth/strategies/jwt-refresh.strategy.ts` | Registered as a provider but no guard uses `'jwt-refresh'`. Its `validate()` is unfinished (the comments admit it). |
| `SecurityService` / `SecurityModule` | `modules/security/` | Exported, injected nowhere. |
| `jwtConfig` (`JWT_SECRET`, `JWT_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`) | `config/jwt.config.ts` | Validated at boot, read by nothing. Actual secrets are the flat `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`; TTLs are hardcoded. |
| `s3Config` (`AWS_*`) | `config/s3.config.ts` | Validated at boot; `UploadsService` is local-disk only. |
| `twilioConfig.TWILIO_PHONE_NUMBER` | `config/twilio.config.ts` | Never read. |
| `OTP_DEV_BYPASS`, `MIN_APP_VERSION` | `config/configuration.ts` | Parsed, never read. |
| `UsersService.cleanupExpiredOtpCodes()` | `modules/users/users.service.ts:184` | No caller, no cron. |
| `users.lastSocialLoginAt` | entity + migration | Never written. |
| `security_events.correlationId` | entity + migration `1745913000000` | Never written. |
| `ErrorCodes.SELF_REVOKE_USE_LOGOUT`, `PROFILE_PHOTO_REQUIRED`, `CONTACT_ALREADY_USED_BY_OTHER` | `common/errors/error-codes.ts` | Defined; not emitted by any identity code path. |
| bcrypt | `auth.service.ts`, `users.service.ts`, `seed-admin.ts` | **Not** legacy — actively used at cost 12 for passwords and (pointlessly) for the stored refresh-token hash. |

---

## 5. Cross-cutting invariants a rebuild must preserve

1. Every non-`@Public` route requires a valid access token, then a non-banned
   user, then the role check, then the rate limit — in that order.
2. Success responses are always `{ success, data }`; errors always
   `{ success:false, error:{ code, message, details, timestamp, path, method } }`.
   `error.code` is the **HTTP status number**, while domain codes
   (`ACCOUNT_BANNED`, `ACCOUNT_RESTRICTED`, `ENDPOINT_REMOVED`, `NOT_FOUND`)
   appear inside `error.details` because they were the exception's response
   object.
3. Passwords: bcrypt cost **12**, policy regex
   `^(?=.*[A-Za-z])(?=.*\d).{8,}$` (≥8 chars, ≥1 letter, ≥1 digit), max 100
   chars at registration. Login imposes only `@MinLength(1)`.
4. Phone numbers: E.164 `^\+[1-9]\d{1,14}$`, stored verbatim, unique.
5. OTP: 6 digits (`^\d{6}$`) everywhere except `DriverVerifyPhoneDto`, which
   accepts `^\d{4,6}$`. Local TTL 5 minutes (**not enforced on lookup**);
   `expiresIn` is always reported as `300`.
6. Access token 15 min, refresh token 7 days, both HS256, both carrying
   `{sub, email, role, did}`.
7. Device fingerprint = `sha256("<platform>:<deviceId>:<installSalt>")` hex;
   raw device ids are never stored.
8. Setting `users.passwordChangedAt` is the only reliable global session kill
   switch.

---

## 6. Known defects summary (prioritised for a rebuild)

| # | Severity | Defect | Location |
|---|---|---|---|
| 1 | **Critical** | Any passenger/driver can self-promote to `admin` via `PATCH /users/me/role` | `users.controller.ts:53-66`, `users.service.ts:82-86`, `users/dto/update-profile.dto.ts` |
| 2 | High | Local-mode OTP codes never expire (no `expiresAt` filter, no cleanup job) | `users.service.ts:177-183` |
| 3 | High | Logout does not invalidate anything; the stored refresh-token hash is never compared | `auth.service.ts:531-535`, `users.service.ts:88-91` |
| 4 | High | `DELETE /uploads/:key` has no ownership check and joins an unsanitised path segment | `uploads.service.ts:89-99` |
| 5 | High | Identity documents are served publicly from `/uploads/**` | `main.ts:18` |
| 6 | Medium | `link-phone` has no DTO/validation and never clears `pendingPhoneLink` | `auth.controller.ts:166-172`, `auth.service.ts:539-559` |
| 7 | Medium | `forgot-password` enumerates registered phone numbers via `404` | `auth.service.ts:569-571` |
| 8 | Medium | The 5-attempt reset cap resets on every new `forgot-password` | `auth.service.ts:578-590` |
| 9 | Medium | Ban cascade is not transactional | `admin/admin-ban.service.ts:147-207` |
| 10 | Medium | `WsAuthGuard` performs no DB check — banned/inactive/revoked users keep their sockets | `common/guards/ws-auth.guard.ts` |
| 11 | Medium | No un-restrict endpoint; `users.restricted` is a one-way flag | `account-risk.service.ts:70` |
| 12 | Low | Multi-account risk check inserts duplicate flags/events on every re-verification | `account-risk.service.ts:56-90` |
| 13 | Low | Registration tokens share the access-token secret | `auth.service.ts:701-712` |
| 14 | Low | `GET /users/:id` returns the full user row to any authenticated caller | `users.controller.ts:83-90` |
| 15 | Low | `Math.random()` used for OTP generation | `auth.service.ts:112` |
