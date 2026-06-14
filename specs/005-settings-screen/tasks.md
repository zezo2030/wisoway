# Tasks: Settings Screen

**Input**: Design documents from `/specs/005-settings-screen/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Include widget and integration-oriented test tasks because the feature artifacts explicitly require behavior verification with `flutter_test` and quickstart smoke checks.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Every task includes an exact file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and package setup for settings feature delivery.

- [x] T001 Add settings feature dependencies (`package_info_plus`, `share_plus`, `webview_flutter`) in rideshare/pubspec.yaml
- [x] T002 Refresh dependency lockfile after settings packages update in rideshare/pubspec.lock
- [x] T003 Add settings feature route constants in rideshare/lib/core/constants/route_names.dart

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core building blocks that all user stories depend on.

- [x] T004 Define all SharedPreferences keys for theme, notifications, and privacy in rideshare/lib/core/constants/app_constants.dart
- [x] T005 Create typed preferences model and enums in rideshare/lib/models/user_preferences.dart
- [x] T006 [P] Implement shared preference CRUD APIs for settings in rideshare/lib/core/services/settings_service.dart
- [x] T007 [P] Implement reactive ThemeMode persistence service in rideshare/lib/core/services/theme_service.dart
- [x] T008 Register ThemeService provider and MaterialApp `themeMode` wiring in rideshare/lib/main.dart
- [x] T009 [P] Create reusable settings section wrapper widget in rideshare/lib/widgets/settings/settings_section.dart
- [x] T010 [P] Create reusable action tile widget in rideshare/lib/widgets/settings/settings_tile.dart
- [x] T011 [P] Create reusable switch tile widget in rideshare/lib/widgets/settings/settings_switch_tile.dart
- [x] T012 [P] Add shared settings localization keys in rideshare/lib/l10n/app_ar.arb
- [x] T013 [P] Add shared settings localization keys in rideshare/lib/l10n/app_en.arb
- [x] T014 Create settings route registration and navigation mapping in rideshare/lib/main.dart

**Checkpoint**: Foundation complete. User stories can now be implemented and tested independently.

---

## Phase 3: User Story 1 - Theme & Appearance Control (Priority: P1) MVP

**Goal**: Let users switch between System/Light/Dark modes with immediate app-wide effect and persistence.

**Independent Test**: From Settings, change theme mode and verify immediate UI change plus correct mode restoration after app restart.

### Tests for User Story 1

- [x] T015 [P] [US1] Add widget test for dark mode toggle behavior in rideshare/test/widget/settings/theme_toggle_test.dart
- [x] T016 [P] [US1] Add widget test for theme mode selector bottom sheet in rideshare/test/widget/settings/theme_toggle_test.dart

### Implementation for User Story 1

- [x] T017 [US1] Implement Appearance section with dark mode switch and theme mode tile in rideshare/lib/screens/settings/settings_screen.dart
- [x] T018 [US1] Implement theme mode selection bottom sheet actions in rideshare/lib/screens/settings/settings_screen.dart
- [x] T019 [US1] Wire ThemeService reads/writes for settings UI controls in rideshare/lib/screens/settings/settings_screen.dart
- [x] T020 [US1] Add theme-related localized labels and helper text in rideshare/lib/l10n/app_ar.arb
- [x] T021 [US1] Add theme-related localized labels and helper text in rideshare/lib/l10n/app_en.arb

**Checkpoint**: US1 is independently functional and testable.

---

## Phase 4: User Story 2 - Language Switching (Priority: P1)

**Goal**: Allow users to switch Arabic/English with immediate text and RTL/LTR updates and persistence.

**Independent Test**: Change language from Settings and verify text + direction update instantly, then persist across restart.

### Tests for User Story 2

- [x] T022 [P] [US2] Add widget test for language selector flow in rideshare/test/widget/settings/language_switch_test.dart
- [x] T023 [P] [US2] Add widget test for RTL/LTR direction change from language selection in rideshare/test/widget/settings/language_switch_test.dart

### Implementation for User Story 2

- [x] T024 [US2] Implement Language section tile and selector bottom sheet in rideshare/lib/screens/settings/settings_screen.dart
- [x] T025 [US2] Wire language change to LocalizationService from Settings UI in rideshare/lib/screens/settings/settings_screen.dart
- [x] T026 [US2] Add language selection labels and confirmations in rideshare/lib/l10n/app_ar.arb
- [x] T027 [US2] Add language selection labels and confirmations in rideshare/lib/l10n/app_en.arb

**Checkpoint**: US2 is independently functional and testable.

---

## Phase 5: User Story 3 - Settings Screen Navigation (Priority: P1)

**Goal**: Make all existing Settings entry points navigate to a complete settings hub screen.

**Independent Test**: Tap Settings in Profile tab and Side Drawer and verify navigation to Settings screen with all required sections visible.

### Tests for User Story 3

- [x] T028 [P] [US3] Add widget test for settings screen section rendering in rideshare/test/widget/settings/settings_screen_test.dart
- [x] T029 [P] [US3] Add widget test for profile and drawer settings navigation in rideshare/test/widget/settings/settings_screen_test.dart

### Implementation for User Story 3

- [x] T030 [US3] Build main settings screen scaffold and section layout in rideshare/lib/screens/settings/settings_screen.dart
- [x] T031 [US3] Wire Profile tab Settings/Help/About buttons to settings routes in rideshare/lib/screens/home/tabs/profile_tab.dart
- [x] T032 [US3] Wire Side Drawer Settings item navigation and drawer close behavior in rideshare/lib/screens/home/home_drawer.dart
- [x] T033 [US3] Add settings screen route entry and builder in rideshare/lib/main.dart

**Checkpoint**: US3 is independently functional and testable.

---

## Phase 6: User Story 4 - Notification Preferences (Priority: P2)

**Goal**: Provide master notification controls and detailed per-category toggles with local persistence and topic updates.

**Independent Test**: Toggle master push and category switches, verify persisted state and topic subscribe/unsubscribe calls.

### Tests for User Story 4

- [x] T034 [P] [US4] Add widget test for notification master toggle behavior in rideshare/test/widget/settings/notification_settings_test.dart
- [x] T035 [P] [US4] Add widget test for notification category toggle persistence in rideshare/test/widget/settings/notification_settings_test.dart

### Implementation for User Story 4

- [x] T036 [US4] Implement notification state APIs (master, sound, vibration, categories) in rideshare/lib/core/services/settings_service.dart
- [x] T037 [US4] Implement category topic subscribe/unsubscribe wiring in rideshare/lib/core/services/settings_service.dart
- [x] T038 [US4] Create detailed notification settings screen UI in rideshare/lib/screens/settings/notification_settings_screen.dart
- [x] T039 [US4] Integrate notification switches and navigation tile in rideshare/lib/screens/settings/settings_screen.dart
- [x] T040 [US4] Add notification labels and category text in rideshare/lib/l10n/app_ar.arb
- [x] T041 [US4] Add notification labels and category text in rideshare/lib/l10n/app_en.arb

**Checkpoint**: US4 is independently functional and testable.

---

## Phase 7: User Story 5 - Account & Security Management (Priority: P2)

**Goal**: Show account identity/verification status and provide link-phone + password-coming-soon actions.

**Independent Test**: Open Account & Security and verify email/phone/role plus verification badges render correctly by user role.

### Tests for User Story 5

- [x] T042 [P] [US5] Add widget test for account info and verification rendering in rideshare/test/widget/settings/account_security_test.dart
- [x] T043 [P] [US5] Add widget test for link-phone and coming-soon actions in rideshare/test/widget/settings/account_security_test.dart

### Implementation for User Story 5

- [x] T044 [US5] Create account and security details screen in rideshare/lib/screens/settings/account_security_screen.dart
- [x] T045 [US5] Implement role-aware verification badges using AuthProvider data in rideshare/lib/screens/settings/account_security_screen.dart
- [x] T046 [US5] Add account security navigation/action tiles in rideshare/lib/screens/settings/settings_screen.dart
- [x] T047 [US5] Add account/security localized strings in rideshare/lib/l10n/app_ar.arb
- [x] T048 [US5] Add account/security localized strings in rideshare/lib/l10n/app_en.arb

**Checkpoint**: US5 is independently functional and testable.

---

## Phase 8: User Story 6 - Privacy Controls (Priority: P2)

**Goal**: Allow users to manage location sharing, online visibility, and rating visibility with persistent toggles.

**Independent Test**: Toggle privacy options, restart app, and verify values persist and are respected by UI/service checks.

### Tests for User Story 6

- [x] T049 [P] [US6] Add widget test for privacy toggle persistence in rideshare/test/widget/settings/privacy_settings_test.dart
- [x] T050 [P] [US6] Add widget test for privacy screen toggle states loading in rideshare/test/widget/settings/privacy_settings_test.dart

### Implementation for User Story 6

- [x] T051 [US6] Implement privacy preference read/write APIs in rideshare/lib/core/services/settings_service.dart
- [x] T052 [US6] Create privacy settings screen with three toggles in rideshare/lib/screens/settings/privacy_settings_screen.dart
- [x] T053 [US6] Add privacy section navigation and summary states in rideshare/lib/screens/settings/settings_screen.dart
- [x] T054 [US6] Enforce location-sharing preference before location broadcast in rideshare/lib/core/services/location_service.dart
- [x] T055 [US6] Add privacy localized strings and descriptions in rideshare/lib/l10n/app_ar.arb
- [x] T056 [US6] Add privacy localized strings and descriptions in rideshare/lib/l10n/app_en.arb

**Checkpoint**: US6 is independently functional and testable.

---

## Phase 9: User Story 7 - Payment & Wallet Shortcuts (Priority: P3)

**Goal**: Provide quick settings shortcuts to wallet and payment history with role-aware wallet routing.

**Independent Test**: From Settings, tap Wallet and Payment History and verify destination screen is correct for driver/passenger roles.

### Tests for User Story 7

- [x] T057 [P] [US7] Add widget test for role-based wallet navigation in rideshare/test/widget/settings/payment_shortcuts_test.dart
- [x] T058 [P] [US7] Add widget test for payment history shortcut navigation in rideshare/test/widget/settings/payment_shortcuts_test.dart

### Implementation for User Story 7

- [x] T059 [US7] Implement payment and wallet shortcut tiles in rideshare/lib/screens/settings/settings_screen.dart
- [x] T060 [US7] Add role-aware wallet route resolution logic in rideshare/lib/screens/settings/settings_screen.dart
- [x] T061 [US7] Add payment shortcut localized labels in rideshare/lib/l10n/app_ar.arb
- [x] T062 [US7] Add payment shortcut localized labels in rideshare/lib/l10n/app_en.arb

**Checkpoint**: US7 is independently functional and testable.

---

## Phase 10: User Story 8 - About & App Info (Priority: P3)

**Goal**: Add about screen with version display, rating/sharing actions, license page, and in-app legal browsing.

**Independent Test**: Open About and verify app version renders; Rate/Share/Licenses/Legal actions open their intended destinations.

### Tests for User Story 8

- [x] T063 [P] [US8] Add widget test for about screen app metadata rendering in rideshare/test/widget/settings/about_screen_test.dart
- [x] T064 [P] [US8] Add widget test for about and legal action handlers in rideshare/test/widget/settings/about_screen_test.dart

### Implementation for User Story 8

- [x] T065 [US8] Create about screen with version, rate, share, and licenses actions in rideshare/lib/screens/settings/about_screen.dart
- [x] T066 [US8] Create reusable in-app browser screen for legal pages in rideshare/lib/screens/settings/in_app_browser_screen.dart
- [x] T067 [US8] Add support/help and about section actions in rideshare/lib/screens/settings/settings_screen.dart
- [x] T068 [US8] Add WhatsApp contact and legal URL launcher helpers in rideshare/lib/screens/settings/settings_screen.dart
- [x] T069 [US8] Add about/support localized strings in rideshare/lib/l10n/app_ar.arb
- [x] T070 [US8] Add about/support localized strings in rideshare/lib/l10n/app_en.arb

**Checkpoint**: US8 is independently functional and testable.

---

## Phase 11: User Story 9 - Account Deletion (Priority: P3)

**Goal**: Provide secure double-confirmation account deletion flow with Contact Support fallback when backend endpoint is unavailable.

**Independent Test**: Trigger delete flow and verify warning + second confirmation + fallback support dialog behavior; cancellation exits safely with no account change.

### Tests for User Story 9

- [x] T071 [P] [US9] Add widget test for double-confirmation delete flow in rideshare/test/widget/settings/account_deletion_test.dart
- [x] T072 [P] [US9] Add widget test for backend-unavailable Contact Support fallback dialog in rideshare/test/widget/settings/account_deletion_test.dart

### Implementation for User Story 9

- [x] T073 [US9] Implement danger-zone delete account tile and dialog entry in rideshare/lib/screens/settings/settings_screen.dart
- [x] T074 [US9] Implement irreversible warning and second confirmation logic in rideshare/lib/screens/settings/settings_screen.dart
- [x] T075 [US9] Implement backend-unavailable fallback to WhatsApp/email support dialog in rideshare/lib/screens/settings/settings_screen.dart
- [x] T076 [US9] Add account deletion localized copy and warnings in rideshare/lib/l10n/app_ar.arb
- [x] T077 [US9] Add account deletion localized copy and warnings in rideshare/lib/l10n/app_en.arb

**Checkpoint**: US9 is independently functional and testable.

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Feature hardening and final validation across all stories.

- [x] T078 [P] Add final settings localization key consistency pass in rideshare/lib/l10n/app_ar.arb
- [x] T079 [P] Add final settings localization key consistency pass in rideshare/lib/l10n/app_en.arb
- [x] T080 Run full settings widget test suite and fix regressions in rideshare/test/widget/settings/
- [x] T081 Execute quickstart smoke checklist and record outcomes in specs/005-settings-screen/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup.
- **User Stories (Phase 3-11)**: Depend on Foundational completion.
- **Polish (Phase 12)**: Depends on all selected stories being complete.

### User Story Dependencies

- **US1 (P1)**: Starts after Foundational; no dependency on other stories.
- **US2 (P1)**: Starts after Foundational; no dependency on other stories.
- **US3 (P1)**: Starts after Foundational; no dependency on other stories.
- **US4 (P2)**: Starts after Foundational; may reuse settings shell from US3.
- **US5 (P2)**: Starts after Foundational; may reuse settings shell from US3.
- **US6 (P2)**: Starts after Foundational; may reuse settings shell from US3.
- **US7 (P3)**: Starts after Foundational; may reuse role data logic from US5.
- **US8 (P3)**: Starts after Foundational; independent from other feature logic.
- **US9 (P3)**: Starts after Foundational; reuses support contact helpers from US8.

### Recommended Delivery Order

1. Complete Phase 1 and Phase 2.
2. Deliver P1 stories in this order: US3, US1, US2.
3. Deliver P2 stories in this order: US4, US5, US6.
4. Deliver P3 stories in this order: US7, US8, US9.
5. Execute Phase 12 polish and regression validation.

### Parallel Opportunities

- **Foundational**: T006/T007 and T009/T010/T011/T012/T013 can run in parallel.
- **US1**: T015 and T016 in parallel, then implementation sequence.
- **US2**: T022 and T023 in parallel, then implementation sequence.
- **US3**: T028 and T029 in parallel, then implementation sequence.
- **US4**: T034 and T035 in parallel; T038 and localization tasks can be parallel after T036.
- **US5**: T042 and T043 in parallel; localization tasks parallel after screen scaffolding.
- **US6**: T049 and T050 in parallel; T052 and T055/T056 parallel after service API.
- **US7**: T057 and T058 in parallel; T061/T062 parallel with route logic.
- **US8**: T063 and T064 in parallel; T065 and T066 can be parallel, then integration.
- **US9**: T071 and T072 in parallel; localization tasks parallel after flow implementation.

---

## Parallel Example: User Story 4

```bash
# Parallel tests
Task: "T034 [US4] Add widget test for notification master toggle behavior in rideshare/test/widget/settings/notification_settings_test.dart"
Task: "T035 [US4] Add widget test for notification category toggle persistence in rideshare/test/widget/settings/notification_settings_test.dart"

