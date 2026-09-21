# 06 — Platform & Infrastructure (Rebuild Specification)

Cross-cutting platform layer of the Wisoway / Rideshare NestJS backend. Everything here is
grounded in the code at `d:\work\wisoway\rideshare-backend` (branch `009-platform-refinements`).
Business features live in sibling documents; this one covers bootstrap, config, data layer,
cross-cutting concerns, the notifications subsystem, background jobs, deployment and third-party
integrations.

Reference root for all relative paths below: `d:\work\wisoway\rideshare-backend`.

---

## 1. Runtime & Bootstrap

Source: `src/main.ts` (95 lines), `src/app.module.ts`.

### 1.1 Boot sequence (exact order in `main.ts`)

| # | Step | Detail |
|---|------|--------|
| 1 | Create app | `NestFactory.create<NestExpressApplication>(AppModule, { logger: ['error','warn','log','debug','verbose'] })` — **all** log levels enabled, including in production. |
| 2 | Static assets | `app.useStaticAssets(path.join(process.cwd(), 'uploads'), { prefix: '/uploads' })` |
| 3 | Static assets | `app.useStaticAssets(path.join(process.cwd(), 'public'),  { prefix: '/public' })` — serves the public trip-share page. |
| 4 | Security headers | `app.use(helmet())` — **default** helmet options, no customisation. |
| 5 | CORS | `app.enableCors({ origin: NODE_ENV==='production' ? ALLOWED_ORIGINS.split(',') ?? ['https://yourdomain.com'] : true, credentials: true })` |
| 6 | Global pipe | `new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true, transformOptions: { enableImplicitConversion: true } })` |
| 7 | Global prefix | `app.setGlobalPrefix(process.env.API_PREFIX || 'api/v1')` |
| 8 | Swagger | `DocumentBuilder` (see below) → `SwaggerModule.setup('api/docs', app, document)` |
| 9 | Listen | `app.listen(process.env.PORT || 3000, process.env.HOST || '0.0.0.0')` |

Swagger document: title `Rideshare Backend API`, description `API documentation for the Rideshare Backend Platform`,
version `1.0`, `addBearerAuth()`, tags: `auth, users, vehicles, trips, bookings, payments, chat,
ratings, notifications, uploads, locations, admin, health`. Served at `/api/docs` — **outside** the
global prefix (the prefix is not applied to the Swagger mount path).

### 1.2 Things that are NOT configured (verify: `src/main.ts` — absent)

- **No `app.enableShutdownHooks()`** → SIGTERM does not trigger Nest lifecycle teardown. Bull/TypeORM
  connections are closed only by process exit. In the container this is mitigated by `dumb-init`
  forwarding signals, but graceful drain is not implemented.
- **No `compression()` middleware** — gzip is done at the nginx edge instead (`gzip on` in `nginx.conf`).
- **No body-size override** — Express default `100kb` for JSON/urlencoded. File uploads bypass this via
  Multer (`MulterModule.register({ limits: { fileSize: 10 * 1024 * 1024 } })`, `src/modules/uploads/uploads.module.ts`).
  nginx allows `client_max_body_size 25M`. **Effective JSON limit is 100 KB.**
- **No `useWebSocketAdapter()`** — the default `IoAdapter` from `@nestjs/platform-socket.io` is used.
  Gateways declare their own namespaces; there is **no Redis Socket.IO adapter**, so WebSocket fan-out
  does not work across more than one backend replica (single-instance assumption).
- **No global timeout interceptor.**
- **No request-id middleware** — `LoggingInterceptor` generates one per request itself (see §4.3).

### 1.3 Global provider registration order (`src/app.module.ts` `providers[]`)

Guards (`APP_GUARD`), executed in registration order:

1. `JwtAuthGuard`
2. `BanGuard`
3. `RolesGuard`
4. `ThrottlerGuard`

→ Rate limiting happens **after** JWT verification and ban checks; an unauthenticated flood is rejected
by the JWT guard first, and throttle buckets are still IP-based (`@nestjs/throttler` default tracker).

Filters: `HttpExceptionFilter` (`APP_FILTER`, `@Catch()` — catches everything).

Interceptors (`APP_INTERCEPTOR`), registration order:

1. `TransformInterceptor`
2. `UploadUrlInterceptor`
3. `LoggingInterceptor`
4. `RestrictedAccountInterceptor`

Nest composes interceptors so the **first registered is outermost**. Request direction runs
1→4; response direction runs 4→1. Net effect on the response payload:

```
handler result
  → RestrictedAccountInterceptor (no map)
  → LoggingInterceptor (tap only)
  → UploadUrlInterceptor  (rewrites /uploads and /public origins on the RAW payload)
  → TransformInterceptor  (wraps into { success: true, data: <payload> })   ← applied last
```

Pipe: `APP_PIPE` → the **custom** `src/common/pipes/validation.pipe.ts`. This is in addition to the
built-in `ValidationPipe` registered in `main.ts`. **Both run** — the custom one first (APP_PIPE-scoped
pipes are appended to the global pipe list), so a DTO is validated twice with two different error
shapes. A reimplementation should pick one.

### 1.4 Root module imports

`ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env', load: [appConfig, databaseConfig,
jwtConfig, s3Config, redisConfig, twilioConfig, a2aCliqConfig, platformConfig] })`, then
`PostgresModule`, `ScheduleModule.forRoot()`, `ThrottlerModule.forRoot([{ ttl: 60000, limit: 200 }])`,
then 26 feature modules (`Health, Auth, Users, Uploads, Vehicles, Trips, Locations, Bookings, Payments,
ChatPostgres, Ratings, Notifications, Jobs, Admin, Tracking, Wallet, Security, Audit, PendingCharges,
TripTime, ShareLinks, Settlement, Calls, Complaints, Refunds, Support, InstantRides`).

Two in-code comments document deliberate decisions worth preserving:
- `ScheduleModule.forRoot()` was added late — before that **every `@Cron` in the repo was inert**.
- Throttling is a **single** bucket (`200 req / 60 s`); an earlier `20/min` bucket applied to all traffic,
  not just public APIs, and was removed.

### 1.5 Root endpoints

| Method | Path | Auth | Behaviour |
|--------|------|------|-----------|
| GET | `/api/v1/` | JWT required (no `@Public`) | `AppController.getHello()` → `AppService.getHello()` → literal `"Hello World!"`, wrapped by TransformInterceptor as `{ success: true, data: "Hello World!" }`. |
| GET | `/api/v1/health` | Public | `@nestjs/terminus` check returning `{ app: { status: 'up' } }` — a static literal, **it does not probe anything**. |
| GET | `/api/v1/health/db` | Public | `TypeOrmHealthIndicator.pingCheck('postgres')`. |

`GET /api/v1/health` is what the Dockerfile and docker-compose healthchecks hit.

---

## 2. Configuration System

Eight `registerAs` namespaces are loaded. **Important structural note:** `registerAs('x', …)` exposes
values at `config.get('x.KEY')`, *not* at `config.get('KEY')`. Most of the codebase calls
`configService.get('KEY')` directly (which falls through to raw `process.env`), so several namespaces
are effectively decorative — they only run validation at boot. Flagged per row below.

### 2.1 Master environment variable catalogue

| Env var | Namespace | Type | Default | Required | Read by | Notes |
|---|---|---|---|---|---|---|
| `NODE_ENV` | `app` | string | `development` | validated (string) | `main.ts:30`, `http-exception.filter.ts:33`, config validators | Drives CORS mode and stack-trace exposure |
| `PORT` | `app` | int | `3000` | validated | `main.ts:76`, `uploads.service.ts:16` | |
| `API_PREFIX` | `app` | string | `api/v1` | validated | `main.ts:49` | |
| `HOST` | — | string | `0.0.0.0` | no | `main.ts:77` | Not in any config namespace, not in `.env.example` |
| `ALLOWED_ORIGINS` | — | CSV | `['https://yourdomain.com']` | prod only | `main.ts:31` | Not in `.env.example` |
| `SERVER_BASE_URL` | — | string | `http://localhost:${PORT||3003}` | no | `uploads.service.ts:15` | Origin baked into new upload URLs |
| `SUPPORT_WHATSAPP_E164` | — | string | `+962788883007` | no | `ban.guard.ts:49`, `refunds.service.ts:28`, `support.controller.ts:34` | Hard-coded fallback number |
| `MONGODB_URI` | `database` | string | *(unset)* | optional | **`database.config.ts` only** + `scripts/backfill-mongo-to-postgres.ts:42` | **DEAD for runtime.** No Mongoose module is imported by `AppModule`. See §2.3 |
| `POSTGRES_HOST` | `database` | string | `localhost` | optional | `postgres.module.ts:48`, `data-source.ts:39` | |
| `POSTGRES_PORT` | `database` | numeric string | `5432` | optional | same | |
| `POSTGRES_USER` | `database` | string | `postgres` | optional | same | |
| `POSTGRES_PASSWORD` | `database` | string | `postgres` | optional | same | |
| `POSTGRES_DB` | `database` | string | `rideshare` | optional | same | |
| `POSTGRES_SSL` | `database` | boolean string | `false` | optional | same → `{ rejectUnauthorized: false }` when `'true'` | |
| `JWT_SECRET` | `jwt` | string | `your-jwt-secret-change-in-production` | validated | **nothing** | **DEAD.** Runtime reads `JWT_ACCESS_SECRET` (below) |
| `JWT_EXPIRES_IN` | `jwt` | string | `15m` | validated | `auth.service.ts` (via raw env) | |
| `JWT_REFRESH_SECRET` | `jwt` | string | `your-refresh-secret-change-in-production` | validated | `auth.service.ts:491,823`, `jwt-refresh.strategy.ts:18` (raw env) | |
| `JWT_REFRESH_EXPIRES_IN` | `jwt` | string | `7d` | validated | `auth.service.ts` | |
| `JWT_ACCESS_SECRET` | — | string | *(none — throws)* | **YES** | `jwt.strategy.ts:16`, `ws-auth.guard.ts:29`, `auth.service.ts:704,717,822`, `uploads.controller.ts:79`, JwtModule in notifications/chat/tracking/trips modules | **Not declared in `.env.example`** but present in the real `.env`. `jwt.strategy.ts` throws at boot if unset |
| `AWS_ACCESS_KEY_ID` | `s3` | string | `''` | validated | **nothing** | **DEAD** — see §2.3 |
| `AWS_SECRET_ACCESS_KEY` | `s3` | string | `''` | validated | nothing | DEAD |
| `AWS_S3_BUCKET` | `s3` | string | `rideshare-uploads` | validated | nothing | DEAD |
| `AWS_REGION` | `s3` | string | `me-south-1` | validated | nothing | DEAD |
| `REDIS_HOST` | `redis` | string | `localhost` | validated | `jobs.module.ts:15` (raw env) | |
| `REDIS_PORT` | `redis` | int | `6379` | validated | `jobs.module.ts:16` (raw env) | |
| `TWILIO_ACCOUNT_SID` | `twilio` | string | `''` | validated | `auth.service.ts:932` | |
| `TWILIO_AUTH_TOKEN` | `twilio` | string | `''` | validated | `auth.service.ts:935`, `calls.controller.ts:52` (webhook signature) | |
| `TWILIO_PHONE_NUMBER` | `twilio` | string | `''` | validated | Programmable-SMS fallback | |
| `TWILIO_VERIFY_SERVICE_SID` | `twilio` | string | `''` | validated | `auth.service.ts:98` | |
| `TWILIO_API_KEY_SID` | `twilio` | string | `''` | validated | `auth.service.ts:938` | |
| `TWILIO_API_KEY_SECRET` | `twilio` | string | `''` | validated | `auth.service.ts:941` | |
| `OTP_PROVIDER` | `twilio` | `'local'\|'twilio'` | `local` (lower-cased) | validated | `auth.service.ts:922` | `local` = code written to app log, no SMS |
| `A2A_CLIQ_BASE_URL` | `a2aCliq` | string | `https://api.uwallet.jo/A2AMerchantInterface` | prod only | `a2a-cliq.service.ts:57` | |
| `A2A_CLIQ_MERCHANT_ID` | `a2aCliq` | string | `''` | prod only | same | Sent as `MerchantID` header |
| `A2A_CLIQ_USER_ID` | `a2aCliq` | string | `''` | prod only | same | `UserID` header |
| `A2A_CLIQ_PASSWORD` | `a2aCliq` | string | `''` | prod only | same | `Password` header |
| `A2A_CLIQ_SECURITY_KEY` | `a2aCliq` | string | `''` | prod only | same | `GetToken` body |
| `A2A_CLIQ_CORRELATION_ID` | `a2aCliq` | string | `''` | prod only | same | `CorrelationID` header |
| `A2A_CLIQ_CALLBACK_URL` | `a2aCliq` | string | `https://example.com/api/v1/payments/cliq/callback` | prod only | same | |
| `BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS` | `platform` | int? | unset → 10 800 s (3 h) | optional | `bookings.service.ts:764,815` (raw env) | Test override |
| `NO_SHOW_GRACE_OVERRIDE_SECONDS` | `platform` | int? | unset → 1 800 s (30 min) | optional | documented in `no-show-detector.processor.ts:7`; **no live read found** | verify: `src/modules/bookings/processors/no-show-detector.processor.ts` |
| `PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS` | `platform` | int? | unset → 1 800 s (30 min) | optional | **no live read found** | DEAD |
| `OTP_DEV_BYPASS` | `platform` | bool | `false` | required-with-default | **no live read found** | DEAD |
| `SETTLEMENT_GRACE_SECONDS` | `platform` | int | `300` | required-with-default | **no live read found** | DEAD |
| `MIN_APP_VERSION` | `platform` | string? | unset (gate disabled) | optional | mentioned only in a comment at `trips.serializer.ts:11` | **DEAD — the version gate is not implemented** |
| `GOOGLE_PLACES_API_KEY` | `platform` | string? | unset | optional | **no live read found** | DEAD — autocomplete uses Photon |
| `FIREBASE_WEB_MESSAGING_SENDER_ID` | `platform` | string? | unset | optional | **no live read found** | Documentation-only |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | — | path | unset | no | `notifications.service.ts` `ensureFirebase()` | Preferred credential source |
| `GOOGLE_APPLICATION_CREDENTIALS` | — | path | unset | no | `ensureFirebase()` fallback #1 | |
| `FIREBASE_PROJECT_ID` | — | string | unset | no | `ensureFirebase()` fallback #2 | |
| `FIREBASE_CLIENT_EMAIL` | — | string | unset | no | same | |
| `FIREBASE_PRIVATE_KEY` | — | PEM | unset | no | same | Normalised: trimmed, surrounding `"` stripped, `\n` → newline |
| `GOOGLE_MAPS_API_KEY` | — | string | `''` | no | `locations.service.ts:85` | Directions API; falls back to OSRM when empty |
| `PHOTON_BASE_URL` | — | url | `https://photon.komoot.io` | no | `locations.service.ts` | **Not in `.env.example`** |
| `GEOCODER_USER_AGENT` | — | string | `WisowayRideshare/1.0 (+https://wisoway.app)` | no | `locations.service.ts` | **Not in `.env.example`** |
| `NOMINATIM_BASE_URL` | — | — | — | — | **nothing** | `.env.example` documents it; code uses `PHOTON_BASE_URL`. STALE |
| `NOMINATIM_USER_AGENT` | — | — | — | — | **nothing** | STALE; superseded by `GEOCODER_USER_AGENT` |
| `LOCATION_AUTOCOMPLETE_COUNTRIES` | — | CSV (max 5) | `''` (global) | no | `locations.service.ts:99` | |
| `TRIP_AUTO_COMPLETE_FALLBACK_HOURS` | — | number | `24` (min 1) | no | `trips/trip-auto-start.util.ts:18` | **Not in `.env.example`** |
| `DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES` | — | number | `60` | no | `driver-trip-fee-reconciliation.job.ts` | Read at call time, not decoration time |
| `DRIVER_TRIP_FEE_RECONCILE_LOOKBACK_HOURS` | — | number | `72` | no | same | |
| `DRIVER_TRIP_FEE_RECONCILE_BATCH` | — | number | `100` | no | same | |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | — | string | — | no | `auth/strategies/google.strategy.ts` | OAuth |
| `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` | — | string | — | no | `auth/strategies/facebook.strategy.ts` | OAuth |
| `POSTGRES_PORT`, `REDIS_PORT`, `EDGE_HTTP_PORT`, `EDGE_HTTPS_PORT`, `VITE_API_BASE_URL`, `VITE_WS_URL` | — | — | see compose | no | `docker-compose.yml` only | Compose-level, not read by the app |

