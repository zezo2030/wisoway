# خطة التنفيذ — تسجيل الدخول، إنشاء حساب راكب/سائق، وربط خدمة الرسائل

> **الغرض:** خطة قابلة للتنفيذ مباشرة لإعادة بناء مسار الهوية بالكامل — إرسال والتحقق من
> OTP، إنشاء حساب راكب، إنشاء حساب سائق، تسجيل الدخول، وإدارة التوكنات — مع ربط خدمة
> الرسائل (Twilio Verify).
>
> مستخرجة من `rideshare-backend/src` على فرع `009-platform-refinements`، وكل رقم وقاعدة
> هنا متحقق منها من الكود. المرجع الكامل: [`01-identity-and-access.md`](01-identity-and-access.md).
>
> **ملاحظة أساسية:** هذا النظام **لا يستخدم إيميل/باسورد للمستخدم النهائي**. المصادقة
> بالهاتف + OTP، والباسورد credential ثانوي يُنشأ وقت التسجيل ويُستخدم في مسار الدخول السريع.
> الإيميل مخصص لحسابات الأدمن فقط.

---

## 0. ملخص تنفيذي

| المسار | الـ endpoints | الحالة في الكود الحالي |
|---|---|---|
| إرسال OTP | `POST /auth/send-otp` | يعمل — بوضعين: `local` و `twilio` |
| إنشاء حساب راكب | `POST /auth/verify-otp` | يعمل — نفس الـ endpoint يسجّل ويُنشئ |
| إنشاء حساب سائق | `POST /auth/driver/verify-phone` → `POST /uploads/registration` → `POST /auth/driver/register` | يعمل — 3 خطوات + توكن تسجيل مؤقت |
| تعديل طلب السائق | `PATCH /auth/driver/registration` | يعمل — قبل موافقة الأدمن فقط |
| تسجيل الدخول | `POST /auth/login` | يعمل — فرعان: هاتف (مستخدم) / إيميل (أدمن) |
| تجديد التوكن | `POST /auth/refresh` | يعمل |
| تسجيل الخروج | `POST /auth/logout` | ⚠️ **شكلي — لا يُبطل أي توكن** |

**الجداول المستخدمة:** `users` · `otp_codes` · `user_devices` · `vehicles` · `account_flags` · `security_events`

---

## 1. الثوابت والقيم الدقيقة

كل هذه القيم مستخرجة حرفياً من الكود. أي إعادة بناء يجب أن تطابقها أو تغيّرها بقرار واعٍ.

### 1.1 التحقق من المدخلات (regex حرفية)

| القاعدة | القيمة | مستخدمة في |
|---|---|---|
| رقم الهاتف (E.164) | `^\+[1-9]\d{1,14}$` | كل الـ DTOs |
| كود OTP (تحقق عادي) | `^\d{6}$` — **6 خانات بالضبط** | `VerifyOtpDto` |
| كود OTP (مسار السائق) | `^\d{4,6}$` — **4 إلى 6** ⚠️ تعارض | `DriverVerifyPhoneDto` |
| الباسورد | `^(?=.*[A-Za-z])(?=.*\d).{8,}$` | التسجيل، إعادة التعيين |
| طول الباسورد | 8 – 100 | |
| الاسم | 1 – 120 حرف | |
| الجنس | `male` \| `female` | |
| الدور عند التسجيل | `passenger` \| `driver` فقط (**لا `admin`**) | |

> ⚠️ **تعارض يجب حسمه:** التحقق العادي يفرض 6 خانات بينما مسار السائق يقبل 4–6.
> وحّدها على 6 في إعادة البناء.

### 1.2 المهل الزمنية والأعداد

| الثابت | القيمة | ملاحظة |
|---|---|---|
| صلاحية OTP (وضع `local`) | **5 دقائق** | `expiresAt = now + 5min` |
| `expiresIn` المُعاد للعميل | **300** ثانية | يُعاد ثابتاً في الوضعين — غير مشتق من Twilio |
| صلاحية توكن تسجيل السائق | **1800** ثانية (30 دقيقة) | `DRIVER_REGISTRATION_TOKEN_TTL_SECONDS` |
| صلاحية access token | **`15m`** | مثبّت في الكود |
| صلاحية refresh token | **`7d`** | مثبّت في الكود |
| تكلفة bcrypt | **12** | |
| خوارزمية JWT | **HS256** (افتراضي `jsonwebtoken`) | |
| حد المحاولات (إعادة تعيين الباسورد) | **5** ثم قفل | |
| حد الطلبات العام | **200 طلب / 60 ثانية** | لا يوجد حد خاص بالهاتف |
| حجم الملف الأقصى | **10 MB** | |
| أنواع الملفات | `image/jpeg`, `image/png`, `image/webp`, `application/pdf` | |
| عتبة تعدد الحسابات لكل جهاز | **3** حسابات / 24 ساعة | `MULTI_ACCOUNT_DEVICE_THRESHOLD` |

### 1.3 عقد الـ JWT

كلا التوكنين يحملان **نفس الـ payload** — يفرّق بينهما سر التوقيع فقط.

```json
{
  "sub":  "<user uuid>",
  "email": "<قد يكون null>",
  "role": "passenger | driver | admin",
  "did":  "<user_devices.id أو null>",
  "iat":  1234567890,
  "exp":  1234568790
}
```

