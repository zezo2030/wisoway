# Phase 0 Research: App UX Improvements

**Feature**: 007-app-ux-improvements
**Date**: 2026-04-23

This document resolves the Technical Context unknowns and captures
best-practice decisions needed to plan implementation. All NEEDS
CLARIFICATION markers from the plan template are addressed here.

---

## R1 — Notification dispatch pattern (sync vs async, how to fan out)

**Decision**: Keep synchronous Firebase Admin dispatch for **per-user
addressed** notifications (booking confirmed, booking rejected, booking
created → driver). Introduce a **Bull-queued** dispatch for the **city
fan-out** trigger ("new trip posted").

**Rationale**:

- The existing `NotificationsService.create()` calls Firebase admin and the
  WebSocket gateway synchronously inside the request that triggered it —
  fine for 1–2 recipients, acceptable latency impact (<200 ms) under load.
- A city fan-out can reach thousands of recipients (spec SC-003 assumes
  cities with up to 50k signed-in users). Running that fan-out in-request
  would make `POST /trips` visibly slow and would block the posting driver.
- The repo already has Bull wired (`src/jobs/jobs.module.ts`) for
  `trip-expiration` and `notification-cleanup`. Adding a
  `new-trip-fanout` queue reuses existing Redis/worker plumbing.
- Structured logs per dispatch attempt (constitution Principle III) are
  easier to correlate when the fan-out is a single traceable job rather
  than an inline loop.

**Alternatives considered**:

- **All synchronous** — rejected: risks slow `POST /trips` and timeouts on
  large city broadcasts.
- **All async via Bull** — rejected for the per-user case: unnecessary
  latency (queue round-trip) for a 1-recipient booking notification and
  more moving parts to diagnose when a driver doesn't get pinged.
