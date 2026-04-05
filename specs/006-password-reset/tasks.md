# Tasks: Password Reset & Update

**Input**: Design documents from `/specs/006-password-reset/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), data-model.md, contracts/api-endpoints.md

**Tests**: Tests are OPTIONAL — not explicitly requested in the spec. No test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Backend**: `rideshare-backend/src/` and `rideshare-backend/test/`
- **Mobile**: `rideshare/lib/`
- Adjust paths based on plan.md structure

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the new entity, modify the user entity, and create all DTOs needed across user stories.

- [X] T001 Create PasswordResetSession entity in `rideshare-backend/src/database/entities/password-reset-session.entity.ts` with fields: id (UUID PK), phoneNumber (string, indexed), otpCode (string, bcrypt-hashed), isVerified (boolean, default false), attemptCount (number, default 0), isLocked (boolean, default false), createdAt (timestamp), expiresAt (timestamp). Follow the existing entity pattern from `pending-registration.entity.ts`.
- [X] T002 [P] Add `passwordChangedAt` column (timestamp, nullable, default null) to UserEntity in `rideshare-backend/src/database/entities/user.entity.ts`. This field tracks when the password was last changed for JWT stale-token detection.
- [X] T003 [P] Create ForgotPasswordDto in `rideshare-backend/src/modules/auth/dto/forgot-password.dto.ts` with `phoneNumber` field validated as E.164 format using `@Matches(/^\+[1-9]\d{1,14}$/)`. Follow the validation pattern from `send-otp.dto.ts`.
- [X] T004 [P] Create VerifyResetOtpDto in `rideshare-backend/src/modules/auth/dto/verify-reset-otp.dto.ts` with `phoneNumber` (E.164) and `code` (6 digits, `@Matches(/^\d{6}$/)`) fields.
- [X] T005 [P] Create ResetPasswordDto in `rideshare-backend/src/modules/auth/dto/reset-password.dto.ts` with `resetToken` (string, non-empty) and `newPassword` (8+ chars, `@Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/)`) fields.
- [X] T006 [P] Create ChangePasswordDto in `rideshare-backend/src/modules/auth/dto/change-password.dto.ts` with `currentPassword` (string, non-empty) and `newPassword` (8+ chars, same pattern as ResetPasswordDto) fields.
- [X] T007 Register PasswordResetSession entity in the TypeORM configuration and update auth.module.ts in `rideshare-backend/src/modules/auth/auth.module.ts` to import any needed repository/provider for the new entity.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Backend service methods that are shared across or prerequisite to multiple user stories.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T008 Implement `forgotPassword` method in `rideshare-backend/src/modules/auth/auth.service.ts`. Logic: (1) Find user by phoneNumber where isPhoneVerified=true. (2) If not found, return generic success message (FR-012). (3) Invalidate any existing active session for that phone number. (4) Generate 6-digit OTP, hash with bcrypt, create PasswordResetSession with 10-min expiresAt. (5) Send OTP via existing `sendPhoneOtp` or directly via Twilio/local provider. (6) Return generic success message.
- [X] T009 Implement `verifyResetOtp` method in `rideshare-backend/src/modules/auth/auth.service.ts`. Logic: (1) Find active (non-expired, non-completed) session by phoneNumber. (2) If not found, throw 404. (3) If session isLocked, throw 400 "Too many attempts". (4) If expired, throw 400 "Code expired". (5) Compare OTP with bcrypt.compare. (6) If wrong, increment attemptCount, lock if >=5, throw 400 with attemptsRemaining. (7) If correct, set isVerified=true, generate short-lived resetToken JWT (5 min TTL) encoding sessionId and phoneNumber, return it.
- [X] T010 Implement `resetPassword` method in `rideshare-backend/src/modules/auth/auth.service.ts`. Logic: (1) Verify resetToken JWT, extract sessionId and phoneNumber. (2) Find session by id, verify it exists, isVerified=true, not expired. (3) Find user by phoneNumber. (4) Verify newPassword is not same as current (bcrypt.compare). (5) Hash new password with bcrypt (12 rounds). (6) Update user.passwordHash, set user.passwordChangedAt to now(), clear user.refreshToken. (7) Mark session isUsed/completed. (8) Return success message.
- [X] T011 Implement `changePassword` method in `rideshare-backend/src/modules/auth/auth.service.ts`. Logic: (1) Check if user.passwordHash exists — if null, throw 403 "Not available for social login". (2) Compare currentPassword with user.passwordHash (bcrypt.compare). (3) If wrong, throw 400 "Current password is incorrect". (4) Verify newPassword !== currentPassword (bcrypt.compare). (5) Hash new password, update user.passwordHash, set passwordChangedAt, clear refreshToken. (6) Return success message.
- [X] T012 Update the existing JWT strategy in `rideshare-backend/src/modules/auth/strategies/jwt.strategy.ts` to check `passwordChangedAt`. If the user's `passwordChangedAt` is set and the token's `iat` (issued at) is before `passwordChangedAt`, reject the token by throwing Unauthorized. This ensures all sessions are invalidated after a password change (FR-015).

**Checkpoint**: Backend service layer complete — all 4 endpoint handlers are implemented.

---

## Phase 3: User Story 1 — Forgot Password via SMS OTP (Priority: P1)

**Goal**: User can recover their account by entering phone number, verifying SMS OTP, and setting a new password.

**Independent Test**: Enter a registered phone number, receive OTP (check console in local dev), verify it, set new password, sign in with new password.

### Backend Implementation for User Story 1

- [X] T013 [P] [US1] Replace placeholder `forgotPassword` endpoint in `rideshare-backend/src/modules/auth/auth.controller.ts` with proper implementation: `@Post('forgot-password') @Public()`, accept `ForgotPasswordDto` body, call `authService.forgotPassword(dto.phoneNumber)`, return generic 200 message. Add Swagger `@ApiOperation` and `@ApiResponse` decorators.
- [X] T014 [P] [US1] Add `verifyResetOtp` endpoint in `rideshare-backend/src/modules/auth/auth.controller.ts`: `@Post('verify-reset-otp') @Public()`, accept `VerifyResetOtpDto` body, call `authService.verifyResetOtp(dto)`, return message + resetToken. Add Swagger decorators.
- [X] T015 [P] [US1] Add `resetPassword` endpoint in `rideshare-backend/src/modules/auth/auth.controller.ts`: `@Post('reset-password') @Public()`, accept `ResetPasswordDto` body, call `authService.resetPassword(dto)`, return success message. Add Swagger decorators. Note: This replaces the existing placeholder `resetPassword` endpoint.

### Flutter Implementation for User Story 1

- [X] T016 [P] [US1] Add forgot password API methods to `rideshare/lib/core/services/auth_service.dart`: `forgotPassword(String phoneNumber)`, `verifyResetOtp(String phoneNumber, String code)` returning resetToken, `resetPassword(String resetToken, String newPassword)`. Follow the existing HTTP call patterns using ApiClient.
- [X] T017 [P] [US1] Add password reset localization strings to `rideshare/lib/core/constants/app_strings.dart`: Arabic and English strings for "Forgot Password", "Enter your phone number", "Send Code", "Enter verification code", "Set new password", "Confirm new password", "Password reset successfully", error messages (invalid code, expired code, too many attempts, password too weak, passwords don't match).
- [X] T018 [US1] Create ForgotPasswordScreen in `rideshare/lib/screens/auth/forgot_password_screen.dart`. UI: phone number input field with E.164 validation, "Send Code" button using Teal primary color, loading state, link back to sign-in. Follow the existing screen patterns (Tajawal font, RTL support, bilingual text via AppStrings, design token spacing). Navigate to ResetPasswordScreen on success.
- [X] T019 [US1] Create ResetPasswordScreen in `rideshare/lib/screens/auth/reset_password_screen.dart`. UI: two-step flow — (1) 6-digit OTP input matching the existing OTPVerificationScreen pattern with 60-second resend timer and "Resend Code" button, (2) after OTP verified: new password field + confirm password field with strength indicator (8+ chars, letter+number). Submit calls resetPassword API. On success, navigate to sign-in screen with success message. Include error states for each step.
- [X] T020 [US1] Add "Forgot Password?" link to the sign-in screen in `rideshare/lib/screens/auth/sign_in_screen.dart`. Place it below the password field, aligned to the start side (RTL-aware). On tap, navigate to ForgotPasswordScreen. Use textSecondary color, not the primary Teal.
- [X] T021 [US1] Register new routes in `rideshare/lib/main.dart` RouteNames: `forgotPassword = '/forgot-password'` and `resetPassword = '/reset-password'`. Add MaterialPageRoute entries that pass phoneNumber and other args via `Map<String, dynamic>`.

**Checkpoint**: At this point, User Story 1 is fully functional — users can tap "Forgot Password" on sign-in, enter phone, verify OTP, set new password, and sign in.

---

## Phase 4: User Story 2 — Update Password from Settings (Priority: P2)

**Goal**: Logged-in users can change their password from Settings by providing current password and new password.

**Independent Test**: Sign in, go to Settings > Account & Security > Change Password, enter current + new password, verify old password no longer works.

### Backend Implementation for User Story 2

- [X] T022 [US2] Add `changePassword` endpoint in `rideshare-backend/src/modules/auth/auth.controller.ts`: `@Post('change-password') @UseGuards(JwtAuthGuard)`, accept `ChangePasswordDto` body, extract user from `@Request()`, call `authService.changePassword(user.id, dto)`. Add Swagger decorators.

### Flutter Implementation for User Story 2

- [X] T023 [P] [US2] Add `changePassword` API method to `rideshare/lib/core/services/auth_service.dart`: `changePassword(String currentPassword, String newPassword)`. Requires JWT token in Authorization header. Follow existing authenticated API call pattern.
- [X] T024 [P] [US2] Add change password localization strings to `rideshare/lib/core/constants/app_strings.dart`: Arabic and English strings for "Change Password", "Current Password", "New Password", "Confirm New Password", "Password changed successfully", error messages (current password incorrect, same password, social login not applicable).
- [X] T025 [US2] Create ChangePasswordScreen in `rideshare/lib/screens/settings/change_password_screen.dart`. UI: current password field (with visibility toggle), new password field with strength indicator (8+ chars, letter+number), confirm new password field, "Change Password" submit button. Validate: new password matches confirmation, meets strength requirements. Show success dialog then navigate to sign-in (tokens invalidated). Handle social login users — show message that password change is not available. Follow existing screen patterns (Tajawal, RTL, design tokens).
- [X] T026 [US2] Enable the disabled "Change Password" tile in `rideshare/lib/screens/settings/settings_screen.dart`. Remove the "Coming Soon" / "قريباً" badge and the disabled state. On tap, navigate to ChangePasswordScreen. Keep the tile under "Account & Security" section.
- [X] T027 [US2] Register change password route in `rideshare/lib/main.dart` RouteNames: `changePassword = '/change-password'`. Add MaterialPageRoute entry.

**Checkpoint**: User Stories 1 AND 2 both work independently. Users can recover accounts via OTP AND change passwords from settings.

---

## Phase 5: User Story 3 — Rate Limiting & Security (Priority: P3)

**Goal**: The system enforces cooldown, attempt limits, session expiry, and OTP reuse prevention.

**Independent Test**: Attempt rapid OTP resends, enter wrong OTP 5 times, reuse a consumed OTP, wait 10+ minutes and attempt to use an expired session.

### Backend Implementation for User Story 3

- [X] T028 [US3] Add 60-second cooldown check to the `forgotPassword` method in `rideshare-backend/src/modules/auth/auth.service.ts`. Before creating a new session, query for the most recent session for that phone number. If it exists and was created less than 60 seconds ago, throw a 429 error with `retryAfter` seconds remaining. This was partially covered in T008 but ensure the cooldown query is efficient using the phoneNumber index.
- [X] T029 [US3] Verify the 5-attempt lockout logic in `verifyResetOtp` method in `rideshare-backend/src/modules/auth/auth.service.ts`. Confirm that: (1) `attemptCount` is incremented on each incorrect OTP, (2) `isLocked` is set to true when `attemptCount >= 5`, (3) locked sessions return 400 with clear message, (4) the lockout persists across requests (not reset on retry). This was designed in T009 — validate it's correctly implemented.
- [X] T030 [US3] Add OTP reuse prevention and session expiry validation in `resetPassword` method in `rideshare-backend/src/modules/auth/auth.service.ts`. Ensure: (1) after successful password reset, the session cannot be used again (mark as completed), (2) if session is expired (expiresAt < now), reject the request, (3) if session isVerified is false, reject (OTP not verified). This was designed in T010 — validate the guards are in place.

### Flutter Implementation for User Story 3

- [X] T031 [US3] Add error handling for rate limiting and security states in `rideshare/lib/screens/auth/reset_password_screen.dart`. Handle: (1) 429 response on resend — show countdown timer with `retryAfter` value instead of allowing resend, (2) locked session (400 "Too many attempts") — show error and navigate back to ForgotPasswordScreen, (3) expired session (400 "Code expired") — show error with "Request new code" action. Update `auth_error_formatter.dart` in `rideshare/lib/core/utils/auth_error_formatter.dart` with new `AuthAction` types for password reset if needed.

**Checkpoint**: All three user stories are fully functional. Security measures prevent abuse.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final touches affecting multiple user stories.

- [X] T032 [P] Add Swagger `@ApiTags('Auth')` and `@ApiBearerAuth()` decorators to all new endpoints in `rideshare-backend/src/modules/auth/auth.controller.ts` for consistent API documentation.
- [X] T033 [P] Add auth BLoC events and states in `rideshare/lib/bloc/auth/auth_event.dart` and `rideshare/lib/bloc/auth/auth_state.dart` for password reset flow: `AuthForgotPassword`, `AuthVerifyResetOTP`, `AuthResetPassword` events; `AuthPasswordResetSent`, `AuthPasswordResetSuccess` states. Update the BLoC in `rideshare/lib/bloc/auth/auth_bloc.dart` to handle these events.
- [X] T034 Verify all new Flutter screens support RTL layout correctly. Test each screen in both Arabic (RTL) and English (LTR) modes: ForgotPasswordScreen, ResetPasswordScreen, ChangePasswordScreen. Ensure Directionality is respected, text alignment flips, and icon positions adjust.
- [X] T35 Run `npm run lint` in rideshare-backend and `flutter analyze` in rideshare to verify no linting errors in all new and modified files.
- [X] T036 Run the full forgot password and change password flows end-to-end as described in `specs/006-password-reset/quickstart.md` to validate the feature works as a complete user journey.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion (entities and DTOs must exist)
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion (service methods must exist)
- **User Story 2 (Phase 2)**: Depends on Phase 2 completion (service methods must exist). Independent of Phase 3.
- **User Story 3 (Phase 5)**: Depends on Phase 3 completion (builds on existing US1 implementation). Partially depends on Phase 4 if change-password rate limiting is added.
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Phase 2. No dependency on other stories.
- **User Story 2 (P2)**: Depends on Phase 2. No dependency on US1 — can be developed in parallel.
- **User Story 3 (P3)**: Depends on US1 being complete (validates and enhances US1 security). Independent of US2.

### Within Each User Story

- Backend endpoint tasks (T013-T015, T022) depend on service methods from Phase 2
- Flutter API methods (T016, T023) can start in parallel with backend endpoints
- Flutter screens (T018-T021, T025-T027) depend on their corresponding API methods
- Route registration (T021, T027) can happen in parallel with screen creation

### Parallel Opportunities

- **Phase 1**: All DTOs (T003-T006) can be created in parallel. T001 and T002 are parallel.
- **Phase 2**: T008-T012 are sequential (same file — auth.service.ts and jwt.strategy.ts)
- **Phase 3 backend**: T013, T014, T015 are parallel (different endpoints, same controller but additive)
- **Phase 3 Flutter**: T016 and T017 are parallel. T018 and T019 are sequential (T019 may reuse T018 patterns)
- **Phase 4**: T023 and T024 are parallel. T022 is independent of Flutter tasks.
- **Phase 5**: T028, T029, T030 are validation tasks that may be parallel if on different code sections
- **Phase 6**: T032 and T033 are parallel

---

## Parallel Example: Phase 3 (User Story 1)

```text
# Backend endpoints (parallel):
Task T013: "Replace forgotPassword endpoint in auth.controller.ts"
Task T014: "Add verifyResetOtp endpoint in auth.controller.ts"
Task T015: "Add resetPassword endpoint in auth.controller.ts"

