# 🔗 دليل التكامل: Cloud Functions مع Flutter

## 📋 نظرة عامة

هذا الدليل يشرح كيفية استخدام Cloud Functions في تطبيق Flutter.

---

## ✅ الخطوة 1: التأكد من وجود Dependencies

في `pubspec.yaml` يجب أن يكون موجود:

```yaml
dependencies:
  cloud_functions: ^5.1.3
```

إذا لم يكن موجوداً، أضفه ثم شغّل:
```bash
flutter pub get
```

---

## ✅ الخطوة 2: Service جاهز للاستخدام

تم إنشاء `CloudFunctionsService` في:
- `lib/core/services/cloud_functions_service.dart`

**لا تحتاج أي إعداد إضافي!** ✅

---

## 🎯 الاستخدام العملي

### المثال 1: إرسال إشعار تجريبي

```dart
import 'package:rideshare/core/services/cloud_functions_service.dart';

class TestNotificationScreen extends StatefulWidget {
  @override
  _TestNotificationScreenState createState() => _TestNotificationScreenState();
}

class _TestNotificationScreenState extends State<TestNotificationScreen> {
  final _functionsService = CloudFunctionsService();
  bool _isLoading = false;

  Future<void> _sendTestNotification() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      await _functionsService.sendTestNotification(
        userId: user.uid,
        title: 'إشعار تجريبي',
        body: 'هذا إشعار تجريبي من التطبيق',
        data: {
          'type': 'test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم إرسال الإشعار بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('اختبار الإشعارات')),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _sendTestNotification,
                child: Text('إرسال إشعار تجريبي'),
              ),
      ),
    );
  }
}
```

---

## 🔄 Functions التلقائية (لا تحتاج استدعاء)

### كيف تعمل؟

هذه Functions تعمل **تلقائياً** عند تغيير البيانات في Firestore:

```dart
// في Flutter - عند إنشاء حجز
await FirebaseFirestore.instance
  .collection('bookings')
  .add({
    'tripId': tripId,
    'userId': userId,
    'driverId': driverId,
    'userName': userName,
    'seatNumber': seatNumber,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  });

// ☁️ Cloud Function onBookingCreated تعمل تلقائياً!
// ✅ ترسل إشعار للسائق تلقائياً
// ✅ لا تحتاج أي كود إضافي!
```

### قائمة Functions التلقائية:

| Function | متى تعمل | ماذا تفعل |
|----------|----------|-----------|
| `onBookingCreated` | عند إنشاء حجز | إشعار للسائق |
| `onBookingConfirmed` | عند تأكيد الحجز | إشعار للراكب |
| `onBookingCancelled` | عند إلغاء الحجز | إشعار للطرفين |
| `onPaymentApproved` | عند موافقة الدفع | تفعيل التواصل |
| `onPaymentRejected` | عند رفض الدفع | إشعار للمستخدم |
| `sendTripReminders` | كل ساعة | تذكيرات الرحلات |

**لا تحتاج أي كود في Flutter!** ✅

---

## 📞 Functions اليدوية (تحتاج استدعاء)

### متى نستخدمها؟

- إرسال إشعار تجريبي
- معالجة دفع يدوية
- الحصول على إحصائيات
- أي عملية تحتاج استدعاء يدوي

### مثال:

```dart
final _functionsService = CloudFunctionsService();

// إرسال إشعار تجريبي
await _functionsService.sendTestNotification(
  userId: 'user123',
  title: 'عنوان الإشعار',
  body: 'نص الإشعار',
);
```

---

## ⚙️ الإعدادات

### 1. استخدام Emulator (للاختبار)

```dart
// في main.dart (للاختبار فقط)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // استخدام Emulator
  final functionsService = CloudFunctionsService();
  functionsService.useEmulator(host: 'localhost', port: 5001);
  
  runApp(MyApp());
}
```

### 2. معالجة الأخطاء

```dart
try {
  await _functionsService.sendTestNotification(...);
} catch (e) {
  if (e.toString().contains('unauthenticated')) {
    // المستخدم غير مسجل دخول
  } else if (e.toString().contains('invalid-argument')) {
    // بيانات غير صحيحة
  } else {
    // خطأ آخر
  }
}
```

---

## 📝 ملاحظات مهمة

### 1. المصادقة
- معظم Functions تتحقق من المصادقة تلقائياً
- تأكد من تسجيل دخول المستخدم قبل الاستدعاء

### 2. الأخطاء
- جميع الأخطاء يتم معالجتها في `CloudFunctionsService`
- رسائل الخطأ بالعربية

### 3. الأداء
- Functions التلقائية تعمل في الخلفية
- لا تؤثر على أداء التطبيق

---

## ✅ الخلاصة

### Functions التلقائية:
- ✅ **لا تحتاج أي كود في Flutter**
- ✅ تعمل تلقائياً عند تغيير Firestore
- ✅ مثل: `onBookingCreated`, `onPaymentApproved`

### Functions اليدوية:
- ✅ **تحتاج استدعاء من Flutter**
- ✅ استخدم `CloudFunctionsService`
- ✅ مثل: `sendTestNotification`

---

## 🚀 الخطوة التالية

1. ✅ Service جاهز (`CloudFunctionsService`)
2. ✅ Function جاهزة (`sendTestNotification`)
3. ⏳ نشر Functions: `firebase deploy --only functions`
4. ⏳ اختبار في التطبيق

**معظم Functions تعمل تلقائياً - لا تحتاج أي كود إضافي!** 🎉








