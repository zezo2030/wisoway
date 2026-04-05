import 'package:dio/dio.dart';

enum AuthAction { signIn, signUp, otp, passwordReset }

class AuthErrorFormatter {
  static bool isPhoneVerificationRequired(Object error) {
    final backendMessage = _extractBackendMessage(error);
    final message = (backendMessage ?? _clean(error.toString())).toLowerCase();
    return message.contains('phone_verification_required');
  }

  static String format(
    Object error, {
    required AuthAction action,
  }) {
    final backendMessage = _extractBackendMessage(error);
    final message = backendMessage ?? _clean(error.toString());
    final lower = message.toLowerCase();

    if (lower.contains('phone_verification_required')) {
      return 'الحساب غير مفعل بعد. يرجى تأكيد رقم الهاتف أولاً.';
    }
    if (lower.contains('email already registered') ||
        lower.contains('email already exists') ||
        lower.contains('already registered')) {
      return 'هذا البريد الإلكتروني مستخدم بالفعل. جرّب تسجيل الدخول أو استخدم بريداً آخر.';
    }
    if (lower.contains('invalid credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (lower.contains('account is inactive')) {
      return 'الحساب غير نشط حالياً. تواصل مع الدعم.';
    }
    if (lower.contains('password') && lower.contains('8')) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
    }
    if (lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection error')) {
      return 'تعذر الاتصال بالخادم. تأكد من الإنترنت وحاول مرة أخرى.';
    }
    if (lower.contains('timeout')) {
      return 'انتهت مهلة الاتصال بالخادم. حاول مرة أخرى.';
    }
    if (lower.contains('invalid or expired otp') ||
        lower.contains('otp code must') ||
        lower.contains('verification code')) {
      return 'رمز التحقق غير صحيح أو منتهي الصلاحية.';
    }

    switch (action) {
      case AuthAction.signIn:
        return 'تعذر تسجيل الدخول حالياً. تحقق من بياناتك وحاول مرة أخرى.';
      case AuthAction.signUp:
        return 'تعذر إنشاء الحساب حالياً. راجع البيانات وحاول مرة أخرى.';
      case AuthAction.otp:
        return 'تعذر التحقق من الرمز حالياً. حاول مرة أخرى.';
      case AuthAction.passwordReset:
        return 'تعذر إعادة تعيين كلمة المرور حالياً. حاول مرة أخرى.';
    }
  }

  static String? _extractBackendMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        if (message is List && message.isNotEmpty) {
          final first = message.first;
          if (first is String && first.trim().isNotEmpty) {
            return first.trim();
          }
        }
        final errorText = data['error'];
        if (errorText is String && errorText.trim().isNotEmpty) {
          return errorText.trim();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'timeout';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'network';
      }
    }
    return null;
  }

  static String _clean(String value) {
    return value.replaceFirst('Exception: ', '').trim();
  }
}