### 2.2 Validation semantics

All eight namespaces use `class-transformer` `plainToClass` + `class-validator` `validateSync`:

| Namespace | Failure behaviour |
|---|---|
| `app` | throws at boot always |
| `database` | throws at boot always (all fields `@IsOptional`, so effectively never) |
| `jwt` | throws at boot always (all fields have defaults, so never) |
| `s3` | throws at boot always (all fields default to `''`, so never) |
| `redis` | throws at boot always |
| `twilio` | throws at boot always (defaults `''`, so never) |
| `a2aCliq` | **throws only when `NODE_ENV === 'production'`** |
| `platform` | `validateSync(config, { skipMissingProperties: true })`; throws `Platform configuration validation failed: …` |

Because every field carries a default, **no namespace can actually fail validation in practice** except
`a2aCliq` in production and `platform` on a malformed integer. There is no "required secret missing"
guard — the only hard boot failure is `JWT_ACCESS_SECRET` being unset (thrown by `jwt.strategy.ts`).

### 2.3 Dead / stale configuration (confirmed by grep over `src/`)

| Item | Evidence |
|---|---|
| **MongoDB is not used at runtime** | `MongooseModule` appears only in `src/modules/chat/chat.module.ts` (not imported by `AppModule`; `ChatPostgresModule` is), `src/jobs/notification-cleanup.job.ts`, `src/jobs/trip-expiration.job.ts` (neither is in any `providers[]`), `src/modules/admin/admin.service.ts` (not in `AdminModule.providers`), and legacy `*.schema.ts` files. `MONGODB_URI` is only read by the one-off backfill script. `mongoose@^9.2.1` + `@nestjs/mongoose@^11.0.4` can be dropped. |
| **AWS S3 is not used** | No file imports `@aws-sdk/client-s3`. `UploadsService` is local-disk only and logs `📁 Upload mode: LOCAL STORAGE`. The whole `s3` namespace and all four `AWS_*` vars are inert. |
| **`@googlemaps/google-maps-services-js` is not used** | No imports. `LocationsService` calls `https://maps.googleapis.com/maps/api` directly with `axios`. |
| **`winston` / `nest-winston` are not used** | No imports; logging is Nest's built-in `Logger`. |
| **`multer` is imported only via `@nestjs/platform-express`** | `MulterModule` is used; the raw package is not imported. |
| **`axios` and `uuid` are used but absent from `package.json`** | `a2a-cliq.service.ts`, `locations.service.ts` import `axios`; `uploads.service.ts` imports `uuid`. Both resolve transitively (axios via `twilio`). A rebuild must declare them explicitly. |
| **`JWT_SECRET` vs `JWT_ACCESS_SECRET`** | `.env.example` ships `JWT_SECRET`; every runtime consumer reads `JWT_ACCESS_SECRET`. Copying `.env.example` verbatim produces a non-booting app. |
| **`NOMINATIM_*` env vars** | Documented in `.env.example`, superseded in code by `PHOTON_BASE_URL` / `GEOCODER_USER_AGENT`. |

---

## 3. Data Layer

### 3.1 TypeORM — runtime connection (`src/database/postgres.module.ts`)

```
type:             'postgres'
host/port/user/password/database: POSTGRES_* (defaults localhost:5432/postgres/postgres/rideshare)
ssl:              POSTGRES_SSL === 'true' ? { rejectUnauthorized: false } : false
synchronize:      false            ← never auto-syncs
autoLoadEntities: true
entities:         explicit array of 35 entity classes (also listed, redundant with autoLoad)
```

- **No `migrationsRun`** → migrations are **not** applied at boot. They must be run manually:
  `npm run db:migration:run`.
- **No naming strategy override** → TypeORM's `DefaultNamingStrategy`. Entities declare explicit
  `@Entity({ name: 'snake_case_plural' })` table names and **camelCase quoted column names**
  (`"userId"`, `"createdAt"`, `"lastSeenAt"`). Any reimplementation must quote identifiers.
- **No connection-pool configuration** → node-postgres default (`max: 10` clients per pool).
- **No query logging, no `extra` options, no `retryAttempts` override** (Nest default: 10 retries, 3 s delay).

Entity set registered at runtime (35): `AccountFlag, AdminAlertPreference, Booking, BookingSeat,
CallSession, ChatRoom, CommunicationFee, Complaint, DeviceToken, DriverAvailability, DriverLocation,
InstantRideOffer, InstantRideRequest, Message, Notification, OtpCode, PasswordResetSession, Payment,
PayoutRequest, PendingCharge, PendingRegistration, Rating, RefundRequest, SecurityEvent,
SettlementAudit, Trip, TripRecurrenceRule, TripShareLink, UserDevice, User, Vehicle, WalletAccount,
WalletHold, WalletTransaction`.

### 3.2 TypeORM — CLI DataSource (`src/database/data-source.ts`)

Same connection settings read straight from `process.env`. Differences from the runtime module:

- `migrations: [<dirname>/migrations/*.{js,ts}]`
- `migrationsTransactionMode: 'each'` — **each migration runs in its own transaction.** This matters:
  `1745906000000` (`ALTER TYPE … ADD VALUE`) relies on it, since Postgres cannot use a newly added enum
  value in the same transaction that added it.
- Its entity list is **stale — 31 entities**, missing `AdminAlertPreferenceEntity`,
  `DriverAvailabilityEntity`, `InstantRideOfferEntity`, `InstantRideRequestEntity`. Harmless for
  migration running (raw SQL), but `synchronize`/`schema:log` against this DataSource would be wrong.

Scripts:

| Script | Command |
|---|---|
| `db:migration:run` | `node -r dotenv/config -r ts-node/register typeorm/cli.js -d src/database/data-source.ts migration:run` |
| `db:migration:revert` | same without `dotenv/config`, `migration:revert` |
| `db:clear` | `ts-node src/database/scripts/clear-postgres.ts` |
| `db:clear-trips` | `ts-node src/database/scripts/clear-trips.ts` |
| `db:backfill` | `ts-node src/database/scripts/backfill-mongo-to-postgres.ts` (one-off Mongo→PG migration) |
| `seed:admin` | `ts-node -r tsconfig-paths/register seed-admin.ts` |

### 3.3 PostgreSQL requirements

Created by migration `1700000000000`:

