# Auth Registration Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pixel-close redesign of account-type, passenger signup (3 steps), driver signup (3 steps), and driver pending-review screens, plus backend `insuranceImageUrl` and pending-registration update API.

**Architecture:** Redesign existing Flutter auth screens in place; split driver complete-profile into a 2→3 wizard with shared state; extend NestJS register-driver + new authenticated PATCH for pending drivers; ship illustrations already under `rideshare/assets/illustrations/auth/`.

**Tech Stack:** NestJS 11 / TypeORM / Jest (backend); Flutter 3.9 / Dart 3 / Provider / Iconsax (mobile)

**Spec:** `docs/superpowers/specs/2026-07-28-auth-registration-redesign-design.md`  
**Assets:** `docs/superpowers/assets/2026-07-28-auth-registration/`

## Global Constraints

- Redesign existing routes/screens — no parallel `/auth/v2` tree
- Passenger steps: 1 basic → 2 OTP → 3 photo+city
- Driver wizard steps: 1 basic → (OTP verify-phone, not counted) → 2 vehicle+license → 3 form+insurance+car
- Stepper labels (driver): المعلومات الأساسية / الهوية والمستندات / معلومات السيارة
- `insuranceImageUrl` required on new register; NULL allowed historically in DB
- Pending edit only while `isDriverApproved === false`
- Prefer Iconsax + shipped illustrations; crops under `images/auth/` are QA/fallback only
- All new copy in `app_ar.arb` + `app_en.arb`
- Do not commit unless the user explicitly asks

---

## File map

| File | Responsibility |
|------|----------------|
| New migration `rideshare-backend/src/database/migrations/1746900000000-add-insurance-image-url-to-vehicles.ts` | Add `insuranceImageUrl` column |
| `rideshare-backend/src/database/entities/vehicle.entity.ts` | Column mapping |
| `rideshare-backend/src/modules/vehicles/dto/create-vehicle.dto.ts` | Optional insurance URL |
| `rideshare-backend/src/modules/auth/dto/register-driver.dto.ts` | Required `insuranceImageUrl` |
| `rideshare-backend/src/modules/auth/dto/update-pending-driver-registration.dto.ts` | PATCH body |
| `rideshare-backend/src/modules/auth/auth.service.ts` | Persist insurance; PATCH pending |
| `rideshare-backend/src/modules/auth/auth.controller.ts` | `PATCH auth/driver/registration` |
| `rideshare-backend/src/modules/auth/auth.service.spec.ts` (create/extend) | Register + PATCH tests |
| `rideshare-backend/src/modules/vehicles/vehicles.service.ts` | Map insurance on create/update |
| `rideshare/lib/widgets/auth/auth_step_indicator.dart` | Shared 1/2/3 chrome |
| `rideshare/lib/widgets/auth/gender_select_cards.dart` | Male/female cards |
| `rideshare/lib/widgets/auth/document_upload_box.dart` | Dashed upload |
| `rideshare/lib/widgets/auth/auth_primary_button.dart` | Teal CTA |
| `rideshare/lib/widgets/auth/security_notice.dart` | Shield + privacy text |
| `rideshare/lib/screens/auth/account_type_selection_screen.dart` | Redesign |
| `rideshare/lib/screens/auth/sign_up_screen.dart` | Passenger step 1 |
| `rideshare/lib/screens/auth/otp_verification_screen.dart` | Step chrome for passenger |
| `rideshare/lib/screens/auth/profile_setup_screen.dart` | Passenger step 3 photo+city |
| `rideshare/lib/screens/auth/driver_sign_up_screen.dart` | Driver step 1 |
| `rideshare/lib/screens/auth/driver_complete/driver_profile_wizard_state.dart` | Shared step 2–3 state |
| `rideshare/lib/screens/auth/driver_complete/driver_complete_step2.dart` | Vehicle + license |
| `rideshare/lib/screens/auth/driver_complete/driver_complete_step3.dart` | Form + insurance + car |
| `rideshare/lib/screens/auth/driver_complete_profile_screen.dart` | Shell orchestration |
| `rideshare/lib/screens/driver/driver_pending_approval_screen.dart` | Pending UI + edit |
| `rideshare/lib/core/services/auth_service.dart` | insurance + PATCH + city |
| `rideshare/lib/core/api/api_endpoints.dart` | New endpoint constant |
| `rideshare/lib/providers/auth_provider.dart` | Wire new APIs |
| `rideshare/lib/l10n/app_ar.arb` + `app_en.arb` | Strings |
| `rideshare/pubspec.yaml` | Already has `illustrations/auth` + `images/auth` |

