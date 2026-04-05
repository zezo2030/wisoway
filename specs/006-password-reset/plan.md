# Implementation Plan: Password Reset & Update

**Branch**: `006-password-reset` | **Date**: 2026-04-03 | **Spec**: `specs/006-password-reset/spec.md`
**Input**: Feature specification from `/specs/006-password-reset/spec.md`

## Summary

Implement a complete password reset and update system for the RedShare platform. The feature adds two user flows: (1) forgot password — users recover accounts via SMS OTP sent to their verified phone number, then set a new password; (2) change password — authenticated users update their password by providing the current password. The backend already has placeholder endpoints and a working Twilio OTP system. The feature spans the NestJS backend (new entity, DTOs, service logic, 4 endpoints) and the Flutter app (3 new screens, route additions, auth service methods).

## Technical Context

**Language/Version**: TypeScript 5.7 (backend), Dart 3.x / Flutter 3.9.2 (mobile)
**Primary Dependencies**: NestJS 11.x, TypeORM, bcrypt, Twilio (backend); Flutter BLoC, dio/http client (mobile)
**Storage**: PostgreSQL (primary), existing Twilio SMS for OTP delivery
**Testing**: Jest (backend), Flutter test (mobile)
**Target Platform**: Node.js server + Android/iOS mobile
**Project Type**: Mobile app + API (backend + Flutter frontend)
**Performance Goals**: OTP delivery < 30s, password reset flow < 2 min end-to-end
**Constraints**: 10-min session TTL, 60s OTP cooldown, 5-attempt lockout
**Scale/Scope**: Existing user base, 4 new API endpoints, 3 new Flutter screens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Type Safety & Validation | PASS | All DTOs will use class-validator; Flutter models will use explicit types |
| II. Modular Architecture | PASS | Backend extends existing auth module; Flutter adds screens to existing auth flow |
| III. Test-First Development | PASS | Tests planned for all 4 endpoints and critical Flutter widget flows |
| IV. API-First Design | PASS | Contracts defined in `contracts/api-endpoints.md` before implementation |
| V. Security & Data Protection | PASS | bcrypt hashing, JWT reset tokens, session invalidation, rate limiting, no phone enumeration |
| VI. RTL-First & Localization | PASS | All new Flutter screens will use localization service and RTL layout |
| VII. Design System Compliance | PASS | Screens will use Tajawal font, Teal brand color, Iconsax Plus, design token spacing |

**Post-Phase 1 Re-check**: All principles still satisfied. The `PasswordResetSession` entity follows the same patterns as existing entities. API contracts follow the existing `/api/v1/auth/` prefix and response format. Flutter screens match the existing OTP verification pattern.

## Project Structure

### Documentation (this feature)

```text
specs/006-password-reset/
├── plan.md              # This file
├── research.md          # Phase 0 — design decisions
├── data-model.md        # Phase 1 — entity schemas
├── quickstart.md        # Phase 1 — dev/test guide
├── contracts/
│   └── api-endpoints.md # Phase 1 — API contracts
└── tasks.md             # Phase 2 — task list (via /speckit.tasks)
```

### Source Code (repository root)

```text
rideshare-backend/
├── src/
│   ├── database/
│   │   └── entities/
│   │       ├── password-reset-session.entity.ts   # NEW
│   │       └── user.entity.ts                      # MODIFIED (add passwordChangedAt)
│   ├── modules/
│   │   └── auth/
│   │       ├── auth.controller.ts                  # MODIFIED (4 endpoints)
│   │       ├── auth.service.ts                     # MODIFIED (5 new methods)
│   │       ├── auth.module.ts                      # MODIFIED (import new entity)
│   │       └── dto/
│   │           ├── forgot-password.dto.ts           # NEW
│   │           ├── verify-reset-otp.dto.ts          # NEW
│   │           ├── reset-password.dto.ts            # NEW
│   │           └── change-password.dto.ts           # NEW
│   └── modules/users/
│       └── users.service.ts                        # MODIFIED (passwordChangedAt logic)
└── test/
    └── auth/
        ├── auth.controller.spec.ts                  # MODIFIED
        └── auth.service.spec.ts                     # MODIFIED

rideshare/
├── lib/
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── sign_in_screen.dart                 # MODIFIED (add forgot password link)
│   │   │   ├── forgot_password_screen.dart          # NEW
│   │   │   └── reset_password_screen.dart           # NEW
│   │   └── settings/
│   │       ├── settings_screen.dart                 # MODIFIED (enable change password tile)
│   │       └── change_password_screen.dart          # NEW
│   ├── core/
│   │   ├── services/
│   │   │   └── auth_service.dart                    # MODIFIED (4 new methods)
│   │   ├── constants/
│   │   │   └── app_strings.dart                     # MODIFIED (new localization strings)
│   │   └── utils/
│   │       └── auth_error_formatter.dart            # MODIFIED (new action types)
│   ├── bloc/
│   │   └── auth/
│   │       ├── auth_event.dart                      # MODIFIED (3 new events)
│   │       └── auth_state.dart                      # MODIFIED (new states)
│   └── main.dart                                    # MODIFIED (new routes)
└── test/
    └── screens/
        └── auth/
            ├── forgot_password_screen_test.dart      # NEW
            ├── reset_password_screen_test.dart       # NEW
            └── change_password_screen_test.dart      # NEW
```

**Structure Decision**: This feature extends the existing Mobile + API structure. Backend changes live in `rideshare-backend/src/modules/auth/` (new DTOs, modified controller/service). Flutter changes live in `rideshare/lib/screens/auth/` (new screens) and `rideshare/lib/screens/settings/` (new change password screen).

## Complexity Tracking

> No constitution violations detected. All changes follow existing patterns.