```sql
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

- `uuid-ossp` supplies `uuid_generate_v4()`, the DEFAULT on every `id` column.
- PostGIS supplies `geography(Point,4326)` columns: `trips.fromPoint`, `trips.toPoint`,
  `driver_locations.point`, `driver_availability.point`, `instant_ride_requests.fromPoint/toPoint`
  — all with GiST indexes (`trips_from_point_idx`, `trips_to_point_idx`, `driver_locations_point_idx`,
  the **partial** `driver_availability_available_point_idx`, `instant_requests_from_point_idx`).
- Docker image: `postgis/postgis:16-3.4` → PostgreSQL 16 + PostGIS 3.4.

### 3.4 Redis usage

Redis is used **only as the BullMQ (bull v4) broker**. There is no `CacheModule`, no `ioredis` client,
no cache keys, no TTL-based caching layer anywhere in `src/`. Two in-process caches exist instead
(both `Map`-based, per-instance, lost on restart):

| Cache | Location | TTL / bound |
|---|---|---|
| Place-autocomplete results | `locations.service.ts` `autocompleteCache` | `cacheTtlMs = 60_000` |
| Autocomplete rate limiter | `locations.service.ts` `rateLimits` | window `60_000` ms, `60` req/window/user |
| WS event rate limiter | `common/guards/ws-rate-limit.guard.ts` | window `60_000` ms, `180` events/window/user |
| A2A CliQ session token | `a2a-cliq.service.ts` | server-supplied expiry, refreshed with a `60_000` ms buffer |

Bull connection (`src/jobs/jobs.module.ts`): `BullModule.forRoot({ redis: { host: REDIS_HOST||'localhost',
port: REDIS_PORT||6379 } })`. **No password, no db index, no TLS, no prefix.** Compose runs Redis with
`--appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru` — note that `allkeys-lru` can evict
queued jobs under memory pressure; the driver-trip-fee reconciliation cron exists specifically because
delayed jobs have been lost this way.

Registered queues (declared in `JobsModule`, plus per-feature `registerQueue`):
`trip-expiration`, `notification-cleanup`, `new-trip-fanout`, `bookings-timeout`, `no-show-detector`,
`pre-trip-confirm`, `recurrence-spawn`, `pending-charge-collect`, `trip-auto-start`,
`trip-auto-complete`, plus `instant-offer-timeout` / `instant-request-expiry` / dispatch-wave queues
(`instant-rides.constants.ts`) and the CliQ poll queue (`payments.module.ts`).

### 3.5 Complete migration history

Chronological (by timestamp prefix). All files in `src/database/migrations/`.

| # | Timestamp | File / class | Schema change |
|---|---|---|---|
| 1 | 1700000000000 | `initialize-postgres` | `CREATE EXTENSION postgis, uuid-ossp`. Enums: `users_role_enum`, `trip_status_enum`, `wallet_account_type_enum`, `wallet_transaction_type_enum`, `wallet_entry_direction_enum`, `wallet_transaction_status_enum`, `payout_status_enum`, `notification_channel_enum`. Tables: `users` (+`users_email_idx`, `users_phone_idx`, `users_role_idx`), `trips` (+`trips_driver_idx`, `trips_status_departure_idx`, GiST `trips_from_point_idx`/`trips_to_point_idx`), `driver_locations` (+2 btree, GiST `driver_locations_point_idx`), `wallet_accounts`, `wallet_transactions` (+account/created, reference idx), `wallet_holds` (+account, status idx), `payout_requests` (+driver, status idx), `notifications` (+user/created, user/read idx), `device_tokens` (+user idx). |
| 2 | 1738800000000 | `add-users-missing-columns` | `users` += `gender`, `provider` (`DEFAULT 'email'`), `providerId`, `photoUrl`, `refreshToken`, `isEmailVerified`, `isPhoneVerified`, `isDriverApproved`, `hasUsedLifetimeFreeTrip`, `rating DECIMAL(3,…)`, `totalRatings INT DEFAULT 0`, `walletBalance DECIMAL(10,…)`, `walletCurrency VARCHAR(5,…)`. |
| 3 | 1738900000000 | `add-pending-registrations-and-otp-codes` | Enum `pending_registration_gender_enum`; tables `pending_registrations` (+phone, email idx), `otp_codes` (+phone/code, expiresAt idx). |
| 4 | 1739000000000 | `add-bookings-table` | `bookings` + `idx_bookings_user_trip` (unique composite), `idx_bookings_trip`, `idx_bookings_user`, `idx_bookings_status`. |
| 5 | 1739100000000 | `add-trips-missing-columns` | `trips` += `driverName`, `fromAddress`, `toAddress`, `seatLayout JSONB`, `seats JSONB DEFAULT '[]'`, `carImageUrl`, `communicationFeeStatus VARCHAR DEFAULT 'not_paid'`, `driverWalletChargeApplied BOOLEAN DEFAULT FALSE`, `driverWalletChargeAt TIMESTAMPTZ`. |
| 6 | 1739200000000 | `add-vehicles-table` | `vehicles`. |
| 7 | 1739300000000 | `add-chat-rooms-and-messages` | `chat_rooms` (+trip, lastMessageTime idx), `messages` (+chatRoom, createdAt DESC idx). |
| 8 | 1739400000000 | `add-communication-fees-table` | `communication_fees`. |
| 9 | 1739500000000 | `add-passenger-id-to-chat-rooms` | `chat_rooms.passengerId UUID REFERENCES users(id)` + unique `idx_chat_rooms_trip_passenger`. |
| 10 | 1739600000000 | `split-pricing-and-booking-payment` | `communication_fees` += `driverUnlockPercent`, `passengerPlatformPercent`, `lifetimeFreeTripEnabled BOOL NOT NULL DEFAULT TRUE`; `bookings` += `seatPriceAtBooking`, `platformAmount`, `driverAmount`, `passengerPaymentId`. |
| 11 | 1743000000000 | `create-payments-table` | `payments` (+user, trip, booking, status idx); `bookings` FK to payments. |
| 12 | 1743100000000 | `set-default-currency-jod` | Sets `DEFAULT 'JOD'` on the currency column of 7 tables. |
| 13 | 1743200000000 | `add-password-changed-at-to-users` | `users.passwordChangedAt TIMESTAMP NULL`. |
| 14 | 1743300000000 | `add-city-to-users` | `users.city VARCHAR(64)` + index. Feeds the city fan-out push. |
| 15 | 1745700000000 | `008.00-foundation__user-extensions` | `users` += `restricted BOOL NOT NULL DEFAULT false`, `hidePhoneNumber BOOL NOT NULL DEFAULT false`, `pendingPhoneLink BOOL NOT NULL DEFAULT false`, `bannedAt TIMESTAMPTZ NULL`, `banReason TEXT NULL`, `lastSocialLoginAt TIMESTAMPTZ NULL`. Backfill: `pendingPhoneLink = true` for social-login accounts with no phone. |
| 16 | 1745800000000 | `008.01-auth-hardening__devices-flags-events` | Enums `user_device_platform_enum`, `user_device_status_enum`, `account_flag_severity_enum`, `account_flag_disposition_enum`. Tables `user_devices` (+user, fingerprint, fingerprint/created idx), `account_flags` (+user, disposition, created idx), `security_events` (+user, type, created idx). |
| 17 | 1745900000000 | `008.02-booking-lifecycle__create-booking-seats` | Table `booking_seats` (+`idx_booking_seats_booking`, unique `idx_booking_seats_seat_number`, partial unique `idx_booking_seats_main_booker` WHERE `isMainBooker`). Backfills one seat row per existing booking. Drops `idx_bookings_user_trip`. |
| 18 | 1745901000000 | `008.03-booking-lifecycle__add-booking-fields` | `bookings` += `seatCount INT DEFAULT 1`, `totalAmount DECIMAL(10,2) NULL`, `settledAt`, `settlementGraceUntil`, `passengerPresenceConfirmedAt`, `driverConfirmedPassengerAt`, `driverMarkedAbsentAt`. Backfills `totalAmount = seatCount × seatPriceAtBooking`. |
| 19 | 1745902000000 | `008.04-booking-lifecycle__booking-status-enum` | Creates `booking_status_enum` (`pending, confirmed, cancelled, rejected, in_progress, completed, no_show`); migrates `bookings.status` varchar→enum via temp column; rebuilds `idx_bookings_status`. |
| 20 | 1745903000000 | `008.05-booking-lifecycle__create-pending-charges` | Enums `pending_charge_kind_enum`, `pending_charge_status_enum`; table `pending_charges` (+booking idx, user/status idx). |
| 21 | 1745906000000 | `008.06-trip-time-flow__trips-extend` | `ALTER TYPE trip_status_enum ADD VALUE` × 4: `draft`, `published`, `fully_booked`, `in_progress`; backfill `active → published`. `trips` += `tripStartedAt`, `tripCompletedAt`, `noShowMarkedAt`, `lastDriverLocationLat/Lng/At`, `preTripConfirmSentAt`, `stops JSONB NOT NULL DEFAULT '[]'`, `notes TEXT`. |
| 22 | 1745907000000 | `008.07-trip-time-flow__create-trip-share-links` | `trip_share_links` + unique `idx_trip_share_links_token`, `idx_trip_share_links_trip`. |
| 23 | 1745908000000 | `008.08-trip-authoring__recurrence-stops-notes` | `trip_recurrence_rules` (+`recurrence_rules_driver_active_idx`, `recurrence_rules_spawn_sweep_idx`); `trips` += `recurrenceRuleId UUID`, `stops JSONB`, `notes TEXT` (idempotent re-add). |
| 24 | 1745909000000 | `008.09-settle-and-call__create-calls-and-audits` | `settlement_audits` (+booking, actor idx); `call_sessions` (+booking, twilioSid idx). |
| 25 | 1745910000000 | `008.10-admin-and-support__create-complaints-and-refunds` | `complaints` (+3 idx), `refund_requests` (+1 idx). |
| 26 | 1745910000000 | `drop-bookings-user-trip-unique` | **Duplicate timestamp with #25.** Drops the `bookings` user/trip unique constraint + index. Ordering between the two is filename-lexicographic within the same timestamp — a rebuild should renumber. |
| 27 | 1745911000000 | `008.11-cleanup__drop-bookings-seatnumber` | Drops legacy `bookings.seatNumber` (superseded by `booking_seats`). |
| 28 | 1745912000000 | `008.12-cleanup__bookings-total-amount-not-null` | `bookings.totalAmount` → `NOT NULL`. |
| 29 | 1745913000000 | `008.13-cleanup__audit-correlation-id` | `correlationId varchar NULL` added to `security_events`, `settlement_audits`, `pending_charges`. |
| 30 | 1745920000000 | `add-seat-layout-to-vehicles` | `vehicles.seatLayout JSONB`. |
| 31 | 1745930000000 | `add-expires-at-to-bookings` | `bookings.expiresAt TIMESTAMP NULL` (pending-booking timeout). |
| 32 | 1745931000000 | `add-passenger-reported-driver-absent-to-bookings` | `bookings.passengerReportedDriverAbsentAt TIMESTAMP NULL`. |
| 33 | 1745932000000 | `add-presence-confirmed-at-to-booking-seats` | `booking_seats.presenceConfirmedAt TIMESTAMP NULL`. |
| 34 | 1746000000000 | `add-admin-fields-to-pending-charges` | `pending_charges` += `reason TEXT NULL`, `createdByAdminId UUID NULL`. |
| 35 | 1746100000000 | `add-car-image-url-to-vehicles` | `vehicles.carImageUrl TEXT NULL`. |
| 36 | 1746200000000 | `add-web-platform-to-device-tokens` | `device_tokens.userAgent VARCHAR(255) NULL` — enables `platform='web'` dashboard tokens. |
| 37 | 1746201000000 | `create-admin-alert-preferences` | Enum `admin_alert_preference_alerttype_enum` (`driver_registration`, `fee_payment`); table `admin_alert_preference` (PK id, UNIQUE `(userId, alertType)`, FK→users ON DELETE CASCADE, `enabled BOOL DEFAULT true`) + `admin_alert_preference_user_idx`. |
| 38 | 1746300000000 | `create-driver-availability` | Table `driver_availability` (PK `driverId`, FK→users CASCADE, `isOnline`, `acceptsInstant DEFAULT true`, `point geography(Point,4326)`, `currentRequestId`, `lastSeenAt`) + **partial** GiST index `WHERE isOnline = true AND currentRequestId IS NULL`. |
| 39 | 1746310000000 | `add-trip-type-to-trips` | `trips.tripType varchar(16) NOT NULL DEFAULT 'scheduled'` + `trips_trip_type_idx`. |
| 40 | 1746320000000 | `create-instant-ride-requests` | `instant_ride_requests` (geography from/to, `status DEFAULT 'searching'`, `radiusKm DEFAULT 3`, `currency DEFAULT 'JOD'`, `expiresAt NOT NULL`) + passenger/status idx + GiST fromPoint idx. |
| 41 | 1746330000000 | `create-instant-ride-offers` | `instant_ride_offers` (FKs→requests CASCADE, →users CASCADE, `status DEFAULT 'offered'`, `expiresAt`) + request idx + driver/status idx. |
| 42 | 1746400000000 | `create-password-reset-sessions` | `password_reset_sessions` (`phoneNumber`, `otpCode`, `isVerified`, `attemptCount`, `isLocked`, `expiresAt`) + phone idx + expires idx. |
| 43 | 1746500000000 | `add-instant-fare-negotiation` | `instant_ride_requests` += `recommendedFare`, `passengerFare`; `instant_ride_offers` += `proposedFare`, `acceptedFare` (all `numeric(10,2)`). |
| 44 | 1746510000000 | `add-instant-dispatch-waves` | += `fareRevision integer NOT NULL DEFAULT 1`, `nudgedAt timestamptz`, `pickupEtaSeconds integer`. |
| 45 | 1746520000000 | `add-instant-terminal-retry-metadata` | += `terminalReason varchar(32)`, `endedAt timestamptz`, `retryOfRequestId uuid`; two unique indexes + backfill UPDATEs. |
| 46 | 1746600000000 | `add-presence-confirmation` | Large presence/wallet migration. `booking_seats` += `passengerSelfConfirmedAt`, `autoFlaggedAbsentAt`, `absenceReason VARCHAR(30)`, `billableOverride BOOLEAN NULL`, `presenceDisputedAt`, `presenceResolvedBy UUID`, `presenceResolutionNote TEXT`; `bookings` += `passengerDeclaredStatus VARCHAR(20)`, `presenceUpdatedAt`, `billableSeatCount INTEGER`; `trips` += `presenceReviewFlagged BOOL NOT NULL DEFAULT false`, `presenceSettledAt`, `driverFeeHoldId UUID`; `wallet_accounts` += `reservedBalance NUMERIC(14,…)`; `wallet_holds` += `capturedAmount`, `releasedAmount`, `settledAt`, `metadata JSONB`; `pending_charges` += `capturedFeeAmount`; plus 2 indexes and 1 unique index. |
| 47 | 1746700000000 | `add-trip-live-eta-and-emergency-alert` | `trips` += `remainingDistanceKm double precision`, `remainingDurationSeconds integer`, `etaAt timestamptz`, `routeProgressPercent double precision`, `etaComputedAt timestamptz`. Guarded `ALTER TYPE admin_alert_preference_alerttype_enum ADD VALUE 'trip_emergency'`. |
| 48 | 1746800000000 | `add-is-family-booking-to-bookings` | `bookings.isFamilyBooking BOOLEAN NOT NULL DEFAULT false`. |
| 49 | 1746900000000 | `add-insurance-image-url-to-vehicles` | `vehicles.insuranceImageUrl TEXT NULL`. |
| 50 | 1747000000000 | `add-driver-trip-fee-pending-charge-kind` | Resolves the actual enum type name of `pending_charges.kind` from `pg_type`, then `ALTER TYPE … ADD VALUE IF NOT EXISTS 'driver_trip_fee'`. `down()` is a deliberate no-op (Postgres cannot drop enum labels). |
| 51 | 1747100000000 | `add-pending-charges-driver-trip-fee-unique` | **Partial** unique index `uq_pending_charges_trip_driver_fee ON pending_charges (tripId, kind) WHERE kind = 'driver_trip_fee'` — DB-level guard against the auto-start retry and the reconciliation sweep both recording a fee. Depends on #50 running first. |
| 52 | 1747200000000 | `release-wallet-holds-fee-at-trip-start` | Data-only cutover after `WalletHoldService` was deleted: (1) `wallet_accounts.reservedBalance = 0` everywhere (`balance` untouched); (2) `wallet_holds` `status NOT IN ('captured','released')` → `released`, `releasedAmount = amount`, `capturedAmount = 0`, `settledAt = COALESCE(settledAt, now())`, `metadata ||= {"migration":"fee-at-trip-start"}` (the predicate is inverted on purpose because the DB DEFAULT status is `'pending'`, a value the app enum never defines); (3) `wallet_transactions` `type='hold' AND status='pending'` → `reversed`; (4) `trips.driverWalletChargeApplied = true WHERE presenceSettledAt IS NOT NULL AND driverWalletChargeApplied IS NOT TRUE`. `down()` is an intentional no-op — restore from backup. |

Reimplementation notes: 51 of 52 migrations are hand-written raw SQL with `IF NOT EXISTS` guards, so
they are re-runnable. Two files share timestamp `1745910000000`. Two migrations (#50, #52) have
non-reversible `down()`.

---

## 4. Cross-cutting Concerns (`src/common/`)

### 4.1 Guards

| Guard | Scope | Behaviour |
|---|---|---|
| `JwtAuthGuard` (`guards/jwt-auth.guard.ts`) | **Global** (`APP_GUARD` #1); also re-applied per-controller via `@UseGuards` in several modules (harmless duplication) | Extends `AuthGuard('jwt')`. Reads `IS_PUBLIC_KEY` metadata via `reflector.getAllAndOverride([handler, class])`; if `@Public()` → allow. `handleRequest` throws `UnauthorizedException('Invalid or expired token')` when `err || !user`. Underlying strategy `jwt.strategy.ts` verifies with `JWT_ACCESS_SECRET` and throws at construction if the secret is unset. |
| `BanGuard` (`guards/ban.guard.ts`) | **Global** (#2) | Skips `@Public()` routes and requests with no `req.user`. If `user.bannedAt != null` → `ForbiddenException({ code: 'ACCOUNT_BANNED', banReason: user.banReason ?? null, supportWhatsApp: SUPPORT_WHATSAPP_E164 ?? '+962788883007' })` → HTTP 403. |
| `RolesGuard` (`guards/roles.guard.ts`) | **Global** (#3) | No `@Roles()` metadata (or empty) → allow. No `user` or no `user.role` → `ForbiddenException('User role not found')`. Role mismatch → `ForbiddenException('Access denied. Required roles: a, b')`. Simple string equality against `user.role` (single role per user). |
| `ThrottlerGuard` (`@nestjs/throttler`) | **Global** (#4) | Default bucket `ttl 60000 ms / limit 200`. Per-route overrides via `@Throttle({ default: { ttl: 60000, limit: 30 } })` on `notifications.controller.ts:85,102,113,124` and `users.controller.ts:42`. Storage is in-memory (no Redis throttler storage) → **per-instance** limits. |
| `WsAuthGuard` (`guards/ws-auth.guard.ts`) | Per-gateway `@UseGuards` (notifications, chat, tracking, trips) | Extracts token in priority order: `handshake.auth.token` → `handshake.query.token` → `Authorization: Bearer …` header. `jwtService.verifyAsync(token, { secret: JWT_ACCESS_SECRET })`. Attaches `client.user = { ...payload, id: sub ?? userId ?? id }` and `client.data.userId`. Failure → `UnauthorizedException('WebSocket authentication token not found' | 'Invalid or expired WebSocket token')`. |
| `WsRateLimitGuard` (`guards/ws-rate-limit.guard.ts`) | Per-gateway | Fixed-window in-memory bucket keyed by `client.data.userId ?? client.user.id ?? handshake.address ?? 'anonymous'`. Window `60_000` ms, max `180` events. Over limit → `BadRequestException('Too many websocket events, try again shortly')`. **The bucket `Map` is never pruned** — unbounded growth over process lifetime. |

### 4.2 Filters — exact error response shape

`src/common/filters/http-exception.filter.ts`, `@Catch()` (all exceptions), registered globally.

```jsonc
{
  "success": false,
  "error": {
    "code": 403,                         // HTTP status number, NOT a string error code
    "message": "Forbidden",              // HttpException.message, or "Internal server error"
    "details": null,                     // see resolution below
    "timestamp": "2026-08-21T10:00:00.000Z",
    "path": "/api/v1/bookings/123",
    "method": "POST",
    // only when status === 500 AND NODE_ENV !== 'production' AND exception instanceof Error:
    "debug": "<exception.message>",
    "stack": "<exception.stack>"
  }
}
```

`details` resolution (`getErrorDetails`):
1. Not an `HttpException` → `null`.
2. Response is a string → `null`.
3. Response object has `error.details` that is an array → that array (this is the custom
   `ValidationPipe` shape).
4. Response object has a `message` key → that value.
5. Otherwise `null`.

Every exception is also logged: `logger.error("<METHOD> <url> - Status: <n> - Message: <msg>", stack)`.

> **Critical rebuild note.** `error.code` is the **numeric HTTP status**, never the string error code.
> Domain errors thrown as `ForbiddenException({ code: 'ACCOUNT_BANNED', … })` (BanGuard) or
> `HttpException({ code: 'ACCOUNT_RESTRICTED', message: … }, 423)` (RestrictedAccountInterceptor)
> have their `code` field **silently dropped** by this filter, because the object lacks a top-level
> `message` (BanGuard case) and `getErrorDetails` never looks at `code`. Clients therefore cannot
> distinguish `ACCOUNT_BANNED` from any other 403 by machine-readable code. If the reimplementation
> wants the `ErrorCodes` catalogue to be usable by clients, the filter must be changed to surface
> `response.code`. verify: `src/common/filters/http-exception.filter.ts:20-70` vs
> `src/common/guards/ban.guard.ts:45-52`.

### 4.3 Interceptors

| Interceptor | Scope | Behaviour |
|---|---|---|
| `TransformInterceptor` (`interceptors/transform.interceptor.ts`) | Global, outermost | `map(data => ({ success: true, data }))`. **Unconditional** — controllers that already return `{ success, data }` (e.g. `notifications.controller.ts` `getUnreadCount`, `markRead`, `markAllRead`, `delete`) end up **double-wrapped** as `{ success: true, data: { success: true, data: … } }`. Note this asymmetry when writing clients. |
| `UploadUrlInterceptor` (`interceptors/upload-url.interceptor.ts`) | Global, HTTP only | Computes `base = (x-forwarded-proto \|\| req.protocol) + '://' + (x-forwarded-host \|\| req.get('host'))`. Recursively walks the payload (arrays, plain objects; skips `Date` and `Buffer`; uses a `WeakSet` to break TypeORM relation cycles) and **mutates strings in place**: an absolute URL matching `/^https?:\/\/[^/]+(\/(?:uploads\|public)\/.*)$/i` has its origin replaced; a string starting with `/uploads/` or `/public/` is prefixed with `base`. Purpose: stored absolute upload URLs baked with `http://localhost:3000` stay reachable from emulators (`10.0.2.2`), LAN IPs, and behind the nginx edge, without a data migration. |
| `LoggingInterceptor` (`interceptors/logging.interceptor.ts`) | Global | Generates `requestId = req.id ?? \`${Date.now()}-${Math.random().toString(36).substring(2,9)}\`` and assigns `request.requestId`. Logs on entry `[id] METHOD url - IP: … - UserAgent: …`; on success `[id] METHOD url - Status: n - Duration: Nms`; on error `[id] METHOD url - Error: msg - Duration: Nms` + stack. No sampling, no redaction — full URLs including query strings are logged. |
| `RestrictedAccountInterceptor` (`interceptors/restricted.interceptor.ts`) | Global, innermost | No-op if `!req.user \|\| !user.restricted`. `GET/HEAD/OPTIONS` pass through. Any other method → `HttpException({ code: 'ACCOUNT_RESTRICTED', message: 'Your account is currently restricted. Write operations are not permitted.' }, 423 Locked)`. Ban supersedes restriction because `BanGuard` (a guard) runs before all interceptors. |
| `LocationGuardInterceptor` (`interceptors/location-guard.interceptor.ts`) | **Not global** — `@UseInterceptors` on `tracking.gateway.ts:79` (`driver:location:update` WS handler); provided by `TrackingModule` | WS-only (returns `next.handle()` for non-`ws` contexts). If payload has `isMockLocation: true` and `client.data.userId` exists: (1) inserts `security_events` row `{ eventType: 'mock_location_rejected', metadata: { tripId, latitude, longitude } }`; (2) counts `mock_location_rejected` events for that user in the last **30 days**; (3) if count ≥ **3** and no OPEN flag with `reason='mock_location_repeated'` exists, inserts `account_flags` row `{ severity: HIGH, disposition: OPEN, notes: "<n> mock-location events detected within 30 days." }`; (4) throws `WsException({ code: 'LOCATION_INTEGRITY_VIOLATION', message: 'Mock location detected. Location update rejected.' })`. |

