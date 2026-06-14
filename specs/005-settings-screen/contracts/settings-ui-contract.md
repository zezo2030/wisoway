# UI Contract: Settings Screen

**Feature**: 005-settings-screen
**Date**: 2026-03-30
**Type**: Mobile App UI Contracts

> This project is a Flutter mobile app. The "contracts" are UI screen specifications — what each screen displays, accepts as input, and produces as output. These serve as the implementation guide for each screen/widget.

---

## Screen: SettingsScreen (`/settings`)

**Route**: `RouteNames.settings` → `/settings`
**Navigation Entry Points**: Profile tab "الإعدادات" button, Side Drawer "الإعدادات" item, Profile tab "المساعدة والدعم" button (→ scrolls to Support section), Profile tab "حول التطبيق" button (→ navigates to AboutScreen directly)

### Layout

```
┌─────────────────────────────────┐
│  ← الإعدادات                    │  AppBar (title: Settings)
├─────────────────────────────────┤
│                                 │
│  ┌─ المظهر ──────────────────┐  │  Section: Appearance
│  │ 🎨 الوضع الداكن    [🔘]   │  │  Switch tile (dark mode toggle)
│  │ 🖌️ سمة التطبيق     [>]   │  │  Tile → BottomSheet (System/Light/Dark)
│  └───────────────────────────┘  │
│                                 │
│  ┌─ اللغة ───────────────────┐  │  Section: Language
│  │ 🌐 اللغة    العربية [>]   │  │  Tile → BottomSheet (Arabic/English)
│  └───────────────────────────┘  │
│                                 │
│  ┌─ الإشعارات ───────────────┐  │  Section: Notifications
│  │ 🔔 الإشعارات       [🔘]   │  │  Master push toggle
│  │ 🔊 الأصوات         [🔘]   │  │  Sound toggle
│  │ 📳 الاهتزاز        [🔘]   │  │  Vibration toggle
│  │ ⚙️ إعدادات مفصلة   [>]   │  │  Tile → NotificationSettingsScreen
│  └───────────────────────────┘  │
│                                 │
│  ┌─ الحساب والأمان ──────────┐  │  Section: Account & Security
│  │ 🛡️ معلومات الحساب  [>]   │  │  Tile → AccountSecurityScreen
│  │ 🔑 تغيير كلمة المرور  ⏳  │  │  Tile (Coming Soon badge)
│  └───────────────────────────┘  │
│                                 │
│  ┌─ الخصوصية ────────────────┐  │  Section: Privacy
│  │ 📍 مشاركة الموقع   [🔘]   │  │  Location sharing toggle
│  │ 🟢 الظهور متصل     [🔘]   │  │  Online status toggle
│  │ ⭐ إظهار التقييم    [🔘]   │  │  Rating visibility toggle
│  └───────────────────────────┘  │
│                                 │
│  ┌─ الدفع والمحفظة ──────────┐  │  Section: Payment & Wallet
│  │ 💰 المحفظة          [>]   │  │  Tile → DriverWallet or PassengerWallet
│  │ 📋 سجل المدفوعات  [>]   │  │  Tile → PaymentHistoryScreen
│  └───────────────────────────┘  │
│                                 │
│  ┌─ الدعم والمساعدة ─────────┐  │  Section: Support & Help
│  │ 💬 تواصل معنا      [>]   │  │  Tile → WhatsApp deep link
│  │ 📜 شروط الاستخدام  [>]   │  │  Tile → InAppBrowserScreen
│  │ 🔒 سياسة الخصوصية  [>]   │  │  Tile → InAppBrowserScreen
│  └───────────────────────────┘  │
│                                 │
│  ┌─ حول التطبيق ─────────────┐  │  Section: About
│  │ ℹ️ حول التطبيق     [>]   │  │  Tile → AboutScreen
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 🗑️  حذف الحساب           │  │  Red danger button, bottom of list
│  └───────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

### Input (Dependencies)

| Dependency | Source | Purpose |
|------------|--------|---------|
| `ThemeService` | Provider (ChangeNotifier) | Read/write theme mode |
| `LocalizationService` | Provider (ChangeNotifier) | Read/write language |
| `SettingsService` | Direct instantiation | Read/write notification + privacy prefs |
| `AuthProvider` | Provider (ChangeNotifier) | Read user role (wallet routing) |

### Output (Actions)

| Action | Effect |
|--------|--------|
| Toggle dark mode | `ThemeService.setThemeMode()` → immediate UI update |
| Select theme mode | Bottom sheet → `ThemeService.setThemeMode()` |
| Select language | Bottom sheet → `LocalizationService.setLanguage()` |
| Toggle notification | `SettingsService.setNotificationPref()` + Firebase topic |
| Toggle privacy | `SettingsService.setPrivacyPref()` |
| Navigate to sub-screen | `Navigator.push()` to respective screen |
| Navigate to wallet | `Navigator.pushNamed()` to driver/passenger wallet based on role |
| Contact Us | `url_launcher` → WhatsApp deep link |
| Delete Account | Double confirmation dialog → Contact Support dialog |

---

## Screen: NotificationSettingsScreen

**Route**: Pushed from SettingsScreen (no named route needed)

### Layout

```
┌─────────────────────────────────┐
│  ← إعدادات الإشعارات            │  AppBar
├─────────────────────────────────┤
│                                 │
│  ┌─ فئات الإشعارات ──────────┐  │
│  │ 🚗 إشعارات الرحلات [🔘]   │  │  Trip notifications
│  │ 💳 إشعارات الدفع   [🔘]   │  │  Payment notifications
│  │ 💬 إشعارات الرسائل [🔘]   │  │  Message notifications
│  │ 📱 إشعارات النظام  [🔘]   │  │  System notifications
│  └───────────────────────────┘  │
│                                 │
│  ℹ️ يمكنك تخصيص الإشعارات     │  Info text
│  التي تريد استقبالها            │
│                                 │
└─────────────────────────────────┘
```

### Input
- `SettingsService`: Read current category toggle states

### Output
- `SettingsService.setNotificationCategoryPref(category, enabled)`: Persist toggle
- `FirebaseMessaging.instance.subscribeToTopic()` / `unsubscribeFromTopic()`: FCM topic management

---

## Screen: AccountSecurityScreen

**Route**: Pushed from SettingsScreen

### Layout

```
┌─────────────────────────────────┐
│  ← الحساب والأمان               │  AppBar
├─────────────────────────────────┤
│                                 │
│  ┌─ معلومات الحساب ──────────┐  │
│  │ 📧 البريد الإلكتروني      │  │  Read-only (from userModel.email)
│  │    user@example.com        │  │
│  │ 📱 رقم الهاتف             │  │  Read-only + Link action
│  │    +20xxxxxxxxxx   [ربط]   │  │  "Link" navigates to PhoneAuthScreen
│  │ 👤 نوع الحساب             │  │  Read-only badge
│  │    [راكب] or [سائق]       │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌─ حالة التوثيق ────────────┐  │
│  │ ✅ البريد الإلكتروني      │  │  Green check / red X
│  │ ✅ رقم الهاتف             │  │  Green check / red X
│  │ ✅ اعتماد السائق          │  │  Only for drivers
│  └───────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

