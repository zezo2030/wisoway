# 🔧 حل مشاكل تحميل الخريطة

## المشكلة: الخريطة لا تحمل

إذا كانت الخريطة لا تحمل عند فتحها، اتبع الخطوات التالية:

---

## ✅ الخطوة 1: التحقق من API Key

### 1. تأكد من وجود API Key في AndroidManifest.xml:

```xml
<!-- Google Maps API Key -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw" />
```

**الموقع**: `android/app/src/main/AndroidManifest.xml`

### 2. تأكد من صحة API Key:

- افتح [Google Cloud Console](https://console.cloud.google.com/)
- اذهب إلى **APIs & Services** > **Credentials**
- ابحث عن API Key: `AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw`
- تأكد من أنه **مفعل** و **غير مقيد** أو مقيد بشكل صحيح

---

## ✅ الخطوة 2: تفعيل APIs المطلوبة

### في Google Cloud Console:

1. اذهب إلى **APIs & Services** > **Library**
2. فعّل APIs التالية:

#### ⚠️ **مهم جداً**:
- ✅ **Maps SDK for Android** (مطلوب لعرض الخريطة)
- ✅ **Geocoding API** (مطلوب للحصول على العناوين)

#### اختياري:
- Places API (للبحث عن الأماكن)
- Directions API (لحساب المسارات)

---

## ✅ الخطوة 3: التحقق من إعدادات API Key

### في Google Cloud Console:

1. اذهب إلى **APIs & Services** > **Credentials**
2. اضغط على API Key
3. تحقق من:

#### Application restrictions:
- **Android apps** (محدد)
- Package name: `com.example.rideshare`
- SHA-1 certificate fingerprint (مضاف)

#### API restrictions:
- **Restrict key** (محدد)
- APIs المحددة:
  - ✅ Maps SDK for Android
  - ✅ Geocoding API

---

## ✅ الخطوة 4: الحصول على SHA-1 Fingerprint

### للـ Debug:

```bash
cd android
gradlew signingReport
```

أو:

```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### أضف SHA-1 في:
1. **Google Cloud Console** > API Key > Application restrictions
2. **Firebase Console** > Project Settings > Your apps > Android app > SHA certificate fingerprints

---

## ✅ الخطوة 5: التحقق من Logcat

### شغل التطبيق وتحقق من الأخطاء:

```bash
flutter run
```

### ابحث عن الأخطاء التالية:

#### خطأ API Key:
```
Google Maps Android API: API key not found
```
**الحل**: تأكد من وجود API Key في AndroidManifest.xml

#### خطأ API غير مفعل:
```
Google Maps Android API: API key not valid
```
**الحل**: فعّل Maps SDK for Android في Google Cloud Console

#### خطأ الصلاحيات:
```
DEVELOPER_ERROR
```
**الحل**: أضف SHA-1 fingerprint في Google Cloud Console

#### خطأ الاتصال:
```
Network error
```
**الحل**: تحقق من الاتصال بالإنترنت

---

## ✅ الخطوة 6: إعادة بناء التطبيق

بعد إجراء أي تغييرات:

```bash
flutter clean
flutter pub get
flutter run
```

---

## 🔍 تشخيص المشكلة

### إذا كانت الخريطة تظهر كصفحة بيضاء:

1. **تحقق من API Key**: قد يكون غير صحيح أو غير مفعل
2. **تحقق من Maps SDK**: تأكد من تفعيل Maps SDK for Android
3. **تحقق من Logcat**: ابحث عن أخطاء محددة

### إذا كانت الخريطة لا تظهر على الإطلاق:

1. **تحقق من الاتصال بالإنترنت**
2. **تحقق من API Key في AndroidManifest.xml**
3. **تحقق من تفعيل APIs في Google Cloud Console**

### إذا كانت الخريطة تظهر لكن لا يمكن التفاعل معها:

1. **تحقق من الصلاحيات**: Location permissions
2. **تحقق من الكود**: قد تكون هناك مشكلة في event handlers

---

## 📱 اختبار سريع

### 1. افتح التطبيق:
```bash
flutter run
```

### 2. افتح Location Picker:
- اضغط على أي زر لاختيار الموقع
- يجب أن تفتح الخريطة

### 3. تحقق من:
- ✅ الخريطة تظهر
- ✅ يمكن الضغط على الخريطة
- ✅ يظهر العنوان عند الضغط
- ✅ يمكن سحب العلامة (marker)

---

## 🛠️ حلول إضافية

### إذا استمرت المشكلة:

1. **تحقق من Billing**:
   - Google Maps API يتطلب Billing Account
   - هناك $200 credit مجاني شهرياً

2. **تحقق من Package Name**:
   - تأكد من أن package name في AndroidManifest.xml يطابق Google Cloud Console

3. **جرب API Key جديد**:
   - أنشئ API Key جديد في Google Cloud Console
   - استبدله في AndroidManifest.xml

4. **تحقق من Internet Permission**:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```

5. **تحقق من Location Permissions**:
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```

---

## 📝 Checklist

- [ ] API Key موجود في AndroidManifest.xml
- [ ] Maps SDK for Android مفعل
- [ ] Geocoding API مفعل
- [ ] SHA-1 fingerprint مضاف
- [ ] Package name صحيح
- [ ] Internet permission موجود
- [ ] Location permissions موجودة
- [ ] Billing Account مفعل
- [ ] تم إعادة بناء التطبيق بعد التغييرات

---

## 🔗 روابط مفيدة

- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [Maps SDK for Android Setup](https://developers.google.com/maps/documentation/android-sdk/start)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)
- [Troubleshooting Guide](https://developers.google.com/maps/documentation/android-sdk/troubleshooting)

---

**تاريخ الإنشاء**: 2024
**آخر تحديث**: 2024