| | Access | Refresh |
|---|---|---|
| السر | `JWT_ACCESS_SECRET` | `JWT_REFRESH_SECRET` |
| المدة | `15m` | `7d` |

---

## 2. متغيّرات البيئة المطلوبة

```bash
# ── JWT (مطلوب — التطبيق لا يقلع بدونه) ────────────────────────────
JWT_ACCESS_SECRET=<سر قوي عشوائي>      # ⚠️ الاسم الصحيح — وليس JWT_SECRET
JWT_REFRESH_SECRET=<سر مختلف تماماً>

# ── مزوّد الرسائل ──────────────────────────────────────────────────
OTP_PROVIDER=local                      # local = بدون SMS | twilio = SMS حقيقي

# ── Twilio (مطلوبة فقط عندما OTP_PROVIDER=twilio) ──────────────────
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   # يجب أن يبدأ بـ AC
TWILIO_VERIFY_SERVICE_SID=VAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# طريقة المصادقة (أ) — المفضّلة:
TWILIO_API_KEY_SID=SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   # يجب أن يبدأ بـ SK
TWILIO_API_KEY_SECRET=<سر مفتاح الـ API>
# طريقة المصادقة (ب) — احتياطية:
TWILIO_AUTH_TOKEN=<توكن الحساب>

# ── الأمان والدعم ──────────────────────────────────────────────────
MULTI_ACCOUNT_DEVICE_THRESHOLD=3
SUPPORT_WHATSAPP_E164=+962788883007
SERVER_BASE_URL=                        # فارغ في التطوير
```

> ⚠️ **`.env.example` الحالي خاطئ:** يوثّق `JWT_SECRET` بينما الكود يقرأ
> `JWT_ACCESS_SECRET`. وكذلك `JWT_EXPIRES_IN` و `JWT_REFRESH_EXPIRES_IN`
> **لا يُقرآن إطلاقاً** — المدد مثبّتة في الكود.
>
> `TWILIO_PHONE_NUMBER` معرّف في الـ config لكنه **غير مستخدم** في هذا المسار
> (مسار Programmable SMS الاحتياطي لم يُستدعَ أبداً).

---

## 3. ربط خدمة الرسائل (Twilio Verify)

### 3.1 المفهوم

النظام يدعم **وضعين** يُحسمان مرة واحدة عند إقلاع الخدمة:

| الوضع | السلوك | التخزين |
|---|---|---|
| `local` | يولّد الكود محلياً، يحفظه في `otp_codes`، ويطبعه في اللوج بمستوى WARN | جدول `otp_codes` |
| `twilio` | يفوّض كل شيء لـ Twilio Verify — التوليد والصلاحية والحد | **لا شيء محلياً** |

> ⚠️ الوضع يُقرأ **مرة واحدة عند بناء الخدمة** — تغيير `OTP_PROVIDER` يتطلب إعادة تشغيل.

### 3.2 ترتيب قراءة الإعداد

الكود يقرأ كل مفتاح بثلاث محاولات متتالية:

```
ConfigService.get('OTP_PROVIDER')            ← المسطّح
  ?? ConfigService.get('twilio.OTP_PROVIDER') ← المُسمّى
  ?? process.env.OTP_PROVIDER
  ?? 'local'                                  ← الافتراضي
```
ثم `.toLowerCase()`، وأي قيمة غير `'twilio'` تعني `'local'`.

### 3.3 بناء عميل Twilio — منطق الاختيار

```
إذا (accountSid يبدأ بـ "AC") و (apiKeySid يبدأ بـ "SK") و (apiKeySecret موجود):
    → new Twilio(apiKeySid, apiKeySecret, { accountSid })      ← المفضّل
وإلا إذا (accountSid يبدأ بـ "AC") و (authToken موجود):
    → new Twilio(accountSid, authToken)                        ← احتياطي
وإلا:
    → لا يُنشأ عميل إطلاقاً، وكل عملية OTP تفشل بـ 400
```

العميل يُبنى **فقط** عندما يكون المزوّد `twilio`.

### 3.4 نداءات Twilio المستخدمة

الحزمة: `twilio ^5.12.1`

| العملية | النداء |
|---|---|
| إرسال الكود | `client.verify.v2.services(VERIFY_SID).verifications.create({ to, channel: 'sms' })` |
| التحقق من الكود | `client.verify.v2.services(VERIFY_SID).verificationChecks.create({ to, code })` |

نجاح التحقق يعني `verificationCheck.status === 'approved'` — أي قيمة أخرى تُعامل كفشل.

### 3.5 سلوك الفشل

| الحالة | الاستجابة |
|---|---|
| العميل غير مُنشأ أو `TWILIO_VERIFY_SERVICE_SID` فارغ | `400 "Twilio Verify is not configured correctly"` |
| أي استثناء من Twilio عند الإرسال | يُسجّل في `console.error` ثم `400 "Failed to send OTP"` |
| أي استثناء من Twilio عند التحقق | `401 "Invalid or expired OTP code"` |

> خطأ Twilio الأصلي **لا يصل للعميل إطلاقاً** — يُبتلع ويُستبدل برسالة عامة.
> في إعادة البناء: سجّل الكود الأصلي من Twilio (مثل `60200 invalid parameter`)
> في اللوج مع correlation id لتسهيل التشخيص.

