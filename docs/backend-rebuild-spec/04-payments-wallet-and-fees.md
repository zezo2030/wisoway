# 04 — Payments, Wallet & Fees

> **Scope.** `src/modules/payments/`, `src/modules/wallet/`, `src/modules/pending-charges/`,
> `src/modules/refunds/`, `src/modules/settlement/`, `src/modules/driver-trip-fee/`,
> `src/config/a2a-cliq.config.ts`, `src/common/currency/`, plus the money-side of
> `src/modules/admin/` (wallet adjustment, fines, pricing settings, payment approval).
>
> This is the **money domain**. Every claim below is grounded in code; file:line references
> are given for anything subtle. Where the code contradicts its own comments or a spec file,
> that is called out explicitly.
>
> Generated from branch `009-platform-refinements`, 2026-08-21.

---

## 0. Domain overview

### 0.1 What the platform actually charges

The revenue model went through **three generations**, and all three are still visible in the
schema. Only generation 3 is live:

| Gen | Model | Status |
|-----|-------|--------|
| 1 | **Pay-to-unlock**: driver pays a flat "communication fee" per booking to reveal passenger contact details. Cliq/manual `payments` rows with `paymentType='communication_fee'`. | **Dead.** All three endpoints throw `BadRequestException('… not yet migrated to Postgres')`. `communication_fees.feeAmount` survives only as the legacy fallback amount for gen 3. |
| 2 | **Presence-confirmed capture**: a wallet *hold* was placed at contact-unlock, then partially captured at trip end based on how many passengers actually showed up. | **Dead.** `WalletHoldService` was deleted; migration `1747200000000` released every open hold and zeroed `reservedBalance`. The `wallet_holds` table and the `reservedBalance` column still exist and are still read by `GET /wallet/me`, but nothing ever writes them again. |
| 3 | **Fee at trip start** (current): the driver's wallet is debited **once**, when the trip flips to `IN_PROGRESS`, for `seatPrice × totalSeats × driverUnlockPercent%`. Passengers pay the driver **cash**, off-platform; the app is not in the rider's payment path at all. | **Live.** Owned end-to-end by `DriverTripFeeService`. |

Consequences of generation 3 that a reimplementation must honour:

- **The passenger never pays the platform.** `PlatformPricingService.passengerSeatPricing()`
  hard-codes `platformAmount = 0`, `requiresOnlinePayment = false`, and **ignores** the
  `passengerPlatformPercent` column entirely (`platform-pricing.service.ts:44-62`).
- **The only wallet debit tied to a ride is the driver's trip fee.** Everything else that
  moves money is a top-up (credit), an admin adjustment, or a penalty (`pending_charges`).
- **Instant rides carry no platform fee at all.** The only money interaction is the
  negative-balance gate before a driver can go online
  (`instant-rides/driver-availability.service.ts:224`).

### 0.2 The ledger model

Three tables form the ledger. **`wallet_accounts` is the balance-of-record**; the rest is
audit and reservation bookkeeping.

```
users.walletBalance ◄──── mirror (denormalised, lossy) ────┐
users.walletCurrency                                       │
                                                           │
  wallet_accounts  (one row per userId × accountType × currency)
    ├── balance          NUMERIC(14,2)   the money the account owns
    ├── reservedBalance  NUMERIC(14,2)   legacy; always 0 since migration 1747200000000
    │
    ├──< wallet_transactions   append-only audit rows (they do NOT compute the balance)
    │       ├── type, direction, status, amount, currency
    │       ├── referenceType / referenceId   ('trip' / tripId, 'pending_charge' / chargeId)
    │       └── idempotencyKey  UNIQUE  ← the durable double-charge guard
    │
    └──< wallet_holds          legacy reservation rows; no live writer
```

**Critical property: the ledger is not double-entry and transactions are not the source of
truth.** `wallet_accounts.balance` is mutated directly, inside a transaction, under
`SELECT … FOR UPDATE`. `wallet_transactions` rows are written in the same transaction as a
*record* of what happened. Replaying the transaction log would **not** reproduce the balance
(admin adjustments, for example, record `balanceBefore`/`balanceAfter` in metadata rather
than being derivable). There is no platform/system counter-account: money debited from a
driver simply leaves the ledger. A reimplementation may choose real double-entry, but must
preserve the idempotency semantics below.

**Balance semantics:**

```
spendable = balance − reservedBalance          (reservedBalance is always 0 today)
availableBalance = round2(balance − reservedBalance)   ← what GET /wallet/me returns
```

`balance` may go **negative** only through the driver trip fee's partial-debit path? — **no**:
`chargeAtTripStart` debits `min(balance, fee)` and never overdraws, and
`adjustBalanceByAdmin` explicitly rejects an adjustment that would go below zero. The
negative-balance guard (`assertNonNegativeDriverBalance`) therefore exists for legacy rows
and manual SQL, not for a path the current code can produce.
*(verify: `wallet.service.ts:146-160`, `driver-trip-fee.service.ts:280-296`.)*

**Buckets.** `accountType` partitions a user's money: `driver`, `rider`, `system`. A user with
both roles has two independent balances. `system` is defined in the enum but never created by
any code path.

**Multi-currency.** The unique key is `(userId, accountType, currency)`, so a user can
accumulate several rows (e.g. a legacy `EGP` row plus a `JOD` row). Nothing converts between
them. `pickPrimaryWalletLedgerAccount()` (`wallet.service.ts:32-42`) decides which row the app
treats as "the" wallet:

1. among accounts with `balance > 0`, the one with the **highest** balance;
2. else the `JOD` account;
3. else the first row returned.

This selection is used by `GET /wallet/me`, by the driver-fee debit, by pending-charge
collection, and by the legacy mirror sync — so all of them agree on which row is charged.

**Legacy mirror.** `users.walletBalance` / `users.walletCurrency` are a denormalised copy of
the primary ledger row, refreshed by `syncUserLegacyWalletMirror()` after top-ups, driver-fee
debits, and pending-charge deductions — **but not** after `adjustBalanceByAdmin` or
`payTripFromRiderWallet`, which therefore leave the mirror stale.
*(verify: `wallet.service.ts:295-332` and `:354-382` — neither calls the sync.)*

### 0.3 Money representation & rounding

| Concern | Rule |
|---|---|
| Storage | `NUMERIC(14,2)` for wallet money, `DECIMAL(12,2)` for `payments.amount`, `DECIMAL(10,2)` for `pending_charges.amount` / `refund_requests.amount` / `trips.capturedFeeAmount`, `DECIMAL(5,2)` for percentages. |
| Transport in code | TypeORM returns `numeric`/`decimal` as **strings**; the code converts with `Number(...)` and writes back with `.toFixed(2)`. All arithmetic happens in IEEE-754 doubles. |
| Minor units | **Not used.** There is no integer-fils/cents representation anywhere. |
| Rounding mode | `Math.round(x * 100) / 100` — **half-up on positives**, half-*toward-+∞* on negatives. `DriverTripFeeService.round2` adds `Number.EPSILON` first (`Math.round((v + Number.EPSILON) * 100) / 100`) to defeat binary-representation shortfalls such as `1.005`. `PlatformPricingService.round2` does **not** add the epsilon — the two round2 implementations are not identical. |
| Currency default | `JOD` everywhere (column defaults, DTO defaults, `DEFAULT_CURRENCY`). The DB defaults were `EGP` until migration `1743100000000`. |
| Currency mixing | Never validated on the fee path: the fee's currency comes from `communication_fees.currency`, the trip has its own `currency`, and the wallet row has a third. The debit is applied to whichever row `pickPrimaryWalletLedgerAccount` returns, **regardless of currency mismatch**. This is a real defect a reimplementation should fix. |

### 0.4 Environment variables read by this domain

| Variable | Read at | Purpose | Default |
|---|---|---|---|
| `API_PREFIX` | `main.ts:49` | Global route prefix; all paths below are `/{API_PREFIX}/…`. | `api/v1` |
| `A2A_CLIQ_BASE_URL` | `config/a2a-cliq.config.ts:31` | uWallet A2A merchant API root. | `https://api.uwallet.jo/A2AMerchantInterface` |
| `A2A_CLIQ_MERCHANT_ID` | `:33` | Sent as `MerchantID` header **and** in the `/Purchase` body. | `''` |
| `A2A_CLIQ_USER_ID` | `:34` | `UserID` header. | `''` |
| `A2A_CLIQ_PASSWORD` | `:35` | `Password` header (plaintext header auth). | `''` |
| `A2A_CLIQ_SECURITY_KEY` | `:36` | Body field of `/GetToken`. | `''` |
| `A2A_CLIQ_CORRELATION_ID` | `:37` | `CorrelationID` header (a per-merchant constant, **not** per-request). | `''` |
| `A2A_CLIQ_CALLBACK_URL` | `:39` | Sent as `CallBackURL` in `/Purchase`. **No route implements it** — see F-03 note 12. | `https://example.com/api/v1/payments/cliq/callback` |
| `DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES` | `driver-trip-fee-reconciliation.job.ts:140` | How long past `departureTime` a trip must be before the sweep touches it. | `60` |
| `DRIVER_TRIP_FEE_RECONCILE_LOOKBACK_HOURS` | same | How far back the sweep reaches. Bounded so a first deploy cannot retroactively bill historical trips. | `72` |
| `DRIVER_TRIP_FEE_RECONCILE_BATCH` | same | Max trips charged per run. | `100` |
| `SUPPORT_WHATSAPP_E164` | `refunds.service.ts:28` | Support number for the refund WhatsApp deep-link (also used by `BanGuard`). | `+962788883007` |
| `NODE_ENV` | `a2a-cliq.config.ts:44` | When `production`, missing CliQ config **throws at boot**; otherwise only a `logger.warn`. | `development` |

Notes:
- Only the three `DRIVER_TRIP_FEE_RECONCILE_*` knobs are documented in `.env.example`
  (lines 79–90). The `A2A_CLIQ_*` block exists only in the real `.env` (lines 43–51) and is
  **not** in `.env.example` — a reimplementation should add it.
- The env values are read via `envNumber()` **at call time**, not at decorator time,
  deliberately: `@Cron` decorators evaluate while the module graph is built, before
  `ConfigModule` has loaded `.env`.
- There is **no sandbox/production switch**. The only difference between environments is the
  value of `A2A_CLIQ_BASE_URL` (UAT is `https://testapi.uwallet.jo/A2AMerchantInterface`, per
  the spec fixture at `a2a-cliq.service.spec.ts:16`).

### 0.5 Cross-cutting HTTP conventions

- **Global prefix** `api/v1`. Every path in this document is written in full.
- **Global guards**, in order (`app.module.ts:115-131`): `JwtAuthGuard` → `BanGuard` →
  `RolesGuard` → `ThrottlerGuard` (200 req / 60 s, global). Every endpoint here requires a
  Bearer JWT; there are no public money endpoints.
- **Success envelope** (`TransformInterceptor`): `{ "success": true, "data": <handler return> }`.
- **Error envelope** (`HttpExceptionFilter`):
  ```json
  { "success": false,
    "error": { "code": 403, "message": "…", "details": "…",
               "timestamp": "ISO-8601", "path": "/api/v1/…", "method": "POST" } }
  ```
  ⚠ **Gotcha:** `error.code` is the **HTTP status number**, not the domain code. When a service
  throws `new ForbiddenException({ code: 'INSUFFICIENT_BALANCE_FOR_TRIP_FEE', message, balance,
  requiredAmount, currency })`, Nest lifts `message` out of the object and the filter emits only
  `message` + `details` — **the domain `code` and the extra numeric fields never reach the
  client**. (verify: `common/filters/http-exception.filter.ts:62-80`.) Clients relying on
  `ErrorCodes.*` strings from money endpoints are relying on something the filter drops. A
  reimplementation should pass the whole object through.
- **Validation**: global `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true,
  transform: true, enableImplicitConversion: true })`. **This only applies to handler params
  whose type is a DTO class.** Three money endpoints declare their body as an inline TypeScript
  type and are therefore **completely unvalidated**: `POST /payments/cliq/initiate`,
  `POST /wallet/rider/pay-trip`, and `GET /payments/wallet/transactions` query params.

---

## 1. Entity reference (full column definitions)

### 1.1 `wallet_accounts`

DDL: `1700000000000-initialize-postgres.ts:163-177`, `1743100000000` (currency default),
`1746600000000:107-118` (`reservedBalance`). Entity: `wallet-account.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | no | `uuid_generate_v4()` | PK |
| `userId` | `UUID` | no | — | FK → `users(id)` **ON DELETE CASCADE** |
| `accountType` | `wallet_account_type_enum` | no | — | `driver` \| `rider` \| `system` |
| `currency` | `VARCHAR(5)` | no | `'JOD'` | was `'EGP'` before migration 1743100000000 |
| `balance` | `NUMERIC(14,2)` | no | `0` | the balance of record |
| `reservedBalance` | `NUMERIC(14,2)` | no | `'0'` | CHECK `>= 0`; legacy, always 0 |
| `isActive` | `BOOLEAN` | no | `TRUE` | read but never enforced by any debit path |
| `createdAt` / `updatedAt` | `TIMESTAMPTZ` | no | `NOW()` | |

Constraints: `UNIQUE (userId, accountType, currency)` named
`wallet_accounts_user_type_unique`; `CHECK ("reservedBalance" >= 0)` named
`chk_wallet_accounts_reserved_non_negative`. Index: `wallet_accounts_user_idx (userId)`.

### 1.2 `wallet_transactions`

DDL: `1700000000000:180-200`. Entity: `wallet-transaction.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | no | `uuid_generate_v4()` | PK |
| `accountId` | `UUID` | no | — | FK → `wallet_accounts(id)` **CASCADE** |
| `type` | `wallet_transaction_type_enum` | no | — | `topup`, `trip_debit`, `trip_payment`, `refund`, `payout`, `adjustment`, `hold`, `release_hold` |
| `direction` | `wallet_entry_direction_enum` | no | — | `debit` \| `credit` |
| `status` | `wallet_transaction_status_enum` | no | `posted` | `pending`, `posted`, `failed`, `reversed` |
| `amount` | `NUMERIC(14,2)` | no | — | always non-negative; sign lives in `direction` |
| `currency` | `VARCHAR(5)` | no | `'JOD'` | copied from the account row |
| `referenceType` | `VARCHAR` | yes | `NULL` | `'trip'`, `'pending_charge'` |
| `referenceId` | `VARCHAR` | yes | `NULL` | not a FK — plain varchar |
| `idempotencyKey` | `VARCHAR` | yes | `NULL` | **UNIQUE** — the double-charge guard |
| `metadata` | `JSONB` | yes | `NULL` | fee basis snapshot, admin notes, balanceBefore/After |
| `createdAt` | `TIMESTAMPTZ` | no | `NOW()` | no `updatedAt` — rows are append-only |

