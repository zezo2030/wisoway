# إعداد Firebase وحل المشاكل الشائعة

## حل مشكلة GoogleApiManager SecurityException

هذا الخطأ يحدث عادة عندما يكون SHA-1 fingerprint غير مسجل في Firebase Console.

### خطوات الحل:

#### 1. الحصول على SHA-1 Fingerprint

**للـ Debug Build:**
```bash
# في Windows (PowerShell)
cd android
.\gradlew signingReport

# أو باستخدام keytool مباشرة
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**للـ Release Build:**
```bash
# استبدل path/to/your/keystore.jks بمسار ملف الـ keystore الخاص بك
keytool -list -v -keystore path/to/your/keystore.jks -alias your-key-alias
```

#### 2. إضافة SHA-1 في Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `rideshare-5f785`
3. اذهب إلى **Project Settings** (⚙️)
4. اختر تطبيق Android الخاص بك
5. في قسم **SHA certificate fingerprints**، اضغط **Add fingerprint**
6. الصق SHA-1 fingerprint الذي حصلت عليه من الخطوة السابقة
7. احفظ التغييرات

#### 3. تحميل google-services.json المحدث

بعد إضافة SHA-1، قم بتحميل ملف `google-services.json` المحدث من Firebase Console:
1. في صفحة Project Settings، اضغط **Download google-services.json**
2. استبدل الملف الموجود في `android/app/google-services.json`

#### 4. إعادة بناء التطبيق

```bash
flutter clean
flutter pub get
flutter run
```

---

## إعداد Firebase App Check

تم إضافة Firebase App Check في الكود لحماية APIs من الإساءة.

### للـ Development:
- يستخدم `AndroidProvider.debug` و `AppleProvider.debug`
- يعمل تلقائياً بدون إعدادات إضافية

### للـ Production:
يجب تغيير الإعدادات في `lib/main.dart`:

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.deviceCheck, // أو playIntegrity
  appleProvider: AppleProvider.deviceCheck, // أو appAttest
);
```

**ملاحظة:** يجب تفعيل App Check في Firebase Console قبل استخدامه في Production.

---

## حل تحذيرات Firebase Locale

تم تحسين الكود لتجنب تحذيرات `X-Firebase-Locale`:
- يتم تعيين Locale بشكل صحيح عند بدء التطبيق
- يتم تحديث Locale تلقائياً عند تغيير اللغة في التطبيق

---

## التحقق من الإعدادات

### 1. التحقق من package name
تأكد أن `applicationId` في `android/app/build.gradle.kts` يطابق `package_name` في `google-services.json`:
- `applicationId = "com.example.rideshare"`
- `package_name: "com.example.rideshare"`

### 2. التحقق من Firebase Configuration
تأكد أن ملف `google-services.json` موجود في `android/app/` وأنه يحتوي على:
- `project_id`: `rideshare-5f785`
- `package_name`: `com.example.rideshare`
- `mobilesdk_app_id`: `1:907014658060:android:2376f0e8dc4dd5141f7629`

---

## مشاكل شائعة أخرى

### خطأ GeneratedPluginRegistrant
هذا الخطأ عادة غير خطير ويحدث أثناء تهيئة الإضافات. إذا استمر، جرب:
```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

### تحذيرات Garbage Collection
هذه رسائل طبيعية من Android لإدارة الذاكرة ولا تحتاج أي إجراء.

---

## روابط مفيدة

- [Firebase Console](https://console.firebase.google.com/)
- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [FlutterFire Documentation](https://firebase.flutter.dev/)








