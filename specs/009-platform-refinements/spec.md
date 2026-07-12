# Feature Specification: Platform Refinements (Localization, Admin Alerts & Trip-Creation UX)

**Feature Branch**: `009-platform-refinements`
**Created**: 2026-06-14
**Status**: Draft
**Input**: User description (Arabic):
"- التأكيد على وجود الترجمة بشكل صحيح.
- إشعارات على الجوال من الداشبورد عند تسجيل سائقين أو دفعات.
- بعد قبول حساب السائق لا يقبل إنشاء رحلة إلا بعد الخروج من التطبيق.
- عند كتابة مكان الإنطلاق والوصول يجب إعطاء اقتراحات مباشرة.
- عند اختيار نوع السيارة يكون التخطيط موجود تلقائي."

## Clarifications

### Session 2026-06-14

- Q: How should admins receive driver-registration and payment alerts "on mobile" (the dashboard is web/React)? → A: Web push — the dashboard sends browser push notifications to admin/operator users (works on desktop and mobile browsers, no app install required); no end-user app channel is used for these operational alerts.
- Q: After an admin approves a driver, when must the running app allow trip creation without a full restart? → A: The app re-checks approval status when the driver opens the create-trip flow and when the app returns to the foreground (no real-time push or background polling required).
- Q: Which payment events trigger an admin alert? → A: Successful in-app platform/communication-fee payments only (consistent with the retained in-app payment model from feature 008); penalties, wallet top-ups, and refunds do not fire admin alerts.
- Q: Which surfaces does the translation-correctness pass cover? → A: Both the mobile app (all primary flows, including its push/server-originated messages) and the React admin dashboard.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Approved driver can publish a trip without restarting the app (Priority: P1)

A driver finishes onboarding and waits for admin approval. The moment the admin approves the account, the driver — who still has the app open — taps "Create trip" and is allowed to proceed. The driver does **not** have to close and reopen the app for the approval to take effect. Today, an approved driver is still blocked from creating a trip until they fully exit and relaunch the app, which makes the platform feel broken at the most important moment of a driver's first session.

