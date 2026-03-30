# Research: Settings Screen

**Feature**: 005-settings-screen
**Date**: 2026-03-30
**Status**: Complete

## Research Task 1: Theme Mode Management in Flutter with Provider

**Context**: The app currently hardcodes `ThemeMode.system` in `main.dart` (line 111). We need reactive theme switching that persists across restarts.

### Decision: Create a `ThemeService` (ChangeNotifier) following the `LocalizationService` pattern

**Rationale**:
- The app already uses `ChangeNotifier` + `Provider` for `LocalizationService` (language switching). Following the identical pattern for theme switching ensures consistency and leverages the existing architecture.
- `ThemeService` extends `ChangeNotifier`, exposes a `themeMode` getter, and persists via `SharedPreferences` using the existing `AppConstants.keyTheme` key.
- The `MaterialApp` already accepts `theme`, `darkTheme`, and `themeMode` properties. Wrapping with `Consumer<ThemeService>` (alongside existing `Consumer<LocalizationService>`) provides instant reactivity.

**Alternatives Considered**:
1. **BLoC for theme state**: Rejected — would require adding a new Bloc/Cubit just for a single boolean/enum state. The existing Blocs (AuthBloc, TripBloc) handle complex async flows; theme switching is a simple sync operation better suited to ChangeNotifier.
2. **Riverpod migration**: Rejected — the entire app uses Provider. Introducing Riverpod for one feature would create inconsistency and a migration burden.
3. **Modifying `LocalizationService` to also handle theme**: Rejected — violates SRP. Theme and language are independent concerns that should be separate services.

### Implementation Pattern

```dart
class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  ThemeService() { _loadSavedTheme(); }
  
  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.keyTheme);
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == saved, orElse: () => ThemeMode.system);
      notifyListeners();
    }
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyTheme, mode.name);
  }
}
```

---

## Research Task 2: New Dependencies — package_info_plus, share_plus, webview_flutter

**Context**: The About screen requires app version info, share functionality, and in-app browser for ToS/Privacy Policy.

### Decision: Add `package_info_plus`, `share_plus`, and `webview_flutter`

**Rationale**:
- `package_info_plus` (Flutter Favorite): Provides app name, version, build number. Used by the About screen. Zero configuration needed.
- `share_plus` (Flutter Favorite): Native share sheet for "Share App" feature. Standard approach in Flutter.
- `webview_flutter` (by flutter.dev team): For opening ToS/Privacy Policy in-app. The spec explicitly requires in-app browser (not `url_launcher` which opens external browser).
- `url_launcher` (already a dependency): Will still be used for WhatsApp deep-linking ("Contact Us"), app store rating, and other external links.

**Alternatives Considered**:
1. **`flutter_inappwebview`**: More features but heavier. `webview_flutter` is sufficient for displaying static web pages and is maintained by the Flutter team.
2. **Manual version string**: Rejected — `package_info_plus` reads from `pubspec.yaml` automatically, avoiding hardcoded version strings that go stale.

**Version Compatibility**: All packages support Dart SDK ^3.9.2 and Flutter latest stable.

---

## Research Task 3: Notification Preference Architecture — Local vs Firebase Topics

**Context**: The app uses Firebase Messaging. Notification category toggles should control which notifications the user sees.

### Decision: Dual approach — Local SharedPreferences filtering + Firebase topic (un)subscription

**Rationale**:
- **Local preferences**: Store per-category toggles (trips, payments, messages, system) in SharedPreferences. When notifications arrive, the local notification handler can filter/suppress based on these preferences.
- **Firebase topics**: Subscribe/unsubscribe from FCM topics (`trips`, `payments`, `messages`, `system`) to reduce unnecessary server pushes. This is fire-and-forget; if offline, Firebase handles retries automatically.
- **Sound/Vibration toggles**: Controlled via `flutter_local_notifications` channel configuration. These are already in the dependency tree.

**Alternatives Considered**:
1. **Backend-only notification control**: Rejected — requires backend API changes, which are out of scope. Local control is more responsive and works offline.
2. **Local-only filtering (no topic changes)**: Rejected — wasteful to receive notifications the user won't see. Topic unsubscription reduces unnecessary payload delivery.

---

## Research Task 4: Privacy Settings — Local Enforcement Strategy

**Context**: Privacy settings (location sharing, online status, rating visibility) are locally enforced per spec. Backend enforcement is out of scope.

### Decision: SharedPreferences booleans checked at point of use