Indexes: `wallet_tx_account_created_idx (accountId, createdAt)`,
`wallet_tx_reference_idx (referenceId)`, unique `wallet_tx_idempotency_idx (idempotencyKey)`.

**Known idempotency-key namespaces** (a reimplementation must keep these exact strings, since
they are the durable dedupe records):

| Key | Written by | Meaning |
|---|---|---|
| `trip-fee:<tripId>` | `DriverTripFeeService.chargeAtTripStart` | this trip's platform fee has been processed (even if the amount was 0) |
| `cliq-topup:<paymentId>` | CliQ success path (3 call sites) | wallet credited for this CliQ payment |
| `payment-topup:<paymentId>` | admin approval of a manual top-up | wallet credited for this approved payment |
| `<caller-supplied>` / `randomUUID()` | `createTopup`, `payTripFromRiderWallet` | free-form |

### 1.3 `wallet_holds` — legacy, no live writer

DDL: `1700000000000:203-221` + `1746600000000:120-135`. Entity: `wallet-hold.entity.ts`.

| Column | Type | Null | Default |
|---|---|---|---|
| `id` | `UUID` | no | `uuid_generate_v4()` |
| `accountId` | `UUID` | no | FK → `wallet_accounts(id)` CASCADE |
| `amount` | `NUMERIC(14,2)` | no | — |
| `currency` | `VARCHAR(5)` | no | `'JOD'` |
| `status` | `VARCHAR` | no | `'pending'` ⚠ |
| `referenceType` / `referenceId` | `VARCHAR` | yes | `NULL` |
| `expiresAt` | `TIMESTAMPTZ` | yes | `NULL` |
| `capturedAmount` / `releasedAmount` | `NUMERIC(14,2)` | yes | `NULL` |
| `settledAt` | `TIMESTAMPTZ` | yes | `NULL` |
| `metadata` | `JSONB` | yes | `NULL` |
| `createdAt` / `updatedAt` | `TIMESTAMPTZ` | no | `NOW()` |

⚠ The DB default is `'pending'`, a value the `WalletHoldStatus` constant
(`active` \| `captured` \| `released`) never defines. Migration `1747200000000` had to test
`status NOT IN ('captured','released')` rather than `= 'active'` for exactly this reason.

Indexes: `wallet_holds_account_idx`, `wallet_holds_status_idx`, and the partial unique
`uq_wallet_holds_active_reference (referenceType, referenceId) WHERE status = 'active'`.

Only reader left: `WalletService.getActiveHolds()` — which itself has **no controller route**
and no caller. Dead.

### 1.4 `payments`

DDL: `1743000000000-create-payments-table.ts`. Entity: `payment.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | no | `gen_random_uuid()` | PK |
| `tripId` | `UUID` | yes | `NULL` | FK → `trips(id)` **SET NULL** |
| `bookingId` | `UUID` | yes | `NULL` | FK → `bookings(id)` **SET NULL** |
| `userId` | `UUID` | no | — | FK → `users(id)` **RESTRICT** |
| `amount` | `DECIMAL(12,2)` | no | — | |
| `currency` | `VARCHAR(5)` | no | `'JOD'` | (`'EGP'` before 1743100000000) |
| `method` | `VARCHAR` | no | — | `wallet` \| `paymob` \| `manual` \| `cliq_a2a` \| `communication_fee` |
| `status` | `VARCHAR` | no | `'pending'` | `pending` \| `approved` \| `rejected` \| `refunded` |
| `paymentType` | `VARCHAR` | no | `'trip'` | `trip` \| `trip_platform` \| `communication_fee` \| `wallet_topup` \| `wallet_trip_charge` |
| `direction` | `VARCHAR` | yes | `NULL` | `credit` (top-up) \| `debit` (charge) |
| `proofImageUrl` | `TEXT` | yes | `NULL` | manual top-up proof |
| `walletNumber` | `VARCHAR` | yes | `NULL` | manual transfer reference |
| `transactionId` | `VARCHAR` | yes | `NULL` | **our** `MessageTrxID` sent to CliQ |
| `paymentGatewayRef` | `VARCHAR` | yes | `NULL` | CliQ `MSGID`, or the wallet-tx id for `trip_platform` |
| `recipientAliasType` | `VARCHAR` | yes | `NULL` | `ALIAS` \| `MOBL` |
| `recipientAliasValue` | `VARCHAR` | yes | `NULL` | CliQ alias / mobile |
| `adminNote` | `TEXT` | yes | `NULL` | approval/rejection note, or a CliQ failure trace |
| `createdAt` / `updatedAt` | `TIMESTAMPTZ` | no | `now()` | |

Indexes: `idx_payments_user`, `idx_payments_trip`, `idx_payments_booking`,
`idx_payments_status`. `bookings.passengerPaymentId` FKs back with SET NULL
(`fk_bookings_passenger_payment`).

⚠ **No unique constraint of any kind** on `payments`. Nothing prevents two identical top-up
rows. Idempotency lives entirely in `wallet_transactions.idempotencyKey`, which is keyed on
the payment id — so a duplicate *payment* row yields a duplicate *credit*.

### 1.5 `pending_charges`

DDL: `1745903000000` + `1746000000000` (`reason`, `createdByAdminId`) + `1745913000000`
(`correlationId`) + `1747000000000` (new enum label) + `1747100000000` (partial unique).
Entity: `pending-charge.entity.ts`.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | no | `gen_random_uuid()` | PK |
| `userId` | `UUID` | no | — | FK → `users(id)` **CASCADE** |
| `kind` | `pending_charge_kind_enum` | no | — | `passenger_cancellation`, `driver_no_show`, `passenger_no_show`, `driver_trip_fee` |
| `amount` | `DECIMAL(10,2)` | no | — | |
| `status` | `pending_charge_status_enum` | no | `'pending'` | `pending`, `applied`, `waived` |
| `bookingId` | `UUID` | yes | `NULL` | FK → `bookings(id)` SET NULL |
| `tripId` | `UUID` | yes | `NULL` | FK → `trips(id)` SET NULL |
| `walletTransactionId` | `UUID` | yes | `NULL` | the debit that settled it — **no FK** |
| `appliedToBookingId` | `UUID` | yes | `NULL` | booking whose confirmation triggered collection — **no FK** |
| `waivedByAdminId` | `UUID` | yes | `NULL` | no FK |
| `waivedAt` | `TIMESTAMP` (no tz) | yes | `NULL` | |
| `reason` | `TEXT` | yes | `NULL` | admin fine justification |
| `createdByAdminId` | `UUID` | yes | `NULL` | null for system charges |
| `correlationId` | `VARCHAR` | yes | `NULL` | `X-Request-ID` passthrough — **never actually set by any code** |
| `createdAt` / `updatedAt` | `TIMESTAMP` (no tz) | no | `now()` | |

Indexes: `idx_pending_charges_user_status (userId,status)`,
`idx_pending_charges_booking (bookingId)`, and the **partial unique**
`uq_pending_charges_trip_driver_fee (tripId, kind) WHERE kind = 'driver_trip_fee'` — the
database-level guarantee of one platform-fee debt per trip.

⚠ Two of the four enum labels — `passenger_cancellation` and `passenger_no_show` — are
**never written by any code path**. The 5 % / 10 % percentages described in the entity's
doc-comment (`pending-charge.entity.ts:9-13`) are **not implemented anywhere**. Only
`driver_trip_fee` (from `DriverTripFeeService`) and `driver_no_show` (from
`AdminFinesService`, as a manually entered amount) are produced.

### 1.6 `payout_requests`

DDL: `1700000000000:224-243`. Entity: `payout-request.entity.ts`.

| Column | Type | Null | Default |
|---|---|---|---|
| `id` | `UUID` | no | `uuid_generate_v4()` |
| `driverId` | `UUID` | no | FK → `users(id)` CASCADE |
| `amount` | `NUMERIC(14,2)` | no | — |
| `currency` | `VARCHAR(5)` | no | `'JOD'` |
| `status` | `payout_status_enum` | no | `'pending'` (`pending`\|`approved`\|`rejected`\|`paid`) |
| `bankAccountRef` | `VARCHAR(120)` | yes | `NULL` |
| `note` | `VARCHAR(255)` | yes | `NULL` |
| `processedByAdminId` | `UUID` | yes | `NULL` (no FK) |
| `processedAt` | `TIMESTAMPTZ` | yes | `NULL` |
| `createdAt` / `updatedAt` | `TIMESTAMPTZ` | no | `NOW()` |

Indexes: `payout_requests_driver_idx (driverId, createdAt)`, `payout_requests_status_idx`.

### 1.7 `refund_requests`

DDL: `1745910000000:57-84`. Entity: `refund-request.entity.ts`.

| Column | Type | Null | Default |
|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` |
| `userId` | `uuid` | no | FK → `users(id)` CASCADE |
| `bookingId` | `uuid` | yes | `NULL`; FK → `bookings(id)` SET NULL |
| `amount` | `numeric(10,2)` | yes | `NULL` |
| `currency` | `varchar(5)` | no | `'JOD'` |
| `reason` | `text` | no | — |
| `status` | `varchar(16)` | no | `'open'` (`open`\|`contacted`\|`resolved`\|`rejected`) |
| `whatsappContactedAt` | `timestamptz` | yes | `NULL` |
| `resolvedByAdminId` | `uuid` | yes | `NULL` |
| `resolvedAt` | `timestamptz` | yes | `NULL` |
| `adminNotes` | `text` | yes | `NULL` |
| `createdAt` / `updatedAt` | `timestamptz` | no | `now()` |

Index: `idx_refund_requests_status_created (status, createdAt)`.

### 1.8 `settlement_audits`

DDL: `1745909000000:8-33` + `1745913000000` (`correlationId`).
Entity: `settlement-audit.entity.ts`.

| Column | Type | Null | Default |
|---|---|---|---|
| `id` | `UUID` | no | `gen_random_uuid()` |
| `bookingId` | `UUID` | no | FK → `bookings(id)` CASCADE |
| `action` | `VARCHAR(20)` | no | CHECK IN (`mark_paid`, `unmark_paid`, `admin_revert`) |
| `actorId` | `UUID` | no | FK → `users(id)` CASCADE |
| `reason` | `TEXT` | yes | `NULL` — required in practice only for `admin_revert` |
| `correlationId` | `VARCHAR` | yes | `NULL` (never set) |
| `createdAt` | `TIMESTAMPTZ` | no | `now()` |

Indexes: `idx_settlement_audits_booking`, `idx_settlement_audits_actor`.

### 1.9 `communication_fees` — the pricing configuration table

DDL: `1739400000000` + `1739600000000`. Entity: `communication-fee.entity.ts`.
Despite the name, this is **the platform's fee-configuration table**, one row per country.

| Column | Type | Null | Default | Meaning today |
|---|---|---|---|---|
| `id` | `UUID` | no | `uuid_generate_v4()` | PK |
| `countryCode` | `VARCHAR(5)` | no | — | **UNIQUE** (`idx_communication_fees_country`) |
| `feeAmount` | `DECIMAL(10,2)` | no | — | **legacy flat fee**, used only when `driverUnlockPercent = 0` |
| `currency` | `VARCHAR(5)` | no | — | currency the fee is denominated in |
| `isActive` | `BOOLEAN` | no | `TRUE` | `getActiveFeeRow` filters on it |
| `passengerPlatformPercent` | `DECIMAL(5,2)` | no | `0` | **ignored** — passenger fee is hard-coded to 0 |
| `driverUnlockPercent` | `DECIMAL(5,2)` | no | `0` | **the live percentage** for the driver trip fee |
| `lifetimeFreeTripEnabled` | `BOOLEAN` | no | `TRUE` | **ignored** — `DriverTripFeeService` never reads it; the free trip is always granted |
| `createdAt` / `updatedAt` | `TIMESTAMPTZ` | no | `NOW()` | |

Seed data (`payments/seeds/communication-fee.seed.ts`) — note this seeder targets **Mongoose**,
not Postgres, and is therefore itself dead code; the values document intent:

| country | feeAmount | currency |
|---|---|---|
| EG | 50 | EGP |
| JO | **2** | JOD |
| SA | 10 | SAR |
| AE | 25 | AED |
| QA | 25 | QAR |

⚠ `PRICING_COUNTRY` is hard-coded to `'JO'` in `DriverTripFeeService` (`:63`) and
`countryCode = 'JO'` is hard-coded in `BookingsService` (`bookings.service.ts:205`). Rows for
other countries can be configured via the admin API but are never read on the live fee path.

### 1.10 Related columns on other tables

| Table.column | Type | Written by | Meaning |
|---|---|---|---|
| `users.walletBalance` | `DECIMAL(10,2)` def `0` | `syncUserLegacyWalletMirror` | denormalised mirror of the primary ledger row |
| `users.walletCurrency` | `VARCHAR(5)` def `'JOD'` | same | |
| `users.hasUsedLifetimeFreeTrip` | `BOOLEAN` def `false` | `chargeAtTripStart` | one-way latch; consumed on the driver's first billable trip |
| `trips.price` | `NUMERIC(10,2)` | driver | seat price — **the fee basis** |
| `trips.totalSeats` | `INT` def `4` | trip creation | **the fee multiplier** |
| `trips.currency` | `VARCHAR(5)` def `'JOD'` | derived from departure country | |
| `trips.driverWalletChargeApplied` | `BOOLEAN` def `false` | `stampTripCharged` | idempotency layer 1 + the reconciliation sweep's filter |
| `trips.driverWalletChargeAt` | `TIMESTAMP` | same | |
| `trips.capturedFeeAmount` | `DECIMAL(10,2)` | same | how much was actually taken |
| `trips.communicationFeeStatus` | `VARCHAR` def `'not_paid'` | same → `'paid'` | legacy display flag |
| `trips.presenceSettledAt`, `billableSeatCount`, `driverFeeHoldId` | — | **nothing** | generation-2 leftovers |
| `bookings.hasDriverPaidToContact` | `BOOLEAN` | `stampTripCharged` | gates chat/calls (covered in doc 03) |
| `bookings.settledAt`, `settlementGraceUntil` | `TIMESTAMPTZ` | `SettlementService` | driver-confirmed cash receipt |
| `bookings.seatPriceAtBooking`, `platformAmount`, `driverAmount`, `passengerPaymentId` | `DECIMAL(10,2)` / `UUID` | booking creation | today always `platformAmount = 0`, `driverAmount = seatPrice`, `passengerPaymentId = NULL` |

