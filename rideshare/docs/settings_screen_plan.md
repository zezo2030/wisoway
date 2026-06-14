# 📋 خطة تطوير شاشة الإعدادات (Settings Screen)

> **المشروع:** RideShare — تطبيق مشاركة الرحلات  
> **التاريخ:** 2026-03-30  
> **الحالة:** مخطط للتنفيذ

---

## 📌 نظرة عامة

بناء شاشة إعدادات شاملة تتكامل مع البنية الحالية للتطبيق (Provider + BLoC)، وتشمل جميع الميزات المناسبة مثل:
الوضع الداكن، اللغة، الإشعارات، إدارة الحساب، الأمان، والمزيد.

### الملفات والبنية الموجودة المرتبطة:

| العنصر | الملف |
|--------|-------|
| Theme System | [app_theme.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/theme/app_theme.dart), [colors.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/theme/colors.dart) |
| Localization | [localization_service.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/services/localization_service.dart) |
| Auth Provider | [auth_provider.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/providers/auth_provider.dart) |
| Notification Provider | [notification_provider.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/providers/notification_provider.dart) |
| User Model | [user_model.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/models/user_model.dart) |
| Route Names | [route_names.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/constants/route_names.dart) |
| App Constants | [app_constants.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/constants/app_constants.dart) (يحتوي `keyTheme`, `keyLanguage`) |
| Profile Tab | [profile_tab.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/screens/home/tabs/profile_tab.dart) (يحتوي زر الإعدادات فارغ) |
| Home Drawer | [home_drawer.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/screens/home/home_drawer.dart) (يحتوي زر الإعدادات فارغ) |

---

## 🏗️ هيكل الملفات المطلوب إنشاؤها

```
lib/
├── core/
│   └── services/
│       └── theme_service.dart                    ← [جديد] إدارة الثيم
├── providers/
│   └── settings_provider.dart                    ← [جديد] Provider للإعدادات
├── screens/
│   └── settings/
│       ├── settings_screen.dart                  ← [جديد] الشاشة الرئيسية
│       ├── widgets/
│       │   ├── settings_section.dart             ← [جديد] قسم إعدادات
│       │   ├── settings_tile.dart                ← [جديد] عنصر إعداد
│       │   ├── theme_selector_sheet.dart         ← [جديد] منتقي الثيم
│       │   └── language_selector_sheet.dart       ← [جديد] منتقي اللغة
│       └── sub_screens/
│           ├── notification_settings_screen.dart  ← [جديد] إعدادات الإشعارات
│           ├── account_security_screen.dart       ← [جديد] الأمان والحساب
│           ├── privacy_settings_screen.dart       ← [جديد] الخصوصية
│           └── about_screen.dart                  ← [جديد] حول التطبيق
```

### الملفات الموجودة التي تحتاج تعديل:

| الملف | التعديل |
|-------|---------|
| [main.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/main.dart) | إضافة ThemeService + SettingsProvider + route |
| [route_names.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/constants/route_names.dart) | إضافة route الإعدادات |
| [profile_tab.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/screens/home/tabs/profile_tab.dart) | ربط زر الإعدادات |
| [home_drawer.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/screens/home/home_drawer.dart) | ربط زر الإعدادات |
| [app_ar.arb](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/l10n/app_ar.arb) | إضافة نصوص الإعدادات |
| [app_en.arb](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/l10n/app_en.arb) | إضافة نصوص الإعدادات |

---

## 🔶 المرحلة 1: البنية التحتية (Theme Service + Settings Provider)

### ⏱️ الوقت المتوقع: ~45 دقيقة

### المهام:

#### 1.1 — إنشاء `ThemeService` (`lib/core/services/theme_service.dart`)

```dart
// المتطلبات:
// - extends ChangeNotifier
// - يحفظ الثيم في SharedPreferences باستخدام AppConstants.keyTheme
// - يدعم 3 أوضاع: system, light, dark
// - يوفر getter ThemeMode themeMode
// - يوفر method setThemeMode(ThemeMode)
// - يحمّل القيمة المحفوظة عند التهيئة
```