### 3.6 خطوات التفعيل العملية

1. أنشئ حساب Twilio واحصل على `Account SID` (يبدأ بـ `AC`).
2. من **Verify → Services** أنشئ خدمة جديدة → انسخ الـ `Service SID` (يبدأ بـ `VA`).
3. من **Account → API keys & tokens** أنشئ API Key → انسخ `SK...` والسر.
4. املأ المتغيّرات الأربعة + `OTP_PROVIDER=twilio`.
5. أعد تشغيل الخدمة (الإعداد لا يُقرأ ديناميكياً).
6. اختبر برقم حقيقي بصيغة E.164 كاملة.

> **الأرقام في وضع الاختبار:** Twilio Verify لا يقبل الأرقام الوهمية افتراضياً.
> للتطوير استخدم `OTP_PROVIDER=local` واقرأ الكود من اللوج.

### 3.7 نواقص يجب إصلاحها في إعادة البناء

| # | المشكلة | الإصلاح |
|---|---|---|
| 1 | **لا يوجد أي حد لإرسال OTP لكل رقم** — فقط الحد العام 200/دقيقة | أضف cooldown (مثلاً 60 ثانية) وحد يومي لكل رقم |
| 2 | الكود يُولَّد بـ `Math.random()` — **ليس CSPRNG** | استخدم مولّد آمن تشفيرياً |
| 3 | الكود يُخزَّن **نصاً صريحاً** في القاعدة ويُطبع في اللوج | خزّن hash، ولا تطبع الكود خارج التطوير |
| 4 | **في وضع `local` الكود لا ينتهي أبداً** — الاستعلام لا يفلتر على `expiresAt` ولا توجد مهمة تنظيف | أضف الفلتر + مهمة دورية |
| 5 | `expiresIn: 300` يُعاد ثابتاً حتى في وضع Twilio | اشتقّه من المهلة الحقيقية |

---

## 4. المسار 1 — إنشاء حساب راكب

### 4.1 التسلسل

```
العميل                                الخادم
  │
  │  POST /api/v1/auth/send-otp
  │  { "phoneNumber": "+962790000000" }
  │ ─────────────────────────────────────►
  │                                    يتحقق من E.164
  │                                    يحذف كل الأكواد غير المستخدمة لهذا الرقم
  │                                    يولّد كوداً جديداً (local) أو ينادي Twilio
  │  ◄─────────────────────────────────
  │  { "message": "OTP sent successfully", "expiresIn": 300 }
  │
  │  POST /api/v1/auth/verify-otp
  │  { phoneNumber, code, name, gender, role:"passenger",
  │    password, device? }
  │ ─────────────────────────────────────►
  │                                    1. يتحقق من الكود ويستهلكه
  │                                    2. يبحث عن المستخدم بالهاتف
  │                                    3. غير موجود → ينشئ حساباً
  │                                    4. يربط الجهاز (اختياري)
  │                                    5. يفحص مخاطر تعدد الحسابات
  │                                    6. يصدر التوكنات
  │  ◄─────────────────────────────────
  │  { user, accessToken, refreshToken,
  │    accountState, deviceState, pendingPhoneLinkRequired }
```

### 4.2 منطق `verify-otp` بالتفصيل — ثلاثة فروع

`verify-otp` ليس مسار دخول. سلوكه يعتمد على حالة الحساب:

| حالة الحساب | الشرط | النتيجة |
|---|---|---|
| **غير موجود** | `password` مُرسل | ✅ ينشئ حساباً جديداً |
| **غير موجود** | `password` غير مُرسل | ❌ `400 "Password is required when creating a new account."` |
| **موجود بلا باسورد** | `password` مُرسل | ✅ يضبط الباسورد ويكمل الإعداد |
| **موجود بلا باسورد** | `password` غير مُرسل | ❌ `400 "Password is required to finish account setup for this phone number."` |
| **موجود وله باسورد** | — | ❌ `409 "Phone number is already registered. Please sign in with your password."` |

> **نتيجة مهمة:** المستخدم المسجَّل بالكامل **لا يستطيع الدخول عبر OTP إطلاقاً** —
> يجب أن يستخدم `POST /auth/login` بالباسورد. لو أردت دخولاً بالـ OTP في إعادة
> البناء فهذا تغيير سلوكي متعمّد يجب اتخاذ قرار بشأنه.

### 4.3 قواعد إنشاء الحساب الجديد

1. `role` = `driver` إذا أُرسلت حرفياً، وإلا `passenger`. **`admin` مستحيل من هنا.**
2. `name` = الاسم بعد التشذيب، وإذا كان فارغاً → **رقم الهاتف نفسه**.
3. الحقول الثابتة: `provider = 'phone'`، `isPhoneVerified = true`، `isActive = true`،
   `isDriverApproved = false`.
4. `passwordHash` = bcrypt بتكلفة 12 (يتخطّى التجزئة إذا كانت القيمة تبدو hash بالفعل).
5. أثران جانبيان **لا يُنتظران ولا يُفشلان الطلب**:
   - `notifyAdminsOfNewUser(user)`
   - `adminAlertsService.notifyDriverRegistration(user)`
     > ⚠️ **خطأ:** يُنادى لكل مستخدم جديد — راكباً كان أو سائقاً.
     > في إعادة البناء: قيّده بـ `role === 'driver'`.

