# 📱 كيفية استخدام Cloud Functions في Flutter

## 🎯 نظرة عامة

هناك نوعان من Cloud Functions:

1. **Firestore Triggers** (تلقائية) - تعمل تلقائياً عند تغيير البيانات
2. **HTTP Functions** (يدوية) - يمكن استدعاؤها من Flutter

---

## ✅ النوع الأول: Firestore Triggers (تلقائية)

### كيف تعمل؟

هذه الـ Functions **تعمل تلقائياً** عند تغيير البيانات في Firestore. **لا تحتاج أي كود في Flutter!**

### مثال:

```dart
// في Flutter - عند إنشاء حجز
await FirebaseFirestore.instance
  .collection('bookings')
  .add({
    'tripId': tripId,
    'userId': userId,
    // ... بيانات الحجز
  });

// ☁️ Cloud Function تعمل تلقائياً في الخلفية!
// ✅ onBookingCreated ترسل إشعار للسائق تلقائياً
```

**لا تحتاج أي كود إضافي!** فقط احفظ البيانات في Firestore والـ Function ستعمل تلقائياً.

---

## 📞 النوع الثاني: HTTP Functions (يدوية)

### متى نحتاجها؟

عندما نريد استدعاء Function يدوياً من Flutter (مثل إرسال إشعار تجريبي).

### الخطوة 1: إنشاء Service

```dart
// lib/core/services/cloud_functions_service.dart
import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// استدعاء Function لإرسال إشعار تجريبي
  Future<void> sendTestNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendTestNotification');
      
      final result = await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });

      print('✅ Test notification sent: ${result.data}');
      return result.data;
    } catch (e) {
      print('❌ Error calling function: $e');
      rethrow;
    }
  }

  /// استدعاء Function أخرى (مثال)
  Future<Map<String, dynamic>> processPayment({
    required String paymentId,
    required String amount,
  }) async {
    try {
      final callable = _functions.httpsCallable('processPayment');
      
      final result = await callable.call({
        'paymentId': paymentId,
        'amount': amount,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('❌ Error processing payment: $e');
      rethrow;
    }
  }
}
```

### الخطوة 2: استخدام Service في التطبيق

```dart
// في أي Screen أو Widget
import 'package:rideshare/core/services/cloud_functions_service.dart';

class MyScreen extends StatefulWidget {
  @override
  _MyScreenState createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final _functionsService = CloudFunctionsService();

  Future<void> _sendTestNotification() async {
    try {
      await _functionsService.sendTestNotification(
        userId: 'user123',
        title: 'إشعار تجريبي',
        body: 'هذا إشعار تجريبي من التطبيق',
        data: {
          'type': 'test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إرسال الإشعار بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('اختبار Functions')),
      body: Center(
        child: ElevatedButton(
          onPressed: _sendTestNotification,
          child: Text('إرسال إشعار تجريبي'),
        ),
      ),
    );
  }
}
```

---

## 🔧 إعداد Cloud Functions للاستدعاء من Flutter

### في `functions/index.js`:

```javascript
// Function يمكن استدعاؤها من Flutter
exports.sendTestNotification = functions.https.onCall(async (data, context) => {
  // التحقق من المصادقة (اختياري)
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'يجب تسجيل الدخول'
    );
  }

  const { userId, title, body, data: extraData } = data;

  // التحقق من البيانات
  if (!userId || !title || !body) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'بيانات غير صحيحة'
    );
  }

  // إرسال الإشعار
  await sendNotification(userId, title, body, extraData);

  return { success: true, message: 'تم إرسال الإشعار' };
});
```

**ملاحظة:** استخدم `onCall` بدلاً من `onRequest` للاستدعاء من Flutter.

---

## 📋 قائمة Functions التلقائية (لا تحتاج استدعاء)

هذه Functions تعمل تلقائياً عند تغيير البيانات:

| Function | متى تعمل | ماذا تفعل |
|----------|----------|-----------|
| `onBookingCreated` | عند إنشاء حجز | إرسال إشعار للسائق |
| `onBookingConfirmed` | عند تأكيد الحجز | إرسال إشعار للراكب |
| `onBookingCancelled` | عند إلغاء الحجز | إرسال إشعار للطرفين |
| `onPaymentApproved` | عند موافقة الدفع | تفعيل التواصل |
| `onPaymentRejected` | عند رفض الدفع | إرسال إشعار للمستخدم |
| `sendTripReminders` | كل ساعة | إرسال تذكيرات الرحلات |

**لا تحتاج أي كود في Flutter!** فقط احفظ البيانات في Firestore.

---

## 📋 قائمة Functions اليدوية (تحتاج استدعاء)

هذه Functions يمكن استدعاؤها من Flutter:

| Function | الاستخدام | مثال |
|----------|-----------|------|
| `sendTestNotification` | إرسال إشعار تجريبي | اختبار الإشعارات |
| `processPayment` | معالجة دفع | دفع Stripe/Paymob |
| `getUserStats` | إحصائيات المستخدم | عرض الإحصائيات |

**تحتاج استدعاء من Flutter** باستخدام `CloudFunctionsService`.

---

## 🎯 مثال كامل: إضافة زر لإرسال إشعار تجريبي

### 1. إنشاء Service:

```dart
// lib/core/services/cloud_functions_service.dart
import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<Map<String, dynamic>> sendTestNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendTestNotification');
      
      final result = await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });

      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('خطأ في Function: ${e.message}');
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }
}
```

### 2. استخدام في Screen:

```dart
// في أي Screen
final _functionsService = CloudFunctionsService();

ElevatedButton(
  onPressed: () async {
    try {
      await _functionsService.sendTestNotification(
        userId: currentUserId,
        title: 'إشعار تجريبي',
        body: 'هذا إشعار تجريبي',
      );
      // عرض رسالة نجاح
    } catch (e) {
      // عرض رسالة خطأ
    }
  },
  child: Text('إرسال إشعار تجريبي'),
)
```

---

## ⚠️ ملاحظات مهمة

### 1. المصادقة (Authentication)

```dart
// Functions تتحقق من المصادقة تلقائياً
// تأكد من تسجيل دخول المستخدم قبل الاستدعاء
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // المستخدم غير مسجل دخول
  return;
}
```

### 2. معالجة الأخطاء

```dart
try {
  await _functionsService.sendTestNotification(...);
} on FirebaseFunctionsException catch (e) {
  switch (e.code) {
    case 'unauthenticated':
      // المستخدم غير مسجل دخول
      break;
    case 'invalid-argument':
      // بيانات غير صحيحة
      break;
    case 'permission-denied':
      // لا يوجد صلاحية
      break;
    default:
      // خطأ آخر
  }
}
```

### 3. استخدام Emulator (للاختبار)

```dart
// في main.dart (للاختبار فقط)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // استخدام Emulator
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  
  runApp(MyApp());
}
```

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

1. إنشاء `CloudFunctionsService`
2. إضافة Functions يدوية في `functions/index.js` (إذا لزم الأمر)
3. استخدام Service في التطبيق

**معظم Functions تعمل تلقائياً - لا تحتاج أي كود إضافي!** 🎉








