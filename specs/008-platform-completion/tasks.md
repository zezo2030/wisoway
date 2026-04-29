---
description: "Task list for Platform Completion (Spec-vs-Code Gap Closure)"
---

# Tasks: Platform Completion (Spec-vs-Code Gap Closure)

**Input**: Design documents from `/specs/008-platform-completion/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md
**Tests**: Included — Constitution II ("Test-First Discipline") requires contract + integration tests for every new HTTP endpoint and time-driven flow.

**Organization**: Tasks are grouped by user story. Each phase corresponds to one of the six branches in plan.md (`009-auth-hardening` … `014-admin-and-support`) and is independently mergeable to `main`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Parallelizable (different files, no dependencies on incomplete tasks)
- **[Story]**: Maps to user stories from spec.md (`US1`–`US6`)
- File paths are absolute under the monorepo (`rideshare-backend/`, `rideshare/`, `rideshare-dashboard/`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Tooling and config touches needed before any branch lands. The monorepo already exists; nothing here creates new top-level dirs.

- [X] T001 Verify the monorepo bootstraps cleanly on a fresh checkout per `specs/008-platform-completion/quickstart.md` Prerequisites section: `docker compose up postgres redis`, `rideshare-backend` migrate+start, `rideshare` flutter pub get, `rideshare-dashboard` npm ci+dev. Document any drift in `specs/008-platform-completion/quickstart.md`.
- [X] T002 [P] Add env-flag scaffolding for time-window overrides used by quickstart and integration tests in `rideshare-backend/src/config/configuration.ts`: `BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS`, `NO_SHOW_GRACE_OVERRIDE_SECONDS`, `PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS`, `OTP_DEV_BYPASS`, `SETTLEMENT_GRACE_SECONDS` (default 300). Read once at boot, exposed via a typed config service.
- [X] T003 [P] Confirm BullMQ queue registry conventions in `rideshare-backend/src/jobs/jobs.module.ts`: register placeholder names `bookings-timeout`, `no-show-detector`, `pre-trip-confirm`, `recurrence-spawn`, `pending-charge-collect` so each subsequent phase can attach its processor without churning the module.
- [X] T004 [P] Add a shared error-code constants file `rideshare-backend/src/common/errors/error-codes.ts` enumerating the new codes used across phases: `LOCATION_INTEGRITY_VIOLATION`, `ACCOUNT_BANNED`, `ACCOUNT_RESTRICTED`, `PROFILE_PHOTO_REQUIRED`, `DRIVER_REQUIRES_APPROVAL`, `SEATS_TAKEN`, `GENDER_ADJACENCY_VIOLATION`, `NO_VALID_ARRANGEMENT`, `CANCELLATION_WINDOW_CLOSED`, `ALREADY_DECIDED`, `NOT_TRIP_DRIVER`, `ALREADY_SETTLED`, `BOOKING_NOT_CONFIRMED`, `BOOKING_NOT_SETTLED`, `GRACE_EXPIRED`, `CONTACT_ALREADY_USED`, `NO_PROXY_NUMBERS_AVAILABLE`, `TIMING_WINDOW`, `SELF_REVOKE_USE_LOGOUT`.
- [X] T005 [P] Add new ARB i18n keys placeholders in `rideshare/lib/l10n/app_ar.arb` and `rideshare/lib/l10n/app_en.arb` for the strings the six branches will populate (ban screen, masked-phone label, "trip ended" share-link state, no-show notification body, pending-charge banner, etc.). Keep AR copy authoritative.
- [X] T006 [P] Add new dashboard i18n key placeholders in `rideshare-dashboard/src/i18n/ar.json` and `rideshare-dashboard/src/i18n/en.json` for new admin pages (account flags, complaints, refunds, pending charges).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema and middleware touches used by ≥2 user stories. Must complete before US1+ work begins.

**⚠️ CRITICAL**: User Story phases MUST NOT begin until Phase 2 is complete.

- [X] T007 Add `bannedAt`, `banReason`, `restricted`, `hidePhoneNumber`, `pendingPhoneLink`, `lastSocialLoginAt` columns to `User` entity in `rideshare-backend/src/database/entities/user.entity.ts` per data-model.md "User (`users`) — extended".
- [X] T008 Create migration `rideshare-backend/src/database/migrations/008.00-foundation__user-extensions.ts` adding the six User columns above; backfill `restricted=false`, `hidePhoneNumber=false`, set `pendingPhoneLink=true` for users that have a non-null social-login provider but no `phoneNumber`.
- [X] T009 [P] Implement `BanGuard` in `rideshare-backend/src/common/guards/ban.guard.ts` that blocks any authenticated request from a `bannedAt IS NOT NULL` user with `403 ACCOUNT_BANNED` and body `{ banReason, supportWhatsApp }` per `admin-support.contract.md` "Server-side ban gate". Wire it as a global guard in `app.module.ts` after the JWT guard.
- [X] T010 [P] Implement `RestrictedAccountInterceptor` in `rideshare-backend/src/common/interceptors/restricted.interceptor.ts` that returns `423 ACCOUNT_RESTRICTED` for write endpoints when the requesting user has `restricted=true`. Read-only endpoints pass through.
- [X] T011 [P] Add a typed `BookingViewerSerializer` helper in `rideshare-backend/src/modules/bookings/serializers/booking-viewer.serializer.ts` (skeleton, returns the data unmodified for now) — Phase 7 (US5) will fill it in. Existing booking responses are routed through this helper now so the cutover in US5 is a one-spot edit.
- [X] T012 [P] Update `rideshare-backend/src/database/scripts/clear-postgres.ts` to also truncate the new tables that will be added across the six migrations (`user_devices`, `account_flags`, `security_events`, `booking_seats`, `pending_charges`, `trip_recurrence_rules`, `trip_share_links`, `call_sessions`, `complaints`, `refund_requests`, `settlement_audits`).

**Checkpoint**: Foundation ready — User Story implementation can begin.

---

## Phase 3: User Story 1 — Phone-only sign-in, mandatory driver photo, account-safety guardrails (Priority: P1) 🎯 MVP

**Goal**: Phone+OTP is the only end-user sign-in path. Devices are recorded, mocked locations are rejected, drivers without a profile photo cannot publish, and high-risk registrations are flagged.

**Independent Test**: Quickstart Stories 1.1–1.5 — register via phone+OTP only, get blocked if email/password is used, see the device list grow, see a `403` on a mocked-location update, get blocked from publishing without a driver photo, and after 4 same-device registrations see a `multi_account_device` admin flag.

**Branch**: `009-auth-hardening`. **Requirements**: FR-001..FR-009, SC-001, SC-002, SC-010.

### Tests for User Story 1 (write FIRST; ensure they fail before implementation)

- [X] T013 [P] [US1] Contract test for `POST /auth/verify-otp` happy + new-device + restricted + banned + pending-phone-link branches in `rideshare-backend/test/contract/auth/verify-otp.contract.spec.ts`.
- [X] T014 [P] [US1] Contract test for `POST/GET/DELETE /auth/devices` and self-revoke 409 in `rideshare-backend/test/contract/auth/devices.contract.spec.ts`.
- [X] T015 [P] [US1] Contract test asserting `POST /auth/register`, `POST /auth/login`, `GET /auth/google*`, `GET /auth/facebook*` all return 410 Gone with the documented body in `rideshare-backend/test/contract/auth/removed-paths.contract.spec.ts`.
- [X] T016 [P] [US1] Contract test for `GET /admin/account-flags`, clear, and escalate in `rideshare-backend/test/contract/auth/account-flags.contract.spec.ts`.
- [X] T017 [P] [US1] Integration test for mocked-location rejection on `POST /tracking/location` and `POST /trips/:id/start` in `rideshare-backend/test/integration/mock-location-rejection.integration.spec.ts`.
- [X] T018 [P] [US1] Integration test for the multi-account-from-one-device threshold flag in `rideshare-backend/test/integration/multi-account-device-flag.integration.spec.ts`.
- [X] T019 [P] [US1] Unit test for the device-fingerprint hashing helper in `rideshare-backend/test/unit/device-fingerprint.spec.ts`.
- [X] T020 [P] [US1] Flutter widget test for the phone-only auth screen (no email field, no social buttons) in `rideshare/test/widget/auth/phone_only_screen_test.dart`.

### Implementation for User Story 1

- [X] T021 [P] [US1] Create `UserDevice` entity in `rideshare-backend/src/database/entities/user-device.entity.ts` per data-model.md schema.
- [X] T022 [P] [US1] Create `AccountFlag` entity in `rideshare-backend/src/database/entities/account-flag.entity.ts`.
- [X] T023 [P] [US1] Create `SecurityEvent` entity (append-only) in `rideshare-backend/src/database/entities/security-event.entity.ts`.
- [X] T024 [US1] Migration `008.01-auth-hardening__create-user-devices-flags-events.ts` in `rideshare-backend/src/database/migrations/`: create `user_devices` (with FCM-token migration from existing `device_tokens`), `account_flags`, `security_events`, all indexes from data-model.md "Index summary".
- [X] T025 [P] [US1] Implement device-fingerprint hashing helper in `rideshare-backend/src/modules/auth/device-fingerprint.service.ts` (SHA-256 of `platform:deviceId:installSalt`, install-salt issuance/refresh) per research.md R-004.
- [X] T026 [US1] Extend `verify-otp` controller and service in `rideshare-backend/src/modules/auth/auth.controller.ts` and `auth.service.ts` to accept the new `device` block, register/refresh `UserDevice`, return `deviceState` and `accountState`, and write a `security_events` row of type `new_device_login` plus a push notification to all other trusted devices for that user (FR-003, FR-004).
- [X] T027 [US1] Add multi-account-from-device heuristic in `rideshare-backend/src/modules/auth/account-risk.service.ts`: count `DISTINCT userId` per `fingerprintHash` over rolling 24h, threshold env-configured (default 3); on breach, set `users.restricted=true` and create an `account_flags` row with `reason='multi_account_device'`. Called from the verify-otp success path (FR-007).
- [X] T028 [US1] Repurpose `POST /auth/link-phone` for legacy social-login migration in `rideshare-backend/src/modules/auth/auth.controller.ts`: accept `phoneNumber+code` for sessions where `pendingPhoneLink=true`, merge or create the phone-only account, clear `pendingPhoneLink` (FR-001 social migration).
- [X] T029 [US1] Remove the email/password and OAuth controllers/methods (`/auth/register`, `/auth/login`, `/auth/google*`, `/auth/facebook*`) from `rideshare-backend/src/modules/auth/auth.controller.ts` (and their service methods); replace each with a small handler returning `410 Gone` with `{ message: "phone-only auth", supportWhatsApp }`.
- [X] T030 [P] [US1] Implement `POST /auth/devices`, `GET /auth/devices`, `DELETE /auth/devices/:deviceId` in a new `rideshare-backend/src/modules/auth/devices.controller.ts` per `auth.contract.md` "New endpoints"; reject self-revoke with `409 SELF_REVOKE_USE_LOGOUT`.
- [X] T031 [P] [US1] Implement `LocationGuardInterceptor` in `rideshare-backend/src/common/interceptors/location-guard.interceptor.ts` that intercepts driver-side endpoints carrying location, rejects `isMockLocation=true` with `403 LOCATION_INTEGRITY_VIOLATION`, writes a `security_events` row of type `mock_location_rejected`, and on the 3rd event in 30 days creates an `account_flags` row of severity `high` (FR-006, R-005).
- [X] T032 [US1] Wire `LocationGuardInterceptor` to `POST /tracking/location` (`rideshare-backend/src/modules/tracking/tracking.controller.ts`) and the `POST /trips/:id/start` body chain it will reach in Phase 5 (placeholder until US3 lands).
- [X] T033 [US1] Mandatory driver-photo guard: in `rideshare-backend/src/modules/users/users.service.ts`, refuse `markDriverApproved=true` and `submitDriverProfileForApproval()` when `users.photoUrl IS NULL`; in `rideshare-backend/src/modules/trips/trips.service.ts` `createTrip()`, refuse trip insert with `422 PROFILE_PHOTO_REQUIRED` when the driver lacks a photo (FR-008).
- [X] T034 [P] [US1] Admin endpoint `GET /admin/account-flags` with cursor pagination in `rideshare-backend/src/modules/admin/admin-flags.controller.ts`; uses index `(disposition, severity, createdAt)`.
- [X] T035 [P] [US1] Admin endpoint `POST /admin/account-flags/:id/clear` in same controller; sets `disposition='cleared'`, clears `users.restricted` if all of the user's flags are now cleared.
- [X] T036 [US1] Admin endpoint `POST /admin/account-flags/:id/escalate` in same controller; on `disposition='banned'`, sets `users.bannedAt`/`banReason` and triggers ban cascade (placeholder service call — full cascade lives in US6, but call site exists now).
- [X] T037 [P] [US1] Admin endpoint `POST /admin/users/:id/devices/:deviceId/revoke` in `rideshare-backend/src/modules/admin/admin.controller.ts`; sets `revokedAt`, `revokedByAdminId`.
- [X] T038 [P] [US1] Mobile: update `rideshare/lib/bloc/auth/auth_bloc.dart` and `auth_state.dart` to drop email/password and Google/Facebook events; add device-block on every `verify-otp` call sourced from `device_info_plus`.
- [X] T039 [P] [US1] Mobile: delete email/social auth screens; ensure `rideshare/lib/screens/auth/` has only phone+OTP flow. Update `rideshare/lib/core/api/api_endpoints.dart` accordingly.
- [X] T040 [P] [US1] Mobile: implement `device_binding_service.dart` and `location_spoof_guard.dart` in `rideshare/lib/core/services/`; the latter sets `isMockLocation` from `geolocator`'s `Position.isMocked` on every outbound location update.
- [X] T041 [P] [US1] Mobile: add a "Devices" screen under Account in `rideshare/lib/screens/auth/devices_screen.dart` listing `GET /auth/devices` and offering revoke per non-current device.
- [X] T042 [P] [US1] Mobile: render the `restricted` account-state banner; if `restricted=true`, disable destructive actions and show the explanatory text from i18n (Phase 1 placeholders).
- [X] T043 [P] [US1] Dashboard: build the Account Flags queue page at `rideshare-dashboard/src/pages/flags/AccountFlagsPage.tsx` listing open flags with clear/escalate actions; wire to the three admin endpoints above.
- [X] T044 [US1] Run quickstart Branch 1 stories 1.1–1.5; record PASS/FAIL inline in a section appended to `specs/008-platform-completion/quickstart.md`.

**Checkpoint**: User Story 1 deployable independently. Phone-only auth, devices, mocked-location rejection, mandatory driver photo, account flagging all work end-to-end.

---

## Phase 4: User Story 2 — Multi-seat bookings, request lifecycle, cancellation/no-show policy (Priority: P1)

**Goal**: Multi-seat bookings (self + companions) with auto-pick. Pending → 3h timeout. Cancellation windows (24h driver, 12h passenger). 5% / 10% pending charges with hybrid wallet-deduct-then-carry-forward collection. Driver no-show detection. Passenger no-show on completion.

**Independent Test**: Quickstart Branch 2 — book 2 seats in one request; observe auto-cancel after the 3h timeout; get blocked when cancelling within the 12h window; see a 5% `pending_charges` row carry forward to the next booking; observe driver-no-show 30 minutes after departure.

**Branch**: `010-booking-lifecycle`. **Requirements**: FR-020..FR-030, SC-003..SC-006. Depends on Phase 3 (uses `users.restricted`/`bannedAt` and the LocationGuardInterceptor).

### Tests for User Story 2

- [X] T045 [P] [US2] Contract test for `POST /v2/bookings` happy + adjacency violation + seats taken in `rideshare-backend/test/contract/bookings/create-multi-seat.contract.spec.ts`.
- [X] T046 [P] [US2] Contract test for concurrent multi-booker on same seats (race) returning 409 SEATS_TAKEN deterministically in `rideshare-backend/test/contract/bookings/create-conflict.contract.spec.ts`.
- [X] T047 [P] [US2] Contract test for `POST /v2/bookings/auto-pick` including `NO_VALID_ARRANGEMENT` in `rideshare-backend/test/contract/bookings/auto-pick.contract.spec.ts`.
- [X] T048 [P] [US2] Contract test for accept/reject (driver) and double-accept 409 in `rideshare-backend/test/contract/bookings/accept-reject.contract.spec.ts`.
- [X] T049 [P] [US2] Contract test for cancellation windows (24h driver / 12h passenger) returning `403 CANCELLATION_WINDOW_CLOSED` with `windowSeconds` in `rideshare-backend/test/contract/bookings/cancel-windows.contract.spec.ts`.
- [X] T050 [P] [US2] Contract test that `POST /v1/bookings` legacy single-seat shape still creates a v2 booking via the shim with one `BookingSeat` row in `rideshare-backend/test/contract/bookings/legacy-v1.contract.spec.ts`.
- [X] T051 [P] [US2] Integration test for the BullMQ 3h pending-booking timeout firing under `BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS` in `rideshare-backend/test/integration/booking-timeout.integration.spec.ts`.
- [X] T052 [P] [US2] Integration test for driver-no-show declaration at `departureTime + 30m` (override env) creating a `pending_charges` row of `kind='driver_no_show'` for 10% in `rideshare-backend/test/integration/driver-no-show.integration.spec.ts`.
- [X] T053 [P] [US2] Integration test for passenger-no-show declared at `complete-trip` with `noShowSeats` set, marking the booking and creating a 5% `pending_charges` row in `rideshare-backend/test/integration/passenger-no-show.integration.spec.ts`.
- [X] T054 [P] [US2] Integration test for hybrid charge collection — wallet-rich auto-deduct path AND wallet-empty carry-forward path on next booking confirmation in `rideshare-backend/test/integration/pending-charge-collection.integration.spec.ts`.
- [X] T055 [P] [US2] Unit test for the cancellation-policy helper (24h driver, 12h passenger) in `rideshare-backend/test/unit/cancellation-policy.spec.ts`.
- [X] T056 [P] [US2] Unit test for the gender-adjacency-with-companions helper across the *full* prospective seat set in `rideshare-backend/test/unit/gender-adjacency.spec.ts`.
- [X] T057 [P] [US2] Update `rideshare-backend/src/modules/bookings/bookings.service.spec.ts` for the multi-seat shape; existing single-seat assertions get rewritten.

### Implementation for User Story 2

- [X] T058 [P] [US2] Create `BookingSeat` entity in `rideshare-backend/src/database/entities/booking-seat.entity.ts` per data-model.md schema (incl. partial unique index for `isMainBooker=true`).
- [X] T059 [P] [US2] Create `PendingCharge` entity in `rideshare-backend/src/database/entities/pending-charge.entity.ts`.
- [X] T060 [US2] Migration `008.02-booking-lifecycle__create-booking-seats.ts`: create `booking_seats`, backfill from `bookings.seatNumber` (one row per existing booking, `isMainBooker=true`, `displayName=user.fullName`, `gender=user.gender`), drop `idx_bookings_user_trip`. Keep `bookings.seatNumber` column for one release as the v1-shim source.
- [X] T061 [US2] Migration `008.03-booking-lifecycle__add-booking-fields.ts`: add `bookings.seatCount`, `totalAmount`, `settledAt`, `settlementGraceUntil`, `passengerPresenceConfirmedAt`, `driverConfirmedPassengerAt`, `driverMarkedAbsentAt` (all nullable on first cut; tighten in a follow-up).
- [X] T062 [US2] Migration `008.04-booking-lifecycle__bookings-status-enum.ts`: convert `bookings.status` from `varchar` to `enum` with values `pending|confirmed|cancelled|rejected|in_progress|completed|no_show`; backfill existing string values 1-1.
- [X] T063 [US2] Migration `008.05-booking-lifecycle__create-pending-charges.ts`: create `pending_charges` with both indexes from data-model.md.
- [X] T064 [P] [US2] Update `Booking` entity in `rideshare-backend/src/database/entities/booking.entity.ts`: drop `seatNumber`, add OneToMany to `BookingSeat`, add the seven new fields, switch `status` to a typed enum.
- [X] T065 [US2] Implement `BookingsService.createMultiSeat()` in `rideshare-backend/src/modules/bookings/bookings.service.ts`: validates 1≤length≤availableSeats, exactly one `isMainBooker=true`, all seats currently free, runs adjacency rule across the prospective full set, creates Booking + BookingSeat rows in one transaction, computes `seatCount` and `totalAmount`, enqueues a `bookings-timeout` BullMQ job with 3h delay (or env override).
- [X] T066 [US2] Implement `BookingsService.autoPick()` in same file: searches for N seats satisfying adjacency, falls back to 422 NO_VALID_ARRANGEMENT.
- [X] T067 [US2] Add gender-adjacency helper `rideshare-backend/src/modules/seats/gender-adjacency.ts` reading from `BookingSeat.gender` plus already-booked seats (R-007); used by both `createMultiSeat` and `autoPick`.
- [X] T068 [US2] Implement `POST /v2/bookings` and `POST /v2/bookings/auto-pick` controllers in `rideshare-backend/src/modules/bookings/bookings.v2.controller.ts`.
- [X] T069 [US2] Implement v1 shim: in `rideshare-backend/src/modules/bookings/bookings.controller.ts`, translate the legacy `seatNumber` payload into a single-seat v2 internal call; emit `Deprecation: true` log line. Keep response shape identical to v1.
- [X] T070 [P] [US2] Implement `POST /bookings/:id/accept` (driver): set status to `confirmed`, remove the `bookings-timeout` job, run pending-charge collection sweep for the user (R-006 carry-forward), notify passenger.
- [X] T071 [P] [US2] Implement `POST /bookings/:id/reject` (driver): set status to `rejected`, remove the timeout job, notify passenger.
- [X] T072 [US2] Implement `POST /bookings/:id/cancel`: enforce 24h-driver / 12h-passenger windows; on within-policy passenger cancellation of confirmed booking, create `pending_charges` of `kind='passenger_cancellation'` for 5% of `totalAmount` and run hybrid wallet-deduct (R-006).
- [X] T073 [US2] Update `GET /bookings/:id` response in `rideshare-backend/src/modules/bookings/bookings.service.ts` to include `seats`, `totalAmount`, `settledAt`, `settlementGraceUntil`, `passengerPresenceConfirmedAt`, `driverConfirmedPassengerAt`, and route through `BookingViewerSerializer` skeleton from T011.
- [X] T074 [P] [US2] Implement `PendingChargeService` in `rideshare-backend/src/modules/pending-charges/pending-charge.service.ts`: `record(userId, kind, amount, bookingId, tripId)` opens a transaction, locks wallet, posts `WalletTransaction` `ADJUSTMENT/DEBIT` if balance suffices (mark `applied`), else leaves `pending` (R-006).
- [X] T075 [US2] Implement `PendingChargeService.collectOutstanding(userId, contextBookingId)` called from booking-confirm transaction; for each `pending` charge, retry wallet-debit, else attach `appliedToBookingId` for next platform-fee invoicing.
- [X] T076 [P] [US2] Implement `GET /me/pending-charges` controller in `rideshare-backend/src/modules/pending-charges/pending-charges.controller.ts`.
- [X] T077 [P] [US2] Implement `POST /admin/pending-charges/:id/waive` admin controller in `rideshare-backend/src/modules/admin/admin-pending-charges.controller.ts`; notifies user via push.
- [X] T078 [US2] Implement `BookingsTimeoutProcessor` in `rideshare-backend/src/jobs/processors/bookings-timeout.processor.ts`: defensive re-check of status; if still `pending`, set `cancelled` with `cancelledBy='system_timeout'`, release seats, push notify the passenger (FR-024).
- [X] T079 [US2] Implement `NoShowDetectorProcessor` in `rideshare-backend/src/jobs/processors/no-show-detector.processor.ts`: scheduled per-trip with delay `departureTime + 30min - now` on trip publish; if trip has no `tripStartedAt` and is not in_progress/completed, mark trip `cancelled` with `noShowMarkedAt`, create `pending_charges` of `kind='driver_no_show'` for 10% of `sum(confirmed bookings totalAmount)`, notify confirmed passengers (FR-027).
- [X] T080 [US2] Wire `complete-trip` no-show flagging side of FR-028 into `rideshare-backend/src/modules/trips/trips.service.ts.completeTrip()` (full implementation in US3, but the `pending_charges` creation hook is included now under a feature flag `TRIP_TIME_FLOW_ENABLED` so T053's test passes against this branch).
- [X] T081 [P] [US2] Mobile: update `rideshare/lib/bloc/booking/` for multi-seat (companion picker, auto-pick CTA, multi-seat summary on the trip detail screen). Update `rideshare/lib/core/services/booking_service.dart` to call `/v2/bookings` and `/v2/bookings/auto-pick`.
- [X] T082 [P] [US2] Mobile: build the companion-picker UI in `rideshare/lib/screens/passenger/companion_picker_screen.dart` (display name + gender per companion; `isMainBooker` derived) and the "pick for me" auto-pick variant.
- [X] T083 [P] [US2] Mobile: implement the cancellation-window warning dialog in the booking detail (`rideshare/lib/screens/passenger/booking_detail_screen.dart` and the driver counterpart) that reads `windowSeconds` from the 403 response.
- [X] T084 [P] [US2] Mobile: render the outstanding pending-charges banner on the trip-detail and booking-confirmation screens; pulled from `GET /me/pending-charges`. Update `rideshare/lib/bloc/trip/trip_state.dart` accordingly.
- [X] T085 [P] [US2] Dashboard: extend `rideshare-dashboard/src/pages/bookings/` to render the multi-seat shape (seats list, gender badges) and the new statuses; add a Pending Charges queue page at `pages/pending-charges/PendingChargesPage.tsx` with the waive action.
- [X] T086 [US2] Run quickstart Branch 2 stories 2.1–2.6; append PASS/FAIL section to `specs/008-platform-completion/quickstart.md`.

**Checkpoint**: User Story 2 deployable. Multi-seat, lifecycle, cancellations, and pending-charges all work end-to-end. US1 still works.

---

## Phase 5: User Story 3 — Pre-trip confirmation cycle, driver Start Trip, public share link (Priority: P2)

**Goal**: 30-minute-before pre-trip prompts; driver-controlled `Start Trip` gated by a 15-minute window; live driver location visible to confirmed passengers; passengers can issue a public share link with no PII.

**Independent Test**: Quickstart Branch 3 — see prompts fire at the override offset; reject early Start Trip; receive a share-link URL and load it in a browser to see a moving driver pin without any passenger data.

**Branch**: `011-trip-time-flow`. **Requirements**: FR-031..FR-036, SC-007, SC-008. Depends on Phase 4 (booking statuses).

### Tests for User Story 3

- [X] T087 [P] [US3] Contract test for `POST /bookings/:id/passenger-confirm` window enforcement and presence-flag setting in `rideshare-backend/test/contract/trip-time/passenger-confirm.contract.spec.ts`.
- [X] T088 [P] [US3] Contract test for `POST /bookings/:id/driver-confirm` per-seat presence in `rideshare-backend/test/contract/trip-time/driver-confirm.contract.spec.ts`.
- [X] T089 [P] [US3] Contract test for `POST /trips/:id/start` timing-window rejection and mocked-location rejection in `rideshare-backend/test/contract/trip-time/start-trip.contract.spec.ts`.
- [X] T090 [P] [US3] Contract test for `POST /trips/:id/complete` no-show flagging path (FR-028 finalized) in `rideshare-backend/test/contract/trip-time/complete-trip.contract.spec.ts`.
- [X] T091 [P] [US3] Contract test for share-link issuance, public-read shape (no PII), rate limit, and post-completion behavior in `rideshare-backend/test/contract/trip-time/share-link.contract.spec.ts`.
- [X] T092 [P] [US3] Integration test for `pre-trip-confirm` BullMQ job firing under override env and pushing to all confirmed passengers + driver in `rideshare-backend/test/integration/pre-trip-confirm.integration.spec.ts`.
- [X] T093 [P] [US3] Integration test that mocked-location during a live trip notifies confirmed passengers and flags the trip in `rideshare-backend/test/integration/live-tracking-mock-rejection.integration.spec.ts`.

### Implementation for User Story 3

- [X] T094 [P] [US3] Create `TripShareLink` entity in `rideshare-backend/src/database/entities/trip-share-link.entity.ts`.
- [X] T095 [US3] Migration `008.06-trip-time-flow__trips-extend.ts`: extend `trips.status` enum with `draft`, `published`, `fully_booked`, `in_progress`; backfill `active → published`; add `tripStartedAt`, `tripCompletedAt`, `noShowMarkedAt`, `lastDriverLocationLat/Lng/At`. Keep response serializer mapping `published → active` for one release per R-008.
- [X] T096 [US3] Migration `008.07-trip-time-flow__create-trip-share-links.ts`: create `trip_share_links` with unique `token` and `(tripId)` indexes.
- [X] T097 [US3] Update `Trip` entity in `rideshare-backend/src/database/entities/trip.entity.ts` for the new enum values and new columns.
- [X] T098 [P] [US3] Implement `POST /bookings/:id/passenger-confirm` in a new `rideshare-backend/src/modules/trip-time/trip-time.controller.ts`; window `[departureTime - 60min, departureTime + 30min]`; sets `passengerPresenceConfirmedAt` or notifies driver of `passengerReportedDriverAbsentAt`.
- [X] T099 [P] [US3] Implement `POST /bookings/:id/driver-confirm` in same controller: per-seat present/absent, rolling up to booking-level `driverConfirmedPassengerAt` / `driverMarkedAbsentAt`.
- [X] T100 [US3] Implement `POST /trips/:id/start` in `rideshare-backend/src/modules/trips/trips.service.ts`: enforce window `[departureTime - 15min, departureTime + 30min]`, banned/restricted gate, no `mock_location_rejected` event in last 5 minutes; flips trip to `in_progress`, all `confirmed` bookings to `in_progress`, removes the `no-show-detector` job.
- [X] T101 [US3] Implement `POST /trips/:id/complete` in same service: flip to `completed`; per-seat `noShowSeats` mark `BookingSeat.markedAbsentAt`; if all of a booking's seats are absent, set `booking.status='no_show'` and call `PendingChargeService.record(passengerId, 'passenger_no_show', totalAmount*0.05, …)` (FR-028); refresh active `trip_share_links` to expire `now + 30min`.
- [X] T102 [US3] Update `POST /tracking/location` to set `trips.lastDriverLocationLat/Lng/At` denormalized columns on success in `rideshare-backend/src/modules/tracking/tracking.controller.ts`.
- [X] T103 [P] [US3] Implement `POST /trips/:id/share-link` in `rideshare-backend/src/modules/share-links/share-links.controller.ts`: caller must have `confirmed` booking on the trip OR be the driver; generates 32-byte URL-safe token; `expiresAt = trip.departureTime + 6h` (R-002).
- [X] T104 [US3] Implement public `GET /share/:token` in same controller: returns shape from `trip-time.contract.md` "GET /share/:token" — no PII; `driverLocation` only when `tripStatus='in_progress'`; on `completed`/`cancelled`, returns the ended-state shape (FR-036). Apply Redis-bucket rate limit (1 req/sec, burst 60) per token.
- [X] T105 [US3] Implement `PreTripConfirmProcessor` in `rideshare-backend/src/jobs/processors/pre-trip-confirm.processor.ts`: hourly sweep finds trips at `departureTime ∈ [now+28min, now+32min]` with at least one `confirmed` booking; pushes prompt to each confirmed passenger, one per booking-seat to the driver (FR-031).
- [X] T106 [P] [US3] Mobile: build the pre-trip prompt sheets in `rideshare/lib/screens/passenger/pre_trip_prompt_screen.dart` and `rideshare/lib/screens/driver/driver_pre_trip_checklist_screen.dart`; bind to push notifications; call the two confirm endpoints.
- [X] T107 [P] [US3] Mobile: implement the driver "Start Trip" gate and the trip-completion screen with per-seat presence ticks in `rideshare/lib/screens/driver/start_trip_screen.dart` and `complete_trip_screen.dart`.
- [X] T108 [P] [US3] Mobile: build the share-link generator screen for confirmed passengers in `rideshare/lib/screens/passenger/share_link_screen.dart` (uses `share_plus`).
- [X] T109 [P] [US3] Build the public share-page HTML/JS in `rideshare-backend/public/share.html` (small Leaflet/Mapbox JS that polls `GET /share/:token`); served alongside the API. No login required.
- [X] T110 [US3] Run quickstart Branch 3 stories 3.1–3.3; append PASS/FAIL section to `specs/008-platform-completion/quickstart.md`.

**Checkpoint**: User Story 3 deployable. Pre-trip cycle, Start Trip gate, complete-trip, share link all work. US1+US2 still work.

---

## Phase 6: User Story 4 — Recurring trips with stops and notes (Priority: P2)

**Goal**: Driver creates a trip once, marked recurring (daily / weekday-mask) with intermediate stops and free-text notes; the system spawns the next 7 occurrences; cancelling one occurrence does not stop future spawns.

**Independent Test**: Quickstart Branch 4 — create a `weekly Sun/Tue/Thu` trip; observe 4–5 future occurrences appear on the passenger feed; add stops and notes and see them rendered in the trip detail.

**Branch**: `012-trip-authoring`. **Requirements**: FR-011, FR-013, FR-014. Independent of US3 but uses the new trip-status enum from Phase 5.

### Tests for User Story 4

- [X] T111 [P] [US4] Contract test for `POST /trips` with stops in `rideshare-backend/test/contract/trips/create-with-stops.contract.spec.ts`.
- [X] T112 [P] [US4] Contract test for `POST /trips` with `recurrence` plus the spawner producing the expected dates in `rideshare-backend/test/contract/trips/create-with-recurrence.contract.spec.ts`.
- [X] T113 [P] [US4] Contract test for `DELETE /trips/:id` 24h cancellation-window rejection in `rideshare-backend/test/contract/trips/cancel-window.contract.spec.ts`.
- [X] T114 [P] [US4] Contract test for `PATCH /trips/recurrence-rules/:id` weekday/until/isActive toggles in `rideshare-backend/test/contract/trips/recurrence-rule-toggle.contract.spec.ts`.
- [X] T115 [P] [US4] Integration test for the spawn-skip-on-conflict path producing a `recurrence_skip` log entry in `rideshare-backend/test/integration/spawn-skip-conflict.integration.spec.ts`.

### Implementation for User Story 4

- [X] T116 [P] [US4] Create `TripRecurrenceRule` entity in `rideshare-backend/src/database/entities/trip-recurrence-rule.entity.ts`.
- [X] T117 [US4] Migration `008.08-trip-authoring__recurrence-stops-notes.ts`: create `trip_recurrence_rules` with both indexes; add `trips.recurrenceRuleId` (FK SET NULL), `trips.stops` (jsonb default `[]`), `trips.notes` (text nullable).
- [X] T118 [P] [US4] Update `Trip` entity for `stops`, `notes`, `recurrenceRuleId`.
- [X] T119 [US4] Extend `POST /trips` request shape and validation in `rideshare-backend/src/modules/trips/trips.service.ts.createTrip()`: accept `stops` (≤5), `notes`, optional `recurrence` block; when `recurrence` present, also create a `trip_recurrence_rules` row with `templateJson` capturing the trip-creation payload (R/recurrence.contract.md).
- [X] T120 [P] [US4] Extend `PATCH /trips/:id` to accept `notes`, `stops`, and `departureTime` (latter only when zero confirmed bookings or > 24h before).
- [X] T121 [P] [US4] Extend `DELETE /trips/:id` policy: refuse with `403 CANCELLATION_WINDOW_CLOSED` inside 24h; when allowed and the trip came from a recurrence rule, do NOT deactivate the rule (FR-014).
- [X] T122 [P] [US4] Implement `GET /trips/recurrence-rules`, `PATCH /trips/recurrence-rules/:id`, `DELETE /trips/recurrence-rules/:id` in a new `rideshare-backend/src/modules/recurrence/recurrence.controller.ts`.
- [X] T123 [US4] Implement `RecurrenceSpawnProcessor` in `rideshare-backend/src/jobs/processors/recurrence-spawn.processor.ts` per the algorithm in `recurrence.contract.md`: hourly cron; for each active rule, compute next occurrences within `min(now+14d, until)`, skip when `(driverId, departureTime)` already exists with `recurrence_skip` log, update `lastSpawnedFor`.
- [X] T124 [P] [US4] Optional admin endpoint `POST /admin/recurrence-rules/:id/spawn-now` in `rideshare-backend/src/modules/admin/admin-recurrence.controller.ts` for ops debugging.
- [X] T125 [P] [US4] Mobile: extend the trip-create form in `rideshare/lib/screens/driver/trip_create_screen.dart` to accept stops, notes, and a recurrence picker (frequency + weekdays + until-date). Update `rideshare/lib/bloc/trip/trip_bloc.dart` accordingly.
- [X] T126 [P] [US4] Mobile: render stops and notes in the passenger trip-detail screen (`rideshare/lib/screens/passenger/trip_detail_screen.dart`) along the route polyline.
- [X] T127 [P] [US4] Dashboard: extend `rideshare-dashboard/src/pages/trips/` to surface stops, notes, and recurrence-rule context in the admin trip detail.
- [X] T128 [US4] Run quickstart Branch 4 stories 4.1–4.2; append PASS/FAIL section to `specs/008-platform-completion/quickstart.md`.

**Checkpoint**: User Story 4 deployable. Recurrence + stops + notes work. US1–US3 still work.

---

## Phase 7: User Story 5 — Mark-paid settlement, contact reveal, in-app calls with masking (Priority: P2)

**Goal**: Driver presses "Mark paid" to settle a booking; passenger and driver phone unmask; chat and call activate. Settlement reversible only inside a 5-minute grace window with no contact yet. Optional `hidePhoneNumber` preference routes calls through a Twilio proxy DID.

**Independent Test**: Quickstart Branch 5 — confirm masked vs. unmasked contact pre/post mark-paid; revert inside grace; revert refused after grace or after first chat; place a masked call against a Twilio test credential.

**Branch**: `013-settle-and-call`. **Requirements**: FR-037..FR-041, SC-009. Depends on Phase 4 (booking shape).

### Tests for User Story 5

- [X] T129 [P] [US5] Contract test for `POST /bookings/:id/mark-paid` happy + double-mark 409 in `rideshare-backend/test/contract/settlement/mark-paid.contract.spec.ts`.
- [X] T130 [P] [US5] Contract test for `POST /bookings/:id/unmark-paid` within grace, after grace 409, after first chat 409 in `rideshare-backend/test/contract/settlement/unmark-paid.contract.spec.ts`.
- [X] T131 [P] [US5] Contract test for `POST /admin/bookings/:id/admin-revert-settlement` always-succeeds idempotency in `rideshare-backend/test/contract/settlement/admin-revert.contract.spec.ts`.
- [X] T132 [P] [US5] Contract test sweeping the affected serializers (booking detail, my-trips, my-bookings, chat preview, notification payload) for masked vs. unmasked shapes in `rideshare-backend/test/contract/settlement/viewer-mask.contract.spec.ts`.
- [X] T133 [P] [US5] Contract test for `POST /bookings/:id/calls/initiate` happy + booking-not-settled 403 + `hidePhoneNumber` mask + pool-exhausted 503 in `rideshare-backend/test/contract/calls/calls-initiate.contract.spec.ts`.
- [X] T134 [P] [US5] Contract test for `POST /calls/twilio-webhook` signature validation + status update in `rideshare-backend/test/contract/calls/calls-twilio-webhook.contract.spec.ts`.
- [X] T135 [P] [US5] Contract test for chat REST + WebSocket gating (REST 403, WS 4403 close code) in `rideshare-backend/test/contract/chat/chat-gating.contract.spec.ts`.

### Implementation for User Story 5

- [X] T136 [P] [US5] Create `CallSession` entity in `rideshare-backend/src/database/entities/call-session.entity.ts`.
- [X] T137 [P] [US5] Create `SettlementAudit` entity (append-only) in `rideshare-backend/src/database/entities/settlement-audit.entity.ts`.
- [X] T138 [US5] Migration `008.09-settle-and-call__create-calls-and-audits.ts`: create `call_sessions` and `settlement_audits` tables with their indexes.
- [X] T139 [US5] Implement `POST /bookings/:id/mark-paid` in `rideshare-backend/src/modules/settlement/settlement.controller.ts`: sets `settledAt=now`, `settlementGraceUntil=now+5min`, inserts `settlement_audits` row, push-notifies passenger.
- [X] T140 [US5] Implement `POST /bookings/:id/unmark-paid`: enforce `now < settlementGraceUntil`, no `chat_messages` rows for the booking, no `call_sessions` rows. On violation, `409 GRACE_EXPIRED` or `409 CONTACT_ALREADY_USED`.
- [X] T141 [US5] Implement `POST /admin/bookings/:id/admin-revert-settlement`: idempotent; inserts `action='admin_revert'` audit row.
- [X] T142 [US5] **Fill in `BookingViewerSerializer`** from T011: when `booking.settledAt IS NULL`, mask `displayName`, `phone`, `photoUrl` for the other-party fields; emit `chatEnabled: false`, `callEnabled: false`. Admin viewers always see raw values. Apply across booking detail, my-trips list, my-bookings list, chat preview, notification payload (FR-037, SC-009).
- [X] T143 [P] [US5] Add `hidePhoneNumber` to `PATCH /me` request DTO in `rideshare-backend/src/modules/users/dto/update-user.dto.ts` and the service write path.
- [X] T144 [P] [US5] Implement Twilio proxy-number pool helper in `rideshare-backend/src/modules/calls/proxy-pool.service.ts`: `allocate(bookingId)` returns an available number (idle or already-bound to that booking) and reuses the same number for the booking's lifecycle; `deallocate(bookingId)` runs at trip-completed-plus-24h.
- [X] T145 [US5] Implement `POST /bookings/:id/calls/initiate` in `rideshare-backend/src/modules/calls/calls.controller.ts`: precondition booking-settled and caller is a participant; allocate proxy; create `call_sessions` row; configure Twilio TwiML to bridge real numbers; respond `{ callSessionId, proxyNumberE164, expiresAt }`. On exhausted pool → `503 NO_PROXY_NUMBERS_AVAILABLE`.
- [X] T146 [US5] Implement `POST /calls/twilio-webhook` (public, signed): validate Twilio signature, update `endedAt`, `durationSeconds`, `terminationReason` on the matching `call_sessions` row.
- [X] T147 [P] [US5] Implement `GET /bookings/:id/calls`: list call sessions; if other party has `hidePhoneNumber=true`, return only proxy and self real number, never the other party's real number.
- [X] T148 [US5] Add chat gating in `rideshare-backend/src/modules/chat/`: REST endpoints return `403 BOOKING_NOT_SETTLED` when underlying booking unsettled; WebSocket gateway closes new connections with code `4403` when not settled (FR-038).
- [X] T149 [P] [US5] Mobile: build the driver "Mark paid" CTA + grace-window "Undo" UI in `rideshare/lib/screens/driver/booking_detail_screen.dart`. Add `rideshare/lib/bloc/settlement/`.
- [X] T150 [P] [US5] Mobile: settled-vs-unsettled card variants in `rideshare/lib/screens/shared/booking_card.dart` — masked phone, disabled chat/call buttons with explanatory tooltip.
- [X] T151 [P] [US5] Mobile: implement the call screen and `call_service.dart` in `rideshare/lib/core/services/`; on tap, calls `/bookings/:id/calls/initiate`, opens system dialer at `proxyNumberE164` via `url_launcher`. Show "calling masked number" copy when proxy ≠ real.
- [X] T152 [P] [US5] Mobile: add the `hidePhoneNumber` toggle to the profile settings screen (`rideshare/lib/screens/auth/profile_settings_screen.dart`).
- [X] T153 [P] [US5] Dashboard: extend the booking detail page to show settlement audit trail + admin-revert button.
- [X] T154 [US5] Run quickstart Branch 5 stories 5.1–5.3; append PASS/FAIL section to `specs/008-platform-completion/quickstart.md`.

**Checkpoint**: User Story 5 deployable. Mark-paid settlement, post-settle reveal, masked calls all work. US1–US4 still work.

---

## Phase 8: User Story 6 — Admin ban, complaints, WhatsApp support & refund records (Priority: P3)

**Goal**: Admins ban users (distinct from deactivate) with cascade; users file complaints from the app; users tap Support/Refund to deep-link to WhatsApp at `+962 78 888 3007` with prefilled context; refunds also create a server-side admin record.

**Independent Test**: Quickstart Branch 6 — admin bans a user; the user sees the ban screen on next app open with a Contact Support button; passenger files a complaint visible in admin queue; refund deep-link opens WhatsApp and creates a `refund_requests` row.

**Branch**: `014-admin-and-support`. **Requirements**: FR-042..FR-049, SC-011, SC-012, SC-013. Depends on Phases 3, 4, 7.

### Tests for User Story 6

- [X] T155 [P] [US6] Contract test for `POST /admin/users/:id/ban` cascade exhaustiveness (pending bookings cancelled, confirmed bookings cancelled, authored published trips cancelled with passenger notifications, all `user_devices` revoked) in `rideshare-backend/test/contract/admin/ban-cascade.contract.spec.ts`.
- [X] T156 [P] [US6] Contract test for the BanGuard from T009 returning `403 ACCOUNT_BANNED` with the documented body on any authenticated endpoint in `rideshare-backend/test/contract/admin/ban-guard.contract.spec.ts`.
- [X] T157 [P] [US6] Contract test for `POST /complaints` validation (at least one of againstUserId|tripId|bookingId) in `rideshare-backend/test/contract/admin/complaints-create.contract.spec.ts`.
- [X] T158 [P] [US6] Contract test for `PATCH /admin/complaints/:id` resolved/rejected status notifying the reporter in `rideshare-backend/test/contract/admin/complaints-admin-update.contract.spec.ts`.
- [X] T159 [P] [US6] Contract test for `POST /refund-requests` returning the `whatsappDeepLink` shape in `rideshare-backend/test/contract/admin/refund-create.contract.spec.ts`.
- [X] T160 [P] [US6] Contract test for `GET /support/config` shape in `rideshare-backend/test/contract/admin/support-config.contract.spec.ts`.

### Implementation for User Story 6

- [X] T161 [P] [US6] Create `Complaint` entity in `rideshare-backend/src/database/entities/complaint.entity.ts`.
- [X] T162 [P] [US6] Create `RefundRequest` entity in `rideshare-backend/src/database/entities/refund-request.entity.ts`.
- [X] T163 [US6] Migration `008.10-admin-and-support__create-complaints-and-refunds.ts`: create `complaints` and `refund_requests` with their indexes.
- [X] T164 [US6] Implement full ban cascade in `rideshare-backend/src/modules/admin/admin-ban.service.ts`: `banUser(userId, reason)` sets `bannedAt`/`banReason`; cancels every `pending` and `confirmed` booking owned by the user; for trips authored by the user that are `published`, cancels them and notifies confirmed passengers; revokes all `user_devices`; writes `security_events` of type `account_banned`.
- [X] T165 [P] [US6] Implement `POST /admin/users/:id/ban` controller in `rideshare-backend/src/modules/admin/admin.controller.ts` calling the cascade service; record reason. Replace the placeholder ban call from T036.
- [X] T166 [P] [US6] Implement `POST /admin/users/:id/unban` controller; sets `bannedAt=null`, `banReason=null` (does not restore previously-cancelled bookings).
- [X] T167 [P] [US6] Implement `POST /complaints`, `GET /me/complaints` in `rideshare-backend/src/modules/complaints/complaints.controller.ts` per `admin-support.contract.md`.
- [X] T168 [P] [US6] Implement `GET /admin/complaints`, `PATCH /admin/complaints/:id` in `rideshare-backend/src/modules/admin/admin-complaints.controller.ts`; resolved/rejected pushes a notification to the reporter.
- [X] T169 [P] [US6] Implement `POST /refund-requests` in `rideshare-backend/src/modules/refunds/refunds.controller.ts`: creates `refund_requests` row with `status='open'`, `whatsappContactedAt=now`; response includes `whatsappDeepLink` built from env-configured number with URL-encoded prefill (booking ref, amount, reason, last-6 user-id chars).
- [X] T170 [P] [US6] Implement `GET /admin/refund-requests` and `PATCH /admin/refund-requests/:id` in `rideshare-backend/src/modules/admin/admin-refunds.controller.ts`.
- [X] T171 [P] [US6] Implement `GET /support/config` in `rideshare-backend/src/modules/support/support.controller.ts`: returns `{ whatsappE164, whatsappDeepLinkBase }` from env (`SUPPORT_WHATSAPP_E164` default `+962788883007`).
- [X] T172 [P] [US6] Update `FR-049` push-notification templates in `rideshare-backend/src/modules/notifications/notifications.service.ts` to cover: complaint status changes, ban applied, penalty charge applied (the booking/trip/chat/device templates landed in earlier phases).
- [X] T173 [P] [US6] Mobile: add the complaint-filing screen at `rideshare/lib/screens/passenger/complaint_screen.dart` reachable from booking detail and trip detail; bind to `POST /complaints`.
- [X] T174 [P] [US6] Mobile: implement the ban screen at `rideshare/lib/screens/auth/banned_screen.dart` rendered globally on `403 ACCOUNT_BANNED` with a Contact Support button that opens WhatsApp at the configured number using `url_launcher`. Use `https://wa.me/962788883007?text=…` (works on iOS and Android per research.md "Open implementation items").
- [X] T175 [P] [US6] Mobile: build the refund-request screen at `rideshare/lib/screens/refund/refund_request_screen.dart` and Support entry in `rideshare/lib/screens/support/support_screen.dart`; both call `GET /support/config` for the number, then deep-link to WhatsApp with prefill.
- [X] T176 [P] [US6] Dashboard: build the Complaints queue page at `rideshare-dashboard/src/pages/complaints/ComplaintsPage.tsx` (filter by status/category, view detail, change status with admin notes).
- [X] T177 [P] [US6] Dashboard: build the Refund queue page at `rideshare-dashboard/src/pages/refunds/RefundsPage.tsx`.
- [X] T178 [P] [US6] Dashboard: extend the user detail page at `rideshare-dashboard/src/pages/users/` to add Ban/Unban actions and a Devices tab.
- [X] T179 [US6] Run quickstart Branch 6 stories 6.1–6.3; append PASS/FAIL section to `specs/008-platform-completion/quickstart.md`.

