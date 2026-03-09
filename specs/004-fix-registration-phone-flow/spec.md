# Feature Specification: Registration & Phone Verification Flow Restructure

**Feature Branch**: `004-fix-registration-phone-flow`
**Created**: 2026-03-06
**Status**: Draft
**Input**: User description: "Restructure the registration and phone verification flow to include phone number in initial registration, verify via OTP, prevent duplicate account creation, and enforce driver data approval before trip creation"

## Problem Statement

The current registration flow has **critical architectural bugs**:

1. **Phone number is not collected during registration** — The sign-up form only collects name, email, password, and gender. Phone number is requested as a separate step *after* account creation.
2. **Duplicate accounts are created** — When a user registers with email and then verifies their phone via OTP, the backend `verifyOtp` endpoint creates a *new* user with `AuthProvider.PHONE` if no user is found by phone number (see `auth.service.ts:190-199`). This results in **two separate user records** for the same person: one created by `register()` with email, and one created by `verifyOtp()` with phone.
3. **Flow is disjointed** — Registration → Phone entry → OTP verification are treated as independent operations rather than a single unified registration process.
4. **Driver approval enforcement is missing** — There is no gate preventing drivers from creating trips before their profile/vehicle data is reviewed and approved by an admin.

## Clarifications

### Session 2026-03-06

