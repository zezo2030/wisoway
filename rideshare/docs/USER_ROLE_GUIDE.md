# 👤 دليل نوع المستخدم (User Role) - حفظ في Firestore

## نظرة عامة

عند إنشاء حساب جديد، يجب على المستخدم اختيار **نوع المستخدم** (الدور) والذي يتم حفظه في Firestore مع بيانات المستخدم الأخرى.

---

## أنواع المستخدمين المتاحة

### 1. راكب (Passenger)
- **القيمة:** `'passenger'` (`AppConstants.rolePassenger`)
- **الوصف:** يمكن للمستخدم حجز الرحلات فقط
- **الاستخدام:** للمستخدمين العاديين الذين يريدون حجز رحلات

### 2. صاحب رحلات (Driver)
- **القيمة:** `'driver'` (`AppConstants.roleDriver`)
- **الوصف:** يمكن للمستخدم إنشاء رحلات وحجز رحلات أخرى
- **الاستخدام:** للسائقين الذين يريدون نشر رحلاتهم

### 3. مدير (Admin)
- **القيمة:** `'admin'` (`AppConstants.roleAdmin`)
- **الوصف:** صلاحيات إدارية كاملة
- **الاستخدام:** للمدراء فقط (يتم تعيينه يدوياً)

---

## كيفية حفظ نوع المستخدم

### 1. في ProfileSetupScreen

عند إنشاء الحساب، المستخدم يختار نوعه من:
- **راكب** (`AppConstants.rolePassenger`)
- **صاحب رحلات** (`AppConstants.roleDriver`)

```dart
// lib/screens/auth/profile_setup_screen.dart
await authProvider.saveUserProfile(
  name: _nameController.text.trim(),
  email: _emailController.text.trim(),
  gender: _selectedGender!,
  role: _selectedRole!, // 'passenger' or 'driver'
  phoneNumber: phoneNumber,
);
```

### 2. في Firestore

نوع المستخدم يتم حفظه في document المستخدم:

```javascript
// Firestore: users/{userId}
{
  "role": "passenger", // or "driver" or "admin"
  "name": "أحمد محمد",
  "gender": "male",
  "email": "ahmed@example.com",
  // ... other fields
}
```

### 3. القيمة الافتراضية

عند إنشاء حساب جديد (Email/Password أو Social Login)، يتم تعيين `role` تلقائياً كـ `'passenger'`:

```dart
// lib/core/services/auth_service.dart
'role': AppConstants.rolePassenger, // Default role
```

**ملاحظة:** هذه القيمة الافتراضية يتم تحديثها في `ProfileSetupScreen` عندما يختار المستخدم نوعه.

---

## Constants المستخدمة

```dart
// lib/core/constants/app_constants.dart
class AppConstants {
  // User Roles
  static const String rolePassenger = 'passenger';
  static const String roleDriver = 'driver';
  static const String roleAdmin = 'admin';
}
```

---

## UserModel Getters

```dart
// lib/models/user_model.dart
class UserModel {
  final String role; // 'passenger', 'driver', or 'admin'
  
  // Getters مفيدة
  bool get isDriver => role == AppConstants.roleDriver;
  bool get isPassenger => role == AppConstants.rolePassenger;
  bool get isAdmin => role == AppConstants.roleAdmin;
  
  // Check if user can book trips (passenger or driver)
  bool get canBookTrips => isPassenger || isDriver;
  
  // Check if user can create trips (driver only)
  bool get canCreateTrips => isDriver;
}
```

---

## كيفية قراءة نوع المستخدم

### 1. من AuthProvider (الطريقة الموصى بها)

```dart
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants/app_constants.dart';

// في أي widget
final authProvider = Provider.of<AuthProvider>(context);
final userModel = authProvider.userModel;

if (userModel != null) {
  // قراءة نوع المستخدم
  final role = userModel.role; // 'passenger', 'driver', or 'admin'
  
  // أو استخدام الـ getters
  final isPassenger = userModel.isPassenger; // true or false
  final isDriver = userModel.isDriver; // true or false
  final isAdmin = userModel.isAdmin; // true or false
  
  // عرض نوع المستخدم
  final roleText = userModel.isDriver 
    ? 'صاحب رحلات' 
    : userModel.isPassenger 
      ? 'راكب' 
      : 'مدير';
  print('نوع المستخدم: $roleText');
}
```

### 2. من UserModel مباشرة

```dart
// إذا كان لديك UserModel
final user = UserModel(...);

// قراءة نوع المستخدم
final role = user.role; // 'passenger', 'driver', or 'admin'

// استخدام الـ getters
if (user.isPassenger) {
  print('المستخدم راكب');
} else if (user.isDriver) {
  print('المستخدم سائق');
} else if (user.isAdmin) {
  print('المستخدم مدير');
}
```

