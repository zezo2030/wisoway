# Tasks: Platform Refinements (Localization, Admin Alerts & Trip-Creation UX)

**Input**: Design documents from `specs/009-platform-refinements/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: INCLUDED â€” the constitution's Principle II (Test-First, NON-NEGOTIABLE) and the plan's Constitution Check require a contract test for every new endpoint and unit/integration tests for new behavior, written red-green before implementation.

**Organization**: Tasks are grouped by user story (priority order) so each story is an independently testable increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: US1â€“US5 (maps to spec.md user stories)
- All paths are absolute-from-repo-root: `rideshare-backend/` (NestJS), `rideshare/` (Flutter), `rideshare-dashboard/` (React).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add the few new dependencies and env scaffolding the feature needs.

- [X] T001 [P] Add `@googlemaps/google-maps-services-js` to `rideshare-backend/package.json` and install (server-side Places proxy â€” research R2).
- [X] T002 [P] Add `firebase` JS SDK to `rideshare-dashboard/package.json` and install (FCM Web â€” research R1).
- [X] T003 [P] Add `GOOGLE_PLACES_API_KEY` to `rideshare-backend/.env.example` and document that the existing Firebase Admin creds are reused for web push (do NOT commit real keys â€” constitution IV).
- [X] T004 [P] Add `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_MESSAGING_SENDER_ID`, `VITE_FIREBASE_APP_ID`, `VITE_FIREBASE_VAPID_KEY` to `rideshare-dashboard/.env.example`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Backend must boot with the new optional configuration. This is the only cross-cutting prerequisite; the five stories are otherwise independent.

**âš ï¸ CRITICAL**: Complete before US2/US4 (which read the new env). US1 (mobile-only) and US5 do not depend on this.

- [X] T005 Update backend config/env validation to register `GOOGLE_PLACES_API_KEY` and the Firebase web sender as optional config in `rideshare-backend/src/config/` (or the existing config-validation module), so missing values fail fast with a clear message rather than at first request.

**Checkpoint**: Foundation ready â€” user stories can proceed (in parallel if staffed).

---

## Phase 3: User Story 1 â€” Approved driver creates a trip without restarting the app (Priority: P1) ðŸŽ¯ MVP

**Goal**: A freshly-approved driver can create a trip without killing/relaunching the app; a revoked driver is re-blocked.

**Independent Test**: Approve a pending driver from the dashboard while their app is open; on foreground/return to the create-trip flow (no restart) trip creation is allowed; revoke â†’ re-blocked.

**Note**: Mobile-only â€” no backend change (`GET /users/me` already returns `isDriverApproved`). Does not depend on Phase 2.

### Tests for User Story 1 âš ï¸ (write first, must FAIL)

- [X] T006 [P] [US1] Unit test: `AuthProvider.loadUserProfile()` refreshes `isDriverApproved` from `/users/me` and notifies listeners, in `rideshare/test/providers/auth_provider_refresh_test.dart`.
- [X] T007 [P] [US1] Widget test: create-trip gate transitions pendingâ†’approved after a profile refresh without app restart, and re-blocks on revoked, in `rideshare/test/screens/create_trip_gate_test.dart`.

### Implementation for User Story 1

- [X] T008 [US1] Add a `WidgetsBindingObserver` that calls `AuthProvider.loadUserProfile()` on `AppLifecycleState.resumed` in the `AuthWrapper` in `rideshare/lib/main.dart` (lines ~350â€“379).
- [X] T009 [US1] In `rideshare/lib/providers/auth_provider.dart`, make `loadUserProfile()` safe to call repeatedly (concurrency guard, error-tolerant) and expose a refresh-in-progress flag.
- [X] T010 [US1] In `rideshare/lib/screens/driver/create_trip_screen.dart` (gate at ~line 329), await a profile refresh before evaluating `user.canCreateTrips`; show a brief loading state; keep the "Account Under Review" dialog for the still-pending case and surface re-block on revoked.
- [X] T011 [US1] Ensure the gate's approved/pending/revoked messages use existing `context.l10n` keys (add any missing keys to `rideshare/lib/l10n/app_en.arb` & `app_ar.arb`).

**Checkpoint**: US1 fully functional and demoable as the MVP.

---

## Phase 4: User Story 2 â€” Live origin/destination suggestions (Priority: P1)

**Goal**: Typing in From/To shows live, ranked, language/region-aware place suggestions; selecting one captures coordinates; graceful no-results/offline fallback.

**Independent Test**: Type â‰¥2 chars in From/To â†’ suggestions appear <~1s and refine per keystroke; tap one â†’ field + coordinates set; offline â†’ falls back to map picker without crashing.

### Tests for User Story 2 âš ï¸ (write first, must FAIL)

- [X] T012 [P] [US2] Contract test for `GET /locations/autocomplete` (401 unauth; `q`<2 â†’ empty 200; valid â†’ suggestion shape; provider error â†’ 502, no key leak) in `rideshare-backend/test/contract/locations-autocomplete.contract.spec.ts`.
- [X] T013 [P] [US2] Contract test for `GET /locations/place/:id` (401; valid placeId â†’ `{placeId,label,lat,lng}`; unknown â†’ 404) in `rideshare-backend/test/contract/locations-place.contract.spec.ts`.

### Implementation for User Story 2

- [X] T014 [P] [US2] Add request/response DTOs (autocomplete query, suggestion, place detail) in `rideshare-backend/src/modules/locations/dto/`.
- [X] T015 [US2] Implement Places client in `rideshare-backend/src/modules/locations/locations.service.ts`: autocomplete + place-detail with session token, `lang`, region bias, optional lat/lng bias, short-TTL cache, per-user rate limit, and no query text in general logs (constitution IV).
- [X] T016 [US2] Add `GET /locations/autocomplete` and `GET /locations/place/:id` (JWT-guarded; 502 on provider failure) in `rideshare-backend/src/modules/locations/locations.controller.ts`; register provider deps in `locations.module.ts`.
- [X] T017 [P] [US2] Add the two endpoints to `rideshare/lib/core/api/api_endpoints.dart`.
- [X] T018 [US2] Add `autocomplete(query, lang, sessionToken)` and `placeDetail(placeId, sessionToken)` calls in `rideshare/lib/core/services/location_service.dart`.
- [X] T019 [US2] Create `rideshare/lib/widgets/location_autocomplete_field.dart`: debounced (~250â€“300ms) input, â‰¥2-char trigger, ranked suggestion list, no-results state, and offline/error fallback to the existing `LocationPickerWidget`.
- [X] T020 [US2] Replace the read-only From/To fields with the autocomplete field in `rideshare/lib/screens/driver/create_trip_screen.dart` (and the passenger trip-search screen), capturing the selected place's coordinates into the existing trip/search payload.
- [X] T021 [P] [US2] Add suggestion/no-results l10n keys to `rideshare/lib/l10n/app_en.arb` & `app_ar.arb`.

**Checkpoint**: US1 + US2 both work independently.

---

## Phase 5: User Story 3 â€” Automatic seat layout from vehicle type (Priority: P2)

**Goal**: Selecting a vehicle type auto-applies its seat-layout template (editable for irregular layouts); changing the type replaces it; offered seats match the stored layout.

**Independent Test**: Pick each vehicle type â†’ layout auto-fills; change type â†’ layout replaces; `GET /vehicles/types` returns every type with a non-empty layout; created trip's bookable seats match.

### Tests for User Story 3 âš ï¸ (write first, must FAIL)

- [X] T022 [P] [US3] Contract test for `GET /vehicles/types` (401; returns full supported set; each entry has `type`, `label.en/ar`, `seats`, non-empty `layout`; `seats` matches `layout`) in `rideshare-backend/test/contract/vehicle-types.contract.spec.ts`.
- [X] T023 [P] [US3] Unit test: catalog resolver returns the right template per type and falls back + flags for an unknown type, in `rideshare-backend/test/unit/vehicle-types.resolver.spec.ts`.

### Implementation for User Story 3

- [X] T024 [P] [US3] Create the canonical catalog `rideshare-backend/src/modules/vehicles/vehicle-types.ts` (sedan/suv/van/truck/bus/motorcycle â†’ `{label{en,ar}, seats, layout}`) using the existing `SeatLayout` shape.
- [X] T025 [US3] Add `GET /vehicles/types` (cacheable, JWT) in `rideshare-backend/src/modules/vehicles/vehicles.controller.ts`.
- [X] T026 [US3] Use the catalog as the fallback in `resolveVehicleSeatLayout()` / `rideshare-backend/src/modules/vehicles/vehicles.service.ts` when a vehicle has no explicit layout, logging a flag when a type lacks a template (FR-012).
- [X] T027 [P] [US3] Add `/vehicles/types` to `rideshare/lib/core/api/api_endpoints.dart` and fetch+cache it (local mirror for offline prefill) in `rideshare/lib/core/services/vehicle_service.dart`.
- [X] T028 [US3] In `rideshare/lib/screens/driver/vehicle_settings_screen.dart`, auto-apply the template's `SeatLayoutConfig` when the vehicle type is selected and replace it when the type changes, preserving the existing custom-layout editing path.
- [X] T029 [US3] Ensure the seating-summary card in `rideshare/lib/screens/driver/create_trip_screen.dart` reflects the auto-derived layout consistently (read-only).

**Checkpoint**: US1 + US2 + US3 independently functional.

---

## Phase 6: User Story 4 â€” Admin web-push alerts for driver registration & payments (Priority: P2)

**Goal**: Subscribed admins receive dashboard web-push on driver registration and successful in-app fee payments, deep-linking to `/users/:id` and `/payments`; preferences honored; non-fee money movements excluded; in-app copy as fallback.

**Independent Test**: Register a web token; create a driver â†’ admin gets a web push opening `/users/:id`; successful fee payment â†’ push opening `/payments`; wallet top-up/refund â†’ no push; disable a type â†’ suppressed; no token â†’ in-app copy still written.

### Tests for User Story 4 âš ï¸ (write first, must FAIL)

- [X] T030 [P] [US4] Contract test for `POST` & `DELETE /notifications/web-token` (401; idempotent upsert; delete) in `rideshare-backend/test/contract/web-token.contract.spec.ts`.
- [X] T031 [P] [US4] Contract test for `GET` & `PATCH /admin/alert-preferences` (403 non-admin; default enabled; PATCH then GET reflects) in `rideshare-backend/test/contract/alert-preferences.contract.spec.ts`.
- [X] T032 [P] [US4] Integration test: driver registration enqueues `driver_registration` to opted-in admins only; communication-fee payment enqueues `fee_payment`; wallet top-up/refund does NOT; disabled pref suppresses; no web token â†’ `notifications` in-app copy written, in `rideshare-backend/test/integration/admin-alerts.spec.ts`.

### Implementation for User Story 4 (backend)

- [X] T033 [US4] Additive migration: allow `platform='web'` and add nullable `userAgent` on `device_tokens` in `rideshare-backend/src/database/migrations/` (update `device-token.entity.ts`).
- [X] T034 [US4] Create `admin_alert_preference` entity + additive migration (unique `(userId, alertType)`, default enabled) in `rideshare-backend/src/database/entities/admin-alert-preference.entity.ts` and `migrations/`.
- [X] T035 [US4] Extend `sendPush` in `rideshare-backend/src/modules/notifications/notifications.service.ts` to target `platform='web'` tokens via `admin.messaging()` with a `data.link` deep-link and web-appropriate payload.
- [X] T036 [US4] Add `POST`/`DELETE /notifications/web-token` in `rideshare-backend/src/modules/notifications/notifications.controller.ts` (+ service upsert/delete; only admin/operator web tokens are targeted by alerts).
- [X] T037 [US4] Add `GET`/`PATCH /admin/alert-preferences` in `rideshare-backend/src/modules/admin/admin.controller.ts` (+ service; default-enabled semantics).
- [X] T038 [US4] Create `rideshare-backend/src/modules/admin/admin-alerts.service.ts`: fire `driver_registration` from the driver registration/approval flow hook and `fee_payment` from the Cliq success path in `rideshare-backend/src/modules/payments/processors/cliq-poll.processor.ts` for `paymentType=communication_fee`; resolve recipients by role + enabled preference; write the `notifications` in-app fallback; emit structured logs (alertType, recipientCount, delivered/failed) per constitution III; exclude penalties/top-ups/refunds.

### Implementation for User Story 4 (dashboard)

- [X] T039 [P] [US4] Create `rideshare-dashboard/public/firebase-messaging-sw.js`: background message handler + `notificationclick` navigating to `data.link` (`/users/:id` or `/payments`).
- [X] T040 [US4] Create `rideshare-dashboard/src/lib/firebase.ts`: init from `VITE_FIREBASE_*`, `getToken({ vapidKey })`, and `onMessage` foreground handler (surface via existing toast/bell).
- [X] T041 [US4] Add `registerWebPushToken`/`unregisterWebPushToken` to `rideshare-dashboard/src/api/admin.ts`, request notification permission, and register/unregister on login/logout (wire in `src/providers/notifications-socket-provider.tsx` or `src/components/layout/app-layout.tsx`).
- [X] T042 [US4] Add an alert-preferences UI (toggle per type) calling `GET`/`PATCH /admin/alert-preferences` in the dashboard settings/notifications page (`rideshare-dashboard/src/pages/notifications/notifications.tsx` or a settings page) + api in `src/api/admin.ts`.
- [X] T043 [P] [US4] Add alert/preferences i18n keys (en + ar) to `rideshare-dashboard/src/i18n/translations.ts`.

**Checkpoint**: US1â€“US4 independently functional.

---

## Phase 7: User Story 5 â€” Complete & correct AR/EN translations across app + dashboard (Priority: P3)

**Goal**: Zero untranslated strings / raw keys / wrong-language fallbacks / RTL defects across both clients, with a guard preventing future drift.

**Independent Test**: Walk every primary mobile flow and dashboard screen in AR and EN â€” no defects; parity guards pass.

### Guards for User Story 5 âš ï¸ (add first, must FAIL on current gaps)

- [X] T044 [P] [US5] Enable gen-l10n untranslated-messages report and add a key-parity check (`app_en.arb` vs `app_ar.arb`) script in `rideshare/` (e.g. `rideshare/tool/check_i18n_parity.dart` + l10n.yaml `untranslated-messages-file`).
- [X] T045 [P] [US5] Create `rideshare-dashboard/src/scripts/check-i18n-parity.ts` (assert `en`/`ar` key sets identical, no empty values) and add `check:i18n` script to `rideshare-dashboard/package.json`.

### Implementation for User Story 5

- [X] T046 [US5] Fill missing/empty AR/EN entries surfaced by the walkthrough + T044 report in `rideshare/lib/l10n/app_en.arb` & `app_ar.arb` (regenerate `app_localizations*`).
- [X] T047 [US5] Replace any remaining hardcoded user-facing strings in mobile with `context.l10n` keys (review screens/widgets flagged during the sweep).
- [X] T048 [US5] Fill missing keys / fix wrong-language values surfaced by T045 in `rideshare-dashboard/src/i18n/translations.ts`.
- [X] T049 [US5] Verify RTL/LTR across all primary mobile and dashboard screens; fix any directional layout defects found.

**Checkpoint**: All five stories independently functional.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T050 [P] Verify structured-log/observability coverage for the alert fan-out (constitution III) and add any missing log assertions.
- [X] T051 [P] Wire the i18n parity guards (T044/T045) into the build/CI gates (mobile analyze step + dashboard build).
- [X] T052 Run the `quickstart.md` verification for all five stories end-to-end.
- [X] T053 [P] Reconcile any contract drift discovered during implementation back into `specs/009-platform-refinements/contracts/`.
- [X] T054 Run full gates: `rideshare-backend` `npm test` + `npm run lint`; `rideshare` `flutter analyze` + `flutter test`; `rideshare-dashboard` `npm run build` + `npm run check:i18n`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2 / T005)**: after Setup; blocks US2 & US4 (which read new env). US1 and US5 do not depend on it.
- **User Stories (Phase 3â€“7)**: after Foundational (US2/US4) â€” US1/US5 may start right after Setup. Stories are otherwise independent and can run in parallel.
- **Polish (Phase 8)**: after the targeted stories are complete.

### User Story Dependencies

- **US1 (P1)**: independent, mobile-only â€” start immediately after Setup. **MVP.**
- **US2 (P1)**: needs T005 (env) â€” independent of other stories.
- **US3 (P2)**: independent.
- **US4 (P2)**: needs T005 (env) â€” independent of other stories.
- **US5 (P3)**: independent; best done last so it sweeps strings added by US1â€“US4.

### Within Each Story

- Tests/guards written and FAILING before implementation (constitution II).
- Backend: DTOs/entities â†’ service â†’ controller â†’ migration run.
- Mobile: endpoints â†’ service â†’ widget â†’ screen wiring.
- Backend change paired with its client change in the same story (constitution V).

### Parallel Opportunities

- Setup T001â€“T004 all [P].
- Once Foundational is done, US1/US2/US3/US4 can be staffed in parallel.
- Within a story, [P] tasks touch different files (e.g., backend contract tests T012/T013; dashboard SW T039 vs backend services).

---

## Parallel Example: User Story 2

```bash
# Contract tests first (parallel, must fail):
Task: "Contract test GET /locations/autocomplete in rideshare-backend/test/contract/locations-autocomplete.contract.spec.ts"
Task: "Contract test GET /locations/place/:id in rideshare-backend/test/contract/locations-place.contract.spec.ts"

