# Feature Specification: Rideshare Backend Platform

**Feature Branch**: `003-rideshare-backend`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "Create rideshare backend to replace Firebase with independent, production-ready backend service"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - User Registration & Authentication (Priority: P1)

A new user opens the rideshare app and creates an account using their email and password, phone number with OTP verification, or social login (Google/Facebook). After registration, the user can sign in, stay authenticated across sessions, and securely sign out. Users can also reset forgotten passwords and link a phone number to their account for identity verification.

**Why this priority**: Authentication is the foundation of the entire platform. No other feature can function without user identity. This is the absolute minimum viable product.

**Independent Test**: Can be fully tested by registering a new user, logging in, refreshing the session, and logging out. Delivers secure user identity management.

**Acceptance Scenarios**:

1. **Given** a visitor with no account, **When** they register with valid email and password, **Then** the system creates an account and returns authentication tokens allowing immediate access.
2. **Given** a visitor with a phone number, **When** they request an OTP and enter the correct code within 5 minutes, **Then** the system verifies their identity and grants authenticated access.
3. **Given** a user with a Google or Facebook account, **When** they choose social login, **Then** the system authenticates them using the social provider and creates or links their account automatically.
4. **Given** an authenticated user whose session has expired, **When** they present a valid refresh token, **Then** the system issues new authentication tokens without requiring re-login.
5. **Given** a user who forgot their password, **When** they request a password reset, **Then** the system sends a reset link to their registered email and allows them to set a new password.
6. **Given** an authenticated user, **When** they choose to delete their account, **Then** the system permanently removes their data and revokes all active sessions.

---

### User Story 2 - Driver Trip Creation & Management (Priority: P2)

A registered driver adds their vehicle information (type, plate number, model, seat count, license documents) and creates trips by specifying departure and arrival locations, departure time, price per seat, total seats, and seat layout configuration. Drivers can manage their trips by editing details, hiding/showing trips, and marking trips as completed.

**Why this priority**: Trips are the core product offering. Without drivers creating trips, passengers have nothing to book. This is the supply side of the marketplace.

**Independent Test**: Can be fully tested by registering as a driver, adding a vehicle, creating a trip with a seat layout, editing trip details, and completing the trip.

**Acceptance Scenarios**:

1. **Given** an authenticated user with the driver role, **When** they submit valid vehicle information with required documents, **Then** the system registers the vehicle and marks it pending verification.
2. **Given** a driver with a registered vehicle, **When** they create a trip with valid departure/arrival locations, time, price, and seat configuration, **Then** the system publishes the trip as available for booking.
3. **Given** a driver with an active trip, **When** they choose to hide the trip, **Then** the trip becomes invisible to passengers in search results but retains existing bookings.
4. **Given** a driver with an active trip, **When** they mark the trip as completed, **Then** the system updates the trip status and triggers post-trip actions (rating prompts, notifications).
5. **Given** a driver, **When** they view their trip list, **Then** the system displays all their trips with current status, booking counts, and seat availability.

---

### User Story 3 - Passenger Trip Search & Seat Booking (Priority: P3)

A passenger searches for available trips by specifying departure and arrival locations, preferred date/time, and price range. They browse results, view trip details including seat layout, and book a specific seat. The system enforces gender-based seating rules when the driver has enabled that option. Passengers can view their bookings and cancel if needed.

**Why this priority**: Booking seats is the core transaction of the platform. Once drivers create trips and passengers can book, the marketplace has basic functionality.

**Independent Test**: Can be fully tested by searching for a trip, viewing available seats, booking a seat, viewing the booking confirmation, and cancelling if desired.

**Acceptance Scenarios**:

1. **Given** a passenger looking for a ride, **When** they search with departure location, destination, and date, **Then** the system returns matching active trips sorted by relevance with seat availability shown.
2. **Given** a passenger viewing a trip, **When** they select an available seat, **Then** the system reserves the seat atomically (preventing double-booking) and creates a pending booking.
3. **Given** a trip with gender-mixing prevention enabled, **When** a passenger of a different gender than existing passengers attempts to book, **Then** the system rejects the booking with a clear explanation.
4. **Given** a passenger with an existing booking, **When** they cancel the booking, **Then** the system releases the seat, updates availability, and notifies the driver.
5. **Given** a driver viewing bookings for their trip, **When** a new booking arrives, **Then** they can confirm or reject the booking.

---

### User Story 4 - Payment Processing (Priority: P4)

Drivers and passengers process payments for trip bookings and communication fees. The system supports both online payments (card-based) and manual payments (wallet transfer with proof upload). Drivers pay a communication fee to unlock contact information for booked passengers. Admin staff review and approve or reject manual payments.

**Why this priority**: Monetization is essential for platform sustainability. Payment processing enables the business model.

**Independent Test**: Can be fully tested by creating a payment for a booking, uploading proof for manual payment, and verifying admin approval/rejection workflow.

**Acceptance Scenarios**:

1. **Given** a passenger with a confirmed booking, **When** they submit a payment via card, **Then** the system processes the payment through the payment gateway and updates the booking status.
2. **Given** a user choosing manual payment, **When** they submit wallet transfer proof (screenshot), **Then** the system records the payment as pending admin review.
3. **Given** a driver wanting to contact a booked passenger, **When** they pay the communication fee for that country, **Then** the system unlocks the passenger's contact information for that booking.
4. **Given** an admin reviewing pending payments, **When** they approve a manual payment with a note, **Then** the system confirms the payment and notifies the user.
5. **Given** an admin reviewing pending payments, **When** they reject a payment, **Then** the system marks the payment as rejected and notifies the user with the rejection reason.

---

### User Story 5 - Real-time Chat (Priority: P5)

Participants of a trip (driver and booked passengers) communicate through a trip-specific chat room. Messages are delivered in real-time. Users see typing indicators and message history. Chat access for drivers requires payment of the communication fee for each passenger they want to contact.

**Why this priority**: Communication between trip participants is critical for coordination (pickup locations, schedule changes). Enhances safety and user experience.

**Independent Test**: Can be fully tested by creating a chat room for a trip, sending messages between driver and passenger, and viewing message history.

**Acceptance Scenarios**:

1. **Given** a driver who has paid the communication fee for a booking, **When** they open the trip chat, **Then** the system creates or joins the chat room with the relevant passengers.
2. **Given** a participant in a chat room, **When** they send a message, **Then** all other participants receive the message in real-time without page refresh.
3. **Given** a participant in a chat room, **When** another participant is typing, **Then** they see a typing indicator.
4. **Given** a participant opening an existing chat room, **When** the room loads, **Then** they see the full message history in chronological order with pagination for older messages.

---

### User Story 6 - Ratings & Reviews (Priority: P6)

After a trip is completed, passengers can rate their driver and drivers can rate their passengers. Ratings are on a 1-5 scale with optional text comments. Each user's overall rating is calculated as an average of all received ratings and displayed on their profile.

**Why this priority**: Trust and reputation are essential for a peer-to-peer rideshare platform. Ratings incentivize good behavior and help users make informed decisions.

**Independent Test**: Can be fully tested by completing a trip, submitting a rating, and verifying the rated user's average score updates correctly.

**Acceptance Scenarios**:

1. **Given** a completed trip, **When** a passenger rates the driver (1-5 stars with optional comment), **Then** the system records the rating and updates the driver's average score.
2. **Given** a completed trip, **When** a driver rates a passenger, **Then** the system records the rating and updates the passenger's average score.
3. **Given** a user who has not participated in a trip, **When** they attempt to rate someone for that trip, **Then** the system rejects the rating.
4. **Given** a user viewing another user's profile, **When** they check the profile, **Then** they see the user's average rating and total number of ratings received.

---

### User Story 7 - Notifications (Priority: P7)

Users receive notifications for important events: new bookings, booking confirmations/cancellations, payment status updates, trip status changes, new chat messages, and new ratings. Notifications are delivered both in-app (real-time) and via push notifications to mobile devices. Users can view their notification history, mark notifications as read, and clear old notifications.

**Why this priority**: Timely notifications keep users engaged and informed about critical actions. Without notifications, users must manually check for updates.

**Independent Test**: Can be fully tested by triggering a notifiable event (e.g., new booking), verifying the notification appears in the user's notification list, and marking it as read.

**Acceptance Scenarios**:

1. **Given** a driver with an active trip, **When** a passenger books a seat, **Then** the driver receives a real-time notification and a push notification on their mobile device.
2. **Given** a user with unread notifications, **When** they open the notification center, **Then** they see all notifications with unread count, sorted by most recent.
3. **Given** a user viewing their notifications, **When** they mark a notification as read, **Then** the unread count decreases accordingly.
4. **Given** a user, **When** they choose to mark all notifications as read, **Then** all notifications are marked as read and the unread count resets to zero.

---

### User Story 8 - Admin Dashboard & Management (Priority: P8)

Platform administrators access a dashboard showing overall statistics (total users, active trips, revenue, pending payments). Admins manage users (view, change roles, ban/unban), review and approve/reject pending manual payments, verify driver vehicles and documents, and generate reports.

**Why this priority**: Administrative oversight is necessary for platform governance, safety compliance, and financial management, but the platform can initially operate with limited admin tooling.

**Independent Test**: Can be fully tested by logging in as an admin, viewing dashboard statistics, managing a user account, and processing a pending payment.

**Acceptance Scenarios**:

1. **Given** an authenticated admin, **When** they access the dashboard, **Then** they see aggregate statistics: total users, active trips, total revenue, and pending payment count.
2. **Given** an admin viewing the user list, **When** they change a user's role or ban a user, **Then** the change takes effect immediately and the affected user is notified.
3. **Given** an admin reviewing pending payments, **When** they view the queue, **Then** they see all pending manual payments with proof images, amounts, and user details.
4. **Given** an admin reviewing a vehicle registration, **When** they verify or reject the vehicle, **Then** the driver is notified and the vehicle status updates accordingly.

---

### Edge Cases

- What happens when two passengers attempt to book the same seat simultaneously? The system MUST use atomic operations to prevent double-booking; only the first successful request gets the seat, the other receives a "seat no longer available" error.
- What happens when a driver cancels a trip with existing bookings? All active bookings MUST be cancelled, seats released, affected passengers notified, and any completed payments flagged for refund processing.
- What happens when a user's refresh token expires? The user MUST be prompted to re-authenticate; the system MUST NOT silently fail or expose unauthorized access.
- What happens when a file upload exceeds the maximum allowed size? The system MUST reject the upload with a clear error message specifying the size limit before processing begins.
- What happens when a user tries to book a seat on their own trip? The system MUST reject the booking with a clear error message.
- What happens when the payment gateway is temporarily unavailable? The system MUST inform the user, suggest trying again later, and not leave the booking in an inconsistent state.
- What happens when a driver creates a trip with a departure time in the past? The system MUST reject the trip creation with a validation error.
- What happens when communication fee amounts differ by country? The system MUST apply the correct fee based on the trip's country/region using a configurable fee schedule.

## Requirements *(mandatory)*

### Functional Requirements

**Authentication & Users**
- **FR-001**: System MUST allow user registration via email/password, phone OTP, Google login, and Facebook login.
- **FR-002**: System MUST issue short-lived access tokens (15 minutes) and long-lived refresh tokens (7 days) upon successful authentication.
- **FR-003**: System MUST support three user roles: passenger, driver, and admin, with role-based access control on all operations.
- **FR-004**: System MUST allow users to update their profile (name, photo, gender, contact info) and switch between passenger and driver roles.
- **FR-005**: System MUST allow users to link a phone number to their account and verify it via OTP.
- **FR-006**: System MUST allow users to permanently delete their account and all associated data.

**Vehicles**
- **FR-007**: System MUST allow drivers to register exactly one vehicle with type, plate number, model, seat count, and license document uploads.
- **FR-008**: System MUST support admin verification of vehicle registrations before drivers can create trips.

**Trips & Seats**
- **FR-009**: System MUST allow drivers to create trips with departure/arrival locations (name, coordinates, address), departure time, price, currency, total seats, and configurable seat layout.
- **FR-010**: System MUST support a seat layout system with configurable rows, seats per row, and optional gender-mixing prevention.
- **FR-011**: System MUST allow drivers to hide, show, edit, complete, and cancel their trips.
- **FR-012**: System MUST allow passengers to search and filter trips by location, date, price range, and availability.
- **FR-013**: System MUST automatically expire trips whose departure time has passed.

**Bookings**
- **FR-014**: System MUST allow passengers to book a specific seat on a trip with atomic seat reservation to prevent double-booking.
- **FR-015**: System MUST enforce gender compatibility rules when the trip's gender-mixing prevention is enabled.
- **FR-016**: System MUST allow booking cancellation by passengers, drivers, or the system, with reason tracking and timestamp.
- **FR-017**: System MUST prevent a user from booking multiple seats on the same trip.

**Payments**
- **FR-018**: System MUST support online card payments through a payment gateway.
- **FR-019**: System MUST support manual payments with proof image upload and admin approval workflow.
- **FR-020**: System MUST implement a communication fee system where drivers pay a country-specific fee to access passenger contact information.
- **FR-021**: System MUST support configurable communication fees per country (e.g., Egypt: 50 EGP, Jordan: 2 JOD, Saudi Arabia: 10 SAR).

**Chat**
- **FR-022**: System MUST provide real-time messaging within trip-specific chat rooms.
- **FR-023**: System MUST restrict chat access to trip participants (driver + booked passengers).
- **FR-024**: System MUST support message history with pagination and typing indicators.

**Ratings**
- **FR-025**: System MUST allow mutual rating (1-5 scale with optional comment) between drivers and passengers after trip completion.
- **FR-026**: System MUST maintain a running average rating for each user, updated after every new rating.
- **FR-027**: System MUST prevent duplicate ratings (one rating per user per trip).

**Notifications**
- **FR-028**: System MUST deliver real-time in-app notifications for booking events, payment updates, trip status changes, new messages, and new ratings.
- **FR-029**: System MUST send push notifications to users' mobile devices for critical events.
- **FR-030**: System MUST allow users to view notification history, mark individual or all notifications as read, and delete notifications.

**File Uploads**
- **FR-031**: System MUST support file uploads for profile images, driver licenses, vehicle licenses, car images, and payment proof.
- **FR-032**: System MUST validate file types and enforce size limits on all uploads.

**Admin**
- **FR-033**: System MUST provide admin dashboard with aggregate statistics (users, trips, revenue, pending payments).
- **FR-034**: System MUST allow admins to manage users (view list, change roles, ban/unban).
- **FR-035**: System MUST allow admins to review, approve, or reject pending manual payments.
- **FR-036**: System MUST allow admins to verify or reject driver vehicle registrations.

**Infrastructure**
- **FR-037**: System MUST expose a health check endpoint for monitoring.
- **FR-038**: System MUST paginate all list endpoints with configurable page size.
- **FR-039**: System MUST rate-limit public endpoints to prevent abuse.
- **FR-040**: System MUST provide geocoding and reverse geocoding for location input.
- **FR-041**: System MUST run background jobs for trip expiration and notification cleanup.

### Key Entities

- **User**: Represents a platform participant with profile information (name, email, phone, gender, photo), role (passenger/driver/admin), authentication credentials, rating score, and account status. A user can be both a driver and a passenger.
- **Vehicle**: Represents a driver's registered vehicle with type, plate number, model, seat count, license documents, and verification status. Each driver has at most one vehicle.
- **Trip**: Represents a planned ride created by a driver with departure and arrival locations (name, coordinates, address), departure time, pricing, seat configuration (layout with rows and seats per row, gender-mixing settings), and status (active/hidden/completed/cancelled/expired).
- **Seat**: Represents an individual seat within a trip's layout, identified by position (row-column), with booking status (available/booked/locked) and occupant information.
- **Booking**: Represents a passenger's reservation of a specific seat on a trip, tracking status (pending/confirmed/cancelled/completed), cancellation details, and communication fee status.
- **Payment**: Represents a financial transaction for a trip booking or communication fee, supporting online and manual methods, with approval workflow and proof documentation.
- **Chat Room**: Represents a messaging space for a specific trip, containing participants (driver + booked passengers) and message history.
- **Message**: Represents a single chat message within a room, with sender information, text content, and timestamp.
- **Rating**: Represents a post-trip evaluation from one user to another, with a 1-5 score, optional comment, and role information (who rated whom).
- **Notification**: Represents a user-facing alert for system events, with type, title, body, read status, and associated data.
- **Communication Fee**: Represents a country-specific fee amount that drivers must pay to access passenger contact information, with currency and active status.

## Assumptions

- The platform operates primarily in the Middle East/North Africa region (Egypt, Jordan, Saudi Arabia, UAE, Qatar) based on the currency and communication fee configuration.
- Each driver can register only one vehicle at a time.
- Gender is limited to male/female for seat assignment purposes.
- Trip prices are set by drivers and not dynamically calculated by the system.
- Manual payment proof is a single image (screenshot of wallet transfer).
- Push notifications target mobile devices (iOS and Android) via a push notification service.
- The system serves a companion Flutter mobile application.
- OTP codes expire after 5 minutes and are single-use.
- Notification cleanup removes notifications older than 30 days.
- Users can only rate after a trip is marked as completed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete registration and first login in under 2 minutes regardless of authentication method (email, phone OTP, or social login).
- **SC-002**: Trip search results return within 2 seconds for searches across the full trip catalog.
- **SC-003**: Seat booking completes atomically with zero double-bookings under concurrent access (100 simultaneous booking attempts on the same seat result in exactly 1 success).
- **SC-004**: Real-time chat messages are delivered to all room participants within 1 second of sending.
- **SC-005**: Push notifications reach users' devices within 5 seconds of the triggering event.
- **SC-006**: System supports at least 1,000 concurrent authenticated users without performance degradation.
- **SC-007**: Payment processing (online) completes within 10 seconds from user submission to confirmation.
- **SC-008**: Admin can review and process a pending payment in under 30 seconds (view proof, approve/reject).
- **SC-009**: System availability of 99.5% uptime measured monthly, with health check endpoint responding within 500ms.
- **SC-010**: All file uploads (images, documents) complete within 15 seconds for files up to the maximum allowed size.
- **SC-011**: 95% of users successfully complete the full journey (search trip, book seat, complete trip, rate) on their first attempt without support intervention.
