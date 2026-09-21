# Mobile — Driver Registration Flow (Flutter)

Source of truth: `d:\work\wisoway\rideshare\lib`. Every claim below is anchored to
`file:line`. All paths are relative to `rideshare/lib` unless stated otherwise.

Scope: the DRIVER signup wizard only. Passenger auth screens (welcome, phone_auth,
sign_up, sign_in, profile_setup, forgot/reset, banned) are covered elsewhere. The
OTP screen is documented here only for its driver branch
(`screens/auth/otp_verification_screen.dart:134-156`).

---

## 1. Flow diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ AccountTypeSelectionScreen                                                   │
│   screens/auth/account_type_selection_screen.dart:161-164                    │
│   driver card → pushReplacementNamed(RouteNames.driverSignUp)                │
└───────────────────────────────┬──────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ D-01  DriverSignUpScreen              screens/auth/driver_sign_up_screen.dart│
│       Step indicator: 1 / 3  ("Basic information")                           │
│       Collects: fullName, country+phone, password, confirm, gender           │
│       BACKEND CALL: AuthProvider.sendOTP(phoneE164)                          │
│                     → POST /api/v1/auth/send-otp        (:95)                │
│       On success: pushReplacementNamed(otpVerification, args{...})  (:103)   │
│         args: phoneNumber, isRegistration:true, role:'driver', name,         │
│               firstName, lastName, gender, password,                         │
│               afterVerifyRoute: RouteNames.driverCompleteProfile             │
└───────────────────────────────┬──────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ D-OTP  OtpVerificationScreen (shared screen, driver branch only)             │
│        screens/auth/otp_verification_screen.dart:111,134-156                 │
│        Detects driver via args['role'] == 'driver'                           │
│        BACKEND CALL: AuthProvider.verifyDriverPhone(...)                     │
│                      → POST /api/v1/auth/driver/verify-phone                 │
│                        {phoneNumber, code}                                   │
│                      ← {registrationToken, expiresIn:1800}                   │
│        Persists PendingDriverRegistration to secure storage                  │
│          (auth_provider.dart:205-217)                                        │
│        NOTE: this screen is NOT one of the 3 wizard steps                    │
│              (driver_sign_up_screen.dart:28-32)                              │
│        On success: pushReplacementNamed(driverCompleteProfile,               │
│                    args{firstName,lastName,email,gender})   (:144-153)       │
└───────────────────────────────┬──────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ DriverCompleteProfileScreen  (shell for steps 2 and 3)                       │
│   screens/auth/driver_complete_profile_screen.dart                           │
│   _bootstrap() (:98-138) decides create-vs-edit; shows spinner while         │
│   _isBootstrapping (:310-319). _loadVehicleTemplates() (:77-89) fires        │
│   GET /api/v1/vehicles/types in initState (:67).                            │
│                                                                              │
│   ┌────────────────────────────────────────────────────────────────────┐    │
│   │ D-02  DriverCompleteStep2   driver_complete/driver_complete_step2  │    │
│   │       Step indicator: 2 / 3  ("ID & documents")                    │    │
│   │       Badge: "Step 2 of 3: Additional information"                 │    │
│   │       Profile photo picker + vehicleType/plate/model/seats +       │    │
│   │       driver-license upload box                                    │    │
│   │       NO BACKEND CALL (step2 doc comment :13-14)                   │    │
│   │       onContinue → _continueToStep3() (:202-213) → state.step = 3  │    │
│   └───────────────────────────────┬────────────────────────────────────┘    │
│                    ▲ back (:369 / PopScope :326-330 / header :414)          │
│                    │              ▼                                          │
│   ┌────────────────┴───────────────────────────────────────────────────┐    │
│   │ D-03  DriverCompleteStep3   driver_complete/driver_complete_step3  │    │
│   │       Step indicator: 3 / 3  ("Vehicle information")               │    │
│   │       Badge: "Step 3 of 3: Vehicle documents"                      │    │
│   │       Registration form + insurance + car photo upload boxes       │    │
│   │       onSubmit → _submit() (:227-295)                              │    │
│   │                                                                     │    │
│   │  CREATE branch (:271-281) → AuthProvider.registerDriver            │    │
│   │    5 × POST /api/v1/uploads/registration (multipart)               │    │
│   │        auth_provider.dart:254-273  (photo, license, vehicleLicense,│    │
│   │                                     insurance, car — sequential)    │    │
│   │    then POST /api/v1/auth/driver/register                          │    │
│   │        auth_service.dart:201-251                                   │    │
│   │    then saves accessToken/refreshToken/userId                      │    │
│   │        auth_service.dart:237-242                                   │    │
│   │    then clears PendingDriverRegistration (auth_provider.dart:310)  │    │
│   │    then POST device token registration (auth_provider.dart:313)    │    │
│   │                                                                     │    │
│   │  EDIT branch (:245-268) → AuthProvider.updatePendingDriverReg…     │    │
│   │    N × POST /api/v1/uploads (session-auth, only re-picked files)   │    │
│   │        auth_provider.dart:346-386                                  │    │
│   │    then PATCH /api/v1/auth/driver/registration                     │    │
│   │        auth_service.dart:257-261, then GET /auth/me                │    │
│   └───────────────────────────────┬────────────────────────────────────┘    │
└───────────────────────────────────┼──────────────────────────────────────────┘
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ DriverPendingApprovalScreen   (pushNamedAndRemoveUntil, stack cleared)       │
│   driver_complete_profile_screen.dart:263-267 (edit) / :285-289 (create)     │
│   "Edit registration" row → pushNamed(driverCompleteProfile,                 │
│    {'editMode': true})    screens/driver/driver_pending_approval_screen.dart │
│                           :402-406  ← re-enters D-02 in edit mode            │
└──────────────────────────────────────────────────────────────────────────────┘

RESUME PATH (cold start with an unexpired pending registration):
  main.dart:443-448 → AuthWrapper renders DriverCompleteProfileScreen directly
  (not via a named route ⇒ ModalRoute arguments == null ⇒ editMode false).