**Rationale**:
- Store three boolean keys: `privacy_location_sharing`, `privacy_show_online`, `privacy_show_rating`.
- The `LocationService` checks `privacy_location_sharing` before broadcasting location.
- UI components displaying online status or rating check the relevant preference before rendering.
- Default values: all enabled (true) — matching current implicit behavior.

**Alternatives Considered**:
1. **Backend-enforced privacy**: Out of scope per spec. Would require new API endpoints.
2. **Centralized privacy service**: Overkill for 3 boolean checks. A simple `SettingsService.getPrivacySetting(key)` method is sufficient.

---

## Research Task 5: In-App Browser for Terms of Service / Privacy Policy

**Context**: The spec requires ToS and Privacy Policy to open in an in-app WebView, not an external browser.

### Decision: Use `webview_flutter` with a reusable `InAppBrowserScreen` widget

**Rationale**:
- Create a generic `InAppBrowserScreen(title, url)` that can be reused for any web content.
- Includes an AppBar with back button for native feel.
- Loading indicator while page loads.
- Keeps user within the app (spec requirement).

**Implementation Pattern**:
```dart
class InAppBrowserScreen extends StatelessWidget {
  final String title;
  final String url;
  // ... WebViewController setup, loading state, AppBar with title
}
```

---

## Research Task 6: Account Deletion Flow — Backend Not Available

**Context**: Backend may not support account deletion. Spec mandates a "Contact Support" fallback.

### Decision: Implement "Contact Support" dialog with WhatsApp/email link

**Rationale**:
- Check backend availability: If deletion endpoint exists, call it with double-confirmation UX.
- Fallback: Show dialog explaining manual process, with a button that opens WhatsApp chat (`url_launcher` with `https://wa.me/{supportNumber}?text=...`) or email (`mailto:...`).
- This satisfies Apple App Store account deletion requirements (user can initiate deletion, even if manual).
- Future-proof: When backend adds deletion endpoint, swap the fallback dialog for the real API call.

---

## Research Task 7: Settings Screen UI Pattern — Best Practices for Flutter

**Context**: Need a well-organized, visually consistent settings screen matching the existing design system.

### Decision: Section-based layout with reusable tile widgets

**Rationale**:
- Use Material 3 `ListView` with grouped sections (Appearance, Notifications, etc.).
- Each section has a header label + list of setting tiles.
- Tile types: `SettingsTile` (navigation/action), `SettingsSwitchTile` (toggle).
- Visual style matches existing `ProfileMenuItem` but extended with switch support.
- Consistent use of `iconsax_plus` icons, `T` color helper, `GoogleFonts.tajawal`.
- Bottom sheet selectors for theme mode and language (3 options each) — matching the app's existing bottom sheet conventions.

**Alternatives Considered**:
1. **`settings_ui` package**: Rejected — adds external dependency for what is essentially a styled ListView. Custom widgets give full control over visual consistency with the existing design system.
2. **CupertinoSettings style**: Rejected — the app uses Material 3 design system throughout.

---

## Research Task 8: WhatsApp Integration for "Contact Us"

**Context**: "Contact Us" should open a WhatsApp chat with a predefined support number.

### Decision: Use `url_launcher` with WhatsApp deep link

**Rationale**:
- URL format: `https://wa.me/{phoneNumber}?text={encodedMessage}`
- The `url_launcher` package is already a dependency (pubspec.yaml line 55).
- No additional package needed.
- Fallback: If WhatsApp is not installed, `url_launcher` opens the link in a browser which shows WhatsApp Web or app store page.

---

## Summary of All Decisions

| # | Topic | Decision | Key Package/Pattern |
|---|-------|----------|-------------------|
| 1 | Theme Management | ThemeService (ChangeNotifier) | SharedPreferences + Provider |
| 2 | New Dependencies | package_info_plus, share_plus, webview_flutter | pub.dev packages |
| 3 | Notification Prefs | Local filtering + Firebase topic (un)subscribe | SharedPreferences + FCM |
| 4 | Privacy Settings | Local boolean prefs, checked at point of use | SharedPreferences |
| 5 | In-App Browser | Reusable InAppBrowserScreen with webview_flutter | webview_flutter |
| 6 | Account Deletion | Contact Support dialog (WhatsApp/email) | url_launcher |
| 7 | UI Pattern | Section-based ListView with custom tiles | Custom widgets |
| 8 | Contact Us | WhatsApp deep link via url_launcher | url_launcher (existing) |