**Checkpoint**: All six user stories deployable independently and together.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Cleanup, hardening, and the deferred shim removals.

- [X] T180 [P] Drop the `published → active` trip-status compatibility shim in `rideshare-backend/src/modules/trips/trips.serializer.ts` once min-app-version gate from R-008 is enforced; bump min-app-version env value.
- [X] T181 [P] Remove the legacy `bookings.seatNumber` column in a follow-up migration `008.11-cleanup__drop-bookings-seatnumber.ts` once one deploy cycle has elapsed since 008.02.
- [X] T182 [P] Tighten `bookings.totalAmount` to `NOT NULL` in a follow-up migration after T061's nullable-on-creation backfill is verified.
- [X] T183 [P] Decide and document the WhatsApp deep-link string format for iOS — research.md flagged that `https://wa.me/962788883007?text=…` works on both, but if iOS users report a web fallback, swap to `whatsapp://send?phone=…&text=…`. Update `rideshare/lib/screens/support/support_screen.dart` and the dashboard if needed.
- [X] T184 [P] Confirm refund-record retention policy (likely 2 years) with operations and document in `specs/008-platform-completion/research.md` "Open implementation items".
- [X] T185 [P] Add unit tests for the BookingViewerSerializer mask logic in `rideshare-backend/test/unit/booking-viewer-serializer.spec.ts`.
- [X] T186 [P] Performance check: nearby-trip query P95 < 1s with PostGIS index on `trips`; trip feed P95 < 2s. Capture results in a comment block in `specs/008-platform-completion/research.md`.
- [X] T187 [P] Audit logs cleanup: ensure `security_events`, `settlement_audits`, `pending_charges` carry the request-id correlation field for ops debugging.
- [X] T188 Run `npm test && npm run lint` in `rideshare-backend/`, `flutter analyze && flutter test` in `rideshare/`, `npm run build` in `rideshare-dashboard/`. All gates green per quickstart.md "Sanity tests".
- [X] T189 Final pass through `specs/008-platform-completion/quickstart.md`: every Branch 1–6 acceptance scenario must show a PASS line; any FAIL gates the merge.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: no dependencies.
- **Phase 2 (Foundational)**: depends on Phase 1; **blocks all User Story phases**.
- **Phase 3 (US1)**: depends on Phase 2.
- **Phase 4 (US2)**: depends on Phase 3 (uses `BanGuard` and the LocationGuardInterceptor). MVP cut: Phases 1+2+3+4.
- **Phase 5 (US3)**: depends on Phase 4 (booking statuses, `pending_charges`).
- **Phase 6 (US4)**: depends on Phase 5 (uses the new trip-status enum) — the two phases can be developed in parallel by different devs but US4's migration sequences after US3's.
- **Phase 7 (US5)**: depends on Phase 4.
- **Phase 8 (US6)**: depends on Phases 3, 4, 7 (ban cascade reaches into user-devices, bookings, settlements).
- **Phase 9 (Polish)**: after all six user-story phases.

