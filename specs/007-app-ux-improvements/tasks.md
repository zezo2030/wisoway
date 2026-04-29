---

description: "Task list for feature 007-app-ux-improvements"
---

# Tasks: App UX Improvements — Error Messaging, Push Notifications, Real Route Rendering

**Input**: Design documents from `/specs/007-app-ux-improvements/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included. Constitution Principle II (Test-First Discipline, NON-NEGOTIABLE) requires failing tests before implementation for backend endpoints and pure-function Flutter components. Test tasks below are to be completed first within each story.

**Organization**: Tasks are grouped by user story (US1, US2, US3) so each story can be implemented and shipped independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different file, no dependency on an incomplete task in the same phase)
- **[Story]**: US1, US2, US3 maps to user stories in `spec.md`. Setup / Foundational / Polish tasks have no story label.

## Path Conventions

- Backend: `rideshare-backend/src/`, tests in `rideshare-backend/test/`
- Mobile: `rideshare/lib/`, tests in `rideshare/test/`
- Feature spec root: `specs/007-app-ux-improvements/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: minimal shared plumbing shared across more than one story.

- [X] T001 [P] Register a new Bull queue `new-trip-fanout` in `rideshare-backend/src/jobs/jobs.module.ts` (registration only — processor is implemented in US2)
- [X] T002 [P] Verify an audit-sink service exists (used by password-change flow); if absent, scaffold `rideshare-backend/src/common/audit/audit.service.ts` (+ module) so US2 device-register/deregister and future auditable actions have a single emission point per constitution Principle III

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: no cross-story blocking prerequisites were identified beyond Phase 1. Each user story is independently implementable.

(intentionally empty — proceed to user stories)

**Checkpoint**: Foundation ready — user story implementation can now begin in parallel

---

## Phase 3: User Story 1 — Clean, user-friendly error messages across the app (Priority: P1) 🎯 MVP

**Goal**: every exception that reaches the UI is translated to a plain-language, localized message via a single `ExceptionMapper`/`Failure`/`error_surface` pipeline; raw stack traces, HTTP codes, and exception class names never reach the user; original errors are preserved in a developer log.

**Independent Test**: follow the US1 section in `quickstart.md` (offline, session expired, 5xx, business-rule, developer-log capture). All messages plain language in current locale, no technical strings visible, developer log contains the original exception.

### Tests for User Story 1

> Write these FIRST and ensure they FAIL before the corresponding implementation tasks.

- [X] T003 [P] [US1] Write failing unit test table for `ExceptionMapper.fromError` in `rideshare/test/core/errors/exception_mapper_test.dart` covering DioException (connect-timeout, receive-timeout, HTTP 401, HTTP 5xx, HTTP 400 with business-rule body), `FirebaseException` (auth/invalid-credential, permission-denied, unknown), `PlatformException` (denied), `FormatException`, `TimeoutException`, generic `Object`
- [X] T004 [P] [US1] Write failing widget test for `showFailure(BuildContext, Failure)` in `rideshare/test/core/ui/error_surface_test.dart` verifying severity→surface mapping (info/warning → SnackBar, error → Dialog, with `nextAction` buttons when present)

### Implementation for User Story 1