```

### Legacy / dead path

`otp_verification_screen.dart:112` reads `args['isDriverCompleteProfile']`, which
**no screen ever sets** (verified: `grep -rn "isDriverCompleteProfile"` matches only
`otp_verification_screen.dart:112,134,181`). Therefore
`_completeDriverProfileAfterOtp` (`otp_verification_screen.dart:218-263`),
`AuthProvider.saveDriverProfile` (`providers/auth_provider.dart:576-633`) and
`VehicleService.addVehicle` (`core/services/vehicle_service.dart:70-115`) are the
**pre-deferred-registration legacy driver path and are unreachable**. Do not port
them.

---

## 2. Wizard state model — `screens/auth/driver_complete/driver_profile_wizard_state.dart`

`DriverProfileWizardState extends ChangeNotifier` (:11). Instantiated once per
screen at `driver_complete_profile_screen.dart:46` as
`late final DriverProfileWizardState _state = DriverProfileWizardState();`
and disposed at `:72-75`.

| Field | Type | Default | Set when | Notes |
|---|---|---|---|---|
| `step` | `int` | `2` (:15) | `goToStep(int)` (:53-57) | 2 = vehicle+license, 3 = vehicle documents. Mutated directly, `notifyListeners()` only when the value actually changes (:54). |
| `isEditMode` | `final bool` | `false` (ctor :12) | constructor only | **Never passed as true** — see mismatch M-08. |
| `profileImage` | `File?` | `null` (:20) | `_pickFile` via `setFile` (`driver_complete_profile_screen.dart:352-354`) | |
| `licenseImage` | `File?` | `null` (:21) | `:355-356` | |
| `vehicleLicenseImage` | `File?` | `null` (:22) | `:362-364` | |
| `insuranceImage` | `File?` | `null` (:23) | `:365-366` | |
| `carImage` | `File?` | `null` (:24) | `:367-368` | |
| `existingPhotoUrl` | `String?` | `null` (:26) | `_bootstrap` edit mode, from `user.photoUrl` (`:113`) | |
| `existingLicenseUrl` | `String?` | `null` (:27) | `_bootstrap` from `vehicle.licenseImageUrl` (`:127`) | |
| `existingVehicleLicenseUrl` | `String?` | `null` (:28) | `:128` | |
| `existingInsuranceUrl` | `String?` | `null` (:29) | `:129` | |
| `existingCarUrl` | `String?` | `null` (:30) | `:130` | |
| `vehicleType` | `String?` | `null` (:32) | `setVehicleType` (:59-64) from the bottom sheet (`:193-197`) or edit prefill (`:120-126`) | Backend enum value, e.g. `'sedan'`. |
| `plateController` | `TextEditingController` | `''` (:34) | user typing / edit prefill (`:117`) | |
| `modelController` | `TextEditingController` | `''` (:35) | user typing / edit prefill (`:118`) | |
| `seatsController` | `TextEditingController` | `''` (:36) | **only programmatically** — `setVehicleType(seats:)` (:62), `_loadVehicleTemplates` (`:85`), edit prefill (`:119`) | field is `readOnly: true` (step2 :107). |
| `vehicleTypeController` | `TextEditingController` | `''` (:39) | `setVehicleType` mirror of the label (:61) | read-only display mirror. |

Derived getters (all "file picked **or** existing URL non-empty"):
`hasProfilePhoto` (:41), `hasLicense` (:43), `hasVehicleLicense` (:45),
`hasInsurance` (:48), `hasCarPhoto` (:50).

Mutators:
* `goToStep(int)` (:53-57)
* `setVehicleType(String? type, {String? label, int? seats})` (:59-64) — writes
  `vehicleTypeController.text = label ?? type ?? ''`, and `seatsController.text`
  only if `seats != null`.
* `setFile(void Function(DriverProfileWizardState) update)` (:66-69) — the caller
  mutates a field inside the closure, then `notifyListeners()`.

**Navigation survival.** Steps 2 and 3 are *not* separate routes; they are two
branches of a single `ListenableBuilder` in one screen
(`driver_complete_profile_screen.dart:321-382`, ternary at `:348`). The state
object outlives both branches, so files and typed text survive step switching
with no serialization. Back from step 3 is intercepted by `PopScope`
(`:326-330`: `canPop: step == 2`; if `!didPop && step == 3` → `goToStep(2)`), and
by the header chevron (`:413-419`).

**Registration token is NOT in this object.** It lives in
`AuthProvider._pendingDriverRegistration` (`providers/auth_provider.dart:24`) and
is mirrored to `flutter_secure_storage` under key `pending_driver_registration`
(`core/storage/token_storage.dart:13,32-34`). It therefore **does survive an app
kill** (`auth_provider.dart:87-96` reloads and drops it if expired). Picked
`File`s, typed plate/model and the chosen vehicle type do **not** survive an app
kill — after a restart the resume path (`main.dart:443-448`) drops the user back
into a blank step 2.

---

## 3. Screens

### D-01: Driver sign-up (basic details) — `screens/auth/driver_sign_up_screen.dart` (481 lines)

**Purpose.** Wizard step 1 of 3. Collects name, phone, password and gender, then
triggers an SMS OTP. Nothing driver-specific is sent yet — only `send-otp`.

**Entry condition.** `pushReplacementNamed(RouteNames.driverSignUp)` from the
driver card on `AccountTypeSelectionScreen`
(`screens/auth/account_type_selection_screen.dart:161-164`). Route registered at
`main.dart:152-153`. Takes **no route arguments**.

**UI structure.**
```
Scaffold(backgroundColor: _heroBackdrop = Color(0xFFF6FBFA)   :26,144)
└ SingleChildScrollView
  └ FadeTransition(opacity: _fadeAnimation)                   :146
    └ Column
      ├ _buildHero()  SizedBox(height: 340 = _heroHeight)     :22,277
      │  ├ ColoredBox(_heroBackdrop)                          :286
      │  ├ Image.asset('assets/illustrations/auth/
      │  │      auth_driver_step1_hero.webp', fit: fitWidth)  :291-294
      │  ├ LinearGradient wash, stops [0, 0.42, 0.80]         :298-313
      │  └ SafeArea > Column
      │     ├ Row(textDirection: LTR, spaceBetween)           :322-344
      │     │  ├ IconButton chevron_left_rounded (LTR-forced) :326-341 → Navigator.pop
      │     │  └ AuthLanguageSwitcher()                       :342
      │     ├ Spacer(flex: 2)                                 :345
      │     ├ Padding(left: screenWidth * 0.22)               :350-354
      │     │  ├ 62×62 circle, primary fill, 3px white border,
      │     │  │   Icon(IconsaxPlusBold.driving, 30)          :358-375
      │     │  ├ Text driverSignupTitle  (26, w800)           :377-385
      │     │  ├ Text driverSignupSubtitle (13, variant)      :387-394
      │     │  └ SecurityNotice()                             :396
      │     └ Spacer(flex: 3)                                 :400
      └ Container(surface, top corners radius 28)             :151-159
        └ Padding(20, 22, 20, 28) > Form(key: _formKey)       :160-162
          ├ AuthStepIndicator(currentStep: 1, totalSteps: 3,
          │    labels:[authStepperBasicInfo, authStepperIdDocs,
          │            authStepperVehicleInfo])               :167-175
          ├ SizedBox(22)
          ├ AuthTextField  full name                          :177-185
          ├ SizedBox(14) · AuthPhoneField                     :187-193
          ├ SizedBox(14) · AuthTextField password             :195-219
          ├ SizedBox(14) · AuthTextField confirm password     :221-244
          ├ SizedBox(22) · _requiredLabel(genderRequiredLabel):246-249
          ├ SizedBox(10) · GenderSelectCards                  :251-254
          ├ SizedBox(26) · AuthPrimaryButton(continueLabel,
          │                  pinnedArrow: true)               :256-261
          └ SizedBox(12) · _buildSignInRow()                  :263
```
Entry animation: `AnimationController(duration: 800ms)` + `Curves.easeInOut`
fade, started in `initState` (:60-67).

`_requiredLabel` (:413-435) renders `"Gender *"` with the trailing `*` recoloured
to `T.error(context)` by splitting on `text.lastIndexOf('*')`.

**Step indicator text** (`widgets/auth/auth_step_indicator.dart:57-84`): three
numbered 30px circles joined by 2px connectors, captions at fontSize 11, w700 for
the current step. Labels: `authStepperBasicInfo` = "Basic information" / "المعلومات
الأساسية"; `authStepperIdDocs` = "ID & documents" / "الهوية والمستندات";
`authStepperVehicleInfo` = "Vehicle information" / "معلومات السيارة".

**Form fields.**

| field | widget | keyboard | validation (exact) | error message (en / ar) |
|---|---|---|---|---|
| Full name | `AuthTextField` `_nameController`, icon `user`, helper `fullNameIdHint` (:177-185) | default text | `v == null \|\| v.trim().length < 3` → error (:182-184) | `validNameRequired` = "Please enter a valid name" / "يرجى إدخال اسم صحيح" |
| Phone | `AuthPhoneField` + `CountryCodePicker` (width 116), helper `phoneConfirmCallHint`, hint `'07 XXX XXXX'`, default country `Countries.defaultCountry` (:49,187-193) | `TextInputType.phone`, forced `TextDirection.ltr` (`auth_phone_field.dart:83-84`) | empty → required; else `digits = v.replaceAll(RegExp(r'\s+'),'')` must match `^0?\d{7,15}$` (`auth_phone_field.dart:114-123`) | `phoneNumberRequired`, `invalidPhoneNumber` |
| Password | `AuthTextField` obscured, `textDirection: ltr`, helper `passwordMinLengthHint`, eye toggle (:195-219,437-449) | default | empty → required; else `RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$')` (:212-214) | `passwordRequired` = "Password is required"; `passwordPolicyError` = "Password must be 8+ chars with a letter and a number" / "يجب أن تحتوي كلمة السر على 8 أحرف مع حرف ورقم" |
| Confirm password | `AuthTextField` obscured (:221-244) | default | empty → required; `v != _passwordController.text` → mismatch (:235-243) | `confirmPasswordRequired`, `passwordsDoNotMatch` |
| Gender | `GenderSelectCards` (female left, male right, row pinned LTR) (:251-254, `widgets/auth/gender_select_cards.dart:26-48`) | n/a | **not** a `FormField` — checked imperatively in `_signUp` (:82-85) | `selectGenderError` = "Please select gender" / "يرجى اختيار الجنس" |

Gender values are `AppConstants.genderFemale` / `AppConstants.genderMale`
(`gender_select_cards.dart:33,42`).

**Document uploads.** None on this screen.

**Client-side validation (pre-flight, `_signUp` :80-85).**
1. `_formKey.currentState!.validate()` — all four text validators above; returns silently on failure.
2. `_selectedGender == null` → `_showSnackBar(l10n.selectGenderError, T.error(context))` and abort (:82-85).

**Backend call.**
* `AuthPhoneField.composeE164(_selectedCountry, _phoneController.text)` (:90-93 →
  `auth_phone_field.dart:147-153`): trims, strips all whitespace, drops a single
  leading `0` when the string does not start with `+`, prefixes `country.dialCode`.
* `await context.read<AuthProvider>().sendOTP(phoneNumber)` (:95) →
  `AuthService.sendOTP` → `POST /api/v1/auth/send-otp`.
* Success → `Navigator.pushReplacementNamed(RouteNames.otpVerification, arguments: {...})`
  (:103-121) with `phoneNumber`, `isRegistration: true`, `role: 'driver'`,
  `name` (trimmed full name), `firstName`/`lastName` split on the **first space**
  (:100-116 — everything after the first space becomes the last name; a
  single-word name yields `lastName: ''`), `gender`, `password` (raw, not
  trimmed), `afterVerifyRoute: RouteNames.driverCompleteProfile`.
* Failure → `ErrorSurface.showFailure(context, ApiClient.mapError(e))` (:123-126).

**State handling.** `_isLoading` (:50) toggles `AuthPrimaryButton(loading:)` and
sets `onPressed: null` (:258-260); reset in `finally` guarded by `mounted`
(:127-129). No global overlay; the rest of the form stays interactive.

**Errors.** Network/server errors go through `ExceptionMapper` → `Failure`;
`ErrorSurface.showFailure` shows a **snackbar** for `info`/`warning` severity and
an **AlertDialog** for `error` severity (`core/ui/error_surface.dart:30-37`). The
gender error uses a plain red `SnackBar` (`_showSnackBar` :132-137).

**Notes for reimplementation.**
* This screen never talks to any driver endpoint; it is a generic OTP kickoff. The driver-ness is only carried in the navigation arguments.
* The name is split into first/last purely so the downstream `PendingDriverRegistration` model can keep a first/last pair (:98-99); the register call re-joins them (`auth_provider.dart:287`).
* Password is passed through navigation arguments in plaintext and then persisted in secure storage — see §6.

---

### D-02: Complete profile — step 2 of 3 — `screens/auth/driver_complete/driver_complete_step2.dart` (192 lines) inside `driver_complete_profile_screen.dart` (493 lines)

**Purpose.** Profile photo, vehicle identity (type/plate/model/seats) and the
driving-license document. Pure local state — "Nothing is sent to the backend
here" (`driver_complete_step2.dart:13-14`).

**Entry condition.** Three ways in:
1. `pushReplacementNamed(RouteNames.driverCompleteProfile, {firstName,lastName,email,gender})` from the OTP screen after `verifyDriverPhone` succeeds (`otp_verification_screen.dart:144-153`). Those four arguments are **read by nobody** in this screen — `_bootstrap` only reads `args['editMode']` (`:100-104`).
2. `pushNamed(RouteNames.driverCompleteProfile, {'editMode': true})` from `DriverPendingApprovalScreen` (`screens/driver/driver_pending_approval_screen.dart:402-406`).
3. Cold start with an unexpired pending registration — `AuthWrapper` renders the widget directly (`main.dart:443-448`), so `ModalRoute.arguments` is null.

**Bootstrap.** `initState` (:65-69) fires `_loadVehicleTemplates()` and schedules
`_bootstrap()` in a post-frame callback. While `_isBootstrapping` the screen is a
full-bleed primary-coloured `Scaffold` with a `CircularProgressIndicator`
(:310-319).

`_bootstrap()` (:98-138):
```dart
final requestedEdit = args?['editMode'] == true;                        // :104
final pendingDriverAccount = user != null
    && user.role == AppConstants.roleDriver && !user.isDriverApproved;  // :105-108
_isEditMode = requestedEdit || (pendingDriverAccount && !requestedEdit);// :110
```
(The right-hand clause is redundant — the expression is equivalent to
`requestedEdit || pendingDriverAccount`.) In edit mode it copies
`user.photoUrl` into `existingPhotoUrl` (:113) and then `GET /api/v1/vehicles/my`
via `VehicleService.getMyVehicle()` (:115) to prefill plate, model, seats,
vehicle type + label + seats, and the four existing document URLs (:117-130). A
throw is swallowed: "A missing vehicle just means nothing to prefill" (:132-134).

**UI structure.**
```
Scaffold(backgroundColor: T.primary)                          :331-332
└ SingleChildScrollView > Column
  ├ _buildHeader(step)                    Stack height 250    :384-492
  │  ├ Image.asset('assets/illustrations/auth/
  │  │     auth_driver_step2_header.webp', BoxFit.cover)      :392-395
  │  └ SafeArea > Column
  │     ├ Row: back chevron (RTL-aware :408-410) + "Help" row :403-440
  │     ├ AuthStepIndicator(currentStep: step, totalSteps: 3) :444-452
  │     ├ Spacer
  │     ├ Text completeDriverProfileTitle (25, w800, white)   :455-462
  │     ├ Pill badge: driverStep2Badge / driverStep3Badge     :464-481
  │     └ SecurityNotice(onDark: true)                        :483
  └ Container(surface, top radius 28) > Padding(20,24,20,28)  :337-347
    └ step == 2 ? DriverCompleteStep2 : DriverCompleteStep3   :348
```
Step 2 body (`driver_complete_step2.dart:37-129`), a `Form` keyed by
`_step2FormKey` (`driver_complete_profile_screen.dart:42`):
```
Center > _buildPhotoPicker()  116×116 circle, 2px primary border,
         FileImage or NetworkImage or Icon(profile_circle, 58),
         34×34 primary camera badge bottom-end          :132-191
Text profilePhotoRequired  (13, w700)                   :44-53
Text profilePhotoClearHint (11, variant)                :54-62
SizedBox(20)
AuthTextField vehicleType   readOnly, chevron suffix    :64-78
SizedBox(14) AuthTextField plate                        :80-88
SizedBox(14) AuthTextField model                        :90-98
SizedBox(14) AuthTextField seats  readOnly, number kb   :100-116
SizedBox(22) DocumentUploadBox driver license           :118-124
SizedBox(26) AuthPrimaryButton(continueLabel)           :126
```
Badge copy: `driverStep2Badge` = "Step 2 of 3: Additional information" /
"الخطوة 2 من 3: المعلومات الإضافية".

**Form fields.**

| field | widget | keyboard | validation (exact) | error message |
|---|---|---|---|---|
| Vehicle type | `AuthTextField` bound to `state.vehicleTypeController`, `readOnly: true`, `onTap: onSelectVehicleType`, suffix `keyboard_arrow_down_rounded`, label `vehicleTypeRequired` ("Vehicle type *"), helper `vehicleTypeSelectHint` (:64-78) | none (read-only, opens a bottom sheet) | `state.vehicleType == null` → error (:75-77) — validates the model, not the text | `vehicleTypeValidation` = "Please select a vehicle type" / "يرجى اختيار نوع المركبة" |
| Plate number | `AuthTextField` `state.plateController`, icon `card`, label `vehiclePlateRequiredLabel` ("Plate number *"), helper `vehiclePlateDocHint` (:80-88) | default text | `v == null \|\| v.trim().isEmpty` (:85-87) | `vehiclePlateRequired` = "Plate number is required" |
| Car model | `AuthTextField` `state.modelController`, icon `car`, label `vehicleModelRequiredLabel` ("Car model *") (:90-98) | default text | `v == null \|\| v.trim().isEmpty` (:95-97) | `vehicleModelRequired` = "Vehicle model is required" |
| Seats | `AuthTextField` `state.seatsController`, icon `people`, `keyboardType: TextInputType.number`, **`readOnly: true`** with the comment "Seats always follow the vehicle-type template" (:100-107) | number (unreachable) | empty → required; `int.tryParse(v.trim())` null or `< 1` → invalid (:108-115) | `vehicleSeatsRequired`; `vehicleSeatsInvalid` = "The number of seats must be a whole number greater than 0" |

No `maxLength`, no `inputFormatters`, no character-set restriction on plate or
model anywhere — `AuthTextField` exposes none (`widgets/auth/auth_text_field.dart:11-26`).

**Document uploads on this step.**

| doc | widget | required |
|---|---|---|
| Profile photo | custom circular picker `_buildPhotoPicker` (:132-191), semantics label `uploadProfilePhoto` | yes — checked in `_continueToStep3` |
| Driver license | `DocumentUploadBox(label: driverLicenseRequired "Driver license *", hint: driverLicenseUploadHint "Tap to upload the license photo", file: state.licenseImage, previewUrl: state.existingLicenseUrl)` (:118-124) | yes — checked in `_continueToStep3` |

Picking mechanics — `_pickFile` (`driver_complete_profile_screen.dart:142-168`):
1. `showModalBottomSheet<ImageSource>` with exactly two `ListTile`s: gallery (`fromGallery` = "From gallery") and camera (`fromCamera` = "From camera") (:143-162). Dismissing returns null → abort (:163).
2. `await _storageService.pickImage(source: source)` (:165) →
   `ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1920, maxHeight: 1920)`
   (`core/services/storage_service.dart:12-25`). This is the **only** compression
   applied anywhere in the flow: JPEG quality **85**, long edge capped at
   **1920×1920**. `pickImage` swallows exceptions and returns `null` (:20-24), so
   a permission denial is silent.
3. `_state.setFile((_) => assign(File(picked.path)))` (:167) — a plain `dart:io`
   `File` is stored; no size check, no MIME check, no re-encode.

No multipart call is made on this step.

**Client-side validation (`_continueToStep3`, :202-213).**
1. `_step2FormKey.currentState?.validate() ?? false` → false aborts silently.
2. `!_state.hasProfilePhoto` → `_showValidation('Personal photo not uploaded')`.
3. `!_state.hasLicense` → `_showValidation('Driver license photo not uploaded')`.
4. `_state.goToStep(3)`.

`_showValidation(String developerDetail)` (:215-225) builds
`Failure(category: validation, messageKey: 'errorsValidationGeneric', severity: warning, developerDetail: <english string>)`.
Because the severity is `warning`, `ErrorSurface` renders a **snackbar** with the
localized generic copy `errorsValidationGeneric` = "Invalid input. Please check
your data and try again." / "البيانات المدخلة غير صحيحة. راجع البيانات وحاول مرة
أخرى." — the specific English detail is only printed to the debug console
(`core/ui/error_surface.dart:19-28`). **The user is never told which document is
missing.**

**Backend call.** None from step 2 itself. Two calls fire around it:
* `GET /api/v1/vehicles/types` — `_loadVehicleTemplates` (:77-89), see §5.
* `GET /api/v1/vehicles/my` — edit mode only (:115).

**State handling.** `_isBootstrapping` gates the whole screen (:310-319). The
step-2 continue button has **no loading state and no disable condition**
(`driver_complete_step2.dart:126` — `AuthPrimaryButton(label:…, onPressed: onContinue)`),
which is fine because it does no I/O.

**Errors.** Vehicle-catalog and vehicle-fetch failures are swallowed
(:86-88, :132-134). Validation failures surface as the generic warning snackbar.

**Notes for reimplementation.**
* The vehicle-type bottom sheet is built from the **hardcoded** `AppConstants.vehicleTypes` list and Arabic-only `AppConstants.vehicleTypeLabels` (:177-179) — **not** from the fetched catalog. See §5 and M-09.
* Seats is `readOnly` and only ever written programmatically; if a selected type has no seat count in either the catalog or the fallback map, the field stays empty and the form becomes unsubmittable with no way to fix it.
* A race exists between `_loadVehicleTemplates` (:84-85) and `_bootstrap` (:119): in edit mode, whichever finishes last wins the seats value. `_loadVehicleTemplates` reads `_state.vehicleType` which is null on a fresh start (so it is a no-op there), but in edit mode it can overwrite the account's actual seat count with the catalog default. verify: `driver_complete_profile_screen.dart:84-85` vs `:119`.

---

### D-03: Complete profile — step 3 of 3 — `screens/auth/driver_complete/driver_complete_step3.dart` (73 lines)

**Purpose.** Collect the three vehicle documents, then perform the entire backend
submission: upload all five images and create (or PATCH) the account.

**Entry condition.** `_state.goToStep(3)` from `_continueToStep3`
(`driver_complete_profile_screen.dart:212`). Same screen, same shell header, only
the body branch and the badge change (`:348`, `:474`).

**UI structure** (`driver_complete_step3.dart:36-71`):
```
Column(crossAxisAlignment: stretch)
├ DocumentUploadBox  vehicleRegistrationFormRequired  ("Registration form *")  :39-44
├ SizedBox(18)
├ DocumentUploadBox  insuranceDocumentLabel           ("Insurance *")          :46-51
├ SizedBox(18)
├ DocumentUploadBox  carPhotoRequired                 ("Car photo *")          :53-58
├ SizedBox(26)
├ AuthPrimaryButton(label: state.isEditMode ? saveChangesButton : complete,
│                   loading: isSubmitting,
│                   onPressed: isSubmitting ? null : onSubmit)                 :60-64
└ SizedBox(10) TextButton(back)  onPressed: isSubmitting ? null : onBack       :66-69
```
Badge copy: `driverStep3Badge` = "Step 3 of 3: Vehicle documents" / "الخطوة 3 من
3: مستندات السيارة".

`DocumentUploadBox` (`widgets/auth/document_upload_box.dart`): fixed
`height: 150`, full width (:53-55). Filled state shows the image
(`Image.file` or `Image.network` with a `gallery_slash` error placeholder),
a primary check badge top-end, and a translucent black `tapToChange` pill
bottom-start (:66-116). Empty state is a dashed rounded rect
(`_DashedBorderPainter`, dash 7 / gap 5, strokeWidth 1.6, radius 16, primary at
45% alpha — :120-122,178-215) containing a 52×52 primary tile with
`document_upload`, the `hint ?? tapToUpload` line (13, w600) and
`documentFormatsHint` (11, maxLines 2, ellipsis) (:124-173).

**`documentFormatsHint` = "Supported: JPG, PNG, PDF (max 5 MB)" / "الصيغ المدعومة:
JPG، PNG، PDF (الحد الأقصى 5 ميجابايت)"** — see mismatches M-03 and M-04.

**Form fields.** None. Step 3 is documents-only.

**Document uploads.**

| doc | widget line | file field | preview URL field | picker callback |
|---|---|---|---|---|
| Vehicle registration form | :39-44 | `state.vehicleLicenseImage` | `existingVehicleLicenseUrl` | `driver_complete_profile_screen.dart:362-364` |
| Insurance | :46-51 | `state.insuranceImage` | `existingInsuranceUrl` | `:365-366` |
| Car photo | :53-58 | `state.carImage` | `existingCarUrl` | `:367-368` |

All three use the same `_pickFile` gallery/camera sheet + `ImagePicker` settings
described in D-02.

**Client-side validation (`_submit`, `driver_complete_profile_screen.dart:227-239`).**
Runs in this order, each aborting:
1. `!_state.hasVehicleLicense` → `_showValidation('Vehicle license photo not uploaded')` → generic warning snackbar.
2. `!_state.hasInsurance` → `_showSnackBar(context.l10n.insuranceImageRequired, T.error(context))` → **specific** copy: `insuranceImageRequired` = "The insurance document is required" / "وثيقة التأمين مطلوبة". (Inconsistent with the other two, which use the generic key.)
3. `!_state.hasCarPhoto` → `_showValidation('Car photo not uploaded')` → generic warning snackbar.

Note there is **no re-check of the step-2 requirements** (profile photo, license,
vehicle type, plate, model, seats) at submit time. On the cold-start resume path
the user lands on step 2 so `_continueToStep3` still gates them; but the
non-null assertions at `:272-280` (`_state.profileImage!`, `_state.vehicleType!`,
`_state.licenseImage!`, …) and `int.parse(...)` at `:276` will throw if any of
those is somehow null/empty.

**Backend call — CREATE branch** (`driver_complete_profile_screen.dart:271-281` →
`providers/auth_provider.dart:230-321`).

1. Guard: `pending == null || pending.isExpired` → throws
   `Exception('انتهت صلاحية جلسة التسجيل. يرجى التحقق من رقم الهاتف مرة أخرى.')`
   ("Your registration session expired. Please verify your phone number again.")
   (`auth_provider.dart:245-251`). Note: **Arabic-only, hardcoded, not localized.**
2. Five **sequential** `POST /api/v1/uploads/registration` calls, in this order —
   profile photo (:254), driver license (:258), vehicle license (:262),
   insurance (:266), car (:270). Each goes through
   `AuthService.uploadRegistrationFile(File, String registrationToken)`
   (`core/services/auth_service.dart:179-196`):
   ```dart
   final fileName = file.path.split('/').last;          // :183  ← '/' only; a
                                                        //   Windows path would
                                                        //   not split, harmless
                                                        //   on iOS/Android
   final formData = FormData.fromMap({
     'file': await MultipartFile.fromFile(file.path, filename: fileName),
     'registrationToken': registrationToken,
   });                                                   // :184-187
   final response = await _api.post(ApiEndpoints.uploadsRegistration, data: formData);
   final url = response['url'] ?? response['data']?['url'];   // :192
   if (url == null) throw Exception('Failed to upload registration image');
   return url as String;
   ```
   Endpoint constant: `/uploads/registration`
   (`core/api/api_endpoints.dart:175`). `AuthInterceptor` lists it as a public
   path, so **no `Authorization` header is attached**
   (`core/api/auth_interceptor.dart:22,29-34`). Dio's default JSON
   `Content-Type` (`core/api/api_client.dart:19-22`) is replaced by Dio itself
   for `FormData`. Only `url` is consumed; the backend's `key` is discarded.
3. Best-effort device block: `PushNotificationService.initialize()` +
   `getToken()` in a try/catch that never blocks (:276-282), then
   `_deviceService.buildPayload(fcmToken:)` (:283-285) →
   `{deviceId, installSalt, platform, fcmToken?, locale?, isMockLocation}`
   (`core/services/device_fingerprint_service.dart:85-92`).
4. `name = '${pending.firstName} ${pending.lastName}'.trim()`, falling back to
   `pending.phoneNumber` when empty (:287-290).
5. `AuthService.registerDriver` (`core/services/auth_service.dart:201-251`) →
   `POST /api/v1/auth/driver/register` (`api_endpoints.dart:14`). Body assembly
   (:216-235): always `registrationToken`, `name`, `password`, `vehicleType`,
   `plateNumber`, `model`, `seats`, `carImageUrl`, `insuranceImageUrl`;
   conditionally `gender` (non-null **and** non-empty), `photoUrl`,
   `licenseImageUrl`, `vehicleLicenseImageUrl`, `device`. In practice all five
   optionals are always present because the wizard makes every document
   mandatory.
6. Response handling (:236-251): reads `response['data'] ?? response`, saves
   `accessToken`/`refreshToken` to secure storage, saves
   `data['user']['_id'] ?? data['user']['id']`, builds `UserModel`, and returns
   `VerifyOtpResult(accountState: data['accountState'] ?? 'active',
   deviceState: data['deviceState'] ?? 'new', pendingPhoneLinkRequired: … ?? false)`.
7. `AuthProvider` stores the user/account/device state (:305-308), **clears** the
   pending registration from memory and secure storage (:310-311), and registers
   the FCM device token (:313-315).
8. Screen: success snackbar `driverProfileSubmitted` = "Your details were
   uploaded successfully. Your request is under review by the administration." on
   `AppColors.success`, then
   `pushNamedAndRemoveUntil(RouteNames.driverPendingApproval, (route) => false)`
   (`driver_complete_profile_screen.dart:283-289`).

**Backend call — EDIT branch** (`driver_complete_profile_screen.dart:245-268` →
`providers/auth_provider.dart:327-403`).

* Requires `_userModel?.id`, else throws `Exception('المستخدم غير مسجل دخول')` (:349-350).
* Uploads only the files that were re-picked, via
  `StorageService.uploadImage(imageFile:, folder:, fileName: userId)` →
  **`POST /api/v1/uploads`** (the session-authenticated endpoint,
  `api_endpoints.dart:172`), with an extra `folder` form field
  (`storage_service.dart:36-44`). Folders used: `profiles`, `driver_licenses`,
  `vehicle_licenses`, `insurance`, `vehicles` (:362-386). Note `uploadImage`
  returns `null` on any error (`storage_service.dart:46-49`), which the local
  `upload()` wrapper turns into `Exception('فشل رفع الملف. حاول مرة أخرى.')` (:365-368).
* Builds a sparse map with only the changed keys: `photoUrl`, `licenseImageUrl`,
  `vehicleLicenseImageUrl`, `insuranceImageUrl`, `carImageUrl`, `vehicleType`,
  `plateNumber`, `model`, `seats` (:370-387). **`fileName` is passed but the
  multipart body never uses it** — `storage_service.dart:34` recomputes the name
  from the path (dead parameter).
* `if (data.isEmpty) return;` — a no-op save silently succeeds (:381-384).
* `PATCH /api/v1/auth/driver/registration`
  (`auth_service.dart:257-261`, `api_endpoints.dart:16`), followed by
  `GET /api/v1/auth/me` to refresh the cached user (`auth_service.dart:260`).
* Screen: snackbar `registrationUpdatedSuccess` = "Your details were updated
  successfully", then `pushNamedAndRemoveUntil(driverPendingApproval)` (:258-268).
* Because `plateNumber`/`model` are always non-null strings from the controllers
  and `vehicleType`/`seats` are prefilled, the PATCH always includes all four
  scalar fields even when untouched.

**State handling.** `_isSubmitting` (:62) is set before the work (:241) and
cleared in `finally` under `mounted` (:292-294). It drives
`AuthPrimaryButton(loading:)`, nulls the submit `onPressed`, and disables the
Back button (`driver_complete_step3.dart:62-68`). There is **no per-file progress
indication** across the five sequential uploads — one indeterminate spinner
covers the whole chain, which on a slow link is five full image uploads.

**Errors.** `catch (e) → ErrorSurface.showFailure(context, ApiClient.mapError(e))`
(:290-291). `ApiClient.mapError` passes a `Failure` through unchanged, otherwise
delegates to `ExceptionMapper.fromError` (`core/api/api_client.dart:71-74`).
`error`-severity failures render as an `AlertDialog`, `warning`/`info` as a
snackbar (`error_surface.dart:30-37`). A partial failure (e.g. the 4th upload
fails) leaves the first three uploaded blobs orphaned on the server and the
wizard on step 3 with all files still in memory — retrying re-uploads everything.

**Notes for reimplementation.**
* `state.isEditMode` is used only for the button label (`driver_complete_step3.dart:61`) and is **always false** (see M-08); the actual branch decision uses `_DriverCompleteProfileScreenState._isEditMode` (`driver_complete_profile_screen.dart:60,245`).
* The create branch uses `/uploads/registration`; the edit branch uses `/uploads`. Both are correct for their auth context, but they are different code paths with different folder semantics.
* Uploads are strictly sequential; parallelising them is the obvious improvement.

---

## 4. Document upload matrix

| document | required by backend? | required by app? | picked from | compressed? | max size enforced client-side? | maps to backend field |
|---|---|---|---|---|---|---|
| Profile photo | optional (`photoUrl?`) | **required** — `_continueToStep3` (`driver_complete_profile_screen.dart:204-207`) | gallery **or** camera (`_pickFile` :142-168) | yes — `imageQuality: 85`, `maxWidth/maxHeight: 1920` (`storage_service.dart:14-19`) | **no** | `photoUrl` (`auth_service.dart:228`) |
| Driver license | optional (`licenseImageUrl?`) | **required** — `_continueToStep3` (:208-211) | gallery or camera | same | **no** | `licenseImageUrl` (`auth_service.dart:229`) |
| Vehicle registration form ("الاستمارة") | optional (`vehicleLicenseImageUrl?`) | **required** — `_submit` (:228-231) | gallery or camera | same | **no** | `vehicleLicenseImageUrl` (`auth_service.dart:230-232`) |
| Insurance | **REQUIRED** | **required** — `_submit` (:232-235), specific error copy | gallery or camera | same | **no** | `insuranceImageUrl` (`auth_service.dart:225`) |
| Car photo | **REQUIRED** | **required** — `_submit` (:236-239) | gallery or camera | same | **no** | `carImageUrl` (`auth_service.dart:224`) |

Transport for all five (create flow):
`POST /api/v1/uploads/registration`, `FormData{file: MultipartFile, registrationToken: String}`,
no `Authorization` header (`auth_service.dart:179-196`, `auth_interceptor.dart:22`).
Transport in edit mode: `POST /api/v1/uploads`,
`FormData{file: MultipartFile, folder: String}`, bearer-authenticated
(`storage_service.dart:28-50`).

There is **no PDF path**: `ImagePicker.pickImage` returns images only. `file_picker`
is not a dependency (`grep -rn "file_picker" lib` → 0 hits). The
`documentFormatsHint` copy advertising PDF is therefore unachievable in the app.

---

## 5. Vehicle type catalog

**Fetch.** `VehicleService.getVehicleTypes({bool allowCachedFallback = true})`
(`core/services/vehicle_service.dart:15-42`):
* `GET /api/v1/vehicles/types` (`api_endpoints.dart:122`).
* Unwraps `response['data'] ?? response`, then `data['types']` as a list of maps →
  `VehicleTypeTemplate.fromJson`, discarding entries with an empty `type` (:20-30).
* On success, caches the whole list as JSON in `SharedPreferences` under
  `vehicle_type_templates` (:12,32-34,61-67).
* On error, falls back to the cache; if the cache is empty it rethrows (:36-41).

`VehicleTypeTemplate` (`models/vehicle_type_template.dart`): `type` (String),
`label` (`Map<String,String>`, locale → text), `seats` (int, tolerant parse),
`layout` (`SeatLayoutConfig`, defaults to `rows:1, seatsPerRow:1`). It exposes
`localizedLabel(languageCode)` (:45-47) — **which this flow never calls**.

**Display.** The picker sheet `_selectVehicleType`
(`driver_complete_profile_screen.dart:170-198`) iterates
**`AppConstants.vehicleTypes`** — a hardcoded list of six ids: `sedan`, `suv`,
`van`, `truck`, `motorcycle`, `bus`
(`core/constants/app_constants.dart:31-36,49-56`) — and labels each with
**`AppConstants.vehicleTypeLabels`**, an Arabic-only map:
`sedan → 'سيارة سيدان'`, `suv → 'سيارة دفع رباعي'`, `van → 'فان'`,
`truck → 'شاحنة'`, `motorcycle → 'دراجة نارية'`, `bus → 'حافلة'`
(`app_constants.dart:39-46`). Selected row gets a primary `tick_circle` trailing
icon (:180-185). So **the fetched catalog contributes nothing to the list or the
labels — only the seat count.**

**Seats.** `_seatsForType(String? type)` (:91-94):
```dart
return _templatesByType[type]?.seats ?? _fallbackSeatsByType[type];
```
with the offline fallback map (:51-58):
`sedan: 4, suv: 5, van: 7, truck: 2, bus: 20, motorcycle: 1`
("the local map keeps the auto-fill working on the very first run without
network" — :48-50). The result is written into `seatsController` by
`setVehicleType(seats:)` (`driver_profile_wizard_state.dart:62`). The seats field
is `readOnly` (`driver_complete_step2.dart:107`), so the driver can never
override it.

**Seat layout.** `SeatLayoutConfig` is parsed into the template but is **never
read** in the registration flow — the app does not send `seatLayout` to
`/auth/driver/register` (`auth_service.dart:216-235` has no such key). The backend
must derive the layout from its own catalog. (`seatLayout` is only sent by the
legacy `VehicleService.addVehicle` at `vehicle_service.dart:102` and by
`updateVehicle` at `:145`, neither of which is on this path.)

**Does the app send `seats` explicitly? YES.** `seats: int.parse(_state.seatsController.text.trim())`
(`driver_complete_profile_screen.dart:276`) → `body['seats'] = seats`
(`auth_service.dart:223`), unconditionally. Since the value normally originates
from the catalog it usually agrees, but in two cases it will not: (a) the catalog
fetch failed and the hardcoded fallback disagrees with the server catalog;
(b) edit mode, where the value came from the driver's existing vehicle
(`driver_complete_profile_screen.dart:119`). In both cases the client value
**overrides** whatever the backend would have derived.

---

## 6. Registration token lifecycle

**Creation.** `POST /auth/driver/verify-phone` in
`AuthService.verifyDriverPhone(phoneNumber, code)`
(`core/services/auth_service.dart:158-175`), returning a Dart record
`({String registrationToken, int expiresIn})`; `expiresIn` defaults to `1800`
when absent (:173). A missing/empty token throws
`Exception('Failed to start driver registration')` (:167-170).

**Storage.** `AuthProvider.verifyDriverPhone` (`providers/auth_provider.dart:190-224`)
wraps it in a `PendingDriverRegistration`
(`models/pending_driver_registration.dart`) holding
`registrationToken`, `expiresAtEpochMs = DateTime.now().millisecondsSinceEpoch + expiresIn * 1000`
(:207-208), plus `phoneNumber`, `firstName`, `lastName`, `email?`, `gender?` and
**the plaintext `password`** (model :19). It is JSON-encoded and written to
`flutter_secure_storage` under key `pending_driver_registration`
(`core/storage/token_storage.dart:13,32-34`) and cached in
`AuthProvider._pendingDriverRegistration` (:24).

**So: the token is NOT memory-only.** It survives an app kill. What does *not*
survive is the wizard's own state — the five picked `File`s, the chosen vehicle
type, and the typed plate/model (§2).

**Validity assumption.** `PendingDriverRegistration.isExpired` is a pure clock
comparison against the stored epoch (`model:32-33`), i.e. the app trusts the
device clock and the server's `expiresIn`. It is consulted in exactly two places:
* `AuthProvider._loadPendingDriverRegistration()` on startup (:87-96) — an
  expired record is deleted from secure storage and the field left null.
* The public getter `pendingDriverRegistration` (:50-54) — returns null when
  expired, which is what `main.dart:445` uses to decide whether to resume.

**Expiry handling: no countdown, no refresh, no proactive warning.** The wizard
shows nothing about the 30-minute budget; the step-2/step-3 UI has no timer. If
the token expires mid-wizard the failure only appears when the user presses
Submit: `registerDriver` throws the hardcoded Arabic
`'انتهت صلاحية جلسة التسجيل. يرجى التحقق من رقم الهاتف مرة أخرى.'`
(`auth_provider.dart:246-251`), which is surfaced through
`ApiClient.mapError` → `ExceptionMapper` → `ErrorSurface`. **The app does not
navigate back to the phone/OTP screen and does not clear the stale record** —
the user is stranded on step 3 with a dialog and must back out manually.
`cancelPendingDriverRegistration()` exists (:430-433) but **no screen calls it**
(`grep -rn "cancelPendingDriverRegistration" lib` → declaration only).

Similarly, the *uploads* can fail with a token-expiry error from the server
mid-chain; nothing distinguishes that from any other upload failure.

**Backgrounding mid-wizard.** `AuthWrapper.didChangeAppLifecycleState`
(`main.dart:420-428`) only refreshes the profile for *authenticated* users, and
during the driver wizard there is no session yet, so a resume is a no-op — the
screen, its `_state` and all picked files are still in memory and the wizard
continues exactly where it was. Only a process kill loses them; after a kill,
`AuthWrapper` (`main.dart:443-448`) re-enters `DriverCompleteProfileScreen` at
step 2 with an empty form, still holding a valid token if within 30 minutes.

---

## 7. Mismatch register

| # | Area | What the app does | What the backend requires / expects | Impact |
|---|---|---|---|---|
| M-01 | `insuranceImageUrl` | **Collected and always sent.** Picked in step 3 (`driver_complete_step3.dart:46-51`), enforced by `_submit` (`driver_complete_profile_screen.dart:232-235`), uploaded at `auth_provider.dart:266-269`, sent at `auth_service.dart:225`. | REQUIRED | ✅ No mismatch. |
| M-02 | `carImageUrl` | **Collected and always sent.** `driver_complete_step3.dart:53-58`, enforced `:236-239`, uploaded `auth_provider.dart:270-273`, sent `auth_service.dart:224`. | REQUIRED | ✅ No mismatch. |
| M-03 | File size limit | **No client-side size check anywhere.** Verified: no `lengthSync`, `fileSize`, `10 * 1024`, or `maxFileSize` in `lib`. Only `imageQuality: 85` + 1920px cap (`storage_service.dart:14-19`) bounds the size incidentally. | max **10 MB** per file | A camera photo from a modern phone at q85/1920px is typically well under 1 MB, so this rarely bites — but a large PNG/screenshot from the gallery can exceed 10 MB and produces an opaque server error at submit time, after up to four other uploads have already succeeded. |
| M-04 | Advertised formats | `documentFormatsHint` says "Supported: JPG, PNG, PDF (**max 5 MB**)" (`document_upload_box.dart:161`). | MIME allowlist is `image/jpeg`, `image/png`, `image/webp`, `application/pdf`; limit is **10 MB** | Copy is wrong twice: the stated limit (5 MB) contradicts the backend (10 MB), and **PDF is unattainable** — the app uses `ImagePicker.pickImage` only (`storage_service.dart:12-19`) with no `file_picker` dependency. `image/webp` is accepted by the backend but never advertised. |
| M-05 | MIME enforcement | **None client-side.** The `MultipartFile` is built from the path with no explicit `contentType` (`auth_service.dart:185`, `storage_service.dart:37-40`), so Dio infers or omits it. | MIME must be in the allowlist | A HEIC/HEIF pick on iOS: `image_picker` normally transcodes to JPEG when `imageQuality` is set, so this is usually safe — verify against the plugin version in `rideshare/pubspec.yaml`. |
| M-06 | `device` | **Sent** on create. Built best-effort with FCM token, `deviceId`, `installSalt`, `platform`, `locale`, `isMockLocation` (`auth_provider.dart:276-285`, `device_fingerprint_service.dart:85-92`); passed as `body['device']` only when non-null (`auth_service.dart:234`). `buildPayload` is awaited unconditionally, so `device` is effectively always present. | optional | ✅ No mismatch. |
| M-07 | Upload response `key` | The app reads only `response['url'] ?? response['data']?['url']` and **discards `key`** (`auth_service.dart:192`). | returns `{url, key}` | The client cannot later reference or delete a blob by key. Orphaned uploads from a failed submit are never cleaned up client-side. |
| M-08 | `isEditMode` on the wizard state | `DriverProfileWizardState()` is constructed with **no arguments** (`driver_complete_profile_screen.dart:46`) so `state.isEditMode` is permanently `false`, while the real decision lives in `_DriverCompleteProfileScreenState._isEditMode` (`:60,110,245`). | n/a (client bug) | The step-3 primary button shows "Complete" (`complete`) instead of "Save changes" (`saveChangesButton`) even in edit mode (`driver_complete_step3.dart:61`). Cosmetic but confusing. |
| M-09 | Vehicle-type catalog | The picker lists the **hardcoded** six ids from `AppConstants.vehicleTypes` with **Arabic-only** labels (`driver_complete_profile_screen.dart:177-179`, `app_constants.dart:39-56`). The fetched `GET /vehicles/types` result is used **only** for the seat count (`:91-94`). `VehicleTypeTemplate.localizedLabel` is never called. | catalog is server-owned | Adding or renaming a vehicle type server-side does not reach the app; and an English-locale driver sees Arabic labels. |
| M-10 | `seats` | **Always sent explicitly** (`driver_complete_profile_screen.dart:276` → `auth_service.dart:223`), sourced from the catalog **or** the hardcoded fallback map `{sedan:4, suv:5, van:7, truck:2, bus:20, motorcycle:1}` (`:51-58`) **or** the existing vehicle in edit mode (`:119`). | optional; backend derives from the catalog when omitted | Client value **overrides** the catalog-derived value. If the fallback map drifts from the server catalog (offline first run), a vehicle is created with the wrong seat count. |
| M-11 | `seatLayout` | Never sent (no such key in `auth_service.dart:216-235`), even though it is parsed into `VehicleTypeTemplate.layout`. | derived server-side | ✅ Fine, but note the parsed layout is dead weight on this path. |
| M-12 | Token expiry UX | No countdown, no refresh, no proactive redirect. Expiry only surfaces as a **hardcoded Arabic** exception at submit time (`auth_provider.dart:246-251`), and the stale record is not cleared. | 30-minute TTL | The user is stranded on step 3 having re-picked five images. `cancelPendingDriverRegistration()` (`:430-433`) exists but is never wired to any UI. |
| M-13 | Missing-document error copy | Two of the three step-3 checks and both step-2 checks use the generic `errorsValidationGeneric` snackbar; the English specifics ("Car photo not uploaded" etc.) go only to `debugPrint` (`driver_complete_profile_screen.dart:215-225`, `error_surface.dart:19-28`). Only insurance has a specific message (`:232-235`). | n/a | The user is not told *which* document is missing in 4 of 5 cases. |
| M-14 | `name` splitting | `firstName`/`lastName` are split on the **first space** at D-01 (`driver_sign_up_screen.dart:100-116`), persisted separately, then re-joined with a single space before the register call (`auth_provider.dart:287`). | expects a single `name` | Lossy round-trip for names with multiple spaces (repeated internal whitespace is collapsed only at the split boundary; the remainder is `.trim()`ed). Also, if both parts end up empty the app sends the **phone number as the name** (`auth_provider.dart:289-290`). |
| M-15 | Password at rest | The plaintext password is carried through navigation arguments (`driver_sign_up_screen.dart:118`) and stored in `flutter_secure_storage` inside the pending-registration JSON for up to 30 minutes (`pending_driver_registration.dart:19,43`). | n/a | Secure storage mitigates this, but the password is also readable from the `LogInterceptor` request-body dump in debug builds (`api_client.dart:26-31`). |
| M-16 | Edit-mode upload endpoint | Edit mode uploads through `POST /uploads` with a `folder` form field (`storage_service.dart:36-44`) rather than `/uploads/registration`. | `/uploads` is the session-authenticated endpoint | ✅ Correct for an authenticated pending driver — noted only so a rebuild keeps both endpoints. Confirm the backend actually honours the `folder` field; if it ignores it, all five folders collapse into one. verify: backend `uploads` controller. |
| M-17 | No submit-time re-validation of step 2 | `_submit` checks only the three step-3 documents; it then force-unwraps `profileImage!`, `vehicleType!`, `licenseImage!`, `vehicleLicenseImage!`, `insuranceImage!`, `carImage!` and `int.parse(seats)` (`driver_complete_profile_screen.dart:271-281`). | n/a | Any path that reaches step 3 without step-2 data (future refactor, deep link) crashes with a `Null check operator` / `FormatException` instead of a validation message. |
| M-18 | Partial-upload recovery | On a mid-chain failure the already-uploaded blobs are orphaned and a retry re-uploads all five (`auth_provider.dart:254-273`). | n/a | Wasted bandwidth and orphaned storage; consider caching the returned URLs in the wizard state. |
| M-19 | Legacy dead path | `otp_verification_screen.dart:112,181,218-263` + `auth_provider.dart:576-633` (`saveDriverProfile`) + `vehicle_service.dart:70-115` (`addVehicle`) implement the **old** create-account-then-add-vehicle flow. The `isDriverCompleteProfile` argument that activates it is never set by any caller. | n/a | Do not port. It calls `PATCH /users/me/role` and `POST /vehicles`, which contradict the deferred-registration design. |

---

## Appendix — file inventory

| file | lines | role |
|---|---|---|
| `screens/auth/driver_sign_up_screen.dart` | 481 | D-01 wizard step 1 |
| `screens/auth/driver_complete_profile_screen.dart` | 493 | shell for steps 2–3, pickers, submit |
| `screens/auth/driver_complete/driver_complete_step2.dart` | 192 | D-02 body |
| `screens/auth/driver_complete/driver_complete_step3.dart` | 73 | D-03 body |
| `screens/auth/driver_complete/driver_profile_wizard_state.dart` | 79 | shared `ChangeNotifier` |
| `widgets/auth/document_upload_box.dart` | 215 | dashed document tile |
| `widgets/auth/auth_step_indicator.dart` | ~90 | 1/2/3 chrome |
| `widgets/auth/auth_text_field.dart` | — | boxed input |
| `widgets/auth/auth_phone_field.dart` | 154 | dial-code + number, `composeE164` |
| `widgets/auth/gender_select_cards.dart` | — | male/female cards |
| `widgets/auth/security_notice.dart` | 39 | shield reassurance line |
| `core/services/vehicle_service.dart` | 169 | `/vehicles/types`, `/vehicles/my`, legacy `addVehicle` |
| `core/services/storage_service.dart` | 94 | `ImagePicker` wrapper + `/uploads` |
| `core/services/auth_service.dart` | — | `verifyDriverPhone` :158, `uploadRegistrationFile` :179, `registerDriver` :201, `updatePendingDriverRegistration` :257 |
| `providers/auth_provider.dart` | — | `verifyDriverPhone` :190, `registerDriver` :230, `updatePendingDriverRegistration` :327, `cancelPendingDriverRegistration` :430 |
| `models/pending_driver_registration.dart` | 71 | persisted token + basic info |
| `models/vehicle_type_template.dart` | 48 | catalog entry |
| `core/storage/token_storage.dart` | ~50 | secure storage keys |
| `core/api/api_endpoints.dart` | — | `:13-16` driver endpoints, `:121-124` vehicles, `:172-175` uploads |
| `core/api/auth_interceptor.dart` | — | `:15-27` public-path allowlist |
