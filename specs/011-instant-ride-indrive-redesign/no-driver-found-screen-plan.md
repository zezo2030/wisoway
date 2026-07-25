# خطة تنفيذ شاشة «لم نتمكن من العثور على سائق»

**الحالة:** جاهزة للتنفيذ  
**التاريخ:** 2026-07-25  
**النطاق:** تطبيق Flutter + NestJS backend + الاختبارات  
**الخطة الأم:** [`plan.md`](./plan.md)، خصوصًا R0/R1 وحالة انتهاء البحث  
**المرجع البصري المحفوظ:** [`references/no-driver-found-reference.png`](./references/no-driver-found-reference.png)

> هذه وثيقة تنفيذ فقط. الأصل البصري أُضيف إلى التطبيق، لكن لم تُعدّل شاشة
> الإنتاج أو عقد الـ API بعد.

---

## 1. النتيجة المطلوبة

عندما ينتهي طلب الرحلة الفورية من دون مطابقة سائق، تبقى خريطة الرحلة والمسار
ظاهرين، وتظهر ورقة سفلية قريبة جدًا من المرجع تحتوي على:

1. رسم سيارة وعلامة خطأ.
2. عنوان وشرح واضحين.
3. بطاقة نصيحة.
4. زر أساسي يعيد البحث فورًا بنفس بيانات الرحلة.
5. زر ثانوي يغلق تدفق الطلب المنتهي.
6. رابط للدعم.
7. شارة «أمان الرحلة» أعلى الخريطة.

يجب ألّا تظهر سيارات وهمية على الخريطة. أي مؤشرات لسائقين يجب أن تكون مبنية
على بيانات حقيقية ومصرّح بعرضها من الخادم؛ هذه الخطة لا تضيف تتبع مواقع سائقين
تقريبية لأن ذلك قد يوحي بتوفر سائق ويكشف بيانات موقع حساسة.

---

## 2. الأصول البصرية الجاهزة

### 2.1 أصل وقت التشغيل

![رسم حالة عدم العثور على سائق](../../rideshare/assets/illustrations/no_driver_found.png)

| الخاصية | القيمة |
|---|---|
| مسار Flutter | `rideshare/assets/illustrations/no_driver_found.png` |
| المقاس | `640 × 640` |
| الصيغة | PNG / RGBA |
| الخلفية | شفافة، بما في ذلك الزوايا الأربع |
| الحجم الحالي | نحو 138 KB |
| SHA-256 | `FB171ACE6712386F0EA45B32748BF495E702BC64A1D79AFC6899E06FB0CF4635` |
| التسجيل في `pubspec.yaml` | لا يحتاج تعديلًا؛ `assets/` مسجل بالفعل |

استخدام الأصل داخل Flutter:

```dart
Image.asset(
  'assets/illustrations/no_driver_found.png',
  width: 148,
  height: 148,
  fit: BoxFit.contain,
)
```

يجب أن يلفّه المنفذ بـ `Semantics` ويستخدم نصًا محليًا مثل
`instantNoDriversIllustrationLabel` بدل الاعتماد على الصورة لنقل المعنى.

### 2.2 وصف التوليد لإعادة الإنتاج

- الأداة: مولّد الصور المدمج.
- دور صورة المرجع: مرجع للأسلوب والتكوين فقط، وليست هدف تعديل.
- الوصف النهائي: رسم حالة فارغة لتطبيق تنقّل؛ سيارة سيدان رمادية جانبية،
  نوافذ وعجلات فحمية، علامة × حمراء داخل دائرة رفيعة فوق السيارة، وهالة وردية
  شاحبة وخطوط طريق مبسطة؛ أسلوب vector-like مسطح وناعم؛ بلا نص أو أشخاص أو
  شعار أو خريطة أو ظل.
- أُنشئت النسخة الأولية على خلفية chroma موحدة، ثم أزيلت محليًا، وحُجّمت إلى
  640 بكسل مع الحفاظ على alpha.

لا تُولّد أيقونات refresh أو lightbulb أو headset أو shield كصور. استخدم
`Icons` أو `iconsax_plus` حتى تتبع اللون والوضع الداكن وحجم النص وإتاحة الوصول.

---