# Parallel implementation after service API exists
Task: "T038 [US4] Create detailed notification settings screen UI in rideshare/lib/screens/settings/notification_settings_screen.dart"
Task: "T040 [US4] Add notification labels and category text in rideshare/lib/l10n/app_ar.arb"
Task: "T041 [US4] Add notification labels and category text in rideshare/lib/l10n/app_en.arb"
```

## Parallel Example: User Story 8

```bash
# Parallel implementation for independent files
Task: "T065 [US8] Create about screen with version, rate, share, and licenses actions in rideshare/lib/screens/settings/about_screen.dart"
Task: "T066 [US8] Create reusable in-app browser screen for legal pages in rideshare/lib/screens/settings/in_app_browser_screen.dart"
Task: "T069 [US8] Add about/support localized strings in rideshare/lib/l10n/app_ar.arb"
Task: "T070 [US8] Add about/support localized strings in rideshare/lib/l10n/app_en.arb"
```

---

## Implementation Strategy

### MVP First (User Stories 3, 1, 2)

1. Finish Setup + Foundational.
2. Implement US3 to unlock all settings entry points.
3. Implement US1 (theme control) and US2 (language switching).
4. Validate MVP behavior with widget tests and quick smoke run.

### Incremental Delivery

1. Ship MVP (US3 + US1 + US2).
2. Add control layers: US4 (notifications), US5 (account/security), US6 (privacy).
3. Add convenience/compliance: US7 (shortcuts), US8 (about/legal/support), US9 (account deletion).
4. Finish with polish and full regression suite.

### Validation Rules Applied

- All tasks use required checklist format: `- [ ] Txxx [P?] [US?] Description with file path`.
- Every user-story task includes `[USx]` label.
- Setup, Foundational, and Polish tasks intentionally omit story labels.
- Task IDs are sequential from T001 to T081.
