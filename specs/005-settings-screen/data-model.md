# Data Model: Settings Screen

**Feature**: 005-settings-screen
**Date**: 2026-03-30

## Entity: AppThemeMode (Enum)

Represents the user's theme preference. Maps directly to Flutter's `ThemeMode`.

| Value | Description | Flutter Mapping |
|-------|-------------|-----------------|
| `system` | Follow device OS theme | `ThemeMode.system` |
| `light` | Always light theme | `ThemeMode.light` |
| `dark` | Always dark theme | `ThemeMode.dark` |

**Storage**: SharedPreferences key `theme` (string value: `system`, `light`, or `dark`)
**Default**: `system`

---

## Entity: NotificationCategory (Enum)

Represents categories of notifications that can be individually toggled.

| Value | Description | Firebase Topic | SharedPreferences Key |
|-------|-------------|----------------|-----------------------|
| `trips` | Trip status changes (created, started, completed, cancelled) | `topic_trips` | `notif_trips` |
| `payments` | Payment confirmations, wallet updates | `topic_payments` | `notif_payments` |
| `messages` | Chat messages from drivers/passengers | `topic_messages` | `notif_messages` |
| `system` | App updates, announcements, maintenance | `topic_system` | `notif_system` |

**Storage**: SharedPreferences (boolean per category)
**Default**: All enabled (`true`)

---

## Entity: UserPreferences (Model)

Composite model representing all user-controlled settings. Not stored as a single JSON blob — each field maps to its own SharedPreferences key for granular access.

### Fields

| Field | Type | SharedPreferences Key | Default | Description |
|-------|------|-----------------------|---------|-------------|
| `themeMode` | `AppThemeMode` | `theme` | `system` | Current theme preference |
| `languageCode` | `String` | `language` | `ar` | ISO 639-1 language code |
| `pushNotificationsEnabled` | `bool` | `notif_push_enabled` | `true` | Master push notification toggle |
| `notificationSoundEnabled` | `bool` | `notif_sound` | `true` | Notification sound toggle |
| `notificationVibrationEnabled` | `bool` | `notif_vibration` | `true` | Notification vibration toggle |
| `notifTripsEnabled` | `bool` | `notif_trips` | `true` | Trip notifications category |
| `notifPaymentsEnabled` | `bool` | `notif_payments` | `true` | Payment notifications category |
| `notifMessagesEnabled` | `bool` | `notif_messages` | `true` | Message notifications category |
| `notifSystemEnabled` | `bool` | `notif_system` | `true` | System notifications category |
| `locationSharingEnabled` | `bool` | `privacy_location_sharing` | `true` | Share live location with others |
| `showOnlineStatus` | `bool` | `privacy_show_online` | `true` | Show online/offline status |
| `showRating` | `bool` | `privacy_show_rating` | `true` | Show rating to other users |

### Validation Rules

- `themeMode`: Must be one of `system`, `light`, `dark`. Invalid values fall back to `system`.
- `languageCode`: Must be `ar` or `en`. Invalid values fall back to `ar`.
- All boolean preferences: Default to `true` if key not found in SharedPreferences.

### Relationships

```
UserPreferences
├── uses → AppThemeMode (enum)
├── references → NotificationCategory (enum for category keys)
├── read by → ThemeService (reads themeMode)
├── read by → LocalizationService (reads languageCode, already exists)
├── read by → SettingsService (reads/writes all preferences)
└── read by → AuthProvider.userModel (account info is read-only from backend)
```

---

## Entity: UserModel (Existing — Read-Only for Settings)

Account & Security screen displays data from the existing `UserModel`. No modifications needed.

### Fields Displayed in Settings

| Field | Display | Section |
|-------|---------|---------|
| `email` | Read-only text | Account Security |
| `phoneNumber` | Read-only text + link action | Account Security |
| `role` | Badge (سائق / راكب) | Account Security |
| `isPhoneVerified` | ✅ / ❌ badge | Account Security > Verification |
| `isEmailVerified` | ✅ / ❌ badge | Account Security > Verification |
| `isDriverApproved` | ✅ Approved / ⏳ Pending (drivers only) | Account Security > Verification |
| `rating` | Star display (privacy-controlled) | Privacy Settings |

---

## Entity: SettingsSection (UI Model)

Organizes settings into visual groups on the main settings screen.

| Section | Icon | Items |
|---------|------|-------|
| Appearance | `IconsaxPlusLinear.paintbucket` | Theme Mode, Dark Mode Toggle |
| Language | `IconsaxPlusLinear.language_square` | Language Selector |
| Notifications | `IconsaxPlusLinear.notification` | Push Toggle, Sound Toggle, Vibration Toggle, Detailed Settings → |
| Account & Security | `IconsaxPlusLinear.shield_tick` | Account Info →, Change Password (Coming Soon) |
| Privacy | `IconsaxPlusLinear.lock` | Location Sharing, Online Status, Show Rating |
| Payment & Wallet | `IconsaxPlusLinear.wallet` | Wallet →, Payment History → |
| Support & Help | `IconsaxPlusLinear.message_question` | Contact Us (WhatsApp), Terms of Service →, Privacy Policy → |
| About | `IconsaxPlusLinear.info_circle` | About Screen →, Rate App, Share App, Licenses |
| Danger Zone | `IconsaxPlusLinear.trash` | Delete Account |

---

## State Transitions

### Theme Mode State

```
[system] ←→ [light] ←→ [dark]
     ↑_________________________↑
```
Any → Any transition allowed. Change triggers:
1. `ThemeService.setThemeMode(mode)`
2. `notifyListeners()` → `MaterialApp` rebuilds with new `themeMode`
3. SharedPreferences persisted async

### Notification Category State

```
[enabled] ←→ [disabled]
```
Per-category toggle. When master push toggle is OFF:
- All category toggles are grayed out / disabled in UI
- Individual category states are preserved in SharedPreferences
- When master toggle returns to ON, previous category states restore

### Account Deletion State

```
[Initial] → [First Confirmation Dialog] → [Second Confirmation] → [Processing] → [Signed Out]
                     ↓                            ↓
              [Cancelled → Initial]    [Cancelled → Initial]
                                                   ↓ (if backend unavailable)
                                        [Contact Support Dialog]
```
