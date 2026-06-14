# Implementation Plan: Platform Completion (Spec-vs-Code Gap Closure)

**Branch**: `008-platform-completion` | **Date**: 2026-04-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-platform-completion/spec.md`

## Summary

Close the gap between the original Arabic product specification (`requredplan.md`) and the current implementation across the three surfaces of the Wisoway rideshare product (NestJS backend, React admin dashboard, Flutter mobile app). The work spans seven cohesive areas:

1. **Auth hardening** — phone+OTP only sign-in, removal of email/password and Google/Facebook OAuth, device binding, server-side rejection of mocked-location updates, and lightweight fake-account flagging.
2. **Driver-photo enforcement and admin queue** — block driver approval and trip publication when the driver photo is missing; surface flagged accounts in the dashboard.
3. **Booking lifecycle overhaul** — multi-seat / companion bookings (one request, N seats), random-seat auto-pick, complete status enum, 3-hour pending timeout, cancellation windows (24h driver / 12h passenger), 5%/10% pending charges with hybrid wallet-deduct-then-carry-forward collection, and no-show detection.
4. **Trip-time flow** — pre-trip per-passenger confirmation cycle, driver "Start Trip" gate, completion flow, and a public share-link page for live driver-location viewing without an app.
5. **Trip authoring extensions** — recurring trips (daily / specific weekdays), intermediate stops, and free-text notes.
6. **Post-payment data reveal** — driver-pressed "Mark paid" settles a booking, after which contact details unmask and chat/call activate. Optional phone-masking preference. New `CallsModule` providing in-app calling with proxy numbers when masking is on.
7. **Admin / support / refund** — distinct ban state, complaint module, in-app refund request that opens WhatsApp deep-link to `+962 78 888 3007` and writes a server-side admin record.

Approach: ship in six branches (one per phase below), each independently mergeable to `main`, each pairing backend changes with the matching dashboard and mobile updates per Constitution V (Cross-Platform Parity).

## Technical Context

**Language/Version**: TypeScript 5.7 (backend), Dart 3.x / Flutter 3.9.2 (mobile), TypeScript ~5.x (admin dashboard)
**Primary Dependencies**: NestJS 11.x, TypeORM, BullMQ (job queues), Twilio (SMS OTP — already integrated), Firebase Admin SDK (push), Socket.IO (chat gateway), Cliq A2A (in-app fee payment — retained per CLAR-001), PostGIS (spatial queries), bcrypt (legacy password hashing — to be removed for end-user auth, kept only for any admin login). Mobile: `flutter_bloc`, `provider`, `dio`, `geolocator`, `device_info_plus`, `share_plus`, Google Maps Flutter, Firebase Messaging, `flutter_localizations` (AR/EN). Dashboard: React, react-i18next.
**Storage**: PostgreSQL (primary store, with PostGIS extension on `trips` for nearby-trip search). Redis (cache + BullMQ broker — already used).
**Testing**: backend `jest` (unit + integration), backend supertest for HTTP contract tests against in-memory or test-database setup, `flutter_test` and widget tests for mobile. Dashboard tests where present (vitest/jest).
**Target Platform**: Linux server (containerized), iOS 13+ and Android 7+ (mobile), evergreen browser (admin dashboard).
**Project Type**: web — multi-surface monorepo containing `rideshare-backend/`, `rideshare-dashboard/`, `rideshare/` (mobile).
**Performance Goals**: trip feed P95 < 2 s, nearby-trip query P95 < 1 s, push notification delivered to device ≤ 30 s after trigger event, share-link map page renders driver location ≤ 20 s old (SC-008), pre-trip notifications fire within ±2 minutes of target (SC-007), pending-booking timeout fires within ≤ 5 minutes of crossing the 3-hour boundary.
**Constraints**: must reuse the existing wallet ledger (`WalletService`) for hybrid penalty collection; must not break the contract surface consumed by deployed mobile clients (versioning required where shapes change — see Constitution I); migrations must be additive-safe per Constitution governance section.
**Scale/Scope**: target ~10 000 active users in the Jordan launch market; roughly 200 concurrent active trips at peak. ~50 new endpoints / events across the seven areas, ~12 new database tables/migrations, ~25 new mobile screens or screen variants, ~8 new dashboard pages.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluating against `.specify/memory/constitution.md` v1.0.0:

| Principle | Status | Notes |
|---|---|---|
| I. API Contract Stability | **PASS with conditions** | Booking shape changes from `seatNumber: string` to `seats: SeatBooking[]` — a breaking change. Must be versioned: ship new endpoints under `/v2/bookings` (or add a new request shape that the existing controller accepts in addition to the legacy one) with the legacy `seatNumber` request kept until the mobile app rolls forward. Booking status enum gains values; mobile must tolerate unknown statuses (already the case). |
| II. Test-First Discipline | PASS | Each phase ships with red-then-green tests: contract tests for every new HTTP endpoint, integration tests for the timeout / no-show / cancellation-fee flows, unit tests for the cancellation-policy and gender-adjacency rules with companions. |
| III. Observability & Auditability | PASS | New entities (`pending_charges`, `account_flags`, `complaints`, `refund_requests`, `user_devices`) all carry `createdAt`, action user, and outcome. Wallet auto-deduct path writes a wallet-transaction audit row (existing pattern). Mocked-location rejection writes a `security_events` row. |
| IV. Security & PII Protection | PASS | OTP endpoints stay rate-limited (existing). Driver/passenger phone hidden until settled (FR-037). New share-link endpoint is read-only and emits no PII. Device fingerprinting stored as opaque hash, not raw IDs in logs. No new password storage paths. |
| V. Cross-Platform Parity | PASS | Each branch ships with paired mobile + dashboard updates in the same PR. New backend enum values flow as i18n keys to both AR/EN ARB files and dashboard `i18n/`. |

**Result**: PASS. Conditional item under Principle I documented in Complexity Tracking below as a deliberate (versioning) tradeoff.

## Project Structure

### Documentation (this feature)

```text
specs/008-platform-completion/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output — entities, relationships, state transitions
├── quickstart.md        # Phase 1 output — local-dev test plan walking each acceptance scenario
├── contracts/           # Phase 1 output — HTTP contract files per area
│   ├── auth.contract.md
│   ├── bookings.contract.md
│   ├── trips.contract.md
│   ├── trip-time.contract.md
│   ├── recurrence.contract.md
│   ├── settlement-and-calls.contract.md
│   └── admin-support.contract.md
└── tasks.md             # Phase 2 output (/speckit.tasks command — NOT created by /speckit.plan)
```

### Source Code (repository root)

This is a multi-surface monorepo. The selected structure is the existing layout — no new top-level directories are introduced. New work lands as new modules within each existing surface:

```text
rideshare-backend/                # NestJS API
├── src/
│   ├── modules/
│   │   ├── auth/                 # MOD: phone-only, device binding, fake-account flag
│   │   ├── users/                # MOD: hidePhoneNumber preference, ban state
│   │   ├── vehicles/             # touched lightly (mandatory-photo-on-driver guard)
│   │   ├── trips/                # MOD: stops, notes, recurrence
│   │   ├── recurrence/           # NEW: recurring-trip rules + spawner job
│   │   ├── bookings/             # MOD: multi-seat, status enum, timeouts, cancel-policy
│   │   ├── seats/                # touched (companion-aware adjacency rule)
│   │   ├── trip-time/            # NEW: confirmation cycle, start/complete, presence flags
│   │   ├── tracking/             # MOD: reject mocked, share-link issuance
│   │   ├── share-links/          # NEW: public read-only trip share endpoint
│   │   ├── settlement/           # NEW: driver "mark paid" + grace-window unsettlement
│   │   ├── calls/                # NEW: in-app call session brokering with masking
│   │   ├── chat/                 # MOD: gate by settledAt
│   │   ├── pending-charges/      # NEW: 5%/10% charges, hybrid collection
│   │   ├── wallet/               # touched (consumed by pending-charges)
│   │   ├── notifications/        # MOD: new templates per FR-049
│   │   ├── complaints/           # NEW
│   │   ├── refunds/              # NEW (record-only; conversation in WhatsApp)
│   │   ├── admin/                # MOD: ban, complaints queue, refunds queue, flags queue
│   │   └── support/              # NEW: WhatsApp deep-link config endpoint
│   ├── jobs/                     # MOD: pending-booking-timeout, no-show-detector, recurrence-spawn, pre-trip-confirm
│   ├── database/
│   │   └── entities/             # +UserDevice, AccountFlag, RecurrenceRule, BookingSeat, PendingCharge, Complaint, RefundRequest, TripShareLink, CallSession, SettlementAudit, SecurityEvent
│   └── database/migrations/      # +10 migrations (one per phase commit roughly)
└── test/
    ├── contract/                 # NEW per-endpoint contract specs
    ├── integration/              # cancellation-fee carry-forward, no-show, timeout, mark-paid grace
    └── unit/                     # cancellation-policy, gender-adjacency-with-companions

