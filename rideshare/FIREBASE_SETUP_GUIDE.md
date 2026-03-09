# 🔥 دليل إعداد Firebase

## خطوات تفعيل Authentication في Firebase Console

### 1. تفعيل Email/Password Authentication

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `rideshare-5f785`
3. من القائمة الجانبية، اختر **Authentication**
4. اضغط على **Sign-in method** (أو **طريقة تسجيل الدخول**)
5. ابحث عن **Email/Password** في القائمة
6. اضغط على **Email/Password**
7. فعّل **Enable** في الأعلى
8. (اختياري) فعّل **Email link (passwordless sign-in)** إذا أردت
9. اضغط **Save**

### 2. تفعيل Phone Authentication

1. في نفس صفحة **Sign-in method**
2. ابحث عن **Phone** في القائمة
3. اضغط على **Phone**
4. فعّل **Enable**
5. (اختياري) أضف **App verification** إذا أردت
6. اضغط **Save**

### 3. تفعيل Anonymous Authentication (للتطوير)

1. في نفس صفحة **Sign-in method**
2. ابحث عن **Anonymous** في القائمة
3. اضغط على **Anonymous**
4. فعّل **Enable**
5. اضغط **Save**

### 4. تفعيل Google Sign-In (اختياري)

1. في نفس صفحة **Sign-in method**
2. ابحث عن **Google** في القائمة
3. اضغط على **Google**
4. فعّل **Enable**
5. أدخل **Project support email**
6. اضغط **Save**

### 5. تفعيل Facebook Sign-In (اختياري)

1. في نفس صفحة **Sign-in method**
2. ابحث عن **Facebook** في القائمة
3. اضغط على **Facebook**
4. فعّل **Enable**
5. أدخل **App ID** و **App Secret** من Facebook Developer
6. اضغط **Save**

---

## خطوات تفعيل Cloud Firestore

### 1. إنشاء Firestore Database

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `rideshare-5f785`
3. من القائمة الجانبية، اختر **Firestore Database**
4. إذا لم يكن موجوداً، اضغط **Create database**
5. اختر **Start in test mode** (للتطوير)
6. اختر **Location** (اختر الأقرب لك)
7. اضغط **Enable**

### 2. إعداد Security Rules (للتطوير)

1. في صفحة **Firestore Database**
2. اضغط على **Rules**
3. استبدل القواعد الحالية بـ:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access to users collection for authenticated users
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow read/write for development (remove in production!)
    match /{document=**} {
      allow read, write: if true; // ⚠️ Development only!
    }
  }
}
```

4. اضغط **Publish**

⚠️ **تحذير**: هذه القواعد مفتوحة للتطوير فقط! يجب تغييرها للإنتاج.

---

## خطوات تفعيل Firebase Storage

### 1. إنشاء Storage Bucket

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `rideshare-5f785`
3. من القائمة الجانبية، اختر **Storage**
4. إذا لم يكن موجوداً، اضغط **Get started**
5. اختر **Start in test mode** (للتطوير)
6. اختر **Location** (اختر نفس موقع Firestore)
7. اضغط **Done**

### 2. نشر Storage Security Rules

#### للتطوير (قواعد مفتوحة):

1. في صفحة **Storage**
2. اضغط على **Rules**
3. استبدل القواعد الحالية بـ:

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

4. اضغط **Publish**

#### للإنتاج (قواعد آمنة):

استخدم ملف `storage.rules` الموجود في المشروع:

1. في صفحة **Storage** → **Rules**
2. انسخ محتوى ملف `storage.rules` من المشروع
3. الصق في Firebase Console
4. اضغط **Publish**

**أو** استخدم Firebase CLI:

```bash
firebase deploy --only storage
```

⚠️ **تحذير**: قواعد التطوير مفتوحة للمستخدمين المسجلين فقط. يجب استخدام قواعد الإنتاج في الإنتاج.

### 3. التحقق من Storage

1. اذهب إلى **Storage** → **Files**
2. يجب أن ترى مجلدات: `profiles`, `driver_licenses`, `vehicle_licenses`
3. جرب رفع صورة من التطبيق
4. يجب أن تظهر الصورة في Storage

---

## التحقق من الإعداد

### 1. التحقق من Authentication

1. اذهب إلى **Authentication** → **Users**
2. يجب أن ترى قائمة المستخدمين المسجلين
3. إذا لم ترى أي مستخدمين، جرب إنشاء حساب جديد من التطبيق

### 2. التحقق من Firestore

1. اذهب إلى **Firestore Database** → **Data**
2. يجب أن ترى collection باسم `users`
3. يجب أن ترى documents للمستخدمين المسجلين
4. **ملاحظة:** في Firestore-only mode، المستخدمون موجودون في Firestore فقط (ليس في Authentication → Users)

---

## حل المشاكل الشائعة

### المشكلة: "Email/Password Authentication غير مفعل"

**الحل:**
- اتبع الخطوات في القسم 1 أعلاه
- تأكد من تفعيل **Email/Password** في Firebase Console

### المشكلة: "Cloud Firestore API غير مفعل"

**الحل:**
- اتبع الخطوات في القسم 2 أعلاه
- أو اذهب إلى: https://console.developers.google.com/apis/api/firestore.googleapis.com/overview?project=rideshare-5f785

### المشكلة: "Permission denied" عند حفظ البيانات

**الحل:**
- تأكد من تحديث Security Rules كما هو موضح أعلاه
- تأكد من أن المستخدم مسجل دخول

### المشكلة: "admin-restricted-operation" أو "Anonymous Auth failed"

**الحل:**
- هذا **طبيعي** في وضع التطوير!
- التطبيق يستخدم **Firestore-only mode** تلقائياً
- المستخدمون يتم إنشاؤهم في Firestore مباشرة
- يمكنك تفعيل Anonymous Auth إذا أردت (اختياري):
  1. Authentication → Sign-in method → Anonymous → Enable

**ملاحظة:** Firestore-only mode يعمل بشكل كامل للتطوير. لا حاجة لتفعيل Anonymous Auth إلا إذا أردت استخدام Firebase Authentication.

### المشكلة: لا أرى مستخدمين في Firebase Console

**الحل:**
1. تأكد من تفعيل **Email/Password Authentication** (للتسجيل بالبريد)
2. تحقق من **Firestore Database** → **Data** → collection `users`
3. في Firestore-only mode، المستخدمون موجودون في Firestore فقط (ليس في Authentication)
4. تأكد من أن التطبيق يعمل بدون أخطاء
5. تحقق من Console logs في التطبيق
6. جرب إنشاء حساب جديد

### المشكلة: "User is not authorized to perform the desired action" عند رفع الصور

**الحل:**
1. تأكد من تفعيل **Firebase Storage** في Firebase Console
2. تأكد من نشر **Storage Security Rules** (انظر القسم أعلاه)
3. تأكد من أن المستخدم **مسجل دخول** في Firebase Auth (ليس Firestore-only mode)
4. للتحقق من تسجيل الدخول:
   - استخدم **Email/Password Auth** أو **Social Login**
   - لا تستخدم Phone Auth مع `skipOTP = true` (لأنه لا ينشئ Firebase Auth user)
5. إذا كنت تستخدم Firestore-only mode، يجب أن تستخدم Firebase Auth لرفع الملفات:
   - غيّر `skipOTP = false` في `AppConstants`
   - أو استخدم Email/Password Auth بدلاً من Phone Auth

---

## روابط مفيدة

- [Firebase Console](https://console.firebase.google.com/)
- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [Cloud Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)

---

**آخر تحديث:** 2024

