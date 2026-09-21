# Mobile Auth Screens — Rebuild Specification

Scope: the Flutter passenger/shared authentication UI under `rideshare/lib/screens/auth/` plus the
shared widgets in `rideshare/lib/widgets/auth/`.

**Out of scope (covered elsewhere):** `driver_sign_up_screen.dart`,
`driver_complete_profile_screen.dart`, `screens/auth/driver_complete/*` (driver flow agent),
`core/services/auth_service.dart` and `providers/auth_provider.dart` (orchestrator). Provider method
signatures are quoted here only where a screen calls them.

All paths below are relative to `d:\work\wisoway\rideshare\lib\` unless stated otherwise.

---

## 0. Flow diagram

```
                                  app launch
                                      |
                            main.dart  home: AuthWrapper
                                      |
      +-------------------------------+---------------------------------------+
      |                               |                                       |
 isInitializing            !isAuthenticated                            isAuthenticated
      |                               |                                       |
 CircularProgress    +----------------+-----------------+           +---------+---------+
                     |                                  |           |                   |
        pendingDriverRegistration != null            else      !isPhoneVerified    isPhoneVerified
                     |                                  |           |                   |
        DriverCompleteProfileScreen              S-01 WELCOME   S-03 PHONE_AUTH     HomeScreen
              (driver flow — out of scope)                      (isLinkPhone:true)


  S-01 WELCOME  (/welcome)
    |
    +-- "Sign in"            --> pushNamed          --> S-06 SIGN_IN
    +-- "Create new account" --> pushNamed          --> S-02 ACCOUNT_TYPE


  S-02 ACCOUNT_TYPE  (/account-type-selection)
    |
    +-- passenger card  --> pushReplacementNamed(/sign-up, {accountType:'passenger'}) --> S-05 SIGN_UP
    +-- driver card     --> pushReplacementNamed(/driver-sign-up) ---------------------> [DRIVER FLOW]
    |                                                                                    (out of scope)
    +-- "Sign in" link  --> pushReplacementNamed --> S-06 SIGN_IN


  S-05 SIGN_UP (step 1/3)  (/sign-up)
    |  AuthProvider.sendOTP(phone)  [on success]
    +--> pushReplacementNamed(/otp-verification,
            {phoneNumber, isRegistration:true, role:'passenger', accountType,
             name, gender, password, afterVerifyRoute:'/profile-setup',
             authStep:2, authTotalSteps:3})                    --> S-04 OTP (step 2/3)
    +-- "Sign in" link --> pushReplacementNamed --> S-06 SIGN_IN


  S-04 OTP_VERIFICATION (step 2/3)  (/otp-verification)
    |
    +-- args.isLinkPhone == true
    |     AuthProvider.linkPhone(...)
    |       +-- args.afterVerifyRoute != null --> pushReplacementNamed(afterVerifyRoute)
    |       +-- else                          --> Navigator.pop()
    |
    +-- args.role == 'driver' && !args.isDriverCompleteProfile
    |     AuthProvider.verifyDriverPhone(...) --> pushReplacementNamed(/driver-complete-profile)
    |                                                                 [DRIVER FLOW — out of scope]
    |
    +-- otherwise (passenger registration / phone sign-in)
          AuthProvider.verifyOTP(...)
            +-- args.isDriverCompleteProfile == true --> _completeDriverProfileAfterOtp()  [DEAD — see notes]
            +-- args.afterVerifyRoute != null        --> pushReplacementNamed(afterVerifyRoute,
            |                                              {name,email,gender,role,phoneNumber,
            |                                               authStep,authTotalSteps})
            |                                            --> S-07 PROFILE_SETUP (step 3/3)
            +-- else                                 --> pushReplacementNamed(/home)


  S-07 PROFILE_SETUP (step 3/3)  (/profile-setup)
    |  AuthProvider.completePassengerProfile(profileImage, city)
    +--> pushNamedAndRemoveUntil(/home, (r)=>false)          --> HomeScreen


  S-06 SIGN_IN  (/sign-in)
    |
    +-- "Sign in" button
    |     AuthProvider.signInWithPhoneAndPassword(phone, password)
    |       +-- userModel.isPhoneVerified == true  --> pushNamedAndRemoveUntil(/home)
    |       +-- else                              --> pushNamedAndRemoveUntil(/phone-auth,
    |                                                    {isLinkPhone:true})  --> S-03
    +-- "Forgot password?"
    |     AuthProvider.forgotPassword(phone)
    |     --> pushNamed(/reset-password, {phoneNumber})       --> S-09 RESET_PASSWORD
    +-- "Create a new account" --> pushReplacementNamed --> S-02 ACCOUNT_TYPE
    +-- AppBar back --> pop --> S-01 WELCOME


  S-03 PHONE_AUTH  (/phone-auth)   [isLinkPhone from route args]
    |  AuthProvider.sendOTP(formattedPhone)
    +--> pushReplacementNamed(/otp-verification,
            {phoneNumber, isSignIn: !isLinkPhone, isLinkPhone,
             + passthrough of afterVerifyRoute/firstName/lastName/email/gender}) --> S-04 OTP
    Entered from: AuthWrapper (isLinkPhone:true), S-06 SIGN_IN (isLinkPhone:true),
                  profile_tab.dart:178 (isLinkPhone:true),
                  account_security_screen.dart:53 (NO ARGS -> isLinkPhone:false, see notes)


  S-08 FORGOT_PASSWORD  (/forgot-password)     [near-orphan — see notes]
    |  AuthProvider.forgotPassword(phone)
    +--> pushNamed(/reset-password, {phoneNumber})            --> S-09
    +-- "Back to sign in" / AppBar back --> pop
    Entered from: ONLY S-09's error paths (missing phone arg, "too many attempts", "expired").


  S-09 RESET_PASSWORD  (/reset-password)  — internal 2-page PageView
    |
    |  page 0: OTP entry
    |     AuthProvider.verifyResetOtp(phone, code) -> resetToken
    |       +-- success                       --> PageView.nextPage() -> page 1
    |       +-- "too many attempts"/"locked"  --> snackbar + action -> pushReplacementNamed(/forgot-password)
    |       +-- "expired"                     --> snackbar + action -> pushReplacementNamed(/forgot-password)
    |       +-- no phoneNumber in args        --> pushReplacementNamed(/forgot-password)  [in initState]
    |
    |  page 1: new password
    |     AuthProvider.resetPassword(resetToken, newPassword)
    +--> pushNamedAndRemoveUntil(/sign-in, (r)=>false)        --> S-06 SIGN_IN


  S-10 BANNED  (/banned)
    Entered ONLY from core/api/auth_interceptor.dart:51 on HTTP 403 with body code == 'ACCOUNT_BANNED':
      tokenStorage.clearAll() then
      navigatorKey.pushNamedAndRemoveUntil(/banned, (r)=>false, {banReason, supportWhatsApp})
    Exits: no in-app navigation. Only an external WhatsApp deep link (https://wa.me/...).


  Global exit (any screen):
    ErrorSurface FailureAction.reauthenticate --> rootNavigator.pushNamedAndRemoveUntil(/sign-in)
    (core/ui/error_surface.dart:149)
```

---

## 1. Localization keys used by the auth flow

Source files: `l10n/app_en.arb`, `l10n/app_ar.arb`. Accessed through
`context.l10n` (`l10n/l10n_extensions.dart` — `AppLocalizations.of(this)`).

| Key | EN | AR |
|---|---|---|
| `welcomeTitle` | Welcome to VisionWay | مرحباً بك في VisionWay |
| `welcomeSubtitle` | Your journey starts here. Pick a destination and travel safely and comfortably. | رحلتك تبدأ من هنا. اختر وجهتك وانطلق معنا بكل أمان وراحة. |
| `signIn` | Sign in | تسجيل الدخول |
| `createNewAccount` | Create a new account | إنشاء حساب جديد |
| `accountTypeTitle` | Choose account type | اختر نوع الحساب |
| `accountTypeSubtitle` | Select how you want to use the app | حدد كيف تريد استخدام التطبيق |
| `accountTypePassenger` | Passenger | راكب |
| `accountTypePassengerTagline` | Book direct or shared rides | احجز رحلات مباشرة أو مشتركة |
| `accountTypePassengerFeatureDirectTitle` | Direct rides | رحلات مباشرة |
| `accountTypePassengerFeatureDirectBody` | Book a private ride that comes to you | احجز رحلة خاصة تصلك مباشرة |
| `accountTypePassengerFeatureSharedTitle` | Shared rides | رحلات مشتركة |
| `accountTypePassengerFeatureSharedBody` | Join a trip and share the savings | انضم لرحلة وشارك في التوفير |
| `accountTypePassengerFeaturePaymentTitle` | Safe and easy payment | دفع آمن وسهل |
| `accountTypePassengerFeaturePaymentBody` | Multiple secure payment options | خيارات دفع متعددة وآمنة |
| `accountTypeDriver` | Driver | سائق |
| `accountTypeDriverTagline` | Create trips and pick up passengers | أنشئ رحلات واستقبل الركاب |
| `accountTypeDriverFeatureTripsTitle` | Create trips | أنشئ رحلات |
| `accountTypeDriverFeatureTripsBody` | Set your destination and departure | حدد وجهتك والانطلاق |
| `accountTypeDriverFeatureBookingsTitle` | Receive bookings | استقبل الحجوزات |
| `accountTypeDriverFeatureBookingsBody` | Get booking requests from passengers | احصل على طلبات الركاب |
| `accountTypeDriverFeatureIncomeTitle` | Earn extra income | حقق دخلاً إضافيا |
| `accountTypeDriverFeatureIncomeBody` | Boost your income in your free time | زد دخلك في أوقات فراغك |
| `accountTypeSafetyTitle` | Your safety is our priority | أمانك هو أولويتنا |
| `accountTypeSafetyBody` | We verify every user to keep the experience safe and trusted for everyone. | نتحقق من جميع المستخدمين لضمان تجربة آمنة وموثوقة للجميع. |
| `alreadyHaveAccount` | `Already have an account? ` (trailing space) | `لديك حساب بالفعل؟ ` (trailing space) |
| `linkPhoneTitle` | Link phone number | ربط رقم الهاتف |
| `enterPhoneToConfirm` | Enter your phone number to confirm | أدخل رقم هاتفك للتأكيد |
| `enterYourPhone` | Enter your phone number | أدخل رقم هاتفك |
| `linkPhoneSubtitle` | Confirm your phone number to continue | أكد رقم هاتفك للمتابعة |
| `devModeDirectLogin` | Development mode: you will be logged in directly | وضع التطوير: سيتم الدخول مباشرة |
| `otpWillBeSentViaSms` | We will send you a verification code via SMS | سنرسل لك رمز التحقق عبر SMS |
| `phoneNumber` | Phone Number | رقم الهاتف |
| `phoneNumberRequired` | Please enter phone number | يرجى إدخال رقم الهاتف |
| `invalidPhoneNumber` | Invalid phone number | رقم الهاتف غير صحيح |
| `loading` | Loading... | جاري التحميل... |
| `enterAction` | Enter | دخول |
| `sendOTP` | Send Verification Code | إرسال رمز التحقق |
| `otpVerification` | Verify Code | التحقق من الرمز |
| `authStepOf` | `Step {current} of {total}` | `خطوة {current} من {total}` |
| `enterOTP` | Enter verification code | أدخل رمز التحقق |
| `otpSentToPhone` | `A 6-digit code has been sent to\n` (trailing newline) | `تم إرسال الرمز المكون من 6 أرقام إلى\n` |
| `otpDigitLabel` | `Verification code digit {index}` | `رمز التحقق {index}` |
| `verifyButton` | Verify | تحقق |
| `resendOTP` | Resend Code | إعادة إرسال الرمز |
| `resendOTPIn` | `Resend code in {seconds} seconds` | `إعادة إرسال الرمز خلال {seconds} ثانية` |
| `otpResent` | Verification code resent | تم إرسال رمز التحقق مرة أخرى |
| `driverProfileSubmitted` | Your details were uploaded successfully. Your request is under review by the administration. | تم رفع بياناتك بنجاح. طلبك قيد المراجعة من الإدارة. |
| `fullName` | Full name | الاسم الكامل |
| `fullNameHint` | Enter your full name | أدخل اسمك بالكامل |
| `validNameRequired` | Please enter a valid name | يرجى إدخال اسم صحيح |
| `password` | Password | كلمة المرور |
| `passwordMinLengthHint` | Must contain at least 8 characters | يجب أن تحتوي على 8 أحرف على الأقل |
| `passwordRequired` | Password is required | كلمة المرور مطلوبة |
| `passwordPolicyError` | Password must be 8+ chars with a letter and a number | يجب أن تحتوي كلمة السر على 8 أحرف مع حرف ورقم |
| `confirmPassword` | Confirm password | تأكيد كلمة المرور |
| `confirmPasswordReenterHint` | Re-enter the password | أعد إدخال كلمة المرور |
| `confirmPasswordRequired` | Please confirm your password | يرجى تأكيد كلمة السر |
| `passwordsDoNotMatch` | Passwords do not match | كلمتا المرور غير متطابقتين |
| `genderRequiredLabel` | `Gender *` | `الجنس *` |
| `male` | Male | ذكر |
| `female` | Female | أنثى |
| `continueLabel` | Continue | متابعة |
| `passengerSignupTitle` | Create a new account | إنشاء حساب جديد |
| `passengerSignupSubtitle` | Register now as a passenger to start your journey with us | سجل الآن كراكب لبدء رحلتك معنا |
| `selectGenderError` | Please select gender | يرجى اختيار الجنس |
| `signInSubtitle` | Welcome back! Sign in to continue. | أهلاً بك مجدداً! سجل دخولك للمتابعة. |
| `required` | Required | مطلوب |
| `passwordTooShort` | Password is too short | كلمة المرور قصيرة |
| `forgotPassword` | Forgot password? | نسيت كلمة السر؟ |
| `noAccountQuestion` | `Don't have an account? ` (trailing space) | `ليس لديك حساب؟ ` (trailing space) |
| `phoneNumberFirst` | Please enter your phone number first | يرجى إدخال رقم الهاتف أولاً |
| `passengerProfileStepTitle` | Complete your profile | أكمل ملفك الشخصي |
| `passengerProfileStepSubtitle` | Add your photo and city so drivers recognise you | أضف صورتك ومدينتك ليتعرف عليك السائقون |
| `profilePhotoRequired` | `Profile photo *` | `الصورة الشخصية *` |
| `profilePhotoClearHint` | A clear photo of your face | صورة واضحة لوجهك |
| `profileCityLabel` | `City *` | `المدينة *` |
| `profileCityHint` | Enter your city | أدخل اسم مدينتك |
| `profileCityRequired` | City is required | المدينة مطلوبة |
| `complete` | Complete | إكمال |
| `uploadProfilePhoto` | Profile photo | صورة الملف الشخصي |
| `fromGallery` | From gallery | من المعرض |
| `fromCamera` | From camera | من الكاميرا |
| `forgotPasswordTitle` | Forgot password | نسيت كلمة المرور |
| `forgotPasswordSubtitle` | Enter your phone and we'll send a reset code | أدخل رقم هاتفك وسنرسل لك رمز إعادة التعيين |
| `sendResetCode` | Send reset code | إرسال رمز إعادة التعيين |
| `backToSignIn` | Back to sign in | العودة إلى تسجيل الدخول |
| `otpSentToYourPhone` | A verification code has been sent to your phone number | تم إرسال رمز التحقق إلى رقم هاتفك |
| `resendCode` | Resend code | إعادة الإرسال |
| `resendCodeIn` | `Resend in {seconds}s` | `إعادة الإرسال بعد {seconds} ث` |
| `otpTooManyAttempts` | Too many attempts. Please request a new code. | محاولات كثيرة جداً. يرجى طلب رمز جديد. |
| `otpExpired` | Verification code has expired. Please request a new one. | انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد. |
| `requestNewCode` | Request New Code | طلب رمز جديد |
| `newOtpSent` | A new verification code has been sent | تم إرسال رمز تحقق جديد |
| `waitBeforeResend` | `Please wait {seconds} seconds before requesting a new code` | `يرجى الانتظار {seconds} ثانية قبل طلب رمز جديد` |
| `resetPasswordTitle` | Reset password | إعادة تعيين كلمة المرور |
| `newPassword` | New password | كلمة المرور الجديدة |
| `newPasswordRequired` | Please enter a new password | يرجى إدخال كلمة مرور جديدة |
| `resetPasswordButton` | Reset | إعادة تعيين |
| `passwordResetSuccess` | Password changed successfully | تم تغيير كلمة المرور بنجاح |
| `accountBannedTitle` | Account Suspended | تم تعليق حسابك |
| `accountBannedNoReason` | Your account has been suspended. Contact support for details. | تم تعليق حسابك. تواصل مع الدعم لمزيد من التفاصيل. |
| `contactSupportViaWhatsApp` | Contact support via WhatsApp | تواصل مع الدعم عبر WhatsApp |
| `bannedWhatsAppPrefill` | Hello, my VisionWay account is suspended and I need help. | مرحباً، حسابي على تطبيق VisionWay موقوف وأحتاج مساعدة. |
| `couldNotOpenWhatsApp` | Could not open WhatsApp | تعذر فتح WhatsApp |
| `authSecurityNotice` | All your data is kept secure and will not be shared with any party | جميع بياناتك محفوظة بأمان ولن تتم مشاركتها مع أي جهة |
| `language` | Language | اللغة |
| `tapToUpload` | Tap to upload | اضغط للرفع |
| `tapToChange` | Tap to change | اضغط للتغيير |
| `documentFormatsHint` | Supported: JPG, PNG, PDF (max 5 MB) | الصيغ المدعومة: JPG، PNG، PDF (الحد الأقصى 5 ميجابايت) |
| `uploadFileLabel` | `Upload {title}` | `رفع {title}` |
| `countryCodePickerSemantic` | (used by `CountryCodePicker`, `widgets/country_code_picker.dart:29`) | — |

Placeholder-bearing keys (must be generated as methods, not getters):
`authStepOf(current, total)`, `otpDigitLabel(index)`, `resendOTPIn(seconds)`,
`resendCodeIn(seconds)`, `waitBeforeResend(seconds)`, `uploadFileLabel(title)`.

---

## 2. Shared constants the auth flow depends on

`core/constants/app_constants.dart`:

| Constant | Value | Notes |
|---|---|---|
| `AppConstants.appName` | `'VisionWay'` | |
| `AppConstants.skipOTP` | `false` | compile-time const; gates dead dev-mode branches in S-03 |
| `AppConstants.printOTPToConsole` | `false` | not referenced by any in-scope screen |
| `AppConstants.otpLength` | `6` | OTP box count on S-04 and S-09 |
| `AppConstants.otpResendTimeout` | `60` (seconds) | resend countdown on S-04 and S-09 |
| `AppConstants.defaultCountryCode` | `'+20'` (Egypt) | **only** used by S-03 PhoneAuthScreen |
| `AppConstants.rolePassenger` / `roleDriver` | `'passenger'` / `'driver'` | |
| `AppConstants.genderMale` / `genderFemale` | `'male'` / `'female'` | |
| `AppConstants.langArabic` / `langEnglish` | used by `AuthLanguageSwitcher` | |

`core/constants/countries.dart`:

| Constant | Value |
|---|---|
| `Countries.defaultCountry` | `CountryData(iso2:'JO', dialCode:'+962', nameEn:'Jordan', nameAr:'الأردن')` |
| `Countries.all` | full ITU-T E.164 list, Arab region first (EG +20, SA +966, AE +971, JO +962, KW +965, …) |

**Gotcha:** the app has two different "default country" notions — `Countries.defaultCountry` is
Jordan `+962` (used by S-05, S-06, S-08 via the picker), while `AppConstants.defaultCountryCode` is
Egypt `+20` (hard-coded fallback in S-03). Reimplementations should unify these.

`core/constants/route_names.dart` (auth block, verbatim):

```dart
static const String welcome              = '/welcome';
static const String signIn               = '/sign-in';
static const String accountTypeSelection = '/account-type-selection';
static const String signUp               = '/sign-up';
static const String phoneAuth            = '/phone-auth';
static const String otpVerification      = '/otp-verification';
static const String profileSetup         = '/profile-setup';
static const String driverSignUp         = '/driver-sign-up';
static const String driverCompleteProfile= '/driver-complete-profile';
static const String driverPendingApproval= '/driver-pending-approval';
static const String forgotPassword       = '/forgot-password';
static const String resetPassword        = '/reset-password';
static const String banned               = '/banned';
```

---

## 3. Router wiring (`main.dart`)

`MaterialApp.home = const AuthWrapper()`. `AuthWrapper` (`main.dart:400-461`) is a
`Consumer<AuthProvider>` with a `WidgetsBindingObserver` that calls
`authProvider.loadUserProfile(silent: true)` on `AppLifecycleState.resumed` while authenticated.

Branch order (`main.dart:432-459`):
1. `authProvider.isInitializing` → `Scaffold(body: Center(child: CircularProgressIndicator()))`
2. `!authProvider.isAuthenticated`
   - `authProvider.pendingDriverRegistration != null` → `DriverCompleteProfileScreen()` (driver flow)
   - else → `WelcomeScreen()`
3. `!(authProvider.userModel?.isPhoneVerified ?? false)` → `PhoneAuthScreen(isLinkPhone: true)`
4. else → `HomeScreen()`

Static `routes:` table entries relevant here (`main.dart:147-194`) — **all take no constructor
arguments**, so any data must arrive via `ModalRoute.of(context).settings.arguments`:

```dart
'/welcome'                 -> const WelcomeScreen()
'/sign-in'                 -> const SignInScreen()
'/account-type-selection'  -> const AccountTypeSelectionScreen()
'/sign-up'                 -> const SignUpScreen()
'/forgot-password'         -> const ForgotPasswordScreen()
'/reset-password'          -> const ResetPasswordScreen()
'/profile-setup'           -> const ProfileSetupScreen()
'/banned'                  -> const BannedScreen()
```

`onGenerateRoute` entries (`main.dart:217-234`) — the only two auth screens with real constructor
parameters:

```dart
if (settings.name == RouteNames.phoneAuth) {
  final args = settings.arguments as Map<String, dynamic>?;
  final isLinkPhone = args?['isLinkPhone'] == true;
  return MaterialPageRoute(settings: settings,
      builder: (_) => PhoneAuthScreen(isLinkPhone: isLinkPhone));
}
if (settings.name == RouteNames.otpVerification) {
  final args = settings.arguments as Map<String, dynamic>;   // NOT nullable — throws if null
  return MaterialPageRoute(settings: settings,
      builder: (_) => OTPVerificationScreen(phoneNumber: args['phoneNumber']));
}
```

Note both pass `settings: settings`, which is what makes `ModalRoute.of(context)!.settings.arguments`
readable inside the screens. Screens registered in the static `routes:` table get their `settings`
from the framework automatically.

Providers available above every auth screen (`main.dart:112-123`):
`LocalizationService`, `ThemeService`, `AuthProvider`, `TripProvider`, `NotificationProvider`
(all `ChangeNotifierProvider`), plus `AuthBloc`, `TripBloc`, `BookingBloc`.
Localization delegates: `AppLocalizations.delegate` + the three `GlobalXLocalizations` delegates;
`locale` comes from `LocalizationService.locale`. Portrait orientation is locked in `main()`
(`main.dart:81-84`).

---

## S-01: WelcomeScreen  (`screens/auth/welcome_screen.dart`)

**Purpose:** First screen an unauthenticated user sees. Branding splash with two choices — sign in or
start registration.

**Reached from:** `AuthWrapper` when `!isAuthenticated && pendingDriverRegistration == null`
(`main.dart:448`). Also registered at `/welcome`, but **no code anywhere pushes that route by name**
(verified by grep — only `main.dart:147` references it).

**Navigates to:**
- `Navigator.pushNamed(context, RouteNames.signIn)` — tap "Sign in" (line 159) → S-06.
- `Navigator.pushNamed(context, RouteNames.accountTypeSelection)` — tap "Create a new account"
  (line 167) → S-02.

Both are `pushNamed` (not replacement), so S-06/S-02 can pop back here.

**Route name / constructor args:** `/welcome`; `const WelcomeScreen({super.key})` — no parameters.

**UI structure:**
```
Scaffold(backgroundColor: T.surface)
└ Stack
  ├ Positioned.fill  → vertical LinearGradient:
  │     [primary@3%, surface, primary@8%]  topCenter→bottomCenter
  ├ Positioned(top:-100, right:-50) → 300×300 circle, primary@5%
  └ SafeArea > Padding(horizontal 24) > Column
      ├ Spacer(flex: 2)
      ├ FadeTransition(_fadeAnimation) > Column
      │   ├ 160×160 circle avatar
      │   │     image: AssetImage('assets/OIG1.jpg'), BoxFit.cover
      │   │     border: 8px surface; shadow primary@20%, blur 30, offset (0,15)
      │   ├ SizedBox(40)
      │   ├ Text(welcomeTitle)     30px, bold, letterSpacing -0.5, centered
      │   ├ SizedBox(16)
      │   └ Text(welcomeSubtitle)  16px, textSecondary, height 1.6, centered
      ├ Spacer(flex: 3)
      └ SlideTransition(_slideAnimation) > FadeTransition > Column(stretch)
          ├ PrimaryGradientButton(text: signIn,
          │      trailingIcon: IconsaxPlusLinear.arrow_left_2)      height 58
          ├ SizedBox(16)
          ├ SizedBox(height: 58) > OutlinedButton(createNewAccount)
          │      side: primary@50%, width 1.5; radius 18; text 17px bold
          └ SizedBox(40)
```

No step indicator.

**Form fields:** none.

**Client-side validation:** none.

**Backend calls:** none. Purely navigational.

**State handling:**
- `SingleTickerProviderStateMixin`; one `AnimationController`, `duration: 1200 ms`, `.forward()` in
  `initState`, disposed in `dispose`.
- `_fadeAnimation`: `Tween(0.0 → 1.0)` on `Interval(0.0, 0.6, curve: Curves.easeIn)`.
- `_slideAnimation`: `Tween(Offset(0, 0.3) → Offset.zero)` on
  `Interval(0.4, 1.0, curve: Curves.easeOutCubic)`.
- No loading state, no disable conditions, no timers.

**Error display:** none.

**Localization keys used:** `welcomeTitle`, `welcomeSubtitle`, `signIn`, `createNewAccount`.

**Notes for reimplementation:**
- The hero image is `assets/OIG1.jpg` — a raw generator filename sitting at the root of `assets/`,
  not under `assets/illustrations/`. Rename when rebuilding.
- The sign-in button's trailing icon is `arrow_left_2` — a hard-coded left arrow that does **not**
  flip with locale, unlike `AuthPrimaryButton` (S-05/S-07) which does. Inconsistent with the rest of
  the flow.
- No language switcher here even though S-02 has one — a user who cannot read the default locale has
  no way to change it before reaching S-02.

---

## S-02: AccountTypeSelectionScreen  (`screens/auth/account_type_selection_screen.dart`)

**Purpose:** Registration entry point — the user picks passenger or driver, which decides which
signup wizard runs.

**Reached from:**
- S-01 "Create a new account" → `pushNamed('/account-type-selection')`.
- S-05 SignUp footer? No — S-05's footer goes to sign-in.
- S-06 SignIn "Create a new account" → `pushReplacementNamed('/account-type-selection')`
  (`sign_in_screen.dart:353-356`).

**Navigates to:**
- Passenger card tap → `Navigator.pushReplacementNamed(context, RouteNames.signUp,
  arguments: {'accountType': AppConstants.rolePassenger})` (lines 126-132) → S-05.
- Driver card tap → `Navigator.pushReplacementNamed(context, RouteNames.driverSignUp)` (lines
  161-164) → **driver flow branch point** (out of scope). Note: **no arguments** are passed to the
  driver route.
- "Sign in" link → `Navigator.pushReplacementNamed(context, RouteNames.signIn)` (line 336) → S-06.

All three are `pushReplacementNamed`, so this screen is removed from the stack on every exit. Coming
from S-01 that leaves `/welcome` underneath; the target screen's back button therefore returns to
S-01, skipping S-02.

**Route name / constructor args:** `/account-type-selection`;
`const AccountTypeSelectionScreen({super.key})` — no parameters.

**UI structure:**
```
Scaffold(backgroundColor: T.surface)
└ Stack
  ├ Positioned(top:0,left:0,right:0) > Opacity(0.35)
  │     Image.asset('assets/illustrations/auth/auth_account_type_cityscape.webp',
  │                 height: 320, fit: BoxFit.cover)
  └ SafeArea > FadeTransition > SingleChildScrollView(padding 16,8,16,24) > Column(stretch)
      ├ _buildTopBar()  → Row(spaceBetween)
      │     ├ Image.asset('assets/illustrations/auth/auth_visionway_logo.webp', height 44)
      │     └ AuthLanguageSwitcher()
      ├ SizedBox(24)
      ├ _buildHeader() → Column
      │     ├ 72×72 circle (primary@12%) containing 52×52 circle (primary)
      │     │     with Icon(IconsaxPlusBold.profile_circle, 28, onPrimary)
      │     ├ SizedBox(14)
      │     ├ Text(accountTypeTitle)     26px w800, centered
      │     ├ SizedBox(6)
      │     ├ Text(accountTypeSubtitle)  14px onSurfaceVariant, centered
      │     ├ SizedBox(10)
      │     └ Row(center): dash(primary) 26×3 r2, gap 4, dash(_driverAccent) 26×3 r2
      ├ SizedBox(24)
      ├ SlideTransition > IntrinsicHeight > Row(stretch)
      │     ├ Expanded > _AccountTypeCard  PASSENGER  (accent: T.primary)
      │     ├ SizedBox(12)
      │     └ Expanded > _AccountTypeCard  DRIVER     (accent: _driverAccent)
      ├ SizedBox(16)
      ├ _buildSafetyBanner()
      ├ SizedBox(12)
      └ _buildSignInRow()
```

`_AccountTypeCard` internals (lines 378-551):
```
Semantics(button, label: '$title - $tagline')
└ InkWell(onTap, radius 20)
  └ Container  surface, radius 20, border accent@25%,
               shadow accent@12% blur 18 offset (0,6)
    └ Padding(12,12,12,14) > Column(stretch)
        ├ _buildHero: Stack(clip: none, bottomCenter)
        │     ├ ClipRRect(r14) > AspectRatio(1.05) > Image.asset(heroAsset, cover)
        │     └ Positioned(bottom: -20) → 42×42 circle, fill accent,
        │           3px surface border, Icon(badgeIcon, 20, white)
        ├ SizedBox(26)            ← clears the -20 badge overhang
        ├ Text(title)    18px w800 centered
        ├ SizedBox(4)
        ├ Text(tagline)  11px height 1.35 onSurfaceVariant centered
        ├ SizedBox(14)
        ├ for each of 3 features: _buildFeatureRow + SizedBox(10)
        │     Row: 30×30 circle accent@10% + Icon(feature.icon, 15, accent),
        │          gap 8, Column[ title 12px w700 maxLines 1 ellipsis,
        │                         body 10px height 1.3 maxLines 2 ellipsis ]
        ├ Spacer()
        └ Center > 38×38 circle accent@10%, border accent@40%,
              Icon(chevron_left_rounded if RTL else chevron_right_rounded, accent)
```

Card contents:

| | Passenger card | Driver card |
|---|---|---|
| hero asset | `assets/illustrations/auth/auth_passenger_card_hero.webp` | `assets/illustrations/auth/auth_driver_card_hero.webp` |
| badge icon | `IconsaxPlusBold.profile_circle` | `IconsaxPlusBold.car` |
| accent | `T.primary(context)` (theme teal) | `_driverAccent = Color(0xFF7C3AED)` (violet) |
| title / tagline | `accountTypePassenger` / `accountTypePassengerTagline` | `accountTypeDriver` / `accountTypeDriverTagline` |
| feature 1 | `IconsaxPlusLinear.car` + `…FeatureDirectTitle/Body` | `IconsaxPlusLinear.driving` + `…FeatureTripsTitle/Body` |
| feature 2 | `IconsaxPlusLinear.profile_2user` + `…FeatureSharedTitle/Body` | `IconsaxPlusLinear.profile_2user` + `…FeatureBookingsTitle/Body` |
| feature 3 | `IconsaxPlusLinear.card` + `…FeaturePaymentTitle/Body` | `IconsaxPlusLinear.wallet_money` + `…FeatureIncomeTitle/Body` |

`_buildSafetyBanner()` (lines 263-315): Container padding (16,14), `surfaceVariant@50%`, radius 16,
border `T.outline`; Row = 40×40 rounded-12 tile `primary@12%` with
`Icon(IconsaxPlusBold.shield_tick, 22, primary)`, gap 12, Column of
`accountTypeSafetyTitle` (14px w700) over `accountTypeSafetyBody` (12px height 1.4).

`_buildSignInRow()` (lines 317-367): Container `surfaceVariant@40%`, radius 16, vertical padding 6;
centered Row of `Text(alreadyHaveAccount)` (13px) + `TextButton` containing
`Text(signIn)` (13px w700 primary) and a directional arrow
(`Icons.arrow_back_rounded` in RTL, `Icons.arrow_forward_rounded` in LTR), size 16.

No step indicator (the wizard chrome starts at S-05 step 1/3).

**Form fields:** none.

**Client-side validation:** none.

**Backend calls:** none.

**State handling:**
- `SingleTickerProviderStateMixin`; `AnimationController(duration: 900 ms)`, `.forward()` in
  `initState`.
- `_fadeAnimation`: `Tween(0.0 → 1.0)`, `Curves.easeInOut` (wraps the whole `SafeArea`).
- `_slideAnimation`: `Tween(Offset(0, 0.15) → Offset.zero)`, `Curves.easeOutCubic` (wraps the card
  row only).
- No loading, no disabled states, no timers.

**Error display:** none.

**Localization keys used:** `accountTypePassenger`, `accountTypePassengerTagline`,
`accountTypePassengerFeatureDirectTitle`, `accountTypePassengerFeatureDirectBody`,
`accountTypePassengerFeatureSharedTitle`, `accountTypePassengerFeatureSharedBody`,
`accountTypePassengerFeaturePaymentTitle`, `accountTypePassengerFeaturePaymentBody`,
`accountTypeDriver`, `accountTypeDriverTagline`, `accountTypeDriverFeatureTripsTitle`,
`accountTypeDriverFeatureTripsBody`, `accountTypeDriverFeatureBookingsTitle`,
`accountTypeDriverFeatureBookingsBody`, `accountTypeDriverFeatureIncomeTitle`,
`accountTypeDriverFeatureIncomeBody`, `accountTypeTitle`, `accountTypeSubtitle`,
`accountTypeSafetyTitle`, `accountTypeSafetyBody`, `alreadyHaveAccount`, `signIn`,
plus `language` via `AuthLanguageSwitcher`.

**Notes for reimplementation:**
- Design reference is recorded in the file's doc comment:
  `docs/superpowers/assets/2026-07-28-auth-registration/account-type-selection.png` (lines 12-14).
- `_driverAccent` is a **hard-coded literal** `Color(0xFF7C3AED)`, not a theme token — it will not
  adapt to dark mode. `T.primary(context)` on the passenger side does.
- Assets are `.webp`. The repo previously shipped `.png` versions of the same names (they appear as
  deleted in git status) — reference the `.webp` paths.
- The badge circle uses `Positioned(bottom: -20)` inside a `Stack(clipBehavior: Clip.none)`; the
  following `SizedBox(height: 26)` is what prevents it overlapping the title.
- The passenger card and the driver card call different route contracts: the passenger route
  receives `{'accountType': 'passenger'}`, the driver route receives nothing.
- The two cards live in an `IntrinsicHeight > Row`, so both cards are as tall as the taller one and
  the `Spacer()` before the chevron does the equalising.

---

## S-03: PhoneAuthScreen  (`screens/auth/phone_auth_screen.dart`)

**Purpose:** Collect a phone number and request an SMS OTP. Serves two modes: verifying/linking a
phone for an already-authenticated user, and (nominally) phone-first sign-in.

**Reached from:**
- `AuthWrapper` (`main.dart:453`) — authenticated but `!isPhoneVerified` → rendered directly as
  `PhoneAuthScreen(isLinkPhone: true)` (not a named route).
- S-06 SignIn (`sign_in_screen.dart:87-94`) — after a successful password sign-in where
  `isPhoneVerified == false`: `pushNamedAndRemoveUntil('/phone-auth', (r)=>false,
  arguments: {'isLinkPhone': true})`.
- `screens/main/tabs/profile_tab.dart:178-183` — "Confirm" button:
  `pushNamed('/phone-auth', arguments: {'isLinkPhone': true})`, then `.then((_) =>
  authProvider.loadUserProfile())`.
- `screens/settings/account_security_screen.dart:53` — "Link phone" button:
  `Navigator.pushNamed(context, RouteNames.phoneAuth)` with **no arguments** →
  `isLinkPhone: false`. See notes.

**Navigates to:** on `sendOTP` success only:
```dart
Navigator.pushReplacementNamed(context, RouteNames.otpVerification, arguments: otpArgs);
```
where `otpArgs` (lines 58-73) is:
```dart
{
  'phoneNumber' : formattedPhone,       // E.164
  'isSignIn'    : !widget.isLinkPhone,
  'isLinkPhone' : widget.isLinkPhone,
  // …plus, only if this screen itself received route arguments:
  'afterVerifyRoute': routeArgs['afterVerifyRoute'],
  'firstName'       : routeArgs['firstName'],
  'lastName'        : routeArgs['lastName'],
  'email'           : routeArgs['email'],
  'gender'          : routeArgs['gender'],
}
```
On failure it stays put and shows an error.

**Route name / constructor args:**
`/phone-auth`, built by `onGenerateRoute` (`main.dart:217-225`).
```dart
const PhoneAuthScreen({super.key, this.isLinkPhone = false});
final bool isLinkPhone;   // "user already logged in; OTP will call linkPhone"
```
Route arguments (optional `Map<String, dynamic>`): `isLinkPhone` (bool, read by the router),
and pass-through `afterVerifyRoute`, `firstName`, `lastName`, `email`, `gender`.

**UI structure:**
```
Scaffold
├ AppBar(title: isLinkPhone ? linkPhoneTitle : signIn)
└ SafeArea > SingleChildScrollView(padding 24) > Form(_formKey)
  └ ConstrainedBox(minHeight: screenHeight - topPadding - bottomPadding - 48)
    └ Column(mainAxisAlignment: center, crossAxisAlignment: stretch)
        ├ Icon(Icons.phone_android, size 80, color: T.primary)
        ├ SizedBox(32)
        ├ Text(headline)   24px bold, centered
        │     isLinkPhone ? enterPhoneToConfirm : enterYourPhone
        ├ SizedBox(8)
        ├ Text(subtitle)   16px onSurfaceVariant, centered
        │     isLinkPhone ? linkPhoneSubtitle
        │                 : (AppConstants.skipOTP ? devModeDirectLogin : otpWillBeSentViaSms)
        ├ SizedBox(32)
        ├ Semantics(label: phoneNumber, textField: true)
        │   └ TextFormField  (see form table)
        ├ SizedBox(24)
        └ Semantics(button) > ElevatedButton(verticalPadding 16)
              label: skipOTP ? enterAction : sendOTP
              loading: 20×20 CircularProgressIndicator(strokeWidth 2, white)
```

No step indicator. Uses a plain `AppBar` (the only auth screen with a stock `AppBar` title-only bar).

**Form fields:**

| field | widget | keyboard type | validation rule | error message key |
|---|---|---|---|---|
| phone | `TextFormField` with `labelText: phoneNumber`, `hintText: '+201234567890'`, `prefixIcon: Icon(Icons.phone)` | `TextInputType.phone` | `value == null \|\| value.isEmpty` | `phoneNumberRequired` |
| | | | after trimming and prefixing with `AppConstants.defaultCountryCode` (`'+20'`) when the value does not start with `+`: `formattedPhone.length < 10` | `invalidPhoneNumber` |

**Client-side validation** (`_sendOTP`, lines 32-90):
1. `_formKey.currentState!.validate()` must pass, else return silently (inline field errors show).
   - Empty → "Please enter phone number" / "يرجى إدخال رقم الهاتف".
   - Composed length < 10 → "Invalid phone number" / "رقم الهاتف غير صحيح".
2. No other client-side rule. Note the validator uses `'+20'` regardless of what the user typed —
   there is **no country picker on this screen**.

Phone normalisation performed before the call (lines 44-51):
```dart
String cleanedPhone = phoneNumber;
if (!phoneNumber.startsWith('+') && phoneNumber.startsWith('0')) {
  cleanedPhone = phoneNumber.substring(1);        // strip a single leading 0
}
final formattedPhone = cleanedPhone.startsWith('+')
    ? cleanedPhone
    : '${AppConstants.defaultCountryCode}$cleanedPhone';   // '+20' + rest
```

**Backend calls:**
- `AuthProvider.sendOTP(formattedPhone)` — `Future<void> sendOTP(String phoneNumber)`
  (`providers/auth_provider.dart:122`).
  - **Success:** `pushReplacementNamed('/otp-verification', arguments: otpArgs)` (see above).
  - **Any throw:** `ErrorSurface.showFailure(context, ApiClient.mapError(e))`. No error is
    distinguished by type here — all failures are funnelled through the same surface.
- `finally`: `if (mounted) setState(() => _isLoading = false)`.

**State handling:**
- `_isLoading` (bool) — set true at the start of `_sendOTP`, reset in `finally`.
- Button `onPressed: _isLoading ? null : _sendOTP` — disabled while loading; child swaps to a
  20×20 `CircularProgressIndicator(strokeWidth: 2, white)`.
- The `Semantics.label` on the button also changes to `loading` ("Loading…") while busy.
- No timers, no auto-focus (the phone field is not focused on entry), no auto-submit.
- `_phoneController` disposed in `dispose`.

**Error display:** `ErrorSurface.showFailure` (`core/ui/error_surface.dart:10-39`) with a
`Failure` from `ApiClient.mapError`. Behaviour depends on `failure.severity`:
- `info` / `warning` → floating `SnackBar` (warning uses `colorScheme.error` background, info uses
  `colorScheme.primary`), optional `SnackBarAction` from `failure.nextAction`.
- `error` → `AlertDialog` titled with the localized `'error'` string, body = resolved message, an OK
  button plus an optional action button.
Copy comes from `ErrorLocalizations.resolveFailure` keyed by `failure.messageKey`, unless the
failure carries a `displayMessage`.

**Localization keys used:** `linkPhoneTitle`, `signIn`, `enterPhoneToConfirm`, `enterYourPhone`,
`linkPhoneSubtitle`, `devModeDirectLogin`, `otpWillBeSentViaSms`, `phoneNumber`,
`phoneNumberRequired`, `invalidPhoneNumber`, `loading`, `enterAction`, `sendOTP`.

**Notes for reimplementation:**
- **Dead branches:** `AppConstants.skipOTP` is a `const bool = false`, so `devModeDirectLogin` and
  `enterAction` can never render. They are compile-time-eliminated.
- **Bug to fix:** `account_security_screen.dart:53` pushes this route with no arguments, so
  `isLinkPhone` becomes `false`. The OTP screen then takes the `verifyOTP` (registration/sign-in)
  path instead of `linkPhone`, for a user who is already signed in. Every other caller passes
  `{'isLinkPhone': true}`.
- **Country code:** hard-codes `+20` (Egypt) while the rest of the flow defaults to `+962` (Jordan).
  A Jordanian number typed as `0791234567` becomes `+20791234567`.
- The `length < 10` check counts the `'+20'` prefix, so it effectively requires ≥ 7 typed digits —
  much weaker than the `^0?\d{7,15}$` used by `AuthPhoneField`.
- Line 74 carries an Arabic comment (`// الانتقال لصفحة إدخال OTP بعد إرسال رمز التحقق بنجاح`);
  the rest of the file is English.
- Lines 53-54 contain a stale comment describing dev-mode behaviour that no longer applies.

---

## S-04: OTPVerificationScreen  (`screens/auth/otp_verification_screen.dart`)

**Purpose:** Enter the 6-digit SMS code. This is the fan-out hub of the whole auth flow — the same
screen serves passenger registration step 2/3, driver phone verification, and phone linking, chosen
by route arguments.

**Reached from:**
- S-05 SignUp (`sign_up_screen.dart:91-107`) — passenger registration, `pushReplacementNamed`.
- S-03 PhoneAuth (`phone_auth_screen.dart:75-79`) — link/confirm phone, `pushReplacementNamed`.
- `driver_sign_up_screen.dart:103-121` — driver registration, `pushReplacementNamed` (driver flow).

**Navigates to** (all inside `_verifyOTP`, lines 98-219, in this exact order):

1. `args['isLinkPhone'] == true` → `AuthProvider.linkPhone(...)`, then
   - `args['afterVerifyRoute'] != null` → `pushReplacementNamed(afterVerifyRoute)` (no arguments
     forwarded), else
   - `Navigator.pop(context)`.
2. `args['role'] == AppConstants.roleDriver && args['isDriverCompleteProfile'] != true` →
   `AuthProvider.verifyDriverPhone(...)`, then
   `pushReplacementNamed('/driver-complete-profile', arguments: {firstName, lastName, email, gender})`.
3. Otherwise → `AuthProvider.verifyOTP(...)`, then
   - `args['isDriverCompleteProfile'] == true` → `_completeDriverProfileAfterOtp(...)` — **dead, see
     notes**;
   - `args['afterVerifyRoute'] != null` → `pushReplacementNamed(afterVerifyRoute, arguments: {...})`
     (lines 185-201, argument map below);
   - else → `pushReplacementNamed('/home')`.

The forwarded map for the `afterVerifyRoute` case:
```dart
{
  'name'       : args?['name'],
  'email'      : args?['email'],
  'gender'     : args?['gender'],
  'role'       : args?['role'] ?? AppConstants.rolePassenger,
  'phoneNumber': widget.phoneNumber,
  if (totalSteps != null) 'authStep'      : totalSteps,   // note: set to totalSteps, not +1
  if (totalSteps != null) 'authTotalSteps': totalSteps,
}
```

**Route name / constructor args:** `/otp-verification`, built by `onGenerateRoute`
(`main.dart:226-234`).
```dart
const OTPVerificationScreen({super.key, required this.phoneNumber});
final String phoneNumber;   // E.164, comes from args['phoneNumber']
```
The router casts `settings.arguments as Map<String, dynamic>` **non-nullably** — pushing this route
with `null` arguments throws.

Route argument contract read by this screen:

| key | type | read at | meaning |
|---|---|---|---|
| `phoneNumber` | `String` | router, line 231 | E.164; becomes the constructor param |
| `isLinkPhone` | `bool` | 110 | route to `linkPhone` instead of `verifyOTP` |
| `role` | `String?` | 111, 176, 195 | `'driver'` selects the driver branch |
| `isDriverCompleteProfile` | `bool` | 112, 134, 181 | **never set by any caller — dead** |
| `afterVerifyRoute` | `String?` | 121, 185 | destination after success |
| `firstName`, `lastName` | `String?` | 138-139, 149-150 | driver branch + name composition |
| `password` | `String?` | 140, 177 | forwarded to verify calls |
| `email` | `String?` | 141, 151 | forwarded |
| `gender` | `String?` | 142, 152, 175 | forwarded |
| `name` | `String?` | 165 | preferred over `firstName + lastName` |
| `authStep` | `int?` | 318 | current step for the indicator; **defaults to 2** |
| `authTotalSteps` | `int?` | 317 | when null the step indicator is hidden entirely |
| `carImage`, `profileImage`, `vehicleType`, `plateNumber`, `model`, `seats`, `driverLicenseImage`, `vehicleLicenseImage` | various | 229-247 | only read by the dead `_completeDriverProfileAfterOtp` |
| `isRegistration`, `accountType`, `isSignIn` | bool/String | — | written by callers, **never read here** |

**UI structure:**
```
Scaffold(backgroundColor: T.surface)
└ Stack
  ├ Positioned(top: -w*0.4, right: -w*0.2)
  │     w*0.8 square circle, RadialGradient(radius .5)
  │     [primary@20%, transparent]
  ├ Positioned(bottom: -w*0.3, left: -w*0.2)
  │     w*0.6 square circle, RadialGradient(radius .5)
  │     [AppColors.teal700@15%, transparent]
  └ SafeArea > Column
      ├ AppBar(title: otpVerification, 20px bold, centerTitle,
      │         transparent, elevation 0, iconTheme onSurface)
      ├ if (args['authTotalSteps'] != null)              ← STEP INDICATOR
      │   Padding(24,0,24,8) > Row
      │     ├ Expanded > AuthStepIndicator(currentStep: args['authStep'] ?? 2,
      │     │                              totalSteps: args['authTotalSteps'])
      │     ├ SizedBox(12)
      │     └ Text(authStepOf(currentStep, totalSteps))  12px w600 primary
      └ Expanded > SingleChildScrollView(BouncingScrollPhysics, horizontal 24) > Column
          ├ SizedBox(32)
          ├ Container padding 24, surface, circle, shadow primary@15% blur 24 offset (0,8)
          │     Icon(Icons.mark_email_read_rounded, size 64, primary)
          ├ SizedBox(40)
          ├ Text(enterOTP)  28px w800, letterSpacing 0.5, centered
          ├ SizedBox(12)
          ├ RichText(centered, 15px w500 height 1.5 onSurfaceVariant):
          │     TextSpan(otpSentToPhone)   ← ends with \n
          │     TextSpan(_maskPhone(phoneNumber))  16px bold primary
          ├ SizedBox(48)
          ├ Row(textDirection: LTR, spaceBetween)   ← 6 OTP BOXES
          │     each: Container width = (screenW - 48 - 5*8)/6, height 64,
          │           surface, radius 16, 2px border
          │             (primary if that box has text, else transparent),
          │           shadow black@4% blur 16 offset (0,4)
          │       └ Center > Semantics(otpDigitLabel(index+1), textField)
          │           > TextField(controller[i], focusNode[i], center, number kb,
          │                       maxLength 1, 24px bold,
          │                       counterText '', border none, contentPadding zero,
          │                       inputFormatters: [FilteringTextInputFormatter.digitsOnly])
          ├ SizedBox(48)
          ├ Container height 56, radius 16, horizontal LinearGradient
          │     [primary, primary@70%], shadow primary@30% blur 12 offset (0,6)
          │   └ ElevatedButton(transparent bg/shadow) — label verifyButton
          │       18px bold white letterSpacing 0.5
          │       loading: 24×24 CircularProgressIndicator(strokeWidth 2.5, white)
          ├ SizedBox(24)
          └ Semantics(button, enabled: _canResend && !_isLoading)
              > GestureDetector > AnimatedContainer(300 ms)
                  padding (8,16), radius 20,
                  bg: _canResend ? primary@10% : transparent
                  Text: _canResend ? resendOTP : resendOTPIn(_resendTimer)
                        color primary (bold) when enabled, else outlineVariant (w500)
          └ SizedBox(32)
```

Step indicator: rendered **only** when `authTotalSteps` is present. For the passenger wizard S-05
passes `authStep: 2, authTotalSteps: 3` → "Step 2 of 3" / "خطوة 2 من 3". The driver signup does not
pass step metadata, so the indicator is hidden on the driver path.

**Form fields:**

| field | widget | keyboard type | validation rule | error message key |
|---|---|---|---|---|
| OTP digit ×6 | `TextField` (**not** `TextFormField` — no `Form`) | `TextInputType.number` | `maxLength: 1`, `FilteringTextInputFormatter.digitsOnly` | none — no validator |

**Client-side validation:** the only guard is in `_verifyOTP` (lines 99-102):
```dart
final otpCode = _getOTPCode();               // concatenation of all 6 controllers
if (otpCode.length != AppConstants.otpLength) return;   // silent no-op
```
There is no error message for a short code; the Verify button is simply disabled instead.

**Backend calls:**

| branch | call | on success | on error |
|---|---|---|---|
| `isLinkPhone` | `AuthProvider.linkPhone(phoneNumber: widget.phoneNumber, smsCode: otpCode)` (`auth_provider.dart:437`) | `pushReplacementNamed(afterVerifyRoute)` or `Navigator.pop()` | shared catch (below) |
| driver | `AuthProvider.verifyDriverPhone(phoneNumber, code: otpCode, firstName, lastName, password, email, gender)` (`auth_provider.dart:190`) — args trimmed; `firstName`/`lastName`/`password` fall back to `''` | `pushReplacementNamed('/driver-complete-profile', {...})` | shared catch |
| default | `AuthProvider.verifyOTP(phoneNumber, smsCode: otpCode, name: composedName, gender, role, password)` (`auth_provider.dart:135`) — `name` is `null` when the composed string is empty | route per rules above | shared catch |
| resend | `AuthProvider.sendOTP(widget.phoneNumber)` | success snackbar + timer restart + fields cleared + focus box 0 | shared catch |

`composedName` (lines 162-169): `args['name']?.trim()`, else `[firstName, lastName]` filtered for
non-null/non-empty, joined with `' '`, trimmed. Empty → `null`.

Shared catch (lines 206-213):
```dart
ErrorSurface.showFailure(context, ApiClient.mapError(e));
for (var controller in _controllers) controller.clear();
_focusNodes[0].requestFocus();
```
i.e. **every** verify failure wipes all six boxes and returns focus to the first. `finally` clears
`_isLoading`.

**State handling:**
- `_controllers`: `List.generate(AppConstants.otpLength /* 6 */, (_) => TextEditingController())`.
- `_focusNodes`: 6 `FocusNode`s. All disposed in `dispose`, along with `_timer?.cancel()`.
- **Auto-focus:** `WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus())`
  in `initState` (lines 43-45).
- **Auto-advance / auto-back** (`_onOTPChanged`, lines 78-92):
  - a digit typed and `index < 5` → focus `index + 1`;
  - a digit typed in the last box → `unfocus()` then `_verifyOTP()` — **auto-submit**;
  - the box becomes empty and `index > 0` → focus `index - 1` (backspace walk-back).
- Every `onChanged` also calls `setState(() {})` purely to repaint the active-box border
  (line 526-529 comment: "For rebuilding border color").
- **Resend timer:** `_resendTimer` starts at `AppConstants.otpResendTimeout` = **60 seconds**.
  `_startResendTimer` sets `_canResend = false`, resets `_resendTimer = 60`, cancels any prior timer
  and starts a `Timer.periodic(Duration(seconds: 1))` that decrements to 0, then sets
  `_canResend = true` and cancels itself. Started once in `initState` and again after each successful
  resend.
- Resend tap is gated by `_canResend && !_isLoading`; `_resendOTP` also early-returns
  `if (!_canResend) return;` and immediately sets `_canResend = false`.
- **Verify button disable condition** (lines 564-569):
  `onPressed: _isLoading ? null : (_getOTPCode().length == 6 ? _verifyOTP : null)` — disabled while
  loading *and* while fewer than 6 digits are entered.
- `_isLoading` gates both the button spinner and the resend tap.

**Error display:**
- Verify/resend failures → `ErrorSurface.showFailure(context, ApiClient.mapError(e))` (dialog for
  `error` severity, snackbar for `info`/`warning`), plus the field reset described above.
- Resend success → `ScaffoldMessenger.showSnackBar(SnackBar(content: Text(otpResent),
  backgroundColor: AppColors.success))`.
- (dead path) driver-profile success → snackbar with `driverProfileSubmitted`,
  `backgroundColor: AppColors.success`.

**Localization keys used:** `otpVerification`, `authStepOf`, `enterOTP`, `otpSentToPhone`,
`otpDigitLabel`, `verifyButton`, `resendOTP`, `resendOTPIn`, `otpResent`, `driverProfileSubmitted`.

**Notes for reimplementation:**
- **Dead code:** `isDriverCompleteProfile` is read in three places (lines 112, 134, 181) but written
  by nobody — a repo-wide grep finds only these reads. Consequently
  `_completeDriverProfileAfterOtp` (lines 221-264) is unreachable, as is the
  `driverProfileSubmitted` snackbar and the `pushNamedAndRemoveUntil('/driver-pending-approval')`
  inside it. That method also holds the only reads of `carImage`, `profileImage`, `vehicleType`,
  `plateNumber`, `model`, `seats`, `driverLicenseImage`, `vehicleLicenseImage`, and the only
  untranslated exception strings in the file (`'Driver data is incomplete'`,
  `'Car photo is missing'`).
- **Dead arguments:** `isRegistration` (set by S-05 and driver signup), `accountType` (set by S-05),
  `isSignIn` (set by S-03) are never read.
- **Step numbering quirk:** when forwarding to `afterVerifyRoute` the screen sets
  `'authStep': totalSteps` (line 198), i.e. the *final* step number rather than `currentStep + 1`.
  It works for the 3-step passenger wizard only because step 3 is the last one.
- **RTL:** the OTP `Row` is explicitly `textDirection: TextDirection.ltr` (line 471) so digits stay
  in entry order under Arabic. Any rebuild must keep this.
- `_maskPhone` (lines 304-309): returns the input unchanged when `length <= 6`; otherwise
  `first 3 chars + '*****' + last 3 chars`. The `*****` run is a fixed 5 characters and does **not**
  scale with the number's length. For `+962791234567` this yields `+96*****567`.
- The OTP boxes are `TextField`s inside no `Form`, so `Form.validate()` cannot reach them.
- Box width is computed as `(screenWidth - 48 - (6-1)*8) / 6` — a hard-coded assumption of 24px page
  padding on each side and 8px gaps, though the `Row` actually uses
  `MainAxisAlignment.spaceBetween` rather than fixed gaps.
- Header uses an `AppBar` placed *inside* a `Column` inside `SafeArea` (not `Scaffold.appBar`), so
  the decorative background circles show through it.

---

## S-05: SignUpScreen  (`screens/auth/sign_up_screen.dart`)

**Purpose:** Passenger registration step **1 of 3** — name, phone, password, gender. Submitting sends
an OTP and hands the collected fields to the OTP screen.

**Reached from:** S-02 AccountTypeSelection, passenger card →
`pushReplacementNamed('/sign-up', arguments: {'accountType': 'passenger'})`.

**Navigates to:**
- On `sendOTP` success → `pushReplacementNamed('/otp-verification', arguments: {...})` (lines
  91-107, map below) → S-04.
- Back chevron (`_buildTopBar`, line 263) → `Navigator.pop(context)`. Since S-02 replaced itself,
  this pops to whatever was under it (S-01 Welcome, when the user came from there).
- "Sign in" link → `pushReplacementNamed('/sign-in')` → S-06.

Arguments handed to the OTP screen:
```dart
{
  'phoneNumber'     : phoneNumber,                 // E.164 from AuthPhoneField.composeE164
  'isRegistration'  : true,                        // never read downstream
  'role'            : role,                        // args['accountType'] ?? 'passenger'
  'accountType'     : role,                        // never read downstream
  'name'            : _nameController.text.trim(),
  'gender'          : _selectedGender,             // 'male' | 'female'
  'password'        : _passwordController.text,    // NOT trimmed
  'afterVerifyRoute': RouteNames.profileSetup,     // '/profile-setup'
  'authStep'        : 2,
  'authTotalSteps'  : 3,
}
```

**Route name / constructor args:** `/sign-up`; `const SignUpScreen({super.key})` — no parameters.
Route arguments (optional `Map<String, dynamic>`): `accountType` (`String`, default
`AppConstants.rolePassenger` when absent, line 79).

**UI structure:**
```
Scaffold(backgroundColor: T.surface)
└ SafeArea > FadeTransition > SingleChildScrollView > Form(_formKey) > Column(stretch)
    ├ _buildTopBar()  Padding(8,4,16,0) > Row
    │     ├ IconButton(chevron_right_rounded if RTL else chevron_left_rounded) → pop
    │     ├ Expanded > Padding(horizontal 12) > AuthStepIndicator(currentStep: 1, totalSteps: 3)
    │     └ Text(authStepOf(1, 3))  12px w600 primary          ← "Step 1 of 3"
    ├ _buildHero()  Stack(center)
    │     ├ Opacity(0.9) > Image.asset(
    │     │      'assets/illustrations/auth/auth_passenger_signup_hero.webp',
    │     │      height 190, width ∞, BoxFit.cover)
    │     └ Column(min)
    │         ├ Text(passengerSignupTitle)     27px w800 centered
    │         ├ SizedBox(6)
    │         └ Padding(horizontal 32) > Text(passengerSignupSubtitle) 13px centered
    └ Padding(20,20,20,24) > Column(stretch)
        ├ AuthTextField  fullName
        ├ SizedBox(14)
        ├ AuthPhoneField
        ├ SizedBox(14)
        ├ AuthTextField  password        (+ eye toggle)
        ├ SizedBox(14)
        ├ AuthTextField  confirmPassword (+ eye toggle)
        ├ SizedBox(22)
        ├ Align(centerStart) > Text(genderRequiredLabel) 14px w700
        ├ SizedBox(10)
        ├ GenderSelectCards(value: _selectedGender, onChanged: …)
        ├ SizedBox(26)
        ├ AuthPrimaryButton(label: continueLabel, loading: _isLoading,
        │                   onPressed: _isLoading ? null : _signUp)
        ├ SizedBox(14)
        └ _buildSignInRow()  Row(center): Text(alreadyHaveAccount) 14px
              + TextButton(Text(signIn) 14px w700 primary) → pushReplacementNamed('/sign-in')
```

Step indicator: `AuthStepIndicator(currentStep: 1, totalSteps: 3)` plus the text
`authStepOf(1, 3)` → "Step 1 of 3" / "خطوة 1 من 3".

**Form fields:**

| field | widget | keyboard type | validation rule (exact) | error message key |
|---|---|---|---|---|
| full name | `AuthTextField(label: fullName, hint: fullNameHint, icon: IconsaxPlusLinear.user)` | default (`TextInputType.text`) | `v == null \|\| v.trim().length < 3` | `validNameRequired` |
| phone | `AuthPhoneField(controller, country: _selectedCountry, onCountryChanged)` | `TextInputType.phone`, forced `TextDirection.ltr` | `v == null \|\| v.trim().isEmpty` | `phoneNumberRequired` |
| | | | after `v.replaceAll(RegExp(r'\s+'), '')`: `!RegExp(r'^0?\d{7,15}$').hasMatch(digits)` | `invalidPhoneNumber` |
| password | `AuthTextField(label: password, helper: passwordMinLengthHint, icon: IconsaxPlusLinear.lock, obscureText: _obscurePassword, textDirection: ltr, suffix: eye toggle)` | default | `v == null \|\| v.isEmpty` | `passwordRequired` |
| | | | `!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(v)` | `passwordPolicyError` |
| confirm password | `AuthTextField(label: confirmPassword, helper: confirmPasswordReenterHint, icon: IconsaxPlusLinear.lock, obscureText: _obscureConfirmPassword, textDirection: ltr, suffix: eye toggle)` | default | `v == null \|\| v.isEmpty` | `confirmPasswordRequired` |
| | | | `v != _passwordController.text` | `passwordsDoNotMatch` |
| gender | `GenderSelectCards` (two tap cards, not a form field) | — | checked imperatively in `_signUp` | `selectGenderError` |

Country picker: `CountryData _selectedCountry = Countries.defaultCountry` (Jordan, `+962`),
changed by `AuthPhoneField.onCountryChanged`.

**Client-side validation** (`_signUp`, lines 70-116, in order):
1. `if (!_formKey.currentState!.validate()) return;` — runs all four validators above; errors render
   inline under each field (11px, `T.error(context)`).
2. `if (_selectedGender == null) { _showSnackBar(l10n.selectGenderError, AppColors.error); return; }`
   — gender is **not** part of the `Form`, so it is checked separately and reported as a red
   snackbar: "Please select gender" / "يرجى اختيار الجنس".

Phone composition (`AuthPhoneField.composeE164`, `widgets/auth/auth_phone_field.dart:147-153`):
```dart
var cleaned = raw.trim().replaceAll(RegExp(r'\s+'), '');
if (!cleaned.startsWith('+') && cleaned.startsWith('0')) cleaned = cleaned.substring(1);
return '${country.dialCode}$cleaned';
```

**Backend calls:**
- `context.read<AuthProvider>().sendOTP(phoneNumber)` (line 88).
  - **Success:** navigate to S-04 with the argument map above.
  - **Any throw:** `ErrorSurface.showFailure(context, ApiClient.mapError(e))` — dialog or snackbar
    depending on severity. The user stays on the form with the entered values intact.
- `finally`: `if (mounted) setState(() => _isLoading = false)`.

No account is created here — registration completes on S-04's `verifyOTP` call.

**State handling:**
- `_isLoading` — button `loading:` flag; `AuthPrimaryButton` swaps its content for a 22×22
  `CircularProgressIndicator(strokeWidth: 2.5, onPrimary)` and forces `onPressed: null`
  while loading. `onPressed` is *also* nulled explicitly by the screen.
- `_obscurePassword` / `_obscureConfirmPassword` — independent booleans, toggled by
  `_visibilityToggle` (`IconButton` with `Icons.visibility_outlined` when obscured,
  `Icons.visibility_off_outlined` when visible, size 20, `onSurfaceVariant`).
- `_selectedGender` — `String?`, set to `AppConstants.genderMale`/`genderFemale`.
- `_selectedCountry` — `CountryData`, defaults to Jordan.
- `SingleTickerProviderStateMixin`: `AnimationController(duration: 800 ms)`,
  `_fadeAnimation = Tween(0.0 → 1.0)` with `Curves.easeIn`, forwarded in `initState`.
- No timers, no auto-focus, no auto-submit.
- All four controllers and the animation controller are disposed.

**Error display:**
- Field errors: inline, under each field, 11px `T.error(context)`.
- Missing gender: `ScaffoldMessenger.showSnackBar(SnackBar(content: Text(selectGenderError),
  backgroundColor: AppColors.error))` via `_showSnackBar` (lines 118-123).
- Network/API errors: `ErrorSurface.showFailure` (AlertDialog for `error` severity).

**Localization keys used:** `fullName`, `fullNameHint`, `validNameRequired`, `password`,
`passwordMinLengthHint`, `passwordRequired`, `passwordPolicyError`, `confirmPassword`,
`confirmPasswordReenterHint`, `confirmPasswordRequired`, `passwordsDoNotMatch`,
`genderRequiredLabel`, `continueLabel`, `alreadyHaveAccount`, `signIn`, `passengerSignupTitle`,
`passengerSignupSubtitle`, `selectGenderError`, `authStepOf`, plus `phoneNumber`,
`phoneNumberRequired`, `invalidPhoneNumber` (from `AuthPhoneField`) and `male`/`female` (from
`GenderSelectCards`).

**Notes for reimplementation:**
- The password travels to S-04 through **route arguments in plain memory** and is only sent to the
  server at the `verifyOTP` step. If the user abandons the flow at OTP, nothing is persisted.
- `password` is passed **untrimmed** (`_passwordController.text`), unlike name/phone.
- The password regex `^(?=.*[A-Za-z])(?=.*\d).{8,}$` requires ≥ 8 chars with at least one letter and
  one digit. S-09's reset screen enforces the *same* policy but with three separate checks; S-06's
  sign-in field only checks `length < 6` — three different thresholds in one flow.
- `AuthTextField` renders label, helper and input stacked *inside* one bordered card; the label is a
  plain `Text`, not an `InputDecoration.labelText`, so it never floats or animates.
- The hero image is behind centered text with no scrim — legibility depends entirely on the asset.
- `'accountType'` is duplicated into the OTP args alongside `'role'`, but only `'role'` is read.
- There is no email field on the passenger path, though the OTP screen forwards an `email` key.

---

## S-06: SignInScreen  (`screens/auth/sign_in_screen.dart`)

**Purpose:** Phone + password sign-in, and the entry point into password recovery.

**Reached from:**
- S-01 Welcome "Sign in" → `pushNamed('/sign-in')`.
- S-02 AccountTypeSelection "Sign in" → `pushReplacementNamed('/sign-in')`.
- S-05 SignUp "Sign in" → `pushReplacementNamed('/sign-in')`.
- S-09 ResetPassword on success → `pushNamedAndRemoveUntil('/sign-in', (r)=>false)`.
- `ErrorSurface` `FailureAction.reauthenticate` → `rootNavigator.pushNamedAndRemoveUntil('/sign-in',
  (r)=>false)` (`core/ui/error_surface.dart:149-150`).
- `widgets/common/logout_confirmation_dialog.dart:53`, `screens/settings/change_password_screen.dart:97`,
  `screens/driver/driver_pending_approval_screen.dart:121`.

**Navigates to:**
- Sign-in success (lines 83-95):
  ```dart
  final nextRoute = authProvider.userModel?.isPhoneVerified ?? false
      ? RouteNames.home : RouteNames.phoneAuth;
  Navigator.pushNamedAndRemoveUntil(context, nextRoute, (route) => false,
      arguments: nextRoute == RouteNames.phoneAuth ? {'isLinkPhone': true} : null);
  ```
  → `/home`, or → S-03 with `isLinkPhone: true`. The stack is cleared either way.
- "Forgot password?" success → `pushNamed('/reset-password', arguments: {'phoneNumber': formattedPhone})`
  → S-09 (**not** `/forgot-password`).
- "Create a new account" → `pushReplacementNamed('/account-type-selection')` → S-02.
- AppBar leading `IconsaxPlusLinear.arrow_right_3` → `Navigator.pop(context)`.

**Route name / constructor args:** `/sign-in`; `const SignInScreen({super.key})` — no parameters, no
route arguments read.

**UI structure:**
```
Scaffold(backgroundColor: T.surface, extendBodyBehindAppBar: true)
├ appBar: AppBar(transparent, elevation 0,
│                leading: IconButton(IconsaxPlusLinear.arrow_right_3) → pop)
└ Stack
  ├ Positioned(top: -50, right: -100) → 300×300 circle, primary@5%
  └ SafeArea > FadeTransition > SlideTransition
      > SingleChildScrollView(horizontal 24, vertical 10) > Form(_formKey) > Column(stretch)
        ├ Center > 70×70 circle primary@10% with Icon(IconsaxPlusBold.login, 30, primary)
        ├ SizedBox(16)
        ├ Text(signIn)          26px bold, letterSpacing -0.5, centered
        ├ SizedBox(8)
        ├ Text(signInSubtitle)  14px textSecondary, centered
        ├ SizedBox(24)
        ├ Container(surface, radius 18, 1px border outline@50%) > Row       ← PHONE ROW
        │     ├ CountryCodePicker(selectedCountry, onCountryChanged,
        │     │                   borderColor: transparent, width: 100)
        │     ├ 1×30 divider, outline@30%
        │     └ Expanded > TextFormField (see form table)
        ├ SizedBox(16)
        ├ ModernInputField  password (hint '••••••••', eye toggle)
        ├ Align(centerLeft) > TextButton(forgotPassword) 13px w600 primary
        ├ SizedBox(16)
        ├ PrimaryGradientButton(text: signIn, isLoading: _isLoading,
        │                       onPressed: _isLoading ? null : _handleSignIn)
        ├ SizedBox(24)
        └ Row(center): Text(noAccountQuestion) 14px textSecondary
              + TextButton(Text(createNewAccount) 14px bold primary)
```

No step indicator.

**Form fields:**

| field | widget | keyboard type | validation rule (exact) | error message key |
|---|---|---|---|---|
| phone | `TextFormField` inside the bordered row; `hintText: phoneNumber`, `prefixIcon: Icon(IconsaxPlusLinear.call, 18, primary)`, `border: InputBorder.none`, contentPadding (16,16), style 16px w600 | `TextInputType.phone` | `v == null \|\| v.isEmpty` | `required` ("Required" / "مطلوب") |
| country code | `CountryCodePicker(width: 100, borderColor: transparent)` | — | none | — |
| password | `ModernInputField(label: password, hint: '••••••••', icon: IconsaxPlusLinear.lock, obscureText: _obscurePassword, textDirection: ltr, suffixIcon: eye)` | default | `v == null \|\| v.length < 6` | `passwordTooShort` |

Eye icon: `IconsaxPlusLinear.eye_slash` when obscured, `IconsaxPlusLinear.eye` when visible, size 20,
`onSurfaceVariant`.

**Client-side validation:**
- Sign-in (`_handleSignIn`, line 63): `if (!_formKey.currentState!.validate()) return;`
  - empty phone → "Required" / "مطلوب"
  - password shorter than 6 → "Password is too short" / "كلمة المرور قصيرة"
- Forgot password (`_handleForgotPassword`, lines 107-112): **does not run the form validator at
  all**. It only checks:
  ```dart
  if (phoneNumber.isEmpty) { ErrorSurface.showInfo(context, context.l10n.phoneNumberFirst); return; }
  ```
  → blue floating snackbar "Please enter your phone number first" / "يرجى إدخال رقم الهاتف أولاً".

Phone normalisation, identical in both handlers (lines 71-76 / 117-121):
```dart
String cleanedPhone = phoneNumber;                       // already .trim()'d
if (!phoneNumber.startsWith('+') && phoneNumber.startsWith('0')) {
  cleanedPhone = phoneNumber.substring(1);
}
final formattedPhone = '${_selectedCountry.dialCode}$cleanedPhone';
```
Note this **always** prepends the dial code, even when the typed value already starts with `+`
(unlike `AuthPhoneField.composeE164`, which preserves a leading `+`).

**Backend calls:**
- `AuthProvider.signInWithPhoneAndPassword(phoneNumber: formattedPhone, password: _passwordController.text)`
  (`auth_provider.dart:454`; internally also calls `_registerDeviceToken()`).
  - **Success + `userModel.isPhoneVerified == true`** → `pushNamedAndRemoveUntil('/home', (r)=>false)`.
  - **Success + not verified** → `pushNamedAndRemoveUntil('/phone-auth', (r)=>false,
    arguments: {'isLinkPhone': true})`.
  - **Any throw** (bad credentials, network, banned…) → `ErrorSurface.showFailure(context,
    ApiClient.mapError(e))`. Note: a **403 `ACCOUNT_BANNED`** is intercepted earlier by
    `AuthInterceptor` (`core/api/auth_interceptor.dart:41-61`), which clears tokens and force-routes
    to `/banned` before this catch sees anything actionable.
- `AuthProvider.forgotPassword(formattedPhone)` (`auth_provider.dart:474`).
  - **Success** → `pushNamed('/reset-password', arguments: {'phoneNumber': formattedPhone})`.
  - **Any throw** → `ErrorSurface.showFailure`.
- Both handlers reset `_isLoading` in `finally`.

**State handling:**
- `_isLoading` — shared by both handlers. `PrimaryGradientButton` shows a 24×24
  `CircularProgressIndicator(strokeWidth: 2.5, white)` and disables itself when `isLoading`.
- **Gap:** the "Forgot password?" `TextButton` is **not** gated on `_isLoading`
  (`onPressed: _handleForgotPassword`, line 318, unconditional) — it can be tapped while a sign-in
  request is in flight.
- `_obscurePassword` — bool, toggled by the suffix `IconButton`.
- `_selectedCountry` — `CountryData`, defaults to `Countries.defaultCountry` (Jordan `+962`).
- `SingleTickerProviderStateMixin`: `AnimationController(duration: 1000 ms)`;
  `_fadeAnimation = Tween(0.0 → 1.0)` `Curves.easeIn`;
  `_slideAnimation = Tween(Offset(0, 0.1) → Offset.zero)` `Curves.easeOutCubic`; forwarded in
  `initState`.
- No timers, no auto-focus, no auto-submit (no `onFieldSubmitted`).

**Error display:**
- Field errors inline via `ModernInputField` / `TextFormField` decoration.
- `phoneNumberFirst` → `ErrorSurface.showInfo` = floating snackbar, `Colors.blue` background
  (`error_surface.dart:41-44, 51-60`).
- API failures → `ErrorSurface.showFailure` (AlertDialog for `error`, snackbar for `info`/`warning`).

**Localization keys used:** `signIn`, `signInSubtitle`, `phoneNumber`, `required`, `password`,
`passwordTooShort`, `forgotPassword`, `noAccountQuestion`, `createNewAccount`, `phoneNumberFirst`,
plus `countryCodePickerSemantic` from `CountryCodePicker`.

**Notes for reimplementation:**
- **`/forgot-password` is bypassed.** The "Forgot password?" button calls
  `AuthProvider.forgotPassword` inline and jumps straight to `/reset-password`. S-08
  `ForgotPasswordScreen` is therefore not part of the happy path at all.
- The forgot-password handler skips form validation, so a phone value that fails the field validator
  (e.g. `"x"`) is still normalised and sent to the server.
- `'${_selectedCountry.dialCode}$cleanedPhone'` double-prefixes a value the user typed with a `+`
  (e.g. `+962791…` becomes `+962+962791…`). `AuthPhoneField.composeE164` guards against this;
  this screen does not.
- Password minimum here is 6, but the registration and reset policies require 8 plus a letter and a
  digit. Any account created through S-05 can never have a 6- or 7-character password, so the
  looser check only serves to fail slower.
- `Align(alignment: Alignment.centerLeft)` on the forgot-password button is **not** directional
  (`AlignmentDirectional`), so the link stays on the physical left in Arabic RTL.
- `extendBodyBehindAppBar: true` with a transparent `AppBar` — the decorative circle shows through.

---

## S-07: ProfileSetupScreen  (`screens/auth/profile_setup_screen.dart`)

**Purpose:** Passenger registration step **3 of 3** — the account already exists (created by S-04's
`verifyOTP`); this screen only collects a profile photo and a city, then lands on home.

**Reached from:** S-04 OTPVerification, when `args['afterVerifyRoute'] == RouteNames.profileSetup`
(set by S-05) → `pushReplacementNamed('/profile-setup', arguments: {name, email, gender, role,
phoneNumber, authStep, authTotalSteps})`.

**Navigates to:** on save success → `Navigator.pushNamedAndRemoveUntil(context, RouteNames.home,
(route) => false)` → `HomeScreen`, with the entire auth stack discarded.

There is **no back button and no skip option** — once here, completing the form is the only exit
(short of the OS back gesture, which pops to whatever remains below; S-04 used
`pushReplacementNamed`, so that is S-05's predecessor).

**Route name / constructor args:** `/profile-setup`; `const ProfileSetupScreen({super.key})` — no
parameters. Route arguments (optional `Map<String, dynamic>`): only `authTotalSteps` (`int?`) is read
(line 121, `?? 3`). `name`, `email`, `gender`, `role`, `phoneNumber` and `authStep` are forwarded by
S-04 but **never read here**.

**UI structure:**
```
Scaffold(backgroundColor: T.surface)
└ SafeArea > FadeTransition > SingleChildScrollView(padding 20,8,20,28)
    > Form(_formKey) > Column(stretch)
      ├ Row                                              ← STEP INDICATOR
      │   ├ Expanded > AuthStepIndicator(currentStep: totalSteps, totalSteps: totalSteps)
      │   ├ SizedBox(12)
      │   └ Text(authStepOf(totalSteps, totalSteps))  12px w600 primary   → "Step 3 of 3"
      ├ SizedBox(28)
      ├ Text(passengerProfileStepTitle)     25px w800, centered
      ├ SizedBox(6)
      ├ Text(passengerProfileStepSubtitle)  13px onSurfaceVariant, centered
      ├ SizedBox(28)
      ├ Center > _buildPhotoPicker()
      │     Semantics(button, label: uploadProfilePhoto) > GestureDetector(onTap: _pickPhoto)
      │       Stack(center)
      │         ├ 120×120 circle, surfaceVariant, 2px primary border,
      │         │     DecorationImage(FileImage(_profileImage), cover) when picked,
      │         │     else Icon(IconsaxPlusBold.profile_circle, 60, onSurfaceVariant)
      │         └ PositionedDirectional(bottom 4, end 4) → 34×34 circle primary,
      │               2px surface border, Icon(IconsaxPlusBold.camera, 16, onPrimary)
      ├ SizedBox(8)
      ├ Center > Text(profilePhotoRequired)   13px w600 onSurface     ← "Profile photo *"
      ├ Center > Text(profilePhotoClearHint)  11px onSurfaceVariant
      ├ SizedBox(26)
      ├ AuthTextField  city
      ├ SizedBox(20)
      ├ Center > SecurityNotice()             ← shield + authSecurityNotice
      ├ SizedBox(26)
      └ AuthPrimaryButton(label: complete, loading: _isSaving,
                          onPressed: _isSaving ? null : _save)
```

Step indicator: `AuthStepIndicator(currentStep: totalSteps, totalSteps: totalSteps)` — i.e. always
the final step, rendered as "Step 3 of 3" / "خطوة 3 من 3" with steps 1 and 2 drawn as completed
check circles.

Photo picker source sheet (`_pickPhoto`, lines 64-91): `showModalBottomSheet<ImageSource>` with a
`SafeArea > Column(min)` of two `ListTile`s —
`Icon(IconsaxPlusLinear.gallery) + Text(fromGallery)` → `ImageSource.gallery`, and
`Icon(IconsaxPlusLinear.camera) + Text(fromCamera)` → `ImageSource.camera`.
Dismissing the sheet returns `null` and aborts.

**Form fields:**

| field | widget | keyboard type | validation rule (exact) | error message key |
|---|---|---|---|---|
| profile photo | `GestureDetector` → `showModalBottomSheet` → `StorageService.pickImage(source:)` | — | **none** — no validator despite the `*` in the label | — |
| city | `AuthTextField(label: profileCityLabel, hint: profileCityHint, icon: IconsaxPlusLinear.location)` | default | `v == null \|\| v.trim().isEmpty` | `profileCityRequired` |

**Client-side validation** (`_save`, line 94): `if (!_formKey.currentState!.validate()) return;`
Only the city rule participates. **The photo is optional in practice** even though the label reads
"Profile photo *" and `AuthProvider.completePassengerProfile` takes `File? profileImage`.

**Backend calls:**
- `context.read<AuthProvider>().completePassengerProfile(profileImage: _profileImage, city: _cityController.text.trim())`
  (`auth_provider.dart:400`; the provider uploads the image via
  `_storageService.uploadProfilePicture(imageFile:, userId: _userModel!.id)` only when
  `profileImage != null && _userModel != null`).
  - **Success** → `pushNamedAndRemoveUntil('/home', (route) => false)`.
  - **Any throw** → `ErrorSurface.showFailure(context, ApiClient.mapError(e))`; the user stays on the
    screen with the picked photo and typed city retained.
- `finally`: `if (mounted) setState(() => _isSaving = false)`.
- `StorageService().pickImage(source: source)` — local, not a backend call; returns `null` if the
  user cancels the OS picker.

**State handling:**
- `_isSaving` (bool) — drives `AuthPrimaryButton.loading` (22×22 spinner) and nulls `onPressed`.
- `_profileImage` (`File?`) — set from `File(picked.path)` after a successful pick, guarded by
  `mounted`.
- `SingleTickerProviderStateMixin`: `AnimationController(duration: 700 ms)`,
  `_fadeAnimation = Tween(0.0 → 1.0)` with `Curves.easeOut`, forwarded in `initState`.
- No timers, no auto-focus, no auto-submit.
- `_cityController` and the animation controller are disposed.

**Error display:**
- City error: inline under the field (11px, `T.error(context)`).
- Save failure: `ErrorSurface.showFailure` → AlertDialog for `error` severity.
- No error surface at all for image-pick failures — `StorageService.pickImage` returning `null` is
  treated as a silent cancel.

**Localization keys used:** `passengerProfileStepTitle`, `passengerProfileStepSubtitle`,
`profilePhotoRequired`, `profilePhotoClearHint`, `profileCityLabel`, `profileCityHint`,
`profileCityRequired`, `complete`, `uploadProfilePhoto`, `fromGallery`, `fromCamera`, `authStepOf`,
plus `authSecurityNotice` (from `SecurityNotice`).

**Notes for reimplementation:**
- **Required-but-unvalidated photo** is the main gotcha: label says `*`, nothing enforces it.
- City is a free-text field, not a picker — there is no city catalogue or autocomplete. The value
  goes straight to the `city` column added in feature 007.
- The step count is driven entirely by `args['authTotalSteps'] ?? 3`, and `currentStep` is set equal
  to it, so this screen always renders as the last step whatever the wizard length.
- No back navigation is offered; a user who mis-typed their name in step 1 cannot return.
- The camera badge uses `PositionedDirectional(end: 4)`, so it flips to the left side in Arabic RTL —
  intentional, unlike the fixed-left forgot-password link on S-06.

---

## S-08: ForgotPasswordScreen  (`screens/auth/forgot_password_screen.dart`)

**Purpose:** Ask for a phone number and trigger a password-reset OTP.

**Reached from:** **effectively orphaned on the happy path.** A repo-wide grep for
`RouteNames.forgotPassword` finds only:
- `main.dart:158` (route registration), and
- `reset_password_screen.dart:73, 165, 182` — three `pushReplacementNamed` calls from S-09:
  1. `_extractPhoneNumber()` when the route arguments carry no `phoneNumber`;
  2. the `requestNewCode` action on the "too many attempts / locked" snackbar;
  3. the `requestNewCode` action on the "expired" snackbar.

S-06's "Forgot password?" button does **not** come here — it calls `forgotPassword` itself and pushes
`/reset-password` directly. So this screen is only ever seen as a recovery step *after* a reset
attempt has already failed.

**Navigates to:**
- Send success → `Navigator.pushNamed(context, RouteNames.resetPassword,
  arguments: {'phoneNumber': phoneNumber})` → S-09.
- "Back to sign in" `TextButton` → `Navigator.of(context).pop()`.
- AppBar leading `Icons.arrow_back` → `Navigator.of(context).pop()`.

Because S-09 arrives here via `pushReplacementNamed`, popping returns to whatever preceded S-09
(typically S-06 SignIn).

**Route name / constructor args:** `/forgot-password`; `const ForgotPasswordScreen({super.key})` —
no parameters, no route arguments read.

**UI structure:**
```
Scaffold(backgroundColor: T.surface)
├ appBar: AppBar(transparent, elevation 0,
│                leading: IconButton(Icons.arrow_back, onSurface) → pop)
└ Stack
  ├ Positioned(top: -w*0.4, right: -w*0.2)
  │     w*0.8 square circle, RadialGradient(radius .5) [primary@20%, transparent]
  └ SafeArea > FadeTransition > Center > SingleChildScrollView(
        BouncingScrollPhysics, horizontal 24, vertical 20)
      > ConstrainedBox(maxWidth: 480) > Column(center)
        ├ Container padding 24, surface, circle,
        │     shadow primary@15% blur 24 offset (0,8)
        │   Icon(Icons.lock_reset_rounded, size 64, primary)
        ├ SizedBox(32)
        ├ Text(forgotPasswordTitle)     32px w800, letterSpacing 0.5
        ├ SizedBox(8)
        ├ Text(forgotPasswordSubtitle)  16px onSurfaceVariant height 1.5, centered
        ├ SizedBox(40)
        └ Form(_formKey) > Column
            ├ Container(surfaceVariant, radius 16) > Row          ← PHONE ROW
            │     ├ CountryCodePicker(borderColor: transparent, width: 110)
            │     ├ 1×30 divider, outline@30%
            │     └ Expanded > TextFormField (see form table)
            ├ SizedBox(32)
            ├ SizedBox(width ∞, height 56) > ElevatedButton
            │     bg primary, fg onPrimary, radius 16, elevation 0
            │     label sendResetCode 18px w600
            │     loading: 24×24 CircularProgressIndicator(strokeWidth 2, white)
            ├ SizedBox(24)
            └ TextButton(backToSignIn) 16px w500 primary → pop
```

No step indicator.

**Form fields:**

| field | widget | keyboard type | validation rule (exact) | error message key |
|---|---|---|---|---|
| country code | `CountryCodePicker(width: 110, borderColor: transparent)` | — | none | — |
| phone | `TextFormField` with `labelText: phoneNumber`, `hintText: '123456789'`, `prefixIcon: Icon(Icons.phone, onSurfaceVariant)`, all borders `InputBorder.none`, `textDirection: TextDirection.ltr` | `TextInputType.phone` | `value == null \|\| value.trim().isEmpty` | `phoneNumberRequired` |
| | | | `!RegExp(r'^\d{7,15}$').hasMatch(value.trim().replaceAll(RegExp(r'\s+'), ''))` | `invalidPhoneNumber` |

**Client-side validation** (`_sendCode`, line 49): `if (!_formKey.currentState!.validate()) return;`
- empty → "Please enter phone number" / "يرجى إدخال رقم الهاتف"
- not 7–15 digits (whitespace stripped, **no `+` allowed**) → "Invalid phone number" / "رقم الهاتف غير صحيح"

Phone normalisation (lines 55-59):
```dart
String cleanedPhone = _phoneController.text.trim();
if (!cleanedPhone.startsWith('+') && cleanedPhone.startsWith('0')) {
  cleanedPhone = cleanedPhone.substring(1);
}
final phoneNumber = '${_selectedCountry.dialCode}$cleanedPhone';
```

**Backend calls:**
- `AuthProvider.forgotPassword(phoneNumber)` (`auth_provider.dart:474`).
  - **Success** → `pushNamed('/reset-password', arguments: {'phoneNumber': phoneNumber})`.
  - **Any throw** → `ErrorSurface.showFailure(context, ApiClient.mapError(e))`. Rate-limit responses
    are *not* specially handled here (unlike S-09's `_extractRetryAfter`).
- `finally`: `if (mounted) setState(() => _isLoading = false)`.

**State handling:**
- `_isLoading` — `onPressed: _isLoading ? null : _sendCode`; child swaps to a 24×24 spinner.
- `_selectedCountry` — `CountryData`, defaults to Jordan `+962`.
- `SingleTickerProviderStateMixin`: `AnimationController(duration: 800 ms)`,
  `_fadeAnimation = Tween(0.0 → 1.0)` with `Curves.easeInOut`, forwarded in `initState`.
- No timers, no auto-focus, no auto-submit.
- `_phoneController` and the animation controller are disposed.

**Error display:**
- Field errors inline (standard `InputDecoration` error text; note all borders are `none`, so the
  error text appears without a red outline).
- API errors → `ErrorSurface.showFailure`.

**Localization keys used:** `forgotPasswordTitle`, `forgotPasswordSubtitle`, `phoneNumber`,
`phoneNumberRequired`, `invalidPhoneNumber`, `sendResetCode`, `backToSignIn`.

**Notes for reimplementation:**
- **Near-dead screen.** Consider either wiring S-06's "Forgot password?" to push this route (the
  obvious intent) or deleting it and folding its recovery role into S-09. As written the user only
  ever sees it after a failure, and it duplicates logic that S-06 already inlines.
- Its regex `^\d{7,15}$` rejects any `+` the user types, while S-06's forgot-password handler
  accepts anything non-empty and S-05's `AuthPhoneField` uses `^0?\d{7,15}$`. Three phone rules for
  the same field across one flow.
- `ConstrainedBox(maxWidth: 480)` is the only width clamp in the auth flow — this screen was written
  with tablets in mind, the others were not.
- Uses raw `Colors.white` for the spinner (line 264) rather than `AppColors.white`/`T.onPrimary`.

---

## S-09: ResetPasswordScreen  (`screens/auth/reset_password_screen.dart`)

**Purpose:** Two-step password recovery in one screen — verify the reset OTP, then set a new
password.

**Reached from:**
- S-06 SignIn "Forgot password?" success → `pushNamed('/reset-password',
  arguments: {'phoneNumber': formattedPhone})`. This is the real-world entry point.
- S-08 ForgotPassword success → same call.

**Navigates to:**
- Reset success → `Navigator.pushNamedAndRemoveUntil(context, RouteNames.signIn, (route) => false)`
  → S-06 with the stack cleared.
- Missing `phoneNumber` argument (in the post-frame callback) →
  `pushReplacementNamed('/forgot-password')` → S-08.
- "Request New Code" snackbar action on `too many attempts`/`locked` or `expired` →
  `pushReplacementNamed('/forgot-password')` → S-08.
- AppBar leading `Icons.arrow_back` → `Navigator.of(context).pop()` — pops the **whole screen**, from
  either page (there is no per-page back).

**Route name / constructor args:** `/reset-password`; `const ResetPasswordScreen({super.key})` — no
parameters. Route arguments: `{'phoneNumber': String}` — **required**; its absence triggers the
redirect above.

**UI structure:** a `PageView` with `NeverScrollableScrollPhysics` (swipe disabled) and exactly two
children; navigation between them is programmatic only.

```
Scaffold(backgroundColor: T.surface)
├ appBar: AppBar(transparent, elevation 0, leading: IconButton(Icons.arrow_back) → pop)
└ SafeArea > PageView(_pageController, NeverScrollableScrollPhysics)
    ├ [0] _buildOTPVerificationStep()
    └ [1] _buildPasswordResetStep()
```

Page 0 — OTP entry (lines 349-473):
```
SingleChildScrollView(horizontal 24, vertical 20) > Column(center)
  ├ Container padding 24, surface, circle, shadow primary@15% blur 24 offset (0,8)
  │     Icon(Icons.sms, size 64, primary)
  ├ SizedBox(32)
  ├ Text(enterOTP)             24px w800, centered
  ├ SizedBox(8)
  ├ Text(otpSentToYourPhone)   16px onSurfaceVariant, centered
  ├ if (_phoneNumber != null): SizedBox(8) + Text(_phoneNumber)  16px w600 primary
  │       ← the FULL number, unmasked (contrast with S-04's _maskPhone)
  ├ SizedBox(40)
  ├ Row(textDirection: LTR, center)                       ← 6 OTP BOXES
  │     each: Expanded > Container height 48,
  │            constraints maxWidth 48, margin horizontal 4
  │       └ TextField(controller[i], focusNode[i], number kb, center, maxLength 1,
  │                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  │                   counterText '', filled with surfaceVariant, radius 12,
  │                   border/enabledBorder: BorderSide.none,
  │                   focusedBorder: 2px primary)
  ├ SizedBox(32)
  └ if (_canResend)  TextButton(resendCode)   16px w500 primary
    else             Text(resendCodeIn(_resendTimer))  14px onSurfaceVariant
```

Page 1 — new password (lines 475-625):
```
SingleChildScrollView(horizontal 24, vertical 20) > Form(_passwordFormKey) > Column(center)
  ├ Container padding 24, surface, circle, shadow primary@15% blur 24 offset (0,8)
  │     Icon(Icons.lock_reset, size 64, primary)
  ├ SizedBox(32)
  ├ Text(resetPasswordTitle)  24px w800, centered
  ├ SizedBox(40)
  ├ TextFormField  newPassword       (obscureText: true, LTR, filled surfaceVariant, radius 16,
  │                                    borders none, focusedBorder 2px primary)
  ├ SizedBox(16)
  ├ TextFormField  confirmPassword   (same decoration)
  ├ SizedBox(32)
  └ SizedBox(width ∞, height 56) > ElevatedButton
        bg primary, fg onPrimary, radius 16, elevation 0
        label resetPasswordButton 18px w600
        loading: 24×24 CircularProgressIndicator(strokeWidth 2, white)
```

No step indicator on either page — the two-page structure is invisible to the user beyond the
transition.

**Form fields:**

| field | widget | keyboard type | validation rule (exact) | error message key |
|---|---|---|---|---|
| OTP digit ×6 (page 0) | `TextField` — **not inside any `Form`** | `TextInputType.number` | `maxLength: 1`, `FilteringTextInputFormatter.digitsOnly`; guard `otpCode.length != 6 \|\| _phoneNumber == null` → silent return | none |
| new password (page 1) | `TextFormField(obscureText: true, textDirection: ltr, labelText: newPassword)` | default | `value == null \|\| value.trim().isEmpty` | `newPasswordRequired` |
| | | | `value.length < 8` | `passwordTooShort` |
| | | | `!RegExp(r'[A-Za-z]').hasMatch(value) \|\| !RegExp(r'[0-9]').hasMatch(value)` | `passwordPolicyError` |
| confirm password (page 1) | `TextFormField(obscureText: true, textDirection: ltr, labelText: confirmPassword)` | default | `value != _passwordController.text` | `passwordsDoNotMatch` |

Neither password field has a visibility toggle — both are permanently obscured.

**Client-side validation:**
- Page 0: none beyond the length-6 guard; the code is submitted automatically.
- Page 1 (`_resetPassword`, lines 287-294):
  ```dart
  if (_resetToken == null) return;                               // silent
  if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
  ```
  The three password rules and the match rule run here, producing inline errors.

**Backend calls:**

| call | site | success | error |
|---|---|---|---|
| `AuthProvider.verifyResetOtp(_phoneNumber!, otpCode)` → `Future<String>` (`auth_provider.dart:487`) | `_verifyOTP`, line 141 | stores `_resetToken`, then `_pageController.nextPage(duration: 300 ms, curve: Curves.easeInOut)` | branching catch, below |
| `AuthProvider.forgotPassword(_phoneNumber!)` (`auth_provider.dart:474`) | `_resendOTP`, line 212 | green snackbar `newOtpSent` (`AppColors.success`) + `_startResendTimer()` | rate-limit branch, below |
| `AuthProvider.resetPassword(_resetToken!, _passwordController.text)` (`auth_provider.dart:501`) | `_resetPassword`, line 300 | green snackbar `passwordResetSuccess` + `pushNamedAndRemoveUntil('/sign-in', (r)=>false)` | `ErrorSurface.showFailure` |

`_verifyOTP` catch (lines 149-197), matching on `_extractErrorMessage(e).toLowerCase()`:
- contains `'too many attempts'` **or** `'locked'` → `SnackBar(otpTooManyAttempts,
  backgroundColor: T.error(context), duration: 4 s,
  action: SnackBarAction(label: requestNewCode, textColor: T.onPrimary(context),
  onPressed: () => pushReplacementNamed('/forgot-password')))`.
- contains `'expired'` → identical snackbar but with `otpExpired`.
- otherwise → `ErrorSurface.showFailure(context, ApiClient.mapError(e))`.
- In **all three** cases: clear every OTP controller and `_otpFocusNodes[0].requestFocus()`.

`_extractErrorMessage` (lines 77-94): for a `DioException`, reads `response.data['message']` when it
is a `String`, or its first element when it is a non-empty `List`; otherwise falls back to
`error.toString()` with a leading `'Exception: '` stripped.

`_resendOTP` catch (lines 223-254): calls `_extractRetryAfter(e)`; when it returns a value the screen
overrides the countdown with that number of seconds, restarts its own `Timer.periodic`, and shows
`SnackBar(waitBeforeResend(_resendTimer), backgroundColor: AppColors.warning, duration: 3 s)`.
Otherwise → `ErrorSurface.showFailure`.

`_extractRetryAfter` (lines 262-285):
```dart
// DioException → response.data['retryAfter'] : int > 0, or double > 0 → .ceil()
// else: lowercased error string containing '429' | 'too many requests' | 'wait'
//       → RegExp(r'retryafter["\s:]+(\d+)').firstMatch(msg) → int.tryParse(group(1))
// else null
```

**State handling:**
- `_pageController` (`PageController`) — drives the two-page `PageView`; disposed.
- `_otpControllers` / `_otpFocusNodes` — 6 each (`AppConstants.otpLength`); all disposed.
- `_passwordController`, `_confirmPasswordController` — disposed.
- `_phoneNumber` (`String?`) — read from route arguments in a post-frame callback
  (`_extractPhoneNumber`, lines 67-75); null → redirect to `/forgot-password`.
- `_resetToken` (`String?`) — the token returned by `verifyResetOtp`; gates `_resetPassword`.
- `_isLoading` — gates the resend `TextButton` (`onPressed: _isLoading ? null : _resendOTP`) and the
  reset `ElevatedButton` (`onPressed: _isLoading ? null : _resetPassword`).
- **Auto-focus:** post-frame callback in `initState` focuses `_otpFocusNodes[0]` (line 47).
- **Auto-advance / auto-submit** (`_onOTPChanged`, lines 114-125): identical to S-04 — digit typed
  advances focus; the 6th digit unfocuses and calls `_verifyOTP()`; clearing a box moves focus back.
  Unlike S-04 there is **no** `setState` in `onChanged`, because these boxes indicate focus through
  `focusedBorder` rather than a content-derived border.
- **Resend timer:** starts at `AppConstants.otpResendTimeout` = **60 seconds**;
  `Timer.periodic(Duration(seconds: 1))` decrements to 0, then `_canResend = true` and
  `timer.cancel()`. Restarted after each successful resend, and replaced wholesale by the
  server-supplied `retryAfter` value on a rate-limit error.
- **No Verify button on page 0** — auto-submit is the only way forward.

**Error display:**
- OTP errors: floating-default `SnackBar`s (4 s) with `T.error(context)` background and a
  `requestNewCode` action for the two recognised cases; `ErrorSurface.showFailure` (dialog) for
  everything else. Fields always cleared and refocused.
- Resend rate limit: `SnackBar` with `AppColors.warning`, 3 s,
  `waitBeforeResend(seconds)` → "Please wait {n} seconds before requesting a new code".
- Resend success: `SnackBar(newOtpSent, backgroundColor: AppColors.success)`.
- Reset success: `SnackBar(passwordResetSuccess, backgroundColor: AppColors.success)`.
- Password field errors: inline.

**Localization keys used:** `enterOTP`, `otpSentToYourPhone`, `resendCode`, `resendCodeIn`,
`otpTooManyAttempts`, `otpExpired`, `requestNewCode`, `newOtpSent`, `waitBeforeResend`,
`resetPasswordTitle`, `newPassword`, `newPasswordRequired`, `passwordTooShort`,
`passwordPolicyError`, `confirmPassword`, `passwordsDoNotMatch`, `resetPasswordButton`,
`passwordResetSuccess`.

**Notes for reimplementation:**
- **String-matched error branching.** `too many attempts`, `locked` and `expired` are matched against
  the *lowercased English message text* from the API. Any backend copy change, or an Arabic-localized
  server message, silently degrades these to the generic dialog. Match on an error `code` instead.
- This is the only screen that imports `package:dio/dio.dart` directly (line 2) to reach
  `DioException.response.data`, bypassing `ApiClient.mapError`. Two parallel error-parsing paths
  (`_extractErrorMessage`, `_extractRetryAfter`) exist only here.
- The phone number is displayed **in full** on page 0, while S-04 masks it. Pick one.
- The AppBar back button pops the entire flow from page 1, discarding a validated `_resetToken` with
  no confirmation.
- `_extractPhoneNumber` runs in `addPostFrameCallback`, so for one frame the screen renders with
  `_phoneNumber == null` (the phone `Text` is simply omitted) before redirecting.
- The OTP `Row` is pinned to `TextDirection.ltr` (line 405) for the same RTL reason as S-04.
- Boxes are `Expanded` with `maxWidth: 48` and `height: 48` — smaller than S-04's 64px boxes. The two
  OTP UIs are visually different implementations of the same control; a rebuild should extract one
  shared widget.
- `Colors.white` is used raw for both spinners (lines 608, 264 in S-08) instead of the theme token.

---

## S-10: BannedScreen  (`screens/auth/banned_screen.dart`)

**Purpose:** Terminal gate shown when the backend reports the account is banned. Offers exactly one
action: contact support on WhatsApp.

**Reached from:** `core/api/auth_interceptor.dart:41-61` only — on **any** HTTP `403` whose response
body carries `code == 'ACCOUNT_BANNED'`:
```dart
await _tokenStorage.clearAll();
final navigator = NotificationNavigationService.navigatorKey.currentState;
navigator?.pushNamedAndRemoveUntil(RouteNames.banned, (route) => false, arguments: {
  'banReason'      : data['banReason'] as String?,
  'supportWhatsApp': data['supportWhatsApp'] as String?,
});
return;   // the DioException is swallowed — the caller's catch never runs
```
Because the whole stack is removed and tokens are cleared first, this screen cannot be reached by any
user gesture.

**Navigates to:** nothing in-app. The only exit is an external WhatsApp deep link
`https://wa.me/<number>?text=<prefill>` opened with
`launchUrl(uri, mode: LaunchMode.externalApplication)`. There is no back button, no sign-out button,
and no route back to `/sign-in`.

**Route name / constructor args:** `/banned`; `const BannedScreen({super.key})` — no parameters.
Route arguments (optional `Map<String, dynamic>`, read in `didChangeDependencies`, lines 30-37):
`banReason` (`String?`), `supportWhatsApp` (`String?`).

**UI structure:**
```
Scaffold
└ Container(width ∞, vertical LinearGradient
        [AppColors.errorDark@8%, T.background(context)])
  └ SafeArea > Padding(horizontal 28) > Column(center/center)
      ├ Spacer()
      ├ 90×90 circle, AppColors.errorDark@12%
      │     Icon(IconsaxPlusBold.shield_slash, size 44, AppColors.errorDark)
      ├ SizedBox(28)
      ├ Text(accountBannedTitle)   26px w800 onSurface, centered
      ├ SizedBox(12)
      ├ Text(_banReason?.isNotEmpty == true ? _banReason! : accountBannedNoReason)
      │     15px, height 1.65, onSurfaceVariant, centered
      ├ SizedBox(40)
      ├ SizedBox(width ∞) > FilledButton.icon
      │     icon: Icon(IconsaxPlusBold.message, 20)
      │     label: Text(contactSupportViaWhatsApp) 16px w600
      │     backgroundColor: const Color(0xFF25D366)   ← WhatsApp brand green
      │     foregroundColor: Colors.white
      │     padding vertical 16, radius 16
      │     onPressed: _fetchConfigAndOpen
      ├ Spacer()
      └ Padding(bottom 16) > Text('VisionWay © ${DateTime.now().year}')
            12px, onSurfaceVariant@50%
```

No step indicator, no `AppBar`.

**Form fields:** none.

**Client-side validation:** none.

**Backend calls:**
- `_fetchConfigAndOpen()` (lines 65-83):
  - if `_supportWhatsApp != null` → skip the network call and open WhatsApp immediately;
  - otherwise `ApiClient().get('/support/config')` and `setState(() => _supportWhatsApp =
    data['whatsappE164'] as String?)`;
  - `catch (_) {}` — **silently swallowed**, then falls through to `_openWhatsApp()` with the
    constant fallback.
- Number resolution (`_whatsAppNumber`, lines 39-44):
  `(_supportWhatsApp ?? SupportConstants.supportPhone).replaceAll('+', '').replaceAll(' ', '')`
  — the leading `+` is stripped for the `wa.me` URL form.
- `_openWhatsApp()` (lines 46-63):
  ```dart
  final prefill = Uri.encodeComponent(context.l10n.bannedWhatsAppPrefill);
  final uri = Uri.parse('https://wa.me/$_whatsAppNumber?text=$prefill');
  if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
  else { snackbar(couldNotOpenWhatsApp) }
  ```

**State handling:**
- `_banReason` and `_supportWhatsApp` (`String?`) read in `didChangeDependencies` — so they refresh
  on every dependency change, not just once.
- **No loading indicator** while `/support/config` is being fetched; the button stays enabled and
  can be tapped repeatedly, each tap firing another request.
- No timers, no animations, no focus management.
- `StatefulWidget` purely to hold the two nullable strings and the `setState` after the config fetch.

**Error display:**
- WhatsApp launch failure → `SnackBar(content: Text(couldNotOpenWhatsApp),
  behavior: SnackBarBehavior.floating)` — **no background colour set**, so it uses the theme default
  rather than an error colour.
- `/support/config` failure → no user-visible error at all.

**Localization keys used:** `accountBannedTitle`, `accountBannedNoReason`,
`contactSupportViaWhatsApp`, `bannedWhatsAppPrefill`, `couldNotOpenWhatsApp`.

**Notes for reimplementation:**
- The file header (lines 1-8) tags this as **T174** and documents the contract; keep that comment.
- `_banReason` is **server-supplied free text rendered verbatim** and is not localized — the backend
  must return it in the user's language, or the UI must map a code to a localized string.
- The footer `'VisionWay © ${DateTime.now().year}'` is a hard-coded English string — the only
  untranslated user-visible copy in the auth flow.
- `Color(0xFF25D366)` and `Colors.white` are hard-coded (WhatsApp brand); they will not adapt to
  dark mode, which is correct for a brand button but should be a named constant.
- Because the interceptor **swallows** the `DioException` after navigating, the originating call site
  never sees a failure — its `finally` blocks still run, but its `catch` does not. Any rebuild must
  preserve that or callers will double-report.
- A banned user has no way to switch accounts; the only recovery is reinstalling or contacting
  support. Consider adding a "back to sign in" affordance.

---

## Shared auth widgets (`widgets/auth/`)

### W-01: `AuthTextField`  (`widgets/auth/auth_text_field.dart`)

Boxed field used across the redesigned auth screens (S-05, S-07, and the driver screens).

```dart
const AuthTextField({
  super.key,
  required TextEditingController controller,
  required String label,
  required IconData icon,
  String? helper,                       // small muted line under the label
  String? hint,
  bool obscureText = false,
  Widget? suffix,                       // trailing action (eye, chevron…)
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  bool readOnly = false,
  bool enabled = true,
  VoidCallback? onTap,
  TextDirection? textDirection,
});
```

Structure: `Container(paddingDirectional start 10/end 6/top 6/bottom 6,
color: enabled ? T.surface : T.surfaceVariant, radius 16, border T.outline,
shadow T.shadow@5% blur 10 offset (0,3))` → `Row`:
- 40×40 rounded-12 tile, `primary@10%`, `Icon(icon, 20, primary)`
- `SizedBox(width: 10)`
- `Expanded > Column(start, min)`:
  - `Text(label)` 13px w700 `onSurface`
  - `Text(helper)` 11px `onSurfaceVariant` (when non-null)
  - `Semantics(label: label, textField: true) > TextFormField` — 15px w500, `isDense: true`,
    **every** border variant set to `InputBorder.none`, `contentPadding: vertical 4`,
    `errorStyle: 11px T.error(context)`
- `suffix` when non-null

Note the label is a static `Text` above the input, not a floating `InputDecoration.labelText`.

### W-02: `AuthPhoneField`  (`widgets/auth/auth_phone_field.dart`)

Dial-code chip + local number input; used by both signup step-1 screens (S-05 and the driver signup).

```dart
const AuthPhoneField({
  super.key,
  required TextEditingController controller,
  required CountryData country,
  required ValueChanged<CountryData> onCountryChanged,
  String? helper,
  String hint = '07 XXX XXXX',
});
static String composeE164(CountryData country, String raw);
```

Structure: `Column(start)`:
- `Container(padding h8/v6, T.surface, radius 16, border T.outline,
  shadow T.shadow@5% blur 10 offset (0,3))` → `Row`:
  - 40×40 rounded-12 tile `primary@10%` with `Icon(IconsaxPlusLinear.call, 20, primary)`
  - `SizedBox(8)`
  - `CountryCodePicker(selectedCountry: country, onCountryChanged, borderColor: T.outline, width: 116)`
  - `SizedBox(8)`
  - `Expanded > Semantics(label: phoneNumber, textField: true)
     > Directionality(textDirection: TextDirection.ltr) > TextFormField`
    - `keyboardType: TextInputType.phone`, `textDirection: ltr`, 16px w600 `letterSpacing: 1`
    - hint 14px `letterSpacing: 1`, `onSurfaceVariant@50%`
    - all borders `InputBorder.none`, `isDense: true`, `contentPadding: vertical 10`,
      `errorStyle: 11px T.error`
- `Padding(startDirectional 8, top 6) > Text(helper)` 11px when `helper != null`

Built-in validator (lines 114-123) — **the widget owns it; callers cannot override**:
```dart
if (v == null || v.trim().isEmpty) return context.l10n.phoneNumberRequired;
final digits = v.replaceAll(RegExp(r'\s+'), '');
if (!RegExp(r'^0?\d{7,15}$').hasMatch(digits)) return context.l10n.invalidPhoneNumber;
return null;
```

`composeE164` (lines 147-153): trim, strip all whitespace, drop a single leading `0` when the value
does not start with `+`, then prefix `country.dialCode`.

**Gotcha:** the whole field is wrapped in an explicit LTR `Directionality` because
`InputDecorator` lays the hint out with the ambient direction, which renders `07 XXX XXXX`
reversed under Arabic (comment at lines 77-78).

### W-03: `AuthPrimaryButton`  (`widgets/auth/auth_primary_button.dart`)

Full-width teal CTA at the bottom of every auth step (S-05, S-07, driver steps).

```dart
const AuthPrimaryButton({
  super.key,
  required String label,
  required VoidCallback? onPressed,
  bool loading = false,
  bool showArrow = true,
  bool pinnedArrow = false,
  IconData? icon,                // replaces the directional arrow
});
```

`SizedBox(height: 56, width: double.infinity) > ElevatedButton`:
- `backgroundColor: T.primary`, `foregroundColor: T.onPrimary`,
  `disabledBackgroundColor: T.primary@50%`, `disabledForegroundColor: T.onPrimary`,
  `elevation: 0`, radius 16
- `onPressed: loading ? null : onPressed`
- loading child: 22×22 `CircularProgressIndicator(strokeWidth: 2.5, T.onPrimary)`
- normal child: `Row(center)` with `Text(label)` 17px w700 and a 20px arrow

Arrow logic (lines 45-50, 33-38):
```dart
final isRtl = Directionality.of(context) == TextDirection.rtl;
final trailing = icon ?? (isRtl && !pinnedArrow
    ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded);
```
- `pinnedArrow: false` (default): arrow **after** the label, pointing in reading direction.
- `pinnedArrow: true`: the `Row` gets `textDirection: TextDirection.ltr` and the arrow is emitted
  **first**, wrapped in its own LTR `Directionality` so the glyph itself cannot mirror. The class
  comment (lines 29-32) explains why: Material's directional arrows carry `matchTextDirection: true`,
  so choosing a different `IconData` is not enough to pin the direction.

`Semantics(button: true, label: label, enabled: onPressed != null && !loading)` wraps the whole
thing.

### W-04: `AuthStepIndicator`  (`widgets/auth/auth_step_indicator.dart`)

Numbered 1/2/3 progress chrome shared by every auth wizard screen (S-04 when step args are present,
S-05, S-07, driver steps).

```dart
const AuthStepIndicator({
  super.key,
  required int currentStep,     // 1-based index of the active step
  required int totalSteps,
  List<String>? labels,         // optional caption per circle; must have totalSteps entries
  double circleSize = 30,
});
```

Layout: a `Row` of `_StepCircle` widgets separated by `Expanded` connector bars
(`height: 2, margin horizontal 6`, coloured `T.primary` when `step <= currentStep`, else
`T.outlineVariant`). When `labels` is supplied **and** `labels.length == totalSteps`, the row is
wrapped in a `Column` with an 8px gap and a second `Row` of `Expanded` captions (11px,
w700 when `step == currentStep` else w500; `T.primary` when `step <= currentStep`, else
`T.onSurfaceVariant`; `maxLines: 2`, ellipsis). If the lengths mismatch, captions are silently
dropped.

`_StepCircle` (lines 89-136):
- `isDone = step < current`, `isActive = step == current`, `filled = isDone || isActive`
- `Container(width/height: size, circle, color: filled ? T.primary : T.surface,
   border: 1.6px filled ? T.primary : T.outlineVariant)`
- child: `Icon(Icons.check, size: size * 0.55, T.onPrimary)` when done, else `Text('$step')` at
  `size * 0.45`, w700, `T.onPrimary` when active else `T.onSurfaceVariant`
- `Semantics(label: 'Step $step', selected: isActive)` — **hard-coded English `'Step N'`**, the one
  deliberate omission (the class comment at lines 8-10 says it is kept localization-free so it can
  render in tests and previews without an `AppLocalizations` ancestor).

Callers pair it with a separate `Text(context.l10n.authStepOf(current, total))` for the visible
"Step 1 of 3" label.

### W-05: `GenderSelectCards`  (`widgets/auth/gender_select_cards.dart`)

Male/female picker on both signup step-1 screens.

```dart
const GenderSelectCards({
  super.key,
  required String? value,               // AppConstants.genderMale | genderFemale | null
  required ValueChanged<String> onChanged,
});
```

`Row(textDirection: TextDirection.ltr)` — **physically pinned**: female left, male right, in both
locales (comment lines 23-25). Two `Expanded > _GenderCard` separated by `SizedBox(width: 12)`.

`_GenderCard`: `GestureDetector > AnimatedContainer(duration: 200 ms, padding vertical 18,
T.surface, radius 16, border: selected ? 2px T.primary : 1px T.outline)` containing a `Stack`:
- when selected, `Positioned(top: 0, left: 0)` → 22×22 `T.primary` circle with
  `Icon(Icons.check, 14, T.onPrimary)` — note **`left`, not `start`**, so the check stays physically
  top-left in RTL
- `Column(min)`: 48×48 circle (`primary@12%` when selected, else `T.surfaceVariant`) with
  `Icon(Icons.female | Icons.male, 24, selected ? primary : onSurfaceVariant)`, `SizedBox(10)`,
  `Text(label)` 15px w600 (`primary` when selected, else `onSurface`)

`Semantics(button: true, selected: selected, label: label)`.

Emits `AppConstants.genderFemale` (`'female'`) / `AppConstants.genderMale` (`'male'`).
Labels come from `context.l10n.female` / `context.l10n.male`.

**Note:** there is no "prefer not to say" / other option, and no way to clear a selection once made.

### W-06: `SecurityNotice`  (`widgets/auth/security_notice.dart`)

Shield + privacy reassurance line under the auth headers (used by S-07 and driver steps).

```dart
const SecurityNotice({super.key, String? text, bool onDark = false});
```

`Row(mainAxisSize: min, center)`:
- `Icon(IconsaxPlusBold.shield_tick, size: 16, color)`
- `SizedBox(6)`
- `Flexible > Text(text ?? context.l10n.authSecurityNotice)` 12px, `height: 1.4`

`color = onDark ? AppColors.white@92% : T.onSurfaceVariant(context)` — `onDark: true` is for
rendering over the teal hero.

### W-07: `AuthLanguageSwitcher`  (`widgets/auth/auth_language_switcher.dart`)

White AR/EN pill in the top corner of the auth headers. Used by S-02 (and the driver signup).

```dart
const AuthLanguageSwitcher({super.key});
```

`context.watch<LocalizationService>()` → requires that provider above it (supplied by `main.dart`).

`PopupMenuButton<String>(onSelected: (code) => localization.setLanguage(code),
position: PopupMenuPosition.under)` with exactly two items:
```dart
PopupMenuItem(value: AppConstants.langArabic,  child: Text('العربية')),
PopupMenuItem(value: AppConstants.langEnglish, child: Text('English')),
```
Trigger: `Container(padding h14/v9, T.surface, radius 22, border T.outline,
shadow T.shadow@6% blur 10 offset (0,3))` → `Row(min)`:
`Icon(IconsaxPlusLinear.global, 18, primary)`, `SizedBox(6)`,
`Text(localization.isArabic ? 'العربية' : 'English')` 13px w600,
`Icon(Icons.keyboard_arrow_down_rounded, 18, onSurfaceVariant)`.

`Semantics(button: true, label: context.l10n.language)`.

The menu item labels are **hard-coded native names**, not localized keys — correct for a language
picker.

### W-08: `DocumentUploadBox`  (`widgets/auth/document_upload_box.dart`)

Dashed upload area for a single registration document.

```dart
const DocumentUploadBox({
  super.key,
  required String label,
  required VoidCallback onTap,
  File? file,
  String? previewUrl,     // already-uploaded image (edit mode)
  String? hint,           // CTA inside the empty box; defaults to l10n.tapToUpload
});
```

**Not used by any in-scope screen.** Consumers are `driver_sign_up_screen.dart`,
`driver_complete_profile_screen.dart`, `driver_complete/driver_complete_step2.dart` and
`driver_complete_step3.dart` — all driver flow. Documented here only because it lives in
`widgets/auth/`.

`Column(start)`: `Text(label)` 14px w600, `SizedBox(10)`,
`Semantics(button: true, label: context.l10n.uploadFileLabel(label)) > GestureDetector >
SizedBox(height: 150, width: ∞)` containing either the preview or the empty state.

- `_hasContent == file != null || (previewUrl?.isNotEmpty ?? false)`.
- Preview (lines 66-116): `Stack(fit: expand)` with `ClipRRect(r16)` around
  `Image.file(file, cover)` or `Image.network(previewUrl, cover)` (its `errorBuilder` falls back to a
  `surfaceVariant` box with `Icon(IconsaxPlusLinear.gallery_slash)`); plus a
  `PositionedDirectional(top 8, end 8)` primary check badge and a
  `PositionedDirectional(bottom 8, start 8)` black@55% pill reading `tapToChange`.
- Empty state (lines 118-174): `CustomPaint(painter: _DashedBorderPainter(color: primary@45%,
  radius: 16))` over a `primary@4%` rounded-16 box containing a 52×52 rounded-14 `primary` tile with
  `Icon(IconsaxPlusBold.document_upload, 26, onPrimary)`, `SizedBox(12)`,
  `Text(hint ?? tapToUpload)` 13px w600, `SizedBox(4)`, `Text(documentFormatsHint)` 11px
  `maxLines: 2` ellipsis.

`_DashedBorderPainter` (lines 178-215) walks `Path.computeMetrics()` extracting
`_dash = 7` px segments separated by `_gap = 5` px, `strokeWidth: 1.6` — Flutter has no dashed
`BorderSide`.

---

## Cross-cutting notes for a rebuild

**Dead / unreachable code inventory**

| Location | What | Why dead |
|---|---|---|
| `otp_verification_screen.dart:181-184, 221-264` | `_completeDriverProfileAfterOtp` and its `isDriverCompleteProfile` guard | the flag is never written anywhere in the repo |
| `otp_verification_screen.dart:229-247` | reads of `carImage`, `profileImage`, `vehicleType`, `plateNumber`, `model`, `seats`, `driverLicenseImage`, `vehicleLicenseImage` | only reachable from the dead method above |
| `otp_verification_screen.dart:252-263` | `driverProfileSubmitted` snackbar + `pushNamedAndRemoveUntil('/driver-pending-approval')` | same |
| `phone_auth_screen.dart:136-139, 178-180, 198-201` | `AppConstants.skipOTP` branches (`devModeDirectLogin`, `enterAction`) | `skipOTP` is `const bool = false` |
| `forgot_password_screen.dart` (whole screen) | S-08 | only reachable from S-09's failure paths; S-06 bypasses it |
| `main.dart:147` `/welcome` | route registration | nothing ever pushes it by name; the screen is only rendered by `AuthWrapper` |
| args `isRegistration`, `accountType`, `isSignIn` | written by S-05, S-03 and the driver signup | never read by any consumer |

**Commented-out / stale code**

- `main.dart:4` — `// import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;`
- `main.dart:74-75` — `//admin@rideshare.com` / `//Admin@123456`: **admin credentials committed in a
  comment**. Remove.
- `main.dart:100-101`, `main.dart:72` — stale comments about FirebaseAuth having been replaced.
- `app_constants.dart:11-12` — `// static const bool forceFirebaseAuth = false;`
- `phone_auth_screen.dart:53-54` — stale dev-mode comment.

**Inconsistencies worth resolving before rebuilding**

1. **Three phone validators**: `^0?\d{7,15}$` (`AuthPhoneField`), `^\d{7,15}$` (S-08),
   `formattedPhone.length < 10` (S-03), plus S-06's bare `isEmpty` check.
2. **Three phone composers**: `AuthPhoneField.composeE164` (guards a typed `+`), S-06/S-08's inline
   `'${dialCode}$cleaned'` (does not), and S-03's `AppConstants.defaultCountryCode` fallback.
3. **Two default countries**: `+962` Jordan vs `+20` Egypt.
4. **Three password thresholds**: 8 + letter + digit (S-05, S-09) vs 6 (S-06 sign-in).
5. **Two OTP UIs**: S-04 (64px boxes, content-driven border, explicit Verify button) vs S-09 (48px
   boxes, focus-driven border, auto-submit only). Same 6 digits, same 60 s timer.
6. **Two phone-masking policies**: S-04 masks, S-09 shows the full number.
7. **Two error-handling stacks**: `ErrorSurface` + `ApiClient.mapError` everywhere, plus S-09's
   direct `DioException` string matching.

**RTL handling** — several places deliberately pin LTR and must be preserved:
`otp_verification_screen.dart:471`, `reset_password_screen.dart:405` (OTP digit order);
`gender_select_cards.dart:27` (female left / male right);
`auth_phone_field.dart:79-84` and `country_code_picker.dart:52` (dial code and hint);
`auth_primary_button.dart:33-38, 88` (`pinnedArrow`).
Conversely, `sign_in_screen.dart:316` (`Alignment.centerLeft`) and
`gender_select_cards.dart:87-88` (`left: 0`) are non-directional by omission rather than by design.

**Assets referenced by in-scope screens**

| Asset | Used by |
|---|---|
| `assets/OIG1.jpg` | S-01 hero avatar |
| `assets/illustrations/auth/auth_account_type_cityscape.webp` | S-02 header backdrop |
| `assets/illustrations/auth/auth_visionway_logo.webp` | S-02 top bar |
| `assets/illustrations/auth/auth_passenger_card_hero.webp` | S-02 passenger card |
| `assets/illustrations/auth/auth_driver_card_hero.webp` | S-02 driver card |
| `assets/illustrations/auth/auth_passenger_signup_hero.webp` | S-05 hero |

All illustration assets are `.webp`; the corresponding `.png` files were removed from the repo.
