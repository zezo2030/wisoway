# Implementation Plan — Passenger Presence Confirmation in Vehicle

**Status:** Draft — awaiting approval
**Date:** 2026-07-25
**Branch:** `009-platform-refinements` (new work → `012-passenger-presence-confirmation`)
**Scope:** Scheduled carpool trips only (bookings + booking_seats). Instant rides are out of scope.
**Visual reference (passenger side):** `references/passenger-presence-reference.png`

---

## 1. Outcome

Two linked screens plus a presence-based billing engine:

1. **Passenger screen** — "تأكيد التواجد في السيارة": the passenger declares whether they are in the
   vehicle (matches the supplied reference).
2. **Driver screen** — "من الموجود في السيارة؟": a roster of every booked seat where the driver marks
   present / absent, with a live fee preview.
3. **Billing** — the platform fee stops being a flat upfront charge on all vehicle seats and becomes
   *capture-on-settlement* against **confirmed-present seats only**, backed by a wallet hold.

The driver is the authority on presence; the passenger's self-declaration is corroborating evidence
that constrains what the driver can claim.

---

## 2. Current state (verified in code)

| Area | Reality today |
|---|---|
| `booking_seats.presenceConfirmedAt` / `markedAbsentAt` | Columns exist (migration `1745932000000`), written by `TripTimeService.driverConfirm` |
| `POST /bookings/:id/driver-confirm` | Exists (`trip-time.controller.ts:37`), **no mobile UI calls it** |
| `POST /bookings/:id/passenger-confirm` | Exists, semantics are "is the *driver* present?", **no mobile UI calls it** |
| `ApiEndpoints.passengerConfirm` / `driverConfirm` | Declared in `api_endpoints.dart:54-57`, **dead code** — never referenced |
| Driver fee | `wallet.service.ts:308` — `round2(trip.price × trip.totalSeats × 0.1)`, debited **upfront** at contact-unlock, hardcoded 10% |
| `wallet_holds` table | Exists since the initial migration, indexed — **completely unused** |
| `WalletTransactionType.HOLD` / `RELEASE_HOLD` | Enum values exist — **never emitted** |
| `wallet_accounts` | Has `balance`, no reserved/available split |
| Trip completion | `POST /trips/:id/arrived` → `TripTimeService.completeTrip`, accepts `noShowSeats[]`; the driver app never sends them |
| Fallback completion | `TripAutoCompleteProcessor` force-completes at departure + 24h, bypassing `completeTrip` entirely |
| No-show detector | `NoShowDetectorProcessor` marks **every seat** of a booking absent 30 min after start if the *passenger* never self-confirmed |

### 2.1 Defects this feature must fix

- **D1 — Auto-absence would zero the fee.** `NoShowDetectorProcessor` writes `markedAbsentAt` on seats
  whose passenger merely never opened the app. If billing keys off `markedAbsentAt`, a driver earns a
  free trip whenever passengers ignore a notification. The auto-detector must not write the billing
  field.
- **D2 — Auto-completion bypasses settlement.** `TripAutoCompleteProcessor` never calls `completeTrip`,
  so any settlement placed only in `completeTrip` leaks holds forever on abandoned trips.
- **D3 — Two competing fee formulas.** `wallet.service.ts` hardcodes `0.1`; `PlatformPricingService.driverUnlockPricing`
  reads `communication_fees.driverUnlockPercent` with a legacy flat fallback. They can disagree.
- **D4 — Fee charged on unsold seats.** The current basis is `totalSeats` (vehicle capacity), so a driver
  with 4 seats and 1 booking pays for 4.
- **D5 — `driverConfirm` has no time window** while `passengerConfirm` has one; a driver can confirm
  presence months later.
- **D6 — `driverConfirm` sets `booking.driverConfirmedPassengerAt` on the *booking*** even when only one
  of several seats is confirmed, making the booking-level flag meaningless for multi-seat bookings.

---

## 3. Design decisions

