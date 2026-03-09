# 🔐 Authentication Flow - تدفق المصادقة

## نظرة عامة

التطبيق يستخدم **Firebase Authentication** لإنشاء وتسجيل الدخول للمستخدمين، مع حفظ بياناتهم الإضافية في **Cloud Firestore**.

---

## طرق التسجيل المتاحة

### 1. ✅ Email/Password (يعمل مع Firebase Auth دائماً)

**الكود:** `signUpWithEmailAndPassword()`

**كيف يعمل:**
1. ينشئ المستخدم في **Firebase Authentication** باستخدام `createUserWithEmailAndPassword()`
2. يحفظ بيانات المستخدم الأساسية في **Firestore**
3. المستخدم يظهر في **Firebase Console → Authentication → Users**

**الحالة:** ✅ **يعمل دائماً مع Firebase Auth**

---

### 2. ✅ Phone OTP (Production Mode)

**الكود:** `sendOTP()` → `verifyOTP()`

**كيف يعمل:**
1. يرسل OTP عبر Firebase Phone Authentication
2. عند التحقق من OTP، ينشئ المستخدم في **Firebase Authentication** باستخدام `signInWithCredential()`
3. يحفظ بيانات المستخدم في **Firestore**
4. المستخدم يظهر في **Firebase Console → Authentication → Users**

**الحالة:** ✅ **يعمل مع Firebase Auth** (عند `printOTPToConsole = false`)

---

### 3. ⚠️ Phone OTP (Development Mode - Console OTP)

**الكود:** `sendOTP()` → `verifyOTP()` (مع `printOTPToConsole = true`)

**كيف يعمل:**
1. يطبع OTP في Console (بدلاً من إرسال SMS)
2. عند التحقق من OTP:
   - **يحاول** استخدام `signInAnonymously()` أولاً
   - إذا نجح: ينشئ المستخدم في **Firebase Authentication** ✅
   - إذا فشل: يستخدم **Firestore-only mode** (لا Firebase Auth) ⚠️

**الحالة:** ⚠️ **قد يستخدم Firestore-only mode** إذا فشل Anonymous Auth

**الحل:** تفعيل Anonymous Auth في Firebase Console

---

### 4. ✅ Social Login (Google/Facebook)

**الكود:** `signInWithGoogle()` / `signInWithFacebook()`

**كيف يعمل:**
1. ينشئ المستخدم في **Firebase Authentication** باستخدام `signInWithCredential()`
2. يحفظ بيانات المستخدم في **Firestore**
3. المستخدم يظهر في **Firebase Console → Authentication → Users**

**الحالة:** ✅ **يعمل دائماً مع Firebase Auth**

---

## Firestore-only Mode

### متى يتم استخدامه؟

يتم استخدام **Firestore-only mode** فقط في الحالات التالية:

1. **Phone OTP (Development)** - عندما:
   - `printOTPToConsole = true`
   - Anonymous Auth فشل أو غير مفعل
   - يتم إنشاء المستخدم مباشرة في Firestore بدون Firebase Auth

2. **Skip OTP Mode** - عندما:
   - `skipOTP = true`
   - Anonymous Auth فشل أو غير مفعل
   - يتم إنشاء المستخدم مباشرة في Firestore بدون Firebase Auth

### الفرق بين Firebase Auth و Firestore-only Mode

| الميزة | Firebase Auth | Firestore-only Mode |
|--------|---------------|---------------------|
| إنشاء المستخدم | ✅ في Firebase Authentication | ❌ فقط في Firestore |
| الظهور في Console | ✅ Authentication → Users | ❌ فقط في Firestore → Data |
| Security Rules | ✅ يمكن استخدام `request.auth` | ❌ لا يمكن استخدام `request.auth` |
| الحالة الحالية | ✅ الإنتاج | ⚠️ التطوير فقط |

---

## الإعدادات الحالية

```dart
// lib/core/constants/app_constants.dart
static const bool skipOTP = true;               // تم تعطيل تسجيل الدخول عبر الهاتف
static const bool printOTPToConsole = false;    // لا توجد أكواد OTP في الـConsole
// static const bool forceFirebaseAuth = false; // أزيل دعم Anonymous Auth
```

### مع هذه الإعدادات:

- ✅ **Email/Password**: يستخدم Firebase Auth دائماً
- ✅ **Social Login**: يستخدم Firebase Auth دائماً
- 🚫 **Phone OTP**: معطل تماماً (زر التبديل للهاتف مخفي ولا يتم إرسال أو قبول OTP)

### خيار forceFirebaseAuth:

إذا قمت بتعيين `forceFirebaseAuth = true`:
- ❌ **Phone OTP**: سيرمي خطأ إذا فشل Anonymous Auth (بدلاً من استخدام Firestore-only mode)
- ⚠️ **يجب** تفعيل Anonymous Auth في Firebase Console
- ✅ يضمن استخدام Firebase Auth دائماً

---

## كيفية التأكد من استخدام Firebase Auth

### 1. تحقق من Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `rideshare-5f785`
3. اذهب إلى **Authentication** → **Users**
4. يجب أن ترى المستخدمين المسجلين هنا

### 2. تحقق من Console Logs

عند التسجيل، ابحث عن:
```
✅ User created in Firebase Auth: [user-id]
```

أو:
```
📝 FIRESTORE-ONLY MODE
```

### 3. تحقق من Firestore

1. اذهب إلى **Firestore Database** → **Data**
2. ابحث عن collection `users`
3. يجب أن ترى documents للمستخدمين

---

## التوصيات

### للتطوير:
- 🚫 Phone OTP معطل حالياً بناءً على المتطلب.
- ✅ استخدم Email/Password أو Social Login للاختبارات.
- ⚠️ لإعادة اختبار OTP مستقبلاً: اجعل `skipOTP = false` (ويمكن ضبط `printOTPToConsole = true` للتجارب بدون SMS).

### للإنتاج:
- 🚫 Phone OTP معطل (ابقِ `skipOTP = true` و `printOTPToConsole = false`).
- ✅ اعتمد طرق Email/Password و Social Login فقط.
- ⚠️ إذا احتجت إعادة تفعيل OTP لاحقاً: عطّل هذا الإعداد، فعّل Firebase Phone Auth وخصص إرسال SMS.

## كيفية تفعيل Anonymous Auth (للتطوير)

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `rideshare-5f785`
3. **Authentication** → **Sign-in method**
4. ابحث عن **Anonymous** في القائمة
5. اضغط على **Anonymous**
6. فعّل **Enable**
7. اضغط **Save**

بعد التفعيل، Phone OTP سيستخدم Firebase Auth بدلاً من Firestore-only mode.

---

## ملخص

| طريقة التسجيل | Firebase Auth | Firestore |
|----------------|---------------|-----------|
| Email/Password | ✅ دائماً | ✅ دائماً |
| Phone OTP (Production) | ✅ دائماً | ✅ دائماً |
| Phone OTP (Dev Console) | ⚠️ إذا نجح Anonymous | ✅ دائماً |
| Social Login | ✅ دائماً | ✅ دائماً |

---

**آخر تحديث:** 2024

