// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'VisionWay';

  @override
  String get phoneAuth => 'تسجيل الدخول';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get phoneNumberHint => '+201234567890';

  @override
  String get phoneNumberRequired => 'يرجى إدخال رقم الهاتف';

  @override
  String get sendOTP => 'إرسال رمز التحقق';

  @override
  String get otpVerification => 'التحقق من الرمز';

  @override
  String get enterOTP => 'أدخل رمز التحقق';

  @override
  String get resendOTP => 'إعادة إرسال الرمز';

  @override
  String resendOTPIn(int seconds) {
    return 'إعادة إرسال الرمز خلال $seconds ثانية';
  }

  @override
  String get profileSetup => 'إعداد الملف الشخصي';

  @override
  String get name => 'الاسم';

  @override
  String get nameRequired => 'يرجى إدخال الاسم';

  @override
  String get gender => 'الجنس';

  @override
  String get genderRequired => 'يرجى اختيار الجنس';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get role => 'الدور';

  @override
  String get roleRequired => 'يرجى اختيار الدور';

  @override
  String get passenger => 'راكب';

  @override
  String get driver => 'سائق';

  @override
  String get save => 'حفظ';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get error => 'خطأ';

  @override
  String get ok => 'موافق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get home => 'الرئيسية';

  @override
  String get welcome => 'مرحباً';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get invalidPhoneNumber => 'رقم الهاتف غير صحيح';

  @override
  String get otpSent => 'تم إرسال رمز التحقق';

  @override
  String get otpVerified => 'تم التحقق بنجاح';

  @override
  String get invalidOTP => 'رمز التحقق غير صحيح';

  @override
  String get profileSaved => 'تم حفظ الملف الشخصي بنجاح';

  @override
  String get settings => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get darkMode => 'الوضع الداكن';

  @override
  String get darkModeSubtitle => 'تفعيل المظهر الداكن للتطبيق';

  @override
  String get themeMode => 'سمة التطبيق';

  @override
  String get themeSystem => 'تلقائي (حسب النظام)';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get selectTheme => 'اختر السمة';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get currentLanguageAr => 'العربية';

  @override
  String get currentLanguageEn => 'English';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get pushNotifications => 'الإشعارات';

  @override
  String get notificationSound => 'الأصوات';

  @override
  String get notificationVibration => 'الاهتزاز';

  @override
  String get notificationSettings => 'إعدادات مفصلة';

  @override
  String get notificationSettingsTitle => 'إعدادات الإشعارات';

  @override
  String get notificationCategories => 'فئات الإشعارات';

  @override
  String get notifTrips => 'إشعارات الرحلات';

  @override
  String get notifPayments => 'إشعارات الدفع';

  @override
  String get notifMessages => 'إشعارات الرسائل';

  @override
  String get notifSystem => 'إشعارات النظام';

  @override
  String get notifCustomizeInfo => 'يمكنك تخصيص الإشعارات التي تريد استقبالها';

  @override
  String get accountSecurity => 'الحساب والأمان';

  @override
  String get accountInfo => 'معلومات الحساب';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get accountSecurityTitle => 'الحساب والأمان';

  @override
  String get accountDetails => 'معلومات الحساب';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get phoneLabel => 'رقم الهاتف';

  @override
  String get accountType => 'نوع الحساب';

  @override
  String get linkPhone => 'ربط';

  @override
  String get verificationStatus => 'حالة التوثيق';

  @override
  String get emailVerified => 'البريد الإلكتروني';

  @override
  String get phoneVerified => 'رقم الهاتف';

  @override
  String get driverApproval => 'اعتماد السائق';

  @override
  String get verified => 'موثّق';

  @override
  String get notVerified => 'غير موثّق';

  @override
  String get approved => 'معتمد';

  @override
  String get pending => 'قيد المراجعة';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get locationSharing => 'مشاركة الموقع';

  @override
  String get locationSharingSubtitle => 'مشاركة موقعك المباشر';

  @override
  String get onlineStatus => 'الظهور متصل';

  @override
  String get onlineStatusSubtitle => 'إظهار حالة الاتصال';

  @override
  String get showRating => 'إظهار التقييم';

  @override
  String get showRatingSubtitle => 'إظهار تقييمك للآخرين';

  @override
  String get privacyTitle => 'الخصوصية';

  @override
  String get privacySettings => 'إعدادات الخصوصية';

  @override
  String get privacyInfo => 'هذه الإعدادات تتحكم في ما يمكن للآخرين رؤيته عنك';

  @override
  String get paymentAndWallet => 'الدفع والمحفظة';

  @override
  String get wallet => 'المحفظة';

  @override
  String get paymentHistory => 'سجل المدفوعات';

  @override
  String get supportAndHelp => 'الدعم والمساعدة';

  @override
  String get contactUs => 'تواصل معنا';

  @override
  String get termsOfService => 'شروط الاستخدام';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get aboutApp => 'حول التطبيق';

  @override
  String get aboutAppTitle => 'حول التطبيق';

  @override
  String get rateApp => 'تقييم التطبيق';

  @override
  String get shareApp => 'مشاركة التطبيق';

  @override
  String get licenses => 'التراخيص';

  @override
  String appVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get appDescription => 'منصة مشاركة الرحلات';

  @override
  String get madeWithLove => 'صنع بـ ❤️ في الأردن';

  @override
  String get inAppBrowserTitle => 'المتصفح';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountWarning =>
      'هل أنت متأكد من رغبتك في حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.';

  @override
  String get deleteAccountConfirm => 'نعم، حذف الحساب';

  @override
  String get deleteAccountSecondWarning =>
      'تحذير أخير: سيتم حذف جميع بياناتك بشكل نهائي ولن تتمكن من استرجاعها.';

  @override
  String get deleteAccountSecondConfirm => 'حذف نهائي';

  @override
  String get contactSupportTitle => 'تواصل مع الدعم';

  @override
  String get contactSupportMessage =>
      'لا يمكن حذف الحساب حالياً. تواصل مع الدعم الفني عبر واتساب أو البريد الإلكتروني.';

  @override
  String get contactWhatsApp => 'تواصل عبر واتساب';

  @override
  String get contactEmail => 'تواصل عبر البريد';

  @override
  String get close => 'إغلاق';

  @override
  String get errorsNetworkOffline =>
      'أنت غير متصل بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get errorsNetworkTimeout => 'انتهت مهلة الاتصال. حاول مرة أخرى.';

  @override
  String get errorsServerGeneric => 'حدث خطأ في الخادم. حاول مرة أخرى لاحقاً.';

  @override
  String get errorsAuthSessionExpired =>
      'انتهت صلاحية جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get errorsAuthInvalidCredentials =>
      'رقم الهاتف أو كلمة المرور غير صحيحة.';

  @override
  String get errorsPermissionDenied => 'تم رفض الإذن. تحقق من إعدادات التطبيق.';

  @override
  String get errorsValidationGeneric =>
      'البيانات المدخلة غير صحيحة. راجع البيانات وحاول مرة أخرى.';

  @override
  String get errorsUnknownGeneric => 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  @override
  String get errorsActionRetry => 'إعادة المحاولة';

  @override
  String get errorsActionReauthenticate => 'تسجيل الدخول مرة أخرى';

  @override
  String get errorsActionOpenSettings => 'فتح الإعدادات';

  @override
  String get errorsRouteUnavailable =>
      'تعذّر تحميل المسار. نعرض نقاط الانطلاق والوصول.';

  @override
  String get notificationsBookingCreatedTitle => 'حجز جديد';

  @override
  String get notificationsBookingCreatedBody => 'تم حجز مقعد جديد في رحلتك';

  @override
  String get notificationsBookingConfirmedTitle => 'تم تأكيد الحجز';

  @override
  String get notificationsBookingConfirmedBody => 'تم تأكيد حجزك بنجاح';

  @override
  String get notificationsBookingRejectedTitle => 'تم رفض الحجز';

  @override
  String get notificationsBookingRejectedBody => 'للأسف، تم رفض حجزك';

  @override
  String get notificationsBookingCanceledTitle => 'تم إلغاء الحجز';

  @override
  String get notificationsBookingCanceledBody => 'تم إلغاء الحجز';

  @override
  String get notificationsNewTripPostedTitle => 'رحلة جديدة';

  @override
  String notificationsNewTripPostedBody(String destination) {
    return 'يتوفر رحلة جديدة إلى $destination';
  }

  @override
  String get accountBannedTitle => 'تم تعليق حسابك';

  @override
  String accountBannedMessage(String reason) {
    return 'تم تعليق حسابك بسبب: $reason';
  }

  @override
  String get accountBannedContactSupport => 'تواصل مع الدعم';

  @override
  String get accountRestrictedBanner =>
      'حسابك مقيّد مؤقتاً. بعض الإجراءات غير متاحة حتى تتم المراجعة.';

  @override
  String get maskedPhoneLabel => 'رقم محجوب';

  @override
  String get maskedPhoneHint => 'يُكشف الرقم بعد إتمام الدفع';

  @override
  String get shareLinkTripEnded => 'انتهت الرحلة';

  @override
  String get shareLinkLiveTracking => 'تتبع مباشر';

  @override
  String get shareLinkGenerate => 'مشاركة الرحلة';

  @override
  String get noShowNotificationTitle => 'لم يصل السائق';

  @override
  String get noShowNotificationBody =>
      'لم يبدأ السائق الرحلة خلال الوقت المحدد. تم إلغاء الرحلة وسيتم احتساب غرامة.';

  @override
  String pendingChargeBanner(String amount) {
    return 'لديك رسوم معلقة بقيمة $amount. ستُخصم عند تأكيد حجزك القادم.';
  }

  @override
  String get pendingChargeTitle => 'رسوم معلقة';

  @override
  String get pendingChargeKindPassengerCancellation => 'غرامة إلغاء حجز';

  @override
  String get pendingChargeKindDriverNoShow => 'غرامة غياب السائق';

  @override
  String get pendingChargeKindPassengerNoShow => 'غرامة غياب الراكب';

  @override
  String get devicesScreenTitle => 'الأجهزة المتصلة';

  @override
  String get devicesRevokeButton => 'إزالة الجهاز';

  @override
  String get devicesCurrentDevice => 'الجهاز الحالي';

  @override
  String get bookingTimeoutNotificationTitle => 'انتهت صلاحية الحجز';

  @override
  String get bookingTimeoutNotificationBody =>
      'انتهت مهلة الحجز ولم يتم قبوله من السائق. المقاعد أصبحت متاحة.';

  @override
  String get settlementMarkPaid => 'تأكيد الدفع';

  @override
  String get settlementUnmarkPaid => 'التراجع عن تأكيد الدفع';

  @override
  String settlementGraceCountdown(int seconds) {
    return 'يمكن التراجع خلال $seconds ثانية';
  }

  @override
  String get chatDisabledUnsettled => 'الدردشة متاحة بعد إتمام الدفع';

  @override
  String get callDisabledUnsettled => 'الاتصال متاح بعد إتمام الدفع';

  @override
  String get callMaskedNumber => 'الاتصال عبر رقم مخفي';

  @override
  String get hidePhoneNumberToggle => 'إخفاء رقم هاتفي';

  @override
  String get hidePhoneNumberSubtitle => 'سيُستخدم رقم وسيط عند الاتصال بك';

  @override
  String get complaintScreenTitle => 'تقديم شكوى';

  @override
  String get complaintCategoryLabel => 'نوع الشكوى';

  @override
  String get complaintDescriptionLabel => 'وصف المشكلة';

  @override
  String get complaintSubmitButton => 'إرسال الشكوى';

  @override
  String get complaintSubmittedSuccess =>
      'تم إرسال شكواك بنجاح. سنراجعها قريباً.';

  @override
  String get complaintStatusResolved => 'تم الحل';

  @override
  String get refundRequestTitle => 'طلب استرداد';

  @override
  String get refundRequestBody =>
      'سيتم فتح واتساب للتواصل مع فريق الدعم بشأن طلب الاسترداد.';

  @override
  String get refundRequestButton => 'تقديم طلب الاسترداد';

  @override
  String get supportScreenTitle => 'الدعم والمساعدة';

  @override
  String get supportWhatsAppButton => 'تواصل عبر واتساب';

  @override
  String get tripStopsLabel => 'محطات التوقف';

  @override
  String get tripNotesLabel => 'ملاحظات الرحلة';

  @override
  String get tripRecurrenceLabel => 'تكرار الرحلة';

  @override
  String get recurrenceFrequencyDaily => 'يومياً';

  @override
  String get recurrenceFrequencyWeekly => 'أسبوعياً';

  @override
  String get recurrenceUntilLabel => 'حتى تاريخ';

  @override
  String get companionPickerTitle => 'إضافة مرافقين';

  @override
  String get companionDisplayNameLabel => 'اسم المرافق';

  @override
  String get autoPickSeatsButton => 'اختيار مقاعد تلقائي';

  @override
  String get preTripPromptTitle => 'تأكيد الحضور';

  @override
  String get preTripPromptPassengerBody => 'هل السائق موجود في نقطة الانطلاق؟';

  @override
  String preTripPromptDriverBody(String name) {
    return 'هل الراكب $name موجود؟';
  }

  @override
  String get presenceScreenTitle => 'تأكيد التواجد في السيارة';

  @override
  String get presenceScreenSubtitle => 'يرجى تأكيد تواجدك لبدء الرحلة';

  @override
  String get presenceHelp => 'مساعدة';

  @override
  String get presenceDriverStartsAfter => 'سيبدأ السائق الرحلة بعد';

  @override
  String get presenceMinutes => 'دقائق';

  @override
  String get presencePickupTitle => 'نقطة بدء الرحلة';

  @override
  String get presenceQuestionTitle => 'هل أنت داخل السيارة؟';

  @override
  String get presenceQuestionSubtitle =>
      'يرجى تأكيد تواجدك لتوثيق الرحلة وبدئها بشكل صحيح';

  @override
  String get presenceInfoBody =>
      'يساعد تأكيد تواجدك داخل السيارة على توثيق الرحلة واحتسابها ضمن سجل رحلاتك وتقييم موثوقية حسابك.\nلن يتم خصم أي رسوم من محفظة السائق في حال عدم التأكيد.';

  @override
  String get presenceInVehicleTitle => 'نعم، أنا داخل السيارة';

  @override
  String get presenceInVehicleSubtitle => 'تأكيد التواجد';

  @override
  String get presenceOnMyWayTitle => 'أنا في طريقي لمقابلة السائق';

  @override
  String get presenceOnMyWaySubtitle => 'سأصل خلال دقائق';

  @override
  String get presenceNotRidingTitle => 'لست داخل السيارة';

  @override
  String get presenceNotRidingSubtitle => 'لن أستقل هذه الرحلة';

  @override
  String get presencePrivacyLine =>
      'بياناتك آمنة ويتم استخدامها فقط لتحسين تجربة الرحلة';

  @override
  String get presenceRequestEndsAfter => 'سينتهي طلب التأكيد تلقائيًا بعد';

  @override
  String get presenceConfirmedTitle => 'تم تأكيد تواجدك';

  @override
  String get presenceConfirmedBody => 'شكرًا لك، تم تسجيل اختيارك لهذه الرحلة.';

  @override
  String get presenceEdit => 'تعديل';

  @override
  String get presenceWindowClosedTitle => 'انتهى وقت التأكيد';

  @override
  String get presenceWindowClosedBody =>
      'لم يعد بإمكانك تعديل حالة تواجدك لهذه الرحلة.';

  @override
  String get presenceLoadFailed => 'تعذر تحميل بيانات تأكيد التواجد';

  @override
  String get presenceSubmitFailed => 'تعذر حفظ اختيارك. حاول مرة أخرى.';

  @override
  String get arrivedAtDestinationButton => 'تم الوصول للوجهة';

  @override
  String get markPassengerAbsent => 'غياب الراكب';

  @override
  String get welcomeTitle => 'مرحباً بك في VisionWay';

  @override
  String get welcomeSubtitle =>
      'رحلتك تبدأ من هنا. اختر وجهتك وانطلق معنا بكل أمان وراحة.';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get createNewAccount => 'إنشاء حساب جديد';

  @override
  String get signInSubtitle => 'أهلاً بك مجدداً! سجل دخولك للمتابعة.';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة';

  @override
  String get passwordTooShort => 'كلمة المرور قصيرة';

  @override
  String get forgotPassword => 'نسيت كلمة السر؟';

  @override
  String get noAccountQuestion => 'ليس لديك حساب؟ ';

  @override
  String get phoneNumberFirst => 'يرجى إدخال رقم الهاتف أولاً';

  @override
  String get passwordResetLinkSent => 'تم إرسال رابط إعادة تعيين كلمة المرور';

  @override
  String get required => 'مطلوب';

  @override
  String get accountTypePassenger => 'راكب';

  @override
  String get accountTypeDriver => 'سائق';

  @override
  String get accountTypeTitle => 'اختر نوع الحساب';

  @override
  String get accountTypeSubtitle => 'حدد كيف تريد استخدام التطبيق';

  @override
  String get accountTypePassengerDesc => 'احجز رحلتك بسهولة';

  @override
  String get accountTypeDriverDesc => 'اعرض رحلاتك للركاب';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get signUpTitle => 'إنشاء حساب';

  @override
  String get signUpSubtitle => 'أنشئ حسابك للبدء';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get fullNameRequired => 'الاسم مطلوب';

  @override
  String get emailOptional => 'البريد الإلكتروني (اختياري)';

  @override
  String get invalidEmail => 'بريد إلكتروني غير صحيح';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟ ';

  @override
  String get phoneAuthTitle => 'تأكيد رقم الهاتف';

  @override
  String get phoneAuthSubtitle => 'سنرسل لك رمز تحقق عبر رسالة نصية';

  @override
  String get linkPhoneTitle => 'ربط رقم الهاتف';

  @override
  String get linkPhoneSubtitle => 'أكد رقم هاتفك للمتابعة';

  @override
  String get otpScreenTitle => 'إدخال رمز التحقق';

  @override
  String otpScreenSubtitle(String phone) {
    return 'أدخل الرمز المرسل إلى $phone';
  }

  @override
  String get verifyButton => 'تحقق';

  @override
  String get didntReceiveCode => 'لم يصلك الرمز؟ ';

  @override
  String get forgotPasswordTitle => 'نسيت كلمة المرور';

  @override
  String get forgotPasswordSubtitle =>
      'أدخل رقم هاتفك وسنرسل لك رمز إعادة التعيين';

  @override
  String get sendResetCode => 'إرسال رمز إعادة التعيين';

  @override
  String get resetPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get resetPasswordSubtitle => 'أدخل الرمز وكلمة المرور الجديدة';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get resetCode => 'رمز إعادة التعيين';

  @override
  String get resetCodeRequired => 'الرمز مطلوب';

  @override
  String get resetPasswordButton => 'إعادة تعيين';

  @override
  String get passwordResetSuccess => 'تم تغيير كلمة المرور بنجاح';

  @override
  String get driverSignUpTitle => 'إنشاء حساب سائق';

  @override
  String get driverSignUpSubtitle => 'ابدأ بإدخال بياناتك الأساسية';

  @override
  String get driverCompleteProfileTitle => 'أكمل ملف السائق';

  @override
  String get driverCompleteProfileSubtitle =>
      'نحتاج بعض البيانات لاعتماد حسابك';

  @override
  String get vehicleMake => 'ماركة السيارة';

  @override
  String get vehicleModel => 'موديل السيارة';

  @override
  String get vehicleYear => 'سنة الصنع';

  @override
  String get vehicleColor => 'اللون';

  @override
  String get vehiclePlate => 'رقم اللوحة';

  @override
  String get vehicleSeats => 'عدد المقاعد';

  @override
  String get licenseNumber => 'رقم رخصة القيادة';

  @override
  String get vehicleMakeRequired => 'ماركة السيارة مطلوبة';

  @override
  String get vehicleModelRequired => 'موديل السيارة مطلوب';

  @override
  String get vehicleYearRequired => 'سنة الصنع مطلوبة';

  @override
  String get vehicleColorRequired => 'اللون مطلوب';

  @override
  String get vehiclePlateRequired => 'رقم اللوحة مطلوب';

  @override
  String get vehicleSeatsRequired => 'عدد المقاعد مطلوب';

  @override
  String get licenseNumberRequired => 'رقم الرخصة مطلوب';

  @override
  String get submitButton => 'إرسال';

  @override
  String get driverPendingApprovalTitle => 'حسابك قيد المراجعة';

  @override
  String get driverPendingApprovalBody =>
      'سنراجع بياناتك وسنخبرك فور الموافقة. حتى ذلك الحين، يمكنك استخدام التطبيق كراكب.';

  @override
  String get driverPendingApprovalAction => 'متابعة كراكب';

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String get tripsTab => 'الرحلات';

  @override
  String get bookingsTab => 'حجوزاتي';

  @override
  String get searchTab => 'بحث';

  @override
  String get profileTab => 'حسابي';

  @override
  String get myTripsTitle => 'رحلاتي';

  @override
  String get createTripTitle => 'إنشاء رحلة';

  @override
  String get editTripTitle => 'تعديل الرحلة';

  @override
  String get fromLabel => 'من';

  @override
  String get toLabel => 'إلى';

  @override
  String get departureDate => 'تاريخ المغادرة';

  @override
  String get departureTime => 'وقت المغادرة';

  @override
  String get pricePerSeat => 'السعر لكل مقعد';

  @override
  String get availableSeats => 'المقاعد المتاحة';

  @override
  String get notes => 'ملاحظات';

  @override
  String get createTripButton => 'إنشاء الرحلة';

  @override
  String get saveChangesButton => 'حفظ التغييرات';

  @override
  String get cancelTripButton => 'إلغاء الرحلة';

  @override
  String get startTripButton => 'بدء الرحلة';

  @override
  String get completeTripButton => 'إنهاء الرحلة';

  @override
  String get tripCreated => 'تم إنشاء الرحلة بنجاح';

  @override
  String get tripUpdated => 'تم تحديث الرحلة';

  @override
  String get tripCanceled => 'تم إلغاء الرحلة';

  @override
  String get tripStarted => 'بدأت الرحلة';

  @override
  String get tripCompleted => 'انتهت الرحلة';

  @override
  String get noTripsYet => 'لا توجد رحلات بعد';

  @override
  String get noBookingsYet => 'لا توجد حجوزات بعد';

  @override
  String get searchTripsHint => 'ابحث عن رحلة...';

  @override
  String get bookSeatButton => 'احجز مقعدًا';

  @override
  String get selectSeats => 'اختر المقاعد';

  @override
  String get selectedSeats => 'المقاعد المختارة';

  @override
  String get totalPrice => 'الإجمالي';

  @override
  String get confirmBooking => 'تأكيد الحجز';

  @override
  String get bookingConfirmed => 'تم تأكيد الحجز';

  @override
  String get viewTripDetails => 'تفاصيل الرحلة';

  @override
  String get tripDetailsTitle => 'تفاصيل الرحلة';

  @override
  String get passengersLabel => 'الركاب';

  @override
  String get driverLabel => 'السائق';

  @override
  String get vehicleLabel => 'المركبة';

  @override
  String get departureLabel => 'المغادرة';

  @override
  String get arrivalLabel => 'الوصول';

  @override
  String get priceLabel => 'السعر';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get callDriver => 'اتصال بالسائق';

  @override
  String get chatWithDriver => 'محادثة السائق';

  @override
  String get rateDriver => 'تقييم السائق';

  @override
  String get rateTrip => 'قيّم الرحلة';

  @override
  String get submitRating => 'إرسال التقييم';

  @override
  String get ratingSubmitted => 'تم إرسال التقييم';

  @override
  String get shareRideButton => 'مشاركة الرحلة';

  @override
  String get trackRideButton => 'تتبع الرحلة';

  @override
  String get startNow => 'ابدأ الآن';

  @override
  String get phoneNumberRequired2 => 'أدخل رقم الهاتف';

  @override
  String get verifyOtpTitle => 'التحقق من رقم الهاتف';

  @override
  String get otpSentTo => 'أرسلنا رمز تحقق إلى';

  @override
  String resendCodeIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ث';
  }

  @override
  String get resendCode => 'إعادة الإرسال';

  @override
  String get verifyAndContinue => 'تحقق ومتابعة';

  @override
  String get changeNumber => 'تغيير الرقم';

  @override
  String get personalInfoTitle => 'البيانات الشخصية';

  @override
  String get vehicleInfoTitle => 'بيانات المركبة';

  @override
  String get documentsTitle => 'المستندات';

  @override
  String get uploadIdFront => 'صورة الهوية - الوجه';

  @override
  String get uploadIdBack => 'صورة الهوية - الخلف';

  @override
  String get uploadLicense => 'صورة رخصة القيادة';

  @override
  String get uploadVehicleRegistration => 'صورة دفتر المركبة';

  @override
  String get uploadProfilePhoto => 'صورة الملف الشخصي';

  @override
  String get uploadingFile => 'جاري الرفع...';

  @override
  String get tapToUpload => 'اضغط للرفع';

  @override
  String get tapToChange => 'اضغط للتغيير';

  @override
  String get complete => 'إكمال';

  @override
  String get next => 'التالي';

  @override
  String get back => 'السابق';

  @override
  String get skip => 'تخطي';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get confirm => 'تأكيد';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get share => 'مشاركة';

  @override
  String get copy => 'نسخ';

  @override
  String get search => 'بحث';

  @override
  String get tryAgain => 'إعادة المحاولة';

  @override
  String get logoutButton => 'تسجيل الخروج';

  @override
  String get logoutConfirmTitle => 'تأكيد تسجيل الخروج';

  @override
  String get logoutConfirmMessage => 'هل تريد بالتأكيد تسجيل الخروج؟';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get markAllAsRead => 'تعيين الكل كمقروء';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String signUpAs(String role) {
    return 'سجل الآن كـ $role لبدء رحلتك معنا.';
  }

  @override
  String get fullNameHint => 'أدخل اسمك بالكامل';

  @override
  String get validNameRequired => 'يرجى إدخال اسم صحيح';

  @override
  String get passwordHint => '8 أحرف على الأقل وتحتوي حرفاً ورقماً';

  @override
  String get passwordPolicyError =>
      'يجب أن تحتوي كلمة السر على 8 أحرف مع حرف ورقم';

  @override
  String get confirmPasswordHint => 'أعد إدخال كلمة السر';

  @override
  String get confirmPasswordRequired => 'يرجى تأكيد كلمة السر';

  @override
  String get createAccountDev => 'إنشاء حساب (تطوير)';

  @override
  String get sendOtpAndCreateAccount => 'إرسال رمز التحقق وإنشاء الحساب';

  @override
  String get selectGenderError => 'يرجى اختيار الجنس';

  @override
  String get couldNotOpenWhatsApp => 'تعذر فتح WhatsApp';

  @override
  String get contactSupportViaWhatsApp => 'تواصل مع الدعم عبر WhatsApp';

  @override
  String get pickImageFromGallery => 'اختيار صورة من المعرض';

  @override
  String get captureImageFromCamera => 'التقاط صورة من الكاميرا';

  @override
  String get fromGallery => 'من المعرض';

  @override
  String get fromCamera => 'من الكاميرا';

  @override
  String get driverProfileSubmittedFull =>
      'تم رفع بياناتك بنجاح. طلبك قيد المراجعة من الإدارة؛ سيتم اعتمادك قريباً وستستطيع إنشاء رحلات بعد الاعتماد.';

  @override
  String get driverProfileSubmitted =>
      'تم رفع بياناتك بنجاح. طلبك قيد المراجعة من الإدارة.';

  @override
  String get driverProfileStep2 => 'الخطوة 2 من 2: المعلومات الإضافية';

  @override
  String get profilePhotoRequired => 'الصورة الشخصية *';

  @override
  String get vehicleType => 'نوع المركبة';

  @override
  String get vehicleTypeRequired => 'نوع المركبة *';

  @override
  String get vehicleTypeValidation => 'يرجى اختيار نوع المركبة';

  @override
  String get vehiclePlateRequiredLabel => 'رقم اللوحة *';

  @override
  String get vehicleModelRequiredLabel => 'موديل السيارة *';

  @override
  String get vehicleSeatsRequiredLabel => 'عدد المقاعد *';

  @override
  String get vehicleSeatsInvalid =>
      'عدد المقاعد يجب أن يكون رقم صحيح أكبر من 0';

  @override
  String get driverLicenseRequired => 'رخصة القيادة *';

  @override
  String get vehicleLicenseRequired => 'رخصة المركبة *';

  @override
  String get carPhotoRequired => 'صورة السيارة *';

  @override
  String uploadFileLabel(String title) {
    return 'رفع $title';
  }

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get firstNameHint => 'أحمد';

  @override
  String get lastName => 'اسم العائلة';

  @override
  String get lastNameHint => 'علي';

  @override
  String get driverSignUpVerifyButton => 'تحقق من رقم الهاتف وأنشئ كلمة السر';

  @override
  String get driverSignUpStep1 => 'الخطوة 1 من 3: المعلومات الأساسية والتحقق';

  @override
  String get backToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get otpResent => 'تم إرسال رمز التحقق مرة أخرى';

  @override
  String get otpSentToPhone => 'تم إرسال الرمز المكون من 6 أرقام إلى\n';

  @override
  String otpDigitLabel(int index) {
    return 'رمز التحقق $index';
  }

  @override
  String get enterPhoneToConfirm => 'أدخل رقم هاتفك للتأكيد';

  @override
  String get enterYourPhone => 'أدخل رقم هاتفك';

  @override
  String get devModeDirectLogin => 'وضع التطوير: سيتم الدخول مباشرة';

  @override
  String get otpWillBeSentViaSms => 'سنرسل لك رمز التحقق عبر SMS';

  @override
  String get enterAction => 'دخول';

  @override
  String get emailHint => 'example@email.com';

  @override
  String selectedRoleLabel(String role) {
    return 'لقد اخترت دور: $role';
  }

  @override
  String get passengerDescription => 'ابحث عن رحلات واحجز مقعدك';

  @override
  String get tripOwnerDescription => 'أنشئ رحلات واعرض مقاعدك';

  @override
  String get tripOwnerNote =>
      'ستحتاج إلى إكمال بيانات المركبة والوثائق ليتم اعتماد حسابك كسائق.';

  @override
  String get saveAndComplete => 'حفظ وإكمال';

  @override
  String get profileSetupSubtitle => 'أكمل بياناتك للمتابعة';

  @override
  String get otpTooManyAttempts => 'محاولات كثيرة جداً. يرجى طلب رمز جديد.';

  @override
  String get otpExpired => 'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.';

  @override
  String get requestNewCode => 'طلب رمز جديد';

  @override
  String get newOtpSent => 'تم إرسال رمز تحقق جديد';

  @override
  String waitBeforeResend(int seconds) {
    return 'يرجى الانتظار $seconds ثانية قبل طلب رمز جديد';
  }

  @override
  String get otpSentToYourPhone => 'تم إرسال رمز التحقق إلى رقم هاتفك';

  @override
  String get newPasswordRequired => 'يرجى إدخال كلمة مرور جديدة';

  @override
  String get yourProfile => 'ملفك الشخصي';

  @override
  String get notSpecified => 'غير محدد';

  @override
  String get viewProfile => 'عرض الملف الشخصي';

  @override
  String get userFallback => 'المستخدم';

  @override
  String get browseTrips => 'تصفح الرحلات';

  @override
  String get myWallet => 'محفظتي';

  @override
  String get pendingChargesTitle => 'الرسوم المستحقة';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get locationServicesDisabledTitle => 'خدمات الموقع معطلة';

  @override
  String get locationServicesDisabledMessage =>
      'يرجى تفعيل خدمات الموقع (GPS) لتتمكن من استخدام التطبيق ومشاركة موقعك.';

  @override
  String get enable => 'تفعيل';

  @override
  String get locationPermissionRequiredTitle => 'تصريح الموقع مطلوب';

  @override
  String get locationPermissionRequiredMessage =>
      'يحتاج التطبيق إلى تصريح الوصول للموقع لتتمكن من مشاركة رحلاتك.';

  @override
  String get grantPermission => 'منح التصريح';

  @override
  String get later => 'لاحقاً';

  @override
  String get chooseYourLocation => 'اختر موقعك';

  @override
  String get defaultCityName => 'عمّان';

  @override
  String get defaultCityAddress => 'عمّان، الأردن';

  @override
  String get myBookings => 'حجوزاتي';

  @override
  String get profileTabLabel => 'البروفايل';

  @override
  String get createNewTrip => 'إنشاء رحلة جديدة';

  @override
  String get mustSignIn => 'يجب تسجيل الدخول';

  @override
  String get noBookingsCurrently => 'لا توجد حجوزات حالياً';

  @override
  String get upcoming => 'قادمة';

  @override
  String get past => 'سابقة';

  @override
  String get cannotCancel => 'لا يمكن الإلغاء';

  @override
  String cannotCancelWithin12Hours(String departure) {
    return 'لا يمكن إلغاء الحجز خلال 12 ساعة من موعد الرحلة.\n\nموعد الرحلة: $departure';
  }

  @override
  String get unknown => 'غير معروف';

  @override
  String get confirmCancelBooking => 'تأكيد إلغاء الحجز';

  @override
  String get cancellationFeeNotice =>
      'سيتم خصم رسوم إلغاء بنسبة 5% من قيمة حجزك، وستُطبَّق على رحلتك القادمة.';

  @override
  String get confirmCancelBookingQuestion => 'هل أنت متأكد من إلغاء الحجز؟';

  @override
  String get goBack => 'تراجع';

  @override
  String get cancelBooking => 'إلغاء الحجز';

  @override
  String get bookingCancelledSuccess => 'تم إلغاء الحجز بنجاح';

  @override
  String get noTripsTitle => 'لا توجد رحلات';

  @override
  String get noTripsSubtitle =>
      'ابدأ بإنشاء رحلة جديدة وشارك\nرحلتك مع الآخرين';

  @override
  String get errorOccurred => 'حدث خطأ';

  @override
  String get openMenu => 'فتح القائمة';

  @override
  String get sideMenu => 'القائمة الجانبية';

  @override
  String get whereWillYourTripStart => 'إلى أين ستنطلق رحلتك؟';

  @override
  String get createTripCtaSubtitle => 'ابدأ رحلتك واستقبل الحجوزات من الركاب';

  @override
  String get currentLocation => 'موقعك الحالي';

  @override
  String get determiningLocation => 'جاري تحديد الموقع...';

  @override
  String get detectLocationAutomatically => 'تحديد الموقع تلقائياً';

  @override
  String get chooseLocationManually => 'اختيار الموقع يدوياً';

  @override
  String get myActiveTrips => 'رحلاتي القائمة';

  @override
  String get errorLoadingTrips => 'خطأ في تحميل الرحلات';

  @override
  String get noActiveTripsTitle => 'لا توجد رحلات قائمة';

  @override
  String get noActiveTripsSubtitle => 'ابدأ بإنشاء رحلة لتظهر هنا.';

  @override
  String get whereDoYouWantToGo => 'إلى أين تريد الذهاب؟';

  @override
  String get haveAPlaceInMind => 'هل لديك مكان في الاعتبار؟';

  @override
  String get nearbyTrips => 'رحلات قريبة منك';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get noNearbyTripsTitle => 'لا توجد رحلات قريبة';

  @override
  String get noNearbyTripsSubtitle => 'جرب تغيير موقعك أو عرض جميع الرحلات';

  @override
  String get viewAllTrips => 'عرض جميع الرحلات';

  @override
  String showMoreTrips(int count) {
    return 'عرض $count رحلة أخرى';
  }

  @override
  String get dataUpdated => 'تم تحديث البيانات';

  @override
  String dataUpdateFailed(String error) {
    return 'تعذر تحديث البيانات: $error';
  }

  @override
  String get refreshData => 'تحديث البيانات';

  @override
  String get driverDataApproved => 'تمت الموافقة على بياناتك';

  @override
  String get driverAccountUnderReview => 'حسابك كسائق قيد المراجعة';

  @override
  String get driverApprovedDescription =>
      'يمكنك إنشاء رحلات وإدارتها من تبويب \"رحلاتي\".';

  @override
  String get driverPendingDescription =>
      'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً الحجز كراكب.';

  @override
  String get checkVerificationStatus => 'معرفة حالة التوثيق';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get helpAndSupport => 'المساعدة والدعم';

  @override
  String get searchForTrip => 'بحث عن رحلة';

  @override
  String get showAllAvailableTrips => 'عرض جميع الرحلات المتاحة';

  @override
  String get showTrips => 'عرض الرحلات';

  @override
  String get completedTrip => 'رحلة منتهية';

  @override
  String get tripUnavailable => 'رحلة غير متاحة';

  @override
  String get bookingStatusPending => 'قيد الانتظار';

  @override
  String get bookingStatusConfirmed => 'مؤكد';

  @override
  String get bookingStatusCancelled => 'ملغي';

  @override
  String get dateLabel => 'التاريخ';

  @override
  String get timeLabel => 'الوقت';

  @override
  String get seatLabel => 'المقعد';

  @override
  String get chat => 'دردشة';

  @override
  String get call => 'اتصال';

  @override
  String distanceKm(String distance) {
    return '$distance كم';
  }

  @override
  String get tripStatusActive => 'نشطة';

  @override
  String get tripStatusFullyBooked => 'مكتملة الحجز';

  @override
  String get tripStatusInProgress => 'قيد التنفيذ';

  @override
  String get tripStatusHidden => 'مخفية';

  @override
  String seatsAvailable(int count) {
    return '$count متاح';
  }

  @override
  String get feePaid => 'مدفوعة';

  @override
  String get feeDue => 'مستحقة';

  @override
  String get tripStartDeadlinePassed =>
      'انتهى وقت بدء الرحلة (لم يبدأ السائق ضمن المهلة)';

  @override
  String get homeGreeting => 'مرحباً';

  @override
  String get defaultUserName => 'المستخدم';

  @override
  String get homeStartTripTitle => 'ابدأ رحلتك';

  @override
  String get homeStartTripSubtitle => 'أنشئ رحلة جديدة واكسب المال';

  @override
  String get homeCreateTripButton => 'إنشاء رحلة جديدة';

  @override
  String get userInfoTitle => 'معلومات المستخدم';

  @override
  String get roleLabel => 'الدور';

  @override
  String get statisticsTitle => 'إحصائيات';

  @override
  String get tripsStatLabel => 'الرحلات';

  @override
  String get passengersStatLabel => 'الركاب';

  @override
  String get editProfilePhoto => 'تعديل الصورة الشخصية';

  @override
  String get phoneNotVerified => 'رقم الهاتف غير مؤكد';

  @override
  String get editProfileMenuItem => 'تعديل الملف الشخصي';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get locationUnavailable => 'تعذر الحصول على الموقع.';

  @override
  String get locationServicesDisabled => 'خدمات الموقع معطلة.';

  @override
  String get enableAction => 'تفعيل';

  @override
  String get locationPermissionRequired => 'تصريح الموقع مطلوب.';

  @override
  String get grantAction => 'منح';

  @override
  String get locationPermissionPermanentlyDenied => 'تم رفض التصريح بشكل دائم.';

  @override
  String filterFromValue(String value) {
    return 'من: $value';
  }

  @override
  String filterToValue(String value) {
    return 'إلى: $value';
  }

  @override
  String filterCityValue(String value) {
    return 'مدينة: $value';
  }

  @override
  String filterDateValue(String value) {
    return 'تاريخ: $value';
  }

  @override
  String get filterSortNewest => 'ترتيب: الأحدث';

  @override
  String get availableTripsTitle => 'الرحلات المتاحة';

  @override
  String get signInToViewTrips => 'يجب تسجيل الدخول لعرض الرحلات';

  @override
  String get changeLocation => 'تغيير الموقع';

  @override
  String get filterAndSort => 'تصفية وترتيب';

  @override
  String get currentLocationLabel => 'موقعك الحالي:';

  @override
  String get detectingLocation => 'جاري تحديد الموقع...';

  @override
  String get preferredTrips => 'رحلات مفضلة';

  @override
  String get allTrips => 'كل الرحلات';

  @override
  String errorWithDetail(String detail) {
    return 'خطأ: $detail';
  }

  @override
  String get enableLocationForTrips => 'فعّل الموقع لعرض هذه الرحلات';

  @override
  String get noTripsAvailable => 'لا توجد رحلات متاحة';

  @override
  String get chooseLocationThenRetry => 'اختر موقعك الحالي ثم أعد المحاولة';

  @override
  String get tryChangingFilterOrLocation => 'جرب تغيير الفلتر أو الموقع';

  @override
  String get refreshTripsList => 'تحديث قائمة الرحلات';

  @override
  String get refresh => 'تحديث';

  @override
  String get filterAndSortTrips => 'تصفية وترتيب الرحلات';

  @override
  String get chooseDeparturePoint => 'اختر نقطة الانطلاق';

  @override
  String get chooseDestination => 'اختر الوجهة';

  @override
  String get cityLabel => 'المدينة';

  @override
  String get searchByCityName => 'ابحث باسم المدينة';

  @override
  String get chooseDate => 'اختر التاريخ';

  @override
  String get sortLabel => 'الترتيب';

  @override
  String get sortNearest => 'الأقرب';

  @override
  String get sortNewest => 'الأحدث';

  @override
  String get apply => 'تطبيق';

  @override
  String tripDetailsFromTo(String from, String to) {
    return 'تفاصيل الرحلة من $from إلى $to';
  }

  @override
  String get liveDriverLocation => 'موقع السائق المباشر';

  @override
  String get tripNotFound => 'الرحلة غير موجودة';

  @override
  String get tripRouteTitle => 'مسار الرحلة';

  @override
  String get viewRouteOnMap => 'عرض المسار على الخريطة';

  @override
  String get tripDistanceLabel => 'مسافة الرحلة';

  @override
  String distanceKmValue(String value) {
    return '$value كم';
  }

  @override
  String get departureTimeLabel => 'وقت الانطلاق';

  @override
  String seatsCountOfTotal(int available, int total) {
    return '$available من $total';
  }

  @override
  String get seatLayoutLabel => 'تخطيط المقاعد';

  @override
  String get preventGenderMixingLabel => 'منع الاختلاط';

  @override
  String get enabledValue => 'مفعل';

  @override
  String get driverInfoTitle => 'معلومات السائق';

  @override
  String get carImageTitle => 'صورة السيارة';

  @override
  String get noSeatsAvailable => 'لا توجد مقاعد متاحة';

  @override
  String get chatLabel => 'المحادثة';

  @override
  String get chatNotEnabledYet =>
      'لم يتم تفعيل التواصل بعد. يجب على السائق دفع رسوم التواصل أولاً.';

  @override
  String get rateLabel => 'تقييم';

  @override
  String get alreadyRatedTrip => 'لقد قمت بتقييم هذه الرحلة بالفعل';

  @override
  String get thanksForRating => 'شكراً لتقييمك!';

  @override
  String get canRateAfterTripEnds => 'يمكنك التقييم بعد انتهاء الرحلة';

  @override
  String get seatNotSelectable =>
      'لا يمكن اختيار هذا المقعد، قد يكون محجوزًا أو غير مناسب حسب قواعد الرحلة.';

  @override
  String get signInRequired => 'يجب تسجيل الدخول';

  @override
  String get tripInfoTitle => 'معلومات الرحلة';

  @override
  String fromValue(String value) {
    return 'من: $value';
  }

  @override
  String toValue(String value) {
    return 'إلى: $value';
  }

  @override
  String pricePerSeatValue(String price, String currency) {
    return 'السعر: $price $currency لكل مقعد';
  }

  @override
  String get selectOneOrMoreSeats =>
      'يمكنك اختيار مقعد واحد أو أكثر حسب المقاعد المتاحة.';

  @override
  String get enterPassengerDataAfterSeats =>
      'بعد اختيار المقاعد ستدخل بيانات كل مسافر قبل إرسال طلب الحجز.';

  @override
  String get appShareWalletNotice =>
      'سيتم خصم حصة التطبيق من محفظتك عند إرسال الحجز. تأكد من كفاية الرصيد من صفحة محفظتي.';

  @override
  String selectedSeatsValue(String seats) {
    return 'المقاعد المحددة: $seats';
  }

  @override
  String get continueToPassengerData => 'متابعة إدخال بيانات المسافرين';

  @override
  String get continueToPassengerDataTooltip =>
      'متابعة لإدخال بيانات المسافرين وإرسال طلب الحجز';

  @override
  String get continueBookOneSeat => 'متابعة لحجز مقعد واحد';

  @override
  String continueBookSeats(int count) {
    return 'متابعة لحجز $count مقاعد';
  }

  @override
  String get bookingRequestSentNotice =>
      'سيتم إرسال طلب الحجز للسائق بعد تأكيد بيانات المسافرين. انتظر موافقة السائق قبل اعتماد الحجز.';

  @override
  String get departurePointTitle => 'نقطة الانطلاق';

  @override
  String get arrivalPointTitle => 'نقطة الوصول';

  @override
  String get destinationTitle => 'الوجهة';

  @override
  String get driverLocationTitle => 'موقع السائق';

  @override
  String get viewFullRoute => 'عرض المسار بالكامل';

  @override
  String get loadingRouteLabel => 'جاري تحميل المسار';

  @override
  String get loadingRoute => 'جاري تحميل المسار...';

  @override
  String get stopFollowingDriver => 'إيقاف تتبع السائق';

  @override
  String get followDriver => 'تتبع السائق';

  @override
  String get liveTrackingEnabled => 'التتبع المباشر مفعل';

  @override
  String get bookingRequestSentWaitConfirm =>
      'تم إرسال طلب الحجز. انتظر تأكيد السائق.';

  @override
  String get autoPickTitle => 'اختيار تلقائي';

  @override
  String get passengerDataTitle => 'بيانات المسافرين';

  @override
  String get seatCountLabel => 'عدد المقاعد';

  @override
  String get mainBookerLabel => 'الحاجز الرئيسي';

  @override
  String companionLabel(int index) {
    return 'مرافق $index';
  }

  @override
  String get sharePhoneWithDriver => 'مشاركة رقم الهاتف مع السائق';

  @override
  String get sharePhoneWithDriverSubtitle => 'السماح للسائق برؤية رقمك للتواصل';

  @override
  String get sendBookingRequest => 'إرسال طلب الحجز';

  @override
  String get seatWord => 'مقعد';

  @override
  String get chatClosedForSending =>
      'انتهت الرحلة، ولا يمكن إرسال رسائل جديدة.';

  @override
  String get errorMustSignInFirst => 'يجب تسجيل الدخول أولاً';

  @override
  String chatLoadError(String error) {
    return 'خطأ في تحميل المحادثة: $error';
  }

  @override
  String chatTitleWithDriver(String driverName) {
    return 'محادثة - $driverName';
  }

  @override
  String get chatLoadErrorShort => 'خطأ في تحميل المحادثة';

  @override
  String errorWithMessage(String error) {
    return 'خطأ: $error';
  }

  @override
  String get chatNoMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get chatStartConversationNow => 'ابدأ المحادثة الآن';

  @override
  String get chatTypeMessageLabel => 'اكتب رسالة';

  @override
  String get chatTypeMessageHint => 'اكتب رسالة...';

  @override
  String get chatSendMessageTooltip => 'إرسال الرسالة';

  @override
  String get complaintCategorySafety => 'سلامة';

  @override
  String get complaintCategoryPayment => 'مدفوعات';

  @override
  String get complaintCategoryVehicleCondition => 'حالة المركبة';

  @override
  String get complaintCategoryDriverBehavior => 'سلوك السائق';

  @override
  String get complaintCategoryAppIssue => 'مشكلة في التطبيق';

  @override
  String get complaintCategoryOther => 'أخرى';

  @override
  String get complaintSubmittedSuccessMessage =>
      'تم إرسال شكواك بنجاح. سنراجعها في أقرب وقت.';

  @override
  String get complaintHeroTitle => 'أخبرنا بما حدث';

  @override
  String get complaintHeroSubtitle =>
      'شكواك تساعدنا على تحسين الخدمة وضمان سلامة الجميع.';

  @override
  String get complaintTypeLabel => 'نوع الشكوى';

  @override
  String get complaintProblemDescriptionLabel => 'وصف المشكلة';

  @override
  String get complaintDescriptionHint =>
      'اشرح المشكلة بتفصيل كافٍ لمساعدتنا في مراجعتها…';

  @override
  String get complaintDescriptionRequired => 'يرجى كتابة وصف للمشكلة';

  @override
  String get complaintDescriptionTooShort =>
      'الوصف قصير جداً (10 أحرف على الأقل)';

  @override
  String get walletMyWallet => 'محفظتي';

  @override
  String get walletTopUpDescription =>
      'تُستخدم لدفع تكلفة الحجز عند تفعيل الدفع من المحفظة. الشحن بالدينار الأردني (JOD) عبر CliQ أو تحويل يدوي مع إثبات؛ يُضاف الرصيد بعد التأكد أو موافقة الإدارة حسب الطريقة.';

  @override
  String get walletTransactionHistory => 'سجل الحركات';

  @override
  String get walletTopUp => 'شحن';

  @override
  String get walletTopUpSemantics => 'شحن المحفظة';

  @override
  String get walletNoTransactionsYet => 'لا توجد حركات بعد';

  @override
  String get walletPendingChargesTitle => 'الرسوم المستحقة';

  @override
  String get walletPendingChargesSubtitle =>
      'عرض الغرامات والرسوم المعلّقة وشحن المحفظة';

  @override
  String get walletBalanceLabel => 'رصيد المحفظة';

  @override
  String get walletAccountInactive => 'الحساب غير مفعّل — تواصل مع الدعم';

  @override
  String get walletTxTopup => 'شحن';

  @override
  String get walletTxTripPayment => 'دفع رحلة';

  @override
  String get walletTxTripDebit => 'خصم رحلة';

  @override
  String get walletTxRefund => 'استرداد';

  @override
  String get walletTxPayout => 'سحب أرباح';

  @override
  String get walletTxAdjustment => 'تعديل رصيد';

  @override
  String get walletTxHold => 'حجز مبلغ';

  @override
  String get walletTxReleaseHold => 'إلغاء حجز';

  @override
  String get ratingPleaseSelectRating => 'يرجى اختيار تقييم';

  @override
  String get ratingAlreadyRated => 'لقد قمت بتقييم هذه الرحلة بالفعل';

  @override
  String get ratingSubmittedSuccess => 'تم إرسال التقييم بنجاح';

  @override
  String get ratingTripTitle => 'تقييم الرحلة';

  @override
  String get ratingHowWasExperience => 'كيف كانت تجربتك مع السائق؟';

  @override
  String get ratingCommentLabel => 'حقل تعليق';

  @override
  String get ratingCommentHint => 'شاركنا رأيك في الرحلة';

  @override
  String get ratingCommentOptional => 'تعليق (اختياري)';

  @override
  String get ratingCommentHintEllipsis => 'شاركنا رأيك في الرحلة...';

  @override
  String get ratingSubmitButton => 'إرسال التقييم';

  @override
  String get ratingLabelVeryBad => 'سيء جداً';

  @override
  String get ratingLabelBad => 'سيء';

  @override
  String get ratingLabelAverage => 'متوسط';

  @override
  String get ratingLabelGood => 'جيد';

  @override
  String get ratingLabelExcellent => 'ممتاز';

  @override
  String get refundSubmittedSuccess =>
      'تم تسجيل طلب الاسترداد. سيتم تحويلك إلى WhatsApp لاستكمال الإجراء.';

  @override
  String get refundRequestScreenTitle => 'طلب استرداد المبلغ';

  @override
  String get refundHeroTitle => 'استرداد رسوم الحجز';

  @override
  String refundTripRef(String tripRef) {
    return 'الرحلة: $tripRef';
  }

  @override
  String get refundContactViaWhatsApp =>
      'سيتواصل معك فريقنا عبر WhatsApp لإتمام الإجراء.';

  @override
  String get refundReasonLabel => 'سبب طلب الاسترداد';

  @override
  String get refundReasonHint => 'اشرح سبب طلبك لاسترداد المبلغ بإيجاز…';

  @override
  String get refundReasonRequired => 'يرجى كتابة سبب الطلب';

  @override
  String get refundReasonTooShort => 'السبب قصير جداً (10 أحرف على الأقل)';

  @override
  String get refundWhatsAppNote =>
      'بعد الإرسال، ستُفتح محادثة WhatsApp مع فريق الدعم لإتمام إجراء الاسترداد.';

  @override
  String get refundSubmitButton => 'إرسال الطلب';

  @override
  String get chatClosedTripEnded => 'انتهت الرحلة، ولا يمكن إرسال رسائل جديدة.';

  @override
  String get mustSignInFirst => 'يجب تسجيل الدخول أولاً';

  @override
  String get chatCreateFailed => 'لا يمكن إنشاء المحادثة';

  @override
  String get tripChatTitle => 'محادثة الرحلة';

  @override
  String chatWithPerson(String name) {
    return 'محادثة مع $name';
  }

  @override
  String get noMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get startChatNow => 'ابدأ المحادثة الآن';

  @override
  String get typeMessage => 'اكتب رسالة';

  @override
  String get typeMessageHint => 'اكتب رسالة...';

  @override
  String get sendMessage => 'إرسال الرسالة';

  @override
  String get send => 'إرسال';

  @override
  String get selectOriginPoint => 'اختر نقطة الانطلاق';

  @override
  String get selectDestination => 'اختر الوجهة';

  @override
  String get completeLocationAndTimeData =>
      'الرجاء إكمال بيانات المواقع والوقت';

  @override
  String get departureTimeMustBeFuture =>
      'وقت الانطلاق يجب أن يكون في المستقبل';

  @override
  String get userNotSignedIn => 'المستخدم غير مسجل دخول';

  @override
  String get tripCreatedSuccess => 'تم إنشاء الرحلة بنجاح';

  @override
  String get tripCreateFailed => 'فشل إنشاء الرحلة';

  @override
  String get weekdaySun => 'أحد';

  @override
  String get weekdayMon => 'اثنين';

  @override
  String get weekdayTue => 'ثلاثاء';

  @override
  String get weekdayWed => 'أربعاء';

  @override
  String get weekdayThu => 'خميس';

  @override
  String get weekdayFri => 'جمعة';

  @override
  String get weekdaySat => 'سبت';

  @override
  String get driverAccountUnderReviewBody =>
      'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً تصفح الرحلات والحجز كراكب.';

  @override
  String get backToHome => 'العودة للرئيسية';

  @override
  String get createNewTripTitle => 'إنشاء رحلة جديدة';

  @override
  String get backLabel => 'رجوع';

  @override
  String get shareYourNextTrip => 'شارك رحلتك القادمة';

  @override
  String get createTripHeaderSubtitle =>
      'قم بتحديد وجهتك ووقت الانطلاق لتبدأ مشاركة رحلتك مع الركاب.';

  @override
  String get tripRoute => 'مسار الرحلة';

  @override
  String get whereAreYouNow => 'أين أنت الآن؟';

  @override
  String get whereIsYourDestination => 'أين وجهتك؟';

  @override
  String get departureAndPriceDetails => 'تفاصيل الانطلاق والسعر';

  @override
  String get pricePerSeatHint => 'السعر لكل مقعد';

  @override
  String get enterPrice => 'أدخل السعر';

  @override
  String get enterValidNumber => 'أدخل رقماً صحيحاً';

  @override
  String seatsCount(int count) {
    return '$count مقعد';
  }

  @override
  String get seatLayoutFromSettings =>
      'تخطيط المقاعد ومنع الاختلاط مأخوذان من إعدادات سيارتك ويُطبَّقان على كل رحلاتك.';

  @override
  String get noSeatLayoutSet =>
      'لم تضبط بعد تخطيط مقاعد لسيارتك — سيتم استخدام تخطيط افتراضي. اضبطه من إعدادات السيارة لتجربة أدق.';

  @override
  String get editVehicleSettings => 'تعديل إعدادات السيارة';

  @override
  String get confirmAndPublishTrip => 'تأكيد ونشر الرحلة';

  @override
  String get stopsLabel => 'محطات التوقف';

  @override
  String get optionalLabel => 'اختياري';

  @override
  String get addStop => 'إضافة محطة توقف';

  @override
  String get stopsHint => 'أضف حتى 5 محطات توقف وسيطة على طول الطريق.';

  @override
  String deleteStopNumber(int number) {
    return 'حذف المحطة $number';
  }

  @override
  String selectStopNumber(int number) {
    return 'اختر محطة توقف $number';
  }

  @override
  String get notesForPassengers => 'ملاحظات للركاب';

  @override
  String get tripNotesHint =>
      'مثال: التوقف في صيدلية البتراء، لا تأخر أكثر من 5 دقائق...';

  @override
  String get tripRecurrence => 'تكرار الرحلة';

  @override
  String enableTripRecurrenceSemantic(String state) {
    return 'تفعيل تكرار الرحلة: $state';
  }

  @override
  String get recurrenceStateEnabled => 'مفعّل';

  @override
  String get recurrenceStateDisabled => 'معطّل';

  @override
  String get recurrenceDisabledHint =>
      'فعّل هذا الخيار لجدولة الرحلة بشكل تلقائي (يومياً أو أسبوعياً).';

  @override
  String get recurrenceDaily => 'يومياً';

  @override
  String get recurrenceWeekly => 'أسبوعياً';

  @override
  String get recurrenceDaysLabel => 'أيام التكرار';

  @override
  String weekdaySelectedSemantic(String day) {
    return '$day (محدد)';
  }

  @override
  String get recurrenceUntilHint => 'تاريخ انتهاء التكرار (اختياري)';

  @override
  String get recurrenceUntilHelp => 'تاريخ انتهاء التكرار';

  @override
  String get uploadCarImageFailed => 'فشل رفع صورة السيارة';

  @override
  String get tripUpdatedSuccess => 'تم تحديث الرحلة بنجاح';

  @override
  String get tripUpdateFailed => 'فشل تحديث الرحلة';

  @override
  String get editTripScreenTitle => 'تعديل الرحلة';

  @override
  String get editYourTrip => 'تعديل رحلتك';

  @override
  String get updateTripInfo => 'قم بتحديث معلومات الرحلة';

  @override
  String get tripDetailsSection => 'تفاصيل الرحلة';

  @override
  String get originPointLabel => 'نقطة الانطلاق';

  @override
  String get originExampleHint => 'مثال: عمّان';

  @override
  String get destinationLabel => 'الوجهة';

  @override
  String get destinationExampleHint => 'مثال: الإسكندرية';

  @override
  String get pickDateAndTime => 'اختر التاريخ والوقت';

  @override
  String get priceExampleHint => 'مثال: 100';

  @override
  String get selectOriginValidator => 'يرجى اختيار نقطة الانطلاق';

  @override
  String get selectDestinationValidator => 'يرجى اختيار الوجهة';

  @override
  String get selectDepartureTimeValidator => 'يرجى اختيار وقت الانطلاق';

  @override
  String get enterPriceValidator => 'يرجى إدخال السعر';

  @override
  String get priceMustBeValidPositive => 'السعر يجب أن يكون رقم صحيح أكبر من 0';

  @override
  String get carImageSection => 'صورة السيارة';

  @override
  String get optionalParen => '(اختياري)';

  @override
  String get uploadCarImage => 'رفع صورة السيارة';

  @override
  String get tapToUploadCarImage => 'اضغط لرفع صورة السيارة';

  @override
  String get saveChanges => 'حفظ التعديلات';

  @override
  String get selectFromMap => 'اختيار من الخريطة';

  @override
  String get warningTitle => 'تحذير';

  @override
  String get pastDateWarningBody =>
      'أنت تختار تاريخ في الماضي. الرحلات في الماضي لن تظهر في نتائج البحث للركاب. هل تريد المتابعة؟';

  @override
  String bookedSeatsEditWarning(int count) {
    return 'هذه الرحلة تحتوي على $count مقعد محجوز. تعديل بعض المعلومات قد يؤثر على الحجوزات الموجودة. هل تريد المتابعة؟';
  }

  @override
  String get myTripsTitleLabel => 'رحلاتي';

  @override
  String get driverAccountUnderReviewTrips =>
      'حسابك كسائق قيد المراجعة. لا يمكنك إنشاء أو إدارة رحلات حتى تتم الموافقة عليه.';

  @override
  String get mustBeApprovedDriver => 'يجب أن تكون سائقاً معتمداً لعرض الرحلات.';

  @override
  String get tabActive => 'نشطة';

  @override
  String get tabHidden => 'مخفية';

  @override
  String get tabCompleted => 'مكتملة';

  @override
  String get retryLabel => 'إعادة المحاولة';

  @override
  String get noActiveTrips => 'لا توجد رحلات نشطة';

  @override
  String get noHiddenTrips => 'لا توجد رحلات مخفية';

  @override
  String get noCompletedTrips => 'لا توجد رحلات مكتملة';

  @override
  String get createTripShort => 'إنشاء رحلة';

  @override
  String get newTrip => 'رحلة جديدة';

  @override
  String get createNewTripSemantic => 'إنشاء رحلة جديدة';

  @override
  String get tripFeeInvoiceTitle => 'فاتورة رسوم الرحلة';

  @override
  String get seatPrice => 'سعر المقعد';

  @override
  String get seatsCountLabel => 'عدد المقاعد';

  @override
  String get feePercentage => 'نسبة الرسوم';

  @override
  String get totalLabel => 'الإجمالي';

  @override
  String get tripFeeDeductExplanation =>
      'سيتم خصم الرسوم من محفظتك وفتح بيانات ركاب هذه الرحلة. لا يتم تغيير عدد المقاعد أو الحجوزات.';

  @override
  String get payFees => 'دفع الرسوم';

  @override
  String get tripFeePaidSuccess => 'تم دفع رسوم الرحلة بنجاح';

  @override
  String get payingInProgress => 'جاري الدفع...';

  @override
  String get unknownLocation => 'موقع غير معروف';

  @override
  String tripFromToSemantic(String from, String to) {
    return 'رحلة من $from إلى $to';
  }

  @override
  String get statusActive => 'نشطة';

  @override
  String get statusDraft => 'مسودة';

  @override
  String get statusFullyBooked => 'مكتملة الحجز';

  @override
  String get statusInProgress => 'قيد التنفيذ';

  @override
  String get statusHidden => 'مخفية';

  @override
  String get statusCompleted => 'مكتملة';

  @override
  String get statusCancelled => 'ملغاة';

  @override
  String get statusUnknown => 'غير معروف';

  @override
  String get fromShort => 'من';

  @override
  String get toShort => 'إلى';

  @override
  String get perSeatSuffix => '/ مقعد';

  @override
  String get seatsWord => 'مقاعد';

  @override
  String get tripFeePaidLabel => 'رسوم الرحلة مدفوعة';

  @override
  String get passengerDetailsTitle => 'تفاصيل الراكب';

  @override
  String seatLabelWithValue(String seat) {
    return 'مقعد $seat';
  }

  @override
  String get phoneNumberLabel => 'رقم الهاتف';

  @override
  String privateChatWithSemantic(String name) {
    return 'محادثة خاصة مع $name';
  }

  @override
  String get privateChat => 'محادثة خاصة';

  @override
  String messagePerson(String name) {
    return 'مراسلة $name';
  }

  @override
  String get confirmFinePayment => 'تأكيد دفع الغرامة';

  @override
  String amountDue(String amount) {
    return 'المبلغ المستحق: $amount د.أ';
  }

  @override
  String currentWalletBalance(String amount) {
    return 'رصيد المحفظة الحالي: $amount د.أ';
  }

  @override
  String balanceAfterPayment(String amount) {
    return 'الرصيد بعد الدفع: $amount د.أ';
  }

  @override
  String get confirmAndPay => 'تأكيد ودفع';

  @override
  String get finePaidSuccess => 'تم دفع الغرامة من محفظتك بنجاح';

  @override
  String get finePartiallyPaid =>
      'تم دفع جزء من الرسوم، تبقى رصيد غير كافٍ للباقي';

  @override
  String get insufficientBalanceForFine => 'الرصيد غير كافٍ لدفع الرسوم';

  @override
  String get chargeKindDriverNoShow => 'عدم حضور السائق';

  @override
  String get chargeKindPassengerNoShow => 'عدم حضور الراكب';

  @override
  String get chargeKindLateCancellation => 'إلغاء الحجز';

  @override
  String get chargeStatusPending => 'مستحق';

  @override
  String get chargeStatusCollected => 'مدفوع';

  @override
  String get chargeStatusWaived => 'ملغى';

  @override
  String get noOutstandingCharges => 'لا توجد رسوم مستحقة';

  @override
  String get accountInGoodStanding => 'حسابك خالٍ من الرسوم.';

  @override
  String get cannotPublishUntilSettled => 'لا يمكنك نشر رحلة جديدة قبل التسوية';

  @override
  String totalDue(String amount) {
    return 'الإجمالي المستحق: $amount د.أ';
  }

  @override
  String walletBalanceAmount(String amount) {
    return 'رصيد المحفظة: $amount د.أ';
  }

  @override
  String get balanceEnoughForFine => 'رصيدك يكفي لدفع الغرامة من المحفظة.';

  @override
  String get balanceNotEnoughForFine =>
      'رصيدك غير كافٍ — اشحن المحفظة لتسوية الغرامة.';

  @override
  String get payFine => 'ادفع الغرامة';

  @override
  String get topUpWallet => 'شحن المحفظة';

  @override
  String amountAmount(String amount) {
    return 'المبلغ: $amount د.أ';
  }

  @override
  String get walletTitle => 'المحفظة';

  @override
  String get pleaseSignIn => 'يرجى تسجيل الدخول';

  @override
  String get txTypeTopup => 'شحن محفظة';

  @override
  String get txTypeTripPayment => 'دفع رحلة';

  @override
  String get txTypeTripDebit => 'رسوم رحلة';

  @override
  String get txTypeRefund => 'استرداد';

  @override
  String get txTypePayout => 'سحب أرباح';

  @override
  String get txTypeAdjustment => 'تعديل رصيد';

  @override
  String get txTypeHold => 'حجز مبلغ';

  @override
  String get txTypeReleaseHold => 'إلغاء حجز';

  @override
  String get transactionsLog => 'سجل الحركات';

  @override
  String get topUpShort => 'شحن';

  @override
  String get noTransactionsYet => 'لا توجد حركات بعد';

  @override
  String get pendingChargesShortcutTitle => 'الرسوم المستحقة';

  @override
  String get pendingChargesShortcutSubtitle =>
      'عرض الغرامات والرسوم المعلّقة وشحن المحفظة';

  @override
  String get freeTripUsed => 'تم استخدام الرحلة المجانية';

  @override
  String get freeTripAvailableDriver =>
      'لديك رحلة مجانية واحدة لفتح بيانات الركاب';

  @override
  String get vehicleSettingsTitle => 'إعدادات السيارة';

  @override
  String get seatLayoutSavedSuccess => 'تم حفظ تخطيط مقاعد السيارة';

  @override
  String get noVehicleRegistered => 'لم يتم تسجيل سيارة بعد';

  @override
  String get noVehicleRegisteredBody =>
      'تحتاج إلى تسجيل سيارتك من خلال إكمال ملف السائق قبل تخصيص تخطيط المقاعد.';

  @override
  String get vehicleDataSection => 'بيانات السيارة';

  @override
  String get vehicleModelLabel => 'الموديل';

  @override
  String get vehicleTypeLabel => 'النوع';

  @override
  String get vehiclePlateNumberLabel => 'رقم اللوحة';

  @override
  String get registeredSeatsCount => 'عدد المقاعد المسجل';

  @override
  String get seatLayoutSection => 'تخطيط المقاعد';

  @override
  String get seatLayoutUsedForAllTrips =>
      'هذا التخطيط يُستخدم لكل الرحلات التي تنشئها بهذه السيارة.';

  @override
  String get gridSystem => 'نظام الشبكة';

  @override
  String get customLayout => 'توزيع مخصص';

  @override
  String get rowsLabel => 'الصفوف';

  @override
  String get perRowLabel => 'بكل صف';

  @override
  String get setSeatsPerRow => 'حدد عدد المقاعد في كل صف:';

  @override
  String get nextToDriver => 'بجانب السائق';

  @override
  String rowNumberLabel(int number) {
    return 'الصف $number';
  }

  @override
  String get addNewRow => 'إضافة صف جديد';

  @override
  String get preventGenderMixing => 'منع الاختلاط';

  @override
  String get saveChangesVehicle => 'حفظ التغييرات';

  @override
  String get editingForActiveTripsOnly => 'التعديل متاح للرحلات النشطة فقط';

  @override
  String get bookedSeatsManagedByBookings =>
      'المقاعد المحجوزة عبر التطبيق تُدار من طلبات الحجز';

  @override
  String get openSeatTitle => 'فتح المقعد';

  @override
  String openSeatBody(int number) {
    return 'إلغاء قفل المقعد رقم $number ليصبح متاحاً للحجز في التطبيق؟';
  }

  @override
  String get openSeat => 'فتح المقعد';

  @override
  String get seatOpenedSuccess => 'تم فتح المقعد';

  @override
  String get lockSeatTitle => 'قفل المقعد';

  @override
  String lockSeatBody(int number) {
    return 'قفل المقعد رقم $number؟ لن يتمكن الركاب من حجزه في التطبيق (مثلاً إذا بيع خارج التطبيق).';
  }

  @override
  String get lockSeat => 'قفل';

  @override
  String get seatLockedSuccess => 'تم قفل المقعد';

  @override
  String get enableLocationRequired => 'تفعيل الموقع مطلوب';

  @override
  String get enableLocationBody =>
      'لازم تشغّل GPS وتسمح للتطبيق بالموقع عشان الركاب يشوفوك على الخريطة أثناء تأكيد التواجد والرحلة. مش هتقدر تكمّل من غير التتبع.';

  @override
  String get openLocationSettings => 'فتح إعدادات الموقع';

  @override
  String get checkAgain => 'تحقق مجددًا';

  @override
  String get tripManagementTitle => 'إدارة الرحلة';

  @override
  String get freeTripDiscountLabel => 'خصم الرحلة المجانية';

  @override
  String freeTripDiscountValue(String amount, String currency) {
    return '-$amount $currency (100%)';
  }

  @override
  String get freeTripAvailableExplanation =>
      'لديك رحلة مجانية متاحة. سيتم تطبيق خصم 100% ليصبح الإجمالي 0.';

  @override
  String get tripFeeFullExplanation =>
      'الدفع يخص رسوم الرحلة كاملة ولا يغير عدد المقاعد أو الحجوزات.';

  @override
  String get hideTripTitle => 'إخفاء الرحلة';

  @override
  String get hideTripConfirm => 'هل أنت متأكد من إخفاء هذه الرحلة؟';

  @override
  String get hideAction => 'إخفاء';

  @override
  String get tripHiddenSuccess => 'تم إخفاء الرحلة بنجاح';

  @override
  String get tripShownSuccess => 'تم إظهار الرحلة بنجاح';

  @override
  String get deleteTripTitle => 'حذف الرحلة';

  @override
  String get deleteTripConfirm =>
      'هل أنت متأكد من حذف هذه الرحلة؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteAction => 'حذف';

  @override
  String get tripDeletedSuccess => 'تم حذف الرحلة بنجاح';

  @override
  String get hideTripTooltip => 'إخفاء الرحلة';

  @override
  String get showTripTooltip => 'إظهار الرحلة';

  @override
  String get deleteTripTooltip => 'حذف الرحلة';

  @override
  String walletBalanceWithAmount(String amount, String currency) {
    return 'رصيد المحفظة: $amount $currency';
  }

  @override
  String get freeTripAvailableShort => 'رحلة مجانية متاحة';

  @override
  String get balanceFromPlatformWallet =>
      'الرصيد من محفظة المنصة (المحفظة الموحدة)';

  @override
  String get tripFeeLabel => 'رسوم الرحلة';

  @override
  String get tripFeeReady => 'فاتورة رسوم الرحلة جاهزة';

  @override
  String tripFeeBreakdownWithFreeTrip(
    int seats,
    String price,
    String currency,
    String amount,
  ) {
    return 'الرسوم: 5% × $seats مقاعد × $price $currency، خصم رحلة مجانية 100% = $amount $currency';
  }

  @override
  String tripFeeBreakdown(
    int seats,
    String price,
    String currency,
    String amount,
  ) {
    return '5% × $seats مقاعد × $price $currency = $amount $currency';
  }

  @override
  String get applyFreeTrip => 'تطبيق الرحلة المجانية';

  @override
  String pendingBookingsCard(int count) {
    return 'حجوزات قيد التأكيد ($count)';
  }

  @override
  String get confirmBookingUnlocksDetails =>
      'تأكيد الحجز يفتح بيانات الراكب (رحلة مجانية أو خصم من المحفظة مرة واحدة للرحلة)';

  @override
  String get passengerFallback => 'راكب';

  @override
  String seatLabelShort(String seat) {
    return 'مقعد $seat';
  }

  @override
  String get chatAvailableAfterFee =>
      'المحادثة والتواصل متاحان بعد دفع رسوم الرحلة';

  @override
  String get awaitingConfirmation => 'بانتظار التأكيد';

  @override
  String seatsWithValue(String seat) {
    return 'المقاعد: $seat';
  }

  @override
  String get pendingConfirmationBadge => 'قيد التأكيد';

  @override
  String get passengerDetailsButton => 'تفاصيل الراكب';

  @override
  String get confirmingInProgress => 'جاري التأكيد...';

  @override
  String get rejectingInProgress => 'جاري الرفض...';

  @override
  String get rejectAction => 'رفض';

  @override
  String get bookingRejected => 'تم رفض الحجز';

  @override
  String get bookedSeatsLabel => 'المقاعد المحجوزة';

  @override
  String ofCount(int count) {
    return 'من $count';
  }

  @override
  String get revenueLabel => 'الإيرادات';

  @override
  String get confirmArrivalTitle => 'تأكيد الوصول';

  @override
  String get confirmArrivalBody =>
      'هل وصلت إلى الوجهة؟ سيتم إنهاء الرحلة ولن يمكن التراجع.';

  @override
  String get yesArrived => 'نعم، وصلت';

  @override
  String get tripEndedSuccess => 'تم إنهاء الرحلة بنجاح.';

  @override
  String autoStartHours(int hours) {
    return 'ستبدأ الرحلة تلقائياً عند موعد الانطلاق (بعد ~$hours ساعة). لا حاجة للضغط على زر بدء.';
  }

  @override
  String autoStartMinutes(int minutes) {
    return 'ستبدأ الرحلة تلقائياً عند موعد الانطلاق (بعد ~$minutes دقيقة). لا حاجة للضغط على زر بدء.';
  }

  @override
  String get tripWillConvertSoon =>
      'سيتم تحويل الرحلة إلى «قيد التنفيذ» تلقائياً خلال لحظات.';

  @override
  String get startTripSection => 'بدء الرحلة';

  @override
  String get endTripSection => 'إنهاء الرحلة';

  @override
  String get endTripHint =>
      'اضغط «تم الوصول للوجهة» بعد إنزال الركاب لإنهاء الرحلة.';

  @override
  String get endingInProgress => 'جاري الإنهاء...';

  @override
  String get arrivedAtDestination => 'تم الوصول للوجهة';

  @override
  String get tripStatusLabel => 'حالة الرحلة';

  @override
  String get departureTimeDetailLabel => 'وقت الانطلاق';

  @override
  String get pricePerSeatLabel => 'السعر لكل مقعد';

  @override
  String get seatsDetailLabel => 'المقاعد';

  @override
  String seatsAvailableTotal(int available, int total) {
    return '$available متاح / $total إجمالي';
  }

  @override
  String get seatLayoutDetailLabel => 'تخطيط المقاعد';

  @override
  String get yesLabel => 'نعم';

  @override
  String get noLabel => 'لا';

  @override
  String get seatLayoutCardTitle => 'تخطيط المقاعد';

  @override
  String get seatLayoutLongPressHint =>
      'اضغط مطولاً على مقعد أخضر لقفله (حجز خارجي)، أو على مقعد مقفل لفتحه.';

  @override
  String get driverSeat => 'مقعد السائق';

  @override
  String get legendAvailable => 'متاح';

  @override
  String get legendLocked => 'مقفل';

  @override
  String get legendBookedMale => 'محجوز - رجل';

  @override
  String get legendBookedFemale => 'محجوز - أنثى';

  @override
  String passengersCardTitle(int count) {
    return 'الركاب ($count)';
  }

  @override
  String get anonymousPassenger => 'راكب مجهول';

  @override
  String get confirmedBadge => 'مؤكد';

  @override
  String get imageLoadFailed => 'فشل تحميل الصورة';

  @override
  String get quickActionsTitle => 'إجراءات سريعة';

  @override
  String get shareAction => 'مشاركة';

  @override
  String get shareFeatureComingSoon => 'قريباً: ميزة المشاركة';

  @override
  String get editAction => 'تعديل';

  @override
  String get carImage => 'صورة السيارة';

  @override
  String passengersWithCount(int count) {
    return 'الركاب ($count)';
  }

  @override
  String get passengerLabel => 'راكب';

  @override
  String seatNumberLabel(Object number) {
    return 'مقعد $number';
  }

  @override
  String get confirmedLabel => 'مؤكد';

  @override
  String pendingBookingsWithCount(int count) {
    return 'حجوزات قيد التأكيد ($count)';
  }

  @override
  String get pendingBookingHint =>
      'تأكيد الحجز يفتح بيانات الراكب (رحلة مجانية أو خصم من المحفظة مرة واحدة للرحلة)';

  @override
  String get pendingConfirmation => 'قيد التأكيد';

  @override
  String get confirmingBooking => 'جاري التأكيد...';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get bookedSeats => 'المقاعد المحجوزة';

  @override
  String ofTotalSeats(Object total) {
    return 'من $total';
  }

  @override
  String get revenue => 'الإيرادات';

  @override
  String get tripDetails => 'تفاصيل الرحلة';

  @override
  String get tripDistance => 'مسافة الرحلة';

  @override
  String distanceInKm(String distance) {
    return '$distance كم';
  }

  @override
  String get seatsLabel => 'المقاعد';

  @override
  String availableOfTotalSeats(Object available, Object total) {
    return '$available متاح / $total إجمالي';
  }

  @override
  String get seatLayout => 'تخطيط المقاعد';

  @override
  String get tripInfo => 'معلومات الرحلة';

  @override
  String get tripStatusCompleted => 'مكتملة';

  @override
  String get tripStatusUnknown => 'غير معروف';

  @override
  String get tripStatusTitle => 'حالة الرحلة';

  @override
  String get freeTripAvailable => 'رحلة مجانية متاحة';

  @override
  String markAllNotificationsRead(int count) {
    return 'قراءة جميع الإشعارات ($count غير مقروء)';
  }

  @override
  String get allNotificationsRead => 'تم قراءة جميع الإشعارات';

  @override
  String markAllReadCount(int count) {
    return 'قراءة الكل ($count)';
  }

  @override
  String get notificationsWillAppearHere => 'ستظهر الإشعارات هنا عند وصولها';

  @override
  String get manualPaymentTitle => 'الدفع اليدوي';

  @override
  String get completePayment => 'إتمام الدفع';

  @override
  String get walletType => 'نوع المحفظة';

  @override
  String get walletTypeOther => 'أخرى';

  @override
  String get jordan => 'الأردن';

  @override
  String get walletNumber => 'رقم المحفظة';

  @override
  String get walletNumberHint => 'مثال: 0791234567';

  @override
  String get walletNumberRequired => 'يرجى إدخال رقم المحفظة';

  @override
  String get walletNumberTooShort =>
      'رقم المحفظة يجب أن يكون 8 أرقام على الأقل';

  @override
  String get paymentProofImage => 'صورة إثبات الدفع';

  @override
  String get requiredLabel => '(مطلوب)';

  @override
  String get requiredWord => 'مطلوب';

  @override
  String get uploadPaymentProof => 'رفع صورة إثبات الدفع';

  @override
  String get tapToUploadPaymentProof => 'اضغط لرفع صورة إثبات الدفع';

  @override
  String get notesLabel => 'ملاحظات';

  @override
  String get additionalNotes => 'ملاحظات إضافية';

  @override
  String get additionalNotesHint => 'أي معلومات إضافية...';

  @override
  String get submitPaymentRequest => 'إرسال طلب الدفع';

  @override
  String get paymentTabAll => 'الكل';

  @override
  String get paymentStatusPending => 'قيد المراجعة';

  @override
  String get paymentStatusApproved => 'مقبولة';

  @override
  String get paymentStatusRejected => 'مرفوضة';

  @override
  String get paymentStatusRefunded => 'مستردة';

  @override
  String get errorLoadingData => 'حدث خطأ في تحميل البيانات';

  @override
  String get noPayments => 'لا توجد مدفوعات';

  @override
  String get paymentMethodWallet => 'محفظة التطبيق';

  @override
  String get paymentMethodManual => 'محفظة إلكترونية';

  @override
  String get paymentMethodCommunicationFee => 'رسوم تواصل';

  @override
  String get amountLabel => 'المبلغ';

  @override
  String get purposeLabel => 'الغرض';

  @override
  String get communicationUnlockFee => 'رسوم فتح التواصل';

  @override
  String get paymentMethodLabel => 'طريقة الدفع';

  @override
  String get profileUpdatedSuccess => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get gallery => 'المعرض';

  @override
  String get camera => 'الكاميرا';

  @override
  String get editProfileTitle => 'تعديل الملف الشخصي';

  @override
  String get chooseProfilePhoto => 'اختر صورة الملف الشخصي';

  @override
  String get changeProfilePhoto => 'تغيير صورة الملف الشخصي';

  @override
  String get hidePhoneFromDriver => 'إخفاء رقم الهاتف عن السائق';

  @override
  String get loadingVersion => 'جارٍ تحميل الإصدار...';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get aboutAppTagline =>
      'منصة تنقل ذكية تربط السائقين والركاب بتجربة عربية واضحة، سريعة، وموثوقة.';

  @override
  String get whatMakesVisionWaySpecial => 'ما الذي يميز VisionWay؟';

  @override
  String get aboutFeatureArabicFirst =>
      'واجهة عربية أولًا مع تجربة استخدام واضحة وسريعة.';

  @override
  String get aboutFeatureFlexibleManagement =>
      'إدارة مرنة للرحلات والحجوزات والتواصل بين السائق والراكب.';

  @override
  String get aboutFeatureTrustDesign =>
      'تصميم يركز على الثقة والبساطة وسهولة الوصول للمعلومات المهمة.';

  @override
  String get revokeDeviceTitle => 'إلغاء الجهاز';

  @override
  String get revokeDeviceMessage =>
      'هل أنت متأكد من إلغاء هذا الجهاز؟ ستحتاج إلى تسجيل الدخول مرة أخرى على هذا الجهاز.';

  @override
  String get deviceRevokedSuccess => 'تم إلغاء الجهاز بنجاح';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get noDevicesRegistered => 'لا توجد أجهزة مسجلة';

  @override
  String deviceLastSeen(String date) {
    return 'آخر نشاط: $date';
  }

  @override
  String get deviceCurrentBadge => 'الحالي';

  @override
  String get roleDriver => 'سائق';

  @override
  String get rolePassenger => 'راكب';

  @override
  String get manageDevices => 'إدارة الأجهزة';

  @override
  String get manageDevicesSubtitle => 'عرض وإلغاء الأجهزة المرتبطة بحسابك';

  @override
  String get enterNewPassword => 'يرجى إدخال كلمة المرور الجديدة';

  @override
  String get passwordChangedTitle => 'تم تغيير كلمة المرور';

  @override
  String get passwordChangedMessage =>
      'تم تغيير كلمة المرور بنجاح. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get changePasswordSubtitle =>
      'أدخل كلمة المرور الحالية وكلمة المرور الجديدة';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get passwordStrengthStrong => 'قوية';

  @override
  String get passwordStrengthMedium => 'متوسطة';

  @override
  String get passwordStrengthWeak => 'ضعيفة';

  @override
  String get passwordPolicyHint => 'يجب أن تكون 8 أحرف على الأقل مع حرف ورقم';

  @override
  String get deleteAccountSecondTitle => 'تأكيد الحذف';

  @override
  String get driverSection => 'السائق';

  @override
  String get vehicleAndSeatLayout => 'إعدادات السيارة وتخطيط المقاعد';

  @override
  String get supportNumberUnavailable => 'رقم الدعم غير متاح حاليًا';

  @override
  String get supportWhatsAppPrefill =>
      'مرحباً، أحتاج مساعدة في تطبيق VisionWay.';

  @override
  String get cannotOpenWhatsApp => 'تعذر فتح WhatsApp';

  @override
  String get cannotOpenEmailApp => 'تعذر فتح تطبيق البريد الإلكتروني';

  @override
  String get supportEmailCopied => 'تم نسخ بريد الدعم';

  @override
  String get supportHeroTitle => 'نحن هنا لمساعدتك';

  @override
  String get supportHeroSubtitle =>
      'إذا واجهتك مشكلة في الحجز أو الحساب أو المدفوعات، يمكنك التواصل مباشرة مع فريق VisionWay.';

  @override
  String get supportContactEmailTitle => 'راسلنا عبر البريد الإلكتروني';

  @override
  String get supportContactEmailDescription =>
      'أرسل استفسارك وسنراجع الرسالة في أقرب وقت ممكن.';

  @override
  String get supportSendEmail => 'إرسال بريد';

  @override
  String get supportCopyEmail => 'نسخ البريد';

  @override
  String get supportContactWhatsAppTitle => 'راسلنا عبر WhatsApp';

  @override
  String get supportContactWhatsAppDescription =>
      'تواصل مباشرة مع فريق الدعم عبر WhatsApp للحصول على مساعدة فورية.';

  @override
  String get supportHowWeHelpTitle => 'كيف نساعدك؟';

  @override
  String get supportHelpItemLogin =>
      'مشكلة في تسجيل الدخول أو تحديث بيانات الحساب';

  @override
  String get supportHelpItemBookings => 'استفسارات الحجز والرحلات والمدفوعات';

  @override
  String get supportHelpItemTechnical => 'مراجعة المشاكل الفنية أو الاقتراحات';

  @override
  String get supportQuickTipTitle => 'نصيحة سريعة';

  @override
  String get supportTipIncludeContact =>
      'اذكر رقم الهاتف أو البريد المسجل داخل التطبيق لتسريع المراجعة.';

  @override
  String get supportTipDescribeProblem =>
      'أضف وصفًا مختصرًا للمشكلة والخطوات التي حدثت قبلها.';

  @override
  String get enterValidAmount => 'أدخل مبلغاً صحيحاً';

  @override
  String get uploadTransferProofRequired => 'يرجى رفع صورة إثبات التحويل';

  @override
  String get enterCliqAliasValue => 'أدخل قيمة الـ CliQ alias';

  @override
  String get topupRequestSent =>
      'تم إرسال طلب الشحن. سيُضاف الرصيد بعد التحقق من التحويل';

  @override
  String get verifyingPaymentStatus => 'جاري التحقق من حالة الدفع...';

  @override
  String verifyingPaymentStatusProgress(int attempt, int total) {
    return 'جاري التحقق من حالة الدفع... ($attempt/$total)';
  }

  @override
  String get walletToppedUpViaCliq => 'تم شحن المحفظة بنجاح عبر CliQ';

  @override
  String get cliqPaymentFailed => 'فشلت عملية الدفع عبر CliQ';

  @override
  String cliqPaymentFailedWithNote(String note) {
    return 'فشلت عملية الدفع: $note';
  }

  @override
  String connectionTemporarilyFailed(int attempt, int total) {
    return 'تعذّر الاتصال مؤقتاً ($attempt/$total). إعادة المحاولة...';
  }

  @override
  String cannotVerifyPayment(String detail) {
    return 'تعذّر التحقق من الدفع: $detail';
  }

  @override
  String get verificationTimedOut =>
      'انتهى وقت التحقق. إذا اكتمل الدفع عند CliQ سيظهر الرصيد خلال دقائق، أو تحقق من سجل المدفوعات.';

  @override
  String get walletTopupTitle => 'شحن المحفظة';

  @override
  String get pleaseWaitDoNotClose => 'يرجى الانتظار وعدم إغلاق الشاشة';

  @override
  String get topupMethodManual => 'تحويل يدوي';

  @override
  String get topupManualDescription =>
      'حوّل المبلغ إلى حساب المنصة ثم أدخل المبلغ وارفع صورة واضحة للتحويل. لا يُضاف رصيد تلقائياً قبل مراجعة الطلب.';

  @override
  String get topupCliqDescription =>
      'سيتم الدفع مباشرة عبر نظام CliQ. أدخل المبلغ وبيانات حسابك في CliQ وسيُضاف الرصيد تلقائياً عند تأكيد الدفع.';

  @override
  String amountWithCurrency(String currency) {
    return 'المبلغ ($currency)';
  }

  @override
  String get transactionReferenceOptional => 'رقم العملية / المرجع (اختياري)';

  @override
  String get ifAvailable => 'إن وُجد';

  @override
  String get uploadTransferProof => 'رفع صورة إثبات التحويل';

  @override
  String get imageSelected => 'تم اختيار صورة';

  @override
  String get aliasType => 'نوع الـ Alias';

  @override
  String get mobileNumber => 'رقم الموبايل';

  @override
  String get aliasName => 'اسم مستعار';

  @override
  String get aliasNameLabel => 'الاسم المستعار (Alias)';

  @override
  String get mobileNumberHint => 'مثال: 00962XXXXXXXXX';

  @override
  String get aliasNameHint => 'مثال: yourname@cliq';

  @override
  String get enterMobileNumber => 'أدخل رقم الموبايل';

  @override
  String get enterAliasName => 'أدخل الاسم المستعار';

  @override
  String get submitTopupRequest => 'إرسال طلب الشحن';

  @override
  String get payViaCliq => 'الدفع عبر CliQ';

  @override
  String get chatYourMessage => 'رسالتك';

  @override
  String chatMessageFrom(String name) {
    return 'رسالة من $name';
  }

  @override
  String chatYesterdayAt(String time) {
    return 'أمس $time';
  }

  @override
  String chatDaysAgo(int count) {
    return '$count أيام';
  }

  @override
  String countryCodePickerSemantic(String country) {
    return 'اختر رمز الدولة، الحالي: $country';
  }

  @override
  String get selectCountry => 'اختر الدولة';

  @override
  String get searchCountryHint => 'ابحث بالاسم أو رمز الدولة...';

  @override
  String get locationDefaultAmman => 'عمّان، الأردن';

  @override
  String get locationCurrentUnavailable => 'تعذر الحصول على الموقع الحالي.';

  @override
  String get locationServicesDisabledEnableGps =>
      'خدمات الموقع معطلة. يرجى تفعيل GPS.';

  @override
  String get locationEnable => 'تفعيل';

  @override
  String get locationGrantPermission => 'منح التصريح';

  @override
  String get locationSettings => 'الإعدادات';

  @override
  String get locationUnknown => 'موقع غير معروف';

  @override
  String get locationGetError => 'خطأ في الحصول على الموقع.';

  @override
  String get locationGrant => 'منح';

  @override
  String get locationPermissionDeniedPermanently => 'تم رفض التصريح بشكل دائم.';

  @override
  String get locationSearchNoResults =>
      'لم يتم العثور على نتائج. جرّب اسم مكان أو عنوان أوضح.';

  @override
  String locationSearchError(String error) {
    return 'خطأ في البحث: $error';
  }

  @override
  String get locationUseCurrent => 'استخدام الموقع الحالي';

  @override
  String get locationSearchSemantic => 'البحث عن مكان أو عنوان';

  @override
  String get locationSearchHint => 'ابحث عن مكان أو عنوان...';

  @override
  String get locationSearchOnMap => 'بحث على الخريطة';

  @override
  String get locationLoadingMap => 'جاري تحميل الخريطة...';

  @override
  String get locationMapLoadError => 'خطأ في تحميل الخريطة';

  @override
  String get locationPickOnMap => 'اختر موقعاً على الخريطة';

  @override
  String get locationConfirm => 'تأكيد الموقع';

  @override
  String get notificationDeleted => 'تم حذف الإشعار';

  @override
  String notificationsWithUnread(int count) {
    return 'الإشعارات ($count غير مقروء)';
  }

  @override
  String ratingStars(int count) {
    return '$count نجوم';
  }

  @override
  String ratingStarsSelected(int count) {
    return '$count نجوم (مختارة)';
  }

  @override
  String get seatDriverSeat => 'مقعد السائق';

  @override
  String get seatStatusAvailable => 'متاح';

  @override
  String get seatStatusBooked => 'محجوز';

  @override
  String get seatStatusLocked => 'مقفل';

  @override
  String get seatStatusUnavailable => 'غير متاح';

  @override
  String get seatStatusInvalid => 'غير صالح';

  @override
  String seatLabelSelected(int number, String status) {
    return 'مقعد $number $status، محدد';
  }

  @override
  String get seatLegendSelected => 'محدد';

  @override
  String get seatLegendLockedExternal => 'مقفل (خارج التطبيق)';

  @override
  String seatColorGuide(String label) {
    return 'دليل الألوان: $label';
  }

  @override
  String walletBalanceWithValue(String balance, String currency) {
    return 'رصيد المحفظة: $balance $currency';
  }

  @override
  String seatLabelNumbered(int number, String status) {
    return 'مقعد $number $status';
  }

  @override
  String get accountBannedNoReason =>
      'تم تعليق حسابك. تواصل مع الدعم لمزيد من التفاصيل.';

  @override
  String get bannedWhatsAppPrefill =>
      'مرحباً، حسابي على تطبيق VisionWay موقوف وأحتاج مساعدة.';

  @override
  String get followUs => 'تابعنا';

  @override
  String get followOnFacebook => 'فيسبوك';

  @override
  String get followOnLinkedIn => 'لينكدإن';

  @override
  String get tripGroupChat => 'محادثة جماعية للرحلة';

  @override
  String groupChatMembersCount(int count) {
    return '$count مشارك';
  }

  @override
  String get shareTripTrackingTitle => 'مشاركة تتبع الرحلة';

  @override
  String get shareTripTrackingMessage =>
      'هل تريد مشاركة تتبع رحلتك المباشر مع أحد؟';

  @override
  String get shareTripTrackingAction => 'مشاركة';

  @override
  String get shareTripTrackingLater => 'لاحقاً';

  @override
  String shareTripTrackingText(String url) {
    return 'تابع رحلتي المباشرة عبر هذا الرابط: $url';
  }

  @override
  String get shareTripTrackingError => 'تعذّر إنشاء رابط المشاركة';

  @override
  String get locationAutocompleteSuggestions => 'اقتراحات الأماكن';

  @override
  String get locationAutocompleteNoResults =>
      'لا توجد أماكن مطابقة. حدد الموقع على الخريطة بدلا من ذلك.';

  @override
  String get instantRidesTitle => 'الرحلات المباشرة';

  @override
  String get instantOnlineReady => 'متصل — جاهز لاستقبال الطلبات';

  @override
  String get instantOffline => 'غير متصل';

  @override
  String get instantOfferTitle => 'طلب رحلة مباشرة';

  @override
  String get instantRideAcceptedToast =>
      'تم قبول الرحلة. توجّه إلى نقطة الانطلاق.';

  @override
  String instantOfferCountdown(int seconds) {
    return 'تنتهي خلال $seconds ثانية';
  }

  @override
  String get instantDecline => 'رفض';

  @override
  String get instantAccept => 'قبول';

  @override
  String get instantRequestNow => 'اطلب الآن';

  @override
  String get instantRequestNowTitle => 'اطلب رحلة الآن';

  @override
  String get instantRequestNowSubtitle => 'سائق قريب يصل إليك مباشرة';

  @override
  String get instantSelectFromTo => 'اختر نقطة الانطلاق والوصول.';

  @override
  String get instantFromHint => 'مكان الانطلاق';

  @override
  String get instantFromPickerTitle => 'اختر نقطة الانطلاق';

  @override
  String get instantToHint => 'مكان الوصول';

  @override
  String get instantToPickerTitle => 'اختر نقطة الوصول';

  @override
  String get instantDriverFound => 'تم العثور على سائق!';

  @override
  String get instantDriverOnTheWay => 'السائق في طريقه إلى نقطة الانطلاق.';

  @override
  String get instantTrackTrip => 'تتبّع الرحلة';

  @override
  String get instantDone => 'تم';

  @override
  String get instantRequestCancelled => 'أُلغي الطلب';

  @override
  String get instantNoDrivers => 'لم نتمكن من العثور على سائق حاليًا';

  @override
  String get instantNoDriversSubtitle =>
      'قد يكون جميع السائقين مشغولين أو لا يوجد سائق قريب منك.';

  @override
  String get instantNoDriversTip =>
      'نصيحة: أعد المحاولة بعد بضع دقائق؛ قد يتوفر سائق قريب منك.';

  @override
  String get instantNoDriversIllustrationLabel => 'لم يتم العثور على سائق';

  @override
  String get instantNeedHelp => 'تحتاج مساعدة؟';

  @override
  String get instantContactSupport => 'تواصل مع الدعم';

  @override
  String get instantRideSafety => 'أمان الرحلة';

  @override
  String get instantPickupPoint => 'نقطة الانطلاق';

  @override
  String get instantDropoffPoint => 'نقطة الوصول';

  @override
  String get instantRetryFareChanged =>
      'تغيّر نطاق السعر؛ راجع السعر ثم أعد الطلب.';

  @override
  String get instantTryAgain => 'إعادة المحاولة';

  @override
  String get instantSearching => 'نبحث عن أقرب سائق...';

  @override
  String instantFareEstimate(String fare, String currency) {
    return 'الأجرة التقديرية: $fare $currency';
  }

  @override
  String get instantCancelRequest => 'إلغاء الطلب';

  @override
  String get instantYourFareLabel => 'سعرك';

  @override
  String instantRecommendedFare(String fare, String currency) {
    return 'السعر المقترح: $fare $currency';
  }

  @override
  String instantYourFareValue(String fare, String currency) {
    return 'سعرك: $fare $currency';
  }

  @override
  String get instantDriverOfferTitle => 'عرض من السائق';

  @override
  String get instantProposeFare => 'اقترح سعرًا أعلى';

  @override
  String get instantSendOffer => 'إرسال العرض';

  @override
  String get instantCounterSentToast => 'أُرسل عرضك للراكب. بانتظار موافقته...';

  @override
  String instantCounterMaxHint(String fare, String currency) {
    return 'الحد الأقصى: $fare $currency';
  }

  @override
  String get instantNudgeTitle => 'لا يوجد سائق قريب حتى الآن';

  @override
  String get instantNudgeSubtitle => 'جرّب رفع سعرك لجذب سائق أسرع';

  @override
  String instantRaiseTo(String fare, String currency) {
    return 'ارفع إلى $fare $currency';
  }

  @override
  String instantKeepFare(String fare, String currency) {
    return 'استمر بـ $fare $currency';
  }

  @override
  String instantArrivingIn(int minutes) {
    return 'يصل خلال ~$minutes دقيقة';
  }

  @override
  String instantAgreedFare(String fare, String currency) {
    return 'الأجرة المتفق عليها: $fare $currency';
  }
}