- [X] T005 [P] [US1] Create `FailureCategory` and `FailureSeverity` enums plus the `Failure` class (fields per `data-model.md` §5) in `rideshare/lib/core/errors/failure.dart`
- [X] T006 [P] [US1] Create `AppException` sealed hierarchy (`NetworkException`, `ServerException`, `ValidationException`, `AuthException`, `PermissionException`, `UnknownException`) in `rideshare/lib/core/errors/app_exception.dart`
- [X] T007 [US1] Implement `ExceptionMapper` in `rideshare/lib/core/errors/exception_mapper.dart` (depends on T005, T006; drives T003 to green)
- [X] T008 [P] [US1] Add Arabic localization keys for every `FailureCategory` + `nextAction` to `rideshare/lib/l10n/app_ar.arb` (`errors.network.offline`, `errors.server.generic`, `errors.auth.session_expired`, `errors.permission.denied`, `errors.validation.generic`, `errors.unknown.generic`, `errors.action.retry`, `errors.action.reauthenticate`, `errors.action.open_settings`)
- [X] T009 [P] [US1] Add matching English localization keys (same key set) to `rideshare/lib/l10n/app_en.arb`
- [X] T010 [US1] Implement `showFailure(BuildContext, Failure)` in `rideshare/lib/core/ui/error_surface.dart` (SnackBar for info/warning, Dialog for error and when `nextAction != null`; localizes via `AppLocalizations` / `intl`; drives T004 to green)
- [X] T011 [US1] Refactor the Dio interceptor chain in `rideshare/lib/core/api/api_client.dart` (or wrapper) so `DioException` is converted to a `Failure` via `ExceptionMapper`; downstream callers receive `Failure` in error paths instead of raw `DioException`
- [X] T012 [US1] Remove (or shim-and-deprecate) the legacy static helper in `rideshare/lib/core/api/error_handler.dart`; any remaining callers now go through `ExceptionMapper`
- [X] T013 [US1] Update `AuthBloc` error state to carry `Failure` (not `String`) in `rideshare/lib/bloc/auth/auth_state.dart` and adjust emissions in `rideshare/lib/bloc/auth/auth_bloc.dart`
- [X] T014 [US1] Update `TripBloc` error state to carry `Failure` in `rideshare/lib/bloc/trip/trip_state.dart` and adjust emissions in `rideshare/lib/bloc/trip/trip_bloc.dart`
- [X] T015 [US1] Grep-and-replace direct `ScaffoldMessenger.of(context).showSnackBar(...)` error invocations across `rideshare/lib/screens/**/*.dart` with `showFailure(context, failure)`; sequential because many screens are touched and conflicts are easier to catch serially
- [X] T016 [P] [US1] Ensure `Failure.developerDetail` is surfaced in debug builds via `developer.log` (or `debugPrint`) from `error_surface.showFailure` so the original exception + stack trace is captured; not visible in release builds

**Checkpoint**: US1 should now be fully functional and testable independently — MVP can ship with only this story in place.

---

## Phase 4: User Story 2 — Push notifications for trip lifecycle events (Priority: P2)

**Goal**: the backend sends FCM push notifications for booking-created (→ driver), booking confirmed/rejected/canceled (→ affected party), and new-trip-posted (→ city fan-out). The Flutter app registers and refreshes device tokens, handles foreground/background/cold-start, and deep-links to booking/trip screens. Multi-device delivery works; permission denial is handled gracefully.

**Independent Test**: follow the US2 section in `quickstart.md` (booking confirmed, booking created, city fan-out, permission denied, multi-device, token invalidation). Notifications arrive within 60 s in ≥95% of attempts, taps land on the correct screen.

### Tests for User Story 2

> Write these FIRST and ensure they FAIL before the corresponding implementation tasks.

- [X] T017 [P] [US2] Write failing contract test for `POST /notifications/devices` in `rideshare-backend/test/notifications/devices.contract.spec.ts` covering all 8 cases in `contracts/notifications-devices.md` (new token, refresh, handoff, 401, 400 invalid platform, rate limit, 204 deregister, 404 foreign token)
- [X] T018 [P] [US2] Write failing contract test for `PATCH /users/me` city field in `rideshare-backend/test/users/profile.contract.spec.ts` covering all 6 cases in `contracts/user-profile-city.md` (happy path, trim-to-null, over-length 400, 401, GET returns null, response excludes `fcmToken`/`token`)
- [X] T019 [P] [US2] Write failing service test for the city fan-out worker in `rideshare-backend/test/notifications/city-fanout.spec.ts` (case-insensitive match, poster exclusion, multicast batching, FCM-unregistered → `isActive=false`, aggregate log)
- [X] T020 [P] [US2] Write failing service test for booking-trigger notifications in `rideshare-backend/test/notifications/booking-triggers.spec.ts` (driver notified on booking-created, passenger notified on confirm/reject, driver notified on passenger-cancel, dispatch failure does NOT throw into caller)

### Implementation for User Story 2 — Backend

