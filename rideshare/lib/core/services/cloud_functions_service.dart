import 'package:cloud_functions/cloud_functions.dart';

/// Service لاستدعاء Cloud Functions من Flutter
class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// إرسال إشعار تجريبي
  /// 
  /// مثال:
  /// ```dart
  /// await cloudFunctionsService.sendTestNotification(
  ///   userId: 'user123',
  ///   title: 'إشعار تجريبي',
  ///   body: 'هذا إشعار تجريبي',
  /// );
  /// ```
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

      return Map<String, dynamic>.from(result.data ?? {});
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionError(e);
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }

  /// معالجة دفع (مثال - يمكن إضافة المزيد)
  Future<Map<String, dynamic>> processPayment({
    required String paymentId,
    required String amount,
    required String currency,
  }) async {
    try {
      final callable = _functions.httpsCallable('processPayment');
      
      final result = await callable.call({
        'paymentId': paymentId,
        'amount': amount,
        'currency': currency,
      });

      return Map<String, dynamic>.from(result.data ?? {});
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionError(e);
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }

  /// الحصول على إحصائيات المستخدم (مثال)
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final callable = _functions.httpsCallable('getUserStats');
      
      final result = await callable.call({
        'userId': userId,
      });

      return Map<String, dynamic>.from(result.data ?? {});
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionError(e);
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }

  /// إرسال إشعار وصول السائق
  /// 
  /// مثال:
  /// ```dart
  /// await cloudFunctionsService.notifyDriverArrived(tripId: 'trip123');
  /// ```
  Future<Map<String, dynamic>> notifyDriverArrived({
    required String tripId,
  }) async {
    try {
      final callable = _functions.httpsCallable('onDriverArrived');
      
      final result = await callable.call({
        'tripId': tripId,
      });

      return Map<String, dynamic>.from(result.data ?? {});
    } on FirebaseFunctionsException catch (e) {
      throw _handleFunctionError(e);
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }

  /// معالجة أخطاء Functions
  Exception _handleFunctionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return Exception('يجب تسجيل الدخول أولاً');
      case 'permission-denied':
        return Exception('ليس لديك صلاحية للقيام بهذا الإجراء');
      case 'invalid-argument':
        return Exception('البيانات المرسلة غير صحيحة: ${e.message}');
      case 'not-found':
        return Exception('الـ Function غير موجودة');
      case 'already-exists':
        return Exception('البيانات موجودة بالفعل');
      case 'resource-exhausted':
        return Exception('تم تجاوز الحد المسموح');
      case 'failed-precondition':
        return Exception('الشرط المطلوب غير متوفر');
      case 'aborted':
        return Exception('تم إلغاء العملية');
      case 'out-of-range':
        return Exception('القيمة خارج النطاق المسموح');
      case 'unimplemented':
        return Exception('هذه الميزة غير متاحة حالياً');
      case 'internal':
        return Exception('خطأ داخلي في الخادم');
      case 'unavailable':
        return Exception('الخدمة غير متاحة حالياً');
      case 'data-loss':
        return Exception('فقدان البيانات');
      default:
        return Exception('خطأ: ${e.message ?? e.code}');
    }
  }

  /// استخدام Emulator للاختبار (في وضع التطوير فقط)
  void useEmulator({String host = 'localhost', int port = 5001}) {
    _functions.useFunctionsEmulator(host, port);
  }
}

