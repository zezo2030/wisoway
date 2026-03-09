# 📦 Dependencies - قائمة الحزم المطلوبة

## pubspec.yaml - Complete Dependencies

```yaml
name: rideshare
description: "Rideshare App - منصة مشاركة الرحلات"
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: ^3.9.2

dependencies:
  flutter:
    sdk: flutter
  
  # Localization
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
  
  # Firebase Core
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.3
  firebase_storage: ^12.3.2
  firebase_messaging: ^15.1.3
  firebase_analytics: ^11.3.3
  cloud_functions: ^5.1.3
  
  # State Management
  provider: ^6.1.2
  
  # UI Components
  cupertino_icons: ^1.0.8
  google_fonts: ^6.2.1
  cached_network_image: ^3.4.1
  
  # Image Handling
  image_picker: ^1.1.2
  image_compression_flutter: ^0.1.0
  
  # Maps & Location
  google_maps_flutter: ^2.9.0
  geolocator: ^13.0.1
  geocoding: ^3.0.0
  
  # Payment
  flutter_stripe: ^11.1.0
  http: ^1.2.2  # For Paymob integration
  
  # QR Code
  qr_flutter: ^4.1.0
  qr_code_scanner: ^1.0.1
  
  # Utilities
  shared_preferences: ^2.3.2
  uuid: ^4.5.1
  timeago: ^3.7.0
  url_launcher: ^6.3.1
  path_provider: ^2.1.2
  
  # Animations (Optional)
  lottie: ^3.1.2
  
  # Form Validation
  email_validator: ^2.1.17

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.9

flutter:
  uses-material-design: true
  
  # Assets
  assets:
    - assets/images/
    - assets/icons/
    - assets/animations/
  
  # Fonts (Optional - if using custom fonts)
  # fonts:
  #   - family: CustomFont
  #     fonts:
  #       - asset: assets/fonts/CustomFont-Regular.ttf
```

---

## Package Details

### Firebase Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^3.6.0 | Firebase initialization |
| `firebase_auth` | ^5.3.1 | Phone authentication |
| `cloud_firestore` | ^5.4.3 | Database |
| `firebase_storage` | ^12.3.2 | Image storage |
| `firebase_messaging` | ^15.1.3 | Push notifications |
| `firebase_analytics` | ^11.3.3 | Analytics (optional) |
| `cloud_functions` | ^5.1.3 | Call cloud functions |

### State Management

| Package | Version | Purpose |
|---------|---------|---------|
| `provider` | ^6.1.2 | State management |

### UI & Design

| Package | Version | Purpose |
|---------|---------|---------|
| `google_fonts` | ^6.2.1 | Custom fonts |
| `cached_network_image` | ^3.4.1 | Image caching |
| `lottie` | ^3.1.2 | Animations |

### Maps & Location

| Package | Version | Purpose |
|---------|---------|---------|
| `google_maps_flutter` | ^2.9.0 | Google Maps |
| `geolocator` | ^13.0.1 | Location services |
| `geocoding` | ^3.0.0 | Address ↔ Coordinates |

### Payment

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_stripe` | ^11.1.0 | Stripe integration |
| `http` | ^1.2.2 | HTTP requests (Paymob) |

### Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| `shared_preferences` | ^2.3.2 | Local storage |
| `uuid` | ^4.5.1 | Unique IDs |
| `timeago` | ^3.7.0 | Relative time |
| `url_launcher` | ^6.3.1 | Open URLs |
| `path_provider` | ^2.1.2 | File paths |

### Image Processing

| Package | Version | Purpose |
|---------|---------|---------|
| `image_picker` | ^1.1.2 | Select images |
| `image_compression_flutter` | ^0.1.0 | Compress images |

### QR Code

| Package | Version | Purpose |
|---------|---------|---------|
| `qr_flutter` | ^4.1.0 | Generate QR codes |
| `qr_code_scanner` | ^1.0.1 | Scan QR codes |

---

## Installation Steps

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Setup Firebase

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

### 3. Platform-specific Setup

#### Android

**android/app/build.gradle:**
```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

**android/app/src/main/AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

#### iOS

**ios/Podfile:**
```ruby
platform :ios, '12.0'
```

**ios/Runner/Info.plist:**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج موقعك لعرض الرحلات القريبة</string>
```

---

## Version Compatibility

### Flutter Version
- **Minimum:** 3.9.0
- **Recommended:** 3.9.2+

### Dart Version
- **Minimum:** 3.9.0
- **Recommended:** 3.9.2+

---

## Troubleshooting

### Common Issues

1. **Firebase not initialized**
   ```dart
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

2. **Google Maps not showing**
   - Check API key in `AndroidManifest.xml` and `Info.plist`
   - Enable Maps SDK in Google Cloud Console

3. **Image picker not working**
   - Add permissions in `AndroidManifest.xml` and `Info.plist`
   - Request runtime permissions

---

## Updating Dependencies

```bash
# Check for updates
flutter pub outdated

# Update all dependencies
flutter pub upgrade

# Update specific package
flutter pub upgrade package_name
```

---

## Alternative Packages (Optional)

### State Management
- **Riverpod** instead of Provider
- **Bloc** for complex state management

### Maps
- **Mapbox** instead of Google Maps

### Payment
- **Paymob SDK** (if available)
- **PayPal** (if needed)

---

**آخر تحديث:** 2024







