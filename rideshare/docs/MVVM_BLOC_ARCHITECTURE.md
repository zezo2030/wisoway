# 🏗️ MVVM Architecture with BLoC

## 📋 نظرة عامة

تم تحويل المشروع من Provider إلى **MVVM Architecture** مع **BLoC** كـ State Management.

---

## 🎯 البنية الجديدة

### 1. BLoC Layer

```
lib/bloc/
├── auth/
│   ├── auth_bloc.dart      # Auth Business Logic
│   ├── auth_event.dart      # Auth Events
│   └── auth_state.dart      # Auth States
└── trip/
    ├── trip_bloc.dart       # Trip Business Logic
    ├── trip_event.dart      # Trip Events
    └── trip_state.dart      # Trip States
```

### 2. MVVM Structure

```
┌─────────────────────────────────────┐
│         View (UI Layer)             │
│  - Screens                          │
│  - Widgets                          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│      ViewModel (BLoC Layer)         │
│  - AuthBloc                         │
│  - TripBloc                         │
│  - Events & States                  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         Model (Data Layer)          │
│  - Services (AuthService, etc.)     │
│  - Models (UserModel, TripModel)    │
│  - Repositories (Future)            │
└─────────────────────────────────────┘
```

---

## 📦 BLoC Components

### Auth BLoC

#### Events:
- `AuthInitialized` - تهيئة Auth
- `AuthSendOTP` - إرسال OTP
- `AuthVerifyOTP` - التحقق من OTP
- `AuthSignUpWithEmail` - التسجيل بالإيميل
- `AuthSignInWithEmail` - تسجيل الدخول بالإيميل
- `AuthSignInWithGoogle` - تسجيل الدخول بـ Google
- `AuthSignInWithFacebook` - تسجيل الدخول بـ Facebook
- `AuthLinkPhoneNumber` - ربط رقم الهاتف
- `AuthSaveUserProfile` - حفظ ملف المستخدم
- `AuthSaveDriverProfile` - حفظ ملف السائق
- `AuthSignOut` - تسجيل الخروج
- `AuthClearError` - مسح الخطأ

#### States:
- `AuthInitial` - الحالة الأولية
- `AuthLoading` - جاري التحميل
- `AuthAuthenticated` - مسجل دخول مع ملف
- `AuthAuthenticatedNoProfile` - مسجل دخول بدون ملف
- `AuthUnauthenticated` - غير مسجل دخول
- `AuthError` - خطأ
- `AuthOTPSent` - تم إرسال OTP
- `AuthProfileSaved` - تم حفظ الملف

### Trip BLoC

#### Events:
- `TripCreate` - إنشاء رحلة
- `TripGetById` - جلب رحلة بالـ ID
- `TripGetDriverTrips` - جلب رحلات السائق
- `TripUpdate` - تحديث رحلة
- `TripHide` - إخفاء رحلة
- `TripShow` - إظهار رحلة
- `TripDelete` - حذف رحلة
- `TripBookSeat` - حجز مقعد
- `TripCancelSeatBooking` - إلغاء حجز مقعد
- `TripGetCurrentLocation` - جلب الموقع الحالي
- `TripGetAddressFromCoordinates` - جلب العنوان من الإحداثيات
- `TripGetCoordinatesFromAddress` - جلب الإحداثيات من العنوان
- `TripClearError` - مسح الخطأ

#### States:
- `TripInitial` - الحالة الأولية
- `TripLoading` - جاري التحميل
- `TripCreated` - تم إنشاء الرحلة
- `TripLoaded` - تم تحميل الرحلة
- `TripDriverTripsLoaded` - تم تحميل رحلات السائق
- `TripUpdated` - تم تحديث الرحلة
- `TripHidden` - تم إخفاء الرحلة
- `TripShown` - تم إظهار الرحلة
- `TripDeleted` - تم حذف الرحلة
- `TripSeatBooked` - تم حجز المقعد
- `TripSeatBookingCancelled` - تم إلغاء حجز المقعد
- `TripLocationLoaded` - تم تحميل الموقع
- `TripAddressLoaded` - تم تحميل العنوان
- `TripError` - خطأ

---

## 🔄 كيفية الاستخدام

### في الشاشات:

```dart
// 1. استخدام BlocBuilder
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    if (state is AuthLoading) {
      return CircularProgressIndicator();
    }
    if (state is AuthAuthenticated) {
      return HomeScreen();
    }
    return SignInScreen();
  },
)

// 2. إرسال Events
context.read<AuthBloc>().add(
  AuthSignInWithEmail(
    email: email,
    password: password,
  ),
);

// 3. الاستماع للتغييرات
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  },
  child: ...,
)
```

---

## 📝 Migration Notes

### من Provider إلى BLoC:

**قبل (Provider):**
```dart
final authProvider = Provider.of<AuthProvider>(context);
await authProvider.signInWithEmail(email: email, password: password);
```

**بعد (BLoC):**
```dart
context.read<AuthBloc>().add(
  AuthSignInWithEmail(email: email, password: password),
);
```

---

## ✅ المزايا

1. **Separation of Concerns**: فصل واضح بين UI و Business Logic
2. **Testability**: سهولة اختبار BLoC بشكل منفصل
3. **Predictable State Management**: حالات واضحة ومحددة
4. **Reactive Programming**: استجابة تلقائية للتغييرات
5. **Scalability**: سهولة إضافة features جديدة

---

## 🚀 الخطوات التالية

1. ✅ إنشاء Auth BLoC
2. ✅ إنشاء Trip BLoC
3. ⏳ تحديث جميع الشاشات
4. ⏳ تحديث main.dart
5. ⏳ اختبار التطبيق

---

## 📚 Resources

- [BLoC Documentation](https://bloclibrary.dev/)
- [MVVM Pattern](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel)

