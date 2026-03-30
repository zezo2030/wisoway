# Feature Specification: Settings Screen

**Feature Branch**: `005-settings-screen`  
**Created**: 2026-03-30  
**Status**: Draft  
**Input**: User description: "Build a comprehensive settings screen for the RideShare Flutter app with dark mode toggle, language switcher, notification settings, account security, privacy controls, payment shortcuts, support section, about screen, and account deletion"

## Clarifications

### Session 2026-03-30

- Q: What should happen when a user taps "Delete Account" if the backend doesn't support it? → A: Show a "Contact Support" dialog with a link to WhatsApp/email support (satisfies Apple App Store account deletion requirements).
- Q: What should the "Contact Us" option open? → A: Open WhatsApp chat with a predefined support number (common support channel in the target region).
- Q: How should Terms of Service and Privacy Policy links be opened? → A: Open in an in-app browser (WebView) to keep users inside the app.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Theme & Appearance Control (Priority: P1)

A user wants to switch between light mode, dark mode, or system-default appearance. They navigate to Setting screen, find the "Appearance" section, and toggle the dark mode switch or select a theme mode from a bottom sheet. The change applies immediately across the entire app and persists after closing and reopening the app.

**Why this priority**: Visual comfort is a fundamental user expectation. The app already has full light/dark theme support (AppTheme.lightTheme / AppTheme.darkTheme) but currently hardcodes `ThemeMode.system` with no user control. This is the highest-impact, lowest-effort setting to implement.

**Independent Test**: Can be fully tested by toggling the dark mode switch and verifying the entire app UI changes instantly, then closing/reopening the app to confirm persistence.

**Acceptance Scenarios**:

1. **Given** a user is on the Settings screen, **When** they toggle the dark mode switch ON, **Then** the entire app immediately switches to dark theme.
2. **Given** a user has selected dark mode, **When** they close and reopen the app, **Then** the app loads in dark mode.
3. **Given** a user taps the "Theme Mode" selector, **When** a bottom sheet appears with three options (System, Light, Dark), **Then** the user can select one and the change applies immediately.
4. **Given** a user selects "System" theme mode, **When** the device OS theme changes, **Then** the app follows the OS theme automatically.

---

### User Story 2 - Language Switching (Priority: P1)

A user wants to switch the app language between Arabic and English. They navigate to Settings, tap the language selector, and choose their preferred language from a bottom sheet. The app immediately switches all text, layout direction (RTL ↔ LTR), and persists the choice.

**Why this priority**: The app already supports Arabic and English with a LocalizationService but has no user-facing control. Bilingual support is critical for the target user base.

**Independent Test**: Can be fully tested by selecting English in the language selector and verifying all visible text changes to English and layout direction flips to LTR, then reverting to Arabic.

**Acceptance Scenarios**:

1. **Given** a user is on the Settings screen with Arabic selected, **When** they tap "Language" and select English, **Then** all app text switches to English and layout direction changes to LTR.
2. **Given** a user has selected English, **When** they close and reopen the app, **Then** the app loads in English.
3. **Given** a user changes language, **When** they navigate back to previous screens, **Then** those screens also reflect the new language.

---

### User Story 3 - Settings Screen Navigation (Priority: P1)

A user wants to access the Settings screen from the Profile tab or Side Drawer. They tap the "Settings" menu item and are navigated to a well-organized settings screen with clearly labeled sections.

**Why this priority**: This is the entry point for all settings. Currently, both the Profile tab and Side Drawer have "Settings" buttons that do nothing (empty onTap handlers). Users see the button but cannot access settings — a broken experience that must be fixed.

**Independent Test**: Can be fully tested by tapping the Settings button in the Profile tab or Side Drawer and verifying navigation to the Settings screen with all sections visible.

**Acceptance Scenarios**:

1. **Given** a user is on the Profile tab, **When** they tap "الإعدادات" (Settings), **Then** they navigate to the Settings screen.
2. **Given** a user opens the Side Drawer, **When** they tap "الإعدادات" (Settings), **Then** the drawer closes and they navigate to the Settings screen.
3. **Given** a user is on the Settings screen, **When** they tap the back button, **Then** they return to the previous screen.
4. **Given** a user is on the Settings screen, **When** they view the screen, **Then** they see organized sections: Appearance, Notifications, Account & Security, Payment & Wallet, Support & Help, and About.

---

### User Story 4 - Notification Preferences (Priority: P2)