### 4.4 ربط الجهاز (اختياري)

يُنفَّذ فقط عند إرسال كتلة `device`:

```
fingerprintHash = SHA256( platform + ":" + deviceId + ":" + installSalt )   // hex
```

1. إذا وُجد صف بـ `{userId, fingerprintHash, status:'revoked'}` →
   `401 "This device has been revoked. Please use another trusted device."`
2. وإلا upsert في `user_devices` بحالة `active`.
3. يُفحص خطر تعدد الحسابات (قد يضبط `users.restricted = true`).
4. يُعاد تحميل المستخدم ليعكس `accountState` الحالة الجديدة فوراً.
5. `user_devices.id` يُدرَج في التوكن كـ `did`.

> ⚠️ **خلل في الترتيب:** الكود يستهلك الـ OTP **قبل** فحص الجهاز الملغى، فالمستخدم
> على جهاز ملغى يحرق كوداً في كل محاولة. **في إعادة البناء: افحص الجهاز أولاً.**
>
> ⚠️ لا يوجد قيد فريد على `(userId, fingerprintHash)` — التحقق على مستوى التطبيق فقط،
> فالطلبات المتزامنة تُنشئ صفوفاً مكرّرة. **أضف القيد الفريد.**

### 4.5 حالات الحساب في الاستجابة

| الحقل | القيم | المعنى |
|---|---|---|
| `accountState` | `active` \| `restricted` \| `banned` | `banned` إذا `bannedAt` غير null، ثم `restricted` |
| `deviceState` | `active` \| `revoked` \| `null` | `null` إذا لم يُربط جهاز |
| `pendingPhoneLinkRequired` | boolean | حساب اجتماعي قديم بلا هاتف |

> ⚠️ **التوكنات تُصدَر حتى للحسابات المحظورة والمقيّدة.** المنع يحدث في الطلبات
> التالية عبر `BanGuard` و `RestrictedAccountInterceptor`. قرار تصميمي مقصود
> ليعرف التطبيق سبب المنع ويعرضه للمستخدم.

---

## 5. المسار 2 — إنشاء حساب سائق (ثلاث خطوات)

### 5.1 الفكرة المعمارية

**لا يُحفظ أي شيء عن السائق حتى تنجح الخطوة الأخيرة.** السائق يثبت ملكية الهاتف أولاً،
يحصل على توكن تسجيل صالح 30 دقيقة، يرفع مستنداته به، ثم تُنشأ صفوف `users` و `vehicles`
معاً في **معاملة واحدة**. التسجيل المهجور لا يترك أثراً.

### 5.2 التسلسل

```
  الخطوة 1 ──────────────────────────────────────────────
  POST /api/v1/auth/driver/verify-phone
  { phoneNumber, code }
      │  يتحقق من الـ OTP (يستهلكه)
      │  يرفض الهاتف المسجَّل مسبقاً → 409
      ▼
  { registrationToken: "<JWT>", expiresIn: 1800 }

  الخطوة 2 ── (0 أو أكثر من مرة، بنفس التوكن) ───────────
  POST /api/v1/uploads/registration   [multipart/form-data]
  registrationToken=<JWT>  file=<binary>
      │  يتحقق من التوقيع و purpose === 'driver_registration'
      ▼
  { url: "http://host/uploads/driver-registration/<uuid>.jpg",
    key: "driver-registration/<uuid>.jpg" }

  الخطوة 3 ──────────────────────────────────────────────
  POST /api/v1/auth/driver/register
  { registrationToken, name, gender?, photoUrl?, password,
    vehicleType, plateNumber, model, seats?,
    licenseImageUrl?, vehicleLicenseImageUrl?,
    carImageUrl, insuranceImageUrl, device? }
      │  يعيد فحص الهاتف → 409
      │  يشتقّ seatLayout من كتالوج أنواع المركبات
      │  ┌─ معاملة واحدة ─────────────────┐
      │  │  INSERT users   (role='driver')│
      │  │  INSERT vehicles                │
      │  └────────────────────────────────┘
      │  يلتقط 23505 → 409 (أمان التزامن)
      ▼
  201 { user, accessToken, refreshToken, accountState, deviceState }
      │
      │  الحساب الآن isDriverApproved = false
      ▼
  PATCH /api/v1/auth/driver/registration   ← تعديل قبل الموافقة (متكرر)
      │
      │  الأدمن: PATCH /admin/users/:id/approve-driver { approved: true }
      ▼
  isDriverApproved = true   ← بيانات التسجيل تُجمَّد
```

### 5.3 توكن التسجيل

```js
jwt.sign(
  { phone: "<E.164>", purpose: "driver_registration" },
  JWT_ACCESS_SECRET,
  { expiresIn: 1800 }
)
```

**قواعد التحقق منه:**
- فشل التوقيع أو الصلاحية → `401 "Registration session expired. Please verify your phone again."`
- الحمولة ليست كائناً، أو `purpose !== 'driver_registration'`، أو `phone` ليس نصاً →
  `401 "Invalid registration token."`

