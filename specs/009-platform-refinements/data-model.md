# Phase 1 Data Model: Platform Refinements

**Feature**: 009-platform-refinements
**Date**: 2026-06-14

This feature is largely additive. Below are the new/changed entities and the in-memory/config structures (autocomplete, seat templates) that don't require persistence. All schema changes are additive-safe (new tables or new nullable columns) per the constitution's migration rule.

---

## 1. Web push token (admin dashboard)

**Approach**: extend the existing `device_tokens` table rather than create a parallel store, since the backend's `sendPush` already iterates device tokens.

**Change to `device_tokens`** (`src/database/entities/device-token.entity.ts`):

| Field | Type | Notes |
|-------|------|-------|
| `platform` | varchar | EXTEND allowed values to include `web` (existing: ios/android). Nullable-safe default for existing rows. |
| `userAgent` | varchar, nullable | NEW (optional) — identify the admin's browser for token hygiene. |

- A web token is owned by an admin/operator user (existing `userId` FK).
- Registration endpoint is auth-gated and only persists `platform='web'` tokens for users whose role is admin/operator.
- Token lifecycle: replace on refresh, delete on `messaging` invalid-token errors (existing cleanup path reused).

**Validation / rules**:
- Only `role IN (admin, operator)` users may register a `web` token used for admin alerts.
- Stale/invalid tokens are pruned on send failure (existing behavior).

---

## 2. Admin alert subscription preference

**New entity** `admin_alert_preference` (`src/database/entities/admin-alert-preference.entity.ts`):

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid PK | |
| `userId` | uuid FK → users | the admin/operator |
| `alertType` | enum (`driver_registration`, `fee_payment`) | which event |
| `enabled` | boolean, default true | per-type opt-in/out (FR-017) |
| `createdAt` / `updatedAt` | timestamptz | |

- Unique constraint on `(userId, alertType)`.
- Absence of a row = default enabled (so existing admins are opted-in by default; they can disable).

**State / rules**:
- An alert of `alertType` is delivered to an admin only if no row exists OR the row's `enabled = true` (FR-016/FR-017).
- End-users (role passenger/driver) are never recipients regardless of preferences.

---

## 3. Admin Alert (notification instance — reuse existing)

No new table. Reuse the existing `notifications` entity for the in-app/audit copy, with:
- `type`: `admin_driver_registration` | `admin_fee_payment`
- `channel`: `PUSH` (delivered as FCM **web**) — the in-app bell copy also surfaces it
- `data` (jsonb): deep-link context, e.g. `{ "link": "/users/<id>", "driverId": "<id>" }` or `{ "link": "/payments", "paymentId": "<id>", "amount": <n>, "currency": "<c>" }`

**Rules**:
- Driver-registration alert fires when a new driver completes registration (account created with role=driver / driver profile submitted).
- Fee-payment alert fires only on a **successful in-app platform/communication-fee payment** (`payment.paymentType = communication_fee` reaching approved/credited state in `cliq-poll.processor` success path). Penalties, top-ups, refunds do **not** fire (clarification + FR-014).
- Each send emits a structured log line (event type, recipient count, success/failure) — constitution III.

---

## 4. Vehicle-type → seat-layout catalog (config, not a row per request)

**New config** `src/modules/vehicles/vehicle-types.ts` — canonical map; optionally seeded into a small `vehicle_types` reference table for admin editing later (table optional for v1).

```text
VehicleTypeTemplate {
  type: string            // 'sedan' | 'suv' | 'van' | 'truck' | 'bus' | 'motorcycle'
  label: { en: string, ar: string }
  seats: number           // bookable passenger seats
  layout: SeatLayout      // { rows, seatsPerRow, seatsPerRowList?, preventGenderMixing? }
}
```

Reuses the existing `SeatLayout` shape already stored on `vehicle.seatLayout` (rows, seatsPerRow, seatsPerRowList, preventGenderMixing). No new seat structure is invented.

**Rules**:
- Each supported `type` MUST have a template (FR-012). A type without one falls back to a sensible default (e.g. sedan: 1 row of 3 bookable) and is flagged in logs.
- Selecting a type on the client auto-applies `layout` (FR-009); changing the type replaces it (FR-010).
- The vehicle's **stored** `seatLayout` remains the source for trip seat generation; the catalog only provides the default/prefill.

---

## 5. Place Suggestion & Place Detail (transient — no persistence)

Returned by the autocomplete proxy; not stored (short-TTL cache only).

```text
PlaceSuggestion {
  placeId: string         // opaque provider id, used to fetch detail
  primaryText: string     // main label
  secondaryText: string   // region/area disambiguation
  description: string     // full label for the field
}

PlaceDetail {
  placeId: string
  label: string
  lat: number
  lng: number
}
```

**Rules**:
- Suggestions are language- and region-aware (FR-007); selecting one resolves to a `PlaceDetail` carrying coordinates for trip creation/search (FR-006).
- No raw query text or suggestion payload is written to general-purpose logs (constitution IV).

---

## 6. Driver Approval Status (no schema change)

Already modeled as `user.isDriverApproved: boolean` plus `restricted`/`bannedAt`. This feature changes only **client freshness** (mobile re-fetch), not the data model. Documented here for completeness:
- `canCreateTrips` (client-derived) = `isDriver && isDriverApproved` and must reflect the latest server value at the create-trip decision point (FR-002).

---

## 7. Localized String Resource (no schema change)

The mobile `.arb` files and the dashboard `translations.ts` are the resource sets verified by this feature. The parity guard (research R5) operates on these files; no database involvement.

---

## Migration summary

| Migration (additive) | Change |
|----------------------|--------|
| `*-add-web-platform-to-device-tokens` | allow `platform='web'`, add nullable `userAgent` |
| `*-create-admin-alert-preferences` | new `admin_alert_preference` table |
| *(optional)* `*-create-vehicle-types` | reference table seeded from the config catalog (only if admin-editable catalog is desired in v1) |

All are nullable-add / new-table only — safe against the previously deployed version for one cycle (constitution: Migrations).
