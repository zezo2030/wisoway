/// Application strings for localization
/// This file contains all user-facing strings in Arabic and English
/// Following Clean Code principles for maintainability and i18n readiness
class AppStrings {
  AppStrings._();

  // ========== Profile Setup Screen ==========
  static const String profileSetupTitle = 'أكمل ملفك الشخصي';
  static const String profileSetupSubtitle =
      'نحتاج بعض المعلومات لإكمال التسجيل';
  static const String lastStep = 'الخطوة الأخيرة';

  // Form Labels
  static const String fullName = 'الاسم الكامل';
  static const String fullNameHint = 'أدخل اسمك الكامل';
  static const String email = 'البريد الإلكتروني';
  static const String emailHint = 'example@email.com';

  // Gender
  static const String gender = 'الجنس';
  static const String male = 'ذكر';
  static const String female = 'أنثى';

  // User Type
  static const String userType = 'نوع المستخدم';
  static const String passenger = 'راكب';
  static const String passengerDescription = 'يمكنك حجز الرحلات';
  static const String tripOwner = 'صاحب رحلات';
  static const String tripOwnerDescription = 'يمكنك إنشاء وحجز الرحلات';
  static const String tripOwnerNote =
      'صاحب الرحلات يمكنه أيضاً حجز رحلات كراكب';

  // Buttons
  static const String saveAndComplete = 'حفظ وإكمال التسجيل';

  // Validation Messages
  static const String nameRequired = 'يرجى إدخال الاسم';
  static const String nameMinLength = 'الاسم يجب أن يكون على الأقل حرفين';
  static const String emailRequired = 'يرجى إدخال البريد الإلكتروني';
  static const String emailInvalid = 'البريد الإلكتروني غير صحيح';
  static const String genderRequired = 'يرجى اختيار الجنس';
  static const String userTypeRequired =
      'يرجى اختيار نوع المستخدم (راكب أو صاحب رحلات)';

  // Common
  static const String error = 'خطأ';
  static const String required = '*';

  // ========== Other Screens (Add as needed) ==========
  // Sign In
  static const String welcome = 'مرحباً بك';
  static const String signInToContinue = 'سجل دخولك للاستمرار';
  static const String signIn = 'تسجيل الدخول';
  static const String password = 'كلمة المرور';
  static const String phoneNumber = 'رقم الهاتف';
  static const String phoneNumberHint = '+201234567890';
  static const String sendVerificationCode = 'إرسال رمز التحقق';
  static const String or = 'أو';
  static const String signInWithGoogle = 'تسجيل الدخول بـ Google';
  static const String signInWithFacebook = 'تسجيل الدخول بـ Facebook';
  static const String noAccount = 'ليس لديك حساب؟';
  static const String createNewAccount = 'إنشاء حساب جديد';
  static const String emailTab = 'بريد إلكتروني';
  static const String phoneTab = 'رقم هاتف';

  // Password Reset
  static const String forgotPassword = 'نسيت كلمة المرور';
  static const String forgotPasswordDesc = 'أدخل رقم هاتفك لإرسال رمز التحقق';
  static const String sendCode = 'إرسال الرمز';
  static const String enterVerificationCode = 'أدخل رمز التحقق';
  static const String setNewPassword = 'تعيين كلمة مرور جديدة';
  static const String confirmNewPassword = 'تأكيد كلمة المرور الجديدة';
  static const String passwordResetSuccess = 'تم إعادة تعيين كلمة المرور بنجاح';
  static const String resendCode = 'إعادة إرسال الرمز';
  static const String codeExpired = 'انتهت صلاحية الرمز';
  static const String tooManyAttempts = 'محاولات كثيرة جداً';
  static const String invalidCode = 'رمز غير صحيح';
  static const String passwordTooWeak = 'كلمة المرور ضعيفة جداً';
  static const String passwordsDontMatch = 'كلمات المرور غير متطابقة';

  // Change Password
  static const String changePassword = 'تغيير كلمة المرور';
  static const String currentPassword = 'كلمة المرور الحالية';
  static const String newPassword = 'كلمة المرور الجديدة';
  static const String confirmPassword = 'تأكيد كلمة المرور';
  static const String passwordChangedSuccess = 'تم تغيير كلمة المرور بنجاح';
  static const String currentPasswordIncorrect = 'كلمة المرور الحالية غير صحيحة';
  static const String samePasswordError = 'كلمة المرور الجديدة يجب أن تكون مختلفة';

  // Social Login Error
  static const String socialLoginNotAvailable = 'غير متاح لحسابات تسجيل الدخول الاجتماعي';

  // Errors
  static const String signInError = 'خطأ في تسجيل الدخول';
  static const String passwordRequired = 'يرجى إدخال كلمة المرور';
  static const String phoneRequired = 'يرجى إدخال رقم الهاتف';
}
