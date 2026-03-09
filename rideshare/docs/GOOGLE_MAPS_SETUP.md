# 🗺️ إعداد Google Maps API

## المشكلة

عند تحديد الموقع من الخريطة لا يعمل - قد يكون السبب عدم تفعيل APIs المطلوبة في Google Cloud Console.

---

## ✅ الحل: تفعيل Google Maps APIs

### الخطوة 1: الذهاب إلى Google Cloud Console

1. افتح [Google Cloud Console](https://console.cloud.google.com/)
2. اختر المشروع: `rideshare-5f785`
3. أو أنشئ مشروع جديد إذا لم يكن موجوداً

---

### الخطوة 2: تفعيل APIs المطلوبة

اذهب إلى **APIs & Services** > **Library** وقم بتفعيل:

#### 1. Maps SDK for Android
- ابحث عن "Maps SDK for Android"
- اضغط **Enable**

#### 2. Maps SDK for iOS (إذا كنت تستخدم iOS)
- ابحث عن "Maps SDK for iOS"
- اضغط **Enable**

#### 3. Geocoding API ⚠️ **مهم جداً**
- ابحث عن "Geocoding API"
- اضغط **Enable**
- **هذا API ضروري للحصول على العناوين من الإحداثيات**

#### 4. Places API (اختياري - للمستقبل)
- ابحث عن "Places API"
- اضغط **Enable**
- مفيد للبحث عن الأماكن

---

### الخطوة 3: التحقق من API Key

#### في AndroidManifest.xml:

```xml
<!-- Google Maps API Key -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw" />

#### التحقق من API Key:

1. اذهب إلى **APIs & Services** > **Credentials**
2. ابحث عن API Key: `AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw`
3. اضغط على API Key للتحرير

#### إعدادات API Key الموصى بها:

1. **Application restrictions**:
   - اختر **Android apps**
   - أضف package name: `com.example.rideshare`
   - أضف SHA-1 certificate fingerprint (للـ debug و release)

2. **API restrictions**:
   - اختر **Restrict key**
   - اختر APIs التالية:
     - Maps SDK for Android
     - Geocoding API
     - Places API (إن كان مفعلاً)

---

### الخطوة 4: الحصول على SHA-1 Fingerprint

#### للـ Debug:

```bash
# Windows
cd android
gradlew signingReport

# أو
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

#### للـ Release:

```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
```

**ملاحظة**: استبدل `upload-keystore.jks` و `upload` بقيمك الفعلية.

---

### الخطوة 5: تفعيل Billing (إن لزم الأمر)

Google Maps API يتطلب تفعيل Billing Account:

1. اذهب إلى **Billing** في Google Cloud Console
2. أضف Billing Account
3. **ملاحظة**: هناك $200 credit مجاني شهرياً

---

## 🔍 التحقق من المشكلة

### إذا كانت الخريطة لا تظهر:

1. **تحقق من Logcat**:
   ```bash
   flutter run
   # ابحث عن أخطاء مثل:
   # "Google Maps API key not found"
   # "API key not valid"
   ```

2. **تحقق من API Key في AndroidManifest.xml**:
   - تأكد من وجود `<meta-data>` tag
   - تأكد من صحة API Key

3. **تحقق من تفعيل APIs**:
   - Maps SDK for Android ✅
   - Geocoding API ✅

### إذا كانت الخريطة تظهر لكن لا يمكن تحديد الموقع:

1. **تحقق من Geocoding API**:
   - تأكد من تفعيله
   - تأكد من إضافته في API restrictions

2. **تحقق من الأخطاء في Logcat**:
   ```bash
   # ابحث عن:
   # "Geocoding API error"
   # "API key not valid for this API"
   ```

---

## 📱 إعداد iOS (إن كنت تستخدم iOS)

### في `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

// في didFinishLaunchingWithOptions:
GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
```

### في `ios/Runner/Info.plist`:

```xml
<key>GMSApiKey</key>
<string>YOUR_IOS_API_KEY</string>
```

---

## 🧪 اختبار الإعداد

### بعد إتمام الإعداد:

1. **أعد بناء التطبيق**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **اختبر تحديد الموقع**:
   - افتح Location Picker
   - اضغط على الخريطة
   - يجب أن يظهر العنوان

3. **تحقق من Logcat**:
   - لا يجب أن تظهر أخطاء متعلقة بـ API key
   - يجب أن تعمل Geocoding بشكل صحيح

---

## 📝 ملاحظات مهمة

1. **API Key Security**:
   - لا تشارك API Key في GitHub
   - استخدم environment variables للـ production
   - قيد API Key بـ package name و SHA-1

2. **Quotas & Limits**:
   - Geocoding API: 40,000 requests/day (free tier)
   - Maps SDK: غير محدود (لكن يتطلب billing)

3. **Debug vs Release**:
   - استخدم API keys مختلفة للـ debug و release
   - أو أضف SHA-1 fingerprints متعددة

---

## 🔗 روابط مفيدة

- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [Geocoding API Documentation](https://developers.google.com/maps/documentation/geocoding)
- [Maps SDK for Android](https://developers.google.com/maps/documentation/android-sdk)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)

---

## ✅ Checklist

- [ ] تفعيل Maps SDK for Android
- [ ] تفعيل Geocoding API
- [ ] التحقق من API Key في AndroidManifest.xml
- [ ] إضافة SHA-1 fingerprint
- [ ] تقييد API Key بـ package name
- [ ] تفعيل Billing (إن لزم الأمر)
- [ ] اختبار تحديد الموقع
- [ ] التحقق من عدم وجود أخطاء في Logcat

---

**تاريخ الإنشاء**: 2024
**آخر تحديث**: 2024

