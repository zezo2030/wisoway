# 👤 دليل استخدام جنس المستخدم (Gender)

## نظرة عامة

عند إنشاء حساب راكب، يتم حفظ جنس المستخدم (ذكر/أنثى) في Firestore. هذا الحقل مهم جداً لضمان منع الاختلاط في المقاعد.

---

## كيفية حفظ الجنس

### 1. في ProfileSetupScreen

عند إنشاء الحساب، المستخدم يختار جنسه من:
- **ذكر** (`AppConstants.genderMale` = `'male'`)
- **أنثى** (`AppConstants.genderFemale` = `'female'`)

```dart
// lib/screens/auth/profile_setup_screen.dart
await authProvider.saveUserProfile(
  name: _nameController.text.trim(),
  email: _emailController.text.trim(),
  gender: _selectedGender!, // 'male' or 'female'
  role: _selectedRole!,
  phoneNumber: phoneNumber,
);
```

### 2. في Firestore

الجنس يتم حفظه في document المستخدم:

```javascript
// Firestore: users/{userId}
{
  "gender": "male", // or "female"
  "name": "أحمد محمد",
  "role": "passenger",
  // ... other fields
}
```

---

## كيفية قراءة الجنس

### 1. من AuthProvider (الطريقة الموصى بها)

```dart
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants/app_constants.dart';

// في أي widget
final authProvider = Provider.of<AuthProvider>(context);
final userModel = authProvider.userModel;

if (userModel != null) {
  // قراءة الجنس
  final gender = userModel.gender; // 'male' or 'female'
  
  // أو استخدام الـ getters
  final isMale = userModel.isMale; // true or false
  final isFemale = userModel.isFemale; // true or false
  
  // عرض الجنس
  final genderText = userModel.isMale ? 'ذكر' : 'أنثى';
  print('الجنس: $genderText');
}
```

### 2. من UserModel مباشرة

```dart
// إذا كان لديك UserModel
final user = UserModel(...);

// قراءة الجنس
final gender = user.gender; // 'male' or 'female'

// استخدام الـ getters
if (user.isMale) {
  print('المستخدم ذكر');
} else if (user.isFemale) {
  print('المستخدم أنثى');
}
```

### 3. من Firestore مباشرة

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

// قراءة جنس مستخدم معين
Future<String?> getUserGender(String userId) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  
  if (doc.exists) {
    final data = doc.data();
    return data?['gender'] ?? AppConstants.genderMale;
  }
  return null;
}
```

---

## أمثلة الاستخدام

### 1. عرض الجنس في Profile Screen

```dart
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.userModel;
        
        if (user == null) {
          return Center(child: Text('لا يوجد مستخدم'));
        }
        
        return Column(
          children: [
            Text('الاسم: ${user.name}'),
            Text('الجنس: ${user.isMale ? 'ذكر' : 'أنثى'}'),
            // أو
            Text('الجنس: ${user.gender == AppConstants.genderMale ? 'ذكر' : 'أنثى'}'),
          ],
        );
      },
    );
  }
}
```

### 2. استخدام الجنس في منع الاختلاط (Seat Booking)

```dart
// مثال: التحقق من إمكانية حجز مقعد بجانب راكب آخر
bool canBookSeatNextTo(UserModel currentUser, UserModel? adjacentUser) {
  // إذا لم يكن هناك راكب بجانب، يمكن الحجز
  if (adjacentUser == null) {
    return true;
  }
  
  // منع الاختلاط: ذكر بجانب أنثى والعكس
  if (currentUser.isMale && adjacentUser.isFemale) {
    return false; // لا يمكن الحجز
  }
  
  if (currentUser.isFemale && adjacentUser.isMale) {
    return false; // لا يمكن الحجز
  }
  
  // نفس الجنس: يمكن الحجز
  return true;
}
```

### 3. فلترة الرحلات حسب الجنس

```dart
// مثال: عرض رحلات مناسبة للجنس
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('trips')
      .where('preventGenderMixing', isEqualTo: true)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return CircularProgressIndicator();
    }
    
    final currentUser = Provider.of<AuthProvider>(context).userModel;
    if (currentUser == null) {
      return Text('يجب تسجيل الدخول');
    }
    
    final trips = snapshot.data!.docs.map((doc) {
      // يمكنك إضافة منطق لفلترة الرحلات حسب الجنس
      return TripModel.fromFirestore(doc);
    }).toList();
    
    return ListView.builder(
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        // عرض الرحلة مع مراعاة الجنس
        return TripCard(trip: trip, userGender: currentUser.gender);
      },
    );
  },
)
```

### 4. عرض أيقونة الجنس

```dart
Widget buildGenderIcon(String gender) {
  if (gender == AppConstants.genderMale) {
    return Icon(Icons.male, color: Colors.blue);
  } else {
    return Icon(Icons.female, color: Colors.pink);
  }
}

// أو استخدام emoji
Widget buildGenderEmoji(String gender) {
  if (gender == AppConstants.genderMale) {
    return Text('👨', style: TextStyle(fontSize: 24));
  } else {
    return Text('👩', style: TextStyle(fontSize: 24));
  }
}
```

---

## Constants المستخدمة

```dart
// lib/core/constants/app_constants.dart
class AppConstants {
  // User Genders
  static const String genderMale = 'male';
  static const String genderFemale = 'female';
}
```

---

## UserModel Getters

```dart
// lib/models/user_model.dart
class UserModel {
  final String gender; // 'male' or 'female'
  
  // Getters مفيدة
  bool get isMale => gender == AppConstants.genderMale;
  bool get isFemale => gender == AppConstants.genderFemale;
}
```

---

## التحقق من وجود الجنس

```dart
// التحقق من أن المستخدم لديه جنس محدد
bool hasGender(UserModel? user) {
  if (user == null) return false;
  
  return user.gender == AppConstants.genderMale || 
         user.gender == AppConstants.genderFemale;
}

// أو استخدام الـ getters
bool hasGender(UserModel? user) {
  return user?.isMale == true || user?.isFemale == true;
}
```

---

## ملاحظات مهمة

1. **الجنس إلزامي**: عند إنشاء الحساب، يجب اختيار الجنس (لا يمكن تركه فارغاً)
2. **القيم الصحيحة**: فقط `'male'` أو `'female'` (من `AppConstants`)
3. **القيمة الافتراضية**: إذا لم يكن الجنس موجوداً، يتم استخدام `AppConstants.genderMale` كقيمة افتراضية
4. **الخصوصية**: الجنس يمكن استخدامه فقط لمنع الاختلاط، وليس للتمييز

---

## مثال كامل: عرض معلومات المستخدم

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants/app_constants.dart';

class UserInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.userModel;
        
        if (user == null) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا يوجد مستخدم مسجل دخول'),
            ),
          );
        }
        
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // أيقونة الجنس
                    user.isMale 
                      ? Icon(Icons.male, color: Colors.blue, size: 32)
                      : Icon(Icons.female, color: Colors.pink, size: 32),
                    SizedBox(width: 12),
                    // معلومات المستخدم
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'الجنس: ${user.isMale ? 'ذكر' : 'أنثى'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'الدور: ${user.role == AppConstants.rolePassenger ? 'راكب' : 'سائق'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

## روابط مفيدة

- [UserModel](./lib/models/user_model.dart) - نموذج بيانات المستخدم
- [ProfileSetupScreen](./lib/screens/auth/profile_setup_screen.dart) - شاشة إعداد الملف الشخصي
- [AppConstants](./lib/core/constants/app_constants.dart) - الثوابت