| # | Decision | Rationale |
|---|---|---|
| DD-1 | Build **both** screens; the driver's answer is authoritative | Passenger evidence blocks driver abuse; driver evidence blocks passenger abuse |
| DD-2 | **Hold at unlock, capture at settlement** | Driver can never overdraw; never pays for no-shows |
| DD-3 | Hold basis = `price × totalSeats × pct` (worst case) | Identical to today's charge, so unlock UX is unchanged; capture is always ≤ hold |
| DD-4 | Capture basis = `price × billableSeats × pct` | Fixes D4 — only seats that were booked *and* present are billable |
| DD-5 | **Default is billable.** A seat is non-billable only when explicitly marked absent by the driver and not contradicted by the passenger | Driver skipping the screen must not mean a free trip |
| DD-6 | Passenger self-confirmation **locks** the seat as billable | A driver cannot erase a passenger who declared themselves in the car; conflicts go to admin |
| DD-7 | Fee percentage read from `communication_fees.driverUnlockPercent` via `PlatformPricingService` | Fixes D3 — one source of truth |
| DD-8 | Settlement is idempotent and callable from both `completeTrip` and the auto-complete processor | Fixes D2 |
| DD-9 | Auto no-show detection writes a **separate soft field**, never the billing field | Fixes D1 |
| DD-10 | Lifetime-free-trip keeps working: hold placed, capture = 0, full release | Preserves existing acquisition perk |

---

## 4. Billing state machine

```
  UNLOCK (POST /wallet/driver/trip-charge)
    maxFee = round2(trip.price × trip.totalSeats × pct)
    require available = balance − reservedBalance ≥ maxFee
    ├─ wallet_holds  += { amount: maxFee, status: 'active', referenceType:'trip', referenceId: tripId }
    ├─ wallet_accounts.reservedBalance += maxFee      (balance UNCHANGED)
    └─ wallet_transactions += { type: HOLD, direction: DEBIT, status: PENDING, amount: maxFee }

  TRIP RUNS — driver + passengers mark presence (no money moves)

  SETTLEMENT (completeTrip | auto-complete | trip cancellation)
    billableSeats = seats of CONFIRMED/IN_PROGRESS/COMPLETED bookings
                    MINUS seats with billableOverride = false
    capture = min( round2(trip.price × billableSeats × pct), hold.amount )
    release = hold.amount − capture
    ├─ wallet_accounts.reservedBalance −= hold.amount
    ├─ wallet_accounts.balance         −= capture
    ├─ hold.status = 'captured' | 'released'
    ├─ wallet_transactions: HOLD tx → status POSTED, amount = capture
    ├─ wallet_transactions += { type: RELEASE_HOLD, direction: CREDIT, amount: release }  (if > 0)
    └─ trips: presenceSettledAt, billableSeatCount, capturedFeeAmount
```

**Cancellation before departure:** full release, `capture = 0`.
**Free lifetime trip:** `capture = 0`, full release, `hasUsedLifetimeFreeTrip` consumed at unlock as today.
**Clamp rationale:** if a trip's `totalSeats` is edited downward after unlock, `capture` could exceed the
hold; `min()` guarantees we never take more than was reserved.

### 4.1 Billable resolution per seat

| Passenger declared | Driver marked | Result | Notes |
|---|---|---|---|
| in vehicle | present | **billable** | agreement |
| in vehicle | absent | **billable + `presenceDisputedAt`** | conflict → admin review, driver still pays |
| in vehicle | *(no action)* | **billable** | DD-5 |
| on my way / nothing | present | **billable** | driver vouches |
| on my way / nothing | absent | **not billable**, booking → `no_show` | accepted no-show |
| not riding | absent | **not billable**, booking → `no_show` | agreement |
| not riding | present | **billable** | passenger boarded after all |
| not riding | *(no action)* | **not billable** | passenger opted out in advance |

Auto-detected absence (`autoFlaggedAbsentAt`) never appears in this table — it is display/analytics only.

### 4.2 Abuse controls

- Conflicts (row 2) increment a counter; ≥3 conflicts in 30 days raises an `AccountFlagEntity` on the
  driver and notifies admins.
