# Research: Registration & Phone Verification Flow Restructure

## Phase 0 — Research Findings

### R-001: Pending Registration Storage Strategy

**Decision**: Use MongoDB collection with TTL index (same pattern as existing `OtpCode` schema)

**Rationale**: The project already uses this exact pattern for OTP codes — `otp-code.schema.ts` has a `expiresAt` field with `expireAfterSeconds: 0` TTL index, which MongoDB auto-deletes when the TTL expires. Reusing the same pattern for `PendingRegistration` ensures consistency and leverages known, tested infrastructure.

**Alternatives considered**:
- **Redis / In-memory store**: Would require adding a new dependency (Redis) not currently in the stack. Unnecessary complexity for a 5-minute TTL.
- **Client-side storage**: Rejected by user's clarification — registration data must be stored server-side for security (password hashes should never live on the client).
- **Temporary flag on User record**: Would require creating the user first, contradicting the deferred-creation decision.

---

### R-002: OTP Flow — Twilio Verify Integration

**Decision**: Keep existing Twilio Verify integration unchanged. Only restructure the flow around it.

**Rationale**: The `sendOtp` and OTP verification logic in `AuthService` currently uses Twilio's API. The spec explicitly states "The OTP verification mechanism (Twilio Verify) remains unchanged." Modifying OTP delivery is out of scope.

**Key findings**:
- `AuthService.sendOtp()` sends OTP via Twilio (line ~149-170 in `auth.service.ts`)
- `OtpCode` schema stores codes with 5-minute TTL (auto-deleted by MongoDB)
- `skipOTP` flag exists in `app_constants.dart` (currently `false`) for dev mode
- `printOTPToConsole` likely exists for debug purposes

**No changes needed** to the OTP sending mechanism itself.

---

### R-003: Driver Approval Gate — Vehicle vs. User Approval

**Decision**: Use existing `vehicle.isVerified` check as the primary driver approval gate. Add `isDriverApproved` to User schema as an additional future-proof field.

**Rationale**: The `TripsService.create()` already checks `vehicle.isVerified` before allowing trip creation. This is effectively a driver approval gate through vehicle verification. Adding `isDriverApproved` on the User schema provides a more explicit, user-level approval that can work independently of vehicle status.

**Key findings**:
- `TripsService.create()` already has: `if (!vehicle.isVerified) throw ForbiddenException`
- Admin endpoint `AdminController.verifyVehicle()` exists with `VerifyVehicleDto`
- `isDriverApproved` does **not** exist yet in the User schema
- The spec requires `isDriverApproved` as a separate field on User

**Implementation approach**: Add `isDriverApproved` to User schema. Trip creation checks BOTH `vehicle.isVerified` AND `user.isDriverApproved`. Admin vehicle verification endpoint can optionally set both.

---

### R-004: Uniqueness Enforcement — Phone Number

**Decision**: Phone number uniqueness is already at database level (`unique: true, sparse: true` on `phoneNumber` in User schema). Add application-level checks in the register and linkPhone endpoints for better error messages.

**Rationale**: Database constraint catches edge cases but throws generic Mongoose errors. Application-level checks provide user-friendly Arabic error messages.

**Key findings**:
- `user.schema.ts` line 52-53: `phoneNumber` has `unique: true, sparse: true`
- `users.service.ts`: `linkPhone()` already checks `findByPhone()` before linking
- The `PendingRegistration` collection will also need phone uniqueness (natural — it's keyed by phone)

---

### R-005: Frontend — Phone Input Widget

**Decision**: Use `intl_phone_field` or similar Flutter package for country code selector with E.164 output.

**Rationale**: The spec requires country code selector (FR-016, FR-017) defaulting to +20 (Egypt). A pre-built widget handles formatting, validation, and country selection.

**Alternatives considered**:
- **Manual TextFormField**: Would require building country code picker from scratch — unnecessary effort.
- **`intl_phone_number_input`**: Popular alternative, but `intl_phone_field` is simpler for the use case.
- Check existing dependencies in `pubspec.yaml` first before adding new packages.

---

### R-006: Frontend — Pending Approval Screen

**Decision**: Create a new `DriverPendingApprovalScreen` widget that shows when `user.role == 'driver'` and `user.isDriverApproved == false`.

**Rationale**: The clarification specified a dedicated screen (not a banner or dialog). This is a new screen that replaces the driver home when the driver is not approved.

**Key findings**:
- Need to add `isDriverApproved` to the Flutter `UserModel`
- Need to add routing logic in the auth flow to redirect non-approved drivers
- The screen should show: driver name, vehicle info summary, and "pending approval" status
- Only logout and profile viewing available from this screen
