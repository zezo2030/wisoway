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

  // Errors
  static const String signInError = 'خطأ في تسجيل الدخول';
  static const String passwordRequired = 'يرجى إدخال كلمة المرور';
  static const String phoneRequired = 'يرجى إدخال رقم الهاتف';
}
