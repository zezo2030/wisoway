# 📝 أمثلة عملية لاستخدام جنس المستخدم

## 1. عرض الجنس في Profile Screen

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_gender_display.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الملف الشخصي')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // استخدام UserInfoCard
            UserInfoCard(),
            
            // أو استخدام UserGenderDisplay فقط
            Padding(
              padding: EdgeInsets.all(16),
              child: UserGenderDisplay(
                showLabel: true,
                iconSize: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 2. استخدام الجنس في Seat Booking Logic

```dart
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class SeatBookingService {
  /// التحقق من إمكانية حجز مقعد بجانب راكب آخر
  static bool canBookSeatNextTo({
    required UserModel currentUser,
    required UserModel? leftSeatUser,
    required UserModel? rightSeatUser,
    required bool preventGenderMixing,
  }) {
    // إذا لم يكن منع الاختلاط مفعلاً، يمكن الحجز
    if (!preventGenderMixing) {
      return true;
    }
    
    // التحقق من المقعد الأيسر
    if (leftSeatUser != null) {
      if (currentUser.isMale && leftSeatUser.isFemale) {
        return false; // ذكر بجانب أنثى - ممنوع
      }
      if (currentUser.isFemale && leftSeatUser.isMale) {
        return false; // أنثى بجانب ذكر - ممنوع
      }
    }
    
    // التحقق من المقعد الأيمن
    if (rightSeatUser != null) {
      if (currentUser.isMale && rightSeatUser.isFemale) {
        return false; // ذكر بجانب أنثى - ممنوع
      }
      if (currentUser.isFemale && rightSeatUser.isMale) {
        return false; // أنثى بجانب ذكر - ممنوع
      }
    }
    
    // نفس الجنس أو لا يوجد راكب بجانب - مسموح
    return true;
  }
  
  /// الحصول على رسالة خطأ عند منع الحجز
  static String getBookingErrorMessage({
    required UserModel currentUser,
    required UserModel? adjacentUser,
  }) {
    if (adjacentUser == null) return '';
    
    if (currentUser.isMale && adjacentUser.isFemale) {
      return 'لا يمكن حجز مقعد بجانب راكب أنثى';
    }
    
    if (currentUser.isFemale && adjacentUser.isMale) {
      return 'لا يمكن حجز مقعد بجانب راكب ذكر';
    }
    
    return '';
  }
}
```

## 3. عرض الجنس في Trip Details

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_gender_display.dart';

class TripDetailsScreen extends StatelessWidget {
  final String tripId;
  
  const TripDetailsScreen({required this.tripId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل الرحلة')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final trip = snapshot.data!;
          final currentUser = Provider.of<AuthProvider>(context).userModel;
          
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // معلومات الرحلة
              Text('نقطة الانطلاق: ${trip['from']}'),
              Text('الوجهة: ${trip['to']}'),
              
              // معلومات السائق
              Card(
                child: ListTile(
                  leading: UserGenderDisplay(
                    showLabel: false,
                    iconSize: 32,
                  ),
                  title: Text('السائق: ${trip['driverName']}'),
                  subtitle: Text('الجنس: ${getGenderText(trip['driverGender'])}'),
                ),
              ),
              
              // المقاعد
              ..._buildSeatsList(trip, currentUser),
            ],
          );
        },
      ),
    );
  }
  
  List<Widget> _buildSeatsList(DocumentSnapshot trip, UserModel? currentUser) {
    final seats = trip['seats'] as Map<String, dynamic>? ?? {};
    final preventMixing = trip['preventGenderMixing'] ?? false;
    
    return seats.entries.map((entry) {
      final seatNumber = entry.key;
      final seatData = entry.value as Map<String, dynamic>?;
      final bookedBy = seatData?['userId'];
      final bookedGender = seatData?['gender'];
      
      return Card(
        child: ListTile(
          leading: bookedBy != null
            ? UserGenderDisplay(
                showLabel: false,
                iconSize: 24,
              )
            : Icon(Icons.event_seat),
          title: Text('مقعد $seatNumber'),
          subtitle: bookedBy != null
            ? Text('محجوز - ${getGenderText(bookedGender)}')
            : Text('متاح'),
          trailing: bookedBy == null && currentUser != null
            ? ElevatedButton(
                onPressed: () {
                  // التحقق من إمكانية الحجز
                  final canBook = SeatBookingService.canBookSeatNextTo(
                    currentUser: currentUser,
                    leftSeatUser: _getSeatUser(seats, seatNumber - 1),
                    rightSeatUser: _getSeatUser(seats, seatNumber + 1),
                    preventGenderMixing: preventMixing,
                  );
                  
                  if (canBook) {
                    // حجز المقعد
                    _bookSeat(trip.id, seatNumber, currentUser);
                  } else {
                    // عرض رسالة خطأ
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          SeatBookingService.getBookingErrorMessage(
                            currentUser: currentUser,
                            adjacentUser: _getSeatUser(seats, seatNumber - 1) ??
                                _getSeatUser(seats, seatNumber + 1),
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Text('حجز'),
              )
            : null,
        ),
      );
    }).toList();
  }
}
```

## 4. فلترة المستخدمين حسب الجنس

```dart
import '../models/user_model.dart';

class UserFilterService {
  /// فلترة قائمة المستخدمين حسب الجنس
  static List<UserModel> filterByGender({
    required List<UserModel> users,
    String? gender,
  }) {
    if (gender == null) {
      return users; // لا فلترة
    }
    
    return users.where((user) => user.gender == gender).toList();
  }
  
  /// الحصول على عدد المستخدمين حسب الجنس
  static Map<String, int> getGenderCounts(List<UserModel> users) {
    return {
      AppConstants.genderMale: users.where((u) => u.isMale).length,
      AppConstants.genderFemale: users.where((u) => u.isFemale).length,
    };
  }
}
```

## 5. استخدام الجنس في Chat (منع مشاركة الأرقام)

```dart
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class ChatService {
  /// التحقق من إمكانية إظهار رقم الهاتف
  static bool canShowPhoneNumber({
    required UserModel currentUser,
    required UserModel otherUser,
    required bool hidePhoneForFemales,
  }) {
    // إذا كان المستخدم الآخر أنثى وتم تفعيل إخفاء الأرقام
    if (hidePhoneForFemales && otherUser.isFemale) {
      return false; // لا تظهر الرقم
    }
    
    // إذا كان المستخدم الحالي أنثى وتم تفعيل إخفاء الأرقام
    if (hidePhoneForFemales && currentUser.isFemale) {
      return false; // لا تظهر الرقم
    }
    
    return true; // يمكن إظهار الرقم
  }
  
  /// الحصول على نص بديل عند إخفاء الرقم
  static String getHiddenPhoneText() {
    return 'الرقم مخفي - استخدم الدردشة للتواصل';
  }
}
```

## 6. استخدام الجنس في Statistics

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class StatisticsService {
  /// الحصول على إحصائيات الجنس
  static Future<Map<String, int>> getGenderStatistics() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    
    int maleCount = 0;
    int femaleCount = 0;
    
    for (var doc in usersSnapshot.docs) {
      final gender = doc.data()['gender'] as String?;
      if (gender == AppConstants.genderMale) {
        maleCount++;
      } else if (gender == AppConstants.genderFemale) {
        femaleCount++;
      }
    }
    
    return {
      AppConstants.genderMale: maleCount,
      AppConstants.genderFemale: femaleCount,
    };
  }
  
  /// عرض إحصائيات الجنس في Chart
  static Widget buildGenderChart(Map<String, int> stats) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('توزيع المستخدمين حسب الجنس'),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.male, color: Colors.blue, size: 48),
                      Text('${stats[AppConstants.genderMale] ?? 0}'),
                      Text('ذكر'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.female, color: Colors.pink, size: 48),
                      Text('${stats[AppConstants.genderFemale] ?? 0}'),
                      Text('أنثى'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## ملخص

1. **قراءة الجنس**: من `AuthProvider.userModel.gender` أو `UserModel.gender`
2. **التحقق من الجنس**: استخدام `user.isMale` أو `user.isFemale`
3. **عرض الجنس**: استخدام `UserGenderDisplay` widget
4. **استخدام الجنس**: في منطق منع الاختلاط، الفلترة، الإحصائيات، إلخ

---

## روابط مفيدة

- [USER_GENDER_GUIDE.md](./USER_GENDER_GUIDE.md) - دليل شامل
- [user_gender_display.dart](../lib/widgets/user_gender_display.dart) - Widgets جاهزة
- [UserModel](../lib/models/user_model.dart) - نموذج البيانات