A user wants to control which notifications they receive and how (sound, vibration). They navigate to the Notifications section in Settings and toggle individual notification categories on/off. They can also access a detailed notification settings sub-screen for granular control.

**Why this priority**: Notification fatigue is a common complaint. Giving users control improves engagement and reduces uninstalls. The app already has a notification system (Firebase Messaging + WebSocket) that this feature would control.

**Independent Test**: Can be fully tested by toggling the "Push Notifications" switch off and verifying no new notifications appear, then toggling sound/vibration individually.

**Acceptance Scenarios**:

1. **Given** a user is on the Settings screen, **When** they toggle "Push Notifications" OFF, **Then** they stop receiving push notifications.
2. **Given** a user is in notification settings, **When** they toggle "Sounds" OFF, **Then** notifications arrive silently.
3. **Given** a user is in notification settings, **When** they toggle "Vibration" OFF, **Then** notifications arrive without vibration.
4. **Given** a user navigates to the detailed Notification Settings sub-screen, **When** they view it, **Then** they see categories: Trip notifications, Payment notifications, Message notifications, and System notifications.
5. **Given** a user toggles off "Trip notifications", **When** a trip status changes, **Then** they do NOT receive a notification for it.

---

### User Story 5 - Account & Security Management (Priority: P2)

A user wants to view their account information, verification status, and manage security-related settings. They navigate to the "Account & Security" section and can see their account details, link/update their phone number, and view verification statuses.

**Why this priority**: Users need to see and manage their account state. The app has verification statuses (email, phone, driver approval) that users should be able to monitor. Phone linking is already supported by the backend.

**Independent Test**: Can be fully tested by navigating to the Account Security sub-screen and verifying that account info (email, phone, role) is displayed correctly and verification badges show accurate status.

**Acceptance Scenarios**:

1. **Given** a user navigates to Account Security, **When** the screen loads, **Then** they see their email (read-only), phone number, and role displayed.
2. **Given** a user's phone is verified, **When** they view the verification section, **Then** they see a green checkmark next to "Phone Number".
3. **Given** a user's phone is NOT verified, **When** they tap "Link Phone Number", **Then** they are navigated to the phone verification flow.
4. **Given** a user taps "Change Password", **When** the feature is not yet available on the backend, **Then** they see a "Coming Soon" message.
5. **Given** a driver user views Account Security, **When** they look at the verification section, **Then** they see their driver approval status (Approved / Pending Review).

---

### User Story 6 - Privacy Controls (Priority: P2)

A user wants to control their privacy preferences — whether to share live location, show online status, and display their rating to other users. They navigate to the Privacy & Security sub-screen and toggle these options.

**Why this priority**: Privacy controls build user trust and are increasingly expected in ride-sharing apps. These are local preferences that control what the app shares or displays.

**Independent Test**: Can be fully tested by toggling "Location Sharing" off and verifying the app stops broadcasting the user's live location.

**Acceptance Scenarios**:

1. **Given** a user is on the Privacy Settings screen, **When** they toggle "Location Sharing" OFF, **Then** the app stops sharing their live location with other users.
2. **Given** a user toggles "Show Online Status" OFF, **When** other users view their profile, **Then** they do not see the user's online/offline status.
3. **Given** a user toggles "Show Rating" OFF, **When** other users view trip details, **Then** they do not see the user's rating score.
4. **Given** a user changes privacy settings, **When** they close and reopen the app, **Then** their privacy preferences are preserved.

---

### User Story 7 - Payment & Wallet Shortcuts (Priority: P3)

A user wants quick access to their wallet and payment history from the Settings screen. They tap the relevant option and are navigated to the existing wallet or payment history screen.

**Why this priority**: These screens already exist; this story only adds navigation shortcuts. Low effort, moderate convenience.

**Independent Test**: Can be fully tested by tapping "Wallet" and verifying navigation to the correct wallet screen (driver or passenger wallet based on user role).

**Acceptance Scenarios**:

1. **Given** a driver user taps "Wallet" in Settings, **When** the navigation completes, **Then** they see the Driver Wallet screen.
2. **Given** a passenger user taps "Wallet" in Settings, **When** the navigation completes, **Then** they see the Passenger Wallet screen.
3. **Given** a user taps "Payment History", **When** the navigation completes, **Then** they see the Payment History screen.

---

### User Story 8 - About & App Info (Priority: P3)

A user wants to see information about the app — version number, rate/share the app, view licenses, and access legal documents. They navigate to the "About" section or sub-screen.

**Why this priority**: Standard feature in all apps, provides brand credibility and legal compliance. Low effort with basic information display.