### 4.4 Pipes

`src/common/pipes/validation.pipe.ts` — custom, registered as `APP_PIPE`.

- Skips primitives (`String, Boolean, Number, Array, Object`) and metatype-less params.
- `plainToClass(metatype, value)` then `validate(object, { whitelist: true, forbidNonWhitelisted: true, transform: true })`.
  (Note: `whitelist`/`forbidNonWhitelisted`/`transform` are **`ValidationPipe` options, not
  `validate()` options** — `class-validator.validate()` accepts `whitelist` and `forbidNonWhitelisted`
  but ignores `transform`. The pipe returns the transformed object regardless.)
- Errors are flattened recursively (own `constraints` values + all `children`) into a `string[]`.
- Throws `BadRequestException({ message: 'Validation failed', success: false, error: { code: 400, message: 'Validation failed', details: string[] } })`.
- Combined with the filter, a validation failure surfaces as
  `{ success:false, error:{ code:400, message:'Validation failed', details:[...], timestamp, path, method } }`.

The `main.ts` built-in `ValidationPipe` (whitelist + forbidNonWhitelisted + transform +
`enableImplicitConversion`) also runs, and produces the standard Nest array-of-strings message shape
for whatever it rejects first. Two shapes are reachable in practice.

### 4.5 Decorators

| Decorator | File | Semantics |
|---|---|---|
| `@Public()` | `decorators/public.decorator.ts` | `SetMetadata('isPublic', true)`. Consumed by `JwtAuthGuard` and `BanGuard`. |
| `@Roles(...roles: string[])` | `decorators/roles.decorator.ts` | `SetMetadata('roles', roles)`. Consumed by `RolesGuard`. |
| `@CurrentUser(key?)` | `decorators/current-user.decorator.ts` | Param decorator. Resolves the user from `ctx.switchToHttp().getRequest().user` for `http` contexts and `ctx.switchToWs().getClient().user` otherwise. No key → the whole user. Key `'id'` → `user.id ?? user._id`, stringified (Mongo `ObjectId` compatibility left over from the Mongo era). Any other key → `user[key]`. |

### 4.6 Error catalogue (`src/common/errors/error-codes.ts`)

String constants used as the `code` field in error bodies, WS close payloads, and as mobile
localisation keys. **HTTP statuses below are the status of the throw site, not defined in this file.**

