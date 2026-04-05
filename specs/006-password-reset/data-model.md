# Data Model: Password Reset & Update

**Feature Branch**: `006-password-reset`
**Date**: 2026-04-03

## New Entity: PasswordResetSession

Stores in-progress password reset sessions. One active session per phone number at a time — requesting a new reset invalidates any existing session.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, auto-generated | Unique session identifier |
| `phoneNumber` | string | NOT NULL, indexed | E.164 format phone number |
| `otpCode` | string | NOT NULL | Hashed 6-digit OTP (bcrypt) |
| `isVerified` | boolean | NOT NULL, default false | Whether OTP has been verified |
| `attemptCount` | number | NOT NULL, default 0 | Consecutive incorrect OTP attempts |
| `isLocked` | boolean | NOT NULL, default false | Locked after 5 failed attempts |
| `createdAt` | timestamp | NOT NULL, auto-set | Session creation time |
| `expiresAt` | timestamp | NOT NULL | Session expiration (createdAt + 10 min) |

### Indexes

| Fields | Type | Purpose |
|--------|------|---------|
| `phoneNumber` | B-tree | Fast lookup by phone during reset flow |
| `expiresAt` | B-tree | TTL cleanup of expired sessions |

### State Transitions

```text
[Created] --OTP verified--> [Verified] --Password set--> [Completed]
[Created] --5 failed attempts--> [Locked]
[Created] --10 minutes pass--> [Expired]
```

- **Created**: Initial state after `forgot-password` request. OTP sent to phone.
- **Verified**: User entered correct OTP. Can now set a new password.
- **Completed**: Password successfully updated. Session is consumed.
- **Locked**: 5 consecutive incorrect OTP entries. User must wait and start over.
- **Expired**: 10 minutes elapsed. Session is no longer valid.

### Validation Rules

- `phoneNumber`: Must match E.164 format (`/^\+[1-9]\d{1,14}$/`)
- `otpCode`: Stored as bcrypt hash (never plaintext)
- `attemptCount`: Must be <= 5 before lockout triggers
- `expiresAt`: Must be exactly `createdAt + 10 minutes`

---

## Modified Entity: User (existing)

Add one field to the existing user entity to support token invalidation after password changes.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `passwordChangedAt` | timestamp | nullable, default null | When password was last changed |

### Impact on Existing Fields

| Field | Change | Reason |
|-------|--------|--------|
| `passwordHash` | Updated on reset/change | New bcrypt hash stored |
| `refreshToken` | Cleared on reset/change | Force re-authentication |
| `passwordChangedAt` | Set to `now()` on reset/change | Enable stale JWT detection |

### JWT Strategy Modification

The existing JWT strategy must check `passwordChangedAt`:
- If `passwordChangedAt` is set AND token `iat` < `passwordChangedAt`, reject the token
- This ensures all sessions are invalidated when password changes

---

## Data Flow: Forgot Password

```text
1. User enters phone number
2. Backend: Invalidate any existing session for that phone
3. Backend: Create new PasswordResetSession (status: Created)
4. Backend: Generate 6-digit OTP, hash it, store in session
5. Backend: Send OTP via SMS (Twilio or local provider)
6. User enters OTP code
7. Backend: Compare OTP with stored hash (bcrypt.compare)
8. Backend: If match → set isVerified=true, attemptCount=0
9. Backend: If mismatch → increment attemptCount, lock if >=5
10. User enters new password
11. Backend: Validate session is Verified and not Expired
12. Backend: Update user.passwordHash, set passwordChangedAt, clear refreshToken
13. Backend: Mark session as Completed
```

## Data Flow: Change Password (Authenticated)

```text
1. User enters current password + new password
2. Backend: Validate JWT (authenticated)
3. Backend: Compare current password with user.passwordHash (bcrypt.compare)
4. Backend: Reject if new password matches current password
5. Backend: Update user.passwordHash, set passwordChangedAt, clear refreshToken
6. Frontend: Sign user out (tokens are now invalid)
7. User redirected to sign-in
```
