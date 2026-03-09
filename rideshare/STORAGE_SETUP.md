# 📦 إعداد Firebase Storage

## المشكلة

إذا واجهت خطأ `firebase_storage/unauthorized` عند رفع الصور، فهذا يعني أن قواعد Firebase Storage غير موجودة أو مقيدة.

## الحل السريع

### 1. تفعيل Firebase Storage في Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `rideshare-5f785`
3. من القائمة الجانبية، اختر **Storage**
4. إذا لم يكن موجوداً، اضغط **Get started**
5. اختر **Start in test mode**
6. اختر **Location** (اختر نفس موقع Firestore)
7. اضغط **Done**

### 2. نشر Storage Rules (طريقة 1: من Firebase Console)

1. في صفحة **Storage**
2. اضغط على **Rules**
3. احذف القواعد القديمة
4. انسخ القواعد التالية:

**للتطوير (مفتوحة للمستخدمين المسجلين):**

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to read/write/delete
    match /{allPaths=**} {
      allow read, write, delete: if request.auth != null;
    }
  }
}
```

**أو للإنتاج (آمنة ومقيدة):**

انسخ محتوى ملف `storage.rules` من المشروع

5. الصق في Firebase Console
6. اضغط **Publish**

### 3. نشر Storage Rules (طريقة 2: باستخدام Firebase CLI)

```bash
# تأكد من تثبيت Firebase CLI
npm install -g firebase-tools

# تسجيل الدخول
firebase login

# نشر قواعد Storage
firebase deploy --only storage
```

## ملاحظات مهمة

### ⚠️ للمستخدمين في Firestore-only Mode

إذا كنت تستخدم Phone Auth مع `skipOTP = true`، فأنت في **Firestore-only mode** (بدون Firebase Auth).

**المشكلة:** Firebase Storage يتطلب Firebase Auth لرفع الملفات.

**الحلول:**

1. **استخدم Email/Password Auth** (موصى به):
   - سجل الدخول باستخدام Email/Password
   - هذا ينشئ Firebase Auth user
   - يمكنك رفع الملفات بعد ذلك

2. **استخدم Social Login** (Google/Facebook):
   - سجل الدخول باستخدام Google أو Facebook
   - هذا ينشئ Firebase Auth user
   - يمكنك رفع الملفات بعد ذلك

3. **فعّل OTP** (للاستخدام الحقيقي):
   - غيّر `skipOTP = false` في `AppConstants`
   - استخدم Phone Auth مع OTP الحقيقي
   - هذا ينشئ Firebase Auth user

### 📝 قواعد Storage

- **`storage.rules.dev`**: قواعد للتطوير (مفتوحة للمستخدمين المسجلين)
- **`storage.rules`**: قواعد للإنتاج (آمنة ومقيدة)

## التحقق من الإعداد

1. تأكد من تفعيل Firebase Storage في Firebase Console
2. تأكد من نشر Storage Rules
3. تأكد من أن المستخدم مسجل دخول في Firebase Auth (ليس Firestore-only mode)
4. جرب رفع صورة من التطبيق
5. تحقق من Storage → Files في Firebase Console

## روابط مفيدة

- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)
- [Storage Security Rules](https://firebase.google.com/docs/storage/security)
- [FIREBASE_SETUP_GUIDE.md](./FIREBASE_SETUP_GUIDE.md) - دليل إعداد Firebase الكامل

