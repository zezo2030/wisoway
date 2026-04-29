# Contract: Notification Device Registration

**Feature**: 007-app-ux-improvements
**Module**: `rideshare-backend/src/modules/notifications/notifications.controller.ts`
**Audience**: authenticated users (mobile app, passenger and driver roles)

This contract governs how the Flutter app registers and deregisters a
device's Firebase Cloud Messaging token with the backend so the backend can
push notifications to it. These are new endpoints added to the existing
`NotificationsModule`.

---

## POST `/notifications/devices`

**Purpose**: register (or refresh) the caller's FCM token for the current
authenticated device.

### Authentication

- Bearer JWT required (standard auth guard).

### Rate limit

- 30 requests / minute / IP (R6 in `research.md`).

### Request

```http
POST /notifications/devices
Content-Type: application/json
Authorization: Bearer <token>

{
  "token": "eX3…:APA91b…",           // FCM registration token
  "platform": "android" | "ios",      // device platform, lowercase
  "appVersion": "1.18.3"              // optional, semver, for diagnostics
}
```

### Validation

- `token` — required, non-empty, max 512 chars, printable ASCII.
- `platform` — required, enum (`android`, `ios`).
- `appVersion` — optional, semver string.

### Behavior

1. If a `DeviceToken` row exists for the exact `token` value:
   - If its `userId` equals the caller's id → update `lastSeenAt = now`,
     `isActive = true`.
   - If its `userId` differs (device handoff) → update `userId` to the
     caller, `isActive = true`, `lastSeenAt = now`.
2. Otherwise, insert a new `DeviceToken` row with `userId`, `token`,
   `platform`, `isActive = true`, `lastSeenAt = now`.
3. Emit an audit record (R8): `action='device.register'`, `userId`,
   `platform`, `tokenPrefix` (first 8 chars + `…`, never the full token),
   timestamp.
4. Emit a structured log (trigger=`device.register`, `userId`, `platform`).

### Response

- `201 Created` (new row) or `200 OK` (existing row updated):

```json
{
  "registered": true,
  "platform": "android",
  "lastSeenAt": "2026-04-23T10:15:00.000Z"
}
```

**Important**: the response MUST NOT include the token (R7).

### Errors

- `400 Bad Request` — validation failed.
- `401 Unauthorized` — missing/invalid bearer token.
- `429 Too Many Requests` — rate limit hit.

---

## DELETE `/notifications/devices/{token}`

**Purpose**: deregister a device token (sign-out, user removes device,
platform-reported unregistered).

### Authentication

- Bearer JWT required.

### Rate limit

- 30 requests / minute / IP.

### Request

```http
DELETE /notifications/devices/eX3%3AAPA91b%E2%80%A6
Authorization: Bearer <token>
```

The token is passed as a path parameter, URL-encoded. An alternative
`DELETE /notifications/devices` with a JSON body carrying `{"token": "…"}`
MAY be accepted to avoid encoding pitfalls — implementer's choice, pick
one and document in the generated OpenAPI.

### Validation

- `token` — required, matches an existing `DeviceToken` row owned by the
  caller. If it's owned by another user, treat as `404 Not Found`
  (preserves privacy — don't reveal foreign token ownership).

### Behavior

1. Set `DeviceToken.isActive = false` for the row. Do NOT delete (keeps
   audit trail; matches existing `notification-cleanup` janitor pattern).
2. Emit an audit record: `action='device.deregister'`, `userId`,
   `platform`, `tokenPrefix`, timestamp.
3. Emit a structured log.

### Response

- `204 No Content`.

### Errors

- `401 Unauthorized`.
- `404 Not Found` — token does not exist, or exists but belongs to another
  user.
- `429 Too Many Requests`.

---

## Contract tests (write before implementation — constitution Principle II)

Location: `rideshare-backend/test/notifications/devices.contract.spec.ts`
(create folder if missing).

Required assertions:

1. `POST /notifications/devices` with a new token → `201`, row inserted,
   `token` not in response body.
2. `POST /notifications/devices` with an existing token owned by same user
   → `200`, `lastSeenAt` advanced, no duplicate row.
3. `POST /notifications/devices` with an existing token owned by another
   user → row's `userId` reassigned, audit record written.
4. `POST /notifications/devices` without auth → `401`.
5. `POST /notifications/devices` with invalid `platform` → `400`.
6. `DELETE /notifications/devices/{token}` on own token → `204`,
   `isActive` is now `false`, audit record written.
7. `DELETE /notifications/devices/{token}` on another user's token →
   `404`.
8. Rate limit: 31 calls in one minute from the same IP → one `429`.

---

## Client responsibilities (Flutter)

Not a server-side contract, but the client MUST:

- Call `POST /notifications/devices` after successful sign-in once a valid
  FCM token is available.
- Call `POST /notifications/devices` again if `FirebaseMessaging.onTokenRefresh`
  fires (token rotation).
- Call `DELETE /notifications/devices/{token}` on explicit sign-out, and
  locally discard the token.
- Never log the full token; only the first 8 chars + `…` for diagnostics.