**Independent Test**: Can be fully tested by navigating to the About screen and verifying the app version number is displayed and "Rate App" / "Share App" buttons open the correct system dialogs.

**Acceptance Scenarios**:

1. **Given** a user navigates to the About screen, **When** the screen loads, **Then** they see the app name ("RideShare"), version number, and description.
2. **Given** a user taps "Rate App", **When** the action completes, **Then** the device's app store page opens.
3. **Given** a user taps "Share App", **When** the share sheet appears, **Then** it contains a link or message to share the app.
4. **Given** a user taps "Licenses", **When** the screen loads, **Then** they see the open-source licenses used in the app.

---

### User Story 9 - Account Deletion (Priority: P3)

A user wants to permanently delete their account. They find the "Delete Account" option at the bottom of Settings, confirm through a double-confirmation dialog, and their account is removed.

**Why this priority**: Required for app store compliance (Apple App Store requires account deletion). High sensitivity requires careful UX but current backend may not support it yet.

**Independent Test**: Can be fully tested by tapping "Delete Account", confirming twice in the dialog, and verifying the user is signed out and their session is cleared.

**Acceptance Scenarios**:

1. **Given** a user taps "Delete Account", **When** the confirmation dialog appears, **Then** it clearly warns that this action is irreversible.
2. **Given** a user confirms deletion in the first dialog, **When** a second confirmation is requested, **Then** the user must type "DELETE" or confirm again to proceed.
3. **Given** a user confirms account deletion, **When** the deletion completes, **Then** the user is signed out and returned to the sign-in screen.
5. **Given** the backend does not yet support account deletion, **When** the user taps "Delete Account", **Then** a "Contact Support" dialog appears with a link to WhatsApp or email to request manual deletion.
4. **Given** a user cancels at any confirmation step, **When** the dialog closes, **Then** no changes are made to their account.

---

### Edge Cases

- What happens when the user changes language while on a sub-screen inside Settings? (The sub-screen should update its text and layout direction immediately)
- What happens when the user toggles dark mode while scrolling? (Theme change should apply smoothly without losing scroll position)
- What happens if SharedPreferences fails to save a setting? (The UI should show a brief error toast and revert the toggle to its previous state)
- What happens when a driver user views Settings vs a passenger user? (Payment section should navigate to the appropriate wallet screen based on role; driver-specific verification status should only appear for drivers)
- What happens if the user has no internet when toggling notification preferences? (Local preferences should still save; server-side topic unsubscription should retry when connectivity resumes)
- What happens when the user taps "Change Password" or features not yet supported by the backend? (A "Coming Soon" message appears as a SnackBar without navigating to a broken screen)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Settings screen accessible from both the Profile tab and the Side Drawer navigation menus.
- **FR-002**: System MUST allow users to switch between three theme modes: System (follows device setting), Light, and Dark.
- **FR-003**: System MUST apply theme changes immediately across all screens without requiring an app restart.
- **FR-004**: System MUST persist the user's theme preference locally so it survives app restarts.
- **FR-005**: System MUST allow users to switch the app language between Arabic and English.
- **FR-006**: System MUST apply language changes immediately, including text direction (RTL for Arabic, LTR for English).
- **FR-007**: System MUST persist the user's language preference locally so it survives app restarts.
- **FR-008**: System MUST allow users to toggle push notifications on/off.
- **FR-009**: System MUST allow users to independently toggle notification sound and vibration.
- **FR-010**: System MUST provide a detailed notification settings sub-screen with per-category toggles (trips, payments, messages, system).
- **FR-011**: System MUST display the user's account information (email as read-only, phone number, user role) in an Account Security sub-screen.
- **FR-012**: System MUST display verification statuses (email verified, phone verified, driver approval status) with visual indicators.
- **FR-013**: System MUST allow users to initiate phone number linking/verification from the Account Security screen.
- **FR-014**: System MUST show a "Coming Soon" indicator for features not yet supported by the backend (e.g., password change).
- **FR-015**: System MUST provide privacy toggles for: live location sharing, online status visibility, and rating visibility.
- **FR-016**: System MUST persist all privacy preferences locally.
- **FR-017**: System MUST provide navigation shortcuts to the Wallet screen (driver wallet or passenger wallet based on user role) and Payment History screen.
- **FR-018**: System MUST display an About screen showing the app name, version number, and description.
- **FR-019**: System MUST allow users to rate the app (opens app store), share the app (opens share sheet), and view open-source licenses.
- **FR-020**: System MUST provide an account deletion option with double-confirmation safeguard. If the backend deletion endpoint is unavailable, the system MUST display a "Contact Support" dialog with a WhatsApp or email link for manual deletion requests.
- **FR-021**: System MUST organize settings into clearly labeled sections with visual separation (Appearance, Notifications, Account & Security, Payment & Wallet, Support & Help, About).
- **FR-022**: System MUST support the existing bilingual localization (Arabic and English) for all new settings labels and text.
- **FR-023**: System MUST adapt the Settings UI based on user role (show driver-specific options like driver approval status only for drivers; navigate to the correct wallet screen based on role).
- **FR-024**: System MUST open a WhatsApp chat with a predefined support phone number when the user taps "Contact Us" in the Support & Help section.
- **FR-025**: System MUST open Terms of Service and Privacy Policy URLs in an in-app browser (WebView) rather than an external browser, keeping users within the app experience.

