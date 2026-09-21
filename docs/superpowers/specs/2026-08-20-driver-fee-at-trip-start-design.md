# Driver Fee at Trip Start + Open Passenger Contact — Design Spec

**Date:** 2026-08-20
**Status:** Approved (2026-08-20)
**Approach:** Single upfront-at-start debit; remove the pay-to-unlock contact gate and the wallet-hold machinery.

## Goal

Two changes to the shared-trip driver economics:

1. **Passenger contact is never locked.** The driver sees each passenger's name, photo and phone number and can call or chat from the moment the booking is confirmed — no payment gate.
2. **The platform fee is debited once, when the trip starts.** Not at publish, not at booking, not at completion. The amount is fixed by the trip's total seat count and never adjusted afterwards.

The problem being solved: drivers currently have money reserved from their wallet *before* the trip runs, in order to unlock passenger contact details. That reservation is the source of ongoing disputes with drivers.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Fee basis | `seatPrice × trip.totalSeats × driverUnlockPercent` — **all seats**, regardless of how many were booked or how many passengers confirmed presence |
| Debit moment | Trip transition to `IN_PROGRESS` (auto-fires at `departureTime`) |
| Wallet holds | Removed entirely — no reservation at any point |
| Refunds / settlement | None. The fee is final once charged |
| Zero-booking trip | No fee charged |
| Balance guard at publish | `balance >= expectedFee`, else publish is blocked |
| Balance shortfall at start | Trip still starts; debit what is available, record the remainder as a `PendingCharge` |
| Lifetime free trip | Unchanged — still consumes `hasUsedLifetimeFreeTrip` and charges nothing |
| Presence confirmation | Kept as an operational no-show record; carries **no** financial effect |
| Contact gate | Removed from calls, chat, and the booking serializer |
| Instant rides | Out of scope — separate fee path, untouched |

### Why trip start, and not publish or first booking

| Scenario | At publish | At first booking | **At trip start** |
|---|---|---|---|
| Nobody books the trip | Driver paid for nothing | No charge | No charge |
| One seat booked, then cancelled | Driver paid | Charged, then needs a refund path | No charge |
| Driver cash-flow burden | Highest | Medium | Lowest |
| Amount stability | Seat count may still change | May still change | Final |
| Implementation surface | Scattered | Scattered | One idempotent hook |

Because contact is no longer gated behind payment, there is no product reason to charge early. Trip start is the last pre-trip moment and the first moment the driver begins collecting fares.

## Current context

- `WalletService.chargeDriverTripFee` (`rideshare-backend/src/modules/wallet/wallet.service.ts`, ~L340–520) is reached via `POST /wallet/driver/trip-charge`. It computes `maxFee = seatPrice × totalSeats × percent` and, under the `PRESENCE_BILLING_ENABLED` flag (default on), calls `WalletHoldService.placeHold` to reserve that amount. It then sets `trip.driverWalletChargeApplied`, `trip.communicationFeeStatus = 'paid'`, and `booking.hasDriverPaidToContact = true` on every pending/confirmed booking.
- The legacy branch of the same method (flag off) performs a straight debit of `maxFee` with an insufficient-balance guard. This is close to the target behaviour, but it fires at the wrong moment.
- `PresenceService.settleTripPresence` (`modules/trip-time/presence.service.ts`, L507+) runs at completion, captures `seatPrice × billableSeats × percent` from the hold and releases the rest. `BookingSeatEntity.isBillable` is `passengerSelfConfirmedAt != null && billableOverride !== false`.
- The contact gate reads `hasDriverPaidToContact` in four places: `modules/calls/calls.service.ts:49`, `modules/chat/chat-postgres.service.ts` (L62, L158, L242, L318), `modules/chat/chat.service.ts:119`, and `modules/bookings/serializers/booking-viewer.serializer.ts` which masks `displayName`, `phone`, `phoneNumber`, `photoUrl` to `***` and forces `chatEnabled`/`callEnabled` to false.
- Trips auto-start at `departureTime` via `TripAutoStartProcessor` (`modules/bookings/processors/trip-auto-start.processor.ts`). There is no manual "Start Trip" button. The processor is already idempotent — it returns early on terminal and already-`IN_PROGRESS` statuses.
- `TripsService.create` (`modules/trips/trips.service.ts`) already blocks publishing when outstanding `PendingCharge` rows exist (L147) and when the driver's balance is negative (L157, `assertNonNegativeDriverBalance`).
- Mobile: `trip_management_screen.dart` renders the fee card and invoice at L1049 (`_buildTripFeePaymentCard`) with `_payTripFee` at L475; `passengers_card.dart` and `trip_management_screen.dart:2177` gate the contact row on `booking.hasDriverPaidToContact`.