## 3. مراجعة الوضع الحالي

### Flutter

- الشاشة الحالية:
  `rideshare/lib/screens/passenger/instant_ride_request_screen.dart`.
- `_buildStatusSheet()` يرسل جميع حالات الفشل إلى `_statusView()` العامة.
- حالة الفشل الحالية تعرض `Icons.search_off` وعنوانًا وزرًا واحدًا فقط.
- `_reset()` يمسح `_request` ويعيد المستخدم إلى نموذج الرحلة؛ لا يعيد البحث
  مباشرة كما يفعل زر المرجع.
- `_cancel()` يستدعي `DELETE` فقط عندما يكون الطلب ما زال في حالة بحث؛ لذلك
  زر «إلغاء الطلب» داخل الحالة النهائية يجب أن يغلق الشاشة، لا أن يحاول إلغاء
  طلب منتهٍ.
- الخريطة والمسار ومؤشرا الانطلاق والوصول موجودة بالفعل ويجب إعادة استخدامها.
- مسار الدعم موجود بالفعل: `RouteNames.support`.
- حالات `no_drivers` و`expired` تُعامل كفشل في
  `rideshare/lib/models/instant_ride_models.dart`.

### Backend

- إنشاء الطلب: `POST /instant-rides/requests`.
- جلب الحالة: `GET /instant-rides/requests/:id`.
- الإلغاء: `DELETE /instant-rides/requests/:id`.
- لا يوجد endpoint لإعادة المحاولة بنفس الطلب.
- `InstantRequestStatus.EXPIRED` معرّف لكنه لا يُكتب حاليًا؛ معالج انتهاء الوقت
  و`finalizeNoDrivers()` يكتبان `no_drivers`.
- لا توجد `terminalReason` تميّز بين عدم وجود سائق مؤهل، انتهاء المهلة، أو
  انتهاء عروض السائقين.
- لا توجد علاقة تدقيق تربط المحاولة الجديدة بالمحاولة السابقة.

---

## 4. مواصفة التصميم الدقيقة

### 4.1 تقسيم الشاشة

على شاشة مرجعية بارتفاع يقارب 844 logical px:

- الخريطة: نحو 50–53% من الارتفاع.
- الورقة السفلية: نحو 47–50%، خلفية سطحية، وزوايا علوية `28`.
- ظل أعلى الورقة: blur بين `18–24` وشفافية خفيفة.
- مقبض السحب: `40 × 4`، radius كامل، لون `outlineVariant`.
- الحشو الأفقي: `24`.
- المسافة الآمنة السفلية مأخوذة من `MediaQuery.padding.bottom`.

لا تستخدم ارتفاعًا ثابتًا قد يسبب overflow. التنفيذ المقترح:

- `DraggableScrollableSheet` أو حاوية محسوبة بـ `LayoutBuilder`.
- `initialChildSize: 0.50` تقريبًا.
- `minChildSize: 0.46`.
- `maxChildSize: 0.72`.
- المحتوى الداخلي `SingleChildScrollView` للشاشات الأقصر من 700 px أو عند
  تكبير الخط.
- حدّث `GoogleMap.padding.bottom` وفق ارتفاع الورقة الفعلي بدل القيمة الحالية
  الثابتة `height * 0.42`.

### 4.2 ترتيب محتوى الورقة

| الترتيب | العنصر | المواصفة |
|---|---|---|
| 1 | مقبض السحب | أعلى الورقة، ثم فراغ 10–12 |
| 2 | الرسم | الأصل الجاهز، `136–148`، بلا قص |
| 3 | العنوان | 20–22، وزن 700، محاذاة وسط |
| 4 | الشرح | 14–15، لون `onSurfaceVariant`، line-height نحو 1.45 |
| 5 | بطاقة النصيحة | خلفية `surfaceVariant`/teal خافت، radius 14–16، أيقونة مصباح بلون primary |
| 6 | إعادة المحاولة | ارتفاع 54، عرض كامل، radius 14، `T.primary(context)`، أيقونة refresh |
| 7 | إلغاء الطلب | ارتفاع 54، outlined، عرض كامل، لون النص `onSurface` |
| 8 | الدعم | صف مركزي صغير: headset + سؤال + رابط الدعم |