> 🔴 **مشكلة أمنية:** التوكن يستخدم **نفس سر الـ access token**. الشيء الوحيد الذي
> يمنع استخدامه كتوكن جلسة هو غياب `sub`/`email` — وهذا **مصادفة وليس تصميماً**؛
> `JwtStrategy` لا يفحص `purpose` إطلاقاً.
>
> **في إعادة البناء: امنحه سراً مستقلاً (`JWT_REGISTRATION_SECRET`)، وافحص سلبياً في
> استراتيجية الجلسة أن التوكن لا يحمل `purpose`.**

### 5.4 الحقول الإلزامية للسائق

| الحقل | إلزامي | ملاحظة |
|---|---|---|
| `registrationToken` | ✅ | |
| `name` | ✅ | 1–120 |
| `password` | ✅ | نفس قواعد التعقيد |
| `vehicleType` | ✅ | ≤100 — يُستخدم لاشتقاق `seatLayout` |
| `plateNumber` | ✅ | ≤20 |
| `model` | ✅ | ≤100 |
| **`carImageUrl`** | ✅ | `"Car photo is required"` |
| **`insuranceImageUrl`** | ✅ | `"Insurance image is required"` |
| `seats` | ❌ | يُشتقّ من الكتالوج؛ القيمة المُرسلة تتغلّب |
| `gender`, `photoUrl`, `licenseImageUrl`, `vehicleLicenseImageUrl`, `device` | ❌ | |

### 5.5 نقاط حرجة في التنفيذ

1. **رقم الهاتف يُؤخذ من التوكن، لا من جسم الطلب.** هذا هو ما يجعل المسار آمناً — لا
   تسمح أبداً بتمرير الهاتف في الـ body.
2. **الباسورد يُجزَّأ قبل فتح المعاملة** — bcrypt بتكلفة 12 عملية بطيئة، لا تُبقِ
   المعاملة مفتوحة أثناءها.
3. **فحص `findByPhone` والإدراج ليسا ذرّيين.** الضمان الحقيقي هو التقاط خطأ
   Postgres `23505` وترجمته إلى `409`. **حافظ على الفهرس الفريد على `users.phoneNumber`.**
4. **اشتقاق المقاعد عند التعديل:** تغيير `vehicleType` يعيد اشتقاق `seatLayout` ويحسب
   `seats` منه، ثم قيمة `seats` في نفس الطلب تتغلّب عليه (ترتيب الإسناد مقصود).

### 5.6 قواعد التعديل (`PATCH /auth/driver/registration`)

| القاعدة | الاستجابة عند الفشل |
|---|---|
| يجب أن يكون `role === 'driver'` | `403 "Driver account required"` |
| يجب أن يكون `isDriverApproved === false` | `403 "Approved drivers cannot update registration via this endpoint"` |
| حقل واحد على الأقل غير فارغ | `400 "At least one field is required"` |
| يجب وجود صف مركبة للسائق | `404 "Vehicle not found"` |

`photoUrl` يُكتب في `users`؛ كل ما عداه في `vehicles`. لا شيء هنا يعيد تفعيل الموافقة.

---

## 6. المسار 3 — تسجيل الدخول

### 6.1 نقطة نهاية واحدة، فرعان

```
POST /api/v1/auth/login
```

| الفرع | الشرط | الاستعلام |
|---|---|---|
| **أدمن** | `email` موجود | `WHERE LOWER(email)=LOWER(:email) AND role='admin'` |
| **مستخدم** | `email` غائب | `WHERE phoneNumber = :phone` (مطابقة تامة، بلا تطبيع) |

> إذا أُرسل الحقلان معاً، **فرع الإيميل يفوز**.
> **الإيميل للأدمن حصراً** — الراكب أو السائق الذي لديه إيميل لا يستطيع استخدام هذا الفرع.

### 6.2 القواعد

1. لا مستخدم، أو `passwordHash === null` → 401 برسالة الفرع المناسبة.
2. `bcrypt.compare` فاشلة → **نفس الرسالة** (لا تسريب لوجود الحساب من عدمه).
3. فرع الهاتف فقط: `!isPhoneVerified` → `401 "Phone number must be verified before signing in."`
4. `isActive === false` **لا يُفحص هنا** — التوكن يُصدَر، ويُرفض في الطلب التالي.
5. `bannedAt` و `restricted` لا يمنعان — يُبلَّغ عنهما في `accountState`.
6. **لا عدّاد محاولات، لا قفل، لا حد لكل حساب.**

| الرسالة | الحالة |
|---|---|
| `Invalid admin email or password` | فرع الإيميل |
| `Invalid phone number or password` | فرع الهاتف |
| `Phone number must be verified before signing in.` | هاتف غير موثّق |

### 6.3 ملاحظة مهمة

الدخول بالباسورد **لا يربط جهازاً** — `deviceState: null` و `did: null` في التوكن.
النتيجة: **التوكن الصادر من `login` ينجو من إلغاء الجهاز.** ثغرة في نموذج الأمان
يجب سدّها في إعادة البناء بربط الجهاز في مسار الدخول أيضاً.

---

## 7. التوكنات — الإصدار والتجديد والخروج

### 7.1 التجديد

```
POST /api/v1/auth/refresh    { "refreshToken": "<JWT>" }
  → { accessToken, refreshToken }        // بدون كائن المستخدم
```

الخطوات: التحقق بـ `JWT_REFRESH_SECRET` → جلب المستخدم بـ `sub` (وإلا احتياطياً بالإيميل)
→ فحص `isActive` → إن وُجد `did` يجب أن يكون الجهاز نشطاً → إصدار زوج جديد بنفس الـ `did`.