# Flutter API + strings (parallel):
Task T016: "Add forgot password API methods to auth_service.dart"
Task T017: "Add password reset localization strings to app_strings.dart"

# Flutter screens (sequential — T019 builds on T018 patterns):
Task T018: "Create ForgotPasswordScreen"
Task T019: "Create ResetPasswordScreen"
Task T020: "Add Forgot Password link to sign_in_screen.dart"
Task T021: "Register new routes in main.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (entities + DTOs)
2. Complete Phase 2: Foundational (service methods)
3. Complete Phase 3: User Story 1 (forgot password flow)
4. **STOP and VALIDATE**: Test the full forgot password flow end-to-end
5. Deploy/demo if ready — users can now recover accounts

### Incremental Delivery

1. Complete Setup + Foundational → Backend ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With backend and Flutter developers working in parallel:

1. **Backend dev**: Phase 1 → Phase 2 → Phase 3 backend tasks (T013-T015)
2. **Flutter dev**: Phase 1 DTOs review → Phase 3 Flutter tasks (T016-T021) once API contracts are clear
3. Flutter dev can start T016-T018 in parallel with backend Phase 2 using the API contracts as the interface

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 and US2 are independently implementable after Phase 2 completes
- US3 enhances US1 with security validations — implement after US1 works
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All Flutter screens MUST follow RTL-first design with Tajawal font and Teal brand color
