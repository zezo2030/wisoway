# 📅 الأسبوع الأول: Setup & Authentication

## 🎯 الأهداف

1. إعداد Firebase بالكامل
2. إعداد Flutter Project Structure
3. Phone Authentication + SMS Verification
4. Profile Setup Screen
5. Localization (AR/EN with RTL)
6. Theme & UI Components

---

## ✅ Checklist

### Day 1-2: Firebase Setup

- [ ] إنشاء Firebase Project
- [ ] تفعيل Phone Authentication
- [ ] تفعيل Cloud Firestore
- [ ] تفعيل Cloud Storage
- [ ] تفعيل Cloud Functions
- [ ] تفعيل Cloud Messaging (FCM)
- [ ] إعداد FlutterFire CLI
- [ ] ربط Flutter مع Firebase

**Commands:**
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure

# Select platforms: Android, iOS
```

---

### Day 3: Project Structure

- [ ] إنشاء هيكل المشروع
- [ ] إعداد Core folders
- [ ] إعداد Models
- [ ] إعداد Services
- [ ] إعداد Providers
- [ ] إعداد Screens structure

**Create folders:**
```
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   ├── services/
│   └── widgets/
├── models/
├── screens/
├── widgets/
└── providers/
```

---

### Day 4: Dependencies

- [ ] تحديث `pubspec.yaml` بجميع الحزم المطلوبة
- [ ] تشغيل `flutter pub get`
- [ ] التحقق من عدم وجود أخطاء

**See:** [DEPENDENCIES.md](./DEPENDENCIES.md)

---

### Day 5: Phone Authentication

- [ ] إنشاء `AuthService`
- [ ] Phone Auth Screen
- [ ] OTP Verification Screen
- [ ] إرسال OTP
- [ ] التحقق من OTP
- [ ] حفظ رقم الهاتف في Firestore

**Files to create:**
- `lib/core/services/auth_service.dart`
- `lib/screens/auth/phone_auth_screen.dart`
- `lib/screens/auth/otp_verification_screen.dart`

---

### Day 6: Profile Setup

- [ ] Profile Setup Screen
- [ ] اختيار الاسم
- [ ] اختيار الجنس (ذكر/أنثى)
- [ ] اختيار الدور (راكب/سائق)
- [ ] حفظ البيانات في Firestore

**Files to create:**
- `lib/screens/auth/profile_setup_screen.dart`
- `lib/models/user_model.dart`

---

### Day 7: Localization & Theme

- [ ] إعداد Localization (AR/EN)
- [ ] إعداد RTL Support
- [ ] إنشاء Theme
- [ ] إنشاء Colors
- [ ] إنشاء Text Styles
- [ ] تطبيق Theme على التطبيق

**Files to create:**
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/colors.dart`
- `lib/core/theme/text_styles.dart`
- `lib/core/services/localization_service.dart`
- `lib/l10n/` (Localization files)

---

## 📝 Code Examples

### 1. Auth Service

**lib/core/services/auth_service.dart:**
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send OTP
  Future<void> sendOTP(String phoneNumber) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        throw e;
      },
      codeSent: (String verificationId, int? resendToken) {
        // Save verificationId for later use
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // Verify OTP
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthCredential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // Save user profile
  Future<void> saveUserProfile({
    required String userId,
    required String name,
    required String gender,
    required String role,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'phoneNumber': _auth.currentUser?.phoneNumber,
      'name': name,
      'gender': gender,
      'role': role,
      'isPhoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
      'rating': 0,
      'totalRatings': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
```

---

### 2. Phone Auth Screen

**lib/screens/auth/phone_auth_screen.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.sendOTP(_phoneController.text);
      
      Navigator.pushNamed(context, '/otp-verification', arguments: {
        'phoneNumber': _phoneController.text,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تسجيل الدخول')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  hintText: '+201234567890',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال رقم الهاتف';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOTP,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('إرسال رمز التحقق'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### 3. Theme Setup

**lib/core/theme/app_theme.dart:**
```dart
import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
```

---

## 🧪 Testing

### Test Phone Auth
1. أدخل رقم هاتف صحيح
2. تحقق من استلام OTP
3. أدخل OTP وتحقق من تسجيل الدخول

### Test Profile Setup
1. بعد تسجيل الدخول، تحقق من ظهور Profile Setup
2. املأ البيانات وحفظها
3. تحقق من حفظ البيانات في Firestore

---

## 📚 Resources

- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Flutter Localization](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [Material Design 3](https://m3.material.io/)

---

## 🐛 Common Issues

### Issue: OTP not received
**Solution:** 
- تحقق من رقم الهاتف
- تأكد من تفعيل Phone Auth في Firebase Console
- تحقق من إعدادات Firebase

### Issue: RTL not working
**Solution:**
- تأكد من إضافة `flutter_localizations`
- استخدم `Directionality` widget
- تحقق من `MaterialApp` locale

---

## ✅ Week 1 Completion Criteria

- [x] Firebase configured
- [x] Phone authentication working
- [x] OTP verification working
- [x] Profile setup complete
- [x] Localization (AR/EN) working
- [x] RTL support enabled
- [x] Theme applied

---

**Next:** [WEEK_02.md](./WEEK_02.md) - Trip Management (Driver)