---

### Task 1: Backend — `insuranceImageUrl` column + register required

**Files:**
- Create: `rideshare-backend/src/database/migrations/1746900000000-add-insurance-image-url-to-vehicles.ts`
- Modify: `rideshare-backend/src/database/entities/vehicle.entity.ts`
- Modify: `rideshare-backend/src/modules/vehicles/dto/create-vehicle.dto.ts`
- Modify: `rideshare-backend/src/modules/auth/dto/register-driver.dto.ts`
- Modify: `rideshare-backend/src/modules/auth/auth.service.ts` (vehicle create mapping)
- Modify: `rideshare-backend/src/modules/vehicles/vehicles.service.ts` (create/update mapping if needed)
- Test: `rideshare-backend/src/modules/auth/auth.service.spec.ts` (create if missing)

**Interfaces:**
- Consumes: existing `RegisterDriverDto`, `VehicleEntity`
- Produces: `insuranceImageUrl: string` required on register; nullable column on vehicles

- [x] **Step 1: Write failing unit test for required insurance on register**

Create or extend `rideshare-backend/src/modules/auth/auth.service.spec.ts`:

```ts
describe('registerDriver insurance', () => {
  it('persists insuranceImageUrl on the vehicle', async () => {
    // Arrange mocks: verifyRegistrationToken → phone, empty findByPhone, transaction saves user+vehicle
    const dto = {
      registrationToken: 'tok',
      name: 'Driver',
      password: 'Password1',
      vehicleType: 'sedan',
      plateNumber: 'ABC123',
      model: 'Camry',
      seats: 4,
      carImageUrl: 'https://cdn/car.jpg',
      licenseImageUrl: 'https://cdn/lic.jpg',
      vehicleLicenseImageUrl: 'https://cdn/form.jpg',
      insuranceImageUrl: 'https://cdn/ins.jpg',
    };
    // Act
    await service.registerDriver(dto as any);
    // Assert vehicleRepo.create called with insuranceImageUrl: 'https://cdn/ins.jpg'
    expect(vehicleCreateMock).toHaveBeenCalledWith(
      expect.objectContaining({ insuranceImageUrl: 'https://cdn/ins.jpg' }),
    );
  });
});
```

If the suite is heavy to mock, alternatively add a DTO validation test:

```ts
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { RegisterDriverDto } from './register-driver.dto';

it('rejects register payload without insuranceImageUrl', async () => {
  const dto = plainToInstance(RegisterDriverDto, {
    registrationToken: 'x',
    name: 'A',
    password: 'Password1',
    vehicleType: 'sedan',
    plateNumber: '1',
    model: 'M',
    carImageUrl: 'https://cdn/car.jpg',
  });
  const errors = await validate(dto);
  expect(errors.some((e) => e.property === 'insuranceImageUrl')).toBe(true);
});
```

- [x] **Step 2: Run test — expect FAIL**

Run (cwd `rideshare-backend`):

```bash
npm test -- --testPathPatterns=register-driver --no-coverage
```

If using auth.service.spec path:

```bash
npm test -- --testPathPatterns=auth.service.spec --no-coverage
```

Expected: FAIL (property missing / not persisted)

- [x] **Step 3: Migration + entity + DTOs + service mapping**

Migration:

```ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddInsuranceImageUrlToVehicles1746900000000
  implements MigrationInterface
{
  name = 'AddInsuranceImageUrlToVehicles1746900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE vehicles
      ADD COLUMN IF NOT EXISTS "insuranceImageUrl" TEXT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE vehicles
      DROP COLUMN IF EXISTS "insuranceImageUrl"
    `);
  }
}
```

On `VehicleEntity` after `carImageUrl`:

```ts
@Column({ type: 'text', nullable: true })
insuranceImageUrl: string | null;
```

On `RegisterDriverDto` — **required** (not `@IsOptional`):

```ts
@IsString()
@IsNotEmpty({ message: 'Insurance image is required' })
@MaxLength(500)
insuranceImageUrl: string;
```

On `CreateVehicleDto` — optional for non-registration creates:

```ts
@IsOptional()
@IsString()
@MaxLength(500)
insuranceImageUrl?: string;
```

In `auth.service.ts` `registerDriver` vehicle create:

```ts
insuranceImageUrl: dto.insuranceImageUrl,
```

In `vehicles.service.ts` create/update, pass through `insuranceImageUrl` when present (mirror `carImageUrl` handling).

- [x] **Step 4: Run tests — expect PASS**

```bash
npm test -- --testPathPatterns=register-driver --no-coverage
```

- [ ] **Step 5: Commit (only if user asked)**

```bash
git add rideshare-backend/src/database/migrations/1746900000000-add-insurance-image-url-to-vehicles.ts rideshare-backend/src/database/entities/vehicle.entity.ts rideshare-backend/src/modules/vehicles/dto/create-vehicle.dto.ts rideshare-backend/src/modules/auth/dto/register-driver.dto.ts rideshare-backend/src/modules/auth/auth.service.ts rideshare-backend/src/modules/vehicles/vehicles.service.ts
git commit -m "feat(backend): require insuranceImageUrl on driver register"
```

---

### Task 2: Backend — PATCH pending driver registration

**Files:**
- Create: `rideshare-backend/src/modules/auth/dto/update-pending-driver-registration.dto.ts`
- Modify: `rideshare-backend/src/modules/auth/auth.controller.ts`
- Modify: `rideshare-backend/src/modules/auth/auth.service.ts`
- Test: extend `auth.service.spec.ts` or new `update-pending-driver-registration.spec.ts`

**Interfaces:**
- Consumes: JWT user id; `VehicleEntity` by `driverId`
- Produces: `PATCH /auth/driver/registration` → updated sanitized user (+ vehicle summary optional)

- [x] **Step 1: Write failing tests**

```ts
it('updates vehicle docs when driver is not approved', async () => {
  // user.isDriverApproved = false; vehicle exists
  await service.updatePendingRegistration(userId, {
    insuranceImageUrl: 'https://cdn/new-ins.jpg',
    plateNumber: 'NEW1',
  });
  expect(vehicle.insuranceImageUrl).toBe('https://cdn/new-ins.jpg');
  expect(vehicle.plateNumber).toBe('NEW1');
  expect(user.isDriverApproved).toBe(false);
});

it('rejects when driver already approved', async () => {
  // user.isDriverApproved = true
  await expect(
    service.updatePendingRegistration(userId, { model: 'X' }),
  ).rejects.toThrow(/approved|forbidden/i);
});
```

- [x] **Step 2: Run — expect FAIL (method missing)**

```bash
npm test -- --testPathPatterns=auth.service.spec --no-coverage
```

- [x] **Step 3: Implement DTO + service + controller**

DTO:

```ts
import {
  IsString,
  IsOptional,
  IsInt,
  MaxLength,
  Min,
  Max,
  ValidateIf,
} from 'class-validator';
import { Type } from 'class-transformer';

