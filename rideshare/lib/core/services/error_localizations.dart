import 'package:flutter/material.dart';

class ErrorLocalizations {
  static const _en = <String, String>{
    'errorsNetworkOffline':
        "You're offline. Check your connection and try again.",
    'errorsNetworkTimeout': 'Connection timed out. Please try again.',
    'errorsServerGeneric':
        'Something went wrong on our end. Please try again later.',
    'errorsAuthSessionExpired': 'Your session has expired. Please sign in again.',
    'errorsAuthInvalidCredentials': 'Invalid email or password.',
    'errorsPermissionDenied': 'Permission denied. Check your app settings.',
    'errorsValidationGeneric':
        'Invalid input. Please check your data and try again.',
    'errorsWalletInsufficientBalance':
        'Your wallet balance is not enough to complete this booking. Please top up your wallet and try again.',
    'errorsUnknownGeneric':
        'An unexpected error occurred. Please try again.',
    'errorsRouteUnavailable':
        "We couldn't load the route. Showing pickup and drop-off points.",
    'errorsActionRetry': 'Retry',
    'errorsActionReauthenticate': 'Sign in again',
    'errorsActionOpenSettings': 'Open Settings',
    'error': 'Error',
    'ok': 'OK',
  };

  static const _ar = <String, String>{
    'errorsNetworkOffline':
        'أنت غير متصل بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.',
    'errorsNetworkTimeout': 'انتهت مهلة الاتصال. حاول مرة أخرى.',
    'errorsServerGeneric': 'حدث خطأ في الخادم. حاول مرة أخرى لاحقًا.',
    'errorsAuthSessionExpired':
        'انتهت صلاحية جلستك. يرجى تسجيل الدخول مرة أخرى.',
    'errorsAuthInvalidCredentials':
        'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
    'errorsPermissionDenied': 'تم رفض الإذن. تحقق من إعدادات التطبيق.',
    'errorsValidationGeneric':
        'البيانات المدخلة غير صحيحة. راجع البيانات وحاول مرة أخرى.',
    'errorsWalletInsufficientBalance':
        'رصيد المحفظة غير كافٍ لإتمام الحجز. يرجى شحن المحفظة ثم المحاولة مرة أخرى.',
    'errorsUnknownGeneric': 'حدث خطأ غير متوقع. حاول مرة أخرى.',
    'errorsRouteUnavailable':
        'تعذّر تحميل المسار. نعرض نقاط الانطلاق والوصول.',
    'errorsActionRetry': 'إعادة المحاولة',
    'errorsActionReauthenticate': 'تسجيل الدخول مرة أخرى',
    'errorsActionOpenSettings': 'فتح الإعدادات',
    'error': 'خطأ',
    'ok': 'موافق',
  };

  static String resolve(BuildContext context, String key) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final map = isAr ? _ar : _en;
    return map[key] ?? _en[key] ?? key;
  }
}
