# Contract: User Profile — `city` field

**Feature**: 007-app-ux-improvements
**Module**: `rideshare-backend/src/modules/users/` (existing)
**Audience**: authenticated users (mobile app)

Extends the existing "update my profile" endpoint (or introduces one if it
doesn't exist today) to allow the caller to set their declared city. The
value drives the city-scoped fan-out defined in
[notifications-triggers.md](./notifications-triggers.md).

---

## PATCH `/users/me`

**Purpose**: the authenticated user updates one or more mutable fields on
their own profile. This feature only adds `city`; the endpoint may already
accept other fields today — preserve that behavior.

### Authentication

- Bearer JWT required.

### Rate limit

- 30 requests / minute / IP.

### Request (relevant fields only)

```http
PATCH /users/me
Content-Type: application/json
Authorization: Bearer <token>

{
  "city": "Amman"
}
```

### Validation

- `city` — optional on PATCH (omitted = unchanged); when present:
  - non-empty after trim,
  - `1 <= length <= 64`,
  - string only (no other types),
  - the empty string `""` is equivalent to `null` → clears the field.

### Behavior

1. Trim leading/trailing whitespace.
2. If the resulting value is empty, write `NULL` to the column.
3. Update `User.city`.
4. Emit a structured log: `trigger=user.profile.update`, `fields=['city']`,
   `userId`, outcome.
5. No push notification is sent as a result of this update.

### Response

- `200 OK`:

```json
{
  "id": "…",
  "email": "…",
  "name": "…",
  "city": "Amman",
  "…": "…other existing profile fields…"
}
```

**Important**: the response MUST NOT include `fcmToken`, `passwordHash`, or
any device tokens (R7).

### Errors

- `400 Bad Request` — validation failed.
- `401 Unauthorized`.
- `429 Too Many Requests`.

---

## GET `/users/me` (if existing)

No shape change required; when the endpoint returns the caller's profile,
`city` MAY be included. Still MUST NOT include `fcmToken`, `passwordHash`,
or any device tokens.

---

## Contract tests

Location: `rideshare-backend/test/users/profile.contract.spec.ts`.

1. `PATCH /users/me` with `{"city":"Amman"}` → `200`, DB column updated,
   no FCM token in response.
2. `PATCH /users/me` with `{"city":"   "}` → DB value becomes `NULL`.
3. `PATCH /users/me` with `{"city":"a".repeat(65)}` → `400`.
4. `PATCH /users/me` without auth → `401`.
5. `GET /users/me` on a user with `city=null` → response includes `city: null`.
6. `GET /users/me` response does NOT contain `fcmToken` or any field named
   `token`.