### Key Entities

- **User Preference**: Represents a locally-stored user setting (theme mode, language, notification preferences, privacy toggles). Stored on the device and loaded at app startup.
- **Theme Mode**: An enumeration of display modes (System, Light, Dark) that controls which visual theme the app renders.
- **Notification Category**: A classification of notification types (Trips, Payments, Messages, System) that users can individually enable or disable.
- **Privacy Setting**: A boolean preference controlling what information about the user is shared or visible to others (location, online status, rating).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can switch between light and dark mode in under 2 seconds with instant visual feedback across the entire app.
- **SC-002**: Users can switch the app language with all on-screen text and layout direction updating within 1 second.
- **SC-003**: 100% of user preference changes (theme, language, notifications, privacy) persist correctly across app restarts.
- **SC-004**: The Settings screen is reachable from all existing navigation entry points (Profile tab "Settings" button, Side Drawer "Settings" item, Profile tab "Help" button, Profile tab "About" button) — eliminating 4 currently non-functional buttons.
- **SC-005**: Users can locate and use any setting within 3 taps from the home screen (Home → Profile tab → Settings → desired setting).
- **SC-006**: The Settings screen renders correctly and is fully usable in both Arabic (RTL) and English (LTR) layouts.
- **SC-007**: The Settings UI is visually consistent with the existing app design system (same card styles, icon styles, typography, and color scheme as the Edit Profile screen).
- **SC-008**: Role-specific features display correctly — drivers see driver approval status and driver wallet; passengers see passenger wallet.
- **SC-009**: All "Coming Soon" features are clearly labeled so users understand the functionality is planned but not yet available, reducing potential confusion or support requests.

## Assumptions

- The app's existing `SharedPreferences` infrastructure is sufficient for persisting all user preferences.
- The existing `LocalizationService` and `AppTheme` (light/dark) system provides a solid foundation — no new backend endpoints are needed for theme or language features.
- Notification category toggles control local filtering/Firebase topic subscription only; the backend continues to send all notification types.
- Privacy settings (location sharing, online status, rating visibility) are enforced locally within the app. Backend enforcement of privacy preferences is out of scope for this feature.
- The "Change Password" feature will show a "Coming Soon" message because the backend's `resetPassword` endpoint is not yet implemented.
- Account deletion may require a backend endpoint that does not currently exist. If unavailable, the deletion option will show a "Contact Support" dialog with a WhatsApp or email link for manual deletion requests (this satisfies Apple App Store account deletion requirements).
- The `package_info_plus`, `share_plus`, and `url_launcher` packages will need to be added as dependencies for the About screen features.

## Scope Boundaries

### In Scope
- Settings screen UI with all sections
- Theme mode switching and persistence
- Language switching and persistence
- Notification preference toggles (local + Firebase topics)
- Account information display and verification status
- Phone number linking (navigation to existing flow)
- Privacy preference toggles (local persistence)
- Navigation shortcuts to existing Wallet and Payment History screens
- About screen with app info, rate, share, and licenses
- Account deletion UI with confirmation flow
- Bilingual localization for all new strings
- Integration with existing Profile tab and Side Drawer navigation

### Out of Scope
- Backend endpoints for password change or account deletion (show "Coming Soon")
- Server-side enforcement of privacy preferences
- New payment methods or wallet features
- Push notification infrastructure changes (only topic subscription control)
- FAQ content or help center implementation (placeholder navigation; "Contact Us" opens WhatsApp and is functional)
- Terms of Service or Privacy Policy content (links to external URLs displayed in an in-app WebView)
- Social media page links (placeholder in About screen)
