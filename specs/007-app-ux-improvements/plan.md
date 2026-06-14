# Implementation Plan: App UX Improvements — Error Messaging, Push Notifications, Real Route Rendering

**Branch**: `007-app-ux-improvements` | **Date**: 2026-04-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-app-ux-improvements/spec.md`

## Summary

Deliver three user-visible improvements across the Flutter mobile app and the
NestJS backend:

1. **User-friendly error messaging (US1, P1)** — introduce a unified
   `AppException` / `Failure` layer in the Flutter app, an `ExceptionMapper`
   that converts Dio/Firebase/platform/JSON/auth errors into localized
   user-visible strings, and a centralized toast/dialog surface. Preserve
   original errors in a developer log.
2. **FCM push notifications (US2, P2)** — extend the existing notifications
   module (Firebase Admin SDK + `DeviceTokenEntity` already present) to
   (a) emit notifications on booking lifecycle events to the correct party,
   (b) fan out "new trip posted" to city-scoped audiences, and
   (c) reconcile multi-device delivery. Flutter side: register and refresh
   tokens, request permission, handle foreground/background/cold-start, and
   deep-link to booking/trip screens.
3. **Real road-route rendering (US3, P3)** — the straight-line fallback in
   `TripRouteMapScreen` already has a Google Directions path; harden it so
   the real polyline is the default, isolate the routing call into a reusable
   `route_service.dart`, ensure every trip-map entry point uses it, and
   upgrade the failure UX to the US1 error style.

**Clarifications locked (session 2026-04-23)**: iOS + Android both in scope;
booking-created notifies the driver; new-trip-posted fans out to users whose
profile `city` matches the trip's origin city; `city` is an explicit profile
field (no ambient location tracking); every valid active device registration
for a user receives each addressed notification.

## Technical Context

**Language/Version**: TypeScript 5.7 (backend); Dart 3.x / Flutter 3.9.2 (mobile)
**Primary Dependencies**:
- Backend: NestJS 11.x, TypeORM, `firebase-admin` (already installed),
  `@nestjs/config`, Bull (for `notification-cleanup` and `trip-expiration`
  jobs — already wired).
- Mobile: `dio` 5.x (HTTP), `google_maps_flutter`, `firebase_core`
  (`^3.6.0`), `firebase_messaging` (`^15.1.3`), `flutter_local_notifications`
  (for foreground display — confirm present, add if missing), `flutter_bloc`
  8.x, `intl` (`^0.20.2`) for localization.
**Storage**: PostgreSQL (backend) via TypeORM. New column `city` on `users`.
Existing `device_tokens` table reused — no schema change expected unless the
survey missed a column; confirmed fields: `userId`, `token`, `platform`,
`isActive`, `lastSeenAt`.
**Testing**:
- Backend: Jest (`npm test`, `npm run test:e2e`). Add contract tests for new
  endpoints; unit tests for city-fan-out query; integration test for the full
  booking-confirmed → push-delivery flow (mock the Firebase admin client).
- Mobile: `flutter_test` widget/unit tests for `ExceptionMapper` (table of
  input→output), and golden-path widget tests for the toast/dialog surface.
  Driver integration test for notification-tap deep-link path if feasible;
  otherwise manual test plan in `quickstart.md`.
**Target Platform**:
- Backend: Node.js server (existing deployment).
- Mobile: Android (minSdk per existing `AndroidManifest`) and iOS
  (per existing Runner target). Both platforms ship with notifications in
  this release.
**Project Type**: Multi-surface web service + mobile app (constitution
Principle V — Cross-Platform Parity applies).
**Performance Goals**:
- Notification end-to-end delivery within 60 s of the triggering event in
  ≥95% of attempts (spec SC-003).
- City fan-out query MUST complete in <500 ms for a city with up to 50k
  signed-in users (expected upper bound for near-term scale).
- Route polyline fetched and rendered on trip-map open in <2 s on a typical
  mobile connection.
**Constraints**:
- Must NOT expose `fcmToken` or device-registration tokens in any API
  response (constitution Principle IV — Security & PII Protection).
- Must NOT leak stack traces or HTTP status codes in user-visible strings
  (constitution Principle IV and spec FR-002).
- All authentication-adjacent endpoints (device registration is an
  account-state transition) MUST emit a structured audit record in addition
  to the request log (constitution Principle III — Observability &
  Auditability).
- Origin / destination coordinates sent to the Google Directions API are
  existing behavior; document that this data leaves the system so a reviewer
  can make the call, but do not widen the data sent.
**Scale/Scope**:
- Backend: ~3 new endpoints (or extensions of existing notification
  controller), one new column (`users.city`), one or two new fan-out service
  methods.
- Flutter: ~6 new files (`core/errors/app_exception.dart`,
  `core/errors/failure.dart`, `core/errors/exception_mapper.dart`,
  `core/ui/error_surface.dart`, `core/services/route_service.dart`, and a
  central notification-route handler), plus edits to existing BLoCs and
  screens to route their errors through the new layer.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluated against `.specify/memory/constitution.md` v1.0.0:

- **I. API Contract Stability** — PASS. New endpoints are additive (device
  registration is a new path; existing notification endpoints continue to
  work). The new `city` field on User is additive and will be nullable on
  first deploy (backfill path, then tighten in a follow-up migration) per
  "Development Workflow & Quality Gates — Migrations".
- **II. Test-First Discipline (NON-NEGOTIABLE)** — PASS, enforced by plan:
  contract tests for each new endpoint will be written to fail before the
  handler is implemented; `ExceptionMapper` tests will be written before the
  mapping table.
- **III. Observability & Auditability** — PASS. Device registration
  mutations MUST write an audit record. Notification dispatch attempts MUST
  emit structured logs with the trigger type, recipient count, and success/
  failure counts.
- **IV. Security & PII Protection** — PASS conditionally, requires two
  specific guardrails captured in the plan:
  - `fcmToken` and `DeviceToken.token` MUST be excluded from every
    user-facing serializer (admin dashboard, mobile profile, public API).
  - Device registration and notification-related auth-adjacent endpoints
    MUST be rate-limited.
- **V. Cross-Platform Parity** — PASS. This plan ships backend and Flutter
  changes in the same branch; the admin dashboard is explicitly out of scope
  (spec Assumptions). A small dashboard patch may be needed if `users.city`
  appears in existing admin user serializers — confirm during Phase 1 design.

**Violations requiring justification**: none. See `Complexity Tracking`
section (empty).

## Project Structure

### Documentation (this feature)

```text
specs/007-app-ux-improvements/
├── plan.md              # This file
├── spec.md              # Feature specification (locked via /speckit.clarify)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (new backend endpoints)
└── checklists/
    └── requirements.md  # Spec-quality checklist (from /speckit.specify)
