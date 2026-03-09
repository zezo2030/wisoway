# 🚗 فلو تسجيل السائق الجديد

## نظرة عامة

تم تقسيم عملية تسجيل السائق إلى خطوتين منفصلتين لضمان إنشاء الحساب في Firebase Auth أولاً، ثم حفظ البيانات في Firestore.

---

## الفلو الكامل

### الخطوة 1: إنشاء الحساب الأساسي (DriverSignUpScreen)

**الشاشة:** `lib/screens/auth/driver_sign_up_screen.dart`

**المعلومات المطلوبة:**
1. الاسم الأول *
2. اسم العائلة *
3. البريد الإلكتروني *
4. كلمة المرور *
5. الجنس (ذكر/أنثى) *

**ما يحدث:**
1. إنشاء الحساب في **Firebase Auth** باستخدام Email/Password
2. حفظ المعلومات الأساسية في **Firestore**:
   - الاسم الكامل (الاسم الأول + اسم العائلة)
   - البريد الإلكتروني
   - الجنس
   - الدور (`role: 'driver'`)
3. الانتقال إلى الخطوة 2

**ملاحظة:** في هذه المرحلة، المستخدم **مسجل دخول بالفعل** في Firebase Auth، لذلك يمكن الكتابة في Firestore.

---

### الخطوة 2: إكمال الملف الشخصي (DriverCompleteProfileScreen)

**الشاشة:** `lib/screens/auth/driver_complete_profile_screen.dart`

**المعلومات المطلوبة:**
1. الصورة الشخصية *
2. رقم الهاتف * (مع OTP إذا لزم الأمر)
3. نوع المركبة *
4. رقم اللوحة *
5. موديل السيارة *
6. عدد المقاعد *
7. رخصة القيادة *
8. رخصة المركبة *

**ما يحدث:**
1. رفع الصور إلى **Firebase Storage**:
   - الصورة الشخصية
   - رخصة القيادة
   - رخصة المركبة
2. التحقق من رقم الهاتف (OTP) إذا لزم الأمر
3. حفظ معلومات السائق في **Firestore**:
   - تحديث معلومات المستخدم (الصورة، رقم الهاتف)
   - حفظ معلومات المركبة في collection `vehicles`
4. الانتقال إلى الشاشة الرئيسية

---

## الملفات المعنية

### 1. الشاشات

- `lib/screens/auth/driver_sign_up_screen.dart` - الخطوة 1
- `lib/screens/auth/driver_complete_profile_screen.dart` - الخطوة 2

### 2. Routes

- `RouteNames.driverSignUp` - `/driver-sign-up`
- `RouteNames.driverCompleteProfile` - `/driver-complete-profile`

### 3. Services

- `AuthService.signUpWithEmailAndPassword()` - إنشاء الحساب
- `AuthService.saveUserProfile()` - حفظ المعلومات الأساسية
- `AuthService.saveDriverProfile()` - حفظ معلومات السائق الكاملة
- `StorageService` - رفع الصور

---

## مثال على الاستخدام

### من SignInScreen أو AccountTypeSelectionScreen:

```dart
Navigator.pushNamed(
  context,
  RouteNames.driverSignUp,
);
```

### الانتقال بين الخطوات:

```dart
// من DriverSignUpScreen إلى DriverCompleteProfileScreen
Navigator.pushReplacementNamed(
  context,
  RouteNames.driverCompleteProfile,
  arguments: {
    'firstName': _firstNameController.text.trim(),
    'lastName': _lastNameController.text.trim(),
    'email': _emailController.text.trim(),
    'gender': _selectedGender!,
  },
);
```

---

## البيانات المحفوظة في Firestore

### Collection: `users/{userId}`

```javascript
{
  "name": "أحمد محمد",
  "firstName": "أحمد",
  "lastName": "محمد",
  "email": "ahmed@example.com",
  "phoneNumber": "+201234567890",
  "gender": "male",
  "role": "driver",
  "photoUrl": "https://...",
  "isPhoneVerified": true,
  "isEmailVerified": true,
  "rating": 0,
  "totalRatings": 0,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "lastLoginAt": "2024-01-01T00:00:00Z"
}
```

### Collection: `vehicles/{userId}`

```javascript
{
  "driverId": "user123",
  "vehicleType": "sedan",
  "plateNumber": "ABC-123",
  "model": "Toyota Camry 2020",
  "seats": 4,
  "licenseImageUrl": "https://...",
  "vehicleLicenseImageUrl": "https://...",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

---

## معالجة OTP

إذا كان `AppConstants.skipOTP = false`:

1. في **DriverCompleteProfileScreen**، المستخدم يضغط "إرسال" لإرسال OTP
2. يتم الانتقال إلى **OTPVerificationScreen**
3. بعد التحقق من OTP:
   - ربط رقم الهاتف بالحساب
   - حفظ معلومات السائق الكاملة
   - الانتقال إلى الشاشة الرئيسية

---

## الأخطاء الشائعة وحلولها

### 1. "User is not authenticated"

**السبب:** المستخدم لم يسجل دخول في Firebase Auth

**الحل:** تأكد من أن `signUpWithEmailAndPassword` تم تنفيذه بنجاح قبل الانتقال إلى الخطوة 2

### 2. "Permission denied" عند حفظ البيانات

**السبب:** Firestore Security Rules تمنع الكتابة

**الحل:** تأكد من أن المستخدم مسجل دخول في Firebase Auth (ليس Firestore-only mode)

### 3. "Error uploading image"

**السبب:** Firebase Storage غير مفعل أو قواعد Storage تمنع الرفع

**الحل:** 
- تأكد من تفعيل Firebase Storage
- تأكد من نشر Storage Security Rules
- تأكد من أن المستخدم مسجل دخول في Firebase Auth

---

## ملاحظات مهمة

1. **Firebase Auth مطلوب:** يجب إنشاء الحساب في Firebase Auth أولاً قبل حفظ البيانات في Firestore
2. **الترتيب مهم:** لا يمكن حفظ البيانات في Firestore إلا بعد تسجيل الدخول
3. **OTP اختياري:** في وضع التطوير (`skipOTP = true`)، يمكن تخطي OTP
4. **الصور مطلوبة:** جميع الصور (الشخصية، رخصة القيادة، رخصة المركبة) مطلوبة

---

## الفرق بين الفلو القديم والجديد

### الفلو القديم:
- جميع المعلومات في شاشة واحدة
- إنشاء الحساب وحفظ البيانات في نفس الوقت
- قد يفشل إذا لم يكن المستخدم مسجل دخول

### الفلو الجديد:
- تقسيم إلى خطوتين
- إنشاء الحساب أولاً (Firebase Auth)
- ثم حفظ البيانات (Firestore)
- أكثر أماناً وموثوقية

---

## روابط مفيدة

- [FIREBASE_SETUP_GUIDE.md](./FIREBASE_SETUP_GUIDE.md) - دليل إعداد Firebase
- [STORAGE_SETUP.md](../STORAGE_SETUP.md) - دليل إعداد Firebase Storage
- [USER_ROLE_GUIDE.md](./USER_ROLE_GUIDE.md) - دليل نوع المستخدم

