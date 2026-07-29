# Auth Registration UI Redesign — Design Spec

**Date:** 2026-07-28  
**Status:** Approved for planning (pending user review of this written spec)  
**Scope:** Passenger + driver signup flows, account-type selection, driver pending-review screen, and matching backend changes.

---

## 1. Goal

Pixel-close redesign of VisionWay auth/registration screens to match the provided Arabic RTL mockups, including extracted illustration assets, while extending the backend for insurance documents and pending-driver profile edits.

---

## 2. Decisions (locked)

| Topic | Decision |
|-------|----------|
| Approach | Redesign existing screens/routes in place (not a parallel v2 route tree) |
| Passenger steps | 1 = basic info → 2 = OTP → 3 = simple profile (photo + city), same visual language |
| Driver steps | 1 = basic info → 2 = vehicle + license → 3 = vehicle documents (form, insurance, car photo) |
| Insurance | Add `insuranceImageUrl` (migration + DTO); required on driver step 3 / register |
| Pending edit | “تعديل بياناتك؟” reopens wizard steps 2–3; backend accepts updates while `isDriverApproved=false` |
| Assets | Generated illustrations under `rideshare/assets/illustrations/auth/`; crops/flag under `rideshare/assets/images/auth/`; inventory in `docs/superpowers/assets/2026-07-28-auth-registration/` |

---

## 3. Screen inventory

### 3.1 Account type selection
**File:** `rideshare/lib/screens/auth/account_type_selection_screen.dart`

- Logo + language switcher
- Cityscape background illustration
- Two vertical cards: Passenger (teal) / Driver (purple) with hero images, feature lists, circular CTA
- Safety banner + login link

### 3.2 Passenger — Step 1 (basic)
**File:** `rideshare/lib/screens/auth/sign_up_screen.dart`

- Step indicator “1 of 3”
- Hero illustration (car/road/city)
- Fields: full name, phone (+962 / JO flag), password, confirm password
- Gender cards (male/female)
- Continue → send OTP → navigate to OTP as step 2

### 3.3 Passenger — Step 2 (OTP)
**File:** `rideshare/lib/screens/auth/otp_verification_screen.dart`

- Restyle to match auth visual system + step indicator “2 of 3”
- Keep existing verify/register behavior
- On success (passenger registration) → profile setup as step 3

### 3.4 Passenger — Step 3 (profile)
**File:** `rideshare/lib/screens/auth/profile_setup_screen.dart`

- Step indicator “3 of 3”
- Required: profile photo + city
- Same teal/RTL chrome as other auth screens
- On save → home

### 3.5 Driver — Step 1 (basic)
**File:** `rideshare/lib/screens/auth/driver_sign_up_screen.dart`

- Match mockup: hero, stepper labels locked to **المعلومات الأساسية / الهوية والمستندات / معلومات السيارة**, full name (single field), phone, password, confirm, gender
- Continue → shared OTP screen (driver verify-phone; OTP is **not** one of the three driver wizard steps) → step 2 with registration token

### 3.6 Driver — Step 2 (additional / vehicle + license)
**Split from:** `rideshare/lib/screens/auth/driver_complete_profile_screen.dart`  
**Preferred structure:** keep orchestration in that file or extract `driver_complete_profile_step2.dart` / wizard state if the file stays too large.

Fields:

- Profile photo *
- Vehicle type *
- Plate number *
- Car model *
- Seats *
- Driving license upload *

Continue → step 3 (does **not** call final register yet).

### 3.7 Driver — Step 3 (vehicle documents)
New UI section/screen in the same flow:

- Vehicle registration form (الاستمارة) → `vehicleLicenseImageUrl` *
- Insurance (التأمين) → `insuranceImageUrl` *
- Car photo → `carImageUrl` *

Submit → upload images → `POST /auth/driver/register` → pending-review screen.

### 3.8 Driver pending review
**File:** `rideshare/lib/screens/driver/driver_pending_approval_screen.dart`

- Hero illustration (doc + magnifier + clock)
- Status card: “قيد المراجعة” badge
- Submitted docs grid (4 tiles with green checks): license, form, insurance, car photo
- Restriction notice
- Edit row → reopen steps 2–3 with existing data prefilled
- Primary: return home
- Keep bottom nav / home entry behavior consistent with current app (unapproved drivers can use rider features)

---

## 4. Shared UI building blocks

| Widget | Responsibility |
|--------|----------------|
| `AuthStepIndicator` | 1/2/3 circles + labels / “خطوة X من 3” |
| `AuthPrimaryButton` | Full-width teal CTA + arrow |
| `GenderSelectCards` | Male/female selectable cards |
| `DocumentUploadBox` | Dashed border upload area + formats hint (JPG/PNG/PDF, max 5MB) |
| `SecurityNotice` | Shield + privacy copy |
| Existing form components | Prefer extending `widgets/common/form_components.dart` over duplicating fields |

