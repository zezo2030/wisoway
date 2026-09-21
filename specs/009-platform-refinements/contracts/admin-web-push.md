# Contract: Admin Web Push (FCM Web) & Alert Preferences

Delivers driver-registration and in-app-fee-payment alerts to subscribed admin/operator users via FCM Web, deep-linking into the dashboard. Reuses the backend's existing Firebase Admin SDK.

## POST /notifications/web-token

Register (upsert) the dashboard browser's FCM web token for the current user.

**Auth**: JWT. Web tokens used for admin alerts are only honored for `role IN (admin, operator)`.

**Body**:
```json
{ "token": "<fcm-web-token>", "userAgent": "Mozilla/5.0 ..." }
```

**200 response**: `{ "ok": true }`

**Rules**:
- Stored as a `device_tokens` row with `platform = 'web'` for `userId`.
- Idempotent upsert on `(userId, token)`.

**Contract tests**: 401 without token; non-admin token still stored but never targeted by admin alerts; duplicate register is idempotent.

---

## DELETE /notifications/web-token

Unregister the browser token (logout / opt-out).

**Auth**: JWT. **Body**: `{ "token": "<fcm-web-token>" }` → `200 { "ok": true }`.

---

## GET /admin/alert-preferences

Return the current admin's per-type alert preferences.

**Auth**: JWT + role admin/operator.

**200 response**:
```json
{ "preferences": [ { "alertType": "driver_registration", "enabled": true }, { "alertType": "fee_payment", "enabled": true } ] }
```
- Missing rows default to `enabled: true`.

## PATCH /admin/alert-preferences

Enable/disable an alert type for the current admin (FR-017).

**Body**:
```json
{ "alertType": "fee_payment", "enabled": false }
```
**200 response**: the updated preference. Disabled types are not delivered (FR-016/FR-017).

**Contract tests**: 403 for non-admin; PATCH then GET reflects change; disabled type is excluded from the send fan-out (integration test).

---

## Alert triggers (server-side behavior, not a client endpoint)

| Trigger | Fires when | Payload `data` |
|---------|-----------|----------------|
| `driver_registration` | a new driver completes registration (account/role=driver created or driver profile submitted for review) | `{ "link": "/users/<id>", "driverId": "<id>" }` |
| `fee_payment` | a successful **in-app platform/communication-fee** payment is recorded (`paymentType=communication_fee` reaches approved/credited in the Cliq success path) | `{ "link": "/payments", "paymentId": "<id>", "amount": <n>, "currency": "<c>" }` |

**Rules**:
- Recipients = admin/operator users with the matching alert type enabled (or no preference row). End-users are never targeted (FR-016).
- Penalty collections, wallet top-ups, and refunds do NOT trigger `fee_payment` (clarification + FR-014).
- Each fan-out emits a structured log (alertType, recipientCount, delivered/failed) and writes the existing `notifications` in-app copy as a fallback when web push can't be delivered (FR-018, constitution III).
- Delivery target: <~1 minute from event (SC-005).

**Service-worker / deep-link**: `firebase-messaging-sw.js` handles `notificationclick` and navigates to `data.link` (`/users/:id` or `/payments`). Foreground messages are surfaced via the existing toast/bell.

**Contract/integration tests**:
- Creating a driver enqueues a `driver_registration` alert to opted-in admins only.
- A successful communication-fee payment enqueues a `fee_payment` alert; a wallet top-up or refund does NOT.
- A disabled preference suppresses delivery to that admin.
- When no valid web token exists, the in-app notification copy is still written.