## Architecture

```
Trip published
  └─ TripsService.create
       └─ assertDriverCanCoverTripFee(driverId, expectedFee)   [NEW]
            → blocks publish if balance < expectedFee

departureTime reached (BullMQ)
  └─ TripAutoStartProcessor.handle
       ├─ status → IN_PROGRESS  (existing)
       └─ DriverTripFeeService.chargeAtTripStart(trip)          [NEW]
            ├─ skip if trip.driverWalletChargeApplied           (idempotency)
            ├─ skip if zero confirmed bookings
            ├─ lifetime-free-trip path → zero-amount audit row
            ├─ debit min(balance, fee); remainder → PendingCharge
            └─ stamp trip.driverWalletChargeApplied / communicationFeeStatus

Trip completed
  └─ PresenceService.settleTripPresence
       └─ presence bookkeeping only — no money movement
```

The new `DriverTripFeeService` lives in the wallet module and owns fee computation and the single debit. `WalletService.chargeDriverTripFee` and `WalletHoldService` are deleted.

## Backend changes

### B1 — New `DriverTripFeeService`

`rideshare-backend/src/modules/wallet/driver-trip-fee.service.ts`

- `computeExpectedFee({ seatPrice, totalSeats, currency }): { amount, seatPrice, totalSeats, percent, currency }` — takes a plain shape rather than a `TripEntity`, so the publish guard can call it before the trip row exists. Wraps `PlatformPricingService.driverUnlockPricing`, the existing single source of truth for the percentage.
- `assertDriverCanCoverTripFee(driverId, { seatPrice, totalSeats, currency })` — throws `ForbiddenException` with code `INSUFFICIENT_BALANCE_FOR_TRIP_FEE` when the driver's balance is below the expected fee.
- `chargeAtTripStart(trip, manager?)` — idempotent by `trip.driverWalletChargeApplied`; returns `{ charged, pendingRemainder }`.
  - Zero confirmed bookings → write a `0.00` `TRIP_DEBIT` audit row with `{ reason: 'no-bookings' }` and stamp the trip, so it is never revisited.
  - `!driver.hasUsedLifetimeFreeTrip` → consume the free trip, write a `0.00` `TRIP_DEBIT` audit row with `freeTripApplied: true`, stamp the trip.
  - Otherwise debit `min(balance, fee)` under a pessimistic row lock; if `balance < fee`, record the remainder via `PendingChargesService.recordCharge` with a new `PendingChargeKind.DRIVER_TRIP_FEE`.
  - Metadata snapshot on the transaction: `{ seatPrice, totalSeats, percent, formula: 'seatPrice * totalSeats * percent%' }`.
  - "Stamp the trip" in every branch means: `driverWalletChargeApplied = true`, `driverWalletChargeAt = now`, `communicationFeeStatus = 'paid'`, `capturedFeeAmount = <amount actually debited>`, and `hasDriverPaidToContact = true` on the trip's pending/confirmed bookings (audit only — nothing gates on it any more).

**Supporting changes this service needs:**

- `PendingChargeKind.DRIVER_TRIP_FEE` added to `pending-charge.entity.ts`, with a migration extending the Postgres enum.
- `walletAccountTypeForCharge` in `pending-charges.service.ts` currently maps everything but `DRIVER_NO_SHOW` to `WalletAccountType.RIDER`. It must map `DRIVER_TRIP_FEE` to `DRIVER`.
- `INSUFFICIENT_BALANCE_FOR_TRIP_FEE` added to `common/errors/error-codes.ts`.

### B2 — Publish-time balance guard

`modules/trips/trips.service.ts` — after the existing outstanding-charges check, replace the bare `assertNonNegativeDriverBalance(driverId)` call with `assertDriverCanCoverTripFee`, passing the seat price and resolved seat count from the incoming `CreateTripDto` so the guard runs before the trip row is written.

### B3 — Charge on trip start

