# Contract — Admin, Complaints, Support & Refund (Phase 6: `014-admin-and-support`)

## Ban (extension of admin user actions)

### POST `/admin/users/:id/ban`
Body: `{ reason: string }`. Effects:
- `users.bannedAt = now`, `users.banReason = reason`.
- Cascade: cancel every `pending` and `confirmed` booking owned by the user; for trips authored by the user that are `published`, cancel them and notify confirmed passengers; revoke all `user_devices`.
- Audit row in `security_events` (type `account_banned`).
Response 200.

### POST `/admin/users/:id/unban`
Sets `bannedAt=null`, `banReason=null`. The user's previously cancelled bookings/trips remain cancelled.

### Server-side ban gate
Every authenticated request runs a `BanGuard`:
- If `users.bannedAt IS NOT NULL`: response `403 ACCOUNT_BANNED` with body `{ banReason, supportWhatsApp: '+962788883007' }`. Mobile app uses this to render the ban screen.

## Complaints

### POST `/complaints` *(authenticated)*
Body:
```json
{
  "againstUserId": "uuid?",
  "tripId": "uuid?",
  "bookingId": "uuid?",
  "category": "safety" | "rude_behavior" | "no_show" | "payment" | "vehicle_condition" | "other",
  "body": "..."
}
```
Validation: at least one of `againstUserId | tripId | bookingId` is present. Response 201 with the created row.

### GET `/me/complaints`
Returns the caller's filed complaints.

### GET `/admin/complaints`
Admin filtered listing. Query params: `status?`, `category?`, `from?`, `to?`, `cursor?`.

### PATCH `/admin/complaints/:id`
Body: `{ status, adminNotes? }`. When `status='resolved'` or `'rejected'`, set `resolvedByAdminId` and `resolvedAt` and notify the reporter.

## Refund

### POST `/refund-requests` *(authenticated)*
Body:
```json
{
  "bookingId": "uuid?",
  "amount": "5.00",
  "currency": "JOD",
  "reason": "..."
}
```
Effects:
- Create `refund_requests` row with `status='open'`, `whatsappContactedAt=now`.
- Response includes a `whatsappDeepLink` field with the prefilled message:
```text
https://wa.me/962788883007?text=<urlencoded prefill>
```
Where the prefill includes booking reference, amount, reason, and the user-id last 6 chars for admin context.

### GET `/admin/refund-requests`
Admin queue listing.

### PATCH `/admin/refund-requests/:id`
Body: `{ status: 'contacted' | 'resolved' | 'rejected', adminNotes? }`.

## Support deep-link configuration

### GET `/support/config`
Returns:
```json
{
  "whatsappE164": "+962788883007",
  "whatsappDeepLinkBase": "https://wa.me/962788883007"
}
```
Allows the mobile/dashboard apps to fetch the configured number rather than hardcoding it. Cache-friendly; admin can change in a dashboard config page (out of strict scope — at minimum, the value lives in env so it's deploy-controlled).

## Dashboard pages

| Page | Endpoints used |
|---|---|
| Users → Ban list | `GET /admin/users?banned=true`, `POST /admin/users/:id/unban` |
| Account flags queue | `GET /admin/account-flags`, `POST /admin/account-flags/:id/clear`, `POST /admin/account-flags/:id/escalate` |
| Complaints queue | `GET /admin/complaints`, `PATCH /admin/complaints/:id` |
| Refund queue | `GET /admin/refund-requests`, `PATCH /admin/refund-requests/:id` |
| Pending charges | `GET /admin/pending-charges`, `POST /admin/pending-charges/:id/waive` |
| Trips with stops/notes/recurrence | existing trips page extended |
| Devices per user | `GET /admin/users/:id/devices`, `POST /admin/users/:id/devices/:deviceId/revoke` |

## Contract tests

- `ban-cascade.contract.spec.ts` (ensures FR-044 cascade is exhaustive)
- `ban-guard.contract.spec.ts` (any authenticated endpoint while banned returns 403 with the documented body)
- `complaints-create.contract.spec.ts` (validation: at least one target)
- `complaints-admin-update.contract.spec.ts` (notification on resolve)
- `refund-create.contract.spec.ts` (deep-link shape)
- `support-config.contract.spec.ts`