**Why this priority**: Trip creation is the single revenue-generating action a driver performs. A driver who has just been approved is at peak motivation; forcing an app restart (which many users won't think to do) silently strands brand-new approved drivers and looks like a rejection. This is a correctness defect on the core driver journey, so it ranks above all enhancements.

**Independent Test**: Approve a driver from the dashboard while their app is open and idle on the home screen. Without the driver closing the app, have them attempt to create a trip; creation must be allowed. Repeat with the app sent to the background and brought back to the foreground (no full restart) — creation must still be allowed.

**Acceptance Scenarios**:

1. **Given** a driver whose account is still pending and who has the app open, **When** an admin approves the account and the driver next opens the create-trip flow or brings the app back to the foreground, **Then** the app reflects the approved state and the "Create trip" action becomes available without an app restart.
2. **Given** an approved driver who never restarted the app since approval, **When** they open the trip-creation flow, **Then** they can complete and publish a trip with no "account not approved" block.
3. **Given** a driver whose account is still pending, **When** they attempt to create a trip, **Then** they are shown a clear message that their account is awaiting approval (not a generic or silent failure).
4. **Given** an approved driver who backgrounds and re-foregrounds the app, **When** they return, **Then** the approved state persists and trip creation remains available.

---

### User Story 2 — Live place suggestions while typing origin and destination (Priority: P1)

When a driver creating a trip (or a passenger searching) types into the "From" (departure) or "To" (arrival) field, a list of matching place suggestions appears immediately and updates as they keep typing. The user picks a suggestion instead of typing a full address, and the field is filled with the chosen place and its exact location. Today the location fields do not offer direct suggestions, so users must type free text and the resulting locations are inconsistent and error-prone.

**Why this priority**: Accurate origin and destination are the backbone of matching, distance, pricing, and nearby-trip search. Free-text entry produces mismatched or unmappable locations that degrade every downstream feature. Real-time suggestions are the standard expectation for any ride app and directly raise booking accuracy.

**Independent Test**: In the trip-creation (and trip-search) location field, type the first few characters of a known place; a ranked suggestion list appears within about a second and refines with each keystroke. Selecting a suggestion fills the field with the place name and captures its coordinates, which then flow into the rest of the flow.

**Acceptance Scenarios**:

1. **Given** an empty "From" or "To" field, **When** the user types at least the minimum trigger characters, **Then** a ranked list of matching place suggestions appears and updates as more characters are typed.
2. **Given** the suggestion list is shown, **When** the user taps a suggestion, **Then** the field is populated with that place and its precise location is captured for use in the trip.
3. **Given** the user's selected language is Arabic or English, **When** suggestions are shown, **Then** they are returned in that language and biased to the platform's service region.
4. **Given** a query that matches no places, **When** the user finishes typing, **Then** a clear "no matching places" state is shown rather than an empty or broken list.
5. **Given** the device is offline or the suggestion lookup fails, **When** the user types, **Then** the field degrades gracefully (clear notice, manual entry still possible) without crashing the flow.

---

### User Story 3 — Seat layout appears automatically from the chosen vehicle type (Priority: P2)

When a driver selects their vehicle type during trip creation, the matching seat layout (number of seats and their arrangement) is generated and displayed automatically. The driver does not manually build or count the seat map; choosing "4-seat sedan", "7-seat van", etc. immediately produces the correct seat plan that passengers will later book against. Today the seat layout is not derived automatically from the vehicle type, leading to mismatched or manually-entered seat configurations.

**Why this priority**: The seat plan drives multi-seat booking, companion seating, and the gender-mixing rule. An automatic, correct layout per vehicle type removes a common source of setup error and is a prerequisite for reliable seat selection, but it depends on the trip-creation flow being reachable (Story 1) and is less urgent than that blocker.

**Independent Test**: In trip creation, pick each supported vehicle type in turn; each selection immediately renders the corresponding seat layout (correct seat count and arrangement) with no manual seat configuration. Switching the vehicle type updates the layout to match the new type.

**Acceptance Scenarios**:

1. **Given** the driver is creating a trip, **When** they select a vehicle type, **Then** the seat layout for that type is displayed automatically with the correct number and arrangement of bookable seats.
2. **Given** a seat layout has been auto-generated, **When** the driver changes the vehicle type, **Then** the layout is replaced with the one matching the newly selected type.
3. **Given** an auto-generated layout, **When** the driver proceeds, **Then** the available seats offered for booking match exactly the auto-generated layout (no more, no fewer).
4. **Given** a vehicle type that has no defined layout, **When** it is selected, **Then** the system applies a sensible default and flags the gap rather than showing an empty seat map.

---

### User Story 4 — Admins are alerted via dashboard web push when a driver registers or a payment is received (Priority: P2)

A platform administrator/operator who is responsible for the dashboard receives a browser (web) push notification — delivered to whichever device runs their dashboard browser, desktop or mobile — the moment a new driver registers (so they can review and approve quickly) and the moment a successful in-app fee payment is received (so they can monitor revenue and reconciliation). Tapping the notification opens the relevant record in the dashboard. This closes the loop with Story 1: faster driver-registration alerts mean faster approvals, which is exactly when drivers expect to start working.

**Why this priority**: Driver approvals and payment monitoring are time-sensitive operational tasks. Without real-time alerts, admins must keep the dashboard open to notice new drivers or payments, so approvals lag and new drivers wait. Real-time alerts shorten approval turnaround and improve financial oversight, but the platform can still function (manually) without them, so it ranks below the core driver-facing fixes.

**Independent Test**: With an admin/operator subscribed to dashboard alerts, complete a new driver registration; the admin's dashboard browser receives a web push notification identifying the new driver within roughly a minute. Record an in-app fee payment; the admin receives a web push notification with the payment context. Tapping each notification opens the corresponding driver or payment record in the dashboard.

**Acceptance Scenarios**:

1. **Given** an admin/operator subscribed to alerts, **When** a new driver completes registration, **Then** that admin receives a dashboard web push notification identifying the driver and the pending-approval action within a short, bounded interval.
2. **Given** an admin/operator subscribed to alerts, **When** a successful in-app fee payment is recorded, **Then** that admin receives a dashboard web push notification stating the amount and context (e.g., which payer/booking).
3. **Given** an alert notification, **When** the admin taps it, **Then** the relevant driver-review or payment record opens directly in the dashboard.
4. **Given** multiple admins, **When** an alert event occurs, **Then** only admins configured to receive that event type are notified (no end-users receive these operational alerts).
5. **Given** an admin has disabled a given alert type, **When** that event occurs, **Then** they do not receive that notification.

---

### User Story 5 — Complete and correct Arabic/English translations across the app and dashboard (Priority: P3)

Every screen, button, message, and notification in the mobile app appears fully translated and correct in both Arabic and English, with no missing entries, no raw translation keys, and no leftover hardcoded text in the wrong language. When a user switches language, the entire visible interface follows, and Arabic is laid out right-to-left correctly. The same completeness and correctness apply to the React admin dashboard.

**Why this priority**: Localization quality is a trust and accessibility issue across the whole product, but most flows are already partially translated, so this is a sweep-and-verify quality pass rather than a blocking defect. It is broad but lower-risk than the functional fixes above.

**Independent Test**: Walk every primary mobile flow (registration, trip creation, search, booking, payment, settings, notifications) and the admin dashboard's primary screens once in Arabic and once in English; record any screen that shows an untranslated string, a raw key, mixed-language text, or broken right-to-left layout. The pass succeeds when no such defects remain on either surface.

**Acceptance Scenarios**:

1. **Given** the app is set to Arabic, **When** the user navigates every primary screen, **Then** all user-facing text is shown in Arabic with no raw keys, no English fallbacks, and correct right-to-left layout.
2. **Given** the app is set to English, **When** the user navigates every primary screen, **Then** all user-facing text is shown in English with no raw keys and no Arabic fallbacks.
3. **Given** the user changes the app language, **When** the change is applied, **Then** all currently visible text and subsequent screens reflect the new language without requiring reinstall.
4. **Given** a server- or notification-originated message (e.g., push notification, status message), **When** it is shown to the user, **Then** it appears in the user's selected language.
5. **Given** the admin dashboard set to Arabic or English, **When** an operator navigates its primary screens, **Then** all dashboard text is shown in the selected language with no raw keys, no wrong-language fallbacks, and correct directional layout.

### Edge Cases

- **Approval race**: An admin approves a driver at the exact moment the driver opens the trip-creation flow — the flow must resolve to "allowed" without requiring a manual retry or restart.
- **Approval revoked**: A driver who was approved is later suspended/revoked while the app is open — trip creation must become blocked again with a clear message (the same freshness mechanism that unblocks must also re-block).
- **Suggestion debounce/quota**: Very fast typing or rate limits on the place-suggestion source must not cause flicker, crashes, or stale results overwriting newer ones.
- **Ambiguous place names**: Two places share a name; the suggestion list must disambiguate (e.g., show region/area) so the correct location is captured.
- **Vehicle type changed after seats configured**: At trip creation no bookings exist, but if the driver edits a draft and changes vehicle type, the previously auto-generated layout must be cleanly replaced (and any incompatible prior selection discarded with notice).
- **Notification fan-out**: Many drivers register or many payments arrive in a short window — admins should not be flooded beyond a reasonable, possibly batched, cadence.
- **Admin without a registered device / notifications disabled at OS level**: The dashboard must still surface the events so nothing is missed when push cannot be delivered.
- **New strings added later**: A string added after this pass must not silently fall back to an untranslated value — missing translations should be detectable.

## Requirements *(mandatory)*

### Functional Requirements

**Approved-driver trip creation (Story 1)**

- **FR-001**: The driver app MUST reflect a change in the driver's approval status without requiring the user to fully close and relaunch the app, by re-checking the latest approval status when the driver opens the trip-creation flow and when the app returns to the foreground.
- **FR-002**: An approved driver MUST be able to open the trip-creation flow and publish a trip; the app MUST NOT block an approved driver from creating a trip due to a stale, locally-cached approval status.
- **FR-003**: A driver whose account is not yet approved MUST be shown a clear, localized message explaining that trip creation is unavailable until approval, rather than a silent or generic failure.
- **FR-004**: If approval is revoked or suspended while the app is open, the app MUST re-block trip creation using the same freshness mechanism and explain the new state.

**Location suggestions (Story 2)**

- **FR-005**: The departure ("From") and arrival ("To") location inputs MUST present real-time, ranked place suggestions as the user types, updating with each keystroke after a minimum trigger length.
- **FR-006**: Selecting a suggestion MUST populate the field with the chosen place label and capture its precise location for use in trip creation, search, matching, and tracking.
- **FR-007**: Suggestions MUST be returned in the user's selected language (Arabic or English) and biased to the platform's service region.
- **FR-008**: The location input MUST handle no-results and lookup-failure/offline states gracefully, showing a clear state and still allowing the user to proceed without crashing the flow.

**Automatic seat layout (Story 3)**

- **FR-009**: Selecting a vehicle type during trip creation MUST automatically generate and display the seat layout (seat count and arrangement) defined for that vehicle type, with no manual seat-by-seat configuration required.
- **FR-010**: Changing the vehicle type MUST replace the displayed seat layout with the one matching the newly selected type.
- **FR-011**: The bookable seats offered to passengers MUST match exactly the auto-generated layout for the trip's vehicle type.
- **FR-012**: Each supported vehicle type MUST map to a defined seat layout; a type lacking a defined layout MUST fall back to a sensible default and be flagged rather than producing an empty seat map.

**Admin mobile alerts (Story 4)**

- **FR-013**: When a new driver completes registration, the system MUST send a browser (web) push notification to admin/operator dashboard users subscribed to driver-registration alerts, within a short, bounded interval, identifying the driver and the pending-approval action.
- **FR-014**: When a successful in-app platform/communication-fee payment is recorded, the system MUST send a browser (web) push notification to admin/operator dashboard users subscribed to payment alerts, including the amount and relevant context (payer/booking reference). Penalty collections, wallet top-ups, and refunds do not trigger admin alerts.
- **FR-015**: Tapping an alert notification MUST open the corresponding driver-review or payment record in the dashboard.
- **FR-016**: Alert delivery MUST be limited to admin/operator recipients subscribed for that event type; end-users MUST NOT receive these operational alerts.
- **FR-017**: Admins MUST be able to enable or disable each alert type for themselves, and disabled alert types MUST NOT be delivered to them.
- **FR-018**: When web push cannot be delivered to an admin (browser not subscribed or notification permission denied), the dashboard MUST still surface the underlying events so they are not missed.

**Localization correctness (Story 5)**

- **FR-019**: All user-facing text in the mobile app **and the admin dashboard** MUST be available and correct in both Arabic and English, with no missing entries, no raw translation keys, and no hardcoded strings that ignore the selected language.
- **FR-020**: Changing the language MUST update all currently visible and subsequently shown text to the selected language without reinstalling the app or reloading from scratch.
- **FR-021**: Arabic MUST render with correct right-to-left layout across all primary mobile screens and all primary dashboard screens.
- **FR-022**: Messages that originate from the server or from notifications MUST be presented in the user's selected language.
- **FR-023**: Missing or untranslated strings MUST be detectable on both the mobile app and the dashboard (so future additions cannot silently ship untranslated).

### Key Entities *(include if feature involves data)*

- **Driver Approval Status**: The current state of a driver account (e.g., pending, approved, suspended/revoked) that gates trip creation; must be observable by the app in near-real-time.
- **Place Suggestion**: A candidate location returned for a partial query — includes a human-readable label (region/area for disambiguation) and a precise location reference; language- and region-aware.
- **Vehicle Type → Seat Layout Template**: A mapping from each supported vehicle type to its defined seat count and arrangement, used to auto-generate the bookable seat plan for a trip.
- **Admin Alert**: An operational notification delivered to admin/operator recipients via dashboard web push, typed by event (driver-registration, in-app fee payment), carrying the context needed to act and a deep link to the related dashboard record; subject to per-admin, per-type subscription preferences.
- **Localized String Resource**: The set of user-facing text entries keyed for Arabic and English — spanning both the mobile app and the admin dashboard — against which completeness and correctness are verified.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After an admin approves a driver whose app is open, the driver can create a trip without restarting the app in 100% of cases, with the approved state reflected the next time they open the create-trip flow or return the app to the foreground.
- **SC-002**: Zero brand-new approved drivers are blocked from trip creation by a stale approval status (measured by the elimination of "approved but can't create trip" support reports).
- **SC-003**: Origin and destination suggestion lists appear within ~1 second of typing, and the intended place is present in the top results for at least 90% of common searches in the service region.
- **SC-004**: 100% of supported vehicle types produce the correct seat layout automatically on selection, with zero manual seat-by-seat configuration required and zero mismatches between offered seats and the vehicle type.
- **SC-005**: Subscribed admins receive driver-registration and in-app-fee-payment alerts via dashboard web push within ~1 minute of the event, with at least 99% of deliverable alerts arriving and each alert deep-linking to the correct dashboard record.
- **SC-006**: A full walkthrough of every primary flow in both Arabic and English — across the mobile app and the admin dashboard — yields zero untranslated strings, zero raw keys, zero mixed-language screens, and zero directional (RTL/LTR) layout defects.

## Assumptions

- **Admin alert recipients & channel** (resolved — see Clarifications): Admin alerts are delivered as browser (web) push from the dashboard to subscribed admin/operator users, on whichever device runs their dashboard browser (desktop or mobile). End-users do not receive these operational alerts, and no separate admin mobile app is built.
- **Payment alert trigger** (resolved — see Clarifications): Only successful in-app platform/communication-fee payments fire an admin alert (consistent with the retained in-app payment model from feature 008). Penalty collections, wallet top-ups, and refunds do not.
- **Scope of trip creation fix**: The "must exit the app" behavior is treated as a status-freshness defect — the fix makes approval status refresh in-session; it does not change the approval policy itself (admin still approves drivers as today).
- **Location suggestion source**: A place-suggestion capability is assumed available to the app; this spec defines the experience and constraints (language, region bias, graceful degradation) but not the specific provider.
- **Vehicle types are a known, finite set**: The supported vehicle types and their seat arrangements are defined by the product (e.g., sedan/van/bus seat counts) and can be mapped to layout templates.
- **Localization framework exists**: The mobile app already supports Arabic/English with right-to-left handling (per features 007/008) and the admin dashboard already uses a translation framework; this work is a completeness-and-correctness sweep across both, plus a guard against future untranslated strings — not a new i18n system.
- **Primary flows in scope for the localization sweep**: mobile — registration/auth, trip creation, trip search, booking, payment, settings, and notifications; dashboard — its primary admin/operator screens.