> كل الاستثناءات الداخلية تُبتلع وتُعاد كـ `401 "Invalid refresh token"`.
> الرسائل التفصيلية تظهر في اللوج فقط.

### 7.2 🔴 تسجيل الخروج لا يفعل شيئاً

`logout` يكتب `bcrypt('')` في `users.refreshToken` فقط. **لا يُبطل التوكنات، لا يُلغي
الجهاز، لا يضع التوكن في قائمة سوداء.** التوكنات الصادرة تبقى صالحة حتى انتهاء مدتها
(حتى **7 أيام** للـ refresh).

السبب الجذري: hash الـ refresh token **يُخزَّن ولا يُقارَن أبداً**. البنية موجودة
بالكامل — المقارنة وحدها هي الناقصة.

**الإصلاح المطلوب:** خزّن الـ hash، قارنه عند التجديد، دوّره مع كل تجديد، وصفّره عند الخروج.

### 7.3 آليات الإبطال التي تعمل فعلاً

| الآلية | كيف تعمل |
|---|---|
| `users.passwordChangedAt` | يُرفض أي access token `iat` أقدم منه → `401 "Token expired due to password change"` |
| إلغاء الجهاز | أي توكن يحمل `did` لجهاز غير نشط يُرفض |
| `users.isActive = false` | `401 "User account is inactive"` |
| `users.bannedAt` | `BanGuard` → 403 |

### 7.4 سلسلة التحقق في كل طلب

`JwtStrategy.validate` يُنفَّذ لكل مسار غير `@Public`:

```
1. لا sub ولا email        → 401 "Invalid token payload"
2. تحميل بالـ sub (أو الإيميل احتياطياً)
3. لا مستخدم               → 401 "User not found"
4. !isActive               → 401 "User account is inactive"
5. did موجود وجهاز غير نشط → 401 "Device session is no longer active"
6. iat < passwordChangedAt → 401 "Token expired due to password change"
7. يُعيد UserEntity كاملاً → يصبح req.user
```

> ⚠️ **`req.user` هو `UserEntity` ويحمل `id` وليس `sub`.** أي كود يقرأ `req.user.sub`
> يحصل على `undefined` — وهذا خطأ حيّ في وحدة التقييمات حالياً.

### 7.5 ⚠️ مصادقة WebSocket أضعف

`WsAuthGuard` يقرأ التوكن من `handshake.auth.token` أو `handshake.query.token` أو
ترويسة `Authorization`، ويتحقق منه بـ `JWT_ACCESS_SECRET` — **لكنه لا يستعلم من القاعدة
إطلاقاً**. لذلك لا يرى `isActive` ولا `bannedAt` ولا `restricted` ولا `passwordChangedAt`
ولا إلغاء الجهاز.

**في إعادة البناء: أضف نفس فحوصات قاعدة البيانات إلى مسار الـ WebSocket.**

---

## 8. مخطط قاعدة البيانات المطلوب

### 8.1 `users` (الأعمدة المتعلقة بالهوية)

| العمود | النوع | Null | افتراضي | ملاحظات |
|---|---|---|---|---|
| `id` | uuid | ❌ | `uuid_generate_v4()` | PK |
| `phoneNumber` | varchar | ✅ | — | **UNIQUE** — الفهرس الفريد ضروري لأمان التزامن |
| `email` | varchar | ✅ | — | **UNIQUE** — للأدمن عملياً |
| `name` | varchar(120) | ❌ | — | |
| `passwordHash` | varchar | ✅ | — | `select:false` — لا يُعاد أبداً إلا بطلب صريح |
| `role` | enum | ❌ | `'passenger'` | `passenger\|driver\|admin` |
| `gender` | varchar | ✅ | — | مقيّد بـ `male\|female` في الـ DTO فقط |
| `photoUrl` | text | ✅ | — | **مطلوب قبل اعتماد السائق** |
| `provider` | varchar | ❌ | `'email'` | `phone` للتسجيل الجديد |
| `isActive` | boolean | ❌ | `true` | |
| `isPhoneVerified` | boolean | ❌ | `false` | |
| `isDriverApproved` | boolean | ❌ | `false` | بوابة الأدمن |
| `refreshToken` | varchar | ✅ | — | `select:false` — hash يُكتب ولا يُقرأ |
| `passwordChangedAt` | timestamp | ✅ | `null` | أداة الإبطال الحقيقية |
| `bannedAt` | timestamptz | ✅ | `null` | |
| `banReason` | text | ✅ | `null` | |
| `restricted` | boolean | ❌ | `false` | ⚠️ **لا يوجد مسار لإزالته** |
| `pendingPhoneLink` | boolean | ❌ | `false` | |

### 8.2 `otp_codes` (وضع `local` فقط)

| العمود | النوع | Null | ملاحظات |
|---|---|---|---|
| `id` | uuid | ❌ | PK |
| `phoneNumber` | varchar | ❌ | فهرس مركّب `(phoneNumber, code)` |
| `code` | varchar(6) | ❌ | ⚠️ نص صريح — خزّنه مجزّأً |
| `expiresAt` | timestamp | ❌ | فهرس — ⚠️ **غير مستخدم في الاستعلام حالياً** |
| `isUsed` | boolean | ❌ | افتراضي `false` |