> [!NOTE]
> **مرجع:** [localization_service.dart](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/services/localization_service.dart) يستخدم نفس النمط (`SharedPreferences` + `ChangeNotifier`)

#### 1.2 — إنشاء `SettingsProvider` (`lib/providers/settings_provider.dart`)

```dart
// المتطلبات:
// - يجمع كل إعدادات المستخدم
// - يدير إعدادات الإشعارات (push, sound, vibration)
// - يدير إعدادات الخصوصية (مشاركة الموقع, إظهار التقييم)
// - يحفظ ويحمّل من SharedPreferences
// - يتكامل مع NotificationProvider الموجود
```

#### 1.3 — تعديل `main.dart`

| التعديل | التفاصيل |
|---------|---------|
| إضافة `ThemeService` كـ Provider | `ChangeNotifierProvider(create: (_) => ThemeService())` |
| إضافة `SettingsProvider` كـ Provider | `ChangeNotifierProvider(create: (_) => SettingsProvider())` |
| ربط `themeMode` | تغيير `themeMode: ThemeMode.system` ← إلى `themeMode: themeService.themeMode` |
| إضافة route الإعدادات | `RouteNames.settings: (context) => const SettingsScreen()` |

> [!IMPORTANT]
> الـ `themeMode` في [main.dart:111](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/main.dart#L111) حالياً `ThemeMode.system` — يجب ربطه بـ `ThemeService` عبر `Consumer<ThemeService>`

#### 1.4 — تعديل `route_names.dart`

```dart
// إضافة في route_names.dart:
static const String settings = '/settings';
static const String notificationSettings = '/notification-settings';
static const String accountSecurity = '/account-security';
static const String privacySettings = '/privacy-settings';
static const String aboutApp = '/about-app';
```

### ✅ معيار الإنجاز:
- [ ] `ThemeService` يحفظ ويحمّل الثيم بنجاح
- [ ] `SettingsProvider` يحفظ ويحمّل جميع الإعدادات
- [ ] التطبيق يستجيب لتغيير الثيم فوراً
- [ ] Routes مسجّلة ومتاحة

---

## 🔶 المرحلة 2: واجهة شاشة الإعدادات الرئيسية

### ⏱️ الوقت المتوقع: ~1 ساعة

### المهام:

#### 2.1 — إنشاء `SettingsSection` Widget

```dart
// مكون قابل لإعادة الاستخدام يعرض:
// - عنوان القسم (مثل: "المظهر", "الحساب")
// - قائمة من SettingsTile
// - تصميم Card مع حواف مستديرة + ظل خفيف
// - يتوافق مع ألوان الثيم الحالي (T.surface, T.primary, etc.)
```

#### 2.2 — إنشاء `SettingsTile` Widget

```dart
// أنواع مختلفة:
// - switch: مفتاح تبديل (مثل: الوضع الداكن)
// - navigation: ينتقل لشاشة فرعية (مثل: إعدادات الإشعارات)
// - selector: يفتح bottom sheet (مثل: اختيار اللغة)
// - action: ينفذ عملية (مثل: مسح الكاش)
//
// يعرض: أيقونة + عنوان + وصف اختياري + trailing widget
// يستخدم iconsax_plus للأيقونات
```

#### 2.3 — إنشاء `SettingsScreen` الرئيسية

```
┌─────────────────────────────────────────────┐
│  ← الإعدادات                         header │
├─────────────────────────────────────────────┤
│                                             │
│  📱 المظهر والعرض                          │
│  ┌─────────────────────────────────────┐    │
│  │ 🌙  الوضع الداكن          [Switch]  │    │
│  │ 🎨  مظهر التطبيق     نظام / داكن ▸  │    │
│  │ 🌐  اللغة              العربية  ▸   │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  🔔 الإشعارات                              │
│  ┌─────────────────────────────────────┐    │
│  │ 🔔  إشعارات فورية        [Switch]  │    │
│  │ 🔊  الأصوات              [Switch]  │    │
│  │ 📳  الاهتزاز             [Switch]  │    │
│  │ ⚙️  إعدادات الإشعارات        ▸     │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  👤 الحساب والأمان                         │
│  ┌─────────────────────────────────────┐    │
│  │ ✏️  تعديل الملف الشخصي       ▸     │    │
│  │ 🔑  تغيير كلمة المرور        ▸     │    │
│  │ 📱  ربط رقم الهاتف           ▸     │    │
│  │ 🛡️  الخصوصية والأمان        ▸     │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  💳 الدفع والمحفظة                          │
│  ┌─────────────────────────────────────┐    │
│  │ 💰  المحفظة                   ▸     │    │
│  │ 📋  سجل المدفوعات            ▸     │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  🆘 الدعم والمساعدة                        │
│  ┌─────────────────────────────────────┐    │
│  │ ❓  الأسئلة الشائعة           ▸     │    │
│  │ 💬  تواصل معنا               ▸     │    │
│  │ 📜  شروط الاستخدام           ▸     │    │
│  │ 🔒  سياسة الخصوصية           ▸     │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ℹ️ حول التطبيق                            │
│  ┌─────────────────────────────────────┐    │
│  │ 📱  إصدار التطبيق     v1.0.0       │    │
│  │ ⭐  تقييم التطبيق            ▸     │    │
│  │ 🔗  مشاركة التطبيق           ▸     │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ 🗑️  حذف الحساب              ▸ 🔴  │    │
│  └─────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
```

#### 2.4 — إنشاء `ThemeSelectorSheet`

```dart
// Bottom Sheet يعرض 3 خيارات:
// 1. 🌐 النظام (يتبع إعدادات الجهاز)
// 2. ☀️ الوضع الفاتح
// 3. 🌙 الوضع الداكن
// 
// كل خيار مع أيقونة ملونة + radio button
// يستدعي ThemeService.setThemeMode()
```

#### 2.5 — إنشاء `LanguageSelectorSheet`

```dart
// Bottom Sheet يعرض اللغات المدعومة:
// 1. 🇸🇦 العربية
// 2. 🇬🇧 English
//
// يستدعي LocalizationService.setLanguage()
// يعرض علامة ✓ على اللغة الحالية
```

### التصميم المرئي:

| العنصر | التفاصيل |
|--------|---------|
| الخلفية | `gradient` خفيف من `primary/0.05` إلى `surface` (مثل [EditProfileScreen](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/screens/profile/edit_profile_screen.dart)) |
| AppBar | مخصص بدون Material AppBar (نفس نمط EditProfileScreen) |
| الأقسام | `Card` مع `borderRadius: 16` و `elevation: 0` + `border` خفيف |
| الأيقونات | `iconsax_plus` (Linear للعادي، Bold للنشط) |
| الخط | `Tajawal` (Google Fonts — الخط الحالي للتطبيق) |
| الألوان | يستخدم `T.primary()`, `T.surface()`, `T.onSurface()` |

### ✅ معيار الإنجاز:
- [ ] شاشة الإعدادات تعرض كل الأقسام بشكل جميل
- [ ] الوضع الداكن يعمل بسلاسة مع التبديل الفوري
- [ ] الـ Bottom Sheets للثيم واللغة تعمل
- [ ] التصميم متجاوب (responsive) مع الشاشات المختلفة

---

## 🔶 المرحلة 3: الشاشات الفرعية

### ⏱️ الوقت المتوقع: ~1.5 ساعة

### المهام:

#### 3.1 — `NotificationSettingsScreen`

```
الميزات:
├── تفعيل/تعطيل الإشعارات العامة
├── إشعارات الرحلات (حجز جديد, تحديث حالة, إلغاء)
├── إشعارات الدفع (تأكيد الدفع, استلام المبلغ)
├── إشعارات الرسائل (رسالة جديدة من سائق/راكب)
├── إشعارات النظام (تحديثات, عروض)
├── الأصوات ← [Switch]
└── الاهتزاز ← [Switch]
```

- **التكامل:** يقرأ/يكتب من `SettingsProvider`
- **دعم:** Firebase Messaging topics subscribe/unsubscribe

#### 3.2 — `AccountSecurityScreen`

```
الميزات:
├── معلومات الحساب (readonly: email, phone, role)
├── تغيير كلمة المرور ← TODO (الباك إند لا يدعمها حالياً)
│   └── يعرض رسالة "قريباً" مع SnackBar
├── ربط/تحديث رقم الهاتف ← ينتقل لـ PhoneAuthScreen(isLinkPhone: true)
├── حالة التحقق:
│   ├── ✅ البريد الإلكتروني (متحقق / غير متحقق)
│   ├── ✅ رقم الهاتف (متحقق / غير متحقق)
│   └── ✅ السائق (معتمد / قيد المراجعة) — للسائقين فقط
├── الجلسات النشطة (مستقبلي)
└── حذف الحساب ← Dialog تأكيد مزدوج + API call
```

- **التكامل:** يقرأ من `AuthProvider.userModel`

> [!WARNING]
> `resetPassword` غير مطبّق حالياً في [auth_service.dart:186-190](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/services/auth_service.dart#L186-L190) — يعرض "قريباً"

#### 3.3 — `PrivacySettingsScreen`

```
الميزات:
├── مشاركة الموقع المباشر ← [Switch]
│   └── يتحكم في LocationService tracking
├── إظهار حالة الاتصال ← [Switch]
├── إظهار التقييم للركاب/السائقين ← [Switch]
├── سياسة الخصوصية ← WebView أو Link خارجي
└── شروط الاستخدام ← WebView أو Link خارجي
```

#### 3.4 — `AboutScreen`

```
الميزات:
├── شعار التطبيق (Logo)
├── اسم التطبيق: RideShare
├── الإصدار: v1.0.0 (من package_info_plus)
├── الوصف: "تطبيق مشاركة الرحلات الآمن والموثوق"
├── تقييم التطبيق ← يفتح Store
├── مشاركة التطبيق ← Share sheet
├── صفحات التواصل الاجتماعي
├── تراخيص البرمجيات (Licenses) ← showLicensePage()
└── حقوق النشر
```

### ✅ معيار الإنجاز:
- [ ] كل شاشة فرعية تعرض المحتوى المطلوب
- [ ] الإعدادات تُحفظ وتُحمّل بشكل صحيح
- [ ] التنقل سلس بين الشاشات

---

## 🔶 المرحلة 4: التكامل والربط

### ⏱️ الوقت المتوقع: ~30 دقيقة

### المهام:

#### 4.1 — ربط الإعدادات من `ProfileTab`

```diff
// تعديل: lib/screens/home/tabs/profile_tab.dart سطر 191-195
 ProfileMenuItem(
   icon: IconsaxPlusLinear.setting_2,
   title: 'الإعدادات',
-  onTap: () {},
+  onTap: () => Navigator.pushNamed(context, RouteNames.settings),
 ),
```

#### 4.2 — ربط الإعدادات من `HomeDrawer`

```diff
// تعديل: lib/screens/home/home_drawer.dart سطر 246-252
 DrawerMenuItem(
   icon: IconsaxPlusLinear.setting_2,
   title: 'الإعدادات',
   onTap: () {
     Navigator.pop(context);
+    Navigator.pushNamed(context, RouteNames.settings);
   },
 ),
```

#### 4.3 — ربط أزرار "المساعدة" و "حول التطبيق" في `ProfileTab`

```diff
// تعديل: lib/screens/home/tabs/profile_tab.dart سطر 197-200
 ProfileMenuItem(
   icon: IconsaxPlusLinear.message_question,
   title: 'المساعدة والدعم',
-  onTap: () {},
+  onTap: () => Navigator.pushNamed(context, RouteNames.settings),
 ),

// سطر 203-206
 ProfileMenuItem(
   icon: IconsaxPlusLinear.info_circle,
   title: 'حول التطبيق',
-  onTap: () {},
+  onTap: () => Navigator.pushNamed(context, RouteNames.aboutApp),
 ),
```

#### 4.4 — إضافة نصوص الترجمة

في [app_ar.arb](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/l10n/app_ar.arb):

```json
{
  "settings": "الإعدادات",
  "appearance": "المظهر والعرض",
  "darkMode": "الوضع الداكن",
  "themeMode": "مظهر التطبيق",
  "themeSystem": "النظام",
  "themeLight": "فاتح",
  "themeDark": "داكن",
  "language": "اللغة",
  "notificationSettings": "إعدادات الإشعارات",
  "pushNotifications": "إشعارات فورية",
  "sounds": "الأصوات",
  "vibration": "الاهتزاز",
  "accountAndSecurity": "الحساب والأمان",
  "editProfile": "تعديل الملف الشخصي",
  "changePassword": "تغيير كلمة المرور",
  "linkPhoneNumber": "ربط رقم الهاتف",
  "privacyAndSecurity": "الخصوصية والأمان",
  "paymentAndWallet": "الدفع والمحفظة",
  "wallet": "المحفظة",
  "paymentHistory": "سجل المدفوعات",
  "supportAndHelp": "الدعم والمساعدة",
  "faq": "الأسئلة الشائعة",
  "contactUs": "تواصل معنا",
  "termsOfService": "شروط الاستخدام",
  "privacyPolicy": "سياسة الخصوصية",
  "aboutApp": "حول التطبيق",
  "appVersion": "إصدار التطبيق",
  "rateApp": "تقييم التطبيق",
  "shareApp": "مشاركة التطبيق",
  "deleteAccount": "حذف الحساب",
  "comingSoon": "قريباً",
  "deleteAccountConfirmation": "هل أنت متأكد من حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.",
  "locationSharing": "مشاركة الموقع المباشر",
  "showOnlineStatus": "إظهار حالة الاتصال",
  "showRating": "إظهار التقييم"
}
```

### ✅ معيار الإنجاز:
- [ ] زر الإعدادات في ProfileTab يعمل
- [ ] زر الإعدادات في HomeDrawer يعمل
- [ ] أزرار المساعدة وحول التطبيق تعمل
- [ ] النصوص بالعربية والإنجليزية متاحة

---

## 🔶 المرحلة 5: التلميع والاختبار

### ⏱️ الوقت المتوقع: ~30 دقيقة

### المهام:

#### 5.1 — تحسينات بصرية

- إضافة **animations** عند التبديل بين الأوضاع (fade/scale)
- تأثير **ripple** على العناصر القابلة للنقر
- **Gradient** خفيف في خلفية الشاشة
- أيقونات ملونة حسب نوع القسم:

| القسم | لون الأيقونة |
|-------|-------------|
| المظهر | `teal` (Primary) |
| الإشعارات | `amber` / `warning` |
| الحساب | `blue` / `info` |
| الدفع | `green` / `success` |
| الدعم | `purple` |
| حول | `slate` |
| حذف الحساب | `red` / `error` |

#### 5.2 — التجاوب (Responsive)

- اختبار على شاشات مختلفة
- استخدام `ResponsiveLayout` الموجود في `lib/core/utils/responsive_layout.dart`
- دعم الـ Navigation Rail للشاشات العريضة

#### 5.3 — حالات الحافة (Edge Cases)

- [ ] ماذا يحدث عند تغيير اللغة والعودة للإعدادات؟
- [ ] ماذا يحدث عند تبديل الثيم أثناء التمرير؟
- [ ] ماذا يحدث إذا فشل حفظ الإعدادات في SharedPreferences؟
- [ ] ماذا يحدث إذا كان المستخدم سائق vs راكب (عرض أقسام مختلفة)؟

#### 5.4 — اختبار التكامل

- [ ] تأكد أن تغيير الثيم ينعكس على كل الشاشات
- [ ] تأكد أن تغيير اللغة ينعكس مباشرة (RTL ↔ LTR)
- [ ] تأكد أن الإعدادات تبقى محفوظة بعد إغلاق التطبيق

---

## 📦 الحزم المطلوبة

| الحزمة | الاستخدام | الحالة |
|--------|----------|--------|
| `shared_preferences` | حفظ الإعدادات محلياً | ✅ موجودة |
| `provider` | إدارة الحالة | ✅ موجودة |
| `iconsax_plus` | أيقونات | ✅ موجودة |
| `google_fonts` | خطوط Tajawal | ✅ موجودة |
| `cached_network_image` | صور الملف الشخصي | ✅ موجودة |
| `package_info_plus` | معلومات الإصدار | ❌ تحتاج إضافة |
| `share_plus` | مشاركة التطبيق | ❌ تحتاج إضافة |
| `url_launcher` | فتح روابط خارجية | ❌ تحتاج إضافة |

---

## 📊 ملخص المراحل

| المرحلة | الوصف | الملفات | الوقت |
|---------|-------|---------|-------|
| **1** | البنية التحتية | `ThemeService`, `SettingsProvider`, تعديل `main.dart` | ~45 دقيقة |
| **2** | الواجهة الرئيسية | `SettingsScreen`, Widgets, Bottom Sheets | ~60 دقيقة |
| **3** | الشاشات الفرعية | 4 شاشات فرعية | ~90 دقيقة |
| **4** | التكامل والربط | تعديل `ProfileTab`, `HomeDrawer`, الترجمة | ~30 دقيقة |
| **5** | التلميع والاختبار | Animations, Responsive, Edge cases | ~30 دقيقة |
| | | **الإجمالي** | **~4 ساعات** |

---

## 🔑 ملاحظات تقنية مهمة

> [!IMPORTANT]
> - الـ `themeMode` في [main.dart:111](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/main.dart#L111) حالياً `ThemeMode.system` — يجب ربطه بـ `ThemeService`
> - الباك إند لا يدعم `resetPassword` حالياً ([auth_service.dart:186-190](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/services/auth_service.dart#L186-L190))
> - يجب عدم كتابة الـ `email` في الباك إند (readonly — [auth_service.dart:158](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/core/services/auth_service.dart#L158))
> - اللغات المدعومة: `ar` (العربية) و `en` (الإنجليزية) — محدد في [main.dart:113](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/main.dart#L113)
> - أزرار الإعدادات في [profile_tab.dart:188-206](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/screens/home/tabs/profile_tab.dart#L188-L206) كلها `onTap: () {}` فارغة

> [!WARNING]
> - حذف الحساب يحتاج endpoint في الباك إند — تأكد من وجوده قبل التنفيذ
> - تغيير اللغة يستدعي `FirebaseAuth.instance.setLanguageCode()` — تأكد من عدم حدوث crash

---

## 🎨 مرجع التصميم

التصميم يجب أن يتبع نفس أسلوب [EditProfileScreen](file:///c:/Users/HP/Desktop/mahoudmsq/rideshare/lib/screens/profile/edit_profile_screen.dart):
- خلفية gradient خفيفة
- Custom AppBar بدون Material AppBar
- Cards مع ظلال خفيفة وحواف مستديرة (16px)
- أيقونات داخل containers ملونة بشفافية 10%
- خط Tajawal عبر Google Fonts
- دعم RTL كامل