المسافات المستهدفة:

- بين الرسم والعنوان: `12`.
- بين العنوان والشرح: `8`.
- قبل بطاقة النصيحة: `18`.
- بين البطاقة والزر الأساسي: `18`.
- بين الزرين: `10`.
- قبل الدعم: `18`.

### 4.3 عناصر الخريطة

- احتفظ بالـ `GoogleMap` الفعلي وبالـ polyline الحالي بلون primary وعرض 5.
- احتفظ بعلامة الانطلاق الخضراء والوصول الحمراء.
- أضف بطاقتي اسم صغيرتين فوق الخريطة قرب العلامتين باستخدام Flutter overlays
  مرتبطة بـ `GoogleMapController.getScreenCoordinate()`، لا صورًا ثابتة:
  - الانطلاق: الاسم + «نقطة الانطلاق».
  - الوصول: الاسم + «نقطة الوصول».
- حدّث موضع البطاقتين عند `onCameraMove` وأخفِهما إذا خرجتا عن حدود الجزء
  المرئي من الخريطة.
- أعلى البداية: زر رجوع دائري `46 × 46`.
- أعلى النهاية: شارة معلوماتية `أمان الرحلة` مع shield، ارتفاع نحو 46،
  وخلفية surface. اجعلها غير مضللة:
  - إن لم توجد شاشة أمان مستقلة، تكون `Semantics(button: false)` ولا تبدو
    كزر قابل للنقر.
  - لا تربطها بالدعم تحت اسم «أمان»؛ رابط الدعم موجود منفصلًا في الورقة.
- لا تضف سيارات زخرفية أو أعداد سائقين غير حقيقية.

### 4.4 الوضع الداكن وRTL

- جميع الألوان من `T` أو `Theme.of(context).colorScheme` عدا error red الخاص
  بالرسم الجاهز.
- استخدم `PositionedDirectional` و`EdgeInsetsDirectional`.
- سهم الرجوع يتبع اتجاه اللغة.
- ترتيب icon/text في الأزرار يتبع `Directionality`.
- اختبر العربية RTL والإنجليزية LTR وتكبير النص إلى `1.3`.

---

## 5. النصوص المحلية

عدّل ملفات المصدر فقط:

- `rideshare/lib/l10n/app_ar.arb`
- `rideshare/lib/l10n/app_en.arb`

لا تعدّل ملفات `lib/l10n/generated/` يدويًا؛ أعد توليدها عبر Flutter.

استخدم المفاتيح الحالية حيث يصلح ذلك، وعدّل قيمها:

| المفتاح | العربية المستهدفة | الإنجليزية المستهدفة |
|---|---|---|
| `instantNoDrivers` | لم نتمكن من العثور على سائق حاليًا | We couldn't find a driver right now |
| `instantNoDriversSubtitle` | قد يكون جميع السائقين مشغولين أو لا يوجد سائق قريب منك. | All nearby drivers may be busy, or none may be close to you. |
| `instantTryAgain` | إعادة المحاولة | Try again |
| `instantCancelRequest` | إلغاء الطلب | Cancel request |

أضف:

| المفتاح | العربية | الإنجليزية |
|---|---|---|
| `instantNoDriversTip` | نصيحة: أعد المحاولة بعد بضع دقائق؛ قد يتوفر سائق قريب منك. | Tip: Try again in a few minutes; a nearby driver may become available. |
| `instantNeedHelp` | تحتاج مساعدة؟ | Need help? |
| `instantContactSupport` | تواصل مع الدعم | Contact support |
| `instantRideSafety` | أمان الرحلة | Ride safety |
| `instantPickupPoint` | نقطة الانطلاق | Pickup point |
| `instantDropoffPoint` | نقطة الوصول | Drop-off point |
| `instantNoDriversIllustrationLabel` | لم يتم العثور على سائق | No driver found |
| `instantRetryFareChanged` | تغيّر نطاق السعر؛ راجع السعر ثم أعد الطلب. | The fare range changed. Review the fare before trying again. |

---

## 6. عقد الـ backend المستهدف

### 6.1 تغيير إضافي وغير كاسر في `GET /instant-rides/requests/:id`

أضف إلى الاستجابة:

