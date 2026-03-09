# 🚀 دليل نشر Cloud Functions

## 📋 المتطلبات

1. ✅ Node.js مثبت (الإصدار 18 أو أحدث)
2. ✅ Firebase CLI مثبت
3. ✅ تسجيل الدخول إلى Firebase
4. ✅ المشروع مهيأ

---

## 🔧 الخطوة 1: تثبيت Firebase CLI (إذا لم يكن مثبتاً)

```bash
npm install -g firebase-tools
```

للتحقق من التثبيت:
```bash
firebase --version
```

---

## 🔐 الخطوة 2: تسجيل الدخول إلى Firebase

```bash
firebase login
```

سيتم فتح المتصفح لتسجيل الدخول. بعد تسجيل الدخول، ارجع إلى Terminal.

---

## 📁 الخطوة 3: التأكد من المجلد الصحيح

تأكد أنك في مجلد المشروع الرئيسي:

```bash
cd C:\Users\HP\Desktop\mahoudmsq\rideshare
```

---

## 📦 الخطوة 4: تثبيت Dependencies

```bash
cd functions
npm install
cd ..
```

**ملاحظة:** إذا كان `node_modules` موجوداً بالفعل، يمكنك تخطي هذه الخطوة.

---

## ✅ الخطوة 5: التحقق من الإعدادات

تأكد من:
- ✅ `functions/index.js` موجود
- ✅ `functions/package.json` موجود
- ✅ `firebase.json` يحتوي على إعدادات functions

---

## 🚀 الخطوة 6: النشر

### الطريقة 1: نشر جميع Functions

```bash
firebase deploy --only functions
```

### الطريقة 2: نشر Function معينة

```bash
firebase deploy --only functions:onBookingCreated
```

### الطريقة 3: نشر مع رسائل تفصيلية

```bash
firebase deploy --only functions --debug
```

---

## 📊 ما سيحدث أثناء النشر

1. **التحقق من الكود** - Firebase يتحقق من صحة الكود
2. **تثبيت Dependencies** - تثبيت جميع الحزم المطلوبة
3. **رفع الكود** - رفع Functions إلى Firebase
4. **النشر** - نشر Functions على الخوادم
5. **عرض النتائج** - عرض روابط Functions المنشورة

---

## ✅ بعد النشر

ستحصل على روابط مثل:

```
✔  functions[onBookingCreated(us-central1)] Successful create operation.
✔  functions[sendTestNotification(us-central1)] Successful create operation.
```

---

## 🧪 اختبار Functions

### اختبار Function يدوية:

```bash
# في Flutter
final functionsService = CloudFunctionsService();
await functionsService.sendTestNotification(
  userId: 'user123',
  title: 'اختبار',
  body: 'هذا اختبار',
);
```

### عرض Logs:

```bash
firebase functions:log
```

### عرض Logs لـ Function معينة:

```bash
firebase functions:log --only onBookingCreated
```

---

## ⚠️ حل المشاكل الشائعة

### 1. خطأ: "Functions directory not found"

**الحل:**
```bash
# تأكد أنك في المجلد الرئيسي
cd C:\Users\HP\Desktop\mahoudmsq\rideshare

# تأكد من وجود مجلد functions
ls functions
```

### 2. خطأ: "npm install failed"

**الحل:**
```bash
cd functions
rm -rf node_modules package-lock.json
npm install
cd ..
```

### 3. خطأ: "Permission denied"

**الحل:**
```bash
# تأكد من تسجيل الدخول
firebase login

# تأكد من المشروع الصحيح
firebase use rideshare-5f785
```

### 4. خطأ: "Billing account required"

**الحل:**
- اذهب إلى Firebase Console
- اذهب إلى Project Settings > Billing
- أضف Billing account (Blaze plan مطلوب لـ Cloud Functions)

---

## 📝 ملاحظات مهمة

### 1. Billing Plan
- ⚠️ Cloud Functions تحتاج **Blaze Plan** (Pay as you go)
- ✅ الـ Plan الأول مجاني (Free tier)
- 💰 بعد ذلك: $0.40 لكل مليون استدعاء

### 2. Node.js Version
- ✅ يجب أن يكون Node.js 18 أو أحدث
- ✅ تم تحديده في `functions/package.json`

### 3. Scheduled Functions
- ⚠️ `sendTripReminders` تحتاج تفعيل Pub/Sub API
- ✅ اذهب إلى Google Cloud Console
- ✅ فعّل Cloud Pub/Sub API

---

## 🔍 التحقق من النشر

### 1. في Firebase Console:
- اذهب إلى: https://console.firebase.google.com
- اختر المشروع: `rideshare-5f785`
- اذهب إلى: Functions
- ستجد جميع Functions المنشورة

### 2. في Terminal:
```bash
firebase functions:list
```

---

## 🎯 الخطوة التالية

بعد النشر:
1. ✅ اختبار Functions في Firebase Console
2. ✅ اختبار من التطبيق
3. ✅ مراقبة Logs
4. ✅ التحقق من الإشعارات

---

## 📚 مراجع

- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)
- [Deploy Functions](https://firebase.google.com/docs/functions/deploy)
- [Functions Pricing](https://firebase.google.com/pricing)

---

**جاهز للنشر!** 🚀








