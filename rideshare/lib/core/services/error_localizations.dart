import 'package:flutter/material.dart';

import '../errors/failure.dart';

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
    'errorsOutstandingCharges':
        'You have {count} unpaid charge(s) totaling {total} JOD. Settle them before publishing a new trip.',
    'errorsActionRetry': 'Retry',
    'errorsActionReauthenticate': 'Sign in again',
    'errorsActionOpenSettings': 'Open Settings',
    'errorsActionViewPendingCharges': 'View Charges',
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
    'errorsOutstandingCharges':
        'لديك {count} رسوم مستحقة بإجمالي {total} د.أ. يجب تسويتها قبل نشر رحلة جديدة.',
    'errorsActionRetry': 'إعادة المحاولة',
    'errorsActionReauthenticate': 'تسجيل الدخول مرة أخرى',
    'errorsActionOpenSettings': 'فتح الإعدادات',
    'errorsActionViewPendingCharges': 'عرض الرسوم',
    'error': 'خطأ',
    'ok': 'موافق',
  };

  static String resolve(BuildContext context, String key) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final map = isAr ? _ar : _en;
    return map[key] ?? _en[key] ?? key;
  }

  /// Resolve a Failure's user-facing message, applying any per-category
  /// interpolation (e.g. count/total for outstanding charges).
  static String resolveFailure(BuildContext context, Failure failure) {
    final template = resolve(context, failure.messageKey);
    if (failure.category == FailureCategory.outstandingCharges) {
      final count = failure.outstandingCount ?? 0;
      final total = (failure.outstandingTotal ?? 0).toStringAsFixed(2);
      return template
          .replaceAll('{count}', count.toString())
          .replaceAll('{total}', total);
    }
    return template;
  }
}