export class UpdatePendingDriverRegistrationDto {
  @IsOptional() @IsString() @MaxLength(500) photoUrl?: string;
  @IsOptional() @IsString() @MaxLength(100) vehicleType?: string;
  @IsOptional() @IsString() @MaxLength(20) plateNumber?: string;
  @IsOptional() @IsString() @MaxLength(100) model?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(50) seats?: number;
  @IsOptional() @IsString() @MaxLength(500) licenseImageUrl?: string;
  @IsOptional() @IsString() @MaxLength(500) vehicleLicenseImageUrl?: string;
  @IsOptional() @IsString() @MaxLength(500) insuranceImageUrl?: string;
  @IsOptional() @IsString() @MaxLength(500) carImageUrl?: string;
}
```

Service method sketch:

```ts
async updatePendingRegistration(
  userId: string,
  dto: UpdatePendingDriverRegistrationDto,
): Promise<{ user: ReturnType<AuthService['sanitizeUser']>; vehicle: VehicleEntity }> {
  const user = await this.userRepo.findOne({ where: { id: userId } });
  if (!user || user.role !== PgUserRole.DRIVER) {
    throw new ForbiddenException('Driver account required');
  }
  if (user.isDriverApproved) {
    throw new ForbiddenException(
      'Approved drivers cannot update registration via this endpoint',
    );
  }
  const hasAny = Object.values(dto).some((v) => v !== undefined && v !== null);
  if (!hasAny) {
    throw new BadRequestException('At least one field is required');
  }

  return this.userRepo.manager.transaction(async (em) => {
    const userRepo = em.getRepository(UserEntity);
    const vehicleRepo = em.getRepository(VehicleEntity);
    if (dto.photoUrl !== undefined) {
      user.photoUrl = dto.photoUrl;
      await userRepo.save(user);
    }
    const vehicle = await vehicleRepo.findOne({ where: { driverId: userId } });
    if (!vehicle) throw new NotFoundException('Vehicle not found');
    if (dto.vehicleType !== undefined) vehicle.vehicleType = dto.vehicleType;
    if (dto.plateNumber !== undefined) vehicle.plateNumber = dto.plateNumber;
    if (dto.model !== undefined) vehicle.model = dto.model;
    if (dto.seats !== undefined) vehicle.seats = dto.seats;
    if (dto.licenseImageUrl !== undefined)
      vehicle.licenseImageUrl = dto.licenseImageUrl;
    if (dto.vehicleLicenseImageUrl !== undefined)
      vehicle.vehicleLicenseImageUrl = dto.vehicleLicenseImageUrl;
    if (dto.insuranceImageUrl !== undefined)
      vehicle.insuranceImageUrl = dto.insuranceImageUrl;
    if (dto.carImageUrl !== undefined) vehicle.carImageUrl = dto.carImageUrl;
    await vehicleRepo.save(vehicle);
    return { user: this.sanitizeUser(user), vehicle };
  });
}
```

Controller (JWT + driver role):

```ts
@Patch('driver/registration')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('driver')
@ApiBearerAuth()
async updatePendingDriverRegistration(
  @CurrentUser('id') userId: string,
  @Body() dto: UpdatePendingDriverRegistrationDto,
) {
  return this.authService.updatePendingRegistration(userId, dto);
}
```

Wire imports/`RolesGuard` if not already on that controller method style — follow neighboring endpoints.

- [x] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit only if user asked**

---

### Task 3: Shared Flutter auth widgets + l10n keys

**Files:**
- Create: `rideshare/lib/widgets/auth/auth_step_indicator.dart`
- Create: `rideshare/lib/widgets/auth/gender_select_cards.dart`
- Create: `rideshare/lib/widgets/auth/document_upload_box.dart`
- Create: `rideshare/lib/widgets/auth/auth_primary_button.dart`
- Create: `rideshare/lib/widgets/auth/security_notice.dart`
- Modify: `rideshare/lib/l10n/app_ar.arb`, `rideshare/lib/l10n/app_en.arb`
- Test: `rideshare/test/widget/auth/auth_step_indicator_test.dart`

**Interfaces:**
- Produces widgets consumed by all auth screens below

- [x] **Step 1: Add ARB keys (EN + AR)**

Minimum keys:

```json
"authStepOf": "Step {current} of {total}",
"authSecurityNotice": "All your data is kept secure and will not be shared with any party",
"authContinue": "Continue",
"authNeedHelp": "Help",
"genderRequiredLabel": "Gender *",
"documentUploadHint": "Tap to upload",
"documentFormatsHint": "Supported: JPG, PNG, PDF (max 5 MB)",
"driverDocLicense": "License",
"driverDocRegistration": "Registration form",
"driverDocInsurance": "Insurance",
"driverDocCarPhoto": "Car photo",
"driverPendingStatusLabel": "Application status",
"driverPendingBadge": "Under review",
"driverSubmittedDocs": "Submitted documents",
"driverPendingRestrictionTitle": "Your account is under review",
"driverPendingRestrictionBody": "You will not be able to use the app as a driver until your account is activated.",
"driverEditRegistrationTitle": "Need to edit your details?",
"driverEditRegistrationSubtitle": "You can update your details or submitted documents.",
"driverReturnHome": "Return to Home",
"passengerSignupTitle": "Create a new account",
"passengerSignupSubtitle": "Register now as a passenger to start your journey with us",
"driverSignupTitle": "Create driver account",
"driverSignupSubtitle": "Start receiving passengers and earning extra income",
"completeDriverProfileTitle": "Complete driver profile",
"driverStep2Badge": "Step 2 of 3: Additional information",
"driverStep3Badge": "Step 3 of 3: Vehicle documents",
"insuranceDocumentLabel": "Insurance *",
"accountTypePassengerTitle": "Passenger",
"accountTypeDriverTitle": "Driver"
```

Mirror Arabic in `app_ar.arb`. Run codegen:

```bash
flutter gen-l10n
```

Working directory: `rideshare`

- [x] **Step 2: Widget test for step indicator**

```dart
testWidgets('highlights current step', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AuthStepIndicator(currentStep: 2, totalSteps: 3),
    ),
  );
  expect(find.text('2'), findsOneWidget);
});
```

- [x] **Step 3: Implement widgets**

`AuthStepIndicator({required int currentStep, required int totalSteps, List<String>? labels})`  
`GenderSelectCards({required String? value, required ValueChanged<String> onChanged})` — values `'male'` / `'female'`  
`DocumentUploadBox({required String label, File? file, required VoidCallback onTap, String? previewUrl})`  
`AuthPrimaryButton({required String label, required VoidCallback? onPressed, bool loading})`  
`SecurityNotice({String? text})` — defaults to `context.l10n.authSecurityNotice`

Use `T.primary` / theme colors; RTL-safe row order.

- [x] **Step 4: Run widget test — PASS**

```bash
flutter test test/widget/auth/auth_step_indicator_test.dart
```

---

### Task 4: Account type selection redesign

**Files:**
- Modify: `rideshare/lib/screens/auth/account_type_selection_screen.dart`
- Test: `rideshare/test/widget/auth/account_type_selection_screen_test.dart` (optional smoke)

- [x] **Step 1: Rebuild UI to mockup**

Layout:

- Top: `Image.asset('assets/illustrations/auth/auth_visionway_logo.png')` + language switcher (reuse existing locale toggle pattern from welcome/sign-in if present)
- Background: `auth_account_type_cityscape.png` (low opacity)
- Title/subtitle from l10n
- Row of two cards:
  - Passenger: `auth_passenger_card_hero.png`, teal accents, 3 feature rows, circular CTA → `RouteNames.signUp` with `accountType: passenger`
  - Driver: `auth_driver_card_hero.png`, purple accents, 3 feature rows, circular CTA → `RouteNames.driverSignUp` (or existing driver signup route)
- Safety banner + login link → `RouteNames.signIn`

Keep existing navigation argument contracts.

- [ ] **Step 2: Manual/visual check against `account-type-selection.png`**

- [ ] **Step 3: Commit only if asked**

---

### Task 5: Passenger step 1 + OTP step chrome + profile step 3

**Files:**
- Modify: `rideshare/lib/screens/auth/sign_up_screen.dart`
- Modify: `rideshare/lib/screens/auth/otp_verification_screen.dart`
- Modify: `rideshare/lib/screens/auth/profile_setup_screen.dart`
- Modify: `rideshare/lib/core/services/auth_service.dart` (`updateProfile` add `city`)
- Modify: `rideshare/lib/providers/auth_provider.dart` if needed

**Interfaces:**
- OTP args must include `authStep: 2`, `authTotalSteps: 3` for passenger registration
- After passenger verify → `RouteNames.profileSetup` with step 3 args (not home directly)

- [x] **Step 1: Extend `AuthService.updateProfile` with city**

```dart
Future<void> updateProfile({
  String? name,
  String? email,
  String? gender,
  String? profileImageUrl,
  String? city,
  bool? hidePhoneNumber,
}) async {
  final data = <String, dynamic>{};
  // ...existing...
  if (city != null) data['city'] = city;
  await _api.patch(ApiEndpoints.me, data: data);
  _currentUser = await getProfile();
}
```

- [x] **Step 2: Redesign `SignUpScreen`**

- Hero: `auth_passenger_signup_hero.png`
- `AuthStepIndicator(currentStep: 1, totalSteps: 3)` + “خطوة 1 من 3”
- Fields + `GenderSelectCards` + `AuthPrimaryButton`
- Phone field: prefer `auth_flag_jo.png` when dial code is +962 (keep country picker)
- On success navigate OTP with `isRegistration: true`, `accountType: passenger`, step metadata

- [x] **Step 3: OTP screen**

When `args['authTotalSteps'] == 3` (passenger):

- Show step indicator current=2
- Same teal auth chrome (no full redesign of OTP logic)
- On passenger register success → `profileSetup` instead of home when coming from this flow

- [x] **Step 4: Redesign `ProfileSetupScreen` for post-register passenger**

Primary fields: profile photo picker + city text field (required).  
Keep name prefilled read-only or editable if already set.  
Remove forcing role selection when role already passenger.  
Submit: upload photo if needed → `updateProfile(photoUrl:, city:)` → home.

- [x] **Step 5: Widget/smoke test + manual path**

```bash
flutter test test/widget/auth/
```

---

### Task 6: Driver step 1 redesign

**Files:**
- Modify: `rideshare/lib/screens/auth/driver_sign_up_screen.dart`

- [x] **Step 1: Match mockup**

- Hero `auth_driver_step1_hero.png`
- Stepper with 3 labels (step 1 active)
- Single full-name field (combine first/last if currently split — send one `name` downstream)
- Phone, password, confirm, gender cards, security notice, continue
- OTP → `afterVerifyRoute: RouteNames.driverCompleteProfile` with registration token flow unchanged

- [x] **Step 2: Verify first/last → name mapping still works for `registerDriver`**

If UI is single name field, pass `name` through OTP args; drop separate first/last or join `"$first $last"`.

---

### Task 7: Driver complete profile wizard (steps 2 + 3) + client insurance

**Files:**
- Create: `rideshare/lib/screens/auth/driver_complete/driver_profile_wizard_state.dart`
- Create: `rideshare/lib/screens/auth/driver_complete/driver_complete_step2.dart`
- Create: `rideshare/lib/screens/auth/driver_complete/driver_complete_step3.dart`
- Modify: `rideshare/lib/screens/auth/driver_complete_profile_screen.dart` (shell)
- Modify: `rideshare/lib/core/services/auth_service.dart` (`insuranceImageUrl` on register; new PATCH method)
- Modify: `rideshare/lib/core/api/api_endpoints.dart`
- Modify: `rideshare/lib/providers/auth_provider.dart`

**Interfaces:**
- `DriverProfileWizardState` holds files + text fields + `isEditMode`
- Step2 continue only validates step2; Step3 submits register or PATCH

- [x] **Step 1: API client pieces**

```dart
// api_endpoints.dart
static const String driverPendingRegistration = '/auth/driver/registration';