**Assets (implementation must use):**

- `assets/illustrations/auth/auth_passenger_card_hero.png`
- `assets/illustrations/auth/auth_driver_card_hero.png`
- `assets/illustrations/auth/auth_account_type_cityscape.png`
- `assets/illustrations/auth/auth_passenger_signup_hero.png`
- `assets/illustrations/auth/auth_driver_step1_hero.png`
- `assets/illustrations/auth/auth_driver_step2_header.png`
- `assets/illustrations/auth/auth_driver_pending_review_hero.png`
- `assets/illustrations/auth/auth_visionway_logo.png`
- `assets/images/auth/auth_flag_jo.png`

Icons: Iconsax Plus / Material (see assets inventory). No emoji.

**Localization:** All new copy in `app_ar.arb` + `app_en.arb` (no hardcoded Arabic-only strings in widgets).

---

## 5. Backend design

### 5.1 Schema
- Add `vehicles.insuranceImageUrl` (`TEXT NULL`) via TypeORM migration.
- Map on `VehicleEntity`, vehicle schema (if still used), create-vehicle DTO, register-driver DTO, auth register mapping.

### 5.2 Register driver
- `RegisterDriverDto.insuranceImageUrl`: required string (URL), max 500.
- `registerDriver` persists it on the vehicle row with the other document URLs.
- New registrations without insurance fail validation (400).

### 5.3 Update while pending (new)
- Endpoint: `PATCH /drivers/me/registration` (authenticated).
- Guard: user is driver AND `isDriverApproved === false`; otherwise 403.
- Body (all optional, but at least one required): vehicle fields + `photoUrl` + document URLs including `insuranceImageUrl`.
- Updates user photo and/or primary vehicle documents/fields in one transaction.
- Does **not** set `isDriverApproved=true`.
- If already approved: 403 with clear error code; client navigates home.

### 5.4 Passenger profile step
- Use existing `PATCH /users/me` for `photoUrl` + `city` (already supported / covered by profile contract tests). No new registration endpoint.

### 5.5 Uploads
- Registration uploads continue via existing registration upload token flow before account creation.
- Pending edits use authenticated upload endpoints after account exists.

---

## 6. Client data flow

```text
Passenger:
  AccountType → SignUp(1) → sendOTP → Otp(2) → register → ProfileSetup(3) → Home

Driver (new):
  AccountType → DriverSignUp(1) → verify-phone OTP → token
    → CompleteProfile step2 (local state) → step3
    → upload docs → registerDriver → PendingReview

Driver (edit while pending):
  PendingReview → CompleteProfile step2/3 (prefilled from user+vehicle)
    → upload changed docs → PATCH /drivers/me/registration → PendingReview
```

Wizard state for driver steps 2–3 should hold file picks + typed fields until final submit (new registration) or PATCH (edit mode). Detect edit mode via route args / `isDriverApproved==false` + existing vehicle.

---

## 7. Error handling

- Client validation before network (required fields, password match, file size ≤ 5MB, allowed mime types).
- API failures via existing `ErrorSurface` / failure mapping.
- Disable CTA + show progress during multi-upload.
- Partial upload failure: stop and show which document failed; do not call register/PATCH with missing URLs.
- Race: if approval flips to true mid-edit, PATCH returns 403 → snackbar + navigate home.

---

## 8. Testing

**Backend**

- Register succeeds with `insuranceImageUrl`.
- Register fails without `insuranceImageUrl`.
- PATCH pending succeeds; PATCH approved fails.
- Vehicle row contains insurance URL after register/update.

**Flutter**

- Widget tests: account-type cards, gender selection, step indicator states.
- Smoke/widget coverage for pending-review doc tiles when args present.

**Manual**

- Full passenger 1→2→3.
- Full driver 1→2→3→pending.
- Edit from pending and confirm admin still sees updated docs / still pending.

---

## 9. Out of scope

- Redesigning login, forgot-password, banned screens (unless shared chrome only).
- Admin dashboard UI for insurance (API/entity enough for admin to read URL if already showing vehicle docs; optional dashboard field is nice-to-have, not required for this spec).
- Pixel-perfect Figma export of step-3 mockup (none provided); step 3 follows step-2 upload patterns + pending-review document set.
- Changing approval business rules beyond allowing pending updates.

---

## 10. Success criteria

1. Five provided mockup screens match visually (layout, teal palette, RTL, illustrations).
2. Passenger flow is explicitly 3 styled steps including OTP + photo/city.
3. Driver can submit insurance; pending screen shows four document checks.
4. Pending driver can reopen steps 2–3 and persist updates without auto-approval.
5. Assets live under app asset folders and are registered in `pubspec.yaml`.