- **Event emitter (Nest's `EventEmitterModule`)** — rejected: adds a
  second dispatch mechanism alongside Bull and still leaves the large
  fan-out in-process.

---

## R2 — `users.city` data shape

**Decision**: Add a single nullable `city` string column to the `users`
table. Store the city **name** (not an ID), normalized for lookup via
lower-case compare. No normalization of locale variants ("Amman" vs
"عمّان") in this release — store whatever the user picks and match via
case-insensitive equality.

**Rationale**:

- Clarification #4 locked "explicit profile field" — no location permission,
  no background tracking.
- Jordan is the initial target market (the backend already defaults
  `walletCurrency` to `JOD` on `UserEntity`). A country column is not
  needed until cross-border targeting is a real requirement — deferred to
  a future PATCH migration.
- Storing the name directly avoids an onboarding-time lookup against a
  cities reference table; list of allowed cities is a UI-level concern (a
  picker that writes the chosen canonical name).
- Case-insensitive lookup (`LOWER(city) = LOWER(:target)`) is cheap and
  sidesteps trailing-whitespace / capitalization bugs.

**Alternatives considered**:

- **`cityId` foreign key to a `cities` table** — rejected for now: adds a
  reference table the product has no other need for; city reference data
  is a UI string list, not a domain entity.
- **GeoJSON / geography column** — rejected: location targeting is not
  geo-shape-based in this feature.
- **Locale-normalized composite** (city + locale) — rejected as
  premature; revisit when multi-lingual city matching shows real
  confusion.

---

## R3 — Flutter error surface architecture

**Decision**: Introduce three cooperating pieces in `rideshare/lib/core/`:

1. `errors/app_exception.dart` — sealed-style hierarchy (`NetworkException`,
   `ServerException`, `ValidationException`, `AuthException`,
   `PermissionException`, `UnknownException`) carrying the **original**
   error and stack for developer log capture.
2. `errors/failure.dart` — UI-layer value type with a **localization key**,
   optional arguments for string interpolation, optional "next action" (e.g.,
   re-authenticate), and a user-severity hint (info/warning/error).
3. `errors/exception_mapper.dart` — pure function from `Object + StackTrace`
   to `Failure`. Handles `DioException`, `FirebaseException`,
   `PlatformException`, `FormatException`, `TimeoutException`, and
   fallthrough → `Failure.unknown(...)`.

Plus:

4. `ui/error_surface.dart` — central `showFailure(BuildContext, Failure)`
   helper used by every screen/BLoC consumer (replaces ad-hoc
   `ScaffoldMessenger.of(context).showSnackBar` calls).

BLoC error states carry `Failure`, not raw exceptions; screens listen and
delegate to `error_surface.showFailure`.

**Rationale**:

- Keeps mapping (`Object → Failure`) separate from presentation
  (`Failure → Snackbar/Dialog`), so each is unit-testable.
- Localization-key + args approach plays nicely with existing `intl`
  + `.arb` files (`app_ar.arb`, `app_en.arb`).
- Developer log capture satisfies constitution Principle IV "developer
  still has access to the original error and stack trace" without leaking
  it to the user.

**Alternatives considered**:

- **`dartz` `Either<Failure, T>`** — rejected: adds a new paradigm across
  the BLoC surface; repository doesn't use it today.
- **Throwing `AppException` from services, catching at the UI** — rejected:
  BLoC states are the existing pattern for UI error signalling; mixing
  throw-at-ui would fight the BLoC convention.
- **Keeping the existing `ErrorHandler.getErrorMessage()` static helper** —
  rejected: it returns strings, not structured failures; no severity, no
  action; hard-coded Arabic; doesn't cover Firebase/platform/JSON cases.

---

## R4 — Real route service extraction

**Decision**: Extract the existing inline Google Directions call and
polyline decoding from `TripRouteMapScreen` into
`core/services/route_service.dart`. Expose a single method:

```dart
Future<RouteResult> fetchRoute({
  required LatLng origin,
  required LatLng destination,
});
```

where `RouteResult` is a sealed type `{ RouteOk(List<LatLng> polyline, BoundsLatLng bounds) | RouteUnavailable(Failure cause) }`. The service owns:

- HTTP call (via existing `ApiClient` dio instance or a dedicated dio with
  its own base URL — decided at implementation time).
- Polyline decoding (reuse the existing `_decodePolyline` algorithm, moved
  into this service and covered by unit tests).
- Bounds computation.
- Mapping of HTTP/Dio/timeout failures into a `Failure` via the new
  `ExceptionMapper` (not into raw exception strings).

Screens (`TripRouteMapScreen` and any other trip-map entry point) stop
calling `http.get()` directly and stop rendering a silent dashed straight
line — on `RouteUnavailable`, they surface the failure via `error_surface`
and still show origin/destination markers (spec FR-018).

**Rationale**:

- Unit-testability: a pure `_decodePolyline` test table + a mocked HTTP
  client verify the service without a real Directions API.
- Reuse: any future screen needing a route gets the same code path.
- Failure UX consistency: routing failures flow through the same error
  surface as every other failure in the app (spec FR-020).

**Alternatives considered**:

- **Move the Directions call to the backend** — rejected for this
  release: adds backend work, a new endpoint, and trip-coordinate
  forwarding pressure; the current client-side approach is working. A
  follow-up release can rehost if rate-limit or billing pressure appears.
- **Use a different routing vendor** — deferred: vendor selection is a
  product/ops decision, not a spec requirement.
- **Compute polylines server-side and store on `Trip`** — rejected:
  polylines go stale when origin/destination change; computing on demand
  is simpler.

---

## R5 — Permission-request UX timing (deferred from clarify)

**Decision**: Request notification permission **after successful sign-in**,
shown once, with a pre-prompt rationale UI ("Turn on notifications to get
booking updates") before the OS prompt. If denied, do not re-prompt
automatically; offer a path in Settings to re-enable.

**Rationale**:

- Matches both Android (Android 13+ runtime permission) and iOS (always a
  runtime prompt) best practice: tie the ask to a just-signed-in state so
  value is obvious.
- Avoids permission-prompt fatigue and platform anti-patterns (e.g.,
  cold-start prompts before the user knows what the app does).
- Keeps the decision revisitable — the spec's FR-007 already allows for
  this flexibility ("at a moment in the user journey when the value is
  clear").

**Alternatives considered**:

- **Cold-start prompt** — rejected: low acceptance rates, no context.
- **Contextual on first action** — valid but more work (two code paths:
  action wants to fire a notification → check permission → ask); revisit
  if post-release telemetry shows low opt-in.

---

## R6 — Rate limiting of device-register and user-facing notification
endpoints

**Decision**: Apply existing `ThrottlerGuard` (if present) or equivalent
middleware to `POST /notifications/devices`, `DELETE /notifications/devices/:token`,
and `PATCH /users/me`. Conservative limits: 30 requests / minute / IP for
each.

**Rationale**:

- Constitution Principle IV: "Authentication and password-reset endpoints
  MUST enforce rate limiting." Device registration is account-state
  adjacent and accepts an FCM token (an artifact an attacker might want
  to overwrite). Treat as auth-adjacent.
- 30/minute is generous for legitimate app traffic (token refresh is
  infrequent) but low enough to make enumeration impractical.

**Alternatives considered**:

- **No rate limit** — rejected on constitution grounds.
- **Per-user instead of per-IP** — could be added; per-IP is simpler and
  covers the unauthenticated attacker case.

---

## R7 — FCM token exposure in serializers

**Decision**: Explicitly exclude `fcmToken` on `UserEntity` and `token`
on `DeviceTokenEntity` from every user-facing serializer. Verify during
implementation by grepping for `fcmToken` and `token` in
`rideshare-backend/src/modules/**/dto/` and in admin dashboard API
responses; any surfacing is a CR blocker.

**Rationale**: Constitution Principle IV requires "Passwords MUST be
stored… and never returned in API responses." FCM tokens are not
passwords but are device identifiers that enable targeted push-spam if
leaked. Treating them as non-returnable matches the principle's intent.

**Alternatives considered**: none reasonable.

---

## R8 — Logging & audit record for device registration

**Decision**: Emit an audit record on `POST /notifications/devices` (create
or update) and on `DELETE /notifications/devices/{token}` with: acting
`userId`, device `platform`, `lastSeenAt` before/after, and the outcome.
The record goes to the same audit sink used by password changes and wallet
adjustments (constitution Principle III).

**Rationale**: Device registrations are an account-state transition that a
future security review will ask about ("who registered this device? when?").

**Alternatives considered**: log-only (no audit). Rejected — a
future-you investigating "did an attacker hijack notifications for user X"
would have nothing to look at.

---

## Summary — resolved unknowns

| Area | Decision |
|------|----------|
| Dispatch pattern | Sync for per-user; Bull queue for city fan-out |
| `users.city` shape | Nullable string, case-insensitive equality, no lookup table |
| Flutter error surface | `AppException` + `Failure` + `ExceptionMapper` + `error_surface` |
| Route service | Extract client-side; no backend proxy |
| Permission prompt moment | Post-sign-in with rationale |
| Rate limits | 30/min/IP on device-register/deregister and `PATCH /users/me` |
| FCM token in API | Never serialized |
| Audit records | Emitted on device register/deregister |

All items above were decidable from the surveyed codebase + spec
clarifications. No residual NEEDS CLARIFICATION.