rideshare/                        # Flutter mobile
├── lib/
│   ├── bloc/
│   │   ├── auth/                 # MOD: drop email/social paths
│   │   ├── trip/                 # MOD: stops/notes/recurrence
│   │   ├── booking/              # MOD: multi-seat, random-seat, cancel-warning
│   │   ├── trip_time/            # NEW: pre-trip confirm, start, complete
│   │   ├── settlement/           # NEW: mark-paid bloc
│   │   ├── calls/                # NEW
│   │   └── complaints/           # NEW
│   ├── screens/
│   │   ├── auth/                 # phone-only flow (delete email/social screens)
│   │   ├── driver/               # +car edit, +trip create with stops/notes/recurrence, +driver pre-trip checklist, +mark-paid, +start trip, +ban screen
│   │   ├── passenger/            # +companion picker, +random seat, +pre-trip prompt, +share link, +complaint
│   │   ├── shared/               # +settled-vs-unsettled card variants, +call screen with masking
│   │   ├── support/              # MOD: WhatsApp deep-link buttons
│   │   └── refund/               # NEW
│   ├── core/api/                 # MOD: api_endpoints adds new routes; api_client adds versioned booking shape
│   ├── core/services/            # +device_binding_service, +location_spoof_guard, +call_service
│   └── l10n/                     # MOD: app_ar.arb + app_en.arb additions
└── test/
    ├── widget/                   # new screens
    └── integration_test/         # bookings-with-companions golden path