```

### Source Code (repository root)

```text
rideshare-backend/                       # NestJS 11 + TypeORM + PostgreSQL
├── src/
│   ├── modules/
│   │   ├── notifications/               # EXISTS — extend
│   │   │   ├── notifications.module.ts
│   │   │   ├── notifications.service.ts       # extend: city fan-out, booking hooks
│   │   │   ├── notifications.controller.ts    # extend: device register/deregister
│   │   │   ├── notifications.gateway.ts
│   │   │   └── dto/
│   │   ├── bookings/                    # EXISTS — inject NotificationsService if not already
│   │   ├── trips/                       # EXISTS — emit new-trip notification on post
│   │   └── users/                       # EXISTS — expose city getter/setter
│   ├── database/
│   │   ├── entities/
│   │   │   ├── user.entity.ts           # add: city (nullable)
│   │   │   └── device-token.entity.ts   # EXISTS — no schema change expected
│   │   └── migrations/
│   │       └── <timestamp>-add-city-to-users.ts   # NEW
│   └── common/
│       └── audit/                       # audit-log sink (reuse if exists, else new)
└── test/                                 # e2e + Jest unit tests

rideshare/                               # Flutter 3.9 passenger/driver app
├── lib/
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart          # existing; route DioException through new mapper
│   │   │   └── error_handler.dart       # DEPRECATED after new layer; keep as shim briefly
│   │   ├── errors/                      # NEW
│   │   │   ├── app_exception.dart       # base AppException
│   │   │   ├── failure.dart             # user-visible Failure model
│   │   │   └── exception_mapper.dart    # Dio/Firebase/Platform/JSON/Auth → Failure
│   │   ├── ui/
│   │   │   └── error_surface.dart       # NEW — unified toast/dialog helper
│   │   └── services/
│   │       ├── push_notification_service.dart  # EXISTS — extend with token lifecycle
│   │       └── route_service.dart       # NEW — extract Directions call + polyline decode
│   ├── bloc/                            # existing — route try/catches through mapper
│   ├── l10n/
│   │   ├── app_ar.arb                   # add keys for each Failure category
│   │   └── app_en.arb
│   └── screens/
│       └── trip_route_map_screen.dart   # refactor: use route_service, use error_surface
└── test/                                 # flutter_test coverage for mapper + ui surface

