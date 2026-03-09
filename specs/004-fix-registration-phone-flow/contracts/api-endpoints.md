# API Contracts: Registration & Phone Verification Flow

## Modified Endpoints

### POST `/auth/register` — Register New User (Step 1)

**Changed**: Now accepts `phoneNumber` and `role`. Does **NOT** create a user account. Creates a pending registration and sends OTP.

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "أحمد محمد",
  "gender": "male",
  "phoneNumber": "+201234567890",
  "role": "passenger"
}
```

**Validation**:
| Field | Rules |
|-------|-------|
| `email` | Required, valid email format, not in User table, not in PendingRegistration table |
| `password` | Required, min 6 characters |
| `name` | Required, 2-100 characters |
| `gender` | Optional, `male` \| `female` |
| `phoneNumber` | **Required**, E.164 format (`/^\+[1-9]\d{1,14}$/`), not in User table, not in PendingRegistration (different email) |
| `role` | Optional, `passenger` (default) \| `driver` |

**Success Response** (201):
```json
{
  "message": "OTP sent successfully. Please verify your phone number.",
  "phoneNumber": "+201234567890",
  "expiresAt": "2026-03-06T21:15:00.000Z"
}
```

**Error Responses**:
| Code | Condition | Body |
|------|-----------|------|
| 400 | Invalid input / validation failure | `{ "message": "Validation failed", "errors": [...] }` |
| 409 | Email already registered (User or PendingRegistration) | `{ "message": "البريد الإلكتروني مسجّل بالفعل" }` |
| 409 | Phone already registered (User or PendingRegistration with different email) | `{ "message": "رقم الهاتف مسجّل بالفعل" }` |

**Side Effects**:
- Creates/overwrites a `PendingRegistration` record (keyed by phoneNumber)
- Sends OTP to the provided phone number via Twilio
- Does **NOT** create a User record
- Does **NOT** return tokens

---

### POST `/auth/verify-otp` — Verify OTP (Step 2 — Completes Registration)

**Changed**: Now creates the user account if a pending registration exists. Returns tokens for new registrations.

**Request Body** (unchanged):
```json
{
  "phoneNumber": "+201234567890",
  "code": "123456"
}
```

**Success Response — New Registration** (201):
```json
{
  "message": "Phone verified and account created successfully",
  "user": {
    "_id": "65f...",
    "email": "user@example.com",
    "phoneNumber": "+201234567890",
    "name": "أحمد محمد",
    "gender": "male",
    "role": "passenger",
    "isPhoneVerified": true,
    "isDriverApproved": false,
    "provider": "email",
    "isActive": true,
    "rating": 0,
    "totalRatings": 0,
    "createdAt": "2026-03-06T21:15:00.000Z"
  },
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```

**Success Response — Existing User (linkPhone fallback)** (200):
```json
{
  "message": "Phone number verified successfully",
  "user": { ... },
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```

**Error Responses**:
| Code | Condition | Body |
|------|-----------|------|
| 400 | Invalid OTP code | `{ "message": "كود التحقق غير صحيح أو منتهي الصلاحية" }` |
| 400 | OTP expired | `{ "message": "كود التحقق منتهي الصلاحية. الرجاء طلب كود جديد" }` |
| 404 | No pending registration AND no existing user with this phone | `{ "message": "لا يوجد تسجيل معلّق لهذا الرقم" }` |

**Side Effects**:
- If pending registration found: Creates User, deletes PendingRegistration, marks OTP as used
- If no pending but existing user: Updates `isPhoneVerified=true` (linkPhone behavior)
- Generates and returns JWT access + refresh tokens

---

### POST `/auth/send-otp` — Resend OTP

**Unchanged** request/response. Used when user needs a new OTP during registration.

**Request Body**:
```json
{
  "phoneNumber": "+201234567890"
}
```

**Success Response** (200):
```json
{
  "message": "OTP sent successfully"
}
```

---

### PATCH `/auth/link-phone` — Link Phone to Existing Account

**Unchanged** but with added uniqueness validation.

**Added Validation**:
- Rejects with 409 if `phoneNumber` is already linked to another user account

**Error Response** (409):
```json
{
  "message": "رقم الهاتف مرتبط بحساب آخر"
}
```

---

## New Endpoint

### PATCH `/admin/users/:id/approve-driver` — Approve/Reject Driver

**New endpoint** to set `isDriverApproved` on a driver's account.

**Auth**: Bearer token, Admin role required

**Request Body**:
```json
{
  "approved": true
}
```

**Success Response** (200):
```json
{
  "message": "Driver approval status updated",
  "user": {
    "_id": "65f...",
    "name": "أحمد السائق",
    "role": "driver",
    "isDriverApproved": true
  }
}
```

**Error Responses**:
| Code | Condition | Body |
|------|-----------|------|
| 400 | User is not a driver | `{ "message": "User is not a driver" }` |
| 403 | Not admin | `{ "message": "Forbidden" }` |
| 404 | User not found | `{ "message": "User not found" }` |

---

## Modified Guard: Trip Creation

### POST `/trips` — Create Trip

**Added check**: Before creating a trip, the endpoint now also checks `user.isDriverApproved`.

**New Error Response** (403):
```json
{
  "message": "حسابك كسائق قيد المراجعة. لا يمكنك إنشاء رحلات حتى يتم الموافقة عليه."
}
```

This check is **in addition to** the existing `vehicle.isVerified` check.