**سلوك الكتابة:** `createOtpCode` يحذف **كل** صفوف `{phoneNumber, isUsed:false}` أولاً،
ثم يُدرج صفاً واحداً بـ `expiresAt = now + 5min`. أي كود واحد حيّ فقط لكل رقم.

### 8.3 `user_devices`

| العمود | النوع | Null | ملاحظات |
|---|---|---|---|
| `id` | uuid | ❌ | PK — **هذا هو `did` في التوكن** |
| `userId` | uuid | ❌ | FK → `users(id)` ON DELETE CASCADE |
| `fingerprintHash` | char(64) | ❌ | SHA-256 hex |
| `platform` | enum | ❌ | `android\|ios` |
| `status` | enum | ❌ | `active\|revoked`، افتراضي `active` |
| `fcmToken` | text | ✅ | |
| `locale` | varchar(8) | ✅ | |
| `label` | varchar(120) | ✅ | ⚠️ لا يُحدَّث على صف موجود |
| `revokedAt` / `revokeReason` | timestamptz / text | ✅ | |
| `lastSeenAt` | timestamptz | ✅ | |

> **أضف قيداً فريداً على `(userId, fingerprintHash)`** — غير موجود حالياً.

---

## 9. قائمة تنفيذ مرتّبة

### المرحلة 1 — الأساس
- [ ] جدول `users` بالفهرس الفريد على `phoneNumber` و `email`
- [ ] جدول `otp_codes` (خزّن الكود **مجزّأً**)
- [ ] إعداد الـ config بأسماء موحّدة: `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`
- [ ] فشل سريع عند الإقلاع إذا كان أي سر مفقوداً أو بالقيمة الافتراضية

### المرحلة 2 — خدمة الرسائل
- [ ] واجهة `OtpProvider` مجرّدة بتنفيذين: `LocalOtpProvider` و `TwilioOtpProvider`
- [ ] بناء عميل Twilio بمنطق الاختيار (API Key أولاً، ثم Auth Token)
- [ ] `sendOtp` → `verifications.create({ to, channel:'sms' })`
- [ ] `verifyOtp` → `verificationChecks.create({ to, code })`، النجاح = `approved`
- [ ] توليد الكود بـ CSPRNG في الوضع المحلي
- [ ] **cooldown 60 ثانية لكل رقم + حد يومي**
- [ ] الفلترة على `expiresAt` + مهمة تنظيف دورية
- [ ] تسجيل كود خطأ Twilio الأصلي في اللوج

### المرحلة 3 — التوكنات
- [ ] `generateTokens` بالحمولة المحدّدة في §1.3
- [ ] تخزين hash الـ refresh token **ومقارنته عند التجديد**
- [ ] تدوير الـ refresh token مع كل تجديد
- [ ] `logout` يصفّر الـ hash فعلياً
- [ ] `JwtStrategy` بسلسلة الفحص السباعية (§7.4)
- [ ] `WsAuthGuard` **بنفس فحوصات قاعدة البيانات**

### المرحلة 4 — مسار الراكب
- [ ] `POST /auth/send-otp`
- [ ] `POST /auth/verify-otp` بالفروع الثلاثة (§4.2)
- [ ] بصمة الجهاز + القيد الفريد على `(userId, fingerprintHash)`
- [ ] **افحص الجهاز الملغى قبل استهلاك الـ OTP**
- [ ] فحص مخاطر تعدد الحسابات
- [ ] قيّد إشعار تسجيل السائق بـ `role === 'driver'`

### المرحلة 5 — مسار السائق
- [ ] `POST /auth/driver/verify-phone` + توكن تسجيل **بسر مستقل**
- [ ] فحص سلبي في `JwtStrategy`: ارفض أي توكن يحمل `purpose`
- [ ] `POST /uploads/registration` بالتحقق من MIME والحجم
- [ ] `POST /auth/driver/register` **في معاملة واحدة** + التقاط `23505`
- [ ] اشتقاق `seatLayout` من كتالوج أنواع المركبات
- [ ] `PATCH /auth/driver/registration` بقواعد §5.6

### المرحلة 6 — الدخول
- [ ] `POST /auth/login` بالفرعين
- [ ] رسائل خطأ موحّدة (لا تسريب لوجود الحساب)
- [ ] **حماية من التخمين: عدّاد محاولات + قفل تصاعدي**
- [ ] **اربط الجهاز في مسار الدخول أيضاً**

### المرحلة 7 — الأمان
- [ ] `BanGuard` + `RestrictedAccountInterceptor`
- [ ] **مسار إداري لإزالة `restricted`** (غير موجود حالياً)
- [ ] `security_events` + **نقطة نهاية لقراءتها**
- [ ] فحص ملكية الملف في `DELETE /uploads/:key`
- [ ] **انقل مستندات الهوية خلف مسار مصادق عليه** (مكشوفة علناً حالياً)

---

## 10. الأخطاء الموروثة — لا تنسخها