| Code | Domain | Meaning | HTTP status at throw site |
|---|---|---|---|
| `LOCATION_INTEGRITY_VIOLATION` | Auth/device | Location update flagged as mocked | WS exception (no HTTP status) — `location-guard.interceptor.ts` |
| `ACCOUNT_BANNED` | Auth | Account banned by an admin | 403 — `ban.guard.ts` |
| `ACCOUNT_RESTRICTED` | Auth | Account restricted; writes blocked | 423 Locked — `restricted.interceptor.ts` |
| `PROFILE_PHOTO_REQUIRED` | Auth | Driver publishing/approval without a profile photo | verify: trips/users service throw site |
| `OUTSTANDING_CHARGES` | Auth/billing | Driver publishing while owing pending charges | verify: trips service |
| `DRIVER_REQUIRES_APPROVAL` | Auth | Driver not yet admin-approved | verify: trips service |
| `SELF_REVOKE_USE_LOGOUT` | Auth | Caller tried to revoke their own current device session | verify: security module |
| `SEATS_TAKEN` | Booking | Requested seats already taken | verify: bookings service |
| `GENDER_ADJACENCY_VIOLATION` | Booking | Female passenger adjacent to a male outside her companion group | verify: bookings seat allocator |
| `NO_VALID_ARRANGEMENT` | Booking | Auto-pick found no valid seat arrangement | verify: bookings seat allocator |
| `CANCELLATION_WINDOW_CLOSED` | Booking | Cancellation outside the allowed window | verify: bookings service |
| `TIMING_WINDOW` | Trip time | Action attempted outside its time window (e.g. Start Trip >15 min early) | verify: trip-time service |
| `ALREADY_SETTLED` | Settlement | Booking already marked paid | verify: settlement service |
| `BOOKING_NOT_CONFIRMED` | Settlement | Action requires a confirmed booking | verify: settlement/calls |
| `BOOKING_NOT_SETTLED` | Settlement | Action requires a settled booking | verify: calls/chat |
| `GRACE_EXPIRED` | Settlement | Unsettle attempted outside the 5-minute grace window | verify: settlement service |
| `CONTACT_ALREADY_USED` | Settlement | Settlement reversal after chat/call already used | verify: settlement service |
| `NO_PROXY_NUMBERS_AVAILABLE` | Calls | Twilio proxy number pool exhausted | verify: calls service |
| `ALREADY_DECIDED` | Admin | Action already decided | verify: admin services |
| `NOT_TRIP_DRIVER` | Shared | Only the trip driver may do this | verify: trips/trip-time |
| `CONTACT_ALREADY_USED_BY_OTHER` | Auth | Phone/device already bound to another account | verify: auth service |
| `PRESENCE_WINDOW_CLOSED` | Presence | Outside window (driver: departure−30m→settlement; passenger: departure−60m→departure+30m) | verify: presence service |
| `PRESENCE_ALREADY_SETTLED` | Presence | Trip fee settled; roster immutable | verify: presence service |
| `PRESENCE_SEAT_NOT_FOUND` | Presence | Seat number not on the referenced booking | verify: presence service |
| `INSUFFICIENT_AVAILABLE_BALANCE` | Wallet | Balance minus active holds insufficient | verify: wallet service |
| `HOLD_NOT_FOUND` | Wallet | Referenced hold missing or closed | verify: wallet service (hold service was deleted — see migration #52) |
| `NEGATIVE_WALLET_BALANCE` | Wallet | Driver blocked from publishing / going online | verify: wallet/trips |
| `INSUFFICIENT_BALANCE_FOR_TRIP_FEE` | Wallet | Wallet cannot cover the trip platform fee | verify: driver-trip-fee service |

Also exported: `type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes]`.

Two edge-level codes exist only in nginx (`docker/nginx/nginx.conf`) and never in application code:
`RATE_LIMIT_EXCEEDED` (429) and `UPSTREAM_ERROR` (502).

### 4.7 Currency helper (`src/common/currency/country-currency.ts`)

- `DEFAULT_CURRENCY = 'JOD'`.
- `COUNTRY_CURRENCY`: frozen map ISO-3166-1 alpha-2 → ISO-4217, 23 entries:
  Levant `JO→JOD, SY→SYP, LB→LBP, PS→ILS, IQ→IQD`;
  Gulf `SA→SAR, AE→AED, QA→QAR, KW→KWD, BH→BHD, OM→OMR, YE→YER`;
  North Africa `EG→EGP, LY→LYD, SD→SDG, DZ→DZD, MA→MAD, TN→TND, MR→MRU`;
  fallbacks `US→USD, GB→GBP, TR→TRY`.
- `currencyForCountry(code?: string | null): string` — trims, upper-cases, returns
  `COUNTRY_CURRENCY[code] ?? 'JOD'`; `null`/empty/unknown → `'JOD'`.
- Semantics: a trip's currency is derived from the country of its **departure point**, so fares are
  always shown in the local currency of where the ride starts.

### 4.8 Audit helper (`src/common/audit/`)

`AuditModule` is `@Global()` and exports `AuditService`.

```ts
interface AuditRecord { action: string; userId: string; [key: string]: any }
emit(record): void  // logger.log(JSON.stringify({ ...record, timestamp: new Date().toISOString() }))
```

**It only writes to the application log** — no database table, no queue, no external sink, and it is
fire-and-forget (`void`, synchronous). Durable audit trails live in dedicated tables
(`security_events`, `settlement_audits`) written directly by the owning services, not by this helper.
Known `action` values emitted from the notifications subsystem: `device.register`,
`device.deregister`, `notification.city_fanout`.

### 4.9 Pagination (`src/common/dto/pagination.dto.ts`, `src/common/interfaces/paginated-result.interface.ts`)

Request DTO:

| Field | Type | Default | Constraints |
|---|---|---|---|
| `page` | number | `1` | `@IsOptional @Type(()=>Number) @IsInt @Min(1)` |
| `limit` | number | `20` | `@IsOptional @Type(()=>Number) @IsInt @Min(1) @Max(100)` |

Response interface:

```ts
interface PaginatedResult<T> {
  data: T[];
  meta: { page: number; limit: number; total: number; totalPages: number };
}
```

`totalPages = Math.ceil(total / limit)`. Offset computed as `skip = (page - 1) * limit`.

> Caveat: `NotificationQueryDto extends PaginationDto` but `NotificationsController.findAll` overrides
> the default with `queryDto.limit || 10`, so the notifications list defaults to **10**, not 20.

---

## 5. Notifications Subsystem

Files: `src/modules/notifications/` (controller, service ~981 lines, gateway, module, 3 DTOs,
1 processor, 1 dead Mongoose schema), `src/modules/admin/admin-alerts.service.ts` (provided and
exported by `NotificationsModule`), entities `notification.entity.ts`, `device-token.entity.ts`,
`admin-alert-preference.entity.ts`.

### F-01: In-app notification inbox

**What it does:** Persists every in-app notification as a `notifications` row, pushes it live over
Socket.IO to the owning user, and exposes a paginated read/mark/delete API.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/notifications` | JWT | Paginated list, newest first, optional read filter |
| GET | `/api/v1/notifications/unread-count` | JWT | Unread count |
| PATCH | `/api/v1/notifications/:id/read` | JWT | Mark one read |
| PATCH | `/api/v1/notifications/read-all` | JWT | Mark all read |
| DELETE | `/api/v1/notifications/:id` | JWT | Delete one |

> Route-order hazard: `PATCH :id/read` is declared before `PATCH read-all`, but they do not collide
> because the first has a two-segment path. Keep both.

**Request/Response contracts:**

`GET /notifications?page=1&limit=10&isRead=false` — `NotificationQueryDto extends PaginationDto` with
`isRead?: boolean` (`@Transform`: `'true'`/`true` → `true`, `'false'`/`false` → `false`, else passthrough
then `@IsBoolean`). Returns `PaginatedResult<NotificationEntity>` (then globally wrapped:
`{ success: true, data: { data: [...], meta: {...} } }`).

`GET /unread-count` → controller returns `{ success: true, data: { count } }`, globally wrapped again
→ `{ success:true, data:{ success:true, data:{ count } } }`. Same double wrap on `:id/read`,
`read-all` (`{ message, updatedCount }`) and `DELETE :id` (`{ message: 'Notification deleted' }`).

**Business rules:**
- Ownership is enforced in the service: `markRead` / `delete` throw a bare `Error('Notification not found')`
  or `Error('Unauthorized')` — **not** Nest HTTP exceptions, so they surface as **500** through the
  global filter. A rebuild should use 404/403. verify: `notifications.service.ts` `markRead`/`delete`.
- `markAllRead` returns the number of affected rows (`update({userId, isRead:false}, {isRead:true})`).
- List query: `WHERE n.userId = :userId [AND n.isRead = :isRead] ORDER BY n.createdAt DESC` with
  `skip/take`; the count is taken from the same builder (note: `getCount()` is executed on the builder
  *after* `skip/take` were applied to it — `Promise.all` ordering makes this fragile; TypeORM ignores
  skip/take for `getCount`, so it is correct in practice).

**Data model — `notifications` table (`NotificationEntity`):**

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | `uuid_generate_v4()` |
| `userId` | uuid | FK → `users.id` `ON DELETE CASCADE` |
| `type` | varchar(50) | free-form string (see catalogue) |
| `title` | varchar(160) | |
| `body` | text NULL | |
| `channel` | `notification_channel_enum` | default `IN_APP` |
| `isRead` | boolean | default `false` |
| `data` | jsonb NULL | arbitrary payload |
| `expiresAt` | timestamptz NULL | **never written or read anywhere** — dead column |
| `createdAt` / `updatedAt` | timestamps | |

Indexes: `notifications_user_created_idx (userId, createdAt)`, `notifications_user_read_idx (userId, isRead)`.

**Errors:** none typed; see the 500 note above.

**Notes for reimplementation:** `NotificationsService.create()` does three things atomically-ish:
saves the row, emits `newNotification` over WS to `user:<id>`, then fires `sendPush()` **without
awaiting** (fire-and-forget). Push failure never fails the API call.

---

### F-02: Real-time notification gateway (Socket.IO)

**What it does:** Delivers freshly-created notifications to connected clients.

**Transport contract:**

| Property | Value |
|---|---|
| Namespace | `/notifications` |
| CORS | `origin: '*'` (gateway-level, independent of the HTTP CORS config) |
| Guards | `@UseGuards(WsAuthGuard, WsRateLimitGuard)` at class level |
| Auth | Token from `handshake.auth.token` → `handshake.query.token` → `Authorization: Bearer` |
| Path | Default `/socket.io/` (proxied by nginx with `Upgrade`/`Connection: upgrade`, 7-day timeouts) |

| Direction | Event | Payload | Notes |
|---|---|---|---|
| client→server | `subscribe` | — | Joins room `user:<userId>`. Ack `{ success: true }`, or `{ success: false, message: 'Unauthorized' }` when `client.data.userId` is missing. **Clients must call this; connection alone does not subscribe.** |
| server→client | `newNotification` | the saved `NotificationEntity` | Emitted by `NotificationsService.create()` and `AdminAlertsService.dispatch()` via `emitToUser(userId, 'newNotification', data)` → `server.to('user:'+userId).emit(...)` |

Connection lifecycle: `handleConnection` reads `client.user` (set by `WsAuthGuard`), resolves
`sub ?? userId ?? id`, disconnects if absent, else records `client.id` in an in-memory
`Map<userId, Set<socketId>>`. `handleDisconnect` removes it and drops the entry when empty.

**Notes for reimplementation:** the `userSockets` map is per-process and there is no Redis Socket.IO
adapter → **single-replica only**. Horizontal scaling requires a pub/sub adapter.

---

### F-03: Device token registration (mobile FCM)

**API Endpoints:**

| Method | Path | Auth | Throttle | Purpose |
|---|---|---|---|---|
| POST | `/api/v1/notifications/devices` | JWT | 30/60 s | Register or refresh a device FCM token |
| DELETE | `/api/v1/notifications/devices/:token` | JWT | 30/60 s | Deregister on sign-out |

**Request/Response contracts:**

`RegisterDeviceDto`: `token` (string, required, `MaxLength(512)`), `platform` (`@IsIn(['android','ios'])`),
`appVersion?` (string, `MaxLength(32)` — **accepted and then discarded; never persisted**).

Response (HTTP **201** when the token row is new, **200** when it existed — set via
`@Res({ passthrough: true })`):

```json
{ "registered": true, "platform": "android", "lastSeenAt": "2026-08-21T10:00:00.000Z" }
```
(globally wrapped in `{ success: true, data: … }`).

`DELETE /devices/:token` → `204 No Content`, empty body.

**Business rules:**
- Lookup is by `token` alone (the token column is globally unique). If the row exists it is
  **re-assigned to the calling user**, platform overwritten, `isActive = true`, `lastSeenAt = now`.
  This is deliberate: a device handed to another user re-binds rather than duplicating.
- Deregister: `findOne({ token })`; if missing **or** `device.userId !== userId` → `NotFoundException('Device token not found')` (404). Otherwise soft-delete via `isActive = false`.
- Both paths emit an audit record and a structured log line with a truncated token
  (`token.substring(0, min(8, len)) + '…'`) — full tokens are never logged.

**Data model — `device_tokens` (`DeviceTokenEntity`):**

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `userId` | uuid | FK → users, CASCADE |
| `token` | varchar(512) | **unique** (`device_tokens_unique_token_idx`) |
| `platform` | varchar(20) | default `'android'`; values in use: `android`, `ios`, `web` |
| `userAgent` | varchar(255) NULL | web tokens only (migration #36) |
| `isActive` | boolean | default `true` |
| `lastSeenAt` | timestamptz NULL | |
| `createdAt`/`updatedAt` | timestamps | |

Index: `device_tokens_user_idx (userId)`.

**Errors:** `404 Device token not found`.

---

### F-04: Dashboard web-push token registration

**API Endpoints:**

| Method | Path | Auth | Throttle | Purpose |
|---|---|---|---|---|
| POST | `/api/v1/notifications/web-token` | JWT | 30/60 s | Register/refresh an FCM **web** token (HTTP 200) |
| DELETE | `/api/v1/notifications/web-token` | JWT | 30/60 s | Deregister (HTTP 200, **body-carried token**) |

**Contracts:** `WebTokenDto { token: string (MaxLength 512), userAgent?: string (MaxLength 255) }`.
Both return `{ ok: true }` (wrapped → `{ success: true, data: { ok: true } }`).

**Business rules:** same upsert-by-token semantics as F-03 but forcing `platform = 'web'` and
preserving a previously-stored `userAgent` when the new request omits one
(`dto.userAgent ?? existing.userAgent ?? null`). Deregister is an `update({ userId, token,
platform: 'web' }, { isActive: false })` — **it does not 404** on an unknown token, unlike F-03.

**Notes:** `DELETE` with a request body is unusual; some HTTP clients strip it. `FIREBASE_WEB_MESSAGING_SENDER_ID`
exists to document the browser-side sender id but is never read by the backend — the same Firebase
Admin credentials serve web push.

---

### F-05: Push delivery (Firebase Cloud Messaging)

**What it does:** `NotificationsService.sendPush(userId, payload)` is the single push egress point for
the whole backend.

**Contract:**

```ts
sendPush(userId: string, payload: {
  title: string;
  body?: string;
  type: string;
  data?: Record<string, unknown>;
  targetPlatforms?: string[];      // e.g. ['web'] — filters device rows by platform
}): Promise<{ successCount: number; failureCount: number }>
```

**Credential loading (`ensureFirebase()`, lazily on first push):**
1. If already initialised (`firebaseReady`) or previously failed (`firebaseUnavailable`) → return.
2. If `admin.apps.length > 0` → adopt the existing app.
3. `FIREBASE_SERVICE_ACCOUNT_PATH` ?? `GOOGLE_APPLICATION_CREDENTIALS` → `resolve()`, `existsSync()`,
   `JSON.parse(readFileSync(…,'utf8'))`, accept either camelCase or snake_case keys
   (`projectId|project_id`, `clientEmail|client_email`, `privateKey|private_key`). Missing any of the
   three → warn and fall through.
4. Fallback: `FIREBASE_PROJECT_ID` + `FIREBASE_CLIENT_EMAIL` + `FIREBASE_PRIVATE_KEY`.
5. Private key normalisation: `trim()`, strip surrounding `"`, replace `\n` with real newlines.
6. If nothing works: `firebaseUnavailable = true`, warn once, and **every push becomes a silent no-op
   returning `{ successCount: 0, failureCount: 0 }`**. The app runs fine without Firebase.

**Message construction:**
- Recipients: `device_tokens WHERE userId = :userId AND isActive = true`, then filtered by
  `targetPlatforms` when provided. Zero tokens → debug log + `{0,0}`.
- `data` payload: `{ userId, type, notificationId?, ...payload.data, title, body? }`, with `null`/`undefined`
  entries dropped and every value stringified (`String()` for primitives, `JSON.stringify()` otherwise) —
  FCM data values must be strings.
- **Collapse key:** only for `type === 'chat_message'` with a `data.chatRoomId` → `chat_<roomId>`.
  Applied as `android.collapseKey`, `android.notification.tag`, and APNs header `apns-collapse-id`.
- **Android channel:** `rideshare_notifications`.
- **Data-only Android for rich layouts:** when `type` is `booking_created` or `instant_offer`, the
  message omits both the top-level `notification` and `android.notification` so the Android client
  (`VisionWayMessagingService`) renders its own custom layout. iOS still receives a visible APNs alert.
- APNs payload always: `{ aps: { alert: { title, body }, sound: 'default' } }`.
- Webpush block is added only when `targetPlatforms` includes `'web'`:
  `{ notification: { title, body }, fcmOptions: data.link ? { link } : undefined }`.
- `android.priority = 'high'` always.

**Send strategy:** exactly one token → `admin.messaging().send({ token, ...base })` and return `{1,0}`.
More than one → `sendEachForMulticast({ tokens, ...base })` returning FCM's counts.

**Error handling:** the whole method is wrapped in try/catch; any throw is logged and returns
`{ successCount: 0, failureCount: 1 }`. **Invalid-token pruning is NOT done here** — only the city
fan-out path (F-06) deactivates `messaging/registration-token-not-registered` tokens. Stale tokens
therefore accumulate on the per-user path.

---

### F-06: New-trip city fan-out

**What it does:** When a trip is published (or spawned from a recurrence rule), everyone whose
`users.city` matches the trip's origin city gets a "New Trip Posted" push.

**Trigger:** `NotificationsService.enqueueCityFanout(tripId)` →
`fanoutQueue.add('fanout', { tripId }, { attempts: 3, backoff: 5000 })` on queue `new-trip-fanout`.
Consumed by `NewTripFanoutProcessor` (`@Processor('new-trip-fanout')`, `@Process('fanout')`), which
logs failures via `@OnQueueFailed`.

**Algorithm (`processCityFanout`):**
1. `ensureFirebase()`; abort silently if push is unavailable.
2. Load the trip; abort with a warning if missing.
3. `originCity = trip.fromName.split(',')[0].trim()`; abort with a warning if empty.
4. Recipients: `SELECT user.id FROM users WHERE LOWER(city) = LOWER(:originCity) AND isActive = true AND id != trip.driverId`.
5. Zero recipients → emit a structured `notification.dispatch` log with all counters at 0 and return.
6. Load all active `device_tokens` for those user ids; zero tokens → return (no log emitted in this branch).
7. Send in batches of **500** tokens via `sendEachForMulticast`, accumulating success/failure counts.
   Per-batch exceptions add `batch.length` to `failureCount` and are logged, not rethrown.
8. Collect tokens whose response error code is `messaging/registration-token-not-registered` and
   bulk `update({ token: In(unregistered) }, { isActive: false })`.
9. `auditService.emit({ action: 'notification.city_fanout', userId: trip.driverId, tripId, originCity,
   recipientUserCount, deviceCount, successCount, failureCount })`.
10. Structured log `{ event:'notification.dispatch', trigger:'city_fanout', originCity,
    recipientUserCount, deviceCount, successCount, failureCount, durationMs, correlationId: tripId }`.

**Message:** `notification: { title: 'New Trip Posted', body: 'A new trip to <toName> is available' }`,
`data: { type: 'new_trip_posted', screen: 'trip_details', entityId: tripId }`,
`android: { priority: 'high', notification: { channelId: 'rideshare_notifications' } }`,
`apns: { payload: { aps: { sound: 'default' } } }`. **No `notifications` inbox rows are created** — this
is push-only.

**Idempotency:** none. Re-enqueuing the same `tripId` re-sends. Job retries (3 attempts, fixed 5 s
backoff) can therefore double-send if a batch partially succeeded before a throw.

---

### F-07: Admin alert broadcast (web push to dashboard)

Provided by `AdminAlertsService` (`src/modules/admin/admin-alerts.service.ts`), exported from
`NotificationsModule`.

**Alert types** (`AdminAlertType` enum, table `admin_alert_preference`):
`driver_registration`, `fee_payment`, `trip_emergency`.

**Preference API** (controller lives in the admin module):
`getPreferences(userId)` returns all three types with `enabled` defaulting to **true** when no row
exists; `setPreference(userId, alertType, enabled)` upserts one row (UNIQUE `(userId, alertType)`).

**Recipient resolution:** all `users WHERE role = ADMIN AND isActive = true`, minus those with an
explicit `enabled = false` preference row for that alert type.

**Dispatch (per recipient):** save a `notifications` row → `emitToUser(id, 'newNotification', row)` →
`sendPush(id, { …, targetPlatforms: ['web'] })` with `data.notificationId` attached. Aggregate counters
are logged as `{ event: 'admin.alert.dispatch', alertType, recipientCount, delivered, failed }`.

| Trigger | Guard | Notification type | Title | Body | `data` |
|---|---|---|---|---|---|
| `notifyDriverRegistration(driver)` | only if `driver.role === DRIVER` | `admin_driver_registration` | `New driver registration` | `<name\|phone\|'New driver'> registered as a driver.` | `{ link: '/users/<id>', driverId }` |
| `notifyFeePayment(payment)` | only if `paymentType === 'communication_fee'` | `admin_fee_payment` | `Communication fee paid` | `A communication fee payment of <amount> <currency> succeeded.` | `{ link: '/payments', paymentId, amount, currency }` |
| `notifyTripEmergency(payload)` | none | `admin_trip_emergency` | `Trip emergency alert` | `<reporterName> triggered emergency on trip <fromName> → <toName>[ at <lat(5dp)>, <lng(5dp)>].` | `{ link: '/trips/<tripId>', tripId, reporterUserId, latitude, longitude }` |

`data.link` doubles as the FCM `webpush.fcmOptions.link` (click-through target in the dashboard).

---

### F-08: Notification catalogue

Every `type` value the backend emits, with its trigger, template, payload and audience.
Localisation is **not** a runtime feature — each template is hard-coded in exactly one language
(Arabic templates are marked AR, the rest are English). There is no i18n layer server-side.

| `type` | Trigger (file) | Title | Body | `data` keys | Audience |
|---|---|---|---|---|---|
| `booking_created` | passenger books a seat — `notifications.service.ts notifyDriverOfNewBooking` | AR `تم حجز مقعد في رحلتك المشتركة` | `<fromName> - <toName>` | `type, screen:'trip_details', entityId, tripId, bookingId, title, route, fromName, toName, departureLabel, distanceKm?, distanceLabel?, meetingPoint, availableSeats, seatsLabel, footerTitle, footerSubtitle, passengerName?` | Trip driver |
| `booking_confirmed` / `booking_rejected` / `booking_canceled` | driver decision — `notifyPassengerOfBookingDecision` | `Booking Confirmed` / `Booking Rejected` / `Booking Cancelled` | `Your booking has been <decision>` | `type, screen:'booking_details', entityId` | Passenger |
| `booking_canceled_by_passenger` | passenger cancels — `notifyDriverOfBookingCancellation` | `Booking Cancelled` | `A passenger cancelled their booking on your trip` | `type, screen:'trip_details', entityId` | Trip driver |
| `booking_cancelled` | admin cancels — `admin.service.ts:773` | `Booking Cancelled` | `Your booking has been cancelled by the administrator.` | — | Passenger |
| `new_trip_posted` | city fan-out — `processCityFanout` | `New Trip Posted` | `A new trip to <toName> is available` | `type, screen:'trip_details', entityId` | All active users in the origin city except the driver |
| `chat_message` | new chat message — `chat-postgres.service.ts:305` | AR `رسالة جديدة` | `<senderName>: <first 50 chars…>` | `chatRoomId` (drives collapse key `chat_<id>`) | Counterparty |
| `presence_prompt` | pre-trip confirm job — `pre-trip-confirm.processor.ts` | AR `تأكيد التواجد في السيارة` | AR `رحلتك إلى <toName> ستبدأ قريبًا. يرجى تأكيد تواجدك داخل السيارة.` | `tripId, bookingId` | Each confirmed passenger |
| `presence_driver_prompt` | same job | AR `تأكيد تواجد الركاب` | AR `رحلتك إلى <toName> ستبدأ قريبًا. يرجى مراجعة تواجد الركاب.` | `tripId` | Driver |
| `presence_passenger_declared` | passenger declares presence — `presence.service.ts:455` | AR `تحديث تواجد راكب` | dynamic (`declarationBody(status)`) | verify | Driver |
| `presence_marked_absent` | driver marks a seat absent — `presence.service.ts:581` | AR `تم تسجيل عدم حضورك` | AR `أبلغ السائق أنك لم تحضر للرحلة إلى <toName>. إن كان ذلك غير صحيح يمكنك الاعتراض خلال 24 ساعة.` | verify | Passenger |
| `presence_conflict_admin` | driver marks confirmed passengers absent — `presence.service.ts:344` | AR `تعارض في تأكيد التواجد` | AR `السائق علّم <n> راكبًا كغائب رغم تأكيدهم التواجد في الرحلة إلى <toName>.` | verify | Admins |
| `trip_started` | auto-start processor — `trip-auto-start.processor.ts:114` | AR `بدأت الرحلة` | AR `بدأت رحلتك إلى <toName>. يمكنك مشاركة تتبع الرحلة المباشر مع أحد.` | verify | Driver/passengers |
| `trip_fee_charged` | auto-start processor — `:133` | AR `رسوم الرحلة` | AR `تم خصم <amount> <currency> من محفظتك كرسوم هذه الرحلة.` | verify | Driver |
| `trip_auto_completed` | auto-complete processor — `:121` | AR `تم إنهاء الرحلة تلقائياً` | AR `لم يتم تأكيد الوصول لرحلتك إلى <toName>. تم إنهاؤها تلقائياً.` | verify | Driver/passengers |
| `trip_completed` | driver marks arrived — `trip-time.service.ts:356` | `Trip Completed` | `The trip to <toName> has been completed` | verify | Passengers |
| `trip_cancelled` | driver cancels — `trips.service.ts:728` | `Trip Cancelled` | `The trip to <toName> has been cancelled by the driver` | verify | Passengers |
| `trip_cancelled_by_admin` | admin ban cascade — `admin-ban.service.ts:224` | `Trip Cancelled` | `Your trip to <toName> has been cancelled` | verify | Passengers |
| `passenger_reported_driver_absent` | passenger no-show report — `trip-time.service.ts:108` | `Passenger Reported Absence` | `A passenger reported you are not at the meeting point for trip to <toName>` | verify | Driver |
| `admin_no_show_report` | same flow — `:146` | AR `بلاغ غياب سائق` | AR `راكب بلّغ أن السائق لم يحضر للرحلة إلى <toName>.` | verify | Admins |
| `settlement_marked_paid` | driver marks paid — `settlement.service.ts:93` | AR `تم تأكيد الدفع` | AR `قام السائق بتأكيد استلام المبلغ. يمكنك الآن التواصل معه.` | verify | Passenger |
| `rating_new` | new rating — `ratings.service.ts:114` | AR `تقييم جديد` | AR `وصلك تقييم <n> من 5[ — <comment>]` | verify | Rated user |
| `wallet_credited` | admin tops up a wallet — `admin-dashboard.service.ts:1354` | AR `تم إضافة رصيد إلى محفظتك` | AR `تمت إضافة <amt> <cur> إلى محفظتك. رصيدك الحالي: <bal> <cur>.` | verify | User |
| `driver_fine_issued` | admin issues a fine — `admin-fines.service.ts:88` | AR `تم إصدار غرامة` | AR `تم إصدار غرامة بقيمة <amount>. السبب: <reason>` | verify | Driver |
| `penalty_charged` | automated penalty — `notifications.service.ts notifyPenaltyCharged` | `Penalty Charge Applied` | `A penalty of <amountFormatted> has been charged: <reason>` | `screen: 'wallet'` | Charged user |
| `account_banned` | admin ban — `notifyUserBanned` | `Account Suspended` | `<banReason>` or `Your account has been suspended. Tap for details.` | `screen: 'banned'` | Banned user |
| `account_verified` | admin verifies — `admin.service.ts:286`, `admin-dashboard.service.ts:235` | `Account Verified` | `Your account has been verified by the administrator.` | verify | User |
| `role_changed` | admin changes role — `admin.service.ts:221` | `Role Updated` | `Your role has been changed to <role>` | verify | User |
| `complaint_resolved` / `complaint_rejected` | admin decision — `notifyComplaintStatusChanged`, `complaints.service.ts:152` | `Complaint Resolved` / `Complaint Update` | `Your complaint has been reviewed and resolved.` / `Your complaint could not be actioned at this time.` | `screen: 'complaints', complaintId` | Reporter |
| `admin_broadcast` | admin broadcast — `admin.service.ts:907`, `admin-dashboard.service.ts:902` | admin-supplied | admin-supplied | verify | Selected users |
| `new_user_registered` | registration completes — `auth.service.ts:1020` | verify | verify | verify | Admins |
| `instant_offer` | driver receives an instant-ride offer — `instant-dispatch.service.ts:225` | AR `طلب رحلة جديدة` | multi-line composed | verify | Candidate drivers. **Data-only on Android** (rich custom layout) |
| `instant_raise_fare_nudge` | dispatch wave found nobody — `:143` | AR `لا يوجد سائق قريب حتى الآن` | AR `جرّب رفع سعرك لجذب سائق أسرع.` | verify | Passenger |
| `instant_no_drivers` | request expired / exhausted — `:308` | AR `انتهت مهلة الطلب` or `لا يوجد سائق متاح` | conditional | verify | Passenger |
| `instant_matched` | driver accepted — `instant-rides.service.ts:568` | AR `تم العثور على سائق!` | AR `السائق <name> في الطريق إليك.` | verify | Passenger |
| `instant_offer_cancelled` | passenger cancels — `:288` | AR `أُلغي الطلب` | AR `ألغى الراكب طلب الرحلة.` | verify | Offered drivers |
| `instant_counter_offer` | driver counters the fare — `:649` | AR `عرض سعر من سائق` | AR `عرض السائق <fare> <currency> لرحلتك.` | verify | Passenger |
| `instant_counter_accepted` | passenger accepts counter — `:695` | AR `قبل الراكب عرضك!` | AR `توجّه إلى نقطة الانطلاق.` | verify | Driver |
| `instant_counter_rejected` | passenger rejects counter — `:732` | AR `لم يُقبل عرضك` | AR `رفض الراكب السعر المقترح.` | verify | Driver |
| `admin_driver_registration` | `AdminAlertsService` | `New driver registration` | see F-07 | `link, driverId` | Admins (web push) |
| `admin_fee_payment` | `AdminAlertsService` | `Communication fee paid` | see F-07 | `link, paymentId, amount, currency` | Admins (web push) |
| `admin_trip_emergency` | `AdminAlertsService` | `Trip emergency alert` | see F-07 | `link, tripId, reporterUserId, latitude, longitude` | Admins (web push) |

Convention for client routing: `data.screen` names the destination screen, `data.entityId` the record
to open, and `data.link` (web only) the dashboard path.

Arabic departure-label helper (`formatDepartureLabelAr`, used by `booking_created`):
same calendar day → `اليوم HH:mm`; next day → `غداً HH:mm`; otherwise `DD/MM HH:mm`. Uses the server's
local timezone. Distance shown on the booking card is a Haversine great-circle distance between
`trip.fromPoint` and `trip.toPoint`, rounded to whole km (`R = 6371`), rendered as `<n> كم`.

**Dead code in this subsystem:** `src/modules/notifications/schemas/notification.schema.ts` is a
Mongoose schema (with a 30-day TTL index `expireAfterSeconds: 2592000`) that is not registered in any
module — a leftover from the MongoDB era. Delete on rebuild.

---

## 6. Background Job Catalogue

Two mechanisms coexist: `@nestjs/schedule` `@Cron` (in-process, every replica runs it) and BullMQ
(`bull` v4) delayed/queued jobs backed by Redis.

### 6.1 Cron jobs

| Job | Cron | Registered? | What it does | Idempotency | Failure behaviour | Env knobs |
|---|---|---|---|---|---|---|
| `DriverTripFeeReconciliationJob.reconcileUnchargedTrips` (`src/modules/driver-trip-fee/driver-trip-fee-reconciliation.job.ts:74`) | `*/30 * * * *` (every 30 min) | **Yes** (`DriverTripFeeModule`) | Selects trips with `driverWalletChargeApplied IS NOT TRUE`, `departureTime < now − GRACE`, `departureTime >= now − LOOKBACK`, `status NOT IN (cancelled, draft)`, ordered by `departureTime ASC`, limited to BATCH. Calls `DriverTripFeeService.chargeAtTripStart(trip)` on each. Safety net for delayed `trip-auto-start` jobs lost from Redis. | Yes — `chargeAtTripStart` short-circuits on the trip stamp and on its `trip-fee:<tripId>` audit row; plus the partial unique index `uq_pending_charges_trip_driver_fee` (migration #51). | Per-trip try/catch; a failure increments `failed` and the trip stays unstamped so the next run retries. One bad trip never stalls the sweep. Returns `{ scanned, recovered, failed }`. | `DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES` (60), `_LOOKBACK_HOURS` (72), `_BATCH` (100) — read at **call** time, not decoration time, because decorators evaluate before `ConfigModule` loads `.env`. |
| `NotificationCleanupJob.handleNotificationCleanup` (`src/jobs/notification-cleanup.job.ts:19`) | `0 2 * * *` (02:00 daily) | **NO — not in any `providers[]`** | Would `deleteMany({ createdAt: { $lt: now − 30d } })` on the **Mongo** notifications collection. | n/a | n/a | **DEAD CODE.** No Postgres equivalent exists — the `notifications` table grows unbounded. A rebuild needs a real retention job. |
| `TripExpirationJob.handleTripExpiration` (`src/jobs/trip-expiration.job.ts:14`) | `*/15 * * * *` | **NO — not in any `providers[]`** | Would set Mongo trips `status: 'active' → 'expired'` when `departureTime < now`. | n/a | n/a | **DEAD CODE.** Superseded by the `trip-auto-start` / `trip-auto-complete` Bull jobs. |

### 6.2 BullMQ queues and jobs

All on the single Redis at `REDIS_HOST:REDIS_PORT`, no prefix/db/password.

| Queue | Job name | Scheduled by | Delay | Job id (dedupe key) | Options | What it does |
|---|---|---|---|---|---|---|
| `new-trip-fanout` | `fanout` | `NotificationsService.enqueueCityFanout` | none | auto | `attempts: 3, backoff: 5000` | City fan-out push (F-06) |
| `bookings-timeout` | verify | `bookings.service.ts:810` | `BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS × 1000` else **10 800 000 ms (3 h)** | `booking-expire-<bookingId>` | `attempts: 3, backoff: { exponential, 5000 }, removeOnComplete: true` | Expires a still-pending booking |
| `no-show-detector` | verify | verify | grace **1 800 s (30 min)** default | verify | verify | Detects driver no-show after the grace period. `NO_SHOW_GRACE_OVERRIDE_SECONDS` is documented but no live read was found |
| `pre-trip-confirm` | `send-prompts` | verify (scheduled ~departure − 30 min) | verify | verify | verify | Sends `presence_prompt` to each CONFIRMED booking's passenger and `presence_driver_prompt` to the driver; stamps `trip.preTripConfirmSentAt`. **Idempotent**: skips if the trip is not in `PUBLISHED/FULLY_BOOKED/ACTIVE`, if `preTripConfirmSentAt` is already set, or if there are no confirmed bookings |
| `recurrence-spawn` | `spawn-occurrences` | hourly (verify the scheduler registration) + manual admin trigger `admin-recurrence.controller.ts:67` | none for the manual trigger | manual: `admin-spawn-now-<ruleId>-<Date.now()>` | manual: `attempts: 1, removeOnComplete: true` | Spawns future `trips` rows from active `trip_recurrence_rules`. Window: from `lastSpawnedFor + 1 day` (or `rule.createdAt`) to `min(now + 14 days, rule.until)`. Timezone is pinned to `+03:00` when parsing `lastSpawnedFor`/`until`. **Idempotent per (driverId, departureTime)** — an existing trip logs `recurrence_skip` and is not duplicated. Advances `rule.lastSpawnedFor`. Each spawned trip enqueues a city fan-out and a `trip-auto-start` job |
| `trip-auto-start` | `enforce` | `trips.service.ts:1011`, `recurrence-spawn.processor.ts:201` | `max(0, departureTime − now)` | `trip-auto-start-<tripId>` | `attempts: 2, backoff: { exponential, 15000 }, removeOnComplete: true` | Flips `PUBLISHED/FULLY_BOOKED → IN_PROGRESS` at departure time (no driver button), charges the driver trip fee, notifies (`trip_started`, `trip_fee_charged`), then schedules `trip-auto-complete` |
| `trip-auto-complete` | verify | `trip-auto-start.processor.ts:151` | `departureTime + max(1, TRIP_AUTO_COMPLETE_FALLBACK_HOURS ?? 24) h − now` | `trip-auto-complete-<tripId>` | `attempts: 2, backoff: { exponential, 30000 }, removeOnComplete: true` | Fallback completion when the driver never presses "Arrived"; sends `trip_auto_completed` |
| `pending-charge-collect` | verify | verify | verify | verify | verify | Collects outstanding `pending_charges` from the wallet |
| instant-offer timeout (`INSTANT_OFFER_TIMEOUT_QUEUE`) | verify | `instant-dispatch.service.ts:247`, `instant-rides.service.ts:633` | `OFFER_TTL_SECONDS = 12 s`; counter-offers `COUNTER_TTL_SECONDS = 30 s` | `offerTimeoutJobId(offerId)` | `removeOnComplete: true` | Expires an unanswered driver offer |
| instant dispatch wave | verify | `instant-dispatch.service.ts:165` | `DISPATCH_RETRY_SECONDS = 10 s` | `dispatchWaveJobId(requestId)` | `removeOnComplete: true` | Next dispatch wave / widen radius |
| instant-request expiry (`INSTANT_REQUEST_EXPIRY_QUEUE`) | verify | `instant-rides.service.ts:166,462` | `REQUEST_TTL_SECONDS = 180 s` | `requestExpiryJobId(requestId)` | `removeOnComplete: true` | Terminates a request nobody accepted |
| CliQ poll (`CLIQ_POLL_QUEUE`) | verify | `payments.service.ts:481,506`, re-armed by `cliq-poll.processor.ts:131` | first `60_000 ms`, then `intervalSeconds × 1000` | verify | `removeOnComplete: true` | Background `PaymentInquiry` polling after foreground polling ends |
| `trip-expiration`, `notification-cleanup` | — | — | — | — | — | Registered in `JobsModule` but **no producer and no processor exists**. Dead queue declarations |

**Global reliability notes for a rebuild:**
- Delayed jobs are the *only* mechanism driving trip lifecycle transitions. Redis is configured with
  `maxmemory-policy allkeys-lru`, so jobs can be evicted; the driver-trip-fee cron exists solely as the
  net under that hole. A rebuild should either use a persistent scheduler or add equivalent sweeps for
  auto-start and auto-complete too.
- `jobId` is used as the dedupe key on every lifecycle job; Bull refuses to add a second job with the
  same id while the first is pending. This is the idempotency mechanism.
- No dead-letter queue, no global `defaultJobOptions`, no queue-level concurrency settings.

---

## 7. Deployment Topology

Files: `rideshare-backend/Dockerfile`, `docker-compose.yml`, `docker/nginx/nginx.conf`.

### 7.1 Backend image (`rideshare-backend/Dockerfile`)

Two-stage, `node:20-alpine`.

- **builder**: `apk add python3 make g++` (native modules), `npm install --no-audit --no-fund`,
  `COPY . .`, `npm run build` (`nest build`), `npm prune --production`.
- **production**: `apk add dumb-init`; creates group `nodejs` (gid 1001) and user `nestjs` (uid 1001);
  copies `dist`, `node_modules`, `package*.json` with `--chown=nestjs:nodejs`; `mkdir -p /app/uploads`
  owned by `nestjs:nodejs` (this ownership is what the `backend_uploads` named volume inherits on first
  init, so the non-root process can write uploads); `ENV NODE_ENV=production PORT=3000`; `USER nestjs`;
  `EXPOSE 3000`.
- Healthcheck: `--interval=30s --timeout=10s --start-period=5s --retries=3`,
  `wget --no-verbose --tries=1 --spider http://localhost:3000/api/v1/health`.
- Entrypoint `dumb-init --`, CMD `node dist/src/main.js` (note the `dist/src/` path — `nest build`
  emits `src/` inside `dist` because `seed-admin.ts` lives at the repo root).
- `.dockerignore` excludes `node_modules, dist, .git, Dockerfile*, .env*, *.log, coverage, test, uploads,
  *.rar, build_output.txt, compile_errors.txt`.

### 7.2 docker-compose services

| Service | Image | Ports (host→container) | Volumes | Healthcheck | Depends on |
|---|---|---|---|---|---|
| `postgres` | `postgis/postgis:16-3.4` | `127.0.0.1:${POSTGRES_PORT:-5432}` → 5432 | `postgres_data:/var/lib/postgresql/data` | `pg_isready -U $USER -d $DB`, 10 s / 5 s / 10 retries | — |
| `redis` | `redis:7-alpine` (`redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru`) | `127.0.0.1:${REDIS_PORT:-6379}` → 6379 | `redis_data:/data` | `redis-cli ping`, 10 s / 5 s / 10 retries | — |
| `backend` | built from `./rideshare-backend`, target `production`, tag `rideshare-backend:latest` | none published (internal only) | `backend_uploads:/app/uploads`; `./rideshare-backend/config/firebase-adminsdk.json:/app/config/firebase-adminsdk.json:ro` | `wget --spider http://127.0.0.1:3000/api/v1/health`, 30 s / 10 s / 3 retries / 20 s start period | postgres `service_healthy`, redis `service_healthy` |
| `dashboard` | built from `./rideshare-dashboard`, build args `VITE_API_BASE_URL=${…:-/api}`, `VITE_WS_URL=${…:-/}` | none published | — | `wget --spider http://127.0.0.1/`, 30 s / 5 s / 3 | — |
| `nginx` | `nginx:1.27-alpine` | `${EDGE_HTTP_PORT:-80}:80`, `${EDGE_HTTPS_PORT:-443}:443` | `./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro`, `certbot_www:/var/www/certbot:ro`, `certbot_conf:/etc/letsencrypt:ro`, `nginx_logs:/var/log/nginx` | `nginx -t`, 30 s / 5 s / 3 | backend, dashboard (no condition) |
| `certbot` | `certbot/certbot:v2.11.0` | — | `certbot_conf:/etc/letsencrypt`, `certbot_www:/var/www/certbot` | — | profile `ssl` (not started by default) |

Network: single bridge `rideshare-net`. Named volumes: `postgres_data, redis_data, backend_uploads,
nginx_logs, certbot_conf, certbot_www`.

Backend environment is `env_file: ./rideshare-backend/.env` **plus** compose-level overrides that win:
`NODE_ENV=production`, `PORT=3000`, `OTP_PROVIDER=${OTP_PROVIDER:-local}`,
`FIREBASE_SERVICE_ACCOUNT_PATH=/app/config/firebase-adminsdk.json`, `POSTGRES_HOST=postgres`,
`POSTGRES_PORT=5432`, `POSTGRES_USER/PASSWORD/DB`, `REDIS_HOST=redis`, `REDIS_PORT=6379`.

> Operational gap: **nothing runs `db:migration:run`.** The backend container starts with
> `synchronize: false` and no migration step, so a fresh stack comes up against an empty database.
> Migrations must be run manually (`docker compose exec backend …` is not possible — the production
> image has pruned dev deps and has no `ts-node`; run them from a dev checkout or add a migration
> job/init container).

### 7.3 nginx edge (`docker/nginx/nginx.conf`)

Global: `worker_processes auto`, `worker_connections 1024`, `use epoll`, `multi_accept on`,
`sendfile/tcp_nopush/tcp_nodelay on`, `keepalive_timeout 65`, `server_tokens off`,
`gzip on` (level 6, `min_length 1000`, types incl. `application/json`, `image/svg+xml`),
`client_max_body_size 25M`, `client_body_buffer_size 16K`, `large_client_header_buffers 4 8k`.
Custom `main` log format includes `rt=$request_time urt="$upstream_response_time"`.

Rate-limit zones: `api_limit 10m rate=20r/s`, `auth_limit 10m rate=5r/s`, `conn_limit 10m`.
Server-level `limit_conn conn_limit 30`.

Upstreams: `backend_upstream → backend:3000 (keepalive 32)`, `dashboard_upstream → dashboard:80 (keepalive 16)`.

Response headers added on every response: `X-Frame-Options: SAMEORIGIN`,
`X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`.

| Location | Target | Notes |
|---|---|---|
| `/.well-known/acme-challenge/` | `root /var/www/certbot` | certbot HTTP-01 |
| `/api/` | backend | `limit_req api_limit burst=40 nodelay`, `limit_req_status 429`. Forwards `Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto, X-Request-ID ($request_id)`. `proxy_connect/send/read_timeout 60s`. HTTP/1.1 |
| `/api/v1/auth/` | backend | `limit_req auth_limit burst=10 nodelay` — stricter bucket for auth |
| `/api/docs` | backend | Swagger UI, no rate limit |
| `= /api/v1/health` | backend | `access_log off` |
| `/socket.io/` | backend | **WebSocket upgrade**: `proxy_set_header Upgrade $http_upgrade; Connection "upgrade"`, `proxy_connect/send/read_timeout 7d` |
| `/uploads/` | backend | Proxied (not served from disk by nginx) |
| `/` | dashboard | Vite SPA served by the dashboard's own nginx |

Error pages return JSON:
`429 → {"success":false,"error":{"code":"RATE_LIMIT_EXCEEDED","message":"Too many requests. Please try again later."}}`
and `500/502/503/504 → {"success":false,"error":{"code":"UPSTREAM_ERROR","message":"Upstream service is unavailable."}}`.

Note the header the backend relies on: `UploadUrlInterceptor` reads `x-forwarded-proto` and
`x-forwarded-host`. nginx sets `X-Forwarded-Proto` but **not** `X-Forwarded-Host`, so the interceptor
falls back to `req.get('host')` — which nginx does set via `proxy_set_header Host $host`. Correct, but
fragile if the proxy chain changes.

TLS: this config is HTTP-only by design. A `nginx.ssl.conf` is referenced in comments and is expected
to be mounted in its place once certs exist (`certbot` profile `ssl`).

### 7.4 Pre-flight provisioning checklist

| Service | Required before boot? | Credential fields to obtain | Where they go |
|---|---|---|---|
| **PostgreSQL 16 + PostGIS 3.4** | **Yes** | host, port, user, password, db name, ssl flag | `POSTGRES_HOST/PORT/USER/PASSWORD/DB/SSL`. Must have `postgis` and `uuid-ossp` creatable (superuser on first migration) |
| **Redis 7** | **Yes** (Bull) | host, port | `REDIS_HOST`, `REDIS_PORT`. No auth support in the current code |
| **JWT secrets** | **Yes** | two random high-entropy strings | `JWT_ACCESS_SECRET` (**mandatory — app throws without it**), `JWT_REFRESH_SECRET`. Also set `JWT_EXPIRES_IN` (`15m`), `JWT_REFRESH_EXPIRES_IN` (`7d`) |
| **Twilio** | Only when `OTP_PROVIDER=twilio` | Account SID (`AC…`), Auth Token, Verify Service SID (`VA…`), API Key SID (`SK…`), API Key Secret; optionally a Programmable-SMS number (`+…`) | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`, `TWILIO_API_KEY_SID`, `TWILIO_API_KEY_SECRET`, `TWILIO_PHONE_NUMBER`. **Dev fallback: `OTP_PROVIDER=local` prints codes to the app log — no Twilio account needed.** The Auth Token is additionally required to validate the `/calls/twilio-webhook` signature |
| **Firebase (FCM)** | No (push silently no-ops) | A service-account JSON with `project_id`, `client_email`, `private_key` — **or** those three as env vars. For the dashboard also: Web Push sender id + VAPID key (client-side) | Mount the JSON at `rideshare-backend/config/firebase-adminsdk.json` (compose bind-mounts it read-only to `/app/config/firebase-adminsdk.json` and sets `FIREBASE_SERVICE_ACCOUNT_PATH`). Alternative: `FIREBASE_PROJECT_ID` + `FIREBASE_CLIENT_EMAIL` + `FIREBASE_PRIVATE_KEY`. `FIREBASE_WEB_MESSAGING_SENDER_ID` is documentation-only. **The compose bind mount is mandatory for the container to start — if the host file does not exist, Docker creates a directory in its place and Firebase init fails with a parse error.** |
| **Google Maps** | No (OSRM fallback) | A Maps Platform API key with **Directions API** enabled, server-key restricted | `GOOGLE_MAPS_API_KEY`. Empty → `LocationsService` logs a warning and routes via `https://router.project-osrm.org` |
| **Photon / OSM geocoder** | No | none (public instance) | Optional `PHOTON_BASE_URL` for a self-hosted mirror, `GEOCODER_USER_AGENT` (OSM policy requires an identifiable UA with contact), `LOCATION_AUTOCOMPLETE_COUNTRIES` (≤5 ISO codes) |
| **A2A CliQ / uWallet** | Only for in-app fee payment; validated in production | Base URL, MerchantID, UserID, Password, SecurityKey, CorrelationID, and a **registered HTTPS callback URL** | `A2A_CLIQ_BASE_URL/MERCHANT_ID/USER_ID/PASSWORD/SECURITY_KEY/CORRELATION_ID/CALLBACK_URL`. Config validation **throws at boot** if any is missing when `NODE_ENV=production` |
| **Google OAuth** | Only for social login | Client ID + Client Secret | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| **Facebook OAuth** | Only for social login | App ID + App Secret | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` |
| **AWS S3** | **No — not used** | — | The `AWS_*` vars are inert; uploads go to the `backend_uploads` volume |
| **TLS certificates** | For HTTPS | domain + email for Let's Encrypt | `docker compose --profile ssl run certbot …`, then mount `nginx.ssl.conf` |

Bring-up order per the compose header comments:
`cp .env.example .env` → fill secrets (**and rename `JWT_SECRET` → `JWT_ACCESS_SECRET`**) → place the
Firebase JSON → `docker compose build` → `docker compose up -d` → run migrations → `npm run seed:admin`.

---

## 8. Third-Party Integration Register

| Service | Purpose | SDK / package + version | Env vars | Endpoints / APIs called | Failure mode | Dev/local fallback |
|---|---|---|---|---|---|---|
| **Firebase Cloud Messaging** | Mobile + web push | `firebase-admin@^13.6.1` (Admin SDK) | `FIREBASE_SERVICE_ACCOUNT_PATH`, `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, (`FIREBASE_WEB_MESSAGING_SENDER_ID` — unused) | `messaging().send()`, `messaging().sendEachForMulticast()` (batches of 500) | Missing/invalid credentials → one warning, `firebaseUnavailable = true`, **all pushes become no-ops returning `{0,0}`**. Per-send exceptions return `{0,1}` and are logged. Tokens erroring `messaging/registration-token-not-registered` are deactivated **only** on the city-fan-out path | **Yes** — the app runs fully without Firebase; in-app notifications and WS delivery still work |
| **Twilio Verify** | Phone OTP for registration/login | `twilio@^5.12.1` | `OTP_PROVIDER`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`, `TWILIO_API_KEY_SID`, `TWILIO_API_KEY_SECRET`, `TWILIO_PHONE_NUMBER` | Verify service `verifications.create` / `verificationChecks.create` (`auth.service.ts`) | verify: `src/modules/auth/auth.service.ts:920-960` | **Yes** — `OTP_PROVIDER=local` stores the code and logs it, no network call. Compose defaults to `local` |
| **Twilio Voice (proxy calls)** | Masked driver↔passenger calls | `twilio@^5.12.1` | `TWILIO_AUTH_TOKEN` (webhook signature), proxy number pool | Inbound webhook `POST /api/v1/calls/twilio-webhook` (`@Public`, signature-verified with `twilio.validateRequest(authToken, x-twilio-signature, absoluteUrl, body)`) | Invalid signature → `ForbiddenException('Invalid Twilio signature')`. Empty pool → `NO_PROXY_NUMBERS_AVAILABLE` | No |
| **A2A CliQ (uWallet)** | In-app communication-fee payment | raw `axios` (transitive dep) | `A2A_CLIQ_*` (7 vars) | `POST {BASE_URL}/GetToken` (no `Authorization`; auth via `CorrelationID`/`MerchantID`/`UserID`/`Password` headers + `SecurityKey` body), `POST /Purchase`, `POST /PaymentInquiry` (both `Authorization: Bearer <session token>`) | Session token ~24 h, cached in-process, refreshed with a 60 s buffer; HTTP 401 invalidates the cache and retries. Incomplete config → one warning at construction, requests then fail. In production, missing config **throws at boot** | No. Background reconciliation via the CliQ poll queue (first retry after 60 s) |
| **Google Maps Directions** | Route polyline, distance, duration, live ETA | raw `axios` (`@googlemaps/google-maps-services-js@^3.4.2` is installed but **unused**) | `GOOGLE_MAPS_API_KEY` | `https://maps.googleapis.com/maps/api/directions/json` | Key unset, non-`OK` status, or unusable payload → warn and fall back to OSRM. Both failing → `Failed to load route: OSRM <code> - <message>` | **Yes** — `https://router.project-osrm.org/route/v1/driving/{lng},{lat};{lng},{lat}` (public demo server; not suitable for production load) |
| **Photon (Komoot / OSM)** | Place autocomplete | raw `axios` | `PHOTON_BASE_URL` (default `https://photon.komoot.io`), `GEOCODER_USER_AGENT`, `LOCATION_AUTOCOMPLETE_COUNTRIES` | `GET {PHOTON_BASE_URL}/api/?q=…&limit=6&lang=ar|en[&lat&lon]` | In-process 60 s result cache; per-user limiter 60 req/60 s → throws on breach. Upstream failure → verify: `locations.service.ts` catch branch | Public instance requires no key. Self-host to lift rate limits |
| **Google OAuth 2.0** | Social login | `passport-google-oauth20@^2.0.0` | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Standard OAuth2 authorize/token | verify: `auth/strategies/google.strategy.ts` | No |
| **Facebook Login** | Social login | `passport-facebook@^3.0.0` | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | Standard OAuth2 authorize/token | verify: `auth/strategies/facebook.strategy.ts` | No |
| **AWS S3** | *(intended object storage)* | `@aws-sdk/client-s3@^3.991.0` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET`, `AWS_REGION` | **none — package never imported** | n/a | Local disk (`./uploads`, served at `/uploads`) is the only implementation |
| **MongoDB** | *(legacy datastore)* | `mongoose@^9.2.1`, `@nestjs/mongoose@^11.0.4` | `MONGODB_URI` | Only the one-off `db:backfill` script | n/a | Fully replaced by PostgreSQL |

### 8.1 Full dependency inventory (`package.json`)

**Runtime dependencies (32):**

| Package | Version | Used for | Live? |
|---|---|---|---|
| `@aws-sdk/client-s3` | ^3.991.0 | S3 uploads | **unused** |
| `@googlemaps/google-maps-services-js` | ^3.4.2 | Maps SDK | **unused** (raw axios instead) |
| `@nestjs/bull` | ^11.0.4 | BullMQ integration | yes |
| `@nestjs/common` | ^11.0.1 | framework core | yes |
| `@nestjs/config` | ^4.0.3 | `ConfigModule`, `registerAs` | yes |
| `@nestjs/core` | ^11.0.1 | framework core | yes |
| `@nestjs/jwt` | ^11.0.2 | JWT sign/verify (WS guards, auth) | yes |
| `@nestjs/mongoose` | ^11.0.4 | Mongo ODM integration | **unused at runtime** |
| `@nestjs/passport` | ^11.0.5 | `AuthGuard('jwt')` and strategies | yes |
| `@nestjs/platform-express` | ^11.0.1 | HTTP adapter, `MulterModule`, static assets | yes |
| `@nestjs/platform-socket.io` | ^11.1.13 | WS adapter (default `IoAdapter`) | yes |
| `@nestjs/schedule` | ^6.1.1 | `@Cron` (`ScheduleModule.forRoot()`) | yes |
| `@nestjs/swagger` | ^11.2.6 | OpenAPI at `/api/docs` | yes |
| `@nestjs/terminus` | ^11.0.0 | health checks | yes |
| `@nestjs/throttler` | ^6.5.0 | global 200/60 s rate limit + `@Throttle` | yes |
| `@nestjs/typeorm` | ^11.0.0 | TypeORM integration | yes |
| `@nestjs/websockets` | ^11.1.13 | gateways, `WsException` | yes |
| `bcrypt` | ^6.0.0 | password hashing (admin login, legacy) | yes |
| `bull` | ^4.16.5 | job queues | yes |
| `class-transformer` | ^0.5.1 | DTO/config transformation | yes |
| `class-validator` | ^0.14.3 | DTO/config validation | yes |
| `firebase-admin` | ^13.6.1 | FCM push | yes |
| `helmet` | ^8.1.0 | security headers (`app.use(helmet())`) | yes |
| `jsonwebtoken` | ^9.0.3 | direct sign/verify in `auth.service`, `uploads.controller` | yes |
| `mongoose` | ^9.2.1 | Mongo driver | **unused at runtime** |
| `multer` | ^2.0.2 | file uploads (via `MulterModule`) | indirect |
| `nest-winston` | ^1.10.2 | structured logging | **unused** |
| `passport` | ^0.7.0 | auth strategy runtime | yes |
| `passport-facebook` | ^3.0.0 | Facebook login | yes |
| `passport-google-oauth20` | ^2.0.0 | Google login | yes |
| `passport-jwt` | ^4.0.1 | JWT strategies (access + refresh) | yes |
| `pg` | ^8.20.0 | PostgreSQL driver | yes |
| `reflect-metadata` | ^0.2.2 | decorator metadata | yes |
| `rxjs` | ^7.8.1 | interceptor pipelines | yes |
| `socket.io` | ^4.8.3 | `Server`/`Socket` types + runtime | yes |
| `swagger-ui-express` | ^5.0.1 | Swagger UI rendering | yes |
| `twilio` | ^5.12.1 | OTP + call webhook validation | yes |
| `typeorm` | ^0.3.28 | ORM + migrations CLI | yes |
| `winston` | ^3.19.0 | logging backend | **unused** |

**Missing from `package.json` but imported by `src/`:** `axios` (in `a2a-cliq.service.ts`,
`locations.service.ts`; resolves transitively via `twilio`) and `uuid` (in `uploads.service.ts`).
Both must be added explicitly.

**Dev dependencies of note:** `typescript@^5.7.3`, `jest@^30`, `ts-jest@^29.2.5`, `supertest@^7.2.2`,
`@nestjs/cli@^11`, `eslint@^9.18` + `typescript-eslint@^8.20` + `prettier@^3.4.2`, `ts-node@^10.9.2`,
`tsconfig-paths@^4.2.0`, `source-map-support@^0.5.21`.

**Build/compiler settings (`tsconfig.json`):** `module`/`moduleResolution: nodenext`, `target: ES2023`,
`experimentalDecorators` + `emitDecoratorMetadata`, `strictNullChecks: true` but `noImplicitAny: false`
and `strictBindCallApply: false`, `declaration: true`, `removeComments: true`, `sourceMap: true`,
`incremental: true`, `outDir: ./dist`. `nest-cli.json` sets `sourceRoot: src`, `deleteOutDir: true`.

**Jest:** `testMatch` = `src/**/*.spec.ts`, `test/unit/**/*.spec.ts`, `test/contract/**/*.spec.ts`;
`testEnvironment: node`; coverage from `src/**/*.(t|j)s` into `coverage/`. E2E via
`test/jest-e2e.json`.

---

## 9. Rebuild Priority Fix List

Issues found while reading the code that a reimplementation should not carry forward:

1. **Error codes never reach clients** — `HttpExceptionFilter` puts the numeric HTTP status in
   `error.code` and drops any string `code` from the thrown response object. The entire `ErrorCodes`
   catalogue is therefore invisible over HTTP.
2. **`JWT_SECRET` vs `JWT_ACCESS_SECRET`** — `.env.example` is wrong; the app will not boot from it.
3. **Double response wrapping** — controllers that already return `{ success, data }` get wrapped
   again by `TransformInterceptor`. Pick one convention.
4. **Double validation** — both a built-in and a custom global `ValidationPipe` are registered, with
   different error shapes.
5. **`notifications` table has no retention** — the only cleanup job is dead Mongo code.
6. **`markRead` / `delete` throw bare `Error`** → 500 instead of 404/403.
7. **Single-replica assumptions** — in-memory WS socket map, in-memory throttler storage, in-memory WS
   rate-limit buckets (never pruned), in-memory autocomplete cache. Horizontal scaling needs a shared
   store and a Socket.IO Redis adapter.
8. **Migrations are not run at deploy time**, and two files share timestamp `1745910000000`.
9. **Redis `allkeys-lru` can evict delayed Bull jobs** that drive the trip lifecycle; only the
   driver-trip-fee path has a reconciliation sweep.
10. **Dead weight to remove**: MongoDB (`mongoose`, `@nestjs/mongoose`, all `*.schema.ts`,
    `notification-cleanup.job.ts`, `trip-expiration.job.ts`, `chat.module.ts`, `admin.service.ts`),
    AWS S3 SDK + `s3` config namespace, `winston`/`nest-winston`,
    `@googlemaps/google-maps-services-js`, and the six never-read `platform` config keys
    (`OTP_DEV_BYPASS`, `SETTLEMENT_GRACE_SECONDS`, `MIN_APP_VERSION`, `GOOGLE_PLACES_API_KEY`,
    `FIREBASE_WEB_MESSAGING_SENDER_ID`, `PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS`).
11. **No graceful shutdown** — add `enableShutdownHooks()` so in-flight Bull jobs and DB connections
    drain on SIGTERM.
12. **100 KB JSON body limit** is undocumented and much smaller than nginx's 25 MB; base64 payloads
    will fail confusingly.
