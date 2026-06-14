# Feature Specification: App UX Improvements — Error Messaging, Push Notifications, Real Route Rendering

**Feature Branch**: `007-app-ux-improvements`
**Created**: 2026-04-23
**Status**: Draft
**Input**: User description: "C:\Users\zezo\Desktop\work\wisoway\app_improvement_execution_plan.md" — a three-part improvement plan covering (1) user-friendly error messages, (2) push notifications for trip lifecycle events, (3) replacing the straight-line trip preview with the real road route.

## Clarifications

### Session 2026-04-23

- Q: Is iOS notification delivery in scope for this feature's initial release, or deferred? → A: Android + iOS both in scope at initial release.
- Q: When a passenger creates a booking on a driver-posted trip, who receives the push notification? → A: The driver who posted the trip.
- Q: Who should be notified when a driver posts a new trip? → A: All signed-in users in the same city as the trip's origin.
- Q: What authoritative source defines a user's city for notification targeting? → A: Explicit profile field set at onboarding and editable in settings (no continuous location tracking required).
- Q: When one user is signed in on multiple devices concurrently, which devices receive each notification? → A: All devices with a valid active registration for that user.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Clean, user-friendly error messages across the app (Priority: P1)

Across every screen of the passenger and driver mobile app, when something goes
wrong — the phone is offline, the server is down, a session has expired, the
action conflicts with existing data, a permission was denied, or an unexpected
condition occurs — the user sees a short, plain-language message that explains
what happened and, when applicable, what they can do about it. The user never
sees raw technical strings such as stack traces, exception class names, HTTP
status codes, or null-reference errors.

**Why this priority**: Error messages are the single most visible reliability
signal to end users and touch every flow in the app. Fixing the error surface
improves trust immediately and is a prerequisite for confidently shipping the
two other features, which will introduce new failure modes (notification
permission denial, route-service failure).

