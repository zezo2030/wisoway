# Feature Specification: Password Reset & Update

**Feature Branch**: `006-password-reset`
**Created**: 2026-04-03
**Status**: Draft
**Input**: User description: "we need to add the reset password and add the forget password and use the sms for the send the otp for reset the password and use the when the update the password for add the current password and add the new password"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Forgot Password via SMS OTP (Priority: P1)

A user who has forgotten their password can recover their account by verifying their identity through an SMS OTP sent to their registered phone number, then setting a new password.

**Why this priority**: This is the most critical recovery path. Without it, users who forget their passwords are permanently locked out. It directly impacts user retention and support burden.

**Independent Test**: Can be fully tested by entering a registered phone number, receiving an OTP via SMS, verifying it, and setting a new password. Delivers complete self-service account recovery.

**Acceptance Scenarios**:

1. **Given** a user has a registered account with a verified phone number, **When** they tap "Forgot Password" and enter their phone number, **Then** the system sends a 6-digit OTP via SMS to that phone number and shows a verification screen
2. **Given** an OTP has been sent to the user's phone, **When** the user enters the correct OTP within the validity period, **Then** the system allows the user to set a new password
3. **Given** the user has successfully verified the OTP, **When** they enter and confirm a new password that meets strength requirements, **Then** the password is updated and the user is redirected to sign in
4. **Given** the OTP has expired or was not received, **When** the user taps "Resend OTP" after the cooldown period, **Then** a new OTP is sent and the cooldown timer resets
5. **Given** a user enters a phone number not registered in the system, **When** they attempt to request a password reset, **Then** the system shows a generic message without revealing whether the phone number exists

---

### User Story 2 - Update Password from Settings (Priority: P2)

A logged-in user can change their password from the app settings by providing their current password and choosing a new one.

**Why this priority**: Important for security hygiene and user control, but less urgent than the recovery flow since the user already has access to their account.

**Independent Test**: Can be fully tested by navigating to settings, entering current password, entering and confirming a new password, and verifying the change takes effect on next sign-in.

**Acceptance Scenarios**:

1. **Given** a user is logged in with a password-based account, **When** they navigate to the password change screen in settings and enter their current password and a valid new password, **Then** the system updates the password and confirms success
2. **Given** a user is on the password change screen, **When** they enter an incorrect current password, **Then** the system rejects the change and shows an error message
3. **Given** a user signed in via Google or Facebook (no password set), **When** they access the password change screen, **Then** the system informs them that password change is not applicable to social login accounts
4. **Given** a user has successfully changed their password, **When** they attempt to use the old password to sign in, **Then** authentication fails with an invalid credentials error

---

### User Story 3 - Password Reset Rate Limiting & Security (Priority: P3)

The system enforces security measures to prevent abuse of the password reset functionality, including rate limiting OTP requests and invalidating reset sessions.

**Why this priority**: Essential for production security but can be addressed after core flows work. Prevents SMS cost abuse and brute-force attacks.

**Independent Test**: Can be tested by attempting rapid repeated OTP requests, multiple incorrect OTP entries, and verifying sessions expire correctly.

**Acceptance Scenarios**:

1. **Given** a user has requested an OTP, **When** they attempt to request another OTP within 60 seconds, **Then** the system rejects the request and shows the remaining cooldown time
2. **Given** a user has entered an incorrect OTP, **When** they reach 5 consecutive failed attempts, **Then** the system locks the reset session and requires waiting before retrying
3. **Given** a successful password reset, **When** the user tries to use the same OTP again, **Then** the system rejects it as already used
4. **Given** a user has not completed the reset flow within 10 minutes, **When** they try to submit a new password, **Then** the session has expired and they must start over

---

### Edge Cases

- User registered with email only (no phone number linked) attempts forgot password — system guides them to link a phone number first or shows that phone-based recovery is unavailable
- User's phone number is linked but not verified — system does not allow SMS-based password reset for unverified phones
- User enters a new password that is the same as the current password — system rejects it with a clear message
- Network failure during OTP submission — user sees a connection error and can retry without losing their place in the flow
- User closes the app mid-reset flow — the session persists for the validity period (10 minutes) so they can resume
- Multiple password reset requests from different devices for the same account — only the latest OTP is valid

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to request a password reset by entering their registered phone number
- **FR-002**: System MUST send a 6-digit OTP via SMS to the user's registered phone number when a reset is requested
- **FR-003**: System MUST verify the OTP before allowing the user to set a new password
- **FR-004**: System MUST allow users to set a new password after successful OTP verification
- **FR-005**: System MUST require the new password to meet minimum strength requirements (at least 8 characters, including a number and a letter)
- **FR-006**: System MUST allow logged-in users to change their password by providing their current password and a new password
- **FR-007**: System MUST validate that the current password is correct before allowing a password change
- **FR-008**: System MUST reject a new password that is identical to the current password
- **FR-009**: System MUST enforce a 60-second cooldown between OTP resend requests
- **FR-010**: System MUST invalidate the OTP after successful use or after 10 minutes
- **FR-011**: System MUST lock the reset session after 5 consecutive incorrect OTP attempts
- **FR-012**: System MUST NOT reveal whether a phone number is registered in the system (generic response for all requests)
- **FR-013**: System MUST only allow password reset via verified phone numbers
- **FR-014**: System MUST redirect the user to the sign-in screen after a successful password reset
- **FR-015**: System MUST sign out the user from all other sessions after a password change (token invalidation)

### Key Entities

- **Password Reset Session**: Represents an in-progress password reset flow. Tracks the phone number, OTP code, verification status, attempt count, creation time, and expiration. Each session is single-use and expires after 10 minutes.
- **User (existing)**: The user account being recovered or updated. Contains the phone number used for OTP delivery and the password hash being changed. Social login users (Google/Facebook) without a password set are handled differently.

## Assumptions

- The existing Twilio SMS service and OTP generation logic will be reused for password reset OTP delivery
- The "Forgot Password" entry point will be added to the existing sign-in screen
- The "Update Password" option will be added to the settings screen (currently being built in feature 005)
- Password strength requirements (8+ chars, number + letter) apply to both reset and update flows
- Social login users without passwords will see a contextual message rather than a password change form
- The app currently requires phone verification during registration, so most users will have a verified phone number available for recovery

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete the full forgot password flow (request OTP, verify, set new password, sign in) in under 2 minutes
- **SC-002**: 95% of valid OTPs are delivered via SMS within 30 seconds of request
- **SC-003**: Users can change their password from settings in under 1 minute
- **SC-004**: Zero user accounts can be accessed with a previous password after a successful reset or change
- **SC-005**: The system rejects 100% of password reset attempts with expired or already-used OTPs
- **SC-006**: The system blocks rapid OTP requests (more than 1 per 60 seconds) with a clear error message