### User Story Dependencies (matches branch dependencies in plan.md "Phasing & Branch Plan")

- **US1 (P1)** standalone after Phase 2.
- **US2 (P1)** depends on US1.
- **US3 (P2)** depends on US2.
- **US4 (P2)** depends on US2; independent of US3 but its migration sequences after US3.
- **US5 (P2)** depends on US2.
- **US6 (P3)** depends on US1, US2, US5.

### Within Each User Story

- Tests are written FIRST and verified failing.
- Models (entities + migrations) before services.
- Services before controllers.
- Backend before mobile/dashboard wiring.

### Parallel Opportunities

- All Setup tasks marked [P] in Phase 1 (T002–T006).
- Foundational [P] tasks T009, T010, T011, T012 (after T007/T008).
- Within each User Story, all `Tests for User Story X` tasks are [P] (different files).
- Within each User Story, model/entity creations are [P]; mobile and dashboard wiring tasks are [P] with each other and with backend controller tasks once entities/services exist.
- Different user stories can be staffed in parallel by separate developers once their dependency phase is in.

---

## Parallel Example: User Story 1

```bash
# After T007/T008 land, launch the test-first batch in parallel:
Task: "Contract test verify-otp" (T013)
Task: "Contract test devices" (T014)
Task: "Contract test removed paths" (T015)
Task: "Contract test account-flags" (T016)
Task: "Integration test mock-location rejection" (T017)
Task: "Integration test multi-account-device flag" (T018)
Task: "Unit test device fingerprint" (T019)
Task: "Widget test phone-only auth screen" (T020)

# Then in parallel for entities/services:
Task: "Create UserDevice entity" (T021)
Task: "Create AccountFlag entity" (T022)
Task: "Create SecurityEvent entity" (T023)

# Then in parallel for mobile + dashboard:
Task: "Mobile auth bloc rework" (T038)
Task: "Mobile drop social/email screens" (T039)
Task: "Mobile device_binding + spoof_guard" (T040)
Task: "Dashboard Account Flags page" (T043)
```

