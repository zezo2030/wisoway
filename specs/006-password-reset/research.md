# Research: Password Reset & Update

**Feature Branch**: `006-password-reset`
**Date**: 2026-04-03

## Decision 1: OTP Delivery Mechanism for Password Reset

**Decision**: Reuse the existing Twilio/local OTP provider infrastructure already used for phone verification.

**Rationale**: The backend already has a fully implemented OTP system in `AuthService` with dual provider support (Twilio for production, local for development). The `sendPhoneOtp()` and `verifyPhoneOtp()` methods handle generation, delivery, and verification. Reusing this avoids duplicating SMS infrastructure and keeps the OTP behavior consistent across registration and password reset.

**Alternatives considered**:
- Email-based reset links: Rejected — the app is phone-first and most users registered via phone. No email sending service is currently configured.
- Separate OTP table for reset: Rejected — will use a dedicated `password_reset_sessions` table instead, since the existing `pending_registrations` pattern is registration-specific and the `otp_codes` table is tied to phone verification.

---

## Decision 2: Reset Session Storage

**Decision**: Create a new `PasswordResetSession` entity/table with fields: `id`, `phoneNumber`, `otpCode`, `isVerified`, `attemptCount`, `createdAt`, `expiresAt`.

**Rationale**: Unlike the existing `PendingRegistration` (which stores pre-registration user data), a password reset session is a lightweight, single-purpose record. It needs to track attempt count (for the 5-attempt lockout), verification status (gating the password update step), and expiration. The existing `OtpCode` entity/model is too simplistic — it only stores code + phone + used flag, with no attempt counting or session state.

**Alternatives considered**:
- Redis-based session: Faster TTL handling but adds operational complexity and loses auditability. Not worth it for low-frequency password resets.
- Reuse `pending_registrations`: Wrong semantics — that table is for registration data (name, email, gender, role), not session management.

---

## Decision 3: Password Change Endpoint (Logged-in Users)

**Decision**: Add a new `POST /auth/change-password` endpoint (separate from the reset flow) requiring JWT authentication, current password, and new password.

**Rationale**: The spec requires logged-in users to provide their current password when changing it. This is fundamentally different from the reset flow (which uses OTP). A separate endpoint keeps the concerns clean: `forgot-password`/`reset-password` are public (unauthenticated), `change-password` is authenticated. The existing `@UseGuards(JwtAuthGuard)` pattern applies directly.

**Alternatives considered**:
- Combine into the existing `reset-password` endpoint: Rejected — different auth requirements (OTP vs current password) and different user contexts (anonymous vs authenticated).

---

## Decision 4: Token Invalidation After Password Change

**Decision**: On password change/reset, delete the user's `refreshToken` field and maintain a `passwordChangedAt` timestamp on the user entity. The JWT strategy will check `passwordChangedAt` against token `iat` to reject stale tokens.

**Rationale**: Simply clearing the refresh token only blocks refresh attempts. Access tokens remain valid for up to 15 minutes. Adding `passwordChangedAt` to the user entity and checking it in the JWT strategy ensures all pre-change tokens are immediately invalidated — matching FR-015's requirement for full session sign-out.

**Alternatives considered**:
- Token blacklist in Redis: Over-engineered for this use case — adds Redis dependency to the auth flow.
- Only clear refresh token: Insufficient — access tokens would remain valid for 15 minutes.

---

## Decision 5: Flutter Screen Architecture

**Decision**: Create three new screens in the existing screen structure (not Clean Architecture features), following the patterns already used in `sign_in_screen.dart` and `otp_verification_screen.dart`.

**Rationale**: The existing auth screens are organized under `lib/screens/auth/` and use a simpler pattern than the full Clean Architecture (no BLoC for individual screens, direct service calls with setState). The OTP verification screen already implements the exact UX pattern needed (6-digit input, 60s timer, resend). Matching this existing pattern keeps the codebase consistent.

**Alternatives considered**:
- Full BLoC with Clean Architecture: Over-engineered for what are essentially 3 screen-level flows. The existing auth screens don't use this pattern.
- Reuse the existing OTP verification screen: Rejected — the reset OTP screen has different post-verification behavior (navigate to set-password vs create account). Forking the logic would create coupling.

---

## Decision 6: Password Strength Validation

**Decision**: Enforce 8+ characters with at least one letter and one number. Validate on both frontend (immediate feedback) and backend (authoritative).

**Rationale**: This matches the spec's FR-005 and is consistent with the existing `sign-up.dto.ts` which uses `@MinLength(8)`. Adding a `@Matches()` regex on the backend and a corresponding validator on the Flutter frontend keeps both layers consistent.

**Alternatives considered**:
- More complex rules (special chars, uppercase): Over-engineered for the user base. The spec explicitly defines "at least 8 characters, including a number and a letter".