# Then backend DTOs + mobile endpoints in parallel (different files):
Task: "Add DTOs in rideshare-backend/src/modules/locations/dto/"
Task: "Add endpoints in rideshare/lib/core/api/api_endpoints.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 Setup â†’ 2. (US1 needs no Foundational) â†’ 3. Phase 3 US1 â†’ **STOP & validate** the approved-driver fix â†’ demo. Highest-impact, lowest-risk, ships alone.

### Incremental Delivery

Setup â†’ US1 (MVP) â†’ US2 (suggestions) â†’ US3 (seat layout) â†’ US4 (admin alerts) â†’ US5 (i18n sweep). Each story is independently testable and deployable.

### Parallel Team Strategy

After Setup + T005: Dev A â†’ US1+US2 (mobile-heavy), Dev B â†’ US3 (vehicles), Dev C â†’ US4 (backend+dashboard alerts). US5 done collaboratively last to capture all new strings.

---

## Notes

- [P] = different files, no incomplete-task dependency.
- Every new endpoint has a contract test authored red-green first (constitution II).
- Migrations are additive-safe (nullable add / new table) â€” constitution Migrations rule.
- No secrets committed; Google key stays server-side; web push uses env-configured Firebase (constitution IV).
- Commit after each task or logical group; stop at any checkpoint to validate a story independently.