`modules/bookings/processors/trip-auto-start.processor.ts` — after the status transition and booking updates, call `driverTripFeeService.chargeAtTripStart(trip)`. Failures are logged and do **not** roll back the start: the trip must begin for the passengers regardless. A failed debit leaves `driverWalletChargeApplied` false, so the reconciliation job (B7) picks it up.

Notify the driver of the debit through the existing `NotificationsService` alongside the `trip_started` notification.

### B4 — Remove the contact gate

- `calls.service.ts:49` — delete the `hasDriverPaidToContact` guard.
- `chat-postgres.service.ts` L62, L158, L242, L318 — delete the guards; the room is created and readable as soon as the booking is confirmed.
- `chat.service.ts:119` — same.
- `booking-viewer.serializer.ts` — the masking contract collapses. `serialize` returns the data with `chatEnabled: true, callEnabled: true` for all viewers. Keep the function and its call sites so a future gate has a seam, but delete the mask branch, the `MASK` constant and the `hasDriverPaidToContact` field from `MaskableBookingView`. Update the header docblock.

`booking.hasDriverPaidToContact` and `trip.communicationFeeStatus` stay as columns and stay populated by B1 — they become an audit trail of *when the fee was charged*, read by the admin dashboard only.

### B5 — Delete the hold machinery

- Delete `modules/wallet/wallet-hold.service.ts` and its spec; drop it from `wallet.module.ts` providers/exports.
- Delete `WalletService.chargeDriverTripFee`, the `presenceBillingEnabled()` flag helper, and the `POST /wallet/driver/trip-charge` controller route and DTO.
- `WalletTransactionType.HOLD` and the `wallet_holds` table stay in place for historical rows; nothing writes to them any more.
- `reservedBalance` stays in the wallet summary response and reports `0.00` — the mobile app and dashboard read it, and removing the field would be a breaking API change for no gain.

### B6 — Presence loses its financial role

`modules/trip-time/presence.service.ts`:

- `settleTripPresence` no longer calls `settleHold`. It records `trip.presenceSettledAt`, `trip.billableSeatCount`, and keeps `presenceReviewFlagged` when seats existed but none confirmed. It must **not** touch `capturedFeeAmount` — that field is owned by B1 now.
- `pricingFor` no longer reads the hold metadata snapshot; it reads `PlatformPricingService` directly, or the fee snapshot stored on the trip's charge transaction.
- `buildRoster` keeps `estimatedFee` but it now reports the fixed all-seats fee, and `estimatedRelease` is removed — there is nothing to release.

### B7 — Reconciliation and migration

- **Migration:** release every `wallet_holds` row still in an active state, returning the reserved amount to the driver's available balance, and mark the rows as reversed with a `migration: 'fee-at-trip-start'` metadata note. Trips whose fee was already fully captured under the old model keep their captured amount and are stamped `driverWalletChargeApplied = true` so B3 does not double-charge them.
- **Reconciliation job:** extend the existing trip reconciliation path to charge any `IN_PROGRESS`/`COMPLETED` trip where `driverWalletChargeApplied` is still false — the safety net for a failed debit in B3.

## Mobile changes

### M1 — Remove the pay-to-unlock UI

`rideshare/lib/screens/driver/trip_management_screen.dart`:

- Delete `_buildTripFeePaymentCard` (L1049), `_showTripFeeInvoice` (L391), `_payTripFee` (L475), `_isPayingTripFee`, `_invoiceRow`, `_baseTripFeeAmount` and `_tripFeeAmount`.

`rideshare/lib/screens/driver/my_trips_screen.dart` carries a **second, duplicated copy** of the same invoice/pay flow — `_tripFeeAmount` (L256), `_invoiceRow` (L309), `_payTripFee` (L325) and the dialog around L260–L305. Delete it too; missing this file would leave a live pay-to-unlock path in the app.

Both copies hardcode `'5%'` in the invoice (`trip_management_screen.dart:408`, `my_trips_screen.dart:274`) while the backend charges `driverUnlockPercent`. The fee line added in M2 must read the percentage from the API rather than repeat that bug.
- Delete the `confirmBookingUnlocksDetails` hint (L1158) and the `chatAvailableAfterFee` fallback (L1179).
- The passenger row at L2177 and L2209 shows name, phone, call and chat unconditionally.

The complete set of `hasDriverPaidToContact` conditionals to drop across the app:

| File | Lines |
|---|---|
| `screens/driver/trip_management_screen.dart` | 1174, 2177, 2183, 2209 |
| `screens/driver/widgets/passengers_card.dart` | 72, 78, 98 |
| `screens/driver/passenger_details_screen.dart` | 49 |
| `screens/home/widgets/booking_card.dart` | 251 (keep the `!isPastTrip` half) |

### M2 — Surface the fee before publishing

In the create-trip wizard review step, show a line: *"رسوم الرحلة (10%): X د. — تُخصم من محفظتك عند انطلاق الرحلة"*, computed from seat price × total seats × percent. This is the driver's one chance to see the number before committing, now that the payment step is gone.

Handle the new `INSUFFICIENT_BALANCE_FOR_TRIP_FEE` error from publish with a dialog offering a wallet top-up.

### M3 — Copy

`rideshare/lib/l10n/app_ar.arb` + `app_en.arb`:

- `tripSummaryFeeDeducted` → «تم خصم رسوم الرحلة ({amount}) من محفظتك عند انطلاق الرحلة.»
- The passenger-roster info box changes from «سيتم خصم رسوم الرحلة من محفظتك **عند انتهاء الرحلة**» to «سيتم خصم رسوم الرحلة من محفظتك **عند انطلاق الرحلة**». *(The design mock carries the old wording; it is superseded by this spec.)*
- New: `createTripFeeNotice`, `insufficientBalanceForTripFee`.
- Delete: `chatAvailableAfterFee`, `tripFeeInvoiceTitle`, `tripFeePaidSuccess`, `tripFeeReady`, `tripFeeBreakdown`, `tripFeeBreakdownWithFreeTrip`, `tripFeeFullExplanation`, `confirmBookingUnlocksDetails`, and `payFees` if unused elsewhere.
- Regenerate `lib/l10n/generated/`.

### M4 — Models

`rideshare/lib/models/booking_model.dart` — keep `hasDriverPaidToContact` parsing (the API still returns it) but stop branching on it in the UI. `trip_provider.dart` and `payment_service.dart` lose the trip-charge call.

## Dashboard

`rideshare-dashboard` — the admin trip view keeps showing `hasDriverPaidToContact`; relabel it to "الرسوم مخصومة" / "Fee charged" since it no longer means "contact unlocked".

## Error handling

| Situation | Behaviour |
|---|---|
| Publish with `balance < fee` | 403 `INSUFFICIENT_BALANCE_FOR_TRIP_FEE`, publish rejected, app offers top-up |
| Balance dropped between publish and start | Trip starts; partial debit + `PendingCharge` for the remainder; driver blocked from publishing again until settled |
| Debit throws at trip start | Trip still starts; error logged; reconciliation job retries |
| Processor runs twice | `driverWalletChargeApplied` short-circuits the second run |
| Trip cancelled before `departureTime` | Auto-start returns early on terminal status — no fee |
| Trip starts with zero confirmed bookings | Stamped as charged with a `0.00` audit row |

## Testing

Backend (TDD — test first for each):

- `driver-trip-fee.service.spec.ts` — fee computation on all seats; idempotency; zero-booking skip; lifetime-free-trip path; exact-balance boundary; partial debit + pending charge; concurrent double-invocation.
- `trip-auto-start.processor.spec.ts` — charge fires once on transition; a throwing fee service does not block the start.
- `trips.service.spec.ts` — publish blocked below the fee, allowed at exactly the fee.
- `presence.service.spec.ts` — update the existing settlement tests: no hold interaction, no capture, presence flags still written.
- `booking-viewer.serializer.spec.ts` — rewrite for the always-revealed contract.
- `calls.service.spec.ts` / chat specs — a call/chat is permitted on a confirmed booking with `hasDriverPaidToContact = false`.
- Migration test — an active hold is released and the balance restored.

Mobile: widget tests asserting the contact row and call/chat buttons render for a booking with `hasDriverPaidToContact = false`, and that no fee-payment card appears in trip management.

Commands: `npm test` and `npm run lint` in `rideshare-backend`; `flutter test` and `flutter analyze` in `rideshare`.

## Out of scope

- Instant rides (`modules/instant-rides`) fee flow.
- Passenger-side fare payment (`payTripFromRiderWallet`).
- Any change to the fee **percentage** or to `communication_fees` admin settings.
- Driver no-show fines and the dispute workflow, which continue to run off presence data.