- [X] T021 [US2] Add nullable `city` column (`varchar(64)`) to `UserEntity` in `rideshare-backend/src/database/entities/user.entity.ts`
- [X] T022 [US2] Create migration `rideshare-backend/src/database/migrations/<next-timestamp>-add-city-to-users.ts` that `ALTER TABLE users ADD COLUMN city varchar(64) NULL` and `CREATE INDEX idx_users_lower_city ON users (LOWER(city)) WHERE "isActive" = true`
- [X] T023 [US2] Verify `DeviceTokenEntity` in `rideshare-backend/src/database/entities/device-token.entity.ts` has `UNIQUE(token)`; add a small migration if missing
- [X] T024 [P] [US2] Create `RegisterDeviceDto` with `token`/`platform`/`appVersion` validators in `rideshare-backend/src/modules/notifications/dto/register-device.dto.ts`
- [X] T025 [US2] Implement `POST /notifications/devices` handler in `rideshare-backend/src/modules/notifications/notifications.controller.ts` and the upsert + handoff logic in `rideshare-backend/src/modules/notifications/notifications.service.ts` (emit audit record + structured log with `tokenPrefix` only; drives part of T017 to green)
- [X] T026 [US2] Implement `DELETE /notifications/devices/:token` handler (404 on foreign token; soft-deactivate; audit + log) in the same controller/service (drives remainder of T017 to green)
- [X] T027 [US2] Apply `ThrottlerGuard` (30/min/IP) to both device endpoints and to `PATCH /users/me` in their respective controllers
- [X] T028 [US2] Grep `rideshare-backend/src/modules/**/*.dto.ts` and any user-serializer helpers to confirm `fcmToken` and `DeviceToken.token` are excluded from every user-facing response; add `@Exclude()` or equivalent where a field leaks
- [X] T029 [US2] Extend `UpdateMeDto` (or existing profile-update DTO) with optional `city` validator (trim, 1–64 chars, empty string → null) in `rideshare-backend/src/modules/users/dto/update-me.dto.ts`
- [X] T030 [US2] Implement `city` write path in `UsersService` at `rideshare-backend/src/modules/users/users.service.ts` (drives T018 to green)
- [X] T031 [P] [US2] Implement `NotificationsService.notifyDriverOfNewBooking(bookingId)` in `rideshare-backend/src/modules/notifications/notifications.service.ts` (resolve driver, build data payload per `contracts/notifications-triggers.md`, dispatch; swallow+log Firebase errors)
- [X] T032 [P] [US2] Implement `NotificationsService.notifyPassengerOfBookingDecision(bookingId, decision)` in the same file
- [X] T033 [P] [US2] Implement `NotificationsService.notifyDriverOfBookingCancellation(bookingId)` in the same file
- [X] T034 [US2] Wire `BookingsService` in `rideshare-backend/src/modules/bookings/bookings.service.ts` to call the three trigger methods on create/confirm/reject/cancel (inject `NotificationsService` if not already; drives T020 to green)
- [X] T035 [US2] Implement `NotificationsService.enqueueCityFanout(tripId)` that only enqueues the Bull job in the notifications service
- [X] T036 [US2] Implement `NewTripFanoutProcessor` at `rideshare-backend/src/jobs/processors/new-trip-fanout.processor.ts` — resolve trip origin city, query `SELECT id FROM users WHERE LOWER(city) = LOWER(:originCity) AND "isActive" = true AND id <> :posterId`, batch up to 500 tokens per `sendEachForMulticast`, deactivate tokens reported as unregistered, emit one aggregate structured log + one audit record (drives T019 to green)
- [X] T037 [US2] Wire `TripsService` in `rideshare-backend/src/modules/trips/trips.service.ts` to call `enqueueCityFanout(trip.id)` on successful trip create

### Implementation for User Story 2 — Flutter

- [X] T038 [P] [US2] Extend `PushNotificationService` in `rideshare/lib/core/services/push_notification_service.dart` to call `POST /notifications/devices` after successful sign-in and on `FirebaseMessaging.instance.onTokenRefresh`
- [X] T039 [P] [US2] Add sign-out hook in the auth flow (likely `rideshare/lib/bloc/auth/auth_bloc.dart` sign-out handler) that calls `DELETE /notifications/devices/{token}` before clearing local auth state
- [ ] T040 [US2] Implement post-sign-in permission-request rationale UI in `rideshare/lib/screens/auth/notification_rationale_screen.dart` (or as a dialog from `AuthBloc` listener in `main.dart`); shown once per account per device
- [ ] T041 [US2] Implement `NotificationRouter` at `rideshare/lib/core/services/notification_router.dart` that parses notification `data` payloads `{type, screen, entityId}` and navigates via `rideshare/lib/main.dart` route table for foreground + background + cold-start paths
- [ ] T042 [US2] Add a settings row "Notifications" in `rideshare/lib/screens/settings/settings_screen.dart` that deep-links to OS notification settings (and surfaces current grant state)
- [X] T043 [P] [US2] Add Arabic localization keys for notification titles/bodies (`notifications.booking_created.title` & `.body`, `.booking_confirmed.*`, `.booking_rejected.*`, `.booking_canceled.*`, `.new_trip_posted.*`) to `rideshare/lib/l10n/app_ar.arb`
- [X] T044 [P] [US2] Add matching English localization keys to `rideshare/lib/l10n/app_en.arb`
- [ ] T045 [US2] Add a small UI for the user to pick/update their profile `city` in `rideshare/lib/screens/settings/settings_screen.dart` or existing profile-edit screen (PATCH /users/me with `city`)