```json
{
  "status": "expired",
  "terminalReason": "no_eligible_drivers",
  "canRetry": true,
  "retryOfRequestId": null
}
```

قيم `terminalReason`:

- `no_eligible_drivers`: لم يُنشأ أي عرض طوال نافذة البحث.
- `all_declined`: أُنشئ عرض واحد أو أكثر وانتهت كلها بالرفض/انتهاء الوقت.
- `ttl_expired`: انتهت مهلة الطلب أثناء وجود محاولة عرض أو حالة غير محسومة.
- `passenger_cancelled`: للإلغاء الصريح، و`canRetry=false` في هذه الشاشة.

التوافق:

- ابدأ بكتابة `status=expired` للحالات الجديدة المنتهية بلا مطابقة.
- لا تحذف `no_drivers` من enum أو parser في هذه المهمة؛ يجب أن تظل تطبيقات
  أقدم والصفوف القديمة مقروءة.
- Flutter يعرض شاشة عدم العثور على سائق للحالتين `expired` و`no_drivers`.

### 6.2 endpoint إعادة المحاولة

```http
POST /instant-rides/requests/:id/retry
Authorization: Bearer <token>
```

لا يحتاج body. السلوك:

1. يتحقق من ملكية الطلب.
2. يقبل فقط `expired` أو `no_drivers`.
3. يقفل الطلب القديم داخل transaction.
4. إذا كانت هناك محاولة جديدة مرتبطة بهذا الطلب، يعيدها بدل إنشاء طلب ثالث؛
   وبذلك يكون double-tap آمنًا.
5. يعيد حساب quote من إحداثيات الطلب المخزنة.
6. يحتفظ بـ `seatCount` والمسار والسعر الذي أقره الراكب إذا بقي ضمن الحدود.
7. إذا خرج السعر من الحدود الجديدة، يعيد `409` مع
   `code=INSTANT_RETRY_FARE_RECONFIRMATION_REQUIRED` وquote الجديدة؛ لا يغيّر
   سعر الراكب بصمت.
8. ينشئ طلبًا جديدًا بـ TTL وdispatch jobs جديدين، ويربطه بالطلب القديم.
9. يعيد `InstantRequestView` للطلب الجديد.

أخطاء العقد:

| HTTP | code | الحالة |
|---|---|---|
| 403 | السلوك الحالي | الطلب لا يخص المستخدم |
| 404 | السلوك الحالي | الطلب غير موجود |
| 409 | `INSTANT_REQUEST_NOT_RETRYABLE` | الطلب ليس نهائيًا أو ملغيًا |
| 409 | `INSTANT_ACTIVE_REQUEST_EXISTS` | توجد محاولة نشطة أخرى |
| 409 | `INSTANT_RETRY_FARE_RECONFIRMATION_REQUIRED` | السعر يحتاج تأكيدًا جديدًا |

### 6.3 تغييرات قاعدة البيانات

أضف migration additive تحت:
`rideshare-backend/src/database/migrations/`.

حقول `instant_ride_requests`:

| الحقل | النوع | الغرض |
|---|---|---|
| `terminalReason` | `varchar(32) NULL` | سبب الحالة النهائية |
| `endedAt` | `timestamptz NULL` | وقت انتهاء البحث/الإلغاء |
| `retryOfRequestId` | `uuid NULL` | ربط المحاولة الجديدة بالقديمة |

قيود وفهارس:

- FK ذاتي لـ `retryOfRequestId` مع `ON DELETE SET NULL`.
- unique index جزئي على `retryOfRequestId WHERE retryOfRequestId IS NOT NULL`
  لمنع أكثر من retry مباشر للطلب نفسه.
- إذا لم يكن فهرس الطلب النشط الجزئي من R0 قد نُفّذ، أضفه في migration نفسها
  للمستخدم والحالات النشطة فقط؛ لا تعتمد على فحص application-level وحده.

### 6.4 المراقبة والخصوصية

أضف structured log عند:

- انتهاء البحث: `requestId`, `passengerId`, `terminalReason`, وعدد العروض.
- نجاح retry: `oldRequestId`, `newRequestId`, `passengerId`.
- رفض retry: السبب فقط.