### 3. من Firestore مباشرة

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

// قراءة نوع مستخدم معين
Future<String?> getUserRole(String userId) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  
  if (doc.exists) {
    final data = doc.data();
    return data?['role'] ?? AppConstants.rolePassenger;
  }
  return null;
}
```

---

## أمثلة الاستخدام

### 1. عرض نوع المستخدم في Profile Screen

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
            Text('نوع المستخدم: ${_getRoleText(user.role)}'),
            // أو
            Text('نوع المستخدم: ${user.isDriver ? 'صاحب رحلات' : 'راكب'}'),
          ],
        );
      },
    );
  }
  
  String _getRoleText(String role) {
    switch (role) {
      case AppConstants.rolePassenger:
        return 'راكب';
      case AppConstants.roleDriver:
        return 'صاحب رحلات';
      case AppConstants.roleAdmin:
        return 'مدير';
      default:
        return 'غير محدد';
    }
  }
}
```

### 2. إظهار/إخفاء الأزرار حسب نوع المستخدم

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.userModel;
        
        return Scaffold(
          appBar: AppBar(title: Text('الرئيسية')),
          body: Column(
            children: [
              // زر حجز رحلة - يظهر للركاب والسائقين
              if (user?.canBookTrips == true)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/book-trip');
                  },
                  child: Text('حجز رحلة'),
                ),
              
              // زر إنشاء رحلة - يظهر للسائقين فقط
              if (user?.canCreateTrips == true)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/create-trip');
                  },
                  child: Text('إنشاء رحلة'),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

### 3. فلترة الرحلات حسب نوع المستخدم

```dart
class TripsListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.userModel;
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('trips')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircularProgressIndicator();
            }
            
            final trips = snapshot.data!.docs.map((doc) {
              return TripModel.fromFirestore(doc);
            }).toList();
            
            // إذا كان المستخدم سائق، اعرض رحلاته أولاً
            if (user?.isDriver == true) {
              final myTrips = trips.where((t) => t.driverId == user!.id).toList();
              final otherTrips = trips.where((t) => t.driverId != user!.id).toList();
              
              return ListView(
                children: [
                  ...myTrips.map((t) => TripCard(trip: t, isOwner: true)),
                  ...otherTrips.map((t) => TripCard(trip: t, isOwner: false)),
                ],
              );
            }
            
            // إذا كان راكب، اعرض جميع الرحلات
            return ListView(
              children: trips.map((t) => TripCard(trip: t)).toList(),
            );
          },
        );
      },
    );
  }
}
```

---

## التحقق من وجود نوع المستخدم

```dart
// التحقق من أن المستخدم لديه نوع محدد
bool hasRole(UserModel? user) {
  if (user == null) return false;
  
  return user.role == AppConstants.rolePassenger || 
         user.role == AppConstants.roleDriver ||
         user.role == AppConstants.roleAdmin;
}

// أو استخدام الـ getters
bool hasRole(UserModel? user) {
  return user?.isPassenger == true || 
         user?.isDriver == true || 
         user?.isAdmin == true;
}
```

---

## ملاحظات مهمة

1. **نوع المستخدم إلزامي**: عند إنشاء الحساب، يجب اختيار نوع المستخدم (لا يمكن تركه فارغاً)
2. **القيم الصحيحة**: فقط `'passenger'`, `'driver'`, أو `'admin'` (من `AppConstants`)
3. **القيمة الافتراضية**: إذا لم يكن نوع المستخدم موجوداً، يتم استخدام `AppConstants.rolePassenger` كقيمة افتراضية
4. **التحديث**: يمكن تحديث نوع المستخدم من `ProfileSetupScreen` أو من إعدادات المستخدم
5. **الصلاحيات**: نوع المستخدم يحدد الصلاحيات (مثل إنشاء رحلات، حجز رحلات، إلخ)

---

## هيكل البيانات في Firestore

```javascript
// users/{userId}
{
  "id": "user123",
  "name": "أحمد محمد",
  "email": "ahmed@example.com",
  "phoneNumber": "+201234567890",
  "gender": "male",
  "role": "passenger", // ← نوع المستخدم
  "isPhoneVerified": true,
  "isEmailVerified": true,
  "rating": 4.5,
  "totalRatings": 10,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "lastLoginAt": "2024-01-01T00:00:00Z"
}
```

---

## روابط مفيدة

- [UserModel](../lib/models/user_model.dart) - نموذج بيانات المستخدم
- [ProfileSetupScreen](../lib/screens/auth/profile_setup_screen.dart) - شاشة إعداد الملف الشخصي
- [AppConstants](../lib/core/constants/app_constants.dart) - الثوابت
- [USER_GENDER_GUIDE.md](./USER_GENDER_GUIDE.md) - دليل الجنس