---

## 2. Fee catalog

| # | Fee | Who pays | Who receives | Amount | Charged when | Recorded in |
|---|---|---|---|---|---|---|
| 1 | **Driver shared-trip platform fee** | driver | platform | `round2(seatPrice × totalSeats × driverUnlockPercent / 100)`; if `driverUnlockPercent = 0` → `round2(feeAmount)` (flat) | exactly once, when the trip flips to `IN_PROGRESS` (or by any of the 3 recovery sweeps) | `wallet_accounts.balance` −=; `wallet_transactions` (`trip_debit`, key `trip-fee:<tripId>`); `trips.capturedFeeAmount` / `driverWalletChargeApplied` / `communicationFeeStatus='paid'` |
| 2 | **Driver fee shortfall** | driver (deferred) | platform | `fee − min(balance, fee)` | same moment, when the wallet cannot cover the fee | `pending_charges` (`driver_trip_fee`, `pending`) |
| 3 | **Lifetime free trip** | — | — | `−100 %` of #1 (fee waived entirely) | on a driver's **first** trip that has ≥1 confirmed booking | `users.hasUsedLifetimeFreeTrip = true`; a `0.00` `trip_debit` audit row with `metadata.freeTripApplied = true, discountPercent: 100` |
| 4 | **Admin manual fine** | driver | platform | arbitrary, admin-entered, `> 0` | on `POST /api/v1/admin/fines` | `pending_charges` (`driver_no_show`), with `reason` + `createdByAdminId`; immediate wallet debit attempt |
| 5 | **Passenger seat platform fee** | passenger | platform | **0.00** — hard-coded (`passengerPlatformPercent` ignored) | never | would be `payments` (`trip_platform`) + `wallet_transactions` (`trip_payment`) — dead path |
| 6 | **Communication / pay-to-unlock fee** | driver | platform | `communication_fees.feeAmount` | **never** — all three endpoints throw | dead |
| 7 | **Passenger cancellation / no-show penalties** | passenger | platform | documented as 5 % (cancellation, no-show) and 10 % (driver no-show) in `pending-charge.entity.ts:9-13` | **never — not implemented** | would be `pending_charges` |
| 8 | **Wallet top-up** | — (inbound) | driver/rider wallet | face value, no platform commission taken | on CliQ `StatusCode = 0`, or on admin approval of a manual top-up | `wallet_transactions` (`topup`, `credit`) |
| 9 | **Payout** | platform | driver | requested amount; **no ledger debit occurs** | on `POST /api/v1/wallet/driver/payout-requests` | `payout_requests` only — see F-12 note 3 |

**Worked examples of fee #1** (`driverUnlockPercent = 10`, `currency = JOD`):

| seatPrice | totalSeats | raw | rounded | source |
|---|---|---|---|---|
| 4.00 | 4 | `4 × 4 × 10/100 = 1.6` | **1.60** | `driver-trip-fee.service.spec.ts:56-64` |
| 3.33 | 3 | `3.33 × 3 × 10/100 = 0.999` | **1.00** | `spec:67-74` |
| 50.00 | 4 | `50 × 4 × 10/100 = 20` | **20.00** | `platform-pricing.service.spec.ts:27-40` |
| any | any | `driverUnlockPercent = 0`, `feeAmount = 0.75` | **0.75** | `spec:76-87` |
| any | any | `driverUnlockPercent = 0`, `feeAmount = 25` | **25.00** | `platform-pricing.service.spec.ts:42-55` |

Partial-debit example: fee `1.60`, wallet balance `1.00` →
`charged = round2(min(1.00, 1.60)) = 1.00`, `remainder = round2(1.60 − 1.00) = 0.60`,
balance → `0.00`, one `pending_charges` row for `0.60`.
(`driver-trip-fee.service.spec.ts:402-414`.)

---

## F-01: Wallet balance & transaction history

**What it does:** Returns a user's current wallet balance for their role bucket, and their
recent ledger entries. This is the read-side of the whole money domain.

**Actors:** passenger, driver, admin (any authenticated user, for their own wallet).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/wallet/me` | JWT (any role) | Balance summary for the caller's role bucket |
| GET | `/api/v1/wallet/transactions` | JWT (any role) | Recent ledger entries |
| GET | `/api/v1/payments/wallet/me` | JWT + `@Roles('driver')` | **Legacy** — reads `users.walletBalance` mirror, not the ledger |
| GET | `/api/v1/payments/wallet/transactions` | JWT + `@Roles('driver')` | **Dead** — always returns an empty page |

**Request / Response contracts:**

`GET /wallet/me` — no parameters. Bucket is chosen from the JWT role:
`role === 'driver' ? DRIVER : RIDER` (so `admin` and `passenger` both map to `rider`).

```jsonc
{ "success": true, "data": {
  "accountId": "uuid",
  "accountType": "driver" | "rider" | "system",
  "currency": "JOD",
  "balance": 20,              // number, 2dp
  "reservedBalance": 0.8,     // number; always 0 in practice
  "availableBalance": 19.2,   // round2(balance - reservedBalance)
  "isActive": true } }
```

`GET /wallet/transactions?limit=<n>` — `limit` is untyped (no DTO), clamped in the service to
`min(max(limit, 1), 200)`, default `50`.

```jsonc
{ "success": true, "data": [ {
  "id": "uuid", "type": "topup", "direction": "credit",
  "amount": 25,               // number
  "currency": "JOD",
  "referenceType": "trip" | "pending_charge" | null,
  "referenceId": "uuid" | null,
  "createdAt": "ISO-8601" } ] }
```

`GET /payments/wallet/me` →
`{ balance: number, currency: string, hasUsedLifetimeFreeTrip: boolean }`, read from
`users.walletBalance` / `walletCurrency` / `hasUsedLifetimeFreeTrip`. Because that mirror is
not updated by admin adjustments or rider trip payments, it can disagree with `/wallet/me`.

**Money math:** `availableBalance = Math.round((balance − reservedBalance) × 100) / 100`.
Nothing else.

**Business rules & validation:**
1. Bucket derivation is `role === 'driver' ? driver : rider` — there is no way to read the
   other bucket through the API.
2. `GET /wallet/me` **creates** an account row (currency `JOD`, balance `0`) if the user has
   none. `GET /wallet/transactions` does the same and returns `[]`.
3. When several currency rows exist, `pickPrimaryWalletLedgerAccount` decides which one is
   reported (highest positive balance → JOD → first). `GET /wallet/transactions`, by contrast,
   returns rows across **all** of the bucket's accounts (`accountId IN (…)`), so the list can
   contain entries in a currency the summary does not show.
4. Transactions are ordered `createdAt DESC` with no pagination cursor — `limit` only.
5. No filter by type/status is available.

**Data model:** reads `wallet_accounts`, `wallet_transactions`, `users`.

**State machine:** none.

**Transactions & locking:** none — plain reads. `getOrCreateAccount` performs a
non-transactional find-then-insert, so two concurrent first-time reads race on
`wallet_accounts_user_type_unique` and one gets a 500. (verify: `wallet.service.ts:61-80`.)

**External services used:** none.

**Background jobs:** none.

**Errors:** `404 Wallet account not found` is not reachable here (accounts are auto-created);
`404 User not found` from `/payments/wallet/me` when the user row is gone.

**Notes for reimplementation:**
- Auto-creating a wallet on read is convenient but makes the read path a write path. Prefer
  creating the account at registration, or use an upsert (`INSERT … ON CONFLICT DO NOTHING`).
- `reservedBalance` and `availableBalance` should be kept in the response shape for client
  compatibility even if holds are not reimplemented; both are always `0` / `= balance`.
- The `users.walletBalance` mirror exists solely for legacy mobile screens. If you rebuild,
  delete it and point `/payments/wallet/me` at the ledger — but note `hasUsedLifetimeFreeTrip`
  genuinely lives on `users`.

---

## F-02: Manual wallet top-up (proof-of-transfer, admin-approved)

**What it does:** A driver or passenger who has transferred money out-of-band (bank/e-wallet)
uploads a proof image and files a top-up request. No money moves until an admin approves it.

**Actors:** driver, passenger (create); admin (approve/reject — see F-04).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/payments/wallet/topup` | JWT + `@Roles('driver','passenger')` | Create a top-up request (`method: 'manual'`) |

**Request contract** — `CreateWalletTopupDto` (`payments/dto/create-wallet-topup.dto.ts`):

| Field | Type | Validators | Required |
|---|---|---|---|
| `amount` | number | `@IsNumber()`, `@Min(0.01)` | yes |
| `currency` | string | `@IsString()`, `@MaxLength(5)` | no — defaults to `'JOD'` |
| `method` | `'manual' \| 'cliq_a2a'` | `@IsString()` only — **the union is not enforced** | yes |
| `proofImageUrl` | string | `@IsString()`, `@MaxLength(500)` | conditionally (see rule 1) |
| `walletNumber` | string | `@IsString()`, `@MaxLength(100)` | no |
| `aliasType` | `'ALIAS' \| 'MOBL'` | `@IsIn(['ALIAS','MOBL'])` | only for `cliq_a2a` |
| `aliasValue` | string | `@IsString()`, `@MaxLength(100)` | only for `cliq_a2a` |

`forbidNonWhitelisted: true` ⇒ any extra property is a `400`.

**Response:** the saved `payments` row:

```jsonc
{ "success": true, "data": {
  "id": "uuid", "userId": "uuid", "tripId": null, "bookingId": null,
  "amount": 100, "currency": "JOD",
  "method": "manual", "status": "pending",
  "paymentType": "wallet_topup", "direction": "credit",
  "proofImageUrl": "https://…", "walletNumber": "079…",
  "createdAt": "…", "updatedAt": "…" } }
```

**Money math:** none at creation. The credit happens at approval (F-04) for exactly
`Number(payment.amount)` in `payment.currency`.

**Business rules & validation:**
1. `method === 'manual'` **and** blank/whitespace `proofImageUrl` ⇒
   `400 "Proof image URL is required for manual top-up"`.
2. `method` values other than `'manual'` and `'cliq_a2a'` fall through to the generic branch and
   create a `pending` row with that arbitrary method string — no enum check exists.
3. There is **no maximum amount** on this endpoint (contrast `CreateTopupDto` for the admin
   endpoint, which caps at `1 000 000`). `@Min(0.01)` is the only bound.
4. No duplicate detection: the same proof image can be submitted any number of times; each
   creates a separate `pending` payment, each independently approvable, each crediting the
   wallet (their idempotency keys differ because they are keyed on the payment id).
5. The proof image URL is not validated as a URL and is not verified to belong to the caller.

**Data model:** inserts one `payments` row.

**State machine:** `pending → approved` (F-04) or `pending → rejected` (F-04). No other
transitions; `refunded` exists in the enum but is never written.

**Transactions & locking:** none — a single insert.

**External services:** none.

**Background jobs:** none.

**Errors:**

| Condition | Status | Body message |
|---|---|---|
| manual without proof | 400 | `Proof image URL is required for manual top-up` |
| `amount < 0.01` / wrong type / unknown property | 400 | class-validator messages in `error.details[]` |
| missing/invalid JWT | 401 | |
| role not driver/passenger | 403 | |

**Notes for reimplementation:** add a per-user rate limit and a duplicate-proof check; the
admin queue is the only fraud control today. Consider a unique key over
`(userId, proofImageUrl)` while `status = 'pending'`.

---

## F-03: CliQ A2A instant wallet top-up (uWallet)

**What it does:** The user enters a CliQ alias or mobile number; the backend asks uWallet to
pull the amount from that account into the merchant account, waits up to ~2 minutes for a final
status, and credits the wallet the moment uWallet reports success. If the status is still
undecided the payment stays `pending` and a background job keeps polling for 24 hours.

**Actors:** driver, passenger.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/payments/wallet/topup` | JWT + `@Roles('driver','passenger')` | Initiate (`method: 'cliq_a2a'`) |
| GET | `/api/v1/payments/{id}/cliq-status` | JWT + `@Roles('driver','passenger','admin')` | Force a status refresh and settle |
| POST | `/api/v1/payments/cliq/initiate` | JWT + `@Roles('driver')` | **Dead** — always throws `400 CliQ not yet migrated to Postgres.` |

**Request contract:** same `CreateWalletTopupDto` as F-02, with `method: 'cliq_a2a'`,
`aliasType ∈ {ALIAS, MOBL}` and a non-blank `aliasValue` both required.

`GET /payments/{id}/cliq-status` takes no body. For non-admins the caller must own the payment.

**Response:** the `payments` row. Its `status` after the call is:
- `approved` — uWallet returned `StatusCode = 0` within the foreground window **and** the
  wallet credit succeeded;
- `rejected` — uWallet returned an immediate terminal rejection (see rule 6); the request
  additionally throws `400` with a localized Arabic message, so the client sees an error, not
  a row;
- `pending` — everything else; background polling has been enqueued.

**Money math:** `amount` is passed through to uWallet unchanged and credited 1:1. No
commission, no FX. `currency` defaults to `'JOD'` and is never sent to uWallet — the gateway
is implicitly JOD-only.

**Business rules & validation:**
1. `aliasType` **and** non-blank `aliasValue` are required ⇒ else `400 "aliasType and
   aliasValue are required for CliQ A2A top-up"`.
2. A `MessageTrxID` is generated with `randomUUID()` and stored in `payments.transactionId`
   **before** contacting uWallet. This is the correlation key for every later inquiry.
3. The payment row is persisted as `pending` before the outbound call, so a crash mid-call
   leaves a recoverable record.
