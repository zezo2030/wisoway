# Quickstart: Password Reset & Update

**Feature Branch**: `006-password-reset`

## Backend (rideshare-backend)

### 1. Start the dev server

```bash
cd rideshare-backend
npm run start:dev
```

### 2. Create the PasswordResetSession entity

Create the new TypeORM entity at `src/database/entities/password-reset-session.entity.ts` following the schema in `data-model.md`. Register it in the TypeORM configuration.

Add `passwordChangedAt` column to the existing `UserEntity` at `src/database/entities/user.entity.ts`.

### 3. Run database migration

```bash
npm run db:migration:run
```

### 4. Test the forgot password flow

```bash
# Request password reset (sends OTP)
curl -X POST http://localhost:3003/api/v1/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+201234567890"}'

# Verify OTP (check console for local OTP)
curl -X POST http://localhost:3003/api/v1/auth/verify-reset-otp \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+201234567890", "code": "123456"}'

# Set new password using resetToken from previous step
curl -X POST http://localhost:3003/api/v1/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"resetToken": "<token>", "newPassword": "NewPass123"}'
```

### 5. Test the change password flow

```bash
# Sign in first to get a JWT
TOKEN=$(curl -s -X POST http://localhost:3003/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "NewPass123"}' | jq -r '.accessToken')

# Change password
curl -X POST http://localhost:3003/api/v1/auth/change-password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"currentPassword": "NewPass123", "newPassword": "AnotherPass456"}'
```

## Flutter App (rideshare)

### 1. Run the app

```bash
cd rideshare
flutter run
```

### 2. Test forgot password

1. Open the app → tap "Sign In"
2. Tap "Forgot Password?" link
3. Enter phone number → tap "Send Code"
4. Enter 6-digit OTP (check backend console for local dev OTP)
5. Enter and confirm new password
6. Verify redirect to sign-in screen

### 3. Test change password (settings)

1. Sign in to the app
2. Navigate to Settings → Account & Security → Change Password
3. Enter current password and new password
4. Verify the app signs out and redirects to sign-in

## Environment Variables

No new environment variables required. The feature reuses the existing:

- `OTP_PROVIDER` — `local` (dev) or `twilio` (production)
- `TWILIO_VERIFY_SERVICE_SID` — Twilio Verify service
- `JWT_ACCESS_SECRET` — For signing reset tokens
- `JWT_REFRESH_SECRET` — For refresh token management