- If a driver marks **100% of seats absent** on a trip, settlement still runs but the trip is flagged
  for admin review before the release is finalised — the release posts, the flag is informational.
- Passengers marked absent get a push notification with a 24 h dispute link into the existing
  complaints module.

---

## 5. Data model

### 5.1 Migration `1746600000000-add-presence-confirmation.ts`

**`booking_seats`**

| Column | Type | Purpose |
|---|---|---|
| `passengerSelfConfirmedAt` | `timestamptz null` | Passenger declared themselves in the vehicle |
| `passengerDeclaredStatus` | `varchar(20) null` | `in_vehicle` / `on_my_way` / `not_riding` |
| `autoFlaggedAbsentAt` | `timestamptz null` | Written by `NoShowDetectorProcessor` (D1) — non-billing |
| `absenceReason` | `varchar(30) null` | `no_show` / `cancelled_on_site` / `wrong_pickup` / `other` |
| `billableOverride` | `boolean null` | `false` = driver-declared absent and uncontested; `null` = default billable |
| `presenceDisputedAt` | `timestamptz null` | Driver/passenger conflict |
| `presenceResolvedBy` | `uuid null` | Admin who resolved |
| `presenceResolutionNote` | `text null` | |
| `presenceUpdatedAt` | `timestamptz null` | Last write by anyone |