rideshare-dashboard/                     # admin — out of scope unless city leaks into a serializer
```

**Structure Decision**: This is Option 3 (Mobile + API). Notifications,
routing, and error handling each touch both surfaces; backend changes pair
with Flutter changes in this branch to satisfy constitution Principle V.

## Phase 0: Outline & Research

Deliverable: `research.md` (see sibling file). Research items resolved:

1. **Notification/event dispatch pattern** — existing code calls
   `NotificationsService` synchronously from `NotificationsService.create()`
   (Firebase admin + WebSocket gateway). Decision: keep synchronous dispatch
   for per-user addressed notifications (booking events), add a Bull-backed
   queue for the city fan-out trigger to avoid blocking the request that
   posts a trip when the recipient set is large (>1k).
2. **City model** — spec clarification #4 locked `users.city` as an explicit
   profile field. Decision: normalize via a `city` string (country-agnostic)
   plus a future `country` pair if cross-border targeting is ever needed;
   for now, a single `city` column with a case-insensitive lookup is
   sufficient.
3. **Flutter error surface** — existing `ErrorHandler.getErrorMessage()`
   covers DioException only and returns hard-coded Arabic strings. Decision:
   replace with `ExceptionMapper` that returns a `Failure` object carrying
   a localization key (not a raw string), so the UI layer localizes based
   on current `LocalizationService` locale.
4. **Route service** — existing `TripRouteMapScreen` already calls Google
   Directions and decodes polylines. Decision: extract the routing call +
   polyline decode + fallback path into `core/services/route_service.dart`
   as a testable unit; screens consume a `Stream<RouteState>` or a one-shot
   `Future<Route>`.
5. **Permission-request UX timing** — deferred from clarification (low
   impact). Decision in this plan: request permission immediately after
   successful sign-in, with a pre-prompt rationale screen per platform best
   practice. Revisitable without spec change.

## Phase 1: Design & Contracts

### Data model — see `data-model.md`

- `User.city` (new, nullable string) — targeting for city fan-out.
- `DeviceToken` (existing) — confirm fields, add uniqueness invariants if
  missing (`token` unique per row; active `true` may co-exist across devices
  for one user — this is the multi-device semantics locked in clarification
  #5).
- `NotificationTrigger` (conceptual only — not a persisted entity; governs
  which service method fires which notification).

### Contracts — see `contracts/` folder

- `POST /notifications/devices` — register an FCM device token.
- `DELETE /notifications/devices/{token}` — deregister (on sign-out).
- `PATCH /users/me` — set/update profile `city`.
- Internal service methods (not HTTP): `NotificationsService.notifyDriverOfBooking(bookingId)`,
  `NotificationsService.notifyCityOfNewTrip(tripId)`,
  `NotificationsService.notifyPassengerOfBookingDecision(bookingId, decision)`.

### Agent context update

Ran `.specify/scripts/powershell/update-agent-context.ps1 -AgentType claude`
as part of this plan step — see `CLAUDE.md` for new technology entries
(Firebase Admin SDK on backend, `firebase_messaging` and `google_maps_flutter`
already present, `ExceptionMapper` pattern).

### Post-design constitution re-check

Re-evaluated after drafting `data-model.md` and `contracts/`:

- I. Contract Stability — PASS (all new endpoints; existing endpoints
  untouched).
- II. Test-First — PASS (quickstart + contract tests drafted before
  implementation).
- III. Observability — PASS (audit record emitted on device-register and
  device-deregister; structured log on each dispatch attempt).
- IV. Security & PII — PASS, with the two guardrails carried into
  `contracts/` (token never in response; endpoints rate-limited).
- V. Cross-Platform Parity — PASS (Flutter and backend in same branch;
  dashboard impact confirmed none unless city surfaces in admin serializer).

No new violations introduced.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |
