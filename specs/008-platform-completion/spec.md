# Feature Specification: Platform Completion (Spec-vs-Code Gap Closure)

**Feature Branch**: `008-platform-completion`
**Created**: 2026-04-27
**Status**: Draft
**Input**: User description: "Implement what is missing per `IMPLEMENTATION_PLAN.md`, derived from `requredplan.md` (the original Arabic product spec). Closes the gap across authentication, booking lifecycle, trip-time flow, recurrence, post-payment data reveal, calls, and admin/support."

## Clarifications

### Session 2026-04-27

- Q: Should the platform/communication fee continue to be charged in-app via the existing Cliq integration, or should the app become entirely cash-only? → A: Keep the current payment model unchanged — the platform/communication fee continues to be charged in-app, and the ride fare remains cash/direct between driver and passenger ("outside the app"). No removal of the existing in-app payment integration.
- Q: How should no-show penalties (5% passenger / 10% driver) be collected? → A: Hybrid — if the user has sufficient wallet balance, the penalty is auto-deducted from the wallet at the moment it is recorded; otherwise it is carried forward as debt and collected from the user's next successful booking transaction (mirroring the cancellation-fee mechanic). Same rule applies to the 5% passenger cancellation fee.
- Q: When does a trip require a separate per-trip "Pending Approval" admin step in addition to driver-level approval? → A: Never. Driver-level approval is sufficient — once a driver is approved, every trip they submit publishes directly. The "Pending Approval" trip state is removed from the model.
- Q: For the cash-settlement model, who marks a booking as paid (the trigger that unmasks contact details and unlocks chat/call)? → A: The driver. After receiving cash, the driver presses "Mark paid" on the booking detail to settle it. The passenger does not need to confirm. Until the driver marks paid, contact details remain masked and chat/call stay disabled.
- Q: Should Google/Facebook social login be retained or removed? → A: Removed entirely. Phone+OTP is the only end-user sign-in path. Existing accounts that signed up via social login must be migrated by linking a verified phone number on next sign-in or treated as inactive.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Phone-only sign-in with mandatory driver photo and account-safety guardrails (Priority: P1)

A new passenger or driver opens the app and signs up using only their phone number plus a one-time password (OTP) sent by SMS. Email/password is no longer offered. The first time they sign in from a new device, the system records that device. Drivers cannot complete onboarding without uploading a clear profile photo. If the same device is being used to register many accounts, or a registration looks suspicious, it is flagged for admin review and the account is held in a restricted state until cleared.

**Why this priority**: Identity is the foundation of every trust decision in the product (driver approval, no-show penalties, refunds). Until phone is the single identity, the rest of the spec cannot land cleanly. Spec lines 1, 8, 197–204 mandate it.

**Independent Test**: A new user can register, verify OTP, and reach the home feed without ever seeing an email field. A driver who tries to publish a trip without a profile photo is blocked with a clear message. Registering ten accounts from the same device within a short window flags the latest accounts for review.

**Acceptance Scenarios**:

1. **Given** the app is freshly installed, **When** a user begins registration, **Then** the only identifier requested is a phone number, and verification proceeds via SMS OTP.
2. **Given** a verified user signs in from a previously unused device, **When** the OTP is verified, **Then** the new device is recorded and any other active sessions for that user receive a security notification.
3. **Given** a driver who has not uploaded a profile photo, **When** they submit their profile for approval, **Then** submission is blocked with a message explaining that a profile photo is required.
4. **Given** a device that has already been used to register multiple accounts within 24 hours, **When** a further registration is attempted from that device, **Then** the account is created in a restricted state and an entry appears in the admin review queue.
5. **Given** a driver client reports its location as mocked or spoofed, **When** the location reaches the server, **Then** the update is rejected, the trip cannot be started, and the event is recorded.

---

### User Story 2 — Multi-seat booking with companions, request-based confirmation, and enforced cancellation/no-show policy (Priority: P1)

A passenger browses a trip, selects one or more seats (their own plus any companions, or "pick for me" for a random valid arrangement), and submits the booking as a request. The driver has three hours to accept or reject; if no decision is made, the request is automatically cancelled and the passenger is notified. After confirmation, cancellation rules differ for each side: the driver may cancel only more than 24 hours before departure; the passenger may cancel only more than 12 hours before departure; both are warned of the rule when they attempt to cancel inside the window. A passenger who cancels a confirmed booking incurs a 5% fee. A driver who fails to show up incurs a 10% penalty; a passenger who fails to show up incurs a 5% penalty. All such fees are collected via the hybrid wallet/carry-forward policy (auto-deduct from wallet when balance is sufficient; otherwise carry to next booking). Booking and trip statuses across the system reflect every state listed in the spec (Pending, Confirmed, Cancelled, Rejected, In Progress, No-Show, plus trip states Draft, Published, Fully Booked, In Progress, Completed, Cancelled).

**Why this priority**: This is the core monetization-and-trust loop of the platform. Today seats are single-passenger only, the 3-hour timeout is missing, and there is no enforcement of cancellation windows or no-show penalties — meaning policy in the product spec is not actually being applied.

**Independent Test**: A passenger books two seats in one request (self + companion). The driver receives the request and ignores it; three hours later, the booking auto-cancels and the passenger is informed. A passenger cancels a confirmed booking 5 hours before departure and is blocked with a clear message; the same passenger cancels 24 hours before and incurs a fee that is applied on their next booking.

**Acceptance Scenarios**:

1. **Given** a trip with 4 free seats, **When** a passenger submits a booking for 2 specific seats with companion details, **Then** both seats are reserved under one booking record and the seat plan shows them blocked.
2. **Given** a passenger taps "pick for me" with companion count of 2, **When** the system finds 2 free seats that respect the optional gender-mixing rule, **Then** the booking is created with those seats; if no valid arrangement exists, the request is rejected with a clear reason.
3. **Given** a booking request that has been pending for 3 hours, **When** the timeout fires, **Then** the booking is automatically cancelled, the seats are released, and the passenger receives a notification.
4. **Given** a confirmed booking on a trip departing in 6 hours, **When** the passenger tries to cancel, **Then** cancellation is refused with a clear explanation of the 12-hour rule.
5. **Given** a confirmed booking that the passenger cancels more than 12 hours before departure, **When** the same passenger creates their next booking, **Then** a 5% fee from the previous trip's price is collected as part of that next transaction.
6. **Given** a trip whose departure time has passed by 30 minutes, **When** the driver never started the trip and never confirmed any passenger, **Then** the trip is marked No-Show on the driver's side, a 10% penalty is recorded, and confirmed passengers are notified that the trip did not run.
7. **Given** a confirmed booking where the driver started the trip and marked the passenger as not present, **When** the driver completes the trip, **Then** that booking is marked No-Show on the passenger side and a 5% penalty is recorded.

---

### User Story 3 — Pre-trip confirmation cycle, driver-controlled start, and shareable live tracking (Priority: P2)

When the trip's departure time is approaching, every confirmed passenger receives a notification asking them to confirm that the driver has arrived; the driver receives a separate notification for each passenger asking whether that passenger is present. When the driver is satisfied, they tap "Start Trip" — only then does the trip move into the "In Progress" state. During the trip, the live driver location is visible to all confirmed passengers, and any passenger can generate a public share link to send to family members so they can follow the trip on a map without needing the app.

**Why this priority**: The core safety and "I know my ride is coming / my person got home" loop. Useful but unblocked by Story 2 — it depends on the booking-status overhaul landing first.

**Independent Test**: A trip leaves at 09:00. At 08:30, all passengers and the driver receive the relevant confirmation prompts. The driver taps Start Trip; the trip becomes "In Progress"; a passenger taps Share, gets a link, and a person opening that link in a browser sees a moving marker on a map.

**Acceptance Scenarios**:

1. **Given** a trip departing in 30 minutes with three confirmed passengers, **When** the pre-trip cycle fires, **Then** each passenger is asked to confirm the driver's presence and the driver receives one prompt per passenger.
2. **Given** a driver whose trip has not been started, **When** they tap Start Trip more than 15 minutes before departure, **Then** the action is blocked with a clear timing message.
3. **Given** an in-progress trip, **When** a passenger creates a share link and the link is opened in a browser, **Then** the page renders a map showing the driver's most recent location updating at least every 15 seconds, with no passenger-identifying details exposed.
4. **Given** a share link whose trip has been completed, **When** the link is opened, **Then** the page shows that the trip has ended and stops updating.

---

### User Story 4 — Recurring trips with stops and notes (Priority: P2)

A driver who runs the same route every weekday creates a trip once and marks it as recurring (daily or specific weekdays). The system automatically creates upcoming occurrences. The driver can add intermediate stops with names and free-text notes (e.g., "I stop for fuel at X").

**Why this priority**: Quality-of-life for active drivers, and a frequently requested feature in the spec — but not blocking the trust loop.

**Independent Test**: A driver creates a recurring trip for "every Sunday/Tuesday/Thursday at 08:00" with one intermediate stop and a note. Without further action, the trip appears on the passenger feed for the next four matching dates with the stop and note visible.

**Acceptance Scenarios**:

1. **Given** a driver creating a trip, **When** they choose "repeat weekly on Sun/Tue/Thu", **Then** trip occurrences are automatically generated for the next several upcoming matching dates and become bookable.
2. **Given** a recurring rule, **When** the driver cancels a single occurrence, **Then** future occurrences continue to be generated as scheduled.
3. **Given** a trip with two intermediate stops, **When** a passenger views the trip detail, **Then** the stops appear in order on the route alongside any free-text note from the driver.

---

### User Story 5 — Post-payment data reveal and in-app contact, with optional phone masking (Priority: P2)

A passenger's name and phone number are not visible to the driver, and the driver's phone is not visible to the passenger, until payment for the booking is settled (cash confirmation by the driver or platform fee paid, depending on the model in use). After settlement, both parties can chat in-app (text, images, location) and place a phone call — and either party can opt to keep their real number hidden, in which case calls are routed through a masked number.

**Why this priority**: Privacy guarantee from the spec. Important but blocked behind the booking loop and the payment model decision.

**Independent Test**: Before settlement, passenger contact details on the driver's booking detail screen show as masked. After settlement, the chat and call buttons activate and contact information is revealed. A driver who has set "hide my number" still receives passenger calls but the passenger's call screen shows a proxy number.

**Acceptance Scenarios**:

1. **Given** a confirmed but unsettled booking, **When** the driver opens the booking detail, **Then** the passenger's phone shows as masked, and chat/call controls are disabled with an explanatory message.
2. **Given** a settled booking, **When** the driver opens the booking detail, **Then** the passenger's phone is shown, and chat/call controls are enabled.
3. **Given** a user who has enabled "hide my phone number", **When** the other party places a phone call to them, **Then** the caller dials a proxy number rather than the real one, and the call connects.

---

### User Story 6 — Admin complaints, distinct ban state, and WhatsApp-based support and refunds (Priority: P3)

End users can file a complaint against another user or trip from the app; complaints land in an admin queue with status tracking. Admins can ban users with a recorded reason that is distinct from the existing "deactivate" state — banned users see an explanatory screen on next app open. Support and refund requests are routed to a dedicated WhatsApp number; opening "Support" or "Request Refund" deep-links to WhatsApp with prefilled context, and the act of requesting a refund creates an admin-visible record so nothing falls through the cracks.

**Why this priority**: Operational hygiene for the support team — beneficial but not blocking the user-facing loops above.

**Independent Test**: A passenger files a complaint about a driver; an admin sees it in the dashboard, marks it resolved, and the passenger receives a notification. An admin bans a user; on the user's next app open they see the ban screen with a Contact Support button that opens WhatsApp at the configured number.

**Acceptance Scenarios**:

1. **Given** a completed trip, **When** a passenger files a complaint with a category and description, **Then** a complaint record is created visible to admins with the trip and reporter context attached.
2. **Given** an admin reviewing a complaint, **When** they change its status to "resolved", **Then** the reporter is notified.
3. **Given** an admin banning a user with a written reason, **When** that user opens the app, **Then** they see a ban screen with the reason summary and a Contact Support action that opens WhatsApp deep-linked to the configured support number.
4. **Given** a user requesting a refund, **When** they tap Request Refund, **Then** WhatsApp opens at the configured number with prefilled details (booking reference, amount, reason) and a refund request record is created for the admin queue.

---

### Edge Cases

- **OTP exhaustion**: A user requests too many OTPs in a short window — the system enforces a cooldown and surfaces a clear "try again in N seconds" message.
- **Companion booking partial conflict**: A passenger requests three seats; one of the three seats is taken between submit and confirm. The whole request fails atomically rather than partially booking.
- **Cancellation fee on a user with no future booking**: A passenger owes a 5% fee but never books again — the fee remains as an outstanding charge until the account is settled or written off by an admin.
- **Driver "no-show" ambiguity**: The driver did start the trip but late. Definition of no-show: driver never marked Start Trip and never confirmed any passenger by departure + 30 minutes.
- **Recurring rule clash**: An auto-generated occurrence conflicts with another trip the driver already created manually for the same date — the auto-generated one is skipped, not created in conflict.
- **Live-share link abuse**: A bad actor receives a share link and tries to scrape passenger details from it — the share link only exposes anonymized driver location and trip ETA, never passenger info.
- **Spoofing during a live trip**: A driver enables a fake-location app mid-trip — the system stops accepting their location updates, alerts confirmed passengers, and flags the trip for review.
- **Banned user with active future bookings**: When a user is banned, their pending bookings are auto-cancelled and the affected counterparties are notified.

## Requirements *(mandatory)*

### Functional Requirements

#### Authentication & Identity

- **FR-001**: The system MUST allow users to register and sign in using only a phone number verified by SMS OTP. Email/password registration and Google/Facebook social login MUST NOT be exposed to end users. Existing accounts that previously signed up via social login MUST be migrated to phone-based identity at next sign-in by requiring the user to verify a phone number; accounts that fail to migrate within a configurable window MUST be treated as inactive.
- **FR-002**: The system MUST issue a one-time password to a user-supplied phone number on request, with rate limiting that prevents repeated requests inside a short cooldown window, and MUST clearly tell the user how long they must wait.
- **FR-003**: The system MUST associate each successful OTP verification with the device used, recording at minimum a device identifier, platform, first-seen timestamp, and last-seen timestamp.
- **FR-004**: The system MUST notify all of a user's previously trusted devices when a new device successfully signs in to the same account.
- **FR-005**: An admin MUST be able to revoke a specific device for a specific user, after which any session bound to that device is rejected.
- **FR-006**: The system MUST detect and reject server-bound location updates that the client identifies as mocked or spoofed, and MUST record each such event for review.
- **FR-007**: The system MUST flag accounts for admin review when registrations from one device, IP, or fingerprint exceed configurable thresholds within a configurable window.
- **FR-008**: A driver MUST NOT be able to submit their profile for approval, and an admin MUST NOT be able to approve a driver, while the driver's profile photo is missing.
- **FR-009**: A passenger profile photo MUST be optional.

#### Trips (Driver)

- **FR-010**: A driver who has not been admin-approved MUST be unable to publish a trip, and any attempt MUST surface a clear explanation.
- **FR-011**: When creating a trip, a driver MUST be able to specify origin (map-picked), destination (map-picked), date and time, per-seat price, optional intermediate stops with names and short notes, and optional free-text notes for the trip itself.
- **FR-012**: The trip's seat layout MUST be derived from the driver's vehicle (seat count and arrangement defined when the vehicle was added or last edited), not configured per-trip.
- **FR-013**: A driver MUST be able to mark a trip as recurring (daily, or on specific weekdays) for a chosen end date or count, after which the system automatically generates upcoming occurrences as bookable trips.
- **FR-014**: When a driver cancels a single occurrence of a recurring trip, future occurrences MUST continue to be generated.
- **FR-015**: A driver MUST be able to cancel a trip only if the departure time is more than 24 hours away. Below that window, the system MUST refuse and explain the rule.
- **FR-016**: Trip status MUST move through: Draft → Published → Fully Booked (when no seats remain) → In Progress → Completed; or to Cancelled at any prior point. There is no per-trip admin approval step — driver-level approval (FR-010) is sufficient, so a published-by-an-approved-driver trip is immediately bookable.

#### Trips (Passenger Browsing)

- **FR-017**: A passenger MUST be able to browse a feed of upcoming published trips.
- **FR-018**: The passenger MUST be able to filter by from-location, to-location, city, and date, and sort by nearest or newest.
- **FR-019**: A trip detail view MUST show driver basic info, vehicle info, price, departure time, available seats, and route with any stops.

#### Bookings & Seats

- **FR-020**: A passenger MUST be able to book one or more seats on a trip in a single booking request (themselves plus companions), entering at minimum a display name and gender for each companion.
- **FR-021**: A passenger MUST be able to ask the system to auto-pick valid seats given a desired number of seats, including respecting the optional gender-mixing rule when the trip has it enabled.
- **FR-022**: The seat plan MUST visually distinguish booked-by-male, booked-by-female, available, and the user's own selection.
- **FR-023**: A booking MUST be created in the Pending state and require explicit driver acceptance to become Confirmed.
- **FR-024**: A booking that remains in the Pending state for more than 3 hours MUST be automatically cancelled, the seats released, and the passenger notified.
- **FR-025**: A passenger MUST be able to cancel a confirmed booking only if departure is more than 12 hours away. Below that window, the system MUST refuse and explain the rule.
- **FR-026**: When a passenger cancels a confirmed booking outside the protected window, the system MUST record a 5% cancellation fee against that passenger as a Pending Charge. Collection MUST follow the hybrid policy: if the user has sufficient wallet balance at the moment the charge is recorded, the system auto-deducts and marks the charge applied; otherwise the charge is carried forward and collected from the user's next successful booking transaction.
- **FR-027**: When a trip's departure time has passed by a system-defined grace window (default 30 minutes) and the driver has not started the trip nor confirmed any passenger, the trip MUST be marked as a driver no-show, a 10% penalty MUST be recorded as a Pending Charge against the driver (collected via the hybrid wallet-auto-deduct-then-carry-forward policy in FR-026), and confirmed passengers MUST be notified that the trip did not run.
- **FR-028**: When a driver completes a trip and has marked specific bookings as passenger-not-present, those bookings MUST be marked No-Show and a 5% penalty MUST be recorded as a Pending Charge against each affected passenger (collected via the hybrid policy in FR-026).
- **FR-029**: Booking status MUST cover: Pending, Confirmed, Cancelled, Rejected, In Progress, Completed, No-Show.
- **FR-030**: An outstanding cancellation or no-show charge MUST be visible to the user and to admins, and an admin MUST be able to waive it.

#### Trip-Time Flow

- **FR-031**: Approximately 30 minutes before departure, every confirmed passenger MUST receive a notification asking them to confirm the driver's presence, and the driver MUST receive a per-passenger notification asking whether each passenger is present.
- **FR-032**: A driver MUST be able to mark each confirmed passenger as present or not-present individually before starting the trip.
- **FR-033**: A driver MUST be able to start the trip only when within a system-defined window before departure (default: 15 minutes before through trip-time). Outside the window, the action MUST be refused with a clear timing message.
- **FR-034**: While a trip is In Progress, the driver's most recent geographic location MUST be visible to confirmed passengers in the app at a refresh interval of at most 15 seconds.
- **FR-035**: A confirmed passenger MUST be able to generate a public share link for the active trip that anyone (including non-app users in a browser) can open to view the live driver location and trip ETA, with no passenger-identifying information exposed.
- **FR-036**: When the trip is completed or cancelled, the public share link MUST stop showing live updates and instead show that the trip has ended.

#### Payment & Data Reveal

- **FR-037**: Until a booking is settled, a passenger's contact details MUST be hidden from the driver and vice versa, with masked placeholders shown instead. A booking is "settled" when the driver explicitly marks it as paid via a "Mark paid" action on the booking detail. The platform/communication fee being paid in-app is independent of this settlement action.
- **FR-038**: The chat and phone-call features for a booking MUST be inaccessible until the booking is settled (FR-037).
- **FR-038a**: The driver MUST be able to undo a "Mark paid" action only within a short grace window (default 5 minutes) and only if neither chat nor call has been used; after the grace window or first contact, settlement is irreversible without admin intervention.
- **FR-039**: After settlement, the system MUST provide an in-app chat room for the booking that supports text, images, and location sharing, and a separate group chat room covering the entire trip (driver + all confirmed passengers).
- **FR-040**: Both a passenger and a driver MUST be able to set a profile preference to hide their real phone number; when set, calls and post-payment displays MUST use a proxy/masked number.
- **FR-041**: New chat messages MUST trigger a push notification to the recipient(s) when the app is not in the foreground.

#### Admin & Operations

- **FR-042**: An admin MUST be able to approve or reject driver applications, with rejection requiring a reason that is shown to the driver.
- **FR-043**: An admin MUST be able to ban a user with a recorded reason, distinct from "deactivate"; banned users on next app open MUST see a ban screen with the reason summary and a Contact Support action.
- **FR-044**: When a user is banned, all of their currently pending or confirmed bookings MUST be automatically cancelled and the affected counterparties notified.
- **FR-045**: An end user MUST be able to file a complaint against a driver, passenger, or trip, with category, description, and optional attached references; admins MUST be able to view, comment on, and change the status of complaints.
- **FR-046**: The admin dashboard MUST display, at minimum: total users, total trips by status, total bookings by status, revenue, and outstanding penalty charges, filterable by date range.
- **FR-047**: The Support and Refund actions in the user app MUST open WhatsApp deep-linked to the configured support phone number (`+962 78 888 3007`) with prefilled context (user identifier and the relevant booking reference where applicable).
- **FR-048**: A refund request initiated from the app MUST also create a server-side record so the admin can track that it was raised, even though the conversation continues in WhatsApp.

#### Notifications

- **FR-049**: The system MUST send push notifications for: booking request received (driver), booking decision made (passenger), pre-trip confirmation prompts (both sides), trip started, trip cancelled by other side, new chat message, complaint status changes, ban applied, new device sign-in, penalty charge applied.

### Key Entities *(include if feature involves data)*

- **User**: A person using the app. Distinguished by role (passenger, driver, admin) and identified by phone number. Holds profile fields including name, photo, gender, city, hide-phone preference, ban state and reason.
- **Device**: A device a user has signed in from. Holds device identifier, platform, first-seen and last-seen timestamps, trusted state, and revoked state. Belongs to one user.
- **Vehicle**: A driver's car. One-per-driver. Holds type, model, plate number, seat count, seat layout (rows/columns), driver-license document, vehicle-license document.
- **Trip**: A driver-published journey from one location to another at a specific time. Holds origin and destination (with map coordinates), departure time, per-seat price, total/available seats, optional stops, optional notes, status (Draft / Published / Fully Booked / In Progress / Completed / Cancelled), recurrence rule reference (if any), seat plan, communication-fee status.
- **Recurrence Rule**: The pattern (daily / weekdays + until-date) that auto-generates trip occurrences for a driver.
- **Booking**: A passenger's request for one or more seats on a trip. Holds the requested seats (with companion name and gender per seat), status, cancellation reason and party, settlement state and `settledAt` timestamp (set when the driver presses "Mark paid"), presence-confirmation timestamps for both sides.
- **Pending Charge**: An outstanding fee (5% cancellation, 5%/10% no-show, etc.) recorded against a user, tied to its origin booking, with status (pending / applied / waived) and resolution context.
- **Complaint**: A user-filed report against another user or trip, with category, description, status, admin notes, and resolution timestamps.
- **Refund Request**: A server-side record of a refund the user raised through the in-app action; tracks status and the WhatsApp handoff timestamp.
- **Account Flag**: A risk signal (multi-account-from-device, geo-mismatch, GPS-spoof event, etc.) attached to a user, with severity and admin disposition.
- **Trip Share Link**: A public token granting read-only access to the live location and ETA of an in-progress trip, with an expiry tied to trip completion.
- **Chat Room and Message**: Container for messages tied to a booking (1:1) or trip (group), and individual messages supporting text, image, and location payload types.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of new sign-ups complete using only phone + OTP — no successful registration is recorded against email/password.
- **SC-002**: Drivers without a profile photo cannot complete onboarding — measured by zero approved drivers having a missing photo at the end of any reporting day.
- **SC-003**: 95% of pending booking requests receive an explicit driver decision before the 3-hour timeout fires; the remainder are auto-cancelled and the passenger is notified within 60 seconds of timeout.
- **SC-004**: 100% of attempted cancellations inside the protected windows (24h driver / 12h passenger) are blocked with a clear in-app explanation of the rule.
- **SC-005**: Every recorded passenger no-show or cancellation fee is either collected on the next booking, settled from wallet balance, or explicitly waived by an admin within 30 days; the proportion left unresolved beyond 30 days stays below 5%.
- **SC-006**: A passenger can complete a multi-seat booking (self + 1 companion) in under 90 seconds from opening the trip detail to receiving the request-submitted confirmation.
- **SC-007**: For 95% of trips, all confirmed passengers receive their pre-trip confirmation prompt within ±2 minutes of the scheduled 30-minutes-before-departure target.
- **SC-008**: 99% of share-link page loads during an active trip render the driver's most recent location no older than 20 seconds.
- **SC-009**: Driver and passenger contact details are not visible to the other party in any pre-settlement state — verified by automated tests covering 100% of booking detail and chat entry points.
- **SC-010**: Mocked/spoofed location attempts are rejected at the server in 100% of detected cases; flagged events surface in the admin dashboard within 5 minutes.
- **SC-011**: At least 90% of complaints reach a resolved or rejected status within 7 days of filing.
- **SC-012**: Banned users are blocked from creating new bookings or trips with 100% reliability and see the ban screen on their next app open within one app session.
- **SC-013**: Refund and Support deep-links open WhatsApp at the configured support number with prefilled context in 100% of attempts on supported platforms; for each in-app refund request, a corresponding admin-visible record exists.

## Assumptions

- **Localization**: The product remains bilingual Arabic + English; every new user-facing string ships in both. Arabic is the primary copy of record where requirements are sourced.
- **Geographic scope**: Primary launch market is Jordan; phone numbers default to country code +962 but the system accepts E.164 numbers from other countries (with allow-list rules controlled by admins).
- **Currency**: Trip prices are in Jordanian Dinar (JOD) by default; cancellation/no-show penalties are computed and tracked in the same currency as the underlying trip price.
- **Payment collection**: Ride fare is settled outside the app between driver and passenger (cash / direct agreement). The platform/communication fee is collected in-app via the existing Cliq integration; this is the model going forward (resolved in CLAR-001).
- **Time zone for windowed rules**: 24h driver-cancel and 12h passenger-cancel windows are computed against the trip's local departure time.
- **No-show grace window**: Default 30 minutes after scheduled departure; admin-configurable.
- **Pre-trip notification timing**: Default 30 minutes before scheduled departure; admin-configurable.
- **Recurrence horizon**: The system maintains the next 7 occurrences of any active recurring rule visible on the passenger feed at any time.
- **Live-tracking refresh**: Driver clients send location updates at most every 5–15 seconds while a trip is In Progress; share-link viewers may see updates at the same cadence.
- **Existing capabilities reused**: Chat, ratings, Google Maps integration, Firebase push, base seat-layout rendering with gender adjacency, driver-approval gate, and one-vehicle-per-driver constraint already exist and are reused — they are not re-implemented by this feature.
- **OTP delivery**: Continued use of the project's existing SMS provider.
- **GPS spoof detection scope**: Server-side rejection of location updates that the client self-reports as mocked is in scope; deeper anti-cheat (root/jailbreak detection, proxy detection) is out of scope for this feature.
- **Refund execution**: Money movement for refunds happens outside the app via WhatsApp; the in-app system only tracks the request as an admin-visible record.

## Resolved Clarifications

All scope-shaping clarifications raised during `/speckit.specify` have been resolved during the `/speckit.clarify` session above. They are recorded here as a stable summary and in the `## Clarifications` section above as Q/A bullets.

- **CLAR-001 — Payment model**: RESOLVED — payment model stays as-is: the platform/communication fee is charged in-app (existing Cliq integration retained); the ride fare is settled outside the app between driver and passenger.
- **CLAR-002 — Social login**: RESOLVED — Google/Facebook OAuth is removed; phone+OTP is the sole end-user sign-in path. Existing social-login accounts get a one-time phone-link migration on next sign-in.
- **CLAR-003 — No-show fee mechanic**: RESOLVED — hybrid collection: auto-deduct from wallet when balance is sufficient; otherwise carry forward to the next booking transaction. Applies uniformly to the 5% passenger cancellation fee, the 5% passenger no-show penalty, and the 10% driver no-show penalty. Top-up is never forced.
- **CLAR-004 — Per-trip admin approval**: RESOLVED — no per-trip approval; driver-level approval is sufficient.
- **CLAR-005 — Cash settlement trigger**: RESOLVED — driver presses "Mark paid" on the booking detail; the action is reversible only within a 5-minute grace window if no contact has occurred.
