# Implementation Plan: Settings Screen

**Branch**: `005-settings-screen` | **Date**: 2026-03-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-settings-screen/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Build a comprehensive Settings screen for the RideShare Flutter app providing user control over appearance (dark mode/theme switching), language (Arabic ↔ English), notification preferences, account & security info, privacy controls, payment/wallet shortcuts, support section, about screen, and account deletion. All preferences are persisted locally via `SharedPreferences`. The feature wires up 4 currently non-functional buttons in the Profile tab and Side Drawer, making them navigate to the new Settings screen and its sub-screens. No new backend endpoints are required.

## Technical Context

**Language/Version**: Dart 3.9.2+ / Flutter (latest stable)
**Primary Dependencies**: flutter, provider ^6.1.2, flutter_bloc ^8.1.6, shared_preferences ^2.3.2, firebase_messaging ^15.1.3, url_launcher ^6.3.1, iconsax_plus ^1.0.0, google_fonts ^6.2.1, cached_network_image ^3.4.1
**New Dependencies**: package_info_plus (app version), share_plus (share app), webview_flutter (in-app browser for ToS/Privacy)
**Storage**: SharedPreferences (local user preferences), REST API backend (read-only for account info)
**Testing**: flutter_test (widget tests)
**Target Platform**: Android + iOS mobile app
**Project Type**: mobile-app (Flutter)
**Performance Goals**: <2s theme/language switch with instant visual feedback, 60fps UI animations
**Constraints**: Offline-capable local settings, bilingual AR/EN support, RTL ↔ LTR layout switching
**Scale/Scope**: ~50 screens, adding 1 main settings screen + 4 sub-screens (notification settings, account security, privacy settings, about)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Phase 0 Gate Evaluation

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety & Validation First | ✅ PASS | All settings models use explicit Dart types. Enums for ThemeMode, NotificationCategory. No `dynamic` or untyped maps. |
| II. Modular Architecture | ✅ PASS | Settings implemented as `screens/settings/` module with dedicated sub-screens, a `SettingsService` in `core/services/`, and reusable widgets. Follows existing pattern (screens/profile/, screens/payment/). |
| III. Test-First Development | ⚠️ ADAPTED | Constitution targets NestJS backend TDD. For this Flutter frontend feature, widget tests will cover key interactions (theme toggle, language switch, navigation). Integration tests verify persistence. The strict "test fails → implement → test passes" loop is adapted for UI widget testing. |
| IV. API-First Design | ✅ PASS | No new API endpoints needed — this is a local-preferences-only feature. Account info is read from existing `AuthProvider.userModel`. Existing wallet/payment history routes are reused. |
| V. Security & Data Protection | ✅ PASS | No sensitive data stored. Preferences are non-sensitive booleans/strings in SharedPreferences. Account deletion uses existing auth flow or "Contact Support" fallback. |

**Gate Result**: ✅ PASS — All principles satisfied or justified. Proceed to Phase 0.

### Post-Phase 1 Gate Re-evaluation

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety & Validation First | ✅ PASS | `UserPreferences` model uses typed fields. Enums: `AppThemeMode`, `NotificationCategory`. Settings service methods have explicit return types. |
| II. Modular Architecture | ✅ PASS | Clean separation: `SettingsService` (persistence logic), `SettingsScreen` (main UI), sub-screens for each section. No circular deps. |
| III. Test-First Development | ⚠️ ADAPTED | Widget tests planned for: theme toggle, language switch, navigation, preference persistence. See justification in Complexity Tracking. |
| IV. API-First Design | ✅ PASS | No new APIs. UI contracts defined in `contracts/settings-ui-contract.md`. |
| V. Security & Data Protection | ✅ PASS | No sensitive data. Account deletion is guarded by double-confirmation dialog. |

**Gate Result**: ✅ PASS

## Project Structure

### Documentation (this feature)

```text
specs/005-settings-screen/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── settings-ui-contract.md
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
rideshare/lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart          # Add new SharedPreferences keys
│   │   └── route_names.dart            # Add settings route names
│   ├── services/
│   │   ├── localization_service.dart   # Existing (no changes needed)
│   │   ├── settings_service.dart       # NEW: preferences persistence
│   │   └── theme_service.dart          # NEW: ThemeMode management (ChangeNotifier)
│   └── theme/
│       └── app_theme.dart              # Existing (no changes needed)
├── screens/
│   ├── home/
│   │   ├── home_drawer.dart            # MODIFY: wire Settings onTap
│   │   └── tabs/
│   │       └── profile_tab.dart        # MODIFY: wire Settings/Help/About onTaps
│   └── settings/                       # NEW: entire directory
│       ├── settings_screen.dart        # Main settings screen
│       ├── notification_settings_screen.dart
│       ├── account_security_screen.dart
│       ├── privacy_settings_screen.dart
│       └── about_screen.dart
├── models/
│   └── user_preferences.dart           # NEW: typed preferences model
├── main.dart                           # MODIFY: add ThemeService provider, wire themeMode
└── widgets/
    └── settings/                       # NEW: reusable settings widgets
        ├── settings_section.dart
        ├── settings_tile.dart
        └── settings_switch_tile.dart

rideshare/test/
└── widget/
    └── settings/                       # NEW: widget tests
        ├── settings_screen_test.dart
        ├── theme_toggle_test.dart
        └── language_switch_test.dart
```

**Structure Decision**: Follows existing single-project Flutter pattern. New settings screens go under `screens/settings/` matching the convention of `screens/profile/`, `screens/payment/`, etc. Shared services go in `core/services/`. The `ThemeService` is a new `ChangeNotifier` similar to `LocalizationService` for reactive theme management.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Test-First adapted (not strict TDD) | Flutter widget tests require UI scaffolding (MaterialApp, providers). Writing failing tests first is impractical for individual widget renders. | Strict backend-style TDD doesn't map to Flutter widget testing workflow. Widget tests are written alongside implementation, verifying behavior after UI composition. Coverage target of key interactions maintained. |