4. `purchaseAndAwait` foreground window: `inquiryMaxWaitMs = 120_000`,
   `inquiryIntervalMs = 3_000` ⇒ up to 40 inquiries. `Purchase` itself has a `30_000` ms
   timeout.
5. **Only `StatusCode === '0'` (or `'000'` in the settle paths) is a confirmed success.**
   uWallet transitions have been observed going `310 → 300 → 0` after a late customer approval,
   so `300` and `310` are explicitly **not** treated as terminal by `awaitFinalStatus`.
6. **Immediate rejection set** (checked against the `/Purchase` response's `errorCode`, before
   any polling): `{ '3010' }` — *CdtrAcct and DbtrAcct matched*, i.e. self-payment. Terminal,
   `status = 'rejected'`, and a `400` is thrown at the caller.
7. On success the wallet is credited via
   `creditPostedTopup({ idempotencyKey: 'cliq-topup:<paymentId>' })`, into the `driver` bucket
   if `user.role === DRIVER`, else `rider`.
8. **Success-but-credit-failed:** if uWallet says `0` and the ledger write throws, the payment
   is left in its current status with `adminNote = "CliQ succeeded but wallet credit failed: …"`
   (truncated to 500 chars) for manual reconciliation. The user's money left their account and
   the wallet was not credited — this is the single worst partial-failure state in the domain.
9. **Network/system error during `purchaseAndAwait`:** not treated as a failure. The payment
   stays `pending` and a poll job is enqueued.
10. Background polling job (`cliq-poll` queue, job `poll-cliq-payment`): first attempt after a
    `60_000` ms delay, then `maxAttempts = 144` at `intervalSeconds = 600` ⇒ **24 hours**.
    Each attempt: reload the payment; if `status !== 'pending'` stop; inquire; on `0`/`000`
    credit + approve + `AdminAlertsService.notifyFeePayment(payment)`; else reschedule. On the
    final attempt, `status = 'rejected'` with
    `adminNote = "[CliQ-poll-timeout] last reason: <reason> after <n> attempts"`.
    Jobs use `removeOnComplete: true, removeOnFail: false`.
11. `GET /{id}/cliq-status` short-circuits if `status` is already `approved` or `rejected`
    (returns the row unchanged) — this is what prevents a double credit on repeated polling.
    It rejects non-`cliq_a2a` payments with `400`, and requires
    `payment.transactionId ?? payment.paymentGatewayRef` to be set (else `400`). The comment at
    `payments.service.ts:120-121` is load-bearing: inquiry must use the **`MessageTrxID` we
    sent** (`transactionId`), *not* the gateway's `MSGID` (`paymentGatewayRef`) — using MSGID
    caused a permanently-pending state.
12. Failure codes in the manual refresh path: `['310','306','FAILED','REJECTED']` ⇒
    `status = 'rejected'`, `adminNote = StatusDescription_ar ?? StatusDescription ?? 'CliQ
    payment rejected'`. Note this **contradicts** `awaitFinalStatus`, which deliberately treats
    `310` as non-terminal. A user who taps "refresh" during a `310` window will have a payment
    that might still settle at uWallet marked rejected here.

**Data model:** `payments` (insert + up to 3 updates), `wallet_accounts`, `wallet_transactions`,
`users` (role lookup + mirror sync).

**State machine (payments, CliQ path):**

```
                     ┌──── StatusCode 0 + credit OK ────► approved  (terminal)
                     │
  (insert) pending ──┼──── errorCode 3010 (immediate)  ─► rejected  (terminal, throws 400)
                     │
                     ├──── 120s elapsed, undecided ────► pending  + poll job
                     │        └─ poll: 0/000 ──────────► approved
                     │        └─ poll: 144 attempts ───► rejected  (poll-timeout)
                     │
                     └──── manual refresh: 310/306/FAILED/REJECTED ─► rejected
```
`approved` and `rejected` are absorbing. Admin `approve`/`reject` (F-04) only accept `pending`.

**Transactions & locking:** the only DB transaction is inside `creditPostedTopup`, which takes
`SELECT … FOR UPDATE` (`pessimistic_write`) on the single `wallet_accounts` row and writes both
the balance update and the `wallet_transactions` row atomically. The `payments` row updates are
**outside** that transaction. Default isolation (`READ COMMITTED`).

**External service — uWallet A2A CliQ (`A2aCliqService`):**

Base URL `${A2A_CLIQ_BASE_URL}`; all calls are `POST`, `Content-Type: application/json`.

*Common headers* (`getBaseHeaders`):
```
CorrelationID: <A2A_CLIQ_CORRELATION_ID>
MerchantID:    <A2A_CLIQ_MERCHANT_ID>
UserID:        <A2A_CLIQ_USER_ID>
Password:      <A2A_CLIQ_PASSWORD>        ← plaintext, every request
Content-Type:  application/json
```

**1. `POST /GetToken`** — no `Authorization` header.
```jsonc
// request
{ "SecurityKey": "<A2A_CLIQ_SECURITY_KEY>" }
// response
{ "TokenInfo": { "Token": "<jwt>", "ExpiryDate": "2026-01-01T00:00:00" },
  "Result":    { "errorCode": 0, "description": "Success" } }
```
Rejected with `400 "Invalid token response from A2A CliQ"` when `TokenInfo.Token` is missing,
or `400 "A2A CliQ token error: <description>"` when `Number(Result.errorCode) !== 0`.
The token is cached in-process and considered valid while
`expiresAt − now > 60_000 ms`. Tokens last ~24 h.

**2. `POST /Purchase`** — `Authorization: Bearer <session token>`.
```jsonc
{ "MessageTrxID": "<uuid we generated>",
  "MerchantID":   "<A2A_CLIQ_MERCHANT_ID>",
  "RAliasType":   "ALIAS" | "MOBL",
  "RAliasValue":  "<alias or mobile>",
  "Amount":       25,
  "CallBackURL":  "<A2A_CLIQ_CALLBACK_URL>" }
// response
{ "errorCode": 0, "description": "Success", "description_ar": "…", "MSGID": "…" }
```
Timeout `30_000` ms. **A timeout is not a failure**: the method returns a synthetic
`{ errorCode: 'TIMEOUT', description: '…', MSGID: null }` and the caller resolves the real
status via `PaymentInquiry`. A missing/undefined `errorCode` ⇒
`400 "Invalid purchase response from A2A CliQ"`. HTTP 401 ⇒ Arabic message
*"رفضت بوابة CliQ المصادقة…"*.

**3. `POST /PaymentInquiry`** — `Authorization: Bearer <session token>`,
`validateStatus: () => true` (never throws on HTTP status).
```jsonc
{ "MessageTrxID": "<the same id sent to /Purchase>" }
// response
{ "MessageTrxID": "…", "RAliasValue": "…", "Amount": 25,
  "StatusCode": "0", "StatusDescription": "Success",
  "StatusDescription_ar": "…", "MSGID": "…" }
```
Non-2xx responses are **normalised, not thrown**: `StatusCode` becomes
`String(data.errorCode)` or the HTTP status, `StatusDescription` becomes
`data.description` or `"HTTP <status>"`. This is deliberate — uWallet returns HTTP 400 with a
meaningful `errorCode: 306` in the body. A body with neither `StatusCode` nor `errorCode` ⇒
`400 "Invalid inquiry response from A2A CliQ"`.

*Auth & retry:* `postCliq` and `paymentInquiry` each retry **exactly once** on HTTP 401, after
invalidating the token cache and fetching a fresh token. No other retries, no backoff, no
circuit breaker.

*Signature verification:* **none.** There is no HMAC, no request signing, no response
signature, and no mTLS. Authentication is header credentials + a bearer session token.

*Webhook/callback:* `CallBackURL` is sent on every purchase, but **no controller implements
`/payments/cliq/callback`** — a repository-wide grep finds the string only in the config file.
Settlement is 100 % poll-driven. If a reimplementation adds the callback it must be idempotent
against the same `cliq-topup:<paymentId>` key.

*Error-code → Arabic message map* (`resolveCliqError`, `payments.service.ts:40-51`):

| code | message (ar) |
|---|---|
| `EE11` | لم يتم العثور على الحساب، تحقق من قيمة الـ alias وأعد المحاولة |
| `EE12` | رصيد غير كافٍ في الحساب |
| `EE13` | الحساب موقوف أو غير فعّال |
| `EE14` | تجاوزت الحد الأقصى للمعاملات اليومية |
| `310` | تم رفض العملية من قِبل مزود الخدمة |
| `300` | انتهت مهلة العملية، حاول مجدداً |
| `001` | بيانات الطلب غير صحيحة |
| *(other)* | falls back to `StatusDescription`, else `فشلت عملية الدفع عبر CliQ` |

**Background jobs:** BullMQ queue `cliq-poll`, job name `poll-cliq-payment`, payload
`{ paymentId, messageTrxId, attempt, maxAttempts, intervalSeconds }`. Self-rescheduling (each
run enqueues the next with `delay: intervalSeconds * 1000`) rather than using a repeatable job.

**Errors:**

| Condition | Status | Message |
|---|---|---|
| missing alias fields | 400 | `aliasType and aliasValue are required for CliQ A2A top-up` |
| immediate terminal rejection | 400 | localized Arabic message from `resolveCliqError` |
| CliQ auth failure (401) | 400 | `رفضت بوابة CliQ المصادقة. راجع إعدادات A2A_CLIQ في البيئة.` |
| gateway malformed response | 400 | `Invalid purchase response from A2A CliQ` |
| refresh: payment missing | 404 | `Payment not found` |
| refresh: not the owner | 403 | `Not authorized to check this payment` |
| refresh: not a CliQ payment | 400 | `Payment is not a CliQ A2A payment` |
| refresh: no trx reference | 400 | `No CliQ transaction reference found for this payment` |

**Notes for reimplementation:**
- **The single credit guarantee is `wallet_transactions.idempotencyKey = 'cliq-topup:<paymentId>'`.**
  Three independent paths can reach it (foreground success, background poll, manual refresh);
  all three pass the same key, and `creditPostedTopup` first does a non-transactional
  `findOne({ idempotencyKey })` and returns the existing row. That pre-check is racy — two
  simultaneous paths can both miss it — but the unique index then makes the loser's transaction
  fail, so at worst you get an error, never a double credit. Handle `23505` explicitly and
  return the winner's row.
- The token cache is **per-process, in-memory**. Multiple instances each hold their own token,
  which uWallet appears to tolerate. A shared cache would reduce `/GetToken` traffic.
- The `payments-cliq-topup.service.spec.ts` file is **stale**: it mocks `purchase` (the current
  code calls `purchaseAndAwait`) and does not provide the `cliq-poll` queue token, so
  `Test.createTestingModule(...).compile()` cannot resolve `PaymentsService`'s
  `@InjectQueue` dependency. Do not treat it as a behavioural spec.
- Consider persisting an outbox row before calling `/Purchase` and reconciling from it, so
  step 8 (success-but-credit-failed) becomes automatically recoverable instead of an admin note.

---

## F-04: Admin approval / rejection of a payment

**What it does:** An admin reviews a pending top-up and either credits the user's wallet or
rejects the request with a note.

**Actors:** admin.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| PATCH | `/api/v1/payments/{id}/approve` | JWT + `@Roles('admin')` | Approve — credits the wallet |
| PATCH | `/api/v1/payments/{id}/reject` | JWT + `@Roles('admin')` | Reject with a note |
| GET | `/api/v1/admin/payments` | JWT + admin | Paginated payment queue (filters: `status`, `method`, `paymentType`, `walletOnly`, `page`, `limit`) |

**Request contracts:**
`ApprovePaymentDto` / `RejectPaymentDto` — both a single optional field:

| Field | Type | Validators | Required |
|---|---|---|---|
| `adminNote` | string | `@IsString()`, `@MaxLength(500)` | no (even for reject, despite the Swagger text saying "required") |

**Response:** the updated `payments` row.

**Money math:** credit of exactly `Number(payment.amount)` in `payment.currency`, into the
bucket derived from `user.role` (`DRIVER → driver`, else `rider`).

**Business rules & validation:**
1. `404 Payment not found` when the id does not exist.
2. `400 Only pending payments can be approved` / `… rejected` — the status guard is the
   double-credit protection at this layer.
3. **Approval is only implemented for `paymentType === 'wallet_topup'`.** Any other type ⇒
   `400 Approval for this payment type is not implemented yet`.
4. Approval credits via `creditPostedTopup({ idempotencyKey: 'payment-topup:<paymentId>' })`
   **before** flipping `status`, then saves `status = 'approved'` and `adminNote`.
   If the status save fails after the credit, a retry is blocked by the pending-status guard —
   but the idempotency key means a retried credit is a no-op, so the state is recoverable.
5. `_adminId` is accepted by both service methods and **discarded** — there is no
   approver audit trail beyond `adminNote` and `updatedAt`.
6. Rejection performs no ledger action at all; the user's out-of-band transfer must be returned
   manually.

**Data model:** `payments` (update), `wallet_accounts` (+balance), `wallet_transactions`
(insert), `users` (role read + mirror sync).

**State machine:** `pending → approved` \| `pending → rejected`. Both absorbing.

**Transactions & locking:** the credit runs in `creditPostedTopup`'s transaction with
`SELECT … FOR UPDATE` on the wallet row. The `payments` update is a separate statement.

**External services:** none.

**Errors:** `404`, `400` (as above), `401`, `403`.

**Notes for reimplementation:** record the approving admin id and a decision timestamp; wrap
the credit and the status flip in one transaction; extend approval to the other payment types
or delete them from the enum.

---

## F-05: Admin instant wallet credit (`POST /wallet/topup`)

**What it does:** A direct, no-proof, immediate wallet credit. Intended for testing and manual
ops only.