Index: `idx_booking_seats_presence (bookingId, billableOverride)`.
`presenceConfirmedAt` / `markedAbsentAt` are **kept** and keep their meaning (driver's explicit action).

**`trips`**

| Column | Type | Purpose |
|---|---|---|
| `presenceSettledAt` | `timestamptz null` | Idempotency guard for settlement |
| `billableSeatCount` | `int null` | Frozen at settlement |
| `capturedFeeAmount` | `numeric(10,2) null` | Frozen at settlement |
| `driverFeeHoldId` | `uuid null` | FK → `wallet_holds.id` |
| `presenceReviewFlagged` | `boolean default false` | 100%-absent or conflict present |

**`wallet_accounts`**

| Column | Type | Purpose |
|---|---|---|
| `reservedBalance` | `numeric(14,2) default '0'` | Sum of active holds; available = `balance − reservedBalance` |

Backfill: `reservedBalance = 0` for all rows (no holds exist today). No data migration needed for the
`booking_seats` additions — all nullable.

### 5.2 Down migration
Drops every added column and the index; `wallet_holds` rows created by this feature are left intact
(they are historical ledger records) but `reservedBalance` disappears, so the down path must first
settle or release active holds. Documented in the migration header.

---

## 6. API contract

### 6.1 Driver — roster

`GET /trips/:id/presence-roster` · `@Roles('driver')`

```jsonc
{
  "tripId": "…",
  "status": "in_progress",
  "window": { "opensAt": "…", "closesAt": null, "isOpen": true },
  "currency": "JOD",
  "seatPrice": "2.00",
  "feePercent": 10,
  "hold": { "amount": "0.80", "status": "active" },
  "seats": [
    {
      "bookingId": "…", "seatId": "…", "seatNumber": "1A",
      "displayName": "أحمد محمود", "gender": "male",
      "isMainBooker": true,
      "passengerDeclaredStatus": "in_vehicle",
      "passengerSelfConfirmedAt": "…",
      "driverState": "unset",            // unset | present | absent
      "locked": true,                    // passenger self-confirmed → cannot be zeroed silently
      "billable": true
    }
  ],
  "summary": {
    "totalSeats": 4, "bookedSeats": 3,
    "billableSeats": 3,
    "estimatedFee": "0.60",
    "maxFee": "0.80",
    "estimatedRelease": "0.20"
  }
}
```

`GET /trips/:id/presence-roster` is safe to poll; it is also pushed over the existing tracking socket
when a passenger self-confirms.

### 6.2 Driver — bulk confirm

`POST /trips/:id/presence-confirm` · `@Roles('driver')`

```jsonc
{
  "entries": [
    { "bookingId": "…", "seatNumber": "1A", "present": true },
    { "bookingId": "…", "seatNumber": "1B", "present": false, "reason": "no_show" }
  ],
  "idempotencyKey": "…"
}
```

Returns the same shape as the roster. Rules:
- Window: `departureTime − 30 min` → trip settlement. Outside → `409 PRESENCE_WINDOW_CLOSED`.
- After `presenceSettledAt` → `409 PRESENCE_ALREADY_SETTLED`.
- `present: false` on a seat with `passengerSelfConfirmedAt` → accepted but sets `presenceDisputedAt`
  and leaves `billableOverride` null (still billable).
- Partial submits allowed; the screen can save each toggle immediately.

`POST /bookings/:id/driver-confirm` is retained as a thin single-seat alias delegating to the same
service method (backwards compatibility), with D5/D6 fixed.

### 6.3 Passenger — prompt + declaration

`GET /bookings/:id/presence-prompt` · owner only — everything the reference screen renders:
driver name/rating/photo, vehicle make/model/colour/plate, `carImageUrl`, pickup point label, distance
and ETA from `driver_locations`, countdown to auto-cancel, seats belonging to this booking.

`POST /bookings/:id/presence-declare` · owner only

```jsonc
{ "status": "in_vehicle", "seatNumbers": ["1A", "1B"] }   // in_vehicle | on_my_way | not_riding
```

- `seatNumbers` omitted → applies to all seats in the booking (the main booker answers for companions).
- Window: `departureTime − 60 min` → `departureTime + 30 min` (matches the existing passenger window).
- `not_riding` also sets `booking.status = cancelled` when submitted **before** departure, reusing the
  existing cancellation-policy helper.

`POST /bookings/:id/passenger-confirm` keeps its current "is the driver present?" meaning and is **not**
merged into this endpoint — they answer different questions.

### 6.4 Completion

`POST /trips/:id/arrived` — unchanged signature. `noShowSeats[]` continues to work and is folded into
the same resolution table before settlement runs. Response gains a `settlement` block:

```jsonc
{ "settlement": { "billableSeats": 2, "captured": "0.40", "released": "0.40", "currency": "JOD" } }
```

### 6.5 Error codes (added to `common/errors/error-codes.ts`)

`PRESENCE_WINDOW_CLOSED`, `PRESENCE_ALREADY_SETTLED`, `PRESENCE_SEAT_NOT_FOUND`,
`INSUFFICIENT_AVAILABLE_BALANCE`, `HOLD_NOT_FOUND`.

---

## 7. Backend work

| # | File | Change |
|---|---|---|
| B1 | `database/migrations/1746600000000-add-presence-confirmation.ts` | New (§5.1) |
| B2 | `database/entities/booking-seat.entity.ts` | Add the 9 new columns |
| B3 | `database/entities/trip.entity.ts` | Add the 5 new columns |
| B4 | `database/entities/wallet-account.entity.ts` | Add `reservedBalance` |
| B5 | `modules/wallet/wallet-hold.service.ts` | **New.** `placeHold`, `captureHold`, `releaseHold`, `getActiveHold` — all inside `dataSource.transaction` with `pessimistic_write` on the account, idempotent by `(referenceType, referenceId)` |
| B6 | `modules/wallet/wallet.service.ts` | `chargeDriverForTrip` → place a hold instead of debiting; percentage from `PlatformPricingService` (D3); `getWalletSummary` returns `availableBalance` |
| B7 | `modules/trip-time/presence.service.ts` | **New.** `getRoster`, `driverConfirm` (bulk), `passengerDeclare`, `resolveBillableSeats`, `settleTripPresence` |
| B8 | `modules/trip-time/trip-time.service.ts` | `completeTrip` calls `settleTripPresence` before notifications; `driverConfirm` delegates to B7 |
| B9 | `modules/trip-time/trip-time.controller.ts` | New routes (§6.1–6.3) |
| B10 | `modules/bookings/processors/trip-auto-complete.processor.ts` | Call `settleTripPresence` (D2) |
| B11 | `modules/bookings/processors/no-show-detector.processor.ts` | Write `autoFlaggedAbsentAt`, stop writing `markedAbsentAt` (D1) |
| B12 | `modules/trips/trips.service.ts` | Trip cancellation → `releaseHold` |
| B13 | `modules/notifications/…` | 4 new types: `presence_prompt`, `presence_driver_prompt`, `presence_marked_absent`, `presence_conflict_admin` |
| B14 | `modules/admin/admin-dashboard.service.ts` | Presence-dispute queue + resolve endpoint; settlement figures on the trip detail view |
| B15 | `modules/trip-time/trip-time.module.ts` | Wire `PresenceService`, `WalletHoldService`, `PlatformPricingService` |

### 7.1 Scheduling
Two new BullMQ jobs on the existing queues:
- `presence-prompt` at `departureTime − 10 min` → push to every confirmed passenger (opens the passenger
  screen via `notification_navigation_service`).
- `presence-driver-prompt` at `departureTime + 2 min` → push to the driver if the roster is untouched.

---

## 8. Mobile (Flutter)

### 8.1 Passenger — `lib/screens/passenger/presence_confirmation_screen.dart`

Rebuilds the reference exactly, in the app's own design tokens (`AppColors`, `T.*`, `AppTextStyles`,
`SectionCard`), RTL-first, dark-mode aware.