rideshare-dashboard/              # React admin
└── src/
    ├── pages/
    │   ├── users/                # MOD: ban action, ban-reason, devices tab
    │   ├── flags/                # NEW: account-flags review queue
    │   ├── complaints/           # NEW
    │   ├── refunds/              # NEW: refund-requests queue (record-only)
    │   ├── pending-charges/      # NEW: outstanding penalty list with waive
    │   ├── trips/                # MOD: stops/notes/recurrence visible
    │   └── bookings/             # MOD: new statuses, multi-seat
    └── i18n/                     # MOD: AR/EN strings for all new UI
```

**Structure Decision**: existing three-surface layout retained. Each new domain area gets a module folder under `rideshare-backend/src/modules/`, paired by a corresponding feature in `rideshare/lib/` and (where admin-visible) a page in `rideshare-dashboard/src/pages/`. No new top-level directories.

## Phasing & Branch Plan

The work is split into six branches. Each branch passes the constitution gates on its own, ships migrations additive-safe, and pairs backend with the corresponding mobile/dashboard changes.

| # | Branch | Scope | Acceptance ties |
|---|---|---|---|
| 1 | `009-auth-hardening` | Phase 1 — phone-only auth, social-login removal with phone-link migration, device binding, mocked-location rejection, fake-account flagging, mandatory driver photo guard | US 1; FR-001..009; SC-001, SC-002, SC-010 |
| 2 | `010-booking-lifecycle` | Phase 2 — booking status enum + multi-seat + auto-pick + 3h timeout + cancellation windows + pending charges + hybrid wallet collection + no-show detector | US 2; FR-020..030; SC-003..006 |
| 3 | `011-trip-time-flow` | Phase 3 — pre-trip confirmations, start/complete, share link with public read page | US 3; FR-031..036; SC-007, SC-008 |
| 4 | `012-trip-authoring` | Phase 4 — recurrence rules + spawner job + stops + notes (Trip entity extensions) | US 4; FR-013..014, FR-011 |
| 5 | `013-settle-and-call` | Phase 5 — driver "Mark paid" + grace-window settlement + post-settle data reveal across all serializers + chat/call gating + new `CallsModule` with masking + `hidePhoneNumber` preference | US 5; FR-037..041; SC-009 |
| 6 | `014-admin-and-support` | Phase 6 — ban state + complaints + WhatsApp deep-link + refund-request record + complaint admin pages + flags/refunds queues + dashboard wiring | US 6; FR-042..049; SC-011..013 |

Branch 1 lands first; Branch 2 depends on it (security & auth must be in place before booking changes that depend on `userDevices` and ban-state). Branches 3 and 4 are independent of each other but both depend on Branch 2's status enum. Branch 5 depends on Branch 2 (settlement gates rest on the new booking statuses). Branch 6 depends on Branches 1, 2, 5.

## Phase 0 — Research

See `research.md`. The clarification session resolved all five scope-shaping ambiguities; Phase 0 only needs to nail down implementation-pattern choices (job scheduler, share-link tokenization, call provider, device-fingerprint hashing). Each item ships with Decision / Rationale / Alternatives.

## Phase 1 — Design Artefacts

- **`data-model.md`** — full entity catalog with fields, relationships, indexes, state transitions, and per-entity migration strategy.
- **`contracts/`** — one HTTP contract spec per domain area listing endpoints, request/response shapes, error codes, and contract-test names. These map 1-to-1 to the test files added under `rideshare-backend/test/contract/`.
- **`quickstart.md`** — a local-dev runbook that walks each P1/P2 acceptance scenario end-to-end (curl + Flutter button taps), useful as the smoke-test checklist before merging each branch.

After Phase 1 is generated, the agent context file is regenerated by the project's `update-agent-context.ps1` so that follow-up runs of `/speckit.plan` or `/speckit.tasks` see the new modules and dependencies.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Versioned booking endpoints (`/v1/bookings/*` legacy + `/v2/bookings/*` multi-seat) | Constitution I requires deployed mobile clients to keep working until they roll forward. The booking request shape changes from a single `seatNumber` to a `seats[]` array. | A single `bookings` endpoint accepting both shapes was considered; it would inflate the controller and duplicate validation. Versioned endpoints isolate the change and let v1 be deleted in a future release once the mobile floor is raised. |
| Two distinct charge mechanisms (wallet auto-deduct *and* pending-charge debt) | CLAR-003 hybrid policy requires both. | A wallet-only model would force user top-ups (rejected in clarification) and a debt-only model would skip the easy-win path for users who already have wallet balance. |
| Public share-link page rendered outside the mobile app | FR-035 explicitly requires a non-app viewer. | Forcing recipients to install the app would cripple the family-tracking use case. Tokenized link with no PII is the minimum viable safe approach. |
| Calls module separate from chat | Spec lines 138–141 distinguish "call" from "chat" and list phone-number masking as a calls-only feature. | Bundling into chat would force chat to depend on a voice provider and conflate gating logic. |

These deviations are recorded; reviewers should challenge them only if a simpler equivalent surfaces during implementation.