---

## Implementation Strategy

### MVP First (Phases 1+2+3+4)

1. Phase 1: Setup.
2. Phase 2: Foundational — BanGuard, RestrictedAccountInterceptor, BookingViewerSerializer skeleton, `User` extensions.
3. Phase 3: US1 (auth hardening).
4. Phase 4: US2 (booking lifecycle + pending charges).
5. **STOP and VALIDATE**: quickstart Branches 1+2 must be green. This is the trust-loop MVP — phone-only auth, multi-seat bookings, cancellation policy, no-show penalties.

### Incremental Delivery

After the MVP:

1. Phase 5 (US3) → Trip-time + share link → demo.
2. Phase 6 (US4) → Recurrence + stops/notes → demo.
3. Phase 7 (US5) → Settlement + reveal + calls → demo.
4. Phase 8 (US6) → Ban + complaints + refunds + WhatsApp → demo.
5. Phase 9 (Polish) → shim removals, NOT NULL tightening, perf checks.

### Parallel Team Strategy

With multiple developers after Phase 4 lands:

- Dev A: Phase 5 (US3 trip-time).
- Dev B: Phase 6 (US4 recurrence) — independent of A.
- Dev C: Phase 7 (US5 settlement & calls) — independent of A and B.
- Phase 8 starts when A+C are merged; Phase 9 last.

---

## Notes

- Every task carries an absolute file path under `rideshare-backend/`, `rideshare/`, or `rideshare-dashboard/`.
- Every backend test file path matches the contract test names listed in `specs/008-platform-completion/contracts/*.contract.md`.
- BullMQ processors are registered through `rideshare-backend/src/jobs/jobs.module.ts` (touched in T003).
- Migrations are sequenced `008.NN-<branch>__<description>.ts` under `rideshare-backend/src/database/migrations/`.
- Mobile + dashboard work for each phase ships in the same PR as the backend per Constitution V (Cross-Platform Parity).
- Hooks: `.specify/extensions.yml` has both `before_tasks` and `after_tasks` git-commit hooks set as optional; commit at branch boundaries rather than per-task.