| Region | Content |
|---|---|
| App bar | Collapse chevron · title `تأكيد التواجد في السيارة` · subtitle · "مساعدة" pill → support |
| Driver card | Avatar, name, rating + count, colour · make · model, plate (`PhoneText`-style LTR digits), car image (`carImageUrl` — already on `vehicles`), countdown "سيبدأ السائق الرحلة بعد mm:ss" |
| Map card | Static pickup map + pickup label + landmark (`trip_route_map_screen` widgets reused) |
| Question block | Bell icon, `هل أنت داخل السيارة؟`, subtitle, info card |
| Info card | **Reworded** — see §8.3 |
| Actions | 3 cards: `نعم، أنا داخل السيارة` (primary, filled) · `أنا في طريقي لمقابلة السائق` · `لست داخل السيارة` |
| Footer | Privacy line + auto-cancel countdown |

States: loading skeleton · loaded · submitting (per-card spinner, others disabled) · submitted
(collapses to a confirmed banner + "تعديل" for 5 min) · window-closed · error/retry · offline (queues
the declaration and retries).

### 8.2 Driver — `lib/screens/driver/presence_roster_screen.dart`

| Region | Content |
|---|---|
| Header | `من الموجود في السيارة؟` + trip route summary |
| Fee banner | Live: `المقاعد المحتسبة: 2 من 3` · `الرسوم المتوقعة 0.40 د.أ` · `سيُعاد 0.40 د.أ` |
| Seat list | One row per seat: avatar, name, seat number, companion badge, passenger-declaration chip (`أكّد تواجده` / `في الطريق` / `لن يركب` / `لم يرد`), and a two-state segmented control `حاضر` / `غائب` |
| Locked rows | Seats with `passengerSelfConfirmedAt` show a lock hint; tapping `غائب` opens a confirm dialog explaining the seat stays billable and goes to review |
| Absence sheet | Reason picker when marking absent |
| Bulk action | `تأكيد الجميع` |
| CTA | `إنهاء الرحلة` → completion summary sheet with final capture/release, then `POST /trips/:id/arrived` |

Entry points: `trip_management_screen.dart` gains a "تأكيد الركاب" card once the trip is `in_progress`;
the `arrived` button routes through the roster instead of completing directly; push notification
`presence_driver_prompt` deep-links here.

### 8.3 Copy corrections to the reference

The reference's info card says *"لن يتم خصم أي رسوم في حال عدم التأكيد"* — under this feature that is
false for the driver and misleading for the passenger. Replacement:

| | Arabic | English |
|---|---|---|
| Info card | `تأكيدك يساعد السائق على بدء الرحلة وتوثيق حضورك. لا تُخصم منك أي رسوم — التطبيق لا يجمع أجرة الرحلة، وتُدفع نقدًا للسائق.` | `Confirming helps the driver start the trip and records your attendance. You are never charged — the app does not collect the fare; you pay the driver in cash.` |
| Conflict dialog (driver) | `هذا الراكب أكّد تواجده داخل السيارة. تعليمه كغائب سيُحتسب ضمن الرسوم وسيُحال إلى المراجعة.` | `This passenger confirmed they are in the vehicle. Marking them absent keeps the seat billable and sends it for review.` |
| Absent notice (passenger) | `أبلغ السائق أنك لم تحضر للرحلة إلى {city}. إن كان ذلك غير صحيح يمكنك الاعتراض خلال 24 ساعة.` | `The driver reported you did not board the trip to {city}. If that's wrong you can dispute within 24 hours.` |

Other refinements over the reference: the three action cards become equal-height and reorder in RTL so
the primary sits at the reading start; the countdown gets `Semantics(liveRegion: true)`; the plate
number is forced LTR inside an RTL layout; tap targets raised to 56 dp.

### 8.4 Supporting Flutter changes

| File | Change |
|---|---|
| `core/api/api_endpoints.dart` | `presenceRoster`, `presenceConfirm`, `presencePrompt`, `presenceDeclare` |
| `core/services/presence_service.dart` | **New** — typed client + offline queue |
| `models/booking_model.dart` | `BookingSeatModel` gains `presenceConfirmedAt`, `passengerSelfConfirmedAt`, `passengerDeclaredStatus`, `billable` (currently only `markedAbsentAt` is parsed) |
| `models/presence_models.dart` | **New** — `PresenceRoster`, `PresenceSeat`, `PresenceSummary` |
| `core/services/notification_navigation_service.dart` | Route the 2 new notification types |
| `screens/driver/trip_management_screen.dart` | Entry card + reroute the arrived button |
| `screens/driver/widgets/passengers_card.dart` | Show presence chips instead of the hardcoded `confirmedLabel` badge |
| `screens/driver/driver_wallet_screen.dart` | Show `availableBalance` vs `balance` and list active holds |
| `l10n/app_ar.arb` / `app_en.arb` | ~42 new keys, then `flutter gen-l10n` |

---

## 9. Admin dashboard

- **Presence disputes** queue: trip, driver, passenger, both declarations, timestamps → resolve as
  *billable* / *not billable* with a note; resolution posts a wallet adjustment via the existing
  `adjustBalanceByAdmin`.
- Trip detail gains: hold amount, captured, released, billable seat count, per-seat presence timeline.
- Driver profile gains an "absence claim rate" stat feeding the DD-2 abuse flag.

---

## 10. Testing

| Level | Coverage |
|---|---|
| Unit — `wallet-hold.service.spec.ts` | place/capture/release, idempotency, insufficient available balance, concurrent capture under lock |
| Unit — `presence.service.spec.ts` | All 8 rows of §4.1, window enforcement, settlement idempotency, clamp when `totalSeats` shrinks, free-trip path |
| Unit — updated `wallet.service.spec.ts` | `chargeDriverForTrip` no longer debits; hold created |
| Unit — updated processor specs | `no-show-detector` writes only `autoFlaggedAbsentAt`; `trip-auto-complete` settles |
| Contract — `test/contract/presence/` | The 4 new endpoints against the documented shapes, plus 401/403/409 paths |
| Integration | Full lifecycle: unlock → hold → 3 bookings → mixed declarations → arrive → assert ledger sums to zero and `balance` moved by exactly `capture` |
| Flutter widget — `test/screens/passenger/presence_confirmation_screen_test.dart` | All 6 states, RTL/LTR, dark mode |
| Flutter widget — `test/screens/driver/presence_roster_screen_test.dart` | Toggles, locked-seat dialog, live fee math, empty roster |

Gates: `npm test` + `npm run lint` (backend), `flutter analyze` + `flutter test` (mobile).

---

## 11. Rollout

1. Migration is additive and safe to deploy ahead of code.
2. Feature flag `PRESENCE_BILLING_ENABLED` (env). Off → `chargeDriverForTrip` keeps the current
   immediate debit; on → hold/capture. Lets us ship the screens before flipping billing.