**Actors:** admin only (double-guarded).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/wallet/topup` | JWT + `@Roles('admin')` | Instantly credit **the calling admin's own** rider wallet |

**Request contract** — `CreateTopupDto` (`wallet/dto/create-topup.dto.ts`):

| Field | Type | Validators | Required |
|---|---|---|---|
| `amount` | number | `@IsNumber()`, `@Min(1)`, `@Max(1000000)` | yes |
| `currency` | string | `@IsString()` | no → `'JOD'` |
| `idempotencyKey` | string | `@IsString()` | no → `randomUUID()` |
| `note` | string | `@IsString()` | no |

**Response:** the created `wallet_transactions` row.

**Money math:** `balance := (Number(balance) + amount).toFixed(2)`. Note this is **not**
`round2`'d before `toFixed` — a float artifact would be truncated by `toFixed`'s own rounding.

**Business rules & validation:**
1. `@Roles('admin')` on the route **and** an explicit `role !== 'admin'` check in the service
   that throws `403 "Use POST /payments/wallet/topup with payment proof. Wallet credit is
   applied after admin approval."`
2. The credit lands in `WalletAccountType.RIDER` for `userId = <the calling admin>`. **There is
   no way to top up another user's wallet through this endpoint** — the target is always the
   caller. (Admins credit other users via F-06 instead.)
3. Omitting `idempotencyKey` generates a fresh UUID, so repeated identical calls each credit
   again.