// auth_service.dart registerDriver — add required:
required String insuranceImageUrl,
// body['insuranceImageUrl'] = insuranceImageUrl;

Future<void> updatePendingDriverRegistration(Map<String, dynamic> data) async {
  await _api.patch(ApiEndpoints.driverPendingRegistration, data: data);
  _currentUser = await getProfile();
}
```

- [x] **Step 2: Wizard state class**

```dart
class DriverProfileWizardState extends ChangeNotifier {
  int step = 2; // 2 or 3
  bool isEditMode = false;
  File? profileImage;
  File? licenseImage;
  File? vehicleLicenseImage;
  File? insuranceImage;
  File? carImage;
  String? existingPhotoUrl;
  String? existingLicenseUrl;
  // ... other existing URLs for edit prefills
  String? vehicleType;
  final plateController = TextEditingController();
  final modelController = TextEditingController();
  final seatsController = TextEditingController();
  // dispose controllers in dispose()
}
```

- [x] **Step 3: Step 2 UI**

Header gradient + `auth_driver_step2_header.png`, badge “Step 2 of 3”, fields from mockup, `DocumentUploadBox` for license, Continue → `step = 3`.

- [x] **Step 4: Step 3 UI**

Same chrome, badge step 3, three `DocumentUploadBox`es: الاستمارة، التأمين، صورة السيارة.  
Submit:

1. Upload each new file (registration upload if !editMode; authenticated upload if editMode)
2. If !editMode → `registerDriver(... insuranceImageUrl: ...)`
3. If editMode → `updatePendingDriverRegistration({...})`
4. Navigate `RouteNames.driverPendingApproval` (or pop to it)

- [x] **Step 5: Shell `DriverCompleteProfileScreen`**

- Parse args: registration token / edit mode
- If edit mode: load `GET /vehicles/my` + user photo into wizard state
- PageView or indexed stack for step 2/3
- Preserve vehicle type template seat autofill logic from current screen

- [ ] **Step 6: Manual test new register with insurance; edit while pending**

---

### Task 8: Driver pending approval redesign + edit entry

**Files:**
- Modify: `rideshare/lib/screens/driver/driver_pending_approval_screen.dart`

- [x] **Step 1: Rebuild to mockup**

- Top help + optional bell
- Hero `auth_driver_pending_review_hero.png`
- Title/body l10n
- Status card + orange “Under review” badge
- Four doc tiles with green checks (icons + labels)
- Restriction banner
- Edit row → `Navigator.pushNamed(RouteNames.driverCompleteProfile, arguments: {'editMode': true})`
- Home button
- Do not block bottom navigation / rider features (existing behavior)

- [ ] **Step 2: Visual QA vs `driver-pending-review.png`**

---

### Task 9: End-to-end verification checklist

- [x] **Backend**

```bash
npm test -- --testPathPatterns=auth.service.spec --no-coverage
```

(cwd `rideshare-backend`)

- [x] **Flutter analyze + targeted tests**

```bash
flutter analyze lib/screens/auth lib/widgets/auth lib/screens/driver/driver_pending_approval_screen.dart
flutter test test/widget/auth/
```

(cwd `rideshare`)

- [ ] **Manual**

1. Account type → passenger → step1 → OTP → profile photo+city → home  
2. Account type → driver → step1 → OTP → step2 → step3 (all 3 docs + insurance) → pending  
3. From pending → edit → change insurance → still pending  
4. Confirm admin approve still works; PATCH after approve fails

---

## Spec coverage self-check

| Spec requirement | Task |
|------------------|------|
| Account type redesign + assets | 4 |
| Passenger 1/2/3 (OTP + photo/city) | 5 |
| Driver step 1 | 6 |
| Driver steps 2–3 + insurance required | 1, 7 |
| Pending review UI | 8 |
| Edit reopens 2–3 + PATCH while pending | 2, 7, 8 |
| Shared chrome / l10n | 3 |
| Assets already extracted | (done; used in 4–8) |
| Testing | 1, 2, 3, 9 |

No TBD placeholders. Commit steps optional per user rule.