| # | المشكلة | الخطورة | الإصلاح |
|---|---|---|---|
| 1 | **ترقية الصلاحيات:** `PATCH /users/me/role` يقبل `{"role":"admin"}` من أي مستخدم | 🔴 حرجة | ارفض أي دور خارج `{passenger, driver}` |
| 2 | `JWT_ACCESS_SECRET` مطلوب في الكود لكن `.env.example` يوثّق `JWT_SECRET` | 🔴 حرجة | وحّد الاسم + فشل سريع عند الإقلاع |
| 3 | توكن تسجيل السائق يشارك سر الـ access token | 🔴 عالية | سر مستقل + فحص `purpose` سلبي |
| 4 | تسجيل الخروج لا يُبطل أي توكن | 🟠 عالية | قارن الـ hash ودوّره وصفّره |
| 5 | مستندات السائق (الرخصة، التأمين) تُقدَّم علناً من `/uploads/**` | 🟠 عالية | مسار مصادق عليه بفحص ملكية |
| 6 | `DELETE /uploads/:key` بلا فحص ملكية | 🟠 عالية | تحقق من المالك |
| 7 | مصادقة WebSocket بلا أي استعلام من القاعدة | 🟠 عالية | أضف الفحوصات |
| 8 | لا حد لإرسال OTP لكل رقم | 🟠 متوسطة | cooldown + حد يومي |
| 9 | كود OTP نص صريح في القاعدة وفي اللوج | 🟡 متوسطة | خزّنه مجزّأً |
| 10 | في الوضع المحلي الكود لا ينتهي أبداً | 🟡 متوسطة | فلترة `expiresAt` + تنظيف |
| 11 | `Math.random()` لتوليد الكود | 🟡 متوسطة | CSPRNG |
| 12 | `restricted` يُضبط ولا يُزال أبداً | 🟡 متوسطة | مسار إداري لإزالته |
| 13 | لا حماية من تخمين الباسورد | 🟡 متوسطة | عدّاد + قفل |
| 14 | لا قيد فريد على `(userId, fingerprintHash)` | 🟡 متوسطة | أضف القيد |
| 15 | استهلاك الـ OTP قبل فحص الجهاز الملغى | 🟢 منخفضة | اعكس الترتيب |
| 16 | إشعار تسجيل السائق يُرسل لكل مستخدم جديد | 🟢 منخفضة | قيّده بالدور |
| 17 | تعارض طول الـ OTP: 6 مقابل 4–6 | 🟢 منخفضة | وحّد على 6 |
| 18 | `JWT_EXPIRES_IN` و `JWT_REFRESH_EXPIRES_IN` لا يُقرآن | 🟢 منخفضة | اقرأهما فعلاً |

---

## 11. كود ميت في هذا المسار — احذفه

| العنصر | السبب |
|---|---|
| جدول `pending_registrations` | لا خدمة ولا مستودع يلمسه — استُبدل بمسار توكن التسجيل |
| `strategies/google.strategy.ts` · `facebook.strategy.ts` | غير مسجّلة كـ providers؛ نقاط النهاية تُعيد `410` |
| `strategies/jwt-refresh.strategy.ts` | مسجّل لكن لا حارس يستخدم استراتيجية `'jwt-refresh'` |
| `modules/users/schemas/*.ts` | مخططات Mongoose من عصر ما قبل Postgres — انقل الـ enums الثلاثة وامسحها |
| `SecurityService` | غير مستخدم |
| `config/s3.config.ts` | يُحمَّل ويُتحقق منه، لكن الرفع على القرص المحلي فقط |
| `config/jwt.config.ts` | يعرّف `JWT_SECRET` الذي لا يقرؤه أحد |
| `OTP_DEV_BYPASS` · `MIN_APP_VERSION` | تُقرأ في الإعداد ولا يستخدمها شيء |
| `cleanupExpiredOtpCodes()` | موجود بلا مُستدعٍ وبلا `@Cron` |
| `users.lastSocialLoginAt` | لا يُكتب أبداً |
| `security_events.correlationId` | لا يُملأ أبداً |
| `TWILIO_PHONE_NUMBER` | مسار Programmable SMS الاحتياطي لا يُستدعى |

---

## 12. مرجع سريع — كل نقاط النهاية

| # | Method | Path | Auth | الغرض |
|---|---|---|---|---|
| 1 | POST | `/api/v1/auth/send-otp` | عام | إرسال كود |
| 2 | POST | `/api/v1/auth/verify-otp` | عام | تحقق + إنشاء/إكمال حساب + توكنات |
| 3 | POST | `/api/v1/auth/driver/verify-phone` | عام | تحقق بلا إنشاء → توكن تسجيل |
| 4 | POST | `/api/v1/uploads/registration` | توكن تسجيل | رفع مستند قبل الحساب |
| 5 | POST | `/api/v1/auth/driver/register` | توكن تسجيل | إنشاء سائق + مركبة (معاملة) |
| 6 | PATCH | `/api/v1/auth/driver/registration` | Bearer | تعديل قبل الموافقة |
| 7 | POST | `/api/v1/auth/login` | عام | دخول بالباسورد |
| 8 | POST | `/api/v1/auth/refresh` | عام | تجديد التوكنات |
| 9 | POST | `/api/v1/auth/logout` | Bearer | خروج (شكلي حالياً) |
| 10 | GET | `/api/v1/auth/devices` | Bearer | قائمة الأجهزة |
| 11 | DELETE | `/api/v1/auth/devices/:deviceId` | Bearer | إلغاء جهاز |
| 12 | PATCH | `/api/v1/admin/users/:id/approve-driver` | أدمن | اعتماد السائق |
