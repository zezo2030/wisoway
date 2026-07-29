# Auth Registration Screens — Design Assets Inventory

Source mockups (copied from user screenshots):

| File | Screen |
|------|--------|
| `account-type-selection.png` | اختيار نوع الحساب |
| `passenger-signup-step1.png` | إنشاء حساب راكب — خطوة 1 |
| `driver-step1-basic.png` | إنشاء حساب سائق — خطوة 1 |
| `driver-step2-vehicle.png` | إنشاء حساب سائق — خطوة 2 |
| `driver-pending-review.png` | السائق قيد المراجعة |

> ملاحظة: تصميم الخطوة 3 للسائق (مستندات السيارة) لم يُرفق كـ mockup منفصل؛ يُستنتج من شاشة المراجعة (الاستمارة / التأمين / صورة السيارة) + نص المستخدم.

---

## A. Custom illustrations (shipped in app)

| ID | Description | App path | Source |
|----|-------------|----------|--------|
| `auth_passenger_card_hero` | راكب في المقعد الخلفي | `rideshare/assets/illustrations/auth/auth_passenger_card_hero.png` | Generated from mockup ref |
| `auth_driver_card_hero` | سائق خلف المقود | `rideshare/assets/illustrations/auth/auth_driver_card_hero.png` | Generated from mockup ref |
| `auth_account_type_cityscape` | خلفية مدينة + نخيل + مسارات | `rideshare/assets/illustrations/auth/auth_account_type_cityscape.png` | Generated from mockup ref |
| `auth_passenger_signup_hero` | سيارة بيضاء + طريق + نخيل | `rideshare/assets/illustrations/auth/auth_passenger_signup_hero.png` | Generated from mockup ref |
| `auth_driver_step1_hero` | سائق + سيارة + مدينة | `rideshare/assets/illustrations/auth/auth_driver_step1_hero.png` | Generated from mockup ref |
| `auth_driver_step2_header` | هيدر خطوة 2 (سائق مبتسم) | `rideshare/assets/illustrations/auth/auth_driver_step2_header.png` | Generated from mockup ref |
| `auth_driver_pending_review_hero` | وثيقة + عدسة مكبرة + ساعة | `rideshare/assets/illustrations/auth/auth_driver_pending_review_hero.png` | Generated from mockup ref |
| `auth_visionway_logo` | شعار VisionWay دائري | `rideshare/assets/illustrations/auth/auth_visionway_logo.png` | Generated from mockup ref |
| `auth_flag_jo` | علم الأردن | `rideshare/assets/images/auth/auth_flag_jo.png` | Generated |

### Crop references (from mockups — for visual QA / fallback)

Under `rideshare/assets/images/auth/`:

- `account_type_passenger_card_crop.png`
- `account_type_driver_card_crop.png`
- `visionway_logo_crop.png`
- `passenger_signup_hero_crop.png`
- `driver_step1_hero_crop.png`
- `driver_step2_header_crop.png`
- `driver_pending_review_hero_crop.png`

Prefer the generated `illustrations/auth/*` files in UI; crops are reference/fallback.

---

## B. Icons (Iconsax / Material — no PNG export)

| Visual | Suggested icon |
|--------|----------------|
| Back | `Icons.arrow_back_ios_new` |
| Help / مساعدة | `IconsaxPlusBroken.info_circle` / `Icons.help_outline` |
| Language globe | `IconsaxPlusBroken.global` / `Icons.language` |
| Bell | `IconsaxPlusBroken.notification` |
| User / name | `IconsaxPlusBroken.user` |
| Phone | `IconsaxPlusBroken.call` |
| Lock | `IconsaxPlusBroken.lock` |
| Eye show/hide | `IconsaxPlusBroken.eye` / `eye_slash` |
| Camera (profile) | `IconsaxPlusBroken.camera` |
| Car / vehicle type | `IconsaxPlusBroken.car` |
| Plate | `IconsaxPlusBroken.card` / plate-style |
| Seat | `Icons.event_seat` |
| Document upload | `IconsaxPlusBroken.document_upload` |
| Shield / security | `IconsaxPlusBroken.shield_tick` |
| Edit pencil | `IconsaxPlusBroken.edit` |
| Home | `IconsaxPlusBroken.home` |
| Steering wheel | `IconsaxPlusBroken.driving` / custom |
| Gender male/female | Unicode `♂` / `♀` or Material |
| Check step | `Icons.check` |
| Chevron / next | `Icons.arrow_forward` (flip in RTL) |

### Pending-review document tiles

| Label | Icon approach |
|-------|---------------|
| الرخصة | ID card icon |
| الاستمارة | Document icon |
| التأمين | Shield check icon |
| صورة السيارة | Car front icon |

---

## C. Backend gap vs design (for plan)

| Design field | Current backend |
|--------------|-----------------|
| رخصة القيادة (`licenseImageUrl`) | موجود |
| الاستمارة (`vehicleLicenseImageUrl`) | موجود |
| **التأمين** | **غير موجود** — يحتاج `insuranceImageUrl` على `vehicles` + DTO/migration |
| صورة السيارة (`carImageUrl`) | موجود |
| الصورة الشخصية (`photoUrl`) | موجود على user |

---

## D. Screen → asset mapping

| Screen | Illustrations |
|--------|---------------|
| Account type | cityscape + passenger card + driver card + logo |
| Passenger signup | passenger signup hero (+ JO flag in phone field) |
| Driver step 1 | driver step1 hero |
| Driver step 2 | driver step2 header |
| Driver step 3 (docs) | upload UI only (icons) — no hero mockup yet |
| Pending review | pending review hero |