- Q: Should the user account be created immediately on registration (before OTP) or deferred until OTP verification succeeds? → A: **Deferred** — account is only created after successful OTP verification. Registration data is held temporarily (server-side pending registration store) until the phone is verified.
- Q: What happens if a user submits registration but doesn't complete OTP, then tries to register again with the same email/phone? → A: **Overwrite** — the existing pending registration is replaced with the new data and a fresh OTP is sent. After TTL expiry (5 minutes), the pending record is automatically deleted and the user can register from scratch.
- Q: What should a non-approved driver see after completing their profile? → A: **Pending approval screen** — a dedicated status screen showing "awaiting approval" with a summary of their submitted data. The driver cannot access trip management until an admin approves them.
- Q: Should the pending registration store also enforce email uniqueness (two pending records can't share the same email)? → A: **Yes, enforce** — registration is rejected if the same email exists in either the User table OR the pending registrations store. Overwrite is only allowed when the same phone number is used (regardless of email change).
- Q: Should phone number be strictly unique (one phone = one account only)? → A: **Yes, strictly enforced** — a phone number can only belong to one account. Enforced at database level (unique constraint), at registration (check users + pending store), and at phone linking (reject if phone belongs to another user).
## User Scenarios & Testing *(mandatory)*

### User Story 1 — Passenger Registration with Phone Verification (Priority: P1)

A new passenger opens the app, fills in their registration details (name, email, password, gender, **and phone number**), submits the form, and receives an OTP code on their phone. They enter the OTP to verify their phone number. Upon successful verification, a **single user account** is created in the backend with both email and phone linked. The passenger is then directed to the home screen.

**Why this priority**: This is the core bug fix. Registration is the gateway to all app functionality. A broken registration that creates duplicate accounts causes data integrity issues across the entire platform.

**Independent Test**: Register a new user, verify OTP, then confirm only ONE user record exists in the database with both email and phone number linked.

**Acceptance Scenarios**:

1. **Given** a visitor on the sign-up screen, **When** they view the registration form, **Then** they see input fields for name, email, password, gender, **and phone number**.
2. **Given** a visitor filling out registration, **When** they submit valid details including a phone number in E.164 format, **Then** the system sends an OTP to their phone and navigates them to the OTP verification screen.
3. **Given** a visitor on the OTP screen, **When** they enter the correct OTP within 5 minutes, **Then** the system creates the user account (with email, phone number, and `isPhoneVerified=true`) and returns authentication tokens. No user record exists prior to this step.
4. **Given** a visitor who enters an incorrect OTP, **When** they submit the wrong code, **Then** the system shows an error message and allows them to retry or resend the OTP.
5. **Given** a visitor whose OTP has expired, **When** they request a new OTP, **Then** the system sends a fresh code and resets the expiry timer.
6. **Given** a visitor registering with an email already in use, **When** they submit the form, **Then** the system rejects registration with a clear "email already registered" error.
7. **Given** a visitor registering with a phone number already in use, **When** they submit the form, **Then** the system rejects registration with a clear "phone number already registered" error.

---

### User Story 2 — Driver Registration with Phone Verification (Priority: P1)

A new driver opens the app, fills in their registration details (first name, last name, email, password, gender, **and phone number**), submits the form, and receives an OTP code. After OTP verification, the driver's account is created and they proceed to complete their driver profile (vehicle details, license images). The driver account is created but **cannot create trips** until an admin reviews and approves their driver data.

**Why this priority**: Same core bug applies to drivers. Additionally, the driver approval gate is missing, which is a safety concern for the platform.

**Independent Test**: Register as a driver, verify OTP, complete vehicle profile, confirm single account exists, then attempt to create a trip and verify it is rejected until admin approval.

**Acceptance Scenarios**:

1. **Given** a visitor on the driver sign-up screen, **When** they view the form, **Then** they see fields for first name, last name, email, password, gender, **and phone number**.
2. **Given** a visitor filling out driver registration, **When** they submit valid details including phone number, **Then** the system sends an OTP and navigates to the OTP verification screen.
3. **Given** a driver on the OTP screen, **When** they verify successfully, **Then** the driver's user account is created for the first time (with `isPhoneVerified=true`) and they are navigated to the vehicle/profile completion screen.
4. **Given** a driver who has completed their profile and vehicle information, **When** they attempt to create a trip, **Then** the system rejects the request with an "awaiting admin approval" message.
5. **Given** a non-approved driver who logs in, **When** they reach the home screen, **Then** they see a dedicated "pending approval" screen with a summary of their submitted data instead of the normal driver dashboard.
6. **Given** an admin who reviews a driver's submitted data, **When** the admin approves the driver, **Then** the driver can now access the full app and create trips.

---

### User Story 3 — Login After Registration (Priority: P2)

A user who has already registered and verified their phone can log in with their email and password. The system no longer blocks login for unverified phone numbers (since phone is now verified during registration).

**Why this priority**: Login must work seamlessly after the new registration flow. The current login check for `isPhoneVerified` must align with the new flow.

**Independent Test**: Register a user with the new flow, log out, then log back in with email/password — verify it succeeds without "phone verification required" errors.

**Acceptance Scenarios**:

1. **Given** a registered user with a verified phone, **When** they log in with correct email and password, **Then** they are authenticated and directed to the home screen.
2. **Given** a user who abandoned registration before OTP verification, **When** they try to log in with the same email, **Then** the system returns "invalid credentials" because no account exists (account creation is deferred until OTP succeeds).

---

### Edge Cases

- What happens if the user closes the app between submitting registration and completing OTP? The pending registration record on the server expires after the OTP window (5 minutes). The user must restart registration. No user account is created.
- What happens if a user enters a phone number during registration that is already linked to another account? The system must reject the registration before sending OTP, with a clear error message.
- What happens if a user's internet connection drops during OTP verification? The system must handle this gracefully — the user should be able to retry verification without re-entering registration data.
- What happens if the same email AND phone are registered but belong to different users (legacy data)? The system should prevent this state going forward; existing data may need a migration or reconciliation strategy.
- What happens if OTP verification succeeds but account creation fails? The system must retry account creation atomically. If it still fails, the user is shown an error and must restart registration (the OTP is consumed).
- What happens if a user starts registration but doesn't complete OTP, then registers again? The pending record is overwritten with new data and a fresh OTP is sent. The old OTP becomes invalid.
- What happens if two users try to register with the same email but different phone numbers concurrently? The second registration is rejected immediately with "email already in use" — uniqueness is enforced in both the User table and the pending registration store.
- What happens if a user tries to register with a phone number that already belongs to another account? The system rejects registration immediately with "phone number already registered" — the same phone cannot be used for two accounts.
- What happens if an existing user tries to link a phone number that belongs to another user? The `linkPhone` endpoint rejects the request with "phone number already linked to another account".

## Requirements *(mandatory)*

### Functional Requirements

**Backend — Registration**
- **FR-001**: The registration request MUST include a `phoneNumber` field (E.164 format, required) alongside email, password, name, and gender.
- **FR-002**: The `/auth/register` endpoint MUST validate that both the email and phone number are not already associated with existing accounts AND not present in any active pending registration record (preventing two pending registrations with the same email but different phones).
- **FR-003**: The `/auth/register` endpoint MUST NOT create a user record. Instead, it MUST store the registration data in a temporary pending registration store (server-side, keyed by phone number, expires after 5 minutes) and send an OTP to the provided phone number. If a pending registration already exists for the same phone number, it MUST be overwritten with the new data and a fresh OTP sent. If a pending registration exists for the same email but a different phone, it MUST be rejected.
- **FR-004**: The `/auth/register` endpoint MUST return a success response with the phone number and expiry time (no tokens, no user ID — the account does not exist yet).
- **FR-005**: The actual user account MUST only be created inside the `/auth/verify-otp` endpoint, after the OTP is successfully verified, using the data from the pending registration store.

**Backend — OTP Verification**
- **FR-006**: The `/auth/verify-otp` endpoint MUST check for a pending registration record for the given phone number. If one exists and the OTP is valid, it MUST create the user account using the stored registration data with `isPhoneVerified=true`, then delete the pending record.
- **FR-007**: When OTP verification succeeds for a new registration, the system MUST return the newly created user data and authentication tokens.
- **FR-008**: If `/auth/verify-otp` is called for a phone number with NO pending registration (i.e., an existing user changing/verifying their phone), it MUST fall back to updating the existing user's `isPhoneVerified` flag via the authenticated `linkPhone` flow instead.

**Backend — Driver Approval Gate**
- **FR-009**: The User schema MUST include a `isDriverApproved` boolean field (default: `false`).
- **FR-010**: Trip creation endpoints MUST check `isDriverApproved` and reject trip creation with a 403 status if the driver is not yet approved.
- **FR-011**: Admin endpoints MUST support approving/rejecting driver profiles (setting `isDriverApproved` to `true`/`false`).

**Backend — Phone Number Uniqueness**
- **FR-012**: The `phoneNumber` field in the User schema MUST have a unique database constraint (sparse unique index, since legacy users may not have a phone).
- **FR-013**: The `/auth/register` endpoint MUST reject registration if the phone number is already associated with any existing user account OR any active pending registration (different email).
- **FR-014**: The `/auth/link-phone` endpoint MUST reject phone linking if the phone number is already associated with another user account.
- **FR-015**: The system MUST NOT allow any operation that results in two user accounts sharing the same phone number. This is the single most critical data integrity rule for phone numbers.

**Frontend — Registration Screens**
- **FR-016**: The passenger sign-up screen MUST include a phone number input field with country code selector.
- **FR-017**: The driver sign-up screen MUST include a phone number input field with country code selector.
- **FR-018**: Both sign-up screens MUST validate phone number format before submission.
- **FR-019**: After successful form submission, the app MUST navigate to OTP verification screen with all registration data passed as arguments.

**Frontend — OTP Flow**
- **FR-020**: The OTP verification screen MUST receive the phone number from the registration flow (not ask the user to re-enter it).
- **FR-021**: Upon successful OTP verification, the app MUST update the user's verified status locally and navigate to the appropriate next screen (home for passengers, vehicle profile for drivers).
- **FR-022**: The separate `PhoneAuthScreen` (standalone phone entry) is no longer needed for the registration flow but may be retained for phone-only login or phone change scenarios.

**Frontend — Driver Approval Status**
- **FR-023**: When a non-approved driver logs in, the app MUST redirect them to a dedicated "Pending Approval" screen showing their submitted profile/vehicle data summary and a clear status message.
- **FR-024**: The "Pending Approval" screen MUST NOT provide access to trip management, trip creation, or the normal driver dashboard. Only profile viewing and logout are available.
- **FR-025**: Once the admin approves the driver (reflected via `isDriverApproved=true` in the user profile), the app MUST redirect the driver to the normal home screen on next login or profile refresh.

### Key Entities

- **User**: Extended with `phoneNumber` as a required registration field and new `isDriverApproved` boolean.
- **PendingRegistration**: New temporary entity storing registration data (email, passwordHash, name, gender, phoneNumber, role) with a TTL of 5 minutes. Keyed by phone number.
- **SignUpDto**: Extended with `phoneNumber` (required, E.164 format).
- **VerifyOtpDto**: Unchanged (`phoneNumber` + `code`). The system determines context (new registration vs. existing user) by checking if a pending registration exists for that phone.

## Assumptions

- Phone number is required for all new registrations going forward (both passengers and drivers).
- Existing users who registered without a phone number are not affected by this change (backward compatible).
- The OTP verification mechanism (Twilio Verify) remains unchanged — only the flow around it is restructured.
- Country code defaults to `+20` (Egypt) if not explicitly provided by the user.
- Admin approval for drivers is a simple boolean toggle, not a multi-step review process.
- The `linkPhone` endpoint remains available for existing users who need to add or change their phone number after registration.
- Legacy data with duplicate accounts (one email, one phone for the same person) should be identified and merged as a separate data migration task.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After registration and OTP verification, exactly ONE user record exists in the database — never two — for 100% of new registrations.
- **SC-002**: Users can complete the full registration flow (form submission → OTP verification) in under 3 minutes.
- **SC-003**: The registration form clearly collects all required information (including phone number) in a single step, with zero navigational confusion.
- **SC-004**: Non-approved drivers see a clear "pending approval" status and are blocked from creating trips with an informative error message.
- **SC-005**: Existing login flow continues to work for all previously registered users without regression.
- **SC-006**: OTP delivery success rate remains at the same level as before the restructuring (no regression in Twilio integration).
- **SC-007**: No orphan user accounts are created during any step of the registration process (including interrupted flows).
