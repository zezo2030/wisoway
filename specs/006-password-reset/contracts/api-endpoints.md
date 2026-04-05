# API Contracts: Password Reset & Update

**Feature Branch**: `006-password-reset`
**Date**: 2026-04-03
**Base Path**: `/api/v1/auth`

---

## 1. POST /auth/forgot-password

Request a password reset by phone number. Sends a 6-digit OTP via SMS.

**Auth**: Public (no JWT required)

### Request

```json
{
  "phoneNumber": "+201234567890"
}
```

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| phoneNumber | string | yes | E.164 format | User's registered phone number |

### Response — 200 OK (always, even if phone not found)

```json
{
  "message": "If this phone number is registered, a verification code has been sent."
}
```

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 429 | Cooldown active (< 60s since last request) | `{ "message": "Please wait before requesting another code.", "retryAfter": 42 }` |
| 400 | Phone number format invalid | `{ "message": "Phone number must be in E.164 format" }` |

### Behavior Notes

- Always returns 200 to prevent phone number enumeration (FR-012)
- Internally: if phone exists AND is verified, create a `PasswordResetSession` and send OTP
- Internally: if phone not found or not verified, do nothing but still return 200
- Invalidates any existing active session for that phone number before creating new one

---

## 2. POST /auth/verify-reset-otp

Verify the OTP code sent during password reset. Does NOT reset the password — marks the session as verified so the user can proceed to set a new password.

**Auth**: Public (no JWT required)

### Request

```json
{
  "phoneNumber": "+201234567890",
  "code": "123456"
}
```

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| phoneNumber | string | yes | E.164 format | Must match the forgot-password request |
| code | string | yes | 6 digits | The OTP code received via SMS |

### Response — 200 OK

```json
{
  "message": "Verification successful. You may now set a new password.",
  "resetToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

| Field | Type | Description |
|-------|------|-------------|
| resetToken | string | Short-lived JWT (5 min) authorizing the password reset. Required for the reset-password endpoint. |

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 400 | OTP incorrect | `{ "message": "Invalid verification code", "attemptsRemaining": 3 }` |
| 400 | Session locked (5 failed attempts) | `{ "message": "Too many attempts. Please request a new code." }` |
| 400 | Session expired (10 min) | `{ "message": "Verification code has expired. Please request a new one." }` |
| 404 | No active session found | `{ "message": "No active reset session found. Please request a new code." }` |

### Behavior Notes

- Increments `attemptCount` on incorrect OTP
- Sets `isLocked = true` when `attemptCount >= 5`
- Returns `resetToken` (a short-lived JWT) on success — this is required to call `reset-password`
- `resetToken` encodes the `sessionId` and `phoneNumber`

---

## 3. POST /auth/reset-password

Set a new password after successful OTP verification.

**Auth**: Requires valid `resetToken` from verify-reset-otp step

### Request

```json
{
  "resetToken": "eyJhbGciOiJIUzI1NiIs...",
  "newPassword": "NewPass123"
}
```

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| resetToken | string | yes | Valid JWT from verify step | Authorizes this password reset |
| newPassword | string | yes | 8+ chars, at least 1 letter + 1 number | The new password |

### Response — 200 OK

```json
{
  "message": "Password has been reset successfully."
}
```

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 400 | resetToken invalid or expired | `{ "message": "Reset session has expired. Please start over." }` |
| 400 | Password too weak | `{ "message": "Password must be at least 8 characters with at least one letter and one number" }` |
| 400 | Password same as current | `{ "message": "New password must be different from current password" }` |
| 404 | Session not found or already used | `{ "message": "Invalid or expired reset session." }` |

### Behavior Notes

- Consumes the reset session (marks as Completed)
- Updates `user.passwordHash` with new bcrypt hash
- Sets `user.passwordChangedAt` to current time
- Clears `user.refreshToken` to invalidate existing sessions
- The `resetToken` expires after 5 minutes (separate from the session's 10-min TTL)

---

## 4. POST /auth/change-password

Change password for an authenticated user. Requires current password.

**Auth**: JWT required (`@UseGuards(JwtAuthGuard)`)

### Request

```json
{
  "currentPassword": "OldPass123",
  "newPassword": "NewPass456"
}
```

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| currentPassword | string | yes | non-empty | User's current password |
| newPassword | string | yes | 8+ chars, at least 1 letter + 1 number | Desired new password |

### Response — 200 OK

```json
{
  "message": "Password changed successfully."
}
```

### Error Responses

| Status | Condition | Body |
|--------|-----------|------|
| 400 | Current password incorrect | `{ "message": "Current password is incorrect" }` |
| 400 | Password too weak | `{ "message": "Password must be at least 8 characters with at least one letter and one number" }` |
| 400 | New password same as current | `{ "message": "New password must be different from current password" }` |
| 403 | Social login user (no password) | `{ "message": "Password change is not available for social login accounts" }` |

### Behavior Notes

- Checks if user has a `passwordHash` — rejects social login users
- Compares `currentPassword` against `user.passwordHash` using bcrypt
- Updates `user.passwordHash`, sets `passwordChangedAt`, clears `refreshToken`
- Client should sign the user out after success (tokens are now invalid)