4. `amount` must be `≥ 1` (unlike F-02's `≥ 0.01`) and `≤ 1 000 000`.
5. `creditPostedTopup` additionally rejects non-finite or `≤ 0` amounts with
   `400 "Invalid top-up amount"`.

**Data model:** `wallet_accounts` (create-if-absent + balance), `wallet_transactions`
(`topup`/`credit`/`posted`, `metadata: { note }`), `users` (mirror sync).

**Transactions & locking:** one `dataSource.transaction`; `SELECT … FOR UPDATE` on the account
row; balance update + transaction insert + mirror sync all inside.

**Errors:** `403` (non-admin), `400` (validation / invalid amount), `404 Wallet account not
found` if the row disappears between the create and the lock.

**Notes for reimplementation:** either delete this endpoint or make the target user a required
parameter — an "admin top-up" that can only credit the admin is a footgun.

---

## F-06: Admin wallet inspection & manual adjustment

**What it does:** Lets an admin browse every wallet account, inspect one, list its
transactions, and post a manual signed correction.

**Actors:** admin.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/wallets` | JWT + admin | List accounts (`page`, `limit`≤100, `accountType`, `search`, `minBalance`, `maxBalance`, `isActive`) |
| GET | `/api/v1/admin/wallets/{id}` | JWT + admin | One account with its user |
| PATCH | `/api/v1/admin/wallets/{id}/adjust` | JWT + admin | Signed balance adjustment |
| GET | `/api/v1/admin/wallets/{id}/transactions` | JWT + admin | Paginated ledger for one account |

**Request contract** — `AdminAdjustWalletDto`:

| Field | Type | Validators | Required |
|---|---|---|---|
| `amount` | number | `@IsNumber()`, `@Min(-1000000)` | yes — **signed**; positive credits, negative debits. No upper bound. |
| `currency` | string | `@IsString()` | no — defaults to the account's own currency |
| `note` | string | `@IsString()`, `@MaxLength(500)` | no |

**Money math:**
```
next = Number(balance) + amount        // amount is signed
if (next < 0) → 400
balance := next.toFixed(2)
tx.amount    := Math.abs(amount).toFixed(2)
tx.direction := amount > 0 ? credit : debit
tx.metadata  := { note, adminId, balanceBefore, balanceAfter }
```
Example: balance `12.40`, `amount: -3.15` ⇒ balance `9.25`, tx `{ type: adjustment,
direction: debit, amount: "3.15" }`.

**Business rules & validation:**
1. `400 "Adjustment amount must be non-zero"` for `0` or non-finite.
2. `404 "Wallet account not found"` for an unknown account id.
3. `400 "Currency does not match wallet currency"` if `currency` is supplied and differs.
   (The admin controller always passes `wallet.currency` as the fallback, so this only fires
   when the caller explicitly sends a mismatched code.)
4. `400 "Adjustment would make wallet balance negative"` — an admin **cannot** push a wallet
   below zero.
5. The adjustment does **not** call `syncUserLegacyWalletMirror`, so `users.walletBalance`
   goes stale after every admin adjustment.
6. No idempotency key is written — a double-submitted adjustment applies twice.
7. The `adminId` is recorded only inside `metadata`, not in a dedicated column.

**Data model:** `wallet_accounts` (balance), `wallet_transactions`
(`adjustment` / `debit`\|`credit` / `posted`).

**Transactions & locking:** `dataSource.transaction` + `pessimistic_write` on the account row.

**Errors:** `400` (as above), `404`, `401`, `403`.

**Notes for reimplementation:** require a reason, write the admin id to a real column, add an
idempotency key, and sync the mirror.

---

## F-07: Driver trip-fee quote and publish-time balance guard

**What it does:** Tells a driver in advance exactly what a trip of a given shape will cost them,
and refuses to publish (or to raise the price of) a trip the driver's wallet cannot cover.

**Actors:** driver (quote + guard); the guard is enforced server-side on trip create/update.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/trips/fee-quote?seatPrice=&totalSeats=` | JWT (any authenticated user) | Fee a trip of this shape will cost |
| GET | `/api/v1/trips/{id}/pricing-preview` | JWT | Full passenger + driver-unlock breakdown for an existing trip |
| POST | `/api/v1/trips` | JWT + driver | Publish — guard runs (see rules) |
| PATCH | `/api/v1/trips/{id}` | JWT + driver | Edit — guard re-runs if `price` changes and the trip is unbilled |

**Request / Response contracts:**

`GET /trips/fee-quote` — query params are raw strings coerced with `Number(… ?? 0)`; there is
no DTO and therefore no validation. Missing params yield `0`. Response:

```jsonc
{ "success": true, "data": {
  "amount": 1.6,        // the fee
  "seatPrice": 4,       // round2 of the input
  "totalSeats": 4,
  "percent": 10,        // driverUnlockPercent from the JO fee row
  "currency": "JOD" } }
```

`GET /trips/{id}/pricing-preview` →
```jsonc
{ "tripId": "uuid",
  "passenger": { "seatPrice": 50, "passengerPlatformPercent": 0, "platformAmount": 0,
                 "driverAmount": 50, "currency": "JOD", "requiresOnlinePayment": false },
  "driverUnlock": { "feeAmount": 20, "currency": "JOD", "driverUnlockPercent": 10,
                    "legacyFlatFeeAmount": 2, "seatPrice": 50, "totalSeats": 4 } }
```

**Money math:**
```
row  = communication_fees WHERE countryCode = 'JO' AND isActive = true
pct  = Number(row?.driverUnlockPercent ?? 0)
flat = Number(row?.feeAmount ?? 0)

fee  = pct > 0 ? round2(seatPrice * totalSeats * pct / 100)
                : round2(flat)

currency = row?.currency ?? basis.currency ?? 'JOD'
```
`round2(v) = Math.round((v + Number.EPSILON) * 100) / 100`.
The fee is on **`totalSeats`, not booked seats** — a driver pays the same whether the car fills
or not. Worked examples in §2.

**Business rules & validation:**
1. The guard compares the fee against `getWalletSummary(driverId, 'driver').balance` — the
   **full** balance, not `availableBalance`.
2. `balance < fee` ⇒ `403` with
   `code: INSUFFICIENT_BALANCE_FOR_TRIP_FEE`, `balance`, `requiredAmount`, `currency`, and the
   Arabic message *"رصيد محفظتك (X) لا يغطي رسوم الرحلة (Y). اشحن محفظتك قبل نشر الرحلة."*
   (Remember the filter drops the structured fields — §0.5.)
3. **Equality passes:** `balance === fee` is allowed (`spec:89-105`). `fee − 0.01` fails
   (`spec:106-118`). A negative balance always fails (`spec:119-131`).
4. Nothing is reserved between publish and start — that is precisely why the whole fee must be
   covered up front.
5. On `PATCH /trips/{id}`, the guard is re-run **only when `price` is present and
   `trip.driverWalletChargeApplied !== true`**. Rationale in `trips.service.ts:605-622`:
   publish 4 seats at `1.00` with `0.50` in the wallet (fee `0.40`, passes), then PATCH price to
   `20.00` → fee `8.00` against the same `0.50`. Once the trip is billed the amount is final and
   must never be re-guarded.
   ⚠ **The guard is not re-run when `totalSeats`/`availableSeats` change**, only on `price`.
6. Two further publish-time gates live outside this service but block the same action:
   `PendingChargesService.getOutstandingSummary(driverId).count > 0` ⇒ `403
   OUTSTANDING_CHARGES` (`trips.service.ts:142-152`), and, for instant rides,
   `assertNonNegativeDriverBalance` ⇒ `403 NEGATIVE_WALLET_BALANCE`.
7. `GET /trips/fee-quote` is **not role-restricted** and leaks the platform's fee configuration
   to any authenticated user. Harmless but worth noting.

**Data model:** reads `communication_fees`, `wallet_accounts`; writes nothing.

**State machine:** none.

**Transactions & locking:** none — reads only. There is a TOCTOU window between the guard and
the charge at trip start; it is accepted by design, and the charge handles the shortfall.

**External services:** none.

**Errors:** `403 INSUFFICIENT_BALANCE_FOR_TRIP_FEE`; `403 OUTSTANDING_CHARGES`;
`404 Trip not found` for the pricing preview.

**Notes for reimplementation:** re-run the guard on any change to `price` **or** `totalSeats`;
validate the `fee-quote` query params; consider actually reserving the fee at publish so the
shortfall path becomes rare.

---

## F-08: Driver trip-fee charge at trip start (the one debit)

**What it does:** Debits the driver's wallet, once per trip, for the platform fee, at the moment
the trip flips to `IN_PROGRESS`. Whatever the wallet cannot cover becomes a pending charge. The
fee is never refunded, never recomputed, and never charged twice.

**Actors:** system only (no HTTP surface).

**Callers** — four, all funnelling into the same idempotent method:

| Caller | When |
|---|---|
| `TripAutoStartProcessor` (`bookings/processors/trip-auto-start.processor.ts:100`) | the normal path — delayed BullMQ job at departure time |
| `TripTimeService.completeTrip` (`trip-time.service.ts:272`) | driver taps "Arrived" and the trip was never stamped |
| `TripAutoCompleteProcessor` (`bookings/processors/trip-auto-complete.processor.ts:68`) | 24 h fallback completion, trip never stamped |
| `DriverTripFeeReconciliationJob` (F-09) | cron sweep for trips whose auto-start job was lost |

**Money math:**
```
quote     = computeExpectedFee({ seatPrice: trip.price, totalSeats: trip.totalSeats, currency })
available = max(Number(account.balance), 0)
charged   = round2(min(available, quote.amount))
remainder = round2(quote.amount - charged)

account.balance := round2(Number(account.balance) - charged).toFixed(2)
```
Worked: fee `1.60`, balance `10.00` ⇒ charged `1.60`, remainder `0`, balance `8.40`.
Fee `1.60`, balance `1.00` ⇒ charged `1.00`, remainder `0.60`, balance `0.00` + a `0.60`
pending charge. Fee `1.60`, balance `0.00` ⇒ charged `0`, remainder `1.60`, a `1.60` pending
charge, and **a `0.00` audit row is still written**.

**Business rules & validation (numbered, in execution order):**

1. Compute the quote from the **trip's current** `price` / `totalSeats`, not from anything
   frozen at publish time.
2. **Idempotency layer 1** — if `trip.driverWalletChargeApplied` is true, return
   `{ charged: Number(trip.capturedFeeAmount ?? 0), pendingRemainder: 0, applied: false,
   reason: 'already-charged' }` without touching anything.
3. **Idempotency layer 2** — look up `wallet_transactions WHERE idempotencyKey =
   'trip-fee:<tripId>'`. If found, *converge*: re-assert the shortfall recorded in
   `metadata.shortfall`, stamp the trip, and return `applied: false, reason: 'already-charged'`.
   This layer exists because the ledger commit and the trip stamp are **not** atomic; without it,
   a retry would collide with the unique index inside the transaction, throw, never stamp the
   trip, and the sweep would retry forever.
4. Count bookings with `status IN (CONFIRMED, IN_PROGRESS)`. Both statuses count because the
   auto-start processor flips confirmed bookings to `IN_PROGRESS` **before** calling.
5. **Ordering is load-bearing at every call site**: the charge must run **before** any booking
   status is moved out of `{CONFIRMED, IN_PROGRESS}`. If bookings are flipped first, the set is
   empty, branch 7 fires, a `0.00` audit row is written, the trip is stamped, and the fee is
   permanently zeroed — and the trip also disappears from the reconciliation query
   (`driverWalletChargeApplied IS NOT TRUE`). Documented at
   `trip-time.service.ts:250-269` and `trip-auto-complete.processor.ts:49-65`.
6. Lock the driver's `users` row (`pessimistic_write`) and **all** the driver's `driver` wallet
   accounts (`pessimistic_write`, `ORDER BY wa.id ASC` — the consistent lock order that prevents
   deadlocks between concurrent chargers). Choose the account with
   `pickPrimaryWalletLedgerAccount`.
7. **No bookings** ⇒ write a `0.00` audit row with `metadata.reason = 'no-bookings'`, return
   `charged: 0, reason: 'no-bookings'`. No money moves.
8. **Lifetime free trip** ⇒ if `driver.hasUsedLifetimeFreeTrip` is false, set it to true, write a
   `0.00` audit row with `metadata = { …basis, freeTripApplied: true, discountPercent: 100 }`,
   return `reason: 'free-trip'`. The latch is consumed on the driver's first trip that has at
   least one booking — an empty trip does **not** burn it (branch 7 runs first).
   ⚠ `communication_fees.lifetimeFreeTripEnabled` is **not consulted**; the free trip cannot be
   switched off through configuration.
9. **No driver wallet account at all** ⇒ log an error and return `charged: 0, remainder: 0`
   with no audit row and **no pending charge**. Deliberate: `wallet_transactions.accountId` is
   `NOT NULL`, so no dedupe record could be written, and recording a debt here would
   double-record on the next sweep. (`spec:517-528`.)
10. Otherwise: compute `charged`/`remainder`, mutate the balance when `charged > 0`, sync the
    legacy mirror, and **always** write the audit row — including when `charged === 0` against
    an empty wallet. The row *is* the idempotency record; it must exist even when no money moved.
11. Audit row shape: `type: trip_debit`, `direction: debit`, `status: posted`,
    `amount: charged.toFixed(2)`, `currency: quote.currency`, `referenceType: 'trip'`,
    `referenceId: trip.id`, `idempotencyKey: 'trip-fee:<tripId>'`,
    `metadata: { seatPrice, totalSeats, percent, formula: 'seatPrice * totalSeats * percent%',
    feeAmount, shortfall }`. The basis snapshot means a mid-trip percent change cannot alter
    what was captured.
12. **Idempotency layer 3** — if the transaction throws a Postgres unique violation (`23505`,
    or a message containing `duplicate key value` / `wallet_tx_idempotency_idx`), the rollback
    has already undone this side's balance mutation; re-read the winner's row and converge on
    it. Any other error propagates. (`spec:488-506` asserts the loser's balance is restored.)
13. **Shortfall recording** (`settleShortfall`): `amount <= 0` ⇒ nothing to do. Otherwise check
    for an existing `pending_charges` row with `(tripId, kind = driver_trip_fee)`; if absent,
    call `PendingChargesService.record(...)`. That check and the insert are **not atomic**; the
    partial unique index `uq_pending_charges_trip_driver_fee` is the real guarantee, and a
    `23505` there is swallowed as success (the debt is on file, which is the desired outcome).
    Any other error ⇒ return `false`.
14. **Stamping is conditional on the debt being on file.** `stampTripCharged` runs only when
    `settleShortfall` returned `true`. If the debt could not be recorded, the trip is left
    **unstamped on purpose** so the reconciliation sweep repairs it.
15. `stampTripCharged` writes, in this order: (a) `bookings.hasDriverPaidToContact = true` for
    every booking of the trip in `{PENDING, CONFIRMED, IN_PROGRESS}`, then (b)
    `trip.driverWalletChargeApplied = true`, `driverWalletChargeAt = now`,
    `communicationFeeStatus = 'paid'`, `capturedFeeAmount = charged.toFixed(2)`.
    Bookings first, because the trip stamp is what makes the next sweep short-circuit —
    persisting it first would strand those bookings without contact access and nothing would
    retry. On failure the in-memory flags are **rolled back** (so a caller that saves the entity
    later does not persist a stamp the DB rejected) and the error is swallowed.
16. **This method never throws for a business reason** — not for a lost race, not for a failed
    stamp, not for a failed shortfall insert. The trip must be able to start regardless.

**Data model:** `trips` (stamp), `bookings` (`hasDriverPaidToContact`), `users`
(`hasUsedLifetimeFreeTrip`, mirror), `wallet_accounts` (balance), `wallet_transactions`
(audit row), `pending_charges` (shortfall).

**State machine (per trip, fee dimension):**

```
  unstamped ──charge succeeds & debt on file──► stamped (driverWalletChargeApplied = true)
      ▲                                              │
      │                                              └─ terminal: never recomputed,
      └── stamp failed / shortfall insert failed         never refunded
          (deliberately left unstamped for the sweep)
```

**Transactions & locking:** one `dataSource.transaction` (`READ COMMITTED`) containing: the
`users` row lock, the `wallet_accounts` locks, the balance update, the mirror sync, and the audit
row insert. The pending-charge insert and the trip/booking stamp are **outside** it — that
non-atomicity is the reason layers 2, 3 and the convergence logic exist.

**External services:** none.

**Background jobs:** invoked from three BullMQ processors + one cron (F-09).

**Errors:** none surfaced to any client. Failures are logged; the trip proceeds.

**Notes for reimplementation:**
- The three-layer idempotency scheme is the heart of this domain. Reproduce it exactly:
  (1) cheap in-row stamp, (2) read of the unique audit row, (3) unique-violation convergence.
- The `0.00` audit row on the no-bookings / free-trip / empty-wallet branches is **not optional**.
  Dropping it re-opens double-recording of the shortfall.
- The `ORDER BY wa.id ASC` on the account lock is the deadlock guard; keep it.
- Partial failure map: money moved + stamp failed ⇒ sweep converges via layer 2 (safe);
  money moved + shortfall insert failed ⇒ trip unstamped, sweep re-records from
  `metadata.shortfall` (safe); no wallet account ⇒ nothing recorded, fee is **silently lost**
  (this is the one un-recovered case — alerting on that log line is advisable).
- If you add currency validation, do it here: the code will happily debit a `SAR` account for a
  `JOD` fee.

---

## F-09: Driver trip-fee reconciliation sweep (cron)

**What it does:** Finds trips that are past their departure time and still carry no fee stamp —
the signature of an auto-start job lost from the queue (Redis restart without persistence, queue
flush, manual removal) — and runs the same idempotent charge.

**Actors:** system (scheduler).

**API Endpoints:** none. `reconcileUnchargedTrips()` is public and returns
`{ scanned, recovered, failed }`, but no controller exposes it.

**Schedule:** `@Cron('*/30 * * * *')` — **every 30 minutes** (`ScheduleModule.forRoot()` in
`app.module.ts:74`).

**Query:**
```sql
SELECT * FROM trips trip
 WHERE trip."driverWalletChargeApplied" IS NOT TRUE     -- nullable column ⇒ IS NOT TRUE, not = false
   AND trip."departureTime" <  :graceCutoff
   AND trip."departureTime" >= :lookbackFloor
   AND trip.status NOT IN ('cancelled', 'draft')
 ORDER BY trip."departureTime" ASC
 LIMIT :batch
```
with
```
graceCutoff   = now − DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES  minutes   (default 60)
lookbackFloor = now − DRIVER_TRIP_FEE_RECONCILE_LOOKBACK_HOURS hours     (default 72)
batch         = DRIVER_TRIP_FEE_RECONCILE_BATCH                          (default 100)
```

**Money math:** none of its own — it delegates entirely to `chargeAtTripStart` (F-08).

**Business rules & validation:**
1. **Grace window.** A trip must be at least `GRACE_MINUTES` past `departureTime` before the
   sweep touches it, so a merely-late auto-start job is not raced.
2. **Lookback floor.** Deliberately bounded: without it, the first deploy of this job would
   retroactively charge every historical trip that was never billed under the old pay-to-unlock
   model. Anything older is an admin data question, not a cron job's business.
3. **Excluded statuses:** `CANCELLED` (never ran ⇒ never charged) and `DRAFT` (never published,
   no bookings — charging would only write a `0.00` row).
4. Batch cap so one bad window cannot stall the scheduler.
5. `envNumber()` accepts a value only if it is present, non-empty, finite and **> 0**; anything
   else silently falls back to the default. Read at **call time**, not decoration time.
6. **`applied === false` is not a recovery.** A short-circuit on F-08's own idempotency means the
   money was already taken; it increments neither `recovered` nor `failed`.
7. One failing trip must never stop the sweep: the exception is caught, `failed++`, and the loop
   continues. A failed charge leaves the trip unstamped by design, so the next run retries it.
8. When `trips.length > 0` the job logs at **warn** level — a non-empty sweep is an anomaly worth
   alerting on.

**Data model:** reads `trips`; all writes are F-08's.

**Transactions & locking:** none at this level.

**Errors:** never propagates; all per-trip errors are logged and counted.

**Notes for reimplementation:**
- Keep the lookback floor. It is the only thing standing between a deploy and a mass retroactive
  billing event.
- The sweep is **not** distributed-lock protected: N application instances each run their own
  cron and can process the same trip simultaneously. That is safe only because F-08's layer-3
  unique-violation convergence exists. If you weaken F-08's idempotency, you must add a lock.
- Cancelled trips being excluded means a trip cancelled *after* it started is never billed. That
  is intentional per the code, but worth confirming as a product decision.

---

## F-10: Pending charges (deferred debt)

**What it does:** Records money a user owes the platform that their wallet could not cover at the
time, and keeps trying to collect it — on demand, at booking confirmation, or when an admin
waives it. An outstanding pending charge blocks a driver from publishing new trips.

**Actors:** passenger, driver (view + self-collect); admin (waive); system (record + collect).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/me/pending-charges` | JWT + `@Roles('passenger','driver')` | Paginated list of the caller's charges |
| POST | `/api/v1/me/pending-charges/collect` | JWT + `@Roles('passenger','driver')` | Attempt to settle all `pending` charges from the wallet now |
| POST | `/api/v1/admin/pending-charges/{id}/waive` | JWT + `@Roles('admin')` | Waive one charge |

**Request / Response contracts:**

`GET /me/pending-charges` — query: `PaginationDto` (`page ≥ 1` default `1`,
`limit 1..100` default `20`) plus `status?: 'pending'|'applied'|'waived'`.
Response is the standard paginated shape:
```jsonc
{ "success": true, "data": {
  "data": [ { "id":"uuid","userId":"uuid","kind":"driver_trip_fee","amount":"0.60",
              "status":"pending","bookingId":null,"tripId":"uuid",
              "walletTransactionId":null,"appliedToBookingId":null,
              "waivedByAdminId":null,"waivedAt":null,"reason":null,
              "createdByAdminId":null,"correlationId":null,
              "createdAt":"…","updatedAt":"…" } ],
  "meta": { "page":1, "limit":20, "total":1, "totalPages":1 } } }
```
Note `amount` is a **string** here (raw `DECIMAL`), unlike the wallet endpoints which cast to
number.

`POST /me/pending-charges/collect` — no body. Response:
```jsonc
{ "success": true, "data": {
  "appliedCount": 1, "skippedCount": 2,
  "appliedTotal": 0.6, "skippedTotal": 3.4 } }
```

`POST /admin/pending-charges/{id}/waive` — no body; returns the updated charge row.

**Money math:** none of its own — the amount is set by whoever records the charge. Collection
debits exactly `Number(charge.amount)`; `balance := (current − amount).toFixed(2)`.

**Business rules & validation:**

*Recording (`record`)*
1. Always inserts the row as `PENDING` **first**, then attempts an immediate wallet deduction.
   If the deduction succeeds the row is updated to `APPLIED` with `walletTransactionId` set.
2. `record` has **no dedupe of its own** — callers must guard (F-08 does, via the partial unique
   index).
3. A failed immediate collection is swallowed and logged; the row simply stays `PENDING`.

*Collection (`collectOutstanding`)*
4. Loads all `PENDING` charges for the user ordered `createdAt ASC` (oldest debt first) and tries
   each independently. Per-charge failures are caught and pushed to `skipped`.
5. **All-or-nothing per charge, never partial.** `deductFromWallet` returns `null` when
   `balance < amount` — there is no partial settlement of a pending charge (contrast the trip fee,
   which does debit partially).
6. On success: `status = APPLIED`, `walletTransactionId = tx.id`,
   `appliedToBookingId = triggeringBookingId` (`null` for the self-service endpoint).
7. Each charge is deducted in its **own** transaction, so a sweep can partially succeed.

*Deduction (`deductFromWallet`)*
8. Bucket routing (`walletAccountTypeForCharge`): `driver_no_show` and `driver_trip_fee` →
   `DRIVER`; `passenger_cancellation` and `passenger_no_show` → `RIDER`.
9. If the user has no account in that bucket, one is **created with balance `0.00`** and the
   method returns `null` (nothing collected).
10. Locks all of the bucket's accounts `FOR UPDATE`, `ORDER BY wa.id ASC`, then picks the primary
    one. `current < amount` ⇒ return `null`.
11. The debit is written as `type: adjustment`, `direction: debit`, `status: posted`,
    `referenceType: 'pending_charge'`, `referenceId: <chargeId>` — **and no `idempotencyKey`**.
    Nothing at the ledger level prevents the same charge being collected twice; the only guard is
    the `status !== PENDING` transition on the charge row, which is written **after** the ledger
    transaction commits. Two concurrent `collect` calls can therefore double-debit the same
    charge. **This is a real race a reimplementation must close** (use
    `idempotencyKey = 'pending-charge:<chargeId>'`, or lock/CAS the charge row).
12. `syncUserLegacyWalletMirror` is called inside the transaction.

*Waiving*
13. `404 "Pending charge not found"`; `400 "Charge is already <status> and cannot be waived"`
    for anything not `PENDING`.
14. Sets `status = WAIVED`, `waivedByAdminId`, `waivedAt = now`. No ledger entry.

*Gating*
15. `getOutstandingSummary(userId)` returns `{ count, totalAmount }` over `PENDING` rows and is
    used by `TripsService.create` to block publishing with `403 OUTSTANDING_CHARGES` and the
    Arabic message *"لا يمكنك نشر رحلة جديدة قبل تسوية الرسوم المستحقة (n) بإجمالي X."*
16. `collectOutstanding` is documented as being called "at booking confirmation time", but
    **the only live caller is the self-service endpoint** — no booking flow invokes it.
    (verify: repo-wide grep finds `collectOutstanding` only in `pending-charges.*`.)

**Data model:** `pending_charges`, `wallet_accounts`, `wallet_transactions`, `users`.

**State machine:**

```
   (record) ──► PENDING ──deduct succeeds──► APPLIED   (terminal)
                   │
                   └──admin waive──────────► WAIVED    (terminal)
```
No transition out of `APPLIED` or `WAIVED`; there is no un-waive and no reversal.

**Transactions & locking:** one transaction per deduction attempt;
`SELECT … FOR UPDATE ORDER BY wa.id ASC` over the bucket's accounts. The charge-row status update
is **outside** that transaction.

**External services:** none.

**Background jobs:** none — collection is entirely on-demand or at record time. Debt that the
user never triggers a collection for simply sits there forever (and keeps them blocked from
publishing).

**Errors:** `404` (waive, unknown id), `400` (waive, wrong status), `401`, `403`.

**Notes for reimplementation:**
- Add the missing idempotency key and make the charge-status flip part of the ledger transaction.
- Consider a periodic collection sweep; today a driver with a shortfall must top up **and** hit
  `POST /me/pending-charges/collect` (or have it collected by whatever the client does) before
  they can publish again.
- `passenger_cancellation` / `passenger_no_show` are unimplemented. If the product wants them,
  the entity comment specifies 5 % of the booking total (passenger cancellation and no-show) and
  10 % of the sum of confirmed booking totals (driver no-show).

---

## F-11: Admin manual fines

**What it does:** Lets an admin levy an arbitrary monetary penalty on a driver, with a written
justification, reusing the pending-charge machinery.

**Actors:** admin.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/fines` | JWT + `@Roles(ADMIN)` | Paginated fine queue |
| POST | `/api/v1/admin/fines` | JWT + `@Roles(ADMIN)` | Issue a fine |
| PATCH | `/api/v1/admin/fines/{id}/waive` | JWT + `@Roles(ADMIN)` | Waive a fine |
| GET | `/api/v1/admin/no-show-reports` | JWT + admin | Read-only aggregation of passenger-reported driver absences, used to decide whether to fine |

`AdminNoShowController` (`@Controller('admin/no-show-reports')`) is covered in doc 05; the
service performs **no** money mutation — it only reports which trips already have a
`driver_no_show` charge (`fineIssued` / `fineId`).

**Request contracts:**

`CreateFineDto`:

| Field | Type | Validators | Required |
|---|---|---|---|
| `driverId` | string | `@IsUUID()` | yes |
| `amount` | number | `@Type(() => Number)`, `@IsNumber()`, `@Min(0.01)` | yes |
| `reason` | string | `@IsString()`, `@MaxLength(2000)` | yes |
| `tripId` | string | `@IsUUID()` | no |
| `bookingId` | string | `@IsUUID()` | no |

`ListFinesQueryDto`: `status?` (enum), `driverId?` (uuid), `from?` / `to?` (date strings parsed
with `new Date()`), `page?`, `limit?` (capped at 100 in the service, default 20).

**Response (list):**
```jsonc
{ "data": [ { …pendingChargeRow,
              "driver": { "id":"uuid", "name":"…", "phone":"…" } } ],
  "meta": { "page":1, "limit":20, "total":3, "totalPages":1 } }
```

**Money math:** none — the amount is entirely admin-entered.

**Business rules & validation:**
1. `400 "amount must be a positive number"` for non-finite or `≤ 0` (redundant with `@Min(0.01)`).
2. `400 "reason is required"` for blank/whitespace.
3. `404 "Driver not found"`; `400 "Target user is not a driver"` when `user.role !== DRIVER`.
4. The fine is recorded as `PendingChargeKind.DRIVER_NO_SHOW` — **the enum label is reused for
   every manual fine regardless of the actual reason.** `reason` and `createdByAdminId` are
   written in a second `save()` after `record()` returns.
5. Because it goes through `PendingChargesService.record`, an immediate wallet debit is attempted;
   if the driver's balance covers it the fine is `APPLIED` on the spot.
6. A push notification `driver_fine_issued` is sent (fire-and-forget, failures logged only) with
   the Arabic body *"تم إصدار غرامة بقيمة X. السبب: …"*.
7. Listing filters `kind = driver_no_show` only, so `driver_trip_fee` shortfalls never appear in
   the fines queue.
8. `waive` rejects a charge whose `kind !== driver_no_show` with
   `400 "Charge is not a driver fine"`, then delegates to `PendingChargesService.waive`.
9. ⚠ The `reason`/`createdByAdminId` update is a second write **after** `record()` may already
   have collected and marked the charge `APPLIED`. There is no transaction spanning the two, so a
   crash between them leaves a fine with no reason and no issuing admin.

**Data model:** `pending_charges` (insert + update), plus everything `record()` touches.

**State machine:** identical to F-10.

**Errors:** `400`, `404`, `401`, `403`.

**Notes for reimplementation:** give manual fines their own enum label
(`admin_fine`), and write `reason`/`createdByAdminId` in the same insert.

---

## F-12: Driver payout requests

**What it does:** A driver asks to withdraw wallet money to a bank account. The request is
recorded for an admin to process out-of-band.

**Actors:** driver (create). **No admin endpoint exists to process it.**

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/wallet/driver/payout-requests` | JWT (**no role guard**) | Create a payout request |

**Request contract** — `CreatePayoutRequestDto`:

| Field | Type | Validators | Required |
|---|---|---|---|
| `amount` | number | `@IsNumber()`, `@Min(1)` | yes |
| `currency` | string | `@IsString()` | no → the account's currency |
| `bankAccountRef` | string | `@IsString()` | no |
| `note` | string | `@IsString()` | no |

**Response:** the created `payout_requests` row (`status: 'pending'`, `amount` as a
2-dp string).

**Money math:** `amount.toFixed(2)`. **No balance is moved and nothing is reserved.**

**Business rules & validation:**
1. The driver's `DRIVER` account for `dto.currency || 'JOD'` is created if absent.
2. `400 "Insufficient wallet balance for payout"` when `Number(account.balance) < dto.amount`.
3. ⚠ **The balance check is the only control.** The wallet is not debited, no hold is placed, and
   there is no cap on the number of concurrent pending requests — a driver with `100.00` can file
   ten `100.00` payout requests, all of which pass.
4. ⚠ The route has **no `@Roles` guard**, so any authenticated user (including a passenger) can
   create a payout request against their `driver` bucket. It will fail the balance check unless
   that bucket has money.
5. `processedByAdminId` / `processedAt` / the `approved`/`rejected`/`paid` statuses are never
   written by any code — **there is no processing endpoint at all**. Payouts are settled entirely
   outside the system, presumably by direct SQL.

**Data model:** `payout_requests` (insert), `wallet_accounts` (read/create).

**State machine:** `pending` is written; `approved`, `rejected`, `paid` exist in
`payout_status_enum` but are unreachable through the API.

**Transactions & locking:** none. The read-then-insert is not atomic, which is what makes rule 3
exploitable.

**Errors:** `400` (insufficient balance / validation), `401`.

**Notes for reimplementation:** debit-and-hold the amount at request time (or at least count
outstanding pending requests against the balance), add the role guard, and build the admin
approve/reject/paid flow with the matching ledger `payout` transaction.

---

## F-13: Refund requests (off-platform, WhatsApp-mediated)

**What it does:** Records a passenger's refund claim and hands them a pre-filled WhatsApp
deep-link to support. **No money is ever moved by this feature** — it is a tracking record plus a
hand-off.

**Actors:** any authenticated user (create); admin (queue management).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/refund-requests` | JWT (**no role guard**) | File a refund request; returns the WhatsApp link |
| GET | `/api/v1/admin/refund-requests` | JWT + `@Roles(ADMIN)` | Queue listing (`status`, `limit`, `offset`) |
| PATCH | `/api/v1/admin/refund-requests/{id}` | JWT + `@Roles(ADMIN)` | Update status / notes |

**Request contracts:**

`CreateRefundRequestBodyDto`:

| Field | Type | Validators | Required |
|---|---|---|---|
| `bookingId` | string | `@IsUUID()` | no |
| `amount` | string | `@IsDecimal()` — **a string, not a number** | no |
| `currency` | string | `@IsIn(['JOD','USD','EUR'])` | no → `'JOD'` |
| `reason` | string | `@IsString()`, `@IsNotEmpty()`, `@MaxLength(1000)` | yes |

`AdminUpdateRefundBodyDto`: `status` `@IsIn(['contacted','resolved','rejected'])` (required),
`adminNotes` `@MaxLength(2000)` (optional).

**Response (create):**
```jsonc
{ "success": true, "data": {
  "refundRequest": { "id":"uuid","userId":"uuid","bookingId":null,"amount":"12.50",
                     "currency":"JOD","reason":"…","status":"open",
                     "whatsappContactedAt":"…","resolvedByAdminId":null,
                     "resolvedAt":null,"adminNotes":null,"createdAt":"…","updatedAt":"…" },
  "whatsappDeepLink": "https://wa.me/962788883007?text=Hi%2C%20I%20would%20like…" } }
```

**Deep-link construction** (`refunds.service.ts:116-137`):
```
number  = SUPPORT_WHATSAPP_E164 with the leading '+' stripped   (default 962788883007)
prefill = "Hi, I would like to request a refund."
        + "\n" + ("Booking: " + last 8 chars of bookingId  |  "No booking ref")
        + "\n" + ("Amount: <amount> <currency>")            [omitted when amount is null]
        + "\n" + "Reason: <reason>"
        + "\n" + "Ref: " + last 6 chars of userId
url     = https://wa.me/<number>?text=<encodeURIComponent(prefill)>
```

**Money math:** none. `amount` is a claim, stored verbatim.

**Business rules & validation:**
1. The row is always created with `status = 'open'` and `whatsappContactedAt = now` — the
   timestamp is a **proxy for "the user was handed the link"**, not proof of contact.
2. No validation that `bookingId` belongs to the caller, that the booking exists, or that any
   payment was ever made. The FK is `SET NULL`, and TypeORM will surface a FK violation as a 500
   for a non-existent booking id.
3. `PATCH` sets `resolvedByAdminId` + `resolvedAt` only for `resolved` and `rejected`, not for
   `contacted`. `adminNotes` is only written when truthy (it cannot be cleared).
4. Admin listing: `ORDER BY createdAt DESC`, `take = limit ?? 50`, `skip = offset ?? 0`, optional
   `status` filter. `limit`/`offset` are parsed with `parseInt` and **not bounded** — a caller can
   request an unbounded page.
5. `POST /refund-requests` uses `@Request() req` / `req.user.id` rather than the `@CurrentUser`
   decorator, and has no `@Roles`.

**Data model:** `refund_requests` only.

**State machine:**
```
   open ──► contacted ──► resolved
     │           │           
     └───────────┴──────► rejected
```
Transitions are **unvalidated**: any of the three target statuses can be set from any state, and
there is no return path to `open`.

**Transactions & locking:** none.

**External services:** none at runtime — the WhatsApp link is a plain URL handed to the client.

**Errors:** `404 "Refund request not found"` (admin update); `400` validation; `401`; `403`.

**Notes for reimplementation:** this is a CRM record, not a payment feature. If real refunds are
ever needed they must credit the wallet through `creditPostedTopup` with an idempotency key like
`refund:<refundRequestId>`; today nothing does.

---

## F-14: Cash settlement (driver confirms receipt) & audit trail

**What it does:** Since passengers pay the driver in cash, the driver marks a booking as paid,
which is what unlocks chat/calls for that booking. A 5-minute grace window lets the driver undo a
mistake, and admins can force a reversal at any time. Every action is audited.

**Actors:** driver (mark/unmark — **no live route**); admin (revert, read audits).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/admin/bookings/{id}/admin-revert-settlement` | JWT + `@Roles('admin')` | Force-clear a settlement |
| GET | `/api/v1/admin/bookings/{id}/settlement-audits` | JWT + `@Roles('admin')` | Full audit trail for a booking |

⚠ **`markPaid` and `unmarkPaid` are implemented in `SettlementService` but have no controller
route.** A repository-wide grep finds no caller (`settlement.controller.ts` exposes only
`adminRevert` and `getAuditTrail`). Either they were removed from the booking controller or the
route was never added; a rebuild must decide whether to expose them. Their semantics are
documented below because `bookings.settledAt` is still read by the chat/call gating in doc 03.

**Request contracts:**

`AdminRevertDto`: `reason?: string` `@IsString()` `@MaxLength(500)` — defaults to
`'No reason provided'` when omitted.

**Responses:** `adminRevert` returns the updated `bookings` row; `getAuditTrail` returns
`SettlementAuditEntity[]` ordered `createdAt ASC` with the `actor` relation eager-loaded.

**Money math:** none — no ledger row is ever written by this feature. Settlement is a *flag*, not
a payment.

**Business rules & validation:**

*`markPaid(bookingId, actorId)` (unrouted)*
1. `404 Booking not found`.
2. `403 { code: NOT_TRIP_DRIVER }` unless `booking.trip.driverId === actorId`.
3. `409 { code: BOOKING_NOT_CONFIRMED }` unless `booking.status === CONFIRMED`.
4. `409 { code: ALREADY_SETTLED }` when `booking.settledAt !== null`.
5. Sets `settledAt = now`, `settlementGraceUntil = now + 5 min`
   (`GRACE_PERIOD_MS = 5 * 60 * 1000`), writes a `mark_paid` audit row, and sends the passenger a
   `settlement_marked_paid` notification (*"تم تأكيد الدفع"*), failures logged only.

*`unmarkPaid(bookingId, actorId)` (unrouted)*
6. `403 NOT_TRIP_DRIVER` unless the caller is the trip's driver.
7. `409 { code: GRACE_EXPIRED }` when `settlementGraceUntil` is null or already passed.
8. `409 { code: CONTACT_ALREADY_USED }` when **any** `call_sessions` row exists for the booking,
   or when the trip/passenger chat room has `≥ 1` message. The reversal window closes the moment
   the unlocked contact is actually used.
9. Clears `settledAt` and `settlementGraceUntil`, writes an `unmark_paid` audit row.

*`adminRevert(bookingId, actorId, reason)`*
10. `404 Booking not found` is the **only** check. No grace window, no contact-used check, no
    status check, no verification that the booking was ever settled — an admin can "revert" an
    unsettled booking and it will simply write an audit row.
11. Clears both timestamps and writes an `admin_revert` audit row carrying the reason.

**Data model:** `bookings.settledAt`, `bookings.settlementGraceUntil`, `settlement_audits`
(insert). Reads `call_sessions`, `chat_rooms`, `messages` for rule 8.

**State machine (per booking):**
```
   unsettled ──markPaid──► settled (grace 5 min)
       ▲                        │
       ├──unmarkPaid (only within grace AND no contact used)──┘
       └──adminRevert (unconditional)────────────────────────┘
```

**Transactions & locking:** **none.** `markPaid` reads, mutates and saves without a lock, so two
concurrent calls can both pass the `settledAt === null` check; the audit table would then show two
`mark_paid` rows. Add `SELECT … FOR UPDATE` on the booking, or a partial unique constraint.

**External services:** push notification via `NotificationsService` (best-effort).

**Errors:** `404`; `403 NOT_TRIP_DRIVER`; `409 BOOKING_NOT_CONFIRMED` / `ALREADY_SETTLED` /
`GRACE_EXPIRED` / `CONTACT_ALREADY_USED`. Remember (§0.5) that the `code` strings do not survive
the exception filter.

**Notes for reimplementation:** decide the fate of `markPaid`/`unmarkPaid`. If cash confirmation
is a product requirement, route them and lock the booking row; if not, delete them and the
`settlementGraceUntil` column.

---

## F-15: Platform pricing configuration

**What it does:** Admin-editable, per-country fee configuration. One row of
`communication_fees` drives the entire live fee calculation.

**Actors:** admin (read/write); any authenticated user (read, indirectly, via the fee quote).

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/api/v1/admin/pricing-settings?countryCode=JO` | JWT + admin | Read (auto-creates a default row) |
| PATCH | `/api/v1/admin/pricing-settings?countryCode=JO` | JWT + admin | Partial update |

**Request contract** — `AdminPatchPricingSettingsDto` (all optional; `forbidNonWhitelisted`):

| Field | Type | Validators | Meaning |
|---|---|---|---|
| `feeAmount` | number | `@IsNumber()`, `@Min(0)` | legacy flat fee (used only when `driverUnlockPercent = 0`) |
| `currency` | string | `@IsString()`, `@MaxLength(5)` | the fee's currency |
| `isActive` | boolean | `@IsBoolean()` | setting `false` makes `getActiveFeeRow` return `null` ⇒ **fee becomes 0** |
| `passengerPlatformPercent` | number | `@Min(0)`, `@Max(100)` | **ignored by all live code** |
| `driverUnlockPercent` | number | `@Min(0)`, `@Max(100)` | **the live percentage** |
| `lifetimeFreeTripEnabled` | boolean | `@IsBoolean()` | **ignored by all live code** |

**Response:** the whole `communication_fees` row.

**Money math:** consumed by F-07/F-08 as documented; see §2.

**Business rules & validation:**
1. `getPlatformPricingSettings(countryCode)` **creates** the row if missing, with
   `feeAmount: 0, currency: 'JOD', isActive: true, passengerPlatformPercent: 0,
   driverUnlockPercent: 0, lifetimeFreeTripEnabled: true`. Note this row is created **without**
   filtering on `isActive`, while `getActiveFeeRow` **does** filter — so a deactivated row is
   editable but invisible to the fee path.
2. `countryCode` defaults to `'JO'` on both endpoints.
3. The patch is a straight field-by-field assignment with no cross-field validation: setting both
   `driverUnlockPercent = 0` and `feeAmount = 0` silently makes the platform free.
4. **Changing the percentage takes effect immediately for every trip not yet charged**, including
   trips already published and already balance-guarded. The basis snapshot in the audit-row
   metadata only protects trips already charged. This is the main operational hazard of the whole
   domain.
5. There is no audit trail of pricing changes.

**Data model:** `communication_fees` (upsert-ish: find-or-create then save).

**Errors:** `400` validation; `401`; `403`.

**Notes for reimplementation:** version the pricing row and stamp the version onto the trip at
publish time, so a mid-flight change cannot alter what an already-published trip will be billed.
Add an audit log for pricing edits.

---

## F-16: Passenger wallet payment for a seat — **dead path**

**What it does:** *Would* debit a passenger's rider wallet for the platform's share of a seat and
create an `approved` `payments` row. It is fully implemented, wired into the booking flow, and
**never executes**, because `passengerSeatPricing().requiresOnlinePayment` is hard-coded `false`.

**Actors:** passenger (via booking creation), or anyone via the raw wallet endpoint.

**API Endpoints:**

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/wallet/rider/pay-trip` | JWT (**no role guard, no DTO ⇒ no validation**) | Raw rider-wallet trip debit |

Body (inline type, unvalidated): `{ tripId: string, amount: number, idempotencyKey?: string }`.

**Money math (if it ran):**
```
pricing = passengerSeatPricing(trip.price, trip.currency, feeRow)
        = { platformAmount: 0, driverAmount: round2(trip.price), requiresOnlinePayment: false }
```
so `platformAmount` would always be `0` even if the branch were reachable. The
`passengerPlatformPercent × seatPrice / 100` formula the column name implies exists **only** in
the DTO documentation, not in code.

**Business rules & validation (of the reachable raw endpoint):**
1. `payTripFromRiderWallet(riderId, tripId, amount, idempotencyKey?)`: if `idempotencyKey` is
   supplied and a matching `wallet_transactions` row exists, that row is returned unchanged.
2. Locks the rider's `JOD` `rider` account `FOR UPDATE`; `400 "Insufficient rider wallet balance"`
   when `balance < amount`; otherwise `balance := (balance − amount).toFixed(2)` and a
   `trip_payment` / `debit` / `posted` row is written with
   `referenceType: 'trip'`, `referenceId: tripId`.
3. ⚠ It does **not** call `syncUserLegacyWalletMirror`.
4. ⚠ `getOrCreateAccount(riderId, RIDER)` is called with the default `'JOD'` currency, so this
   path always targets the JOD row regardless of the trip's currency.
5. ⚠ **Any authenticated user can debit their own rider wallet by an arbitrary amount against an
   arbitrary `tripId`, with no validation whatsoever.** The `amount` is caller-supplied and never
   checked against the trip's price. It cannot create money (the balance check holds), but it
   destroys it silently.
6. `resolvePassengerWalletPaymentForBooking` (the booking-flow wrapper) additionally validates:
   `404 Trip not found`; `400 "Cannot book your own trip"`; `400 "Seat is not available"`;
   `400 "Online payment is not required for this trip"` — and the last one **always** fires,
   which is why the path is dead. On success it would write a `payments` row with
   `method: 'wallet'`, `status: 'approved'`, `paymentType: 'trip_platform'`,
   `direction: 'debit'`, `paymentGatewayRef: <walletTx.id>`.

**Notes for reimplementation:** delete `POST /wallet/rider/pay-trip` or lock it down hard. If
passenger-side platform fees are ever reinstated, the amount must be derived server-side from the
trip, never accepted from the client.

---

## F-17: Currency resolution

**What it does:** Derives a trip's currency from the country of its departure point so fares
display in the local currency.

**Actors:** system (called during trip creation, `TripsService.resolveTripCurrency`).

**API Endpoints:** none.

**Mapping** (`common/currency/country-currency.ts`), ISO-3166 alpha-2 → ISO-4217:

| Region | Mapping |
|---|---|
| Levant | `JO→JOD`, `SY→SYP`, `LB→LBP`, `PS→ILS`, `IQ→IQD` |
| Gulf | `SA→SAR`, `AE→AED`, `QA→QAR`, `KW→KWD`, `BH→BHD`, `OM→OMR`, `YE→YER` |
| North Africa | `EG→EGP`, `LY→LYD`, `SD→SDG`, `DZ→DZD`, `MA→MAD`, `TN→TND`, `MR→MRU` |
| Other | `US→USD`, `GB→GBP`, `TR→TRY` |

`currencyForCountry(code)`: trims and upper-cases; `null` / `''` / unknown ⇒
`DEFAULT_CURRENCY = 'JOD'`.

**Business rules:**
1. Pure function, no I/O, case-insensitive, whitespace-tolerant.
2. **No FX conversion exists anywhere in the platform.** A trip in `SAR` is charged a fee whose
   currency comes from the `JO` `communication_fees` row (`JOD`), against a wallet row that may be
   in a third currency, with no conversion and no validation. Multi-currency is nominal only.

**Notes for reimplementation:** either commit to single-currency, or introduce a real FX layer
plus a currency check on every debit.

---

## F-18: Legacy / dead endpoints and code

Everything below is reachable over HTTP but does nothing useful. Listed so a rebuild does not
faithfully reproduce it.

| Method | Path | Behaviour | File |
|---|---|---|---|
| POST | `/api/v1/payments` | throws `400 "Payment creation not yet migrated to Postgres. Use wallet or manual flows."` | `payments.service.ts:73-80` |
| POST | `/api/v1/payments/communication-fee` | throws `400 "Communication fee not yet migrated to Postgres."` | `:82-89` |
| POST | `/api/v1/payments/cliq/initiate` | throws `400 "CliQ not yet migrated to Postgres."` | `:91-98` |
| GET | `/api/v1/payments/my` | always `{ data: [], meta: { page:1, limit:20, total:0, totalPages:0 } }` | `:238-243` |
| GET | `/api/v1/payments/{id}` | always throws `404 "Payment not found"` — **so a user can never read their own payment row** (only `/cliq-status` returns one) | `:245-251` |
| GET | `/api/v1/payments/wallet/transactions` | always an empty page | `:367-372` |

Other dead code in the domain:

- `PaymentsService.findAll`, `hasUserPaidCommunicationFee` (returns `false` unconditionally) —
  no live callers of consequence.
- `WalletService.getActiveHolds` — no route, no caller.
- `payments/schemas/payment.schema.ts`, `payments/schemas/communication-fee.schema.ts`,
  `payments/seeds/communication-fee.seed.ts` — **Mongoose** artefacts from the pre-Postgres era.
  They are the only place the `wallet_trip_charge` payment type and the
  `enum: ['pending','approved','rejected','refunded']` constraint are declared; the Postgres
  columns are plain `VARCHAR` with no CHECK.
- `wallet_holds` + `wallet_accounts.reservedBalance` + `trips.presenceSettledAt` /
  `billableSeatCount` / `driverFeeHoldId` — generation-2 remains.
- `pending_charges.correlationId`, `settlement_audits.correlationId` — added by migration
  `1745913000000` for `X-Request-ID` tracing; **no code ever sets them**.
- **Explicitly deleted, do not resurrect:** `PaymentsService.chargeDriverWalletForTrip()`. Its
  tombstone comment (`payments.service.ts:339-346`) records why: it was a *second*, complete
  driver-fee implementation that computed the fee from `driverUnlockPricing`, consumed
  `hasUsedLifetimeFreeTrip`, debited `users.walletBalance` **directly, bypassing the wallet
  ledger**, and stamped `driverWalletChargeApplied` / `communicationFeeStatus` /
  `hasDriverPaidToContact` — all **without** writing the `trip-fee:<tripId>` audit row that
  `DriverTripFeeService.chargeAtTripStart` uses for idempotency, so it could silently defeat it.
  Nothing called it. **`DriverTripFeeService` is the only path that charges a driver for a trip.**
- `payments-cliq-topup.service.spec.ts` is stale and cannot compile against the current service
  (see F-03 note).

---

## Appendix A — Idempotency & concurrency summary

| Operation | Guard | Strength |
|---|---|---|
| CliQ / manual top-up credit | `wallet_transactions.idempotencyKey` = `cliq-topup:<id>` / `payment-topup:<id>` + unique index | **Strong** (pre-check is racy, index is authoritative) |
| Driver trip fee debit | `trips.driverWalletChargeApplied` → `trip-fee:<tripId>` audit read → unique-index convergence | **Strong** (three layers, race-tested) |
| Driver fee shortfall | partial unique `uq_pending_charges_trip_driver_fee (tripId, kind)` | **Strong** |
| Pending-charge collection | `status !== PENDING` transition, written **after** the ledger commit; no idempotency key | ⚠ **Weak — double-debit race** |
| Admin wallet adjustment | none | ⚠ **None** |
| Payment approval | `status === 'pending'` guard + credit idempotency key | Strong for the credit, weak for the row |
| `markPaid` | `settledAt === null` check without a lock | ⚠ **Weak** |
| Payout request | balance check without a lock or reservation | ⚠ **Weak — over-request possible** |
| Wallet balance mutation | `SELECT … FOR UPDATE` on `wallet_accounts`, `ORDER BY id ASC` where multiple | Strong |

## Appendix B — Endpoint index (money domain)

| Method | Path | Roles |
|---|---|---|
| GET | `/api/v1/wallet/me` | any |
| GET | `/api/v1/wallet/transactions` | any |
| POST | `/api/v1/wallet/topup` | admin |
| POST | `/api/v1/wallet/rider/pay-trip` | any ⚠ |
| POST | `/api/v1/wallet/driver/payout-requests` | any ⚠ |
| POST | `/api/v1/payments` | any (throws) |
| POST | `/api/v1/payments/communication-fee` | driver (throws) |
| POST | `/api/v1/payments/cliq/initiate` | driver (throws) |
| POST | `/api/v1/payments/wallet/topup` | driver, passenger |
| GET | `/api/v1/payments/my` | any (empty) |
| GET | `/api/v1/payments/wallet/me` | driver |
| GET | `/api/v1/payments/wallet/transactions` | driver (empty) |
| GET | `/api/v1/payments/{id}` | any (throws 404) |
| GET | `/api/v1/payments/{id}/cliq-status` | driver, passenger, admin |
| PATCH | `/api/v1/payments/{id}/approve` | admin |
| PATCH | `/api/v1/payments/{id}/reject` | admin |
| GET | `/api/v1/me/pending-charges` | passenger, driver |
| POST | `/api/v1/me/pending-charges/collect` | passenger, driver |
| POST | `/api/v1/admin/pending-charges/{id}/waive` | admin |
| GET | `/api/v1/admin/fines` | admin |
| POST | `/api/v1/admin/fines` | admin |
| PATCH | `/api/v1/admin/fines/{id}/waive` | admin |
| POST | `/api/v1/refund-requests` | any |
| GET | `/api/v1/admin/refund-requests` | admin |
| PATCH | `/api/v1/admin/refund-requests/{id}` | admin |
| POST | `/api/v1/admin/bookings/{id}/admin-revert-settlement` | admin |
| GET | `/api/v1/admin/bookings/{id}/settlement-audits` | admin |
| GET | `/api/v1/admin/wallets` | admin |
| GET | `/api/v1/admin/wallets/{id}` | admin |
| PATCH | `/api/v1/admin/wallets/{id}/adjust` | admin |
| GET | `/api/v1/admin/wallets/{id}/transactions` | admin |
| GET | `/api/v1/admin/payments` | admin |
| GET | `/api/v1/admin/pricing-settings` | admin |
| PATCH | `/api/v1/admin/pricing-settings` | admin |
| GET | `/api/v1/trips/fee-quote` | any |
| GET | `/api/v1/trips/{id}/pricing-preview` | any |

## Appendix C — Scheduled work

| Job | Schedule | Batch / window | Knobs |
|---|---|---|---|
| `DriverTripFeeReconciliationJob.reconcileUnchargedTrips` | `@Cron('*/30 * * * *')` | ≤100 trips, departure in `[now−72 h, now−60 min)` | `DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES`, `_LOOKBACK_HOURS`, `_BATCH` |
| `CliqPollProcessor` (`cliq-poll` / `poll-cliq-payment`) | self-rescheduling BullMQ job | first run +60 s, then 144 × 600 s = 24 h | hard-coded in `payments.service.ts:481-495` |
