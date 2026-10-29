import 'package:flutter/material.dart';

import '../errors/failure.dart';

class ErrorLocalizations {
  static const _en = <String, String>{
    'errorsNetworkOffline':
        "You're offline. Check your connection and try again.",
    'errorsNetworkTimeout': 'Connection timed out. Please try again.',
    'errorsServerGeneric':
        'Something went wrong on our end. Please try again later.',
    'errorsAuthSessionExpired':
        'Your session has expired. Please sign in again.',
    'errorsAuthInvalidCredentials': 'Invalid email or password.',
    'errorsPermissionDenied': 'Permission denied. Check your app settings.',
    'errorsValidationGeneric':
        'Invalid input. Please check your data and try again.',
    'errorsWalletInsufficientBalance':
        'Your wallet balance is not enough to complete this booking. Please top up your wallet and try again.',
    'errorsUnknownGeneric': 'An unexpected error occurred. Please try again.',
    'errorsPhoneHidden':
        'This person keeps their number private. Reach them through the in-app chat.',
    'errorsRouteUnavailable':
        "We couldn't load the route. Showing pickup and drop-off points.",
    'errorsOutstandingCharges':
        'You have {count} unpaid charge(s) totaling {total} JOD. Settle them before publishing a new trip.',
    'errorsNegativeWalletBalance':
        'Top up your wallet with at least JOD 5, SAR 25, or the equivalent and settle any outstanding dues to continue receiving and creating trips.',
    'errorsInsufficientBalanceForTripFee':
        'Your wallet balance is not enough to cover the trip fee. Top up your wallet before publishing.',
    'errorsActionRetry': 'Retry',
    'errorsActionReauthenticate': 'Sign in again',
    'errorsActionOpenSettings': 'Open Settings',
    'errorsActionViewPendingCharges': 'View Charges',
    'errorsActionTopUpWallet': 'Top up wallet',
    'error': 'Error',
    'ok': 'OK',
  };

  static const _ar = <String, String>{
    'errorsNetworkOffline':
        'أنت غير متصل بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.',
    'errorsNetworkTimeout': 'انتهت مهلة الاتصال. حاول مرة أخرى.',
    'errorsServerGeneric': 'حدث خطأ في الخادم. حاول مرة أخرى لاحقاً.',
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
    'errorsPhoneHidden':
        'هذا المستخدم يُخفي رقم هاتفه. تواصل معه عبر المحادثة في التطبيق.',
    'errorsRouteUnavailable': 'تعذّر تحميل المسار. نعرض نقاط الانطلاق والوصول.',
    'errorsOutstandingCharges':
        'لديك {count} رسوم مستحقة بإجمالي {total} د.أ. يجب تسويتها قبل نشر رحلة جديدة.',
    'errorsNegativeWalletBalance':
        'اشحن محفظتك بحد أدنى 5 دنانير أو 25 ريالاً أو ما يعادلها وسدد أي مستحقات للاستمرار في استقبال الرحلات وإنشائها.',
    'errorsInsufficientBalanceForTripFee':
        'رصيد محفظتك لا يكفي لتغطية رسوم الرحلة. اشحن محفظتك قبل نشر الرحلة.',
    'errorsActionRetry': 'إعادة المحاولة',
    'errorsActionReauthenticate': 'تسجيل الدخول مرة أخرى',
    'errorsActionOpenSettings': 'فتح الإعدادات',
    'errorsActionViewPendingCharges': 'عرض الرسوم',
    'errorsActionTopUpWallet': 'شحن المحفظة',
    'error': 'خطأ',
    'ok': 'موافق',
  };

  static String resolve(BuildContext context, String key) {
    // Keyed off the app's locale, not the ambient text direction: a subtree
    // that opts out of RTL for layout reasons (the vehicle cabin does) would
    // otherwise show English errors inside an Arabic app.
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
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