**Independent Test**: A tester can trigger representative failure conditions —
airplane mode, expired session, server 5xx, duplicate booking, denied location
permission — and confirm that every resulting message is in plain language
(matching the app's Arabic/English style guide), is non-technical, names the
problem, and offers a next step where one exists. This test requires no
notification or routing work.

**Acceptance Scenarios**:

1. **Given** the device has no internet connection, **When** the user taps any
   action that calls the backend, **Then** the app displays a connectivity
   message in the user's language telling them the device is offline and to
   retry once connected.
2. **Given** the user's session has expired, **When** the user performs an
   authenticated action, **Then** the app displays a "session expired — please
   sign in again" message and routes them to the sign-in flow.
3. **Given** the backend returns a 5xx server error, **When** the user is
   performing any action, **Then** the app shows a generic "something went
   wrong on our side, please try again later" message without exposing the
   status code or exception type.
4. **Given** the user attempts to create a booking that conflicts with an
   existing one, **When** the backend rejects the request with a business-rule
   error, **Then** the app shows the specific plain-language reason (e.g.,
   "this booking already exists or the selected time is taken").
5. **Given** any unexpected error occurs in the app, **When** the error reaches
   the UI layer, **Then** the UI shows a safe fallback message and the original
   technical error is still captured in the developer log stream for
   diagnostics.

---

### User Story 2 — Push notifications for trip lifecycle events (Priority: P2)

Passengers and drivers receive push notifications on their mobile devices for
the events that affect them: a passenger sees a notification when their
booking is confirmed or rejected; the driver who posted a trip sees a
notification when a passenger books it; signed-in users whose current city
matches a newly-posted trip's origin city receive a notification about the
new trip. Tapping a notification takes the user directly to the related
screen (booking details, trip details) rather than just opening the home
screen.

**Why this priority**: Notifications convert the app from a pull-only
experience (user opens app, user checks state) to a push experience and
materially improve response times for time-sensitive actions like accepting a
booking. It is second priority because the error-handling layer (US1) should
be in place so that notification-delivery and permission failures are handled
cleanly.

**Independent Test**: A tester on a real device (Android, and iOS if in scope)
grants notification permission, performs the triggering action from a second
account, and confirms: (a) the notification arrives in foreground, background,
and cold-start states; (b) the notification text is correct and localized;
(c) tapping it lands on the intended screen with the correct entity loaded.
Delivery can be tested independently of route rendering and independently of
individual error-handling improvements.

**Acceptance Scenarios**:

1. **Given** a signed-in user who has granted notification permission,
   **When** an event that affects them occurs (booking confirmed, booking
   rejected, relevant new trip posted, their trip booked by a passenger),
   **Then** a push notification is delivered to their device within a short
   delivery window.
2. **Given** the app is in the background or closed, **When** a notification
   arrives and the user taps it, **Then** the app opens and navigates to the
   specific screen and entity referenced by the notification (e.g., the exact
   booking).
3. **Given** the app is in the foreground, **When** a notification arrives,
   **Then** it is displayed non-intrusively in-app and, when tapped or
   actioned, navigates to the referenced entity.
4. **Given** a user denies notification permission, **When** the app later
   attempts to use notification features, **Then** the app does not crash,
   does not repeatedly re-prompt, and degrades gracefully (in-app inbox or
   silent no-op) with a clear setting to re-enable.
5. **Given** a user signs out or uninstalls the app, **When** subsequent
   events fire, **Then** notifications are not delivered to that former device
   token.

---

### User Story 3 — Real road route on the trip map (Priority: P3)

When a passenger opens a trip on the map, the route drawn between the origin
and the destination follows the actual road path — turning with streets,
respecting one-way roads, accounting for detours — rather than drawing a
straight line between the two points. Start and end markers are visible, and
the map camera frames the whole route.

**Why this priority**: This is visibly important but it does not block trips
from happening today (the booking logic is unaffected). It is sequenced last
because it depends on an external routing capability and is easier to validate
once US1's error handling covers routing-service failures.

**Independent Test**: A tester opens trip details for a variety of trips —
short urban, long intercity, trips with major road detours — and visually
confirms the drawn polyline follows real roads, that start and end markers
are at the correct points, and that the map is zoomed/panned to show the full
route. This test is independent of notifications and of error-message rewrites.

**Acceptance Scenarios**:

1. **Given** a passenger opens a trip's details, **When** the map loads,
   **Then** the route displayed between origin and destination follows the
   actual road network, not a straight line.
2. **Given** the map is displayed, **When** the user views it, **Then** the
   origin is marked with a start marker, the destination with an end marker,
   and the camera fits the full route on-screen.
3. **Given** the routing service is unavailable or returns no route, **When**
   the map loads, **Then** the app displays the two markers with a clear
   "route unavailable" message consistent with the error-handling style
   defined in US1, and does not crash.
4. **Given** a trip has changed origin or destination, **When** the user
   re-opens the trip, **Then** the displayed route reflects the latest
   coordinates rather than a stale route.

---

### Edge Cases

- User tries to act while the device is offline → single clear offline
  message, not a stack of generic error toasts from each failed dependency.
- Backend returns an error structure the app has never seen before (new error
  code) → fallback to a generic-but-safe user message while the original
  payload is logged for developers.
- Notification permission is granted on one device and revoked on another of
  the same account → revoked device stops receiving; granted device continues.
- App is uninstalled between when a notification was queued and when it would
  have delivered → no delivery attempt should produce user-visible fallout on
  a reinstall.
- User receives a notification for a booking that has since been canceled by
  the other party → tapping it takes the user to a state that reflects the
  current (canceled) status, with an appropriate message, not a broken screen.
- Routing service returns a very long route (cross-region) → camera framing
  still produces a legible view rather than a globe-level zoom.
- Origin and destination are the same point or extremely close → the map
  renders without zero-distance errors and without spinning forever waiting
  for a route.
- Routing service rate-limits the app → requests degrade gracefully with the
  standard error-handling treatment, and a recent route is reused if
  available.

## Requirements *(mandatory)*

### Functional Requirements

**Error handling (US1)**

- **FR-001**: The mobile app MUST translate every exception that reaches the
  UI layer (from network, backend responses, platform permissions, location
  services, map rendering, notification subsystem, JSON parsing, authentication,
  and unexpected runtime errors) into a plain-language, localized user-facing
  message.
- **FR-002**: User-facing messages MUST NOT contain stack traces, exception
  class names, HTTP status codes, raw backend error strings, or technical
  phrases such as "null is not a subtype of" or "SocketException".
- **FR-003**: The app MUST classify errors into stable categories that cover,
  at minimum: connectivity, server failure, validation/business rule,
  authentication/session, permission, and unknown-fallback.
- **FR-004**: Every error surfaced to the user MUST also be captured in a
  developer-facing log record that preserves the original error, stack trace,
  and correlating request id; the developer record is never shown to the user.
- **FR-005**: Business-rule errors returned by the backend (e.g., "booking
  already exists") MUST be surfaced to the user with a message specific to
  that business rule, not with a generic fallback.
- **FR-006**: Session-expiry errors MUST route the user to the sign-in flow
  after displaying a "session expired" message.

**Push notifications (US2)**

- **FR-007**: The mobile app MUST request notification permission at a
  moment in the user journey when the value is clear, and MUST handle both
  grant and deny outcomes without regressions.
- **FR-008**: The app MUST register each signed-in user's device with the
  backend so the backend can deliver targeted notifications to that device;
  registration MUST update when the user signs in, signs out, or switches
  devices. A single user MAY have any number of concurrently active device
  registrations (phone, tablet, replacement device in transition), and
  notifications addressed to that user MUST be delivered to every device with
  a currently-valid registration. Only registrations reported as invalid by
  the delivery platform (see FR-014) are excluded.
- **FR-009**: The backend MUST support sending notifications to: a specific
  user, a fan-out list of users, and a city-scoped audience (all signed-in
  users whose profile `city` value matches the trip's origin city). The
  city-scoped audience is the targeting rule for "new trip posted"
  notifications.
- **FR-009a**: Every signed-in user MUST have a `city` value on their
  profile, set during onboarding and editable in settings; no location-
  permission or continuous-location tracking is required to determine the
  targeting city.
- **FR-010**: The backend MUST send a notification for each of the following
  events, addressed to the party identified:
  - **Booking created** → delivered to the driver who posted the trip.
  - **Booking confirmed** → delivered to the passenger who created the booking.
  - **Booking rejected or canceled** → delivered to the opposing party (the
    passenger if the driver rejects/cancels; the driver if the passenger
    cancels).
  - **New trip posted** → delivered to the set of users the trip is relevant
    to (targeting criteria defined in FR-009).
  Trip reminders are a deferred enhancement (see Assumptions).
- **FR-011**: Every notification MUST carry structured metadata sufficient
  for the app to deep-link to the correct screen and entity (e.g., booking
  details for a specific booking id).
- **FR-012**: Tapping a notification MUST open the referenced screen with the
  referenced entity loaded, whether the app was in foreground, background, or
  not running.
- **FR-013**: Notifications MUST display correctly and non-intrusively when
  the app is in the foreground.
- **FR-014**: Device registrations MUST be invalidated when they are reported
  as unregistered by the delivery platform, so stale devices stop receiving.

**Real route rendering (US3)**

- **FR-015**: The passenger map, when showing a trip, MUST render the route
  between origin and destination as a polyline that follows the actual road
  network rather than a straight line.
- **FR-016**: The map MUST display a distinct start marker at the origin and
  a distinct end marker at the destination.
- **FR-017**: The map MUST frame the viewport so the full route, start
  marker, and end marker are visible on first load.
- **FR-018**: When the routing capability is unavailable or returns no route,
  the map MUST display the markers and a user-friendly "route unavailable"
  message consistent with US1, and MUST NOT leave the user staring at a blank
  or infinitely-loading map.
- **FR-019**: The app MUST invalidate or refresh the drawn route when trip
  origin or destination changes.

**Cross-cutting**

- **FR-020**: New failure modes introduced by push notifications and route
  rendering MUST be handled through the same error-classification surface
  defined in FR-003 — no direct stack-trace leakage is acceptable from these
  features.

### Key Entities *(include if feature involves data)*

- **Device Registration**: the linkage between a signed-in user account and a
  specific mobile device capable of receiving push notifications; includes the
  device-identifying push token, the account it belongs to, and metadata about
  when it was last seen active. Invalidated on sign-out or when the delivery
  platform reports the token as unregistered.
- **Notification**: a delivered message addressed to one user's device;
  carries a user-visible title/body and a structured payload identifying the
  referenced screen and entity (e.g., booking id, trip id) for deep-linking on
  tap.
- **Notification Trigger**: a business event in the backend (booking created,
  booking confirmed, booking rejected, booking canceled, trip posted) that
  fans out to zero or more notifications addressed to relevant users'
  registered devices.
- **Trip Route**: the geospatial road-following path between a trip's origin
  and destination, rendered on the passenger map; derived from the trip's
  origin and destination and refreshed when either changes.
- **User Error Category**: a stable classification of any error surfaced to
  the user — at minimum connectivity, server, validation/business,
  authentication, permission, unknown — used to pick a localized user
  message while preserving full developer context separately.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At least 95% of error toasts/dialogs shown to users during a
  post-release audit across the app's primary flows are in plain, localized
  language; zero occurrences of exception class names, stack traces, or raw
  HTTP status codes are observed.
- **SC-002**: Every identified error source in the app (network, backend,
  permissions, auth, map, location, notifications, JSON parsing) is covered
  by the centralized error-handling treatment — 100% audit coverage before
  release.
- **SC-003**: Users who have granted notification permission receive a
  notification for each target event (booking confirmed, booking rejected,
  booking created against their trip, relevant new trip) within one minute of
  the event in at least 95% of attempts during end-to-end testing.
- **SC-004**: Tapping a notification opens the intended screen with the
  correct entity in at least 99% of test attempts across foreground,
  background, and cold-start states.
- **SC-005**: Denying notification permission does not produce any crash, and
  the app offers a clear path to re-enable notifications from inside the app.
- **SC-006**: On a representative sample of real trips (short urban, long
  intercity, trips crossing one-way networks), the route drawn on the map
  visibly follows the road network and the camera frames the full route —
  0 occurrences of straight-line renders across the sample.
- **SC-007**: When the routing capability is unavailable, the trip map
  degrades to markers-plus-message within the error-handling style, and does
  not produce a blank or indefinitely-loading map in any tested failure
  scenario.
- **SC-008**: Support tickets referencing confusing or technical error
  messages drop by at least 50% in the first reporting window after release,
  relative to the prior comparable window.

## Assumptions

- "The mobile app" refers to the Flutter passenger/driver app in this
  repository; the admin dashboard is not in scope for this feature.
- The backend already has authenticated user accounts, booking lifecycle
  events, and trip records with origin/destination coordinates — these are
  the substrate this feature builds on, not part of its scope.
- A third-party push-delivery service and a third-party routing/directions
  service will be used. Selection, credentials, quota, and cost management
  are treated as solved by the implementation phase; this spec is agnostic to
  the specific vendor.
- Android and iOS are both in scope for notification delivery in the initial
  release; both platforms MUST ship with working permission flows, device
  registration, and deep-link handling before the feature is considered
  complete.
- Trip reminders and other future notification types (trip updates beyond
  booking/cancellation) are deferred to a later release and are explicitly
  out of scope here.
- Waypoints and multi-stop routes on the map are out of scope for the initial
  release; only origin-to-destination is in scope.
- Existing authentication and session handling are trusted; this feature
  relies on them rather than modifying them.
- Localization already exists for Arabic and English in the app; new
  user-facing strings will be authored in both languages within the existing
  localization system.
- Centralized logging for developer-facing error records is available or will
  be stood up as part of this feature's engineering work; its specific
  destination (console, file, remote log sink) is an implementation detail.