لا تسجل الإحداثيات الدقيقة أو العناوين في هذه الرسائل.

---

## 7. ملفات التنفيذ

### Flutter

عدّل:

- `rideshare/lib/screens/passenger/instant_ride_request_screen.dart`
- `rideshare/lib/models/instant_ride_models.dart`
- `rideshare/lib/core/services/instant_ride_service.dart`
- `rideshare/lib/core/api/api_endpoints.dart`
- `rideshare/lib/l10n/app_ar.arb`
- `rideshare/lib/l10n/app_en.arb`

أنشئ:

- `rideshare/lib/screens/passenger/widgets/no_driver_found_sheet.dart`
- `rideshare/lib/screens/passenger/widgets/route_endpoint_label.dart`
- `rideshare/test/screens/passenger/widgets/no_driver_found_sheet_test.dart`
- `rideshare/test/screens/passenger/instant_ride_request_screen_test.dart`

ملاحظة بنيوية: الملف الحالي للشاشة يتجاوز 1400 سطر؛ لا تضف الواجهة الجديدة
كلها إليه. استخرج الورقة وعلامات المسار إلى widgets مستقلة، ومرّر callbacks
وحالة loading لها.

### Backend

عدّل:

- `rideshare-backend/src/database/entities/instant-ride-request.entity.ts`
- `rideshare-backend/src/modules/instant-rides/instant-rides.controller.ts`
- `rideshare-backend/src/modules/instant-rides/instant-rides.service.ts`
- `rideshare-backend/src/modules/instant-rides/instant-dispatch.service.ts`
- `rideshare-backend/src/modules/instant-rides/processors/instant-request-expiry.processor.ts`
- `rideshare-backend/src/modules/instant-rides/instant-rides.service.spec.ts`

أنشئ:

- migration باسم وصفي ينتهي بـ
  `add-instant-terminal-retry-metadata.ts`
- `rideshare-backend/src/modules/instant-rides/processors/instant-request-expiry.processor.spec.ts`
- `rideshare-backend/test/contract/instant-rides/retry-request.contract.spec.ts`

---

## 8. ترتيب التنفيذ

### المرحلة A — اختبارات backend أولًا

- [ ] اختبار سبب النهاية عندما لا يوجد أي offer.
- [ ] اختبار `all_declined` عند وجود offers منتهية.
- [ ] اختبار ownership وحالات retry المسموحة.
- [ ] اختبار أن double-tap يعيد نفس الطلب الجديد.
- [ ] اختبار منع إنشاء طلب نشط ثانٍ تحت التزامن.
- [ ] اختبار إعادة التحقق من السعر وعدم تغييره بصمت.

### المرحلة B — migration وعقد backend

- [ ] إضافة الحقول والقيود additive.
- [ ] توحيد إنهاء الطلب في helper واحد يكتب status/reason/endedAt.
- [ ] تحديث `finalizeNoDrivers()` ومعالج expiry لاستخدام helper.
- [ ] إضافة `retryRequest()` transactionally.
- [ ] إضافة route وSwagger responses.
- [ ] تحديث `toRequestView()` بالحقول الإضافية.
- [ ] إضافة logs من دون PII مكاني.

### المرحلة C — نماذج وخدمة Flutter

- [ ] إضافة `terminalReason`, `canRetry`, `retryOfRequestId` إلى
  `InstantRequest`.
- [ ] إبقاء parser متوافقًا إذا لم تُرسل الحقول من backend أقدم.
- [ ] إضافة endpoint builder و`InstantRideService.retryRequest(id)`.
- [ ] حقن service أو abstraction في الشاشة لتصبح قابلة للاختبار.

### المرحلة D — الواجهة

- [ ] استخراج `NoDriverFoundSheet`.
- [ ] استخدام الأصل الجاهز.
- [ ] إبقاء المسار والخريطة ظاهرين مع padding ديناميكي.
- [ ] إضافة route endpoint overlays.
- [ ] إضافة شارة أمان الرحلة.
- [ ] ربط «إعادة المحاولة» بالـ endpoint الجديد.
- [ ] أثناء retry: تعطيل الزرين وإظهار spinner داخل الزر، ومنع النقر المزدوج.
- [ ] عند النجاح: استبدال `_request` بالطلب الجديد، تشغيل polling فورًا،
  والعودة إلى searching sheet من دون المرور بنموذج الإدخال.
- [ ] عند خطأ الشبكة: إبقاء شاشة الفشل وإظهار `ErrorSurface`.
- [ ] عند خطأ إعادة تأكيد السعر: العودة إلى form sheet بالـ quote الجديدة
  وإظهار `instantRetryFareChanged`.
- [ ] «إلغاء الطلب» في الحالة النهائية ينفذ `Navigator.maybePop()` فقط.
- [ ] رابط الدعم يفتح `RouteNames.support`.

### المرحلة E — التعريب والتحقق

- [ ] تحديث ARB وإعادة توليد l10n.
- [ ] فحص RTL/LTR والوضعين الفاتح والداكن.
- [ ] فحص 360×640 و390×844 وtablet.
- [ ] فحص text scale 1.3 وعدم وجود overflow.

---

## 9. اختبارات Flutter المطلوبة

1. `no_drivers` يعرض الرسم والعنوان والنصيحة والزرين والدعم.
2. `expired` يعرض نفس الورقة.
3. `cancelled` لا يستخدم ورقة «لم نجد سائقًا».
4. retry الناجح يرسل id الصحيح وينقل الحالة إلى searching.
5. الضغط المزدوج لا يرسل طلبين من التطبيق.
6. فشل retry يبقي الورقة ولا يمسح بيانات الرحلة.
7. زر الإلغاء النهائي يغلق الشاشة ولا يستدعي `DELETE`.
8. رابط الدعم يستخدم `RouteNames.support`.
9. Semantics تتضمن عنوان الفشل ووصف الرسم وأسماء الأزرار.
10. لا overflow على viewport صغير أو text scale 1.3.
11. golden بالعربية للورقة على 390×844، وgolden إنجليزية واحدة للتحقق من LTR.

---

## 10. معايير القبول

- [ ] التطابق البصري مع المرجع واضح في تقسيم الخريطة/الورقة، الزوايا،
  التسلسل، المسافات، وبروز الزر الأساسي.
- [ ] الرسم يُحمّل من المسار المحدد ولا توجد أيقونة placeholder.
- [ ] الخريطة والمسار ونقطتا البداية والوصول تبقى ظاهرة.
- [ ] لا تظهر بيانات سائق وهمية أو مواقع حساسة.
- [ ] إعادة المحاولة تبدأ بحثًا جديدًا مباشرةً بنفس الرحلة.
- [ ] إعادة المحاولة آمنة تحت double-tap والتزامن.
- [ ] السعر لا يتغير بصمت.
- [ ] الطلب القديم يبقى نهائيًا وقابلًا للتدقيق.
- [ ] التطبيق يتعامل مع `no_drivers` القديم و`expired` الجديد.
- [ ] العربية والإنجليزية والوضع الداكن وإتاحة الوصول تعمل.
- [ ] لا يُكسر عقد عميل أقدم؛ التغييرات في الاستجابة إضافية.
- [ ] اختبارات backend وFlutter والتحليل والبناء تمر.

---

## 11. أوامر التحقق

من `rideshare-backend/`:

```powershell
npm test -- --runInBand
npm run build
npm run lint
```

من `rideshare/`:

```powershell
dart run tool/check_i18n_parity.dart
flutter analyze
flutter test
```

نفّذ migration على قاعدة اختبار PostgreSQL قبل contract/E2E tests. لا تعتمد
اختبارات القيود والتزامن على repository mocks فقط.

---

## 12. فحص الدستور

- **ثبات العقد:** الحقول والـ endpoint إضافية، مع إبقاء `no_drivers`.
- **الاختبارات أولًا:** مراحل التنفيذ تبدأ باختبارات backend ثم Flutter.
- **المراقبة:** أسباب الانتهاء ومحاولات retry مسجلة structured.
- **الخصوصية:** لا سجلات إحداثيات ولا سيارات وهمية أو مواقع سائقين.
- **التكافؤ:** backend وFlutter والتعريب يسلّمون في التغيير نفسه.

لا توجد مخالفة دستورية متوقعة إذا نُفّذت الخطة كما هي.