**Checkpoint**: US1 and US2 should both work independently.

---

## Phase 5: User Story 3 — Real road route on the trip map (Priority: P3)

**Goal**: the passenger trip map shows a polyline that follows the real road network (not a straight line). Start/end markers present, camera framed to the full route. Routing failures surface via the US1 error layer with markers still visible.

**Independent Test**: follow the US3 section in `quickstart.md` (real polyline on urban short trip, camera framing, routing failure UX, refresh on origin/destination change).

### Tests for User Story 3

- [X] T046 [P] [US3] Write failing unit test for `RouteService.fetchRoute` in `rideshare/test/core/services/route_service_test.dart` covering polyline decode table, bounds computation, and HTTP failure mapping to `Failure` via `ExceptionMapper`

### Implementation for User Story 3

- [X] T047 [US3] Create `RouteService` exposing `Future<RouteResult> fetchRoute({required LatLng origin, required LatLng destination})` plus the `RouteResult` sealed type (`RouteOk`, `RouteUnavailable`) and a `BoundsLatLng` helper in `rideshare/lib/core/services/route_service.dart` — move the Directions HTTP call and `_decodePolyline` out of `TripRouteMapScreen` into this file (drives T046 to green)
- [X] T048 [US3] Refactor `rideshare/lib/screens/trip_route_map_screen.dart` to consume `RouteService`; delete the inline `http.get` call and delete the silent dashed-straight-line fallback branch
- [X] T049 [US3] In `trip_route_map_screen.dart`, when `RouteResult` is `RouteUnavailable`, render only origin/destination markers and call `showFailure(context, failure)` from US1 (spec FR-018 & FR-020)
- [X] T050 [US3] Grep `rideshare/lib/**/*.dart` for other `Polyline(` usages drawing origin→destination; route each through `RouteService` so the app has a single source of truth for trip polylines
- [X] T051 [P] [US3] Add Arabic localization key `errors.route.unavailable` (e.g., "تعذّر تحميل المسار. نعرض نقاط الانطلاق والوصول.") to `rideshare/lib/l10n/app_ar.arb`
- [X] T052 [P] [US3] Add matching English localization key to `rideshare/lib/l10n/app_en.arb`

**Checkpoint**: all user stories now independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: repo-wide quality gates, cross-surface regressions, and acceptance validation.

- [ ] T053 [P] Run `npm run lint` in `rideshare-backend/` and fix findings
- [ ] T054 [P] Run `flutter analyze` in `rideshare/` and fix findings
- [ ] T055 [P] Run `npm test` in `rideshare-backend/` and ensure all contract + service tests green
- [ ] T056 [P] Run `flutter test` in `rideshare/` and ensure US1 mapper + error_surface + US3 route_service tests green
- [ ] T057 [P] Grep `rideshare-dashboard/src/` for user-profile response shapes and regression-check that `users.city` appearing in admin serializers is handled (display-only is fine; crash-on-null is not)
- [ ] T058 [P] Add an automated assertion (test or lint grep) that no response body shape exposes `fcmToken` or a field literally named `token`, in `rideshare-backend/test/security/no-token-leak.spec.ts`
- [ ] T059 Execute the manual quickstart checklist in `specs/007-app-ux-improvements/quickstart.md` on a real Android device end-to-end; record results in the PR description
- [ ] T060 Execute the same quickstart on a real iOS device end-to-end (requires APNs credentials provisioned); clarification #1 makes this a blocker for feature acceptance
- [ ] T061 Update `rideshare-backend/README.md` with a short "Notifications" section pointing at `specs/007-app-ux-improvements/spec.md`
- [ ] T062 Update `rideshare/README.md` (or wherever client-side feature docs live) with a short "Errors & Notifications & Routes" section pointing at the same spec

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately.
- **Foundational (Phase 2)**: empty; no blockers.
- **User Stories (Phase 3+)**: all start after Phase 1.
  - US1, US2, US3 are independent and can proceed in parallel with separate developers.
  - **Soft cross-cutting dependency** (spec FR-020): US2 and US3 surface their failures via US1's `error_surface.showFailure(...)`. If US1 is not yet landed, US2/US3 developers can temporarily surface errors via local snackbars and swap to `showFailure` when US1 lands — this was accounted for by keeping the stories otherwise independent.
- **Polish (Phase 6)**: depends on the stories that are being released.

