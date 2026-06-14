# Contract — Auth & Identity (Phase 1: `009-auth-hardening`)

All endpoints under `/auth` unless otherwise noted. JSON request/response. All error responses follow the existing project error envelope `{ statusCode, message, error, details? }`.

## Removed endpoints (breaking — covered by versioning policy and the social-login migration step)

| Method | Path | Status after this phase |
|---|---|---|
| POST | `/auth/register` (email/password) | **removed** — returns 410 Gone with body explaining phone-only |
| POST | `/auth/login` (email/password) | **removed** — same |
| GET | `/auth/google`, `/auth/google/callback` | **removed** for end users; admin-only login path retained at `/admin/auth/*` if ever needed |
| GET | `/auth/facebook`, `/auth/facebook/callback` | **removed** |

## Modified endpoints

### POST `/auth/send-otp` *(existing)*
Request unchanged. Response unchanged. Behavior change: when the phone resolves to an account that is `bannedAt IS NOT NULL`, return `403 ACCOUNT_BANNED` with `banReason` summary so the mobile app can render the ban screen without a separate roundtrip.

### POST `/auth/verify-otp` *(existing — extended)*
Request shape gains:
```json
{
  "phoneNumber": "+962790000000",
  "code": "123456",
  "device": {
    "deviceId": "<platform-stable id>",
    "fingerprint": "<sha256-hex>",  // optional; server can compute from server-issued installSalt
    "platform": "ios" | "android" | "web",
    "fcmToken": "..."
  }
}
```
Response shape gains:
```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "user": { ... },
  "deviceState": "trusted" | "new",
  "accountState": "active" | "restricted" | "banned",
  "pendingPhoneLinkRequired": false
}
```
Errors: `403 LOCATION_INTEGRITY_VIOLATION` not applicable here. `403 ACCOUNT_BANNED` if user is banned. `423 ACCOUNT_RESTRICTED` if `restricted=true` (banner shown; partial functionality only).

### POST `/auth/link-phone` *(existing — repurposed)*
Used by the social-login migration: a legacy social-login session that has `pendingPhoneLink=true` posts here with `phoneNumber` + verified `code`, server merges accounts (or creates a fresh phone-only account if not previously linked).

## New endpoints

### POST `/auth/devices` *(authenticated)*
Register a new device for the current user *without* completing a fresh OTP — used after token refresh from a known-trusted device that wants to update its `fcmToken`.
Request: `{ deviceId, fingerprint, platform, fcmToken }`.
Response: `{ id, isTrusted: true }`.

### GET `/auth/devices` *(authenticated)*
Returns the current user's `user_devices` list (excluding revoked) for the in-app "active sessions" UI.

### DELETE `/auth/devices/:deviceId` *(authenticated)*
User revokes one of their own devices. Response 204. Triggers JWT rejection at next API call from that device. The current device cannot revoke itself this way (returns `409 SELF_REVOKE_USE_LOGOUT`).

## Admin endpoints (under `/admin`)

### GET `/admin/account-flags`
Query params: `disposition?`, `severity?`, `from?`, `to?`, `cursor?`, `limit?`.
Returns paginated `account_flags` rows joined with the user.

### POST `/admin/account-flags/:id/clear`
Body `{ note? }`. Sets `disposition='cleared'`, `dispositionByAdminId`, `dispositionAt=now`. Sets `users.restricted=false` for the affected user if all of their flags are now cleared.

### POST `/admin/account-flags/:id/escalate`
Body `{ disposition: 'restricted' | 'banned', note }`. Sets disposition; if `banned`, sets `users.bannedAt`, `users.banReason`, and triggers the cascade in FR-044 (cancel pending bookings, notify counterparties).

### POST `/admin/users/:id/devices/:deviceId/revoke`
Same as user-side revoke but recorded with `revokedByAdminId`.

## Contract tests (added under `rideshare-backend/test/contract/auth/`)

- `verify-otp.contract.spec.ts` — covers happy path, ban response, restricted response, new-device branch with security-event log, and the legacy social-login pending-phone-link branch.
- `devices.contract.spec.ts` — list / register / delete; ensures cross-user attempts return 404 not 403 (no enumeration).
- `removed-paths.contract.spec.ts` — asserts the four removed endpoints return 410 with the documented body.
- `account-flags.contract.spec.ts` — admin only; non-admin gets 403; ordering and cursor pagination invariants.
