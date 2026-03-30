# Quickstart: Settings Screen

**Feature**: 005-settings-screen
**Date**: 2026-03-30

## Prerequisites

- Flutter SDK (Dart ^3.9.2)
- Existing `rideshare` project cloned and running
- Firebase configured (for FCM topic management)

## Setup Steps

### 1. Install New Dependencies

```bash
cd rideshare
flutter pub add package_info_plus share_plus webview_flutter
```

### 2. Key Files to Create (in order)

| # | File | Purpose |
|---|------|---------|
| 1 | `lib/core/services/settings_service.dart` | SharedPreferences CRUD for all setting keys |
| 2 | `lib/core/services/theme_service.dart` | ThemeMode ChangeNotifier (mirrors LocalizationService) |
| 3 | `lib/models/user_preferences.dart` | Typed preferences model (optional — service methods can work directly) |
| 4 | `lib/widgets/settings/settings_section.dart` | Reusable section header + children widget |
| 5 | `lib/widgets/settings/settings_tile.dart` | Reusable tappable settings row |
| 6 | `lib/widgets/settings/settings_switch_tile.dart` | Reusable toggle settings row |
| 7 | `lib/screens/settings/settings_screen.dart` | Main settings screen |
| 8 | `lib/screens/settings/notification_settings_screen.dart` | Detailed notification category toggles |
| 9 | `lib/screens/settings/account_security_screen.dart` | Account info + verification status |
| 10 | `lib/screens/settings/privacy_settings_screen.dart` | Privacy toggle sub-screen |
| 11 | `lib/screens/settings/about_screen.dart` | App info, rate, share, licenses |
| 12 | `lib/screens/settings/in_app_browser_screen.dart` | Reusable WebView wrapper |

### 3. Key Files to Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/core/constants/app_constants.dart` | Add SharedPreferences keys for new settings |
| 2 | `lib/core/constants/route_names.dart` | Add `settings` and `about` route names |
| 3 | `lib/main.dart` | Add `ThemeService` to providers, consume `themeMode` in MaterialApp |
| 4 | `lib/screens/home/tabs/profile_tab.dart` | Wire onTap handlers for Settings, Help, About buttons |
| 5 | `lib/screens/home/home_drawer.dart` | Wire Settings onTap to navigate to Settings screen |
| 6 | `lib/l10n/app_ar.arb` | Add Arabic strings for all settings labels |
| 7 | `lib/l10n/app_en.arb` | Add English strings for all settings labels |

### 4. Quick Validation

```bash
# Verify dependencies installed
flutter pub get

# Run analysis
flutter analyze

# Run tests
flutter test

# Build and run
flutter run
```

### 5. Smoke Test Checklist

- [ ] Tap "الإعدادات" in Profile tab → navigates to Settings screen
- [ ] Tap "الإعدادات" in Side Drawer → navigates to Settings screen
- [ ] Toggle dark mode → app theme changes immediately
- [ ] Select language English → all text switches to English, layout flips to LTR
- [ ] Close and reopen app → theme and language preferences persist
- [ ] Toggle push notifications OFF → sub-toggles become disabled
- [ ] Navigate to Account Security → shows user email, phone, role, verification status
- [ ] Tap "تواصل معنا" → opens WhatsApp with support number
- [ ] Navigate to About → shows app version
- [ ] Tap "حذف الحساب" → shows double-confirmation or Contact Support dialog

## Architecture Diagram

```
┌──────────────────────────────────────────────────────┐
│                    main.dart                         │
│  MultiProvider                                       │
│  ├── ThemeService (NEW)          ──→ themeMode       │
│  ├── LocalizationService (EXISTS) ──→ locale         │
│  ├── AuthProvider (EXISTS)        ──→ user data      │
│  └── ...                                             │
│                                                      │
│  MaterialApp(                                        │
│    themeMode: themeService.themeMode,  // CHANGED     │
│    ...                                               │
│  )                                                   │
└──────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────┐     ┌──────────────────────┐
│  HomeScreen      │     │  HomeDrawer           │
│  └─ ProfileTab   │     │  └─ "الإعدادات" ──────┤───→ SettingsScreen
│     ├─ Settings──┤───→ │                       │
│     ├─ Help ─────┤───→ └──────────────────────┘
│     └─ About ────┤───→ AboutScreen
└──────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│                  SettingsScreen                       │
│  ├── ThemeService (toggle/select)                     │
│  ├── LocalizationService (language select)            │
│  ├── SettingsService (notification + privacy prefs)   │
│  │                                                    │
│  ├──→ NotificationSettingsScreen                      │
│  ├──→ AccountSecurityScreen (reads AuthProvider)      │
│  ├──→ PrivacySettingsScreen                           │
│  ├──→ AboutScreen                                     │
│  ├──→ InAppBrowserScreen (ToS / Privacy Policy)       │
│  ├──→ DriverWallet / PassengerWallet (existing)       │
│  ├──→ PaymentHistory (existing)                       │
│  └──→ WhatsApp (url_launcher)                         │
└──────────────────────────────────────────────────────┘
```