### Input
- `AuthProvider.userModel`: All account data (read-only)

### Output
- Navigation to `RouteNames.phoneAuth` with `isLinkPhone: true` (existing flow)

---

## Screen: PrivacySettingsScreen

**Route**: Pushed from SettingsScreen (optional — may be inlined in main Settings)

### Layout

```
┌─────────────────────────────────┐
│  ← الخصوصية                     │  AppBar
├─────────────────────────────────┤
│                                 │
│  ┌─ إعدادات الخصوصية ────────┐  │
│  │ 📍 مشاركة الموقع   [🔘]   │  │  Location sharing toggle
│  │     مشاركة موقعك المباشر  │  │  Subtitle text
│  │ 🟢 الظهور متصل     [🔘]   │  │  Online status toggle
│  │     إظهار حالة الاتصال    │  │  Subtitle text
│  │ ⭐ إظهار التقييم    [🔘]   │  │  Show rating toggle
│  │     إظهار تقييمك للآخرين  │  │  Subtitle text
│  └───────────────────────────┘  │
│                                 │
│  ℹ️ هذه الإعدادات تتحكم في    │  Info note
│  ما يمكن للآخرين رؤيته عنك     │
│                                 │
└─────────────────────────────────┘
```

---

## Screen: AboutScreen

**Route**: `RouteNames.about` → `/about` (also directly accessible from Profile tab)

### Layout

```
┌─────────────────────────────────┐
│  ← حول التطبيق                  │  AppBar
├─────────────────────────────────┤
│                                 │
│          🚗                     │  App icon / logo
│       RideShare                 │  App name
│      الإصدار 1.0.0              │  Version from package_info_plus
│                                 │
│  منصة مشاركة الرحلات           │  App description
│                                 │
│  ┌───────────────────────────┐  │
│  │ ⭐ تقييم التطبيق   [>]   │  │  Opens app store
│  │ 📤 مشاركة التطبيق  [>]   │  │  Opens share sheet
│  │ 📋 التراخيص        [>]   │  │  Opens LicensePage
│  └───────────────────────────┘  │
│                                 │
│     صنع بـ ❤️ في مصر           │  Footer text
│                                 │
└─────────────────────────────────┘
```

### Output
- Rate App: `url_launcher.launchUrl()` → app store URL
- Share App: `share_plus.Share.share()` → native share sheet
- Licenses: `Navigator.push()` → Flutter's built-in `LicensePage()`

---

## Screen: InAppBrowserScreen (Reusable)

**Route**: Pushed with title + URL parameters

### Layout

```
┌─────────────────────────────────┐
│  ← {title}                      │  AppBar with dynamic title
├─────────────────────────────────┤
│                                 │
│  [═══════════50%═══════      ]  │  LinearProgressIndicator (while loading)
│                                 │
│  ┌───────────────────────────┐  │
│  │                           │  │
│  │    WebView content        │  │  webview_flutter WebView
│  │                           │  │
│  │                           │  │
│  └───────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

---

## Widget: SettingsSection

**Purpose**: Visual group with header label containing child tiles.

### Props

| Prop | Type | Required |
|------|------|----------|
| `title` | `String` | Yes |
| `children` | `List<Widget>` | Yes |

---

## Widget: SettingsTile

**Purpose**: Tappable row with icon, title, optional subtitle, optional trailing widget.

### Props

| Prop | Type | Required |
|------|------|----------|
| `icon` | `IconData` | Yes |
| `title` | `String` | Yes |
| `subtitle` | `String?` | No |
| `trailing` | `Widget?` | No (defaults to chevron) |
| `onTap` | `VoidCallback?` | No |
| `badge` | `String?` | No (e.g., "Coming Soon") |
| `iconColor` | `Color?` | No |
| `textColor` | `Color?` | No |

---

## Widget: SettingsSwitchTile

**Purpose**: Extends `SettingsTile` with a trailing `Switch`.

### Props

| Prop | Type | Required |
|------|------|----------|
| `icon` | `IconData` | Yes |
| `title` | `String` | Yes |
| `subtitle` | `String?` | No |
| `value` | `bool` | Yes |
| `onChanged` | `ValueChanged<bool>?` | Yes |
| `enabled` | `bool` | No (default true) |
