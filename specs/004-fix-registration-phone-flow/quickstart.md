# Quickstart: Registration & Phone Verification Flow Restructure

## Prerequisites

- Node.js >= 18
- MongoDB running locally or connection string configured
- Twilio Verify credentials configured in `.env`
- Flutter SDK installed
- Backend running on port 3003

## Environment Variables (Backend)

Ensure these are set in `.env`:
```env
TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
TWILIO_VERIFY_SERVICE_SID=VA...
JWT_ACCESS_SECRET=your_access_secret
JWT_REFRESH_SECRET=your_refresh_secret
MONGODB_URI=mongodb://localhost:27017/rideshare
```

## Quick Verification Steps

### 1. Start Backend
```bash
cd rideshare-backend
npm install
npm run start:dev
```

### 2. Test New Registration Flow
```bash
# Step 1: Register (creates pending registration + sends OTP)
curl -X POST http://localhost:3003/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!",
    "name": "تجريبي",
    "gender": "male",
    "phoneNumber": "+201234567890",
    "role": "passenger"
  }'
# Expected: 201 with { message, phoneNumber, expiresAt }
# No tokens, no user created yet

# Step 2: Verify OTP (creates user account)
curl -X POST http://localhost:3003/api/v1/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "+201234567890",
    "code": "123456"
  }'
# Expected: 201 with { user, accessToken, refreshToken }
# User created with isPhoneVerified=true
```

### 3. Verify No Duplicate Accounts
```bash
# Check MongoDB directly
mongo rideshare --eval "db.users.find({email: 'test@example.com'}).count()"
# Expected: 1

mongo rideshare --eval "db.users.find({phoneNumber: '+201234567890'}).count()"
# Expected: 1 (same user)
```

### 4. Test Phone Uniqueness
```bash
# Try registering with same phone
curl -X POST http://localhost:3003/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "other@example.com",
    "password": "Test123!",
    "name": "آخر",
    "phoneNumber": "+201234567890"
  }'
# Expected: 409 with "رقم الهاتف مسجّل بالفعل"
```

### 5. Start Flutter App
```bash
cd rideshare
flutter pub get
flutter run
```

### 6. Test Driver Approval Gate
```bash
# Register as driver, verify OTP, then try creating a trip
# Expected: 403 "حسابك كسائق قيد المراجعة"
```

## Key Files to Modify

### Backend
| File | Change Summary |
|------|---------------|
| `src/modules/users/schemas/pending-registration.schema.ts` | **NEW** — PendingRegistration schema |
| `src/modules/auth/dto/sign-up.dto.ts` | Add `phoneNumber`, `role` fields |
| `src/modules/auth/auth.service.ts` | Rewrite `register()`, `verifyOtp()` |
| `src/modules/auth/auth.module.ts` | Import PendingRegistration model |
| `src/modules/users/schemas/user.schema.ts` | Add `isDriverApproved` field |
| `src/modules/users/users.service.ts` | Add pending registration CRUD methods |
| `src/modules/trips/trips.service.ts` | Add `isDriverApproved` check in `create()` |
| `src/modules/admin/admin.controller.ts` | Add `approveDriver` endpoint |
| `src/modules/admin/admin.service.ts` | Add `approveDriver` method |

### Frontend
| File | Change Summary |
|------|---------------|
| `lib/screens/auth/sign_up_screen.dart` | Add phone number field |
| `lib/screens/auth/driver_sign_up_screen.dart` | Add phone number field |
| `lib/screens/auth/otp_verification_screen.dart` | Simplify — handle new flow |
| `lib/core/services/auth_service.dart` | Update `signUp()` to include phone |
| `lib/providers/auth_provider.dart` | Update registration flow methods |
| `lib/models/user_model.dart` | Add `isDriverApproved` field |
| `lib/screens/driver/driver_pending_approval_screen.dart` | **NEW** — Pending approval screen |