### User Story Dependencies

- **US1 (P1)**: no dependency on other stories. MVP shipable on its own.
- **US2 (P2)**: no hard dependency on US1 (see soft note above). Backend tasks (T021–T037) and Flutter tasks (T038–T045) are mostly parallelizable across a backend dev and a mobile dev.
- **US3 (P3)**: no hard dependency on US1 (soft only). A self-contained Flutter-only workstream.

### Within Each User Story

- Tests MUST be written (and failing) before the implementation task they cover.
- Backend: migrations & entity changes before service/controller changes; service before controller; controller before DTO-exclusion audit.
- Flutter: value types (enums, `Failure`, `AppException`) before the mapper; mapper before the `error_surface`; `error_surface` before BLoC/screen refactors.
- US2 Backend: device-token upsert before triggers (the trigger code assumes tokens exist); the city fan-out worker can be built in parallel with per-user triggers.

### Parallel Opportunities (selected)

- All tasks marked `[P]` within the same phase can run in parallel.
- US1 tests T003 and T004 can be written in parallel with value-type tasks T005/T006 (different files).
- US2 backend tests T017/T018/T019/T020 can be written in parallel (different files).
- US2 backend trigger implementations T031/T032/T033 are same-file and therefore NOT parallel with each other; each is parallel with device-endpoint work on the controller side.
- US2 Flutter tasks T038/T039 (service extension, sign-out hook) are parallel with backend work on a separate dev.
- US3 tests T046 are parallel with US1 and US2.
- Phase 6 lint/test/grep tasks (T053–T058) are parallel across the repo.

---

## Parallel Example: User Story 1 (P1 / MVP)

```bash
# Kick off the US1 tests and value types in one parallel batch:
Task: "Write failing unit test table for ExceptionMapper in rideshare/test/core/errors/exception_mapper_test.dart"          # T003
Task: "Write failing widget test for showFailure in rideshare/test/core/ui/error_surface_test.dart"                       # T004
Task: "Create Failure class + enums in rideshare/lib/core/errors/failure.dart"                                             # T005
Task: "Create AppException hierarchy in rideshare/lib/core/errors/app_exception.dart"                                     # T006
Task: "Add Arabic failure-category keys to rideshare/lib/l10n/app_ar.arb"                                                 # T008
Task: "Add English failure-category keys to rideshare/lib/l10n/app_en.arb"                                                # T009

# Then the mapper + surface (sequentially), then bloc/screen integration (sequentially due to many touched files)
```

## Parallel Example: User Story 2 (P2) backend ramp-up

```bash
# All four contract/service tests can be written concurrently:
Task: "Failing contract test POST /notifications/devices"      # T017
Task: "Failing contract test PATCH /users/me city"             # T018
Task: "Failing service test city fan-out"                      # T019
Task: "Failing service test booking triggers"                  # T020
Task: "Create RegisterDeviceDto"                                # T024
```

---

## Implementation Strategy

### MVP first (US1 only)

1. Phase 1 (T001–T002)
2. Phase 3 (all of US1, T003–T016)
3. **STOP and VALIDATE**: execute the US1 section of `quickstart.md`
4. Deploy as MVP if ready — delivers an immediate UX win across every screen

### Incremental delivery

1. Setup → US1 validated → **ship MVP**
2. US2 backend + Flutter → validate with `quickstart.md` US2 section → **ship**
3. US3 → validate with `quickstart.md` US3 section → **ship**
4. Polish (Phase 6) layered in throughout and finalized before the final story ship

### Parallel team strategy

- Backend dev: T001 (setup), then US2 backend block (T021–T037) once US1 decisions on audit sink are settled.
- Mobile dev A: US1 full (T003–T016), then US3 (T046–T052).
- Mobile dev B: US2 Flutter block (T038–T045) while dev A is on US3.
- QA: writes/executes `quickstart.md` sections per story as each story completes.

---

## Notes

- `[P]` tasks = different files, no dependencies on incomplete tasks in the same phase.
- `[Story]` labels (`[US1]`, `[US2]`, `[US3]`) trace every implementation task back to its source story in `spec.md`.
- Every test task MUST be confirmed failing before its paired implementation task proceeds (constitution Principle II).
- Commit after each task or logical group; respect the constitution's Governance rule that destructive migrations require an explicit rollback plan in the PR (T022 is additive-nullable, so no special rollback needed).
- Avoid cross-story file conflicts: if a screen touched in T015 also needs edits for US2 T041 deep-linking, coordinate the two PRs or sequence them.