3. In-flight trips at flip time have no hold — `settleTripPresence` no-ops when `driverFeeHoldId` is
   null and logs, so nothing breaks.
4. Deploy per `project_deployment_process` memory: build image, run migrations from compiled `dist` JS
   on the prod host, then restart.

---

## 12. Task order

```
T01 migration + entities (B1–B4)
T02 WalletHoldService + spec (B5)
T03 wallet.service hold integration + spec update (B6)
T04 PresenceService: roster + resolution table + spec (B7)
T05 PresenceService: settleTripPresence + spec (B7)
T06 controller routes + DTOs + error codes (B9)
T07 processors + trips cancellation (B10, B11, B12)
T08 notifications + scheduled prompts (B13, §7.1)
T09 contract tests
T10 Flutter models + service + endpoints (8.4)
T11 passenger screen + widget tests (8.1)   ← needs mockup M1
T12 driver roster screen + widget tests (8.2) ← needs mockup M2
T13 trip_management + wallet screen wiring
T14 l10n keys + gen-l10n
T15 admin dashboard (B14, §9)
T16 full gate run + integration test
```

T02–T09 are backend-only and independent of the mockups, so implementation starts immediately while
mockups are produced in parallel.

---

## 13. Mockups delegated to ChatGPT/Codex

Only these are outsourced; all architecture, code and integration stay in-house.

**Format decision: SVG only — no PNG, no rasterisation at any step.** The `codex` CLI (v0.144.1,
installed and on PATH) is a coding agent and cannot emit raster artwork, but it produces SVG natively.
SVG is also the better artefact here: reviewable as a plain-text diff, resolution-independent, and
themeable via `currentColor`.

| ID | Deliverable | Path | Spec |
|---|---|---|---|
| M1 | Passenger presence screen mockup | `specs/012-…/references/passenger-presence-mockup.svg` | 390×844 viewBox (logical pts), RTL Arabic, app palette, light + dark variants in one file via `<g id="light">` / `<g id="dark">` |
| M2 | Driver roster screen mockup | `specs/012-…/references/driver-presence-roster-mockup.svg` | Same frame; 3 seat rows covering all three passenger-declaration chips and both toggle states |
| M3 | Presence-confirm illustration | `rideshare/assets/illustrations/presence_confirm.svg` | 640×640 viewBox, no background rect (transparent), stroke/fill only — no embedded rasters, no external fonts |
| M4 | All-confirmed success illustration | `rideshare/assets/illustrations/presence_all_confirmed.svg` | Same spec, success state |

M1/M2 are **reference only** — the shipped screens are hand-written Flutter using the project's
existing design tokens. M3/M4 are **runtime assets**.

### 13.1 Consequence: `flutter_svg` dependency

`rideshare/pubspec.yaml` has no SVG renderer today (the existing `no_driver_found.png` is raster). M3/M4
therefore require:

- `flutter_svg: ^2.0.10` added to `dependencies`
- no `pubspec.yaml` asset-block change — `assets/illustrations/` is already registered as a directory
  (line 90), so `.svg` files there are picked up automatically
- `SvgPicture.asset(...)` instead of `Image.asset(...)`, wrapped in `Semantics` with a localised label

Text inside M3/M4 must be converted to paths or omitted entirely (localised strings are rendered by
Flutter, not baked into the asset) — `flutter_svg` does not resolve arbitrary font families.

---

## 14. Open risks

| Risk | Mitigation |
|---|---|
| Driver marks everyone absent to avoid fees | DD-6 lock + conflict flagging + admin queue + account flag |
| Passenger self-confirms then never boards | Driver marks present=false; conflict goes to admin; passenger's rating/flags record the pattern |
| Push not delivered → nobody confirms | DD-5 default-billable makes silence the safe outcome for the platform |
| Hold leaks on crashed settlement | Nightly reconciliation job: active holds on trips completed > 6 h ago → force settle |
| Percent changed mid-trip | Percent snapshotted into hold `metadata` at unlock and reused at capture |
