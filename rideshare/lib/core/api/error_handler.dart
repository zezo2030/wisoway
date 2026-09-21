import 'package:dio/dio.dart';

class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final data = error.response?.data;
        if (data is Map && data.containsKey('message')) {
          final message = data['message'];
          if (message is List) return message.join('\n');
          return message.toString();
        }
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'انتهى وقت الاتصال';
        case DioExceptionType.connectionError:
          return 'يرجى التحقق من اتصالك بالإنترنت';
        default:
          return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
      }
    }
    return error.toString();
  }
}
