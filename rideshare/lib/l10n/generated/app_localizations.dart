import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'VisionWay'**
  String get appName;

  /// عنوان شاشة تسجيل الدخول
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get phoneAuth;

  /// تسمية حقل رقم الهاتف
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumber;

  /// نص توضيحي لحقل رقم الهاتف
  ///
  /// In ar, this message translates to:
  /// **'+201234567890'**
  String get phoneNumberHint;

  /// رسالة خطأ عند عدم إدخال رقم الهاتف
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم الهاتف'**
  String get phoneNumberRequired;

  /// نص زر إرسال رمز التحقق
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز التحقق'**
  String get sendOTP;

  /// عنوان شاشة التحقق من OTP
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الرمز'**
  String get otpVerification;

  /// نص توضيحي لحقول OTP
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز التحقق'**
  String get enterOTP;

  /// نص زر إعادة إرسال OTP
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرمز'**
  String get resendOTP;

  /// نص العد التنازلي لإعادة إرسال OTP
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرمز خلال {seconds} ثانية'**
  String resendOTPIn(int seconds);

  /// عنوان شاشة إعداد الملف الشخصي
  ///
  /// In ar, this message translates to:
  /// **'إعداد الملف الشخصي'**
  String get profileSetup;

  /// تسمية حقل الاسم
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get name;

  /// رسالة خطأ عند عدم إدخال الاسم
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال الاسم'**
  String get nameRequired;

  /// تسمية حقل الجنس
  ///
  /// In ar, this message translates to:
  /// **'الجنس'**
  String get gender;

  /// رسالة خطأ عند عدم اختيار الجنس
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار الجنس'**
  String get genderRequired;

  /// خيار الجنس - ذكر
  ///
  /// In ar, this message translates to:
  /// **'ذكر'**
  String get male;

  /// خيار الجنس - أنثى
  ///
  /// In ar, this message translates to:
  /// **'أنثى'**
  String get female;

  /// تسمية حقل الدور
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get role;

  /// رسالة خطأ عند عدم اختيار الدور
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار الدور'**
  String get roleRequired;

  /// خيار الدور - راكب
  ///
  /// In ar, this message translates to:
  /// **'راكب'**
  String get passenger;

  /// خيار الدور - سائق
  ///
  /// In ar, this message translates to:
  /// **'سائق'**
  String get driver;

  /// نص زر الحفظ
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// نص حالة التحميل
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل...'**
  String get loading;

  /// عنوان رسالة الخطأ
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get error;

  /// نص زر الموافقة
  ///
  /// In ar, this message translates to:
  /// **'موافق'**
  String get ok;

  /// نص زر الإلغاء
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// عنوان شاشة الرئيسية
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// رسالة الترحيب
  ///
  /// In ar, this message translates to:
  /// **'مرحباً'**
  String get welcome;

  /// نص زر تسجيل الخروج
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// رسالة خطأ عند إدخال رقم هاتف غير صحيح
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير صحيح'**
  String get invalidPhoneNumber;

  /// رسالة نجاح إرسال OTP
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رمز التحقق'**
  String get otpSent;

  /// رسالة نجاح التحقق من OTP
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق بنجاح'**
  String get otpVerified;

  /// رسالة خطأ عند إدخال OTP غير صحيح
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق غير صحيح'**
  String get invalidOTP;

  /// رسالة نجاح حفظ الملف الشخصي
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الملف الشخصي بنجاح'**
  String get profileSaved;

  /// عنوان شاشة الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// قسم المظهر في الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get appearance;

  /// خيار تبديل الوضع الداكن
  ///
  /// In ar, this message translates to:
  /// **'الوضع الداكن'**
  String get darkMode;

  /// وصف خيار الوضع الداكن
  ///
  /// In ar, this message translates to:
  /// **'تفعيل المظهر الداكن للتطبيق'**
  String get darkModeSubtitle;

  /// خيار اختيار سمة التطبيق
  ///
  /// In ar, this message translates to:
  /// **'سمة التطبيق'**
  String get themeMode;

  /// خيار السمة - تبع النظام
  ///
  /// In ar, this message translates to:
  /// **'تلقائي (حسب النظام)'**
  String get themeSystem;

  /// خيار السمة - فاتح
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// خيار السمة - داكن
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeDark;

  /// عنوان نافذة اختيار السمة
  ///
  /// In ar, this message translates to:
  /// **'اختر السمة'**
  String get selectTheme;

  /// قسم اللغة في الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// اللغة العربية
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// اللغة الإنجليزية
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// عنوان نافذة اختيار اللغة
  ///
  /// In ar, this message translates to:
  /// **'اختر اللغة'**
  String get selectLanguage;

  /// اللغة الحالية - عربي
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get currentLanguageAr;

  /// اللغة الحالية - إنجليزي
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get currentLanguageEn;

  /// قسم الإشعارات في الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// خيار تبديل الإشعارات
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get pushNotifications;

  /// خيار صوت الإشعارات
  ///
  /// In ar, this message translates to:
  /// **'الأصوات'**
  String get notificationSound;

  /// خيار اهتزاز الإشعارات
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز'**
  String get notificationVibration;

  /// عنوان الانتقال لإعدادات الإشعارات المفصلة
  ///
  /// In ar, this message translates to:
  /// **'إعدادات مفصلة'**
  String get notificationSettings;

  /// عنوان شاشة إعدادات الإشعارات
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الإشعارات'**
  String get notificationSettingsTitle;

  /// عنوان قسم فئات الإشعارات
  ///
  /// In ar, this message translates to:
  /// **'فئات الإشعارات'**
  String get notificationCategories;

  /// فئة إشعارات الرحلات
  ///
  /// In ar, this message translates to:
  /// **'إشعارات الرحلات'**
  String get notifTrips;

  /// فئة إشعارات الدفع
  ///
  /// In ar, this message translates to:
  /// **'إشعارات الدفع'**
  String get notifPayments;

  /// فئة إشعارات الرسائل
  ///
  /// In ar, this message translates to:
  /// **'إشعارات الرسائل'**
  String get notifMessages;

  /// فئة إشعارات النظام
  ///
  /// In ar, this message translates to:
  /// **'إشعارات النظام'**
  String get notifSystem;

  /// نص معلومات تخصيص الإشعارات
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تخصيص الإشعارات التي تريد استقبالها'**
  String get notifCustomizeInfo;

  /// قسم الحساب والأمان
  ///
  /// In ar, this message translates to:
  /// **'الحساب والأمان'**
  String get accountSecurity;

  /// عنوان الانتقال لمعلومات الحساب
  ///
  /// In ar, this message translates to:
  /// **'معلومات الحساب'**
  String get accountInfo;

  /// عنوان تغيير كلمة المرور
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get changePassword;

  /// شعار قريباً
  ///
  /// In ar, this message translates to:
  /// **'قريباً'**
  String get comingSoon;

  /// عنوان شاشة الحساب والأمان
  ///
  /// In ar, this message translates to:
  /// **'الحساب والأمان'**
  String get accountSecurityTitle;

  /// قسم تفاصيل الحساب
  ///
  /// In ar, this message translates to:
  /// **'معلومات الحساب'**
  String get accountDetails;

  /// تسمية البريد الإلكتروني
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailLabel;

  /// تسمية رقم الهاتف
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneLabel;

  /// تسمية نوع الحساب
  ///
  /// In ar, this message translates to:
  /// **'نوع الحساب'**
  String get accountType;

  /// زر ربط الهاتف
  ///
  /// In ar, this message translates to:
  /// **'ربط'**
  String get linkPhone;

  /// قسم حالة التوثيق
  ///
  /// In ar, this message translates to:
  /// **'حالة التوثيق'**
  String get verificationStatus;

  /// توثيق البريد الإلكتروني
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailVerified;

  /// توثيق رقم الهاتف
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneVerified;

  /// اعتماد حساب السائق
  ///
  /// In ar, this message translates to:
  /// **'اعتماد السائق'**
  String get driverApproval;

  /// حالة التوثيق - موثّق
  ///
  /// In ar, this message translates to:
  /// **'موثّق'**
  String get verified;

  /// حالة التوثيق - غير موثّق
  ///
  /// In ar, this message translates to:
  /// **'غير موثّق'**
  String get notVerified;

  /// حالة اعتماد السائق - معتمد
  ///
  /// In ar, this message translates to:
  /// **'معتمد'**
  String get approved;

  /// حالة اعتماد السائق - قيد المراجعة
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get pending;

  /// قسم الخصوصية في الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get privacy;

  /// تبديل مشاركة الموقع
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الموقع'**
  String get locationSharing;

  /// وصف مشاركة الموقع
  ///
  /// In ar, this message translates to:
  /// **'مشاركة موقعك المباشر'**
  String get locationSharingSubtitle;

  /// تبديل حالة الاتصال
  ///
  /// In ar, this message translates to:
  /// **'الظهور متصل'**
  String get onlineStatus;

  /// وصف حالة الاتصال
  ///
  /// In ar, this message translates to:
  /// **'إظهار حالة الاتصال'**
  String get onlineStatusSubtitle;

  /// تبديل إظهار التقييم
  ///
  /// In ar, this message translates to:
  /// **'إظهار التقييم'**
  String get showRating;

  /// وصف إظهار التقييم
  ///
  /// In ar, this message translates to:
  /// **'إظهار تقييمك للآخرين'**
  String get showRatingSubtitle;

  /// عنوان شاشة الخصوصية
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get privacyTitle;

  /// قسم إعدادات الخصوصية
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الخصوصية'**
  String get privacySettings;

  /// نص معلومات الخصوصية
  ///
  /// In ar, this message translates to:
  /// **'هذه الإعدادات تتحكم في ما يمكن للآخرين رؤيته عنك'**
  String get privacyInfo;

  /// قسم الدفع والمحفظة في الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'الدفع والمحفظة'**
  String get paymentAndWallet;

  /// بلاط المحفظة
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get wallet;

  /// بلاط سجل المدفوعات
  ///
  /// In ar, this message translates to:
  /// **'سجل المدفوعات'**
  String get paymentHistory;

  /// قسم الدعم والمساعدة في الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'الدعم والمساعدة'**
  String get supportAndHelp;

  /// بلاط تواصل معنا عبر واتساب
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا'**
  String get contactUs;

  /// بلاط شروط الاستخدام
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام'**
  String get termsOfService;

  /// بلاط سياسة الخصوصية
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// قسم حول التطبيق في الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get aboutApp;

  /// عنوان شاشة حول التطبيق
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get aboutAppTitle;

  /// بلاط تقييم التطبيق
  ///
  /// In ar, this message translates to:
  /// **'تقييم التطبيق'**
  String get rateApp;

  /// بلاط مشاركة التطبيق
  ///
  /// In ar, this message translates to:
  /// **'مشاركة التطبيق'**
  String get shareApp;

  /// بلاط التراخيص
  ///
  /// In ar, this message translates to:
  /// **'التراخيص'**
  String get licenses;

  /// رقم إصدار التطبيق
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String appVersion(String version);

  /// وصف التطبيق
  ///
  /// In ar, this message translates to:
  /// **'منصة مشاركة الرحلات'**
  String get appDescription;

  /// نص ذيل الشاشة
  ///
  /// In ar, this message translates to:
  /// **'صنع بـ ❤️ في الأردن'**
  String get madeWithLove;

  /// عنوان شاشة المتصفح داخل التطبيق
  ///
  /// In ar, this message translates to:
  /// **'المتصفح'**
  String get inAppBrowserTitle;

  /// بلاط حذف الحساب
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get deleteAccount;

  /// رسالة تحذير حذف الحساب
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من رغبتك في حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.'**
  String get deleteAccountWarning;

  /// زر تأكيد حذف الحساب
  ///
  /// In ar, this message translates to:
  /// **'نعم، حذف الحساب'**
  String get deleteAccountConfirm;

  /// رسالة التحذير الثاني لحذف الحساب
  ///
  /// In ar, this message translates to:
  /// **'تحذير أخير: سيتم حذف جميع بياناتك بشكل نهائي ولن تتمكن من استرجاعها.'**
  String get deleteAccountSecondWarning;

  /// زر التأكيد النهائي لحذف الحساب
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get deleteAccountSecondConfirm;

  /// عنوان نافذة تواصل مع الدعم
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الدعم'**
  String get contactSupportTitle;

  /// رسالة فشل حذف الحساب
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن حذف الحساب حالياً. تواصل مع الدعم الفني عبر واتساب أو البريد الإلكتروني.'**
  String get contactSupportMessage;

  /// زر تواصل عبر واتساب
  ///
  /// In ar, this message translates to:
  /// **'تواصل عبر واتساب'**
  String get contactWhatsApp;

  /// زر تواصل عبر البريد الإلكتروني
  ///
  /// In ar, this message translates to:
  /// **'تواصل عبر البريد'**
  String get contactEmail;

  /// زر إغلاق
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// رسالة خطأ عدم الاتصال بالشبكة
  ///
  /// In ar, this message translates to:
  /// **'أنت غير متصل بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.'**
  String get errorsNetworkOffline;

  /// رسالة خطأ انتهاء مهلة الاتصال
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة الاتصال. حاول مرة أخرى.'**
  String get errorsNetworkTimeout;

  /// رسالة خطأ الخادم العامة
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الخادم. حاول مرة أخرى لاحقاً.'**
  String get errorsServerGeneric;

  /// رسالة انتهاء صلاحية الجلسة
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية جلستك. يرجى تسجيل الدخول مرة أخرى.'**
  String get errorsAuthSessionExpired;

  /// رسالة بيانات الدخول غير الصحيحة
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف أو كلمة المرور غير صحيحة.'**
  String get errorsAuthInvalidCredentials;

  /// رسالة رفض الإذن
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الإذن. تحقق من إعدادات التطبيق.'**
  String get errorsPermissionDenied;

  /// رسالة خطأ التحقق العامة
  ///
  /// In ar, this message translates to:
  /// **'البيانات المدخلة غير صحيحة. راجع البيانات وحاول مرة أخرى.'**
  String get errorsValidationGeneric;

  /// رسالة الخطأ غير المعروف
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع. حاول مرة أخرى.'**
  String get errorsUnknownGeneric;

  /// زر إعادة المحاولة
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get errorsActionRetry;

  /// زر إعادة تسجيل الدخول
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول مرة أخرى'**
  String get errorsActionReauthenticate;

  /// زر فتح الإعدادات
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get errorsActionOpenSettings;

  /// رسالة تعذر تحميل المسار
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل المسار. نعرض نقاط الانطلاق والوصول.'**
  String get errorsRouteUnavailable;

  /// Title for booking created notification
  ///
  /// In ar, this message translates to:
  /// **'حجز جديد'**
  String get notificationsBookingCreatedTitle;

  /// Body for booking created notification
  ///
  /// In ar, this message translates to:
  /// **'تم حجز مقعد جديد في رحلتك'**
  String get notificationsBookingCreatedBody;

  /// Title for booking confirmed notification
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد الحجز'**
  String get notificationsBookingConfirmedTitle;

  /// Body for booking confirmed notification
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد حجزك بنجاح'**
  String get notificationsBookingConfirmedBody;

  /// Title for booking rejected notification
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الحجز'**
  String get notificationsBookingRejectedTitle;

  /// Body for booking rejected notification
  ///
  /// In ar, this message translates to:
  /// **'للأسف، تم رفض حجزك'**
  String get notificationsBookingRejectedBody;

  /// Title for booking canceled notification
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الحجز'**
  String get notificationsBookingCanceledTitle;

  /// Body for booking canceled notification
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الحجز'**
  String get notificationsBookingCanceledBody;

  /// Title for new trip posted notification
  ///
  /// In ar, this message translates to:
  /// **'رحلة جديدة'**
  String get notificationsNewTripPostedTitle;

  /// Body for new trip posted notification
  ///
  /// In ar, this message translates to:
  /// **'يتوفر رحلة جديدة إلى {destination}'**
  String notificationsNewTripPostedBody(String destination);

  /// Ban screen title shown when user account is banned
  ///
  /// In ar, this message translates to:
  /// **'تم تعليق حسابك'**
  String get accountBannedTitle;

  /// Ban screen body message with reason
  ///
  /// In ar, this message translates to:
  /// **'تم تعليق حسابك بسبب: {reason}'**
  String accountBannedMessage(String reason);

  /// Button on ban screen that opens WhatsApp support
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الدعم'**
  String get accountBannedContactSupport;

  /// Banner shown when the account is in restricted state
  ///
  /// In ar, this message translates to:
  /// **'حسابك مقيّد مؤقتاً. بعض الإجراءات غير متاحة حتى تتم المراجعة.'**
  String get accountRestrictedBanner;

  /// Placeholder shown instead of the actual phone number before settlement
  ///
  /// In ar, this message translates to:
  /// **'رقم محجوب'**
  String get maskedPhoneLabel;

  /// Hint explaining why the phone number is masked
  ///
  /// In ar, this message translates to:
  /// **'يُكشف الرقم بعد إتمام الدفع'**
  String get maskedPhoneHint;

  /// State label shown on the public share-link page when the trip has completed
  ///
  /// In ar, this message translates to:
  /// **'انتهت الرحلة'**
  String get shareLinkTripEnded;

  /// Label shown on the public share-link page while the trip is in progress
  ///
  /// In ar, this message translates to:
  /// **'تتبع مباشر'**
  String get shareLinkLiveTracking;

  /// Button to generate a public share link for the trip
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الرحلة'**
  String get shareLinkGenerate;

  /// Push notification title when the driver no-show threshold is reached
  ///
  /// In ar, this message translates to:
  /// **'لم يصل السائق'**
  String get noShowNotificationTitle;

  /// Push notification body for driver no-show cancellation
  ///
  /// In ar, this message translates to:
  /// **'لم يبدأ السائق الرحلة خلال الوقت المحدد. تم إلغاء الرحلة وسيتم احتساب غرامة.'**
  String get noShowNotificationBody;

  /// Banner shown to a user who has an outstanding pending charge
  ///
  /// In ar, this message translates to:
  /// **'لديك رسوم معلقة بقيمة {amount}. ستُخصم عند تأكيد حجزك القادم.'**
  String pendingChargeBanner(String amount);

  /// Title for the pending charges section
  ///
  /// In ar, this message translates to:
  /// **'رسوم معلقة'**
  String get pendingChargeTitle;

  /// Label for a pending charge of kind passenger_cancellation
  ///
  /// In ar, this message translates to:
  /// **'غرامة إلغاء حجز'**
  String get pendingChargeKindPassengerCancellation;

  /// Label for a pending charge of kind driver_no_show
  ///
  /// In ar, this message translates to:
  /// **'غرامة غياب السائق'**
  String get pendingChargeKindDriverNoShow;

  /// Label for a pending charge of kind passenger_no_show
  ///
  /// In ar, this message translates to:
  /// **'غرامة غياب الراكب'**
  String get pendingChargeKindPassengerNoShow;

  /// Title for the connected devices management screen
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة المتصلة'**
  String get devicesScreenTitle;

  /// Button to revoke a connected device session
  ///
  /// In ar, this message translates to:
  /// **'إزالة الجهاز'**
  String get devicesRevokeButton;

  /// Label for the current device in the devices list
  ///
  /// In ar, this message translates to:
  /// **'الجهاز الحالي'**
  String get devicesCurrentDevice;

  /// Push notification title when a pending booking expires after 3 hours
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية الحجز'**
  String get bookingTimeoutNotificationTitle;

  /// Push notification body for booking timeout cancellation
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة الحجز ولم يتم قبوله من السائق. المقاعد أصبحت متاحة.'**
  String get bookingTimeoutNotificationBody;

  /// Driver CTA button to mark a booking as paid/settled
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الدفع'**
  String get settlementMarkPaid;

  /// Driver CTA to undo mark-paid within the grace window
  ///
  /// In ar, this message translates to:
  /// **'التراجع عن تأكيد الدفع'**
  String get settlementUnmarkPaid;

  /// Countdown text shown during the 5-minute grace window
  ///
  /// In ar, this message translates to:
  /// **'يمكن التراجع خلال {seconds} ثانية'**
  String settlementGraceCountdown(int seconds);

  /// Tooltip shown when chat is disabled because the booking is unsettled
  ///
  /// In ar, this message translates to:
  /// **'الدردشة متاحة بعد إتمام الدفع'**
  String get chatDisabledUnsettled;

  /// Tooltip shown when call is disabled because the booking is unsettled
  ///
  /// In ar, this message translates to:
  /// **'الاتصال متاح بعد إتمام الدفع'**
  String get callDisabledUnsettled;

  /// Label shown when the call is routed through a proxy number
  ///
  /// In ar, this message translates to:
  /// **'الاتصال عبر رقم مخفي'**
  String get callMaskedNumber;

  /// Profile settings toggle to hide phone number from other parties
  ///
  /// In ar, this message translates to:
  /// **'إخفاء رقم هاتفي'**
  String get hidePhoneNumberToggle;

  /// Description for the hide-phone-number toggle
  ///
  /// In ar, this message translates to:
  /// **'سيُستخدم رقم وسيط عند الاتصال بك'**
  String get hidePhoneNumberSubtitle;

  /// Title for the complaint filing screen
  ///
  /// In ar, this message translates to:
  /// **'تقديم شكوى'**
  String get complaintScreenTitle;

  /// Label for the complaint category picker
  ///
  /// In ar, this message translates to:
  /// **'نوع الشكوى'**
  String get complaintCategoryLabel;

  /// Label for the complaint description text field
  ///
  /// In ar, this message translates to:
  /// **'وصف المشكلة'**
  String get complaintDescriptionLabel;

  /// Submit button for the complaint form
  ///
  /// In ar, this message translates to:
  /// **'إرسال الشكوى'**
  String get complaintSubmitButton;

  /// Success message after complaint submission
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال شكواك بنجاح. سنراجعها قريباً.'**
  String get complaintSubmittedSuccess;

  /// Complaint status label for resolved complaints
  ///
  /// In ar, this message translates to:
  /// **'تم الحل'**
  String get complaintStatusResolved;

  /// Title for the refund request screen
  ///
  /// In ar, this message translates to:
  /// **'طلب استرداد'**
  String get refundRequestTitle;

  /// Explainer text on the refund request screen
  ///
  /// In ar, this message translates to:
  /// **'سيتم فتح واتساب للتواصل مع فريق الدعم بشأن طلب الاسترداد.'**
  String get refundRequestBody;

  /// Button to submit a refund request and open WhatsApp
  ///
  /// In ar, this message translates to:
  /// **'تقديم طلب الاسترداد'**
  String get refundRequestButton;

  /// Title for the support screen
  ///
  /// In ar, this message translates to:
  /// **'الدعم والمساعدة'**
  String get supportScreenTitle;

  /// Button to open WhatsApp support chat
  ///
  /// In ar, this message translates to:
  /// **'تواصل عبر واتساب'**
  String get supportWhatsAppButton;

  /// Label for the trip stops section
  ///
  /// In ar, this message translates to:
  /// **'محطات التوقف'**
  String get tripStopsLabel;

  /// Label for the trip notes section
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات الرحلة'**
  String get tripNotesLabel;

  /// Label for the trip recurrence settings
  ///
  /// In ar, this message translates to:
  /// **'تكرار الرحلة'**
  String get tripRecurrenceLabel;

  /// Recurrence frequency option: daily
  ///
  /// In ar, this message translates to:
  /// **'يومياً'**
  String get recurrenceFrequencyDaily;

  /// Recurrence frequency option: weekly
  ///
  /// In ar, this message translates to:
  /// **'أسبوعياً'**
  String get recurrenceFrequencyWeekly;

  /// Label for the recurrence end date picker
  ///
  /// In ar, this message translates to:
  /// **'حتى تاريخ'**
  String get recurrenceUntilLabel;

  /// Title for the companion (multi-seat) picker screen
  ///
  /// In ar, this message translates to:
  /// **'إضافة مرافقين'**
  String get companionPickerTitle;

  /// Label for the companion display name field
  ///
  /// In ar, this message translates to:
  /// **'اسم المرافق'**
  String get companionDisplayNameLabel;

  /// Button to trigger automatic seat selection
  ///
  /// In ar, this message translates to:
  /// **'اختيار مقاعد تلقائي'**
  String get autoPickSeatsButton;

  /// Title for the pre-trip presence confirmation prompt
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحضور'**
  String get preTripPromptTitle;

  /// Body of the pre-trip prompt shown to the passenger
  ///
  /// In ar, this message translates to:
  /// **'هل السائق موجود في نقطة الانطلاق؟'**
  String get preTripPromptPassengerBody;

  /// Body of the pre-trip prompt shown to the driver for each passenger
  ///
  /// In ar, this message translates to:
  /// **'هل الراكب {name} موجود؟'**
  String preTripPromptDriverBody(String name);

  /// Driver button to mark trip as arrived (completes the trip)
  ///
  /// In ar, this message translates to:
  /// **'تم الوصول للوجهة'**
  String get arrivedAtDestinationButton;

  /// Driver action to mark a passenger as absent at trip completion
  ///
  /// In ar, this message translates to:
  /// **'غياب الراكب'**
  String get markPassengerAbsent;

  /// No description provided for @welcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك في VisionWay'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'رحلتك تبدأ من هنا. اختر وجهتك وانطلق معنا بكل أمان وراحة.'**
  String get welcomeSubtitle;

  /// No description provided for @signIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get signIn;

  /// No description provided for @createNewAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get createNewAccount;

  /// No description provided for @signInSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك مجدداً! سجل دخولك للمتابعة.'**
  String get signInSubtitle;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @passwordRequired.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور مطلوبة'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور قصيرة'**
  String get passwordTooShort;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة السر؟'**
  String get forgotPassword;

  /// No description provided for @noAccountQuestion.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟ '**
  String get noAccountQuestion;

  /// No description provided for @phoneNumberFirst.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم الهاتف أولاً'**
  String get phoneNumberFirst;

  /// No description provided for @passwordResetLinkSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رابط إعادة تعيين كلمة المرور'**
  String get passwordResetLinkSent;

  /// No description provided for @required.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get required;

  /// No description provided for @accountTypePassenger.
  ///
  /// In ar, this message translates to:
  /// **'راكب'**
  String get accountTypePassenger;

  /// No description provided for @accountTypeDriver.
  ///
  /// In ar, this message translates to:
  /// **'سائق'**
  String get accountTypeDriver;

  /// No description provided for @accountTypeTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الحساب'**
  String get accountTypeTitle;

  /// No description provided for @accountTypeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حدد كيف تريد استخدام التطبيق'**
  String get accountTypeSubtitle;

  /// No description provided for @accountTypePassengerDesc.
  ///
  /// In ar, this message translates to:
  /// **'احجز رحلتك بسهولة'**
  String get accountTypePassengerDesc;

  /// No description provided for @accountTypeDriverDesc.
  ///
  /// In ar, this message translates to:
  /// **'اعرض رحلاتك للركاب'**
  String get accountTypeDriverDesc;

  /// No description provided for @continueLabel.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueLabel;

  /// No description provided for @signUpTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get signUpTitle;

  /// No description provided for @signUpSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حسابك للبدء'**
  String get signUpSubtitle;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fullName;

  /// No description provided for @fullNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'الاسم مطلوب'**
  String get fullNameRequired;

  /// No description provided for @emailOptional.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني (اختياري)'**
  String get emailOptional;

  /// No description provided for @invalidEmail.
  ///
  /// In ar, this message translates to:
  /// **'بريد إلكتروني غير صحيح'**
  String get invalidEmail;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get passwordsDoNotMatch;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟ '**
  String get alreadyHaveAccount;

  /// No description provided for @phoneAuthTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد رقم الهاتف'**
  String get phoneAuthTitle;

  /// No description provided for @phoneAuthSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سنرسل لك رمز تحقق عبر رسالة نصية'**
  String get phoneAuthSubtitle;

  /// No description provided for @linkPhoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'ربط رقم الهاتف'**
  String get linkPhoneTitle;

  /// No description provided for @linkPhoneSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أكد رقم هاتفك للمتابعة'**
  String get linkPhoneSubtitle;

  /// No description provided for @otpScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'إدخال رمز التحقق'**
  String get otpScreenTitle;

  /// No description provided for @otpScreenSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز المرسل إلى {phone}'**
  String otpScreenSubtitle(String phone);

  /// No description provided for @verifyButton.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get verifyButton;

  /// No description provided for @didntReceiveCode.
  ///
  /// In ar, this message translates to:
  /// **'لم يصلك الرمز؟ '**
  String get didntReceiveCode;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتفك وسنرسل لك رمز إعادة التعيين'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendResetCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز إعادة التعيين'**
  String get sendResetCode;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين كلمة المرور'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز وكلمة المرور الجديدة'**
  String get resetPasswordSubtitle;

  /// No description provided for @newPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get newPassword;

  /// No description provided for @resetCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز إعادة التعيين'**
  String get resetCode;

  /// No description provided for @resetCodeRequired.
  ///
  /// In ar, this message translates to:
  /// **'الرمز مطلوب'**
  String get resetCodeRequired;

  /// No description provided for @resetPasswordButton.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين'**
  String get resetPasswordButton;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور بنجاح'**
  String get passwordResetSuccess;

  /// No description provided for @driverSignUpTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب سائق'**
  String get driverSignUpTitle;

  /// No description provided for @driverSignUpSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإدخال بياناتك الأساسية'**
  String get driverSignUpSubtitle;

  /// No description provided for @driverCompleteProfileTitle.
  ///
  /// In ar, this message translates to:
  /// **'أكمل ملف السائق'**
  String get driverCompleteProfileTitle;

  /// No description provided for @driverCompleteProfileSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'نحتاج بعض البيانات لاعتماد حسابك'**
  String get driverCompleteProfileSubtitle;

  /// No description provided for @vehicleMake.
  ///
  /// In ar, this message translates to:
  /// **'ماركة السيارة'**
  String get vehicleMake;

  /// No description provided for @vehicleModel.
  ///
  /// In ar, this message translates to:
  /// **'موديل السيارة'**
  String get vehicleModel;

  /// No description provided for @vehicleYear.
  ///
  /// In ar, this message translates to:
  /// **'سنة الصنع'**
  String get vehicleYear;

  /// No description provided for @vehicleColor.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get vehicleColor;

  /// No description provided for @vehiclePlate.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة'**
  String get vehiclePlate;

  /// No description provided for @vehicleSeats.
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد'**
  String get vehicleSeats;

  /// No description provided for @licenseNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم رخصة القيادة'**
  String get licenseNumber;

  /// No description provided for @vehicleMakeRequired.
  ///
  /// In ar, this message translates to:
  /// **'ماركة السيارة مطلوبة'**
  String get vehicleMakeRequired;

  /// No description provided for @vehicleModelRequired.
  ///
  /// In ar, this message translates to:
  /// **'موديل السيارة مطلوب'**
  String get vehicleModelRequired;

  /// No description provided for @vehicleYearRequired.
  ///
  /// In ar, this message translates to:
  /// **'سنة الصنع مطلوبة'**
  String get vehicleYearRequired;

  /// No description provided for @vehicleColorRequired.
  ///
  /// In ar, this message translates to:
  /// **'اللون مطلوب'**
  String get vehicleColorRequired;

  /// No description provided for @vehiclePlateRequired.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة مطلوب'**
  String get vehiclePlateRequired;

  /// No description provided for @vehicleSeatsRequired.
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد مطلوب'**
  String get vehicleSeatsRequired;

  /// No description provided for @licenseNumberRequired.
  ///
  /// In ar, this message translates to:
  /// **'رقم الرخصة مطلوب'**
  String get licenseNumberRequired;

  /// No description provided for @submitButton.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get submitButton;

  /// No description provided for @driverPendingApprovalTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابك قيد المراجعة'**
  String get driverPendingApprovalTitle;

  /// No description provided for @driverPendingApprovalBody.
  ///
  /// In ar, this message translates to:
  /// **'سنراجع بياناتك وسنخبرك فور الموافقة. حتى ذلك الحين، يمكنك استخدام التطبيق كراكب.'**
  String get driverPendingApprovalBody;

  /// No description provided for @driverPendingApprovalAction.
  ///
  /// In ar, this message translates to:
  /// **'متابعة كراكب'**
  String get driverPendingApprovalAction;

  /// No description provided for @homeTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get homeTitle;

  /// No description provided for @tripsTab.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات'**
  String get tripsTab;

  /// No description provided for @bookingsTab.
  ///
  /// In ar, this message translates to:
  /// **'حجوزاتي'**
  String get bookingsTab;

  /// No description provided for @searchTab.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get searchTab;

  /// No description provided for @profileTab.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get profileTab;

  /// No description provided for @myTripsTitle.
  ///
  /// In ar, this message translates to:
  /// **'رحلاتي'**
  String get myTripsTitle;

  /// No description provided for @createTripTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رحلة'**
  String get createTripTitle;

  /// No description provided for @editTripTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرحلة'**
  String get editTripTitle;

  /// No description provided for @fromLabel.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get toLabel;

  /// No description provided for @departureDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ المغادرة'**
  String get departureDate;

  /// No description provided for @departureTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت المغادرة'**
  String get departureTime;

  /// No description provided for @pricePerSeat.
  ///
  /// In ar, this message translates to:
  /// **'السعر لكل مقعد'**
  String get pricePerSeat;

  /// No description provided for @availableSeats.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد المتاحة'**
  String get availableSeats;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notes;

  /// No description provided for @createTripButton.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الرحلة'**
  String get createTripButton;

  /// No description provided for @saveChangesButton.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get saveChangesButton;

  /// No description provided for @cancelTripButton.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الرحلة'**
  String get cancelTripButton;

  /// No description provided for @startTripButton.
  ///
  /// In ar, this message translates to:
  /// **'بدء الرحلة'**
  String get startTripButton;

  /// No description provided for @completeTripButton.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الرحلة'**
  String get completeTripButton;

  /// No description provided for @tripCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الرحلة بنجاح'**
  String get tripCreated;

  /// No description provided for @tripUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الرحلة'**
  String get tripUpdated;

  /// No description provided for @tripCanceled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الرحلة'**
  String get tripCanceled;

  /// No description provided for @tripStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدأت الرحلة'**
  String get tripStarted;

  /// No description provided for @tripCompleted.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الرحلة'**
  String get tripCompleted;

  /// No description provided for @noTripsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات بعد'**
  String get noTripsYet;

  /// No description provided for @noBookingsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حجوزات بعد'**
  String get noBookingsYet;

  /// No description provided for @searchTripsHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن رحلة...'**
  String get searchTripsHint;

  /// No description provided for @bookSeatButton.
  ///
  /// In ar, this message translates to:
  /// **'احجز مقعدًا'**
  String get bookSeatButton;

  /// No description provided for @selectSeats.
  ///
  /// In ar, this message translates to:
  /// **'اختر المقاعد'**
  String get selectSeats;

  /// No description provided for @selectedSeats.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد المختارة'**
  String get selectedSeats;

  /// No description provided for @totalPrice.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get totalPrice;

  /// No description provided for @confirmBooking.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحجز'**
  String get confirmBooking;

  /// No description provided for @bookingConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد الحجز'**
  String get bookingConfirmed;

  /// No description provided for @viewTripDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة'**
  String get viewTripDetails;

  /// No description provided for @tripDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة'**
  String get tripDetailsTitle;

  /// No description provided for @passengersLabel.
  ///
  /// In ar, this message translates to:
  /// **'الركاب'**
  String get passengersLabel;

  /// No description provided for @driverLabel.
  ///
  /// In ar, this message translates to:
  /// **'السائق'**
  String get driverLabel;

  /// No description provided for @vehicleLabel.
  ///
  /// In ar, this message translates to:
  /// **'المركبة'**
  String get vehicleLabel;

  /// No description provided for @departureLabel.
  ///
  /// In ar, this message translates to:
  /// **'المغادرة'**
  String get departureLabel;

  /// No description provided for @arrivalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوصول'**
  String get arrivalLabel;

  /// No description provided for @priceLabel.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get priceLabel;

  /// No description provided for @statusLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get statusLabel;

  /// No description provided for @callDriver.
  ///
  /// In ar, this message translates to:
  /// **'اتصال بالسائق'**
  String get callDriver;

  /// No description provided for @chatWithDriver.
  ///
  /// In ar, this message translates to:
  /// **'محادثة السائق'**
  String get chatWithDriver;

  /// No description provided for @rateDriver.
  ///
  /// In ar, this message translates to:
  /// **'تقييم السائق'**
  String get rateDriver;

  /// No description provided for @rateTrip.
  ///
  /// In ar, this message translates to:
  /// **'قيّم الرحلة'**
  String get rateTrip;

  /// No description provided for @submitRating.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get submitRating;

  /// No description provided for @ratingSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال التقييم'**
  String get ratingSubmitted;

  /// No description provided for @shareRideButton.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الرحلة'**
  String get shareRideButton;

  /// No description provided for @trackRideButton.
  ///
  /// In ar, this message translates to:
  /// **'تتبع الرحلة'**
  String get trackRideButton;

  /// No description provided for @startNow.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get startNow;

  /// No description provided for @phoneNumberRequired2.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الهاتف'**
  String get phoneNumberRequired2;

  /// No description provided for @verifyOtpTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من رقم الهاتف'**
  String get verifyOtpTitle;

  /// No description provided for @otpSentTo.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رمز تحقق إلى'**
  String get otpSentTo;

  /// No description provided for @resendCodeIn.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال بعد {seconds} ث'**
  String resendCodeIn(int seconds);

  /// No description provided for @resendCode.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال'**
  String get resendCode;

  /// No description provided for @verifyAndContinue.
  ///
  /// In ar, this message translates to:
  /// **'تحقق ومتابعة'**
  String get verifyAndContinue;

  /// No description provided for @changeNumber.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرقم'**
  String get changeNumber;

  /// No description provided for @personalInfoTitle.
  ///
  /// In ar, this message translates to:
  /// **'البيانات الشخصية'**
  String get personalInfoTitle;

  /// No description provided for @vehicleInfoTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات المركبة'**
  String get vehicleInfoTitle;

  /// No description provided for @documentsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المستندات'**
  String get documentsTitle;

  /// No description provided for @uploadIdFront.
  ///
  /// In ar, this message translates to:
  /// **'صورة الهوية - الوجه'**
  String get uploadIdFront;

  /// No description provided for @uploadIdBack.
  ///
  /// In ar, this message translates to:
  /// **'صورة الهوية - الخلف'**
  String get uploadIdBack;

  /// No description provided for @uploadLicense.
  ///
  /// In ar, this message translates to:
  /// **'صورة رخصة القيادة'**
  String get uploadLicense;

  /// No description provided for @uploadVehicleRegistration.
  ///
  /// In ar, this message translates to:
  /// **'صورة دفتر المركبة'**
  String get uploadVehicleRegistration;

  /// No description provided for @uploadProfilePhoto.
  ///
  /// In ar, this message translates to:
  /// **'صورة الملف الشخصي'**
  String get uploadProfilePhoto;

  /// No description provided for @uploadingFile.
  ///
  /// In ar, this message translates to:
  /// **'جاري الرفع...'**
  String get uploadingFile;

  /// No description provided for @tapToUpload.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للرفع'**
  String get tapToUpload;

  /// No description provided for @tapToChange.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للتغيير'**
  String get tapToChange;

  /// No description provided for @complete.
  ///
  /// In ar, this message translates to:
  /// **'إكمال'**
  String get complete;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skip;

  /// No description provided for @yes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get no;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get share;

  /// No description provided for @copy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get copy;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @tryAgain.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get tryAgain;

  /// No description provided for @logoutButton.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logoutButton;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد تسجيل الخروج'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد بالتأكيد تسجيل الخروج؟'**
  String get logoutConfirmMessage;

  /// No description provided for @noNotifications.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات'**
  String get noNotifications;

  /// No description provided for @markAllAsRead.
  ///
  /// In ar, this message translates to:
  /// **'تعيين الكل كمقروء'**
  String get markAllAsRead;

  /// No description provided for @clearAll.
  ///
  /// In ar, this message translates to:
  /// **'مسح الكل'**
  String get clearAll;

  /// No description provided for @signUpAs.
  ///
  /// In ar, this message translates to:
  /// **'سجل الآن كـ {role} لبدء رحلتك معنا.'**
  String signUpAs(String role);

  /// No description provided for @fullNameHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسمك بالكامل'**
  String get fullNameHint;

  /// No description provided for @validNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال اسم صحيح'**
  String get validNameRequired;

  /// No description provided for @passwordHint.
  ///
  /// In ar, this message translates to:
  /// **'8 أحرف على الأقل وتحتوي حرفاً ورقماً'**
  String get passwordHint;

  /// No description provided for @passwordPolicyError.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن تحتوي كلمة السر على 8 أحرف مع حرف ورقم'**
  String get passwordPolicyError;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'أعد إدخال كلمة السر'**
  String get confirmPasswordHint;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تأكيد كلمة السر'**
  String get confirmPasswordRequired;

  /// No description provided for @createAccountDev.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب (تطوير)'**
  String get createAccountDev;

  /// No description provided for @sendOtpAndCreateAccount.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز التحقق وإنشاء الحساب'**
  String get sendOtpAndCreateAccount;

  /// No description provided for @selectGenderError.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار الجنس'**
  String get selectGenderError;

  /// No description provided for @couldNotOpenWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح WhatsApp'**
  String get couldNotOpenWhatsApp;

  /// No description provided for @contactSupportViaWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الدعم عبر WhatsApp'**
  String get contactSupportViaWhatsApp;

  /// No description provided for @pickImageFromGallery.
  ///
  /// In ar, this message translates to:
  /// **'اختيار صورة من المعرض'**
  String get pickImageFromGallery;

  /// No description provided for @captureImageFromCamera.
  ///
  /// In ar, this message translates to:
  /// **'التقاط صورة من الكاميرا'**
  String get captureImageFromCamera;

  /// No description provided for @fromGallery.
  ///
  /// In ar, this message translates to:
  /// **'من المعرض'**
  String get fromGallery;

  /// No description provided for @fromCamera.
  ///
  /// In ar, this message translates to:
  /// **'من الكاميرا'**
  String get fromCamera;

  /// No description provided for @driverProfileSubmittedFull.
  ///
  /// In ar, this message translates to:
  /// **'تم رفع بياناتك بنجاح. طلبك قيد المراجعة من الإدارة؛ سيتم اعتمادك قريباً وستستطيع إنشاء رحلات بعد الاعتماد.'**
  String get driverProfileSubmittedFull;

  /// No description provided for @driverProfileSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'تم رفع بياناتك بنجاح. طلبك قيد المراجعة من الإدارة.'**
  String get driverProfileSubmitted;

  /// No description provided for @driverProfileStep2.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 2 من 2: المعلومات الإضافية'**
  String get driverProfileStep2;

  /// No description provided for @profilePhotoRequired.
  ///
  /// In ar, this message translates to:
  /// **'الصورة الشخصية *'**
  String get profilePhotoRequired;

  /// No description provided for @vehicleType.
  ///
  /// In ar, this message translates to:
  /// **'نوع المركبة'**
  String get vehicleType;

  /// No description provided for @vehicleTypeRequired.
  ///
  /// In ar, this message translates to:
  /// **'نوع المركبة *'**
  String get vehicleTypeRequired;

  /// No description provided for @vehicleTypeValidation.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار نوع المركبة'**
  String get vehicleTypeValidation;

  /// No description provided for @vehiclePlateRequiredLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة *'**
  String get vehiclePlateRequiredLabel;

  /// No description provided for @vehicleModelRequiredLabel.
  ///
  /// In ar, this message translates to:
  /// **'موديل السيارة *'**
  String get vehicleModelRequiredLabel;

  /// No description provided for @vehicleSeatsRequiredLabel.
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد *'**
  String get vehicleSeatsRequiredLabel;

  /// No description provided for @vehicleSeatsInvalid.
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد يجب أن يكون رقم صحيح أكبر من 0'**
  String get vehicleSeatsInvalid;

  /// No description provided for @driverLicenseRequired.
  ///
  /// In ar, this message translates to:
  /// **'رخصة القيادة *'**
  String get driverLicenseRequired;

  /// No description provided for @vehicleLicenseRequired.
  ///
  /// In ar, this message translates to:
  /// **'رخصة المركبة *'**
  String get vehicleLicenseRequired;

  /// No description provided for @carPhotoRequired.
  ///
  /// In ar, this message translates to:
  /// **'صورة السيارة *'**
  String get carPhotoRequired;

  /// No description provided for @uploadFileLabel.
  ///
  /// In ar, this message translates to:
  /// **'رفع {title}'**
  String uploadFileLabel(String title);

  /// No description provided for @firstName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الأول'**
  String get firstName;

  /// No description provided for @firstNameHint.
  ///
  /// In ar, this message translates to:
  /// **'أحمد'**
  String get firstNameHint;

  /// No description provided for @lastName.
  ///
  /// In ar, this message translates to:
  /// **'اسم العائلة'**
  String get lastName;

  /// No description provided for @lastNameHint.
  ///
  /// In ar, this message translates to:
  /// **'علي'**
  String get lastNameHint;

  /// No description provided for @driverSignUpVerifyButton.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من رقم الهاتف وأنشئ كلمة السر'**
  String get driverSignUpVerifyButton;

  /// No description provided for @driverSignUpStep1.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة 1 من 3: المعلومات الأساسية والتحقق'**
  String get driverSignUpStep1;

  /// No description provided for @backToSignIn.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى تسجيل الدخول'**
  String get backToSignIn;

  /// No description provided for @otpResent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رمز التحقق مرة أخرى'**
  String get otpResent;

  /// No description provided for @otpSentToPhone.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال الرمز المكون من 6 أرقام إلى\n'**
  String get otpSentToPhone;

  /// No description provided for @otpDigitLabel.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق {index}'**
  String otpDigitLabel(int index);

  /// No description provided for @enterPhoneToConfirm.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتفك للتأكيد'**
  String get enterPhoneToConfirm;

  /// No description provided for @enterYourPhone.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتفك'**
  String get enterYourPhone;

  /// No description provided for @devModeDirectLogin.
  ///
  /// In ar, this message translates to:
  /// **'وضع التطوير: سيتم الدخول مباشرة'**
  String get devModeDirectLogin;

  /// No description provided for @otpWillBeSentViaSms.
  ///
  /// In ar, this message translates to:
  /// **'سنرسل لك رمز التحقق عبر SMS'**
  String get otpWillBeSentViaSms;

  /// No description provided for @enterAction.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get enterAction;

  /// No description provided for @emailHint.
  ///
  /// In ar, this message translates to:
  /// **'example@email.com'**
  String get emailHint;

  /// No description provided for @selectedRoleLabel.
  ///
  /// In ar, this message translates to:
  /// **'لقد اخترت دور: {role}'**
  String selectedRoleLabel(String role);

  /// No description provided for @passengerDescription.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن رحلات واحجز مقعدك'**
  String get passengerDescription;

  /// No description provided for @tripOwnerDescription.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ رحلات واعرض مقاعدك'**
  String get tripOwnerDescription;

  /// No description provided for @tripOwnerNote.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج إلى إكمال بيانات المركبة والوثائق ليتم اعتماد حسابك كسائق.'**
  String get tripOwnerNote;

  /// No description provided for @saveAndComplete.
  ///
  /// In ar, this message translates to:
  /// **'حفظ وإكمال'**
  String get saveAndComplete;

  /// No description provided for @profileSetupSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أكمل بياناتك للمتابعة'**
  String get profileSetupSubtitle;

  /// No description provided for @otpTooManyAttempts.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة جداً. يرجى طلب رمز جديد.'**
  String get otpTooManyAttempts;

  /// No description provided for @otpExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.'**
  String get otpExpired;

  /// No description provided for @requestNewCode.
  ///
  /// In ar, this message translates to:
  /// **'طلب رمز جديد'**
  String get requestNewCode;

  /// No description provided for @newOtpSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رمز تحقق جديد'**
  String get newOtpSent;

  /// No description provided for @waitBeforeResend.
  ///
  /// In ar, this message translates to:
  /// **'يرجى الانتظار {seconds} ثانية قبل طلب رمز جديد'**
  String waitBeforeResend(int seconds);

  /// No description provided for @otpSentToYourPhone.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رمز التحقق إلى رقم هاتفك'**
  String get otpSentToYourPhone;

  /// No description provided for @newPasswordRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال كلمة مرور جديدة'**
  String get newPasswordRequired;

  /// No description provided for @yourProfile.
  ///
  /// In ar, this message translates to:
  /// **'ملفك الشخصي'**
  String get yourProfile;

  /// No description provided for @notSpecified.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get notSpecified;

  /// No description provided for @viewProfile.
  ///
  /// In ar, this message translates to:
  /// **'عرض الملف الشخصي'**
  String get viewProfile;

  /// No description provided for @userFallback.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم'**
  String get userFallback;

  /// No description provided for @browseTrips.
  ///
  /// In ar, this message translates to:
  /// **'تصفح الرحلات'**
  String get browseTrips;

  /// No description provided for @myWallet.
  ///
  /// In ar, this message translates to:
  /// **'محفظتي'**
  String get myWallet;

  /// No description provided for @pendingChargesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرسوم المستحقة'**
  String get pendingChargesTitle;

  /// No description provided for @profileTitle.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profileTitle;

  /// No description provided for @locationServicesDisabledTitle.
  ///
  /// In ar, this message translates to:
  /// **'خدمات الموقع معطلة'**
  String get locationServicesDisabledTitle;

  /// No description provided for @locationServicesDisabledMessage.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تفعيل خدمات الموقع (GPS) لتتمكن من استخدام التطبيق ومشاركة موقعك.'**
  String get locationServicesDisabledMessage;

  /// No description provided for @enable.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get enable;

  /// No description provided for @locationPermissionRequiredTitle.
  ///
  /// In ar, this message translates to:
  /// **'تصريح الموقع مطلوب'**
  String get locationPermissionRequiredTitle;

  /// No description provided for @locationPermissionRequiredMessage.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج التطبيق إلى تصريح الوصول للموقع لتتمكن من مشاركة رحلاتك.'**
  String get locationPermissionRequiredMessage;

  /// No description provided for @grantPermission.
  ///
  /// In ar, this message translates to:
  /// **'منح التصريح'**
  String get grantPermission;

  /// No description provided for @later.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get later;

  /// No description provided for @chooseYourLocation.
  ///
  /// In ar, this message translates to:
  /// **'اختر موقعك'**
  String get chooseYourLocation;

  /// No description provided for @defaultCityName.
  ///
  /// In ar, this message translates to:
  /// **'عمّان'**
  String get defaultCityName;

  /// No description provided for @defaultCityAddress.
  ///
  /// In ar, this message translates to:
  /// **'عمّان، الأردن'**
  String get defaultCityAddress;

  /// No description provided for @myBookings.
  ///
  /// In ar, this message translates to:
  /// **'حجوزاتي'**
  String get myBookings;

  /// No description provided for @profileTabLabel.
  ///
  /// In ar, this message translates to:
  /// **'البروفايل'**
  String get profileTabLabel;

  /// No description provided for @createNewTrip.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رحلة جديدة'**
  String get createNewTrip;

  /// No description provided for @mustSignIn.
  ///
  /// In ar, this message translates to:
  /// **'يجب تسجيل الدخول'**
  String get mustSignIn;

  /// No description provided for @noBookingsCurrently.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حجوزات حالياً'**
  String get noBookingsCurrently;

  /// No description provided for @upcoming.
  ///
  /// In ar, this message translates to:
  /// **'قادمة'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In ar, this message translates to:
  /// **'سابقة'**
  String get past;

  /// No description provided for @cannotCancel.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن الإلغاء'**
  String get cannotCancel;

  /// No description provided for @cannotCancelWithin12Hours.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إلغاء الحجز خلال 12 ساعة من موعد الرحلة.\n\nموعد الرحلة: {departure}'**
  String cannotCancelWithin12Hours(String departure);

  /// No description provided for @unknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get unknown;

  /// No description provided for @confirmCancelBooking.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد إلغاء الحجز'**
  String get confirmCancelBooking;

  /// No description provided for @cancellationFeeNotice.
  ///
  /// In ar, this message translates to:
  /// **'سيتم خصم رسوم إلغاء بنسبة 5% من قيمة حجزك، وستُطبَّق على رحلتك القادمة.'**
  String get cancellationFeeNotice;

  /// No description provided for @confirmCancelBookingQuestion.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من إلغاء الحجز؟'**
  String get confirmCancelBookingQuestion;

  /// No description provided for @goBack.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get goBack;

  /// No description provided for @cancelBooking.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحجز'**
  String get cancelBooking;

  /// No description provided for @bookingCancelledSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الحجز بنجاح'**
  String get bookingCancelledSuccess;

  /// No description provided for @noTripsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات'**
  String get noTripsTitle;

  /// No description provided for @noTripsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإنشاء رحلة جديدة وشارك\nرحلتك مع الآخرين'**
  String get noTripsSubtitle;

  /// No description provided for @errorOccurred.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get errorOccurred;

  /// No description provided for @openMenu.
  ///
  /// In ar, this message translates to:
  /// **'فتح القائمة'**
  String get openMenu;

  /// No description provided for @sideMenu.
  ///
  /// In ar, this message translates to:
  /// **'القائمة الجانبية'**
  String get sideMenu;

  /// No description provided for @whereWillYourTripStart.
  ///
  /// In ar, this message translates to:
  /// **'إلى أين ستنطلق رحلتك؟'**
  String get whereWillYourTripStart;

  /// No description provided for @createTripCtaSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ رحلتك واستقبل الحجوزات من الركاب'**
  String get createTripCtaSubtitle;

  /// No description provided for @currentLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقعك الحالي'**
  String get currentLocation;

  /// No description provided for @determiningLocation.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديد الموقع...'**
  String get determiningLocation;

  /// No description provided for @detectLocationAutomatically.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الموقع تلقائياً'**
  String get detectLocationAutomatically;

  /// No description provided for @chooseLocationManually.
  ///
  /// In ar, this message translates to:
  /// **'اختيار الموقع يدوياً'**
  String get chooseLocationManually;

  /// No description provided for @myActiveTrips.
  ///
  /// In ar, this message translates to:
  /// **'رحلاتي القائمة'**
  String get myActiveTrips;

  /// No description provided for @errorLoadingTrips.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في تحميل الرحلات'**
  String get errorLoadingTrips;

  /// No description provided for @noActiveTripsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات قائمة'**
  String get noActiveTripsTitle;

  /// No description provided for @noActiveTripsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإنشاء رحلة لتظهر هنا.'**
  String get noActiveTripsSubtitle;

  /// No description provided for @whereDoYouWantToGo.
  ///
  /// In ar, this message translates to:
  /// **'إلى أين تريد الذهاب؟'**
  String get whereDoYouWantToGo;

  /// No description provided for @haveAPlaceInMind.
  ///
  /// In ar, this message translates to:
  /// **'هل لديك مكان في الاعتبار؟'**
  String get haveAPlaceInMind;

  /// No description provided for @nearbyTrips.
  ///
  /// In ar, this message translates to:
  /// **'رحلات قريبة منك'**
  String get nearbyTrips;

  /// No description provided for @viewAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get viewAll;

  /// No description provided for @noNearbyTripsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات قريبة'**
  String get noNearbyTripsTitle;

  /// No description provided for @noNearbyTripsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'جرب تغيير موقعك أو عرض جميع الرحلات'**
  String get noNearbyTripsSubtitle;

  /// No description provided for @viewAllTrips.
  ///
  /// In ar, this message translates to:
  /// **'عرض جميع الرحلات'**
  String get viewAllTrips;

  /// No description provided for @showMoreTrips.
  ///
  /// In ar, this message translates to:
  /// **'عرض {count} رحلة أخرى'**
  String showMoreTrips(int count);

  /// No description provided for @dataUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث البيانات'**
  String get dataUpdated;

  /// No description provided for @dataUpdateFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحديث البيانات: {error}'**
  String dataUpdateFailed(String error);

  /// No description provided for @refreshData.
  ///
  /// In ar, this message translates to:
  /// **'تحديث البيانات'**
  String get refreshData;

  /// No description provided for @driverDataApproved.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة على بياناتك'**
  String get driverDataApproved;

  /// No description provided for @driverAccountUnderReview.
  ///
  /// In ar, this message translates to:
  /// **'حسابك كسائق قيد المراجعة'**
  String get driverAccountUnderReview;

  /// No description provided for @driverApprovedDescription.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إنشاء رحلات وإدارتها من تبويب \"رحلاتي\".'**
  String get driverApprovedDescription;

  /// No description provided for @driverPendingDescription.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً الحجز كراكب.'**
  String get driverPendingDescription;

  /// No description provided for @checkVerificationStatus.
  ///
  /// In ar, this message translates to:
  /// **'معرفة حالة التوثيق'**
  String get checkVerificationStatus;

  /// No description provided for @editProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get editProfile;

  /// No description provided for @helpAndSupport.
  ///
  /// In ar, this message translates to:
  /// **'المساعدة والدعم'**
  String get helpAndSupport;

  /// No description provided for @searchForTrip.
  ///
  /// In ar, this message translates to:
  /// **'بحث عن رحلة'**
  String get searchForTrip;

  /// No description provided for @showAllAvailableTrips.
  ///
  /// In ar, this message translates to:
  /// **'عرض جميع الرحلات المتاحة'**
  String get showAllAvailableTrips;

  /// No description provided for @showTrips.
  ///
  /// In ar, this message translates to:
  /// **'عرض الرحلات'**
  String get showTrips;

  /// No description provided for @completedTrip.
  ///
  /// In ar, this message translates to:
  /// **'رحلة منتهية'**
  String get completedTrip;

  /// No description provided for @tripUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'رحلة غير متاحة'**
  String get tripUnavailable;

  /// No description provided for @bookingStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار'**
  String get bookingStatusPending;

  /// No description provided for @bookingStatusConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'مؤكد'**
  String get bookingStatusConfirmed;

  /// No description provided for @bookingStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغي'**
  String get bookingStatusCancelled;

  /// No description provided for @dateLabel.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get dateLabel;

  /// No description provided for @timeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get timeLabel;

  /// No description provided for @seatLabel.
  ///
  /// In ar, this message translates to:
  /// **'المقعد'**
  String get seatLabel;

  /// No description provided for @chat.
  ///
  /// In ar, this message translates to:
  /// **'دردشة'**
  String get chat;

  /// No description provided for @call.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get call;

  /// No description provided for @distanceKm.
  ///
  /// In ar, this message translates to:
  /// **'{distance} كم'**
  String distanceKm(String distance);

  /// No description provided for @tripStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'نشطة'**
  String get tripStatusActive;

  /// No description provided for @tripStatusFullyBooked.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة الحجز'**
  String get tripStatusFullyBooked;

  /// No description provided for @tripStatusInProgress.
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get tripStatusInProgress;

  /// No description provided for @tripStatusHidden.
  ///
  /// In ar, this message translates to:
  /// **'مخفية'**
  String get tripStatusHidden;

  /// No description provided for @seatsAvailable.
  ///
  /// In ar, this message translates to:
  /// **'{count} متاح'**
  String seatsAvailable(int count);

  /// No description provided for @feePaid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوعة'**
  String get feePaid;

  /// No description provided for @feeDue.
  ///
  /// In ar, this message translates to:
  /// **'مستحقة'**
  String get feeDue;

  /// No description provided for @tripStartDeadlinePassed.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقت بدء الرحلة (لم يبدأ السائق ضمن المهلة)'**
  String get tripStartDeadlinePassed;

  /// No description provided for @homeGreeting.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً'**
  String get homeGreeting;

  /// No description provided for @defaultUserName.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم'**
  String get defaultUserName;

  /// No description provided for @homeStartTripTitle.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ رحلتك'**
  String get homeStartTripTitle;

  /// No description provided for @homeStartTripSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ رحلة جديدة واكسب المال'**
  String get homeStartTripSubtitle;

  /// No description provided for @homeCreateTripButton.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رحلة جديدة'**
  String get homeCreateTripButton;

  /// No description provided for @userInfoTitle.
  ///
  /// In ar, this message translates to:
  /// **'معلومات المستخدم'**
  String get userInfoTitle;

  /// No description provided for @roleLabel.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get roleLabel;

  /// No description provided for @statisticsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إحصائيات'**
  String get statisticsTitle;

  /// No description provided for @tripsStatLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات'**
  String get tripsStatLabel;

  /// No description provided for @passengersStatLabel.
  ///
  /// In ar, this message translates to:
  /// **'الركاب'**
  String get passengersStatLabel;

  /// No description provided for @editProfilePhoto.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الصورة الشخصية'**
  String get editProfilePhoto;

  /// No description provided for @phoneNotVerified.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير مؤكد'**
  String get phoneNotVerified;

  /// No description provided for @editProfileMenuItem.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get editProfileMenuItem;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @locationUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذر الحصول على الموقع.'**
  String get locationUnavailable;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In ar, this message translates to:
  /// **'خدمات الموقع معطلة.'**
  String get locationServicesDisabled;

  /// No description provided for @enableAction.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get enableAction;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In ar, this message translates to:
  /// **'تصريح الموقع مطلوب.'**
  String get locationPermissionRequired;

  /// No description provided for @grantAction.
  ///
  /// In ar, this message translates to:
  /// **'منح'**
  String get grantAction;

  /// No description provided for @locationPermissionPermanentlyDenied.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض التصريح بشكل دائم.'**
  String get locationPermissionPermanentlyDenied;

  /// No description provided for @filterFromValue.
  ///
  /// In ar, this message translates to:
  /// **'من: {value}'**
  String filterFromValue(String value);

  /// No description provided for @filterToValue.
  ///
  /// In ar, this message translates to:
  /// **'إلى: {value}'**
  String filterToValue(String value);

  /// No description provided for @filterCityValue.
  ///
  /// In ar, this message translates to:
  /// **'مدينة: {value}'**
  String filterCityValue(String value);

  /// No description provided for @filterDateValue.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ: {value}'**
  String filterDateValue(String value);

  /// No description provided for @filterSortNewest.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب: الأحدث'**
  String get filterSortNewest;

  /// No description provided for @availableTripsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات المتاحة'**
  String get availableTripsTitle;

  /// No description provided for @signInToViewTrips.
  ///
  /// In ar, this message translates to:
  /// **'يجب تسجيل الدخول لعرض الرحلات'**
  String get signInToViewTrips;

  /// No description provided for @changeLocation.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الموقع'**
  String get changeLocation;

  /// No description provided for @filterAndSort.
  ///
  /// In ar, this message translates to:
  /// **'تصفية وترتيب'**
  String get filterAndSort;

  /// No description provided for @currentLocationLabel.
  ///
  /// In ar, this message translates to:
  /// **'موقعك الحالي:'**
  String get currentLocationLabel;

  /// No description provided for @detectingLocation.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديد الموقع...'**
  String get detectingLocation;

  /// No description provided for @preferredTrips.
  ///
  /// In ar, this message translates to:
  /// **'رحلات مفضلة'**
  String get preferredTrips;

  /// No description provided for @allTrips.
  ///
  /// In ar, this message translates to:
  /// **'كل الرحلات'**
  String get allTrips;

  /// No description provided for @errorWithDetail.
  ///
  /// In ar, this message translates to:
  /// **'خطأ: {detail}'**
  String errorWithDetail(String detail);

  /// No description provided for @enableLocationForTrips.
  ///
  /// In ar, this message translates to:
  /// **'فعّل الموقع لعرض هذه الرحلات'**
  String get enableLocationForTrips;

  /// No description provided for @noTripsAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات متاحة'**
  String get noTripsAvailable;

  /// No description provided for @chooseLocationThenRetry.
  ///
  /// In ar, this message translates to:
  /// **'اختر موقعك الحالي ثم أعد المحاولة'**
  String get chooseLocationThenRetry;

  /// No description provided for @tryChangingFilterOrLocation.
  ///
  /// In ar, this message translates to:
  /// **'جرب تغيير الفلتر أو الموقع'**
  String get tryChangingFilterOrLocation;

  /// No description provided for @refreshTripsList.
  ///
  /// In ar, this message translates to:
  /// **'تحديث قائمة الرحلات'**
  String get refreshTripsList;

  /// No description provided for @refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get refresh;

  /// No description provided for @filterAndSortTrips.
  ///
  /// In ar, this message translates to:
  /// **'تصفية وترتيب الرحلات'**
  String get filterAndSortTrips;

  /// No description provided for @chooseDeparturePoint.
  ///
  /// In ar, this message translates to:
  /// **'اختر نقطة الانطلاق'**
  String get chooseDeparturePoint;

  /// No description provided for @chooseDestination.
  ///
  /// In ar, this message translates to:
  /// **'اختر الوجهة'**
  String get chooseDestination;

  /// No description provided for @cityLabel.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get cityLabel;

  /// No description provided for @searchByCityName.
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم المدينة'**
  String get searchByCityName;

  /// No description provided for @chooseDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ'**
  String get chooseDate;

  /// No description provided for @sortLabel.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get sortLabel;

  /// No description provided for @sortNearest.
  ///
  /// In ar, this message translates to:
  /// **'الأقرب'**
  String get sortNearest;

  /// No description provided for @sortNewest.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get sortNewest;

  /// No description provided for @apply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get apply;

  /// No description provided for @tripDetailsFromTo.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة من {from} إلى {to}'**
  String tripDetailsFromTo(String from, String to);

  /// No description provided for @liveDriverLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقع السائق المباشر'**
  String get liveDriverLocation;

  /// No description provided for @tripNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الرحلة غير موجودة'**
  String get tripNotFound;

  /// No description provided for @tripRouteTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسار الرحلة'**
  String get tripRouteTitle;

  /// No description provided for @viewRouteOnMap.
  ///
  /// In ar, this message translates to:
  /// **'عرض المسار على الخريطة'**
  String get viewRouteOnMap;

  /// No description provided for @tripDistanceLabel.
  ///
  /// In ar, this message translates to:
  /// **'مسافة الرحلة'**
  String get tripDistanceLabel;

  /// No description provided for @distanceKmValue.
  ///
  /// In ar, this message translates to:
  /// **'{value} كم'**
  String distanceKmValue(String value);

  /// No description provided for @departureTimeLabel.
  ///
  /// In ar, this message translates to:
  /// **'وقت الانطلاق'**
  String get departureTimeLabel;

  /// No description provided for @seatsCountOfTotal.
  ///
  /// In ar, this message translates to:
  /// **'{available} من {total}'**
  String seatsCountOfTotal(int available, int total);

  /// No description provided for @seatLayoutLabel.
  ///
  /// In ar, this message translates to:
  /// **'تخطيط المقاعد'**
  String get seatLayoutLabel;

  /// No description provided for @preventGenderMixingLabel.
  ///
  /// In ar, this message translates to:
  /// **'منع الاختلاط'**
  String get preventGenderMixingLabel;

  /// No description provided for @enabledValue.
  ///
  /// In ar, this message translates to:
  /// **'مفعل'**
  String get enabledValue;

  /// No description provided for @driverInfoTitle.
  ///
  /// In ar, this message translates to:
  /// **'معلومات السائق'**
  String get driverInfoTitle;

  /// No description provided for @carImageTitle.
  ///
  /// In ar, this message translates to:
  /// **'صورة السيارة'**
  String get carImageTitle;

  /// No description provided for @noSeatsAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مقاعد متاحة'**
  String get noSeatsAvailable;

  /// No description provided for @chatLabel.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة'**
  String get chatLabel;

  /// No description provided for @chatNotEnabledYet.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تفعيل التواصل بعد. يجب على السائق دفع رسوم التواصل أولاً.'**
  String get chatNotEnabledYet;

  /// No description provided for @rateLabel.
  ///
  /// In ar, this message translates to:
  /// **'تقييم'**
  String get rateLabel;

  /// No description provided for @alreadyRatedTrip.
  ///
  /// In ar, this message translates to:
  /// **'لقد قمت بتقييم هذه الرحلة بالفعل'**
  String get alreadyRatedTrip;

  /// No description provided for @thanksForRating.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لتقييمك!'**
  String get thanksForRating;

  /// No description provided for @canRateAfterTripEnds.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك التقييم بعد انتهاء الرحلة'**
  String get canRateAfterTripEnds;

  /// No description provided for @seatNotSelectable.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن اختيار هذا المقعد، قد يكون محجوزًا أو غير مناسب حسب قواعد الرحلة.'**
  String get seatNotSelectable;

  /// No description provided for @signInRequired.
  ///
  /// In ar, this message translates to:
  /// **'يجب تسجيل الدخول'**
  String get signInRequired;

  /// No description provided for @tripInfoTitle.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الرحلة'**
  String get tripInfoTitle;

  /// No description provided for @fromValue.
  ///
  /// In ar, this message translates to:
  /// **'من: {value}'**
  String fromValue(String value);

  /// No description provided for @toValue.
  ///
  /// In ar, this message translates to:
  /// **'إلى: {value}'**
  String toValue(String value);

  /// No description provided for @pricePerSeatValue.
  ///
  /// In ar, this message translates to:
  /// **'السعر: {price} {currency} لكل مقعد'**
  String pricePerSeatValue(String price, String currency);

  /// No description provided for @selectOneOrMoreSeats.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك اختيار مقعد واحد أو أكثر حسب المقاعد المتاحة.'**
  String get selectOneOrMoreSeats;

  /// No description provided for @enterPassengerDataAfterSeats.
  ///
  /// In ar, this message translates to:
  /// **'بعد اختيار المقاعد ستدخل بيانات كل مسافر قبل إرسال طلب الحجز.'**
  String get enterPassengerDataAfterSeats;

  /// No description provided for @appShareWalletNotice.
  ///
  /// In ar, this message translates to:
  /// **'سيتم خصم حصة التطبيق من محفظتك عند إرسال الحجز. تأكد من كفاية الرصيد من صفحة محفظتي.'**
  String get appShareWalletNotice;

  /// No description provided for @selectedSeatsValue.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد المحددة: {seats}'**
  String selectedSeatsValue(String seats);

  /// No description provided for @continueToPassengerData.
  ///
  /// In ar, this message translates to:
  /// **'متابعة إدخال بيانات المسافرين'**
  String get continueToPassengerData;

  /// No description provided for @continueToPassengerDataTooltip.
  ///
  /// In ar, this message translates to:
  /// **'متابعة لإدخال بيانات المسافرين وإرسال طلب الحجز'**
  String get continueToPassengerDataTooltip;

  /// No description provided for @continueBookOneSeat.
  ///
  /// In ar, this message translates to:
  /// **'متابعة لحجز مقعد واحد'**
  String get continueBookOneSeat;

  /// No description provided for @continueBookSeats.
  ///
  /// In ar, this message translates to:
  /// **'متابعة لحجز {count} مقاعد'**
  String continueBookSeats(int count);

  /// No description provided for @bookingRequestSentNotice.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إرسال طلب الحجز للسائق بعد تأكيد بيانات المسافرين. انتظر موافقة السائق قبل اعتماد الحجز.'**
  String get bookingRequestSentNotice;

  /// No description provided for @departurePointTitle.
  ///
  /// In ar, this message translates to:
  /// **'نقطة الانطلاق'**
  String get departurePointTitle;

  /// No description provided for @arrivalPointTitle.
  ///
  /// In ar, this message translates to:
  /// **'نقطة الوصول'**
  String get arrivalPointTitle;

  /// No description provided for @destinationTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوجهة'**
  String get destinationTitle;

  /// No description provided for @driverLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'موقع السائق'**
  String get driverLocationTitle;

  /// No description provided for @viewFullRoute.
  ///
  /// In ar, this message translates to:
  /// **'عرض المسار بالكامل'**
  String get viewFullRoute;

  /// No description provided for @loadingRouteLabel.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل المسار'**
  String get loadingRouteLabel;

  /// No description provided for @loadingRoute.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل المسار...'**
  String get loadingRoute;

  /// No description provided for @stopFollowingDriver.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف تتبع السائق'**
  String get stopFollowingDriver;

  /// No description provided for @followDriver.
  ///
  /// In ar, this message translates to:
  /// **'تتبع السائق'**
  String get followDriver;

  /// No description provided for @liveTrackingEnabled.
  ///
  /// In ar, this message translates to:
  /// **'التتبع المباشر مفعل'**
  String get liveTrackingEnabled;

  /// No description provided for @bookingRequestSentWaitConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب الحجز. انتظر تأكيد السائق.'**
  String get bookingRequestSentWaitConfirm;

  /// No description provided for @autoPickTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختيار تلقائي'**
  String get autoPickTitle;

  /// No description provided for @passengerDataTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيانات المسافرين'**
  String get passengerDataTitle;

  /// No description provided for @seatCountLabel.
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد'**
  String get seatCountLabel;

  /// No description provided for @mainBookerLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحاجز الرئيسي'**
  String get mainBookerLabel;

  /// No description provided for @companionLabel.
  ///
  /// In ar, this message translates to:
  /// **'مرافق {index}'**
  String companionLabel(int index);

  /// No description provided for @sharePhoneWithDriver.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة رقم الهاتف مع السائق'**
  String get sharePhoneWithDriver;

  /// No description provided for @sharePhoneWithDriverSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'السماح للسائق برؤية رقمك للتواصل'**
  String get sharePhoneWithDriverSubtitle;

  /// No description provided for @sendBookingRequest.
  ///
  /// In ar, this message translates to:
  /// **'إرسال طلب الحجز'**
  String get sendBookingRequest;

  /// No description provided for @seatWord.
  ///
  /// In ar, this message translates to:
  /// **'مقعد'**
  String get seatWord;

  /// No description provided for @chatClosedForSending.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الرحلة، ولا يمكن إرسال رسائل جديدة.'**
  String get chatClosedForSending;

  /// No description provided for @errorMustSignInFirst.
  ///
  /// In ar, this message translates to:
  /// **'يجب تسجيل الدخول أولاً'**
  String get errorMustSignInFirst;

  /// No description provided for @chatLoadError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في تحميل المحادثة: {error}'**
  String chatLoadError(String error);

  /// No description provided for @chatTitleWithDriver.
  ///
  /// In ar, this message translates to:
  /// **'محادثة - {driverName}'**
  String chatTitleWithDriver(String driverName);

  /// No description provided for @chatLoadErrorShort.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في تحميل المحادثة'**
  String get chatLoadErrorShort;

  /// No description provided for @errorWithMessage.
  ///
  /// In ar, this message translates to:
  /// **'خطأ: {error}'**
  String errorWithMessage(String error);

  /// No description provided for @chatNoMessagesYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل بعد'**
  String get chatNoMessagesYet;

  /// No description provided for @chatStartConversationNow.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ المحادثة الآن'**
  String get chatStartConversationNow;

  /// No description provided for @chatTypeMessageLabel.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة'**
  String get chatTypeMessageLabel;

  /// No description provided for @chatTypeMessageHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة...'**
  String get chatTypeMessageHint;

  /// No description provided for @chatSendMessageTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرسالة'**
  String get chatSendMessageTooltip;

  /// No description provided for @complaintCategorySafety.
  ///
  /// In ar, this message translates to:
  /// **'سلامة'**
  String get complaintCategorySafety;

  /// No description provided for @complaintCategoryPayment.
  ///
  /// In ar, this message translates to:
  /// **'مدفوعات'**
  String get complaintCategoryPayment;

  /// No description provided for @complaintCategoryVehicleCondition.
  ///
  /// In ar, this message translates to:
  /// **'حالة المركبة'**
  String get complaintCategoryVehicleCondition;

  /// No description provided for @complaintCategoryDriverBehavior.
  ///
  /// In ar, this message translates to:
  /// **'سلوك السائق'**
  String get complaintCategoryDriverBehavior;

  /// No description provided for @complaintCategoryAppIssue.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة في التطبيق'**
  String get complaintCategoryAppIssue;

  /// No description provided for @complaintCategoryOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get complaintCategoryOther;

  /// No description provided for @complaintSubmittedSuccessMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال شكواك بنجاح. سنراجعها في أقرب وقت.'**
  String get complaintSubmittedSuccessMessage;

  /// No description provided for @complaintHeroTitle.
  ///
  /// In ar, this message translates to:
  /// **'أخبرنا بما حدث'**
  String get complaintHeroTitle;

  /// No description provided for @complaintHeroSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'شكواك تساعدنا على تحسين الخدمة وضمان سلامة الجميع.'**
  String get complaintHeroSubtitle;

  /// No description provided for @complaintTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'نوع الشكوى'**
  String get complaintTypeLabel;

  /// No description provided for @complaintProblemDescriptionLabel.
  ///
  /// In ar, this message translates to:
  /// **'وصف المشكلة'**
  String get complaintProblemDescriptionLabel;

  /// No description provided for @complaintDescriptionHint.
  ///
  /// In ar, this message translates to:
  /// **'اشرح المشكلة بتفصيل كافٍ لمساعدتنا في مراجعتها…'**
  String get complaintDescriptionHint;

  /// No description provided for @complaintDescriptionRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى كتابة وصف للمشكلة'**
  String get complaintDescriptionRequired;

  /// No description provided for @complaintDescriptionTooShort.
  ///
  /// In ar, this message translates to:
  /// **'الوصف قصير جداً (10 أحرف على الأقل)'**
  String get complaintDescriptionTooShort;

  /// No description provided for @walletMyWallet.
  ///
  /// In ar, this message translates to:
  /// **'محفظتي'**
  String get walletMyWallet;

  /// No description provided for @walletTopUpDescription.
  ///
  /// In ar, this message translates to:
  /// **'تُستخدم لدفع تكلفة الحجز عند تفعيل الدفع من المحفظة. الشحن بالدينار الأردني (JOD) عبر CliQ أو تحويل يدوي مع إثبات؛ يُضاف الرصيد بعد التأكد أو موافقة الإدارة حسب الطريقة.'**
  String get walletTopUpDescription;

  /// No description provided for @walletTransactionHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل الحركات'**
  String get walletTransactionHistory;

  /// No description provided for @walletTopUp.
  ///
  /// In ar, this message translates to:
  /// **'شحن'**
  String get walletTopUp;

  /// No description provided for @walletTopUpSemantics.
  ///
  /// In ar, this message translates to:
  /// **'شحن المحفظة'**
  String get walletTopUpSemantics;

  /// No description provided for @walletNoTransactionsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركات بعد'**
  String get walletNoTransactionsYet;

  /// No description provided for @walletPendingChargesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرسوم المستحقة'**
  String get walletPendingChargesTitle;

  /// No description provided for @walletPendingChargesSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'عرض الغرامات والرسوم المعلّقة وشحن المحفظة'**
  String get walletPendingChargesSubtitle;

  /// No description provided for @walletBalanceLabel.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة'**
  String get walletBalanceLabel;

  /// No description provided for @walletAccountInactive.
  ///
  /// In ar, this message translates to:
  /// **'الحساب غير مفعّل — تواصل مع الدعم'**
  String get walletAccountInactive;

  /// No description provided for @walletTxTopup.
  ///
  /// In ar, this message translates to:
  /// **'شحن'**
  String get walletTxTopup;

  /// No description provided for @walletTxTripPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفع رحلة'**
  String get walletTxTripPayment;

  /// No description provided for @walletTxTripDebit.
  ///
  /// In ar, this message translates to:
  /// **'خصم رحلة'**
  String get walletTxTripDebit;

  /// No description provided for @walletTxRefund.
  ///
  /// In ar, this message translates to:
  /// **'استرداد'**
  String get walletTxRefund;

  /// No description provided for @walletTxPayout.
  ///
  /// In ar, this message translates to:
  /// **'سحب أرباح'**
  String get walletTxPayout;

  /// No description provided for @walletTxAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'تعديل رصيد'**
  String get walletTxAdjustment;

  /// No description provided for @walletTxHold.
  ///
  /// In ar, this message translates to:
  /// **'حجز مبلغ'**
  String get walletTxHold;

  /// No description provided for @walletTxReleaseHold.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء حجز'**
  String get walletTxReleaseHold;

  /// No description provided for @ratingPleaseSelectRating.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار تقييم'**
  String get ratingPleaseSelectRating;

  /// No description provided for @ratingAlreadyRated.
  ///
  /// In ar, this message translates to:
  /// **'لقد قمت بتقييم هذه الرحلة بالفعل'**
  String get ratingAlreadyRated;

  /// No description provided for @ratingSubmittedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال التقييم بنجاح'**
  String get ratingSubmittedSuccess;

  /// No description provided for @ratingTripTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقييم الرحلة'**
  String get ratingTripTitle;

  /// No description provided for @ratingHowWasExperience.
  ///
  /// In ar, this message translates to:
  /// **'كيف كانت تجربتك مع السائق؟'**
  String get ratingHowWasExperience;

  /// No description provided for @ratingCommentLabel.
  ///
  /// In ar, this message translates to:
  /// **'حقل تعليق'**
  String get ratingCommentLabel;

  /// No description provided for @ratingCommentHint.
  ///
  /// In ar, this message translates to:
  /// **'شاركنا رأيك في الرحلة'**
  String get ratingCommentHint;

  /// No description provided for @ratingCommentOptional.
  ///
  /// In ar, this message translates to:
  /// **'تعليق (اختياري)'**
  String get ratingCommentOptional;

  /// No description provided for @ratingCommentHintEllipsis.
  ///
  /// In ar, this message translates to:
  /// **'شاركنا رأيك في الرحلة...'**
  String get ratingCommentHintEllipsis;

  /// No description provided for @ratingSubmitButton.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get ratingSubmitButton;

  /// No description provided for @ratingLabelVeryBad.
  ///
  /// In ar, this message translates to:
  /// **'سيء جداً'**
  String get ratingLabelVeryBad;

  /// No description provided for @ratingLabelBad.
  ///
  /// In ar, this message translates to:
  /// **'سيء'**
  String get ratingLabelBad;

  /// No description provided for @ratingLabelAverage.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get ratingLabelAverage;

  /// No description provided for @ratingLabelGood.
  ///
  /// In ar, this message translates to:
  /// **'جيد'**
  String get ratingLabelGood;

  /// No description provided for @ratingLabelExcellent.
  ///
  /// In ar, this message translates to:
  /// **'ممتاز'**
  String get ratingLabelExcellent;

  /// No description provided for @refundSubmittedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل طلب الاسترداد. سيتم تحويلك إلى WhatsApp لاستكمال الإجراء.'**
  String get refundSubmittedSuccess;

  /// No description provided for @refundRequestScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب استرداد المبلغ'**
  String get refundRequestScreenTitle;

  /// No description provided for @refundHeroTitle.
  ///
  /// In ar, this message translates to:
  /// **'استرداد رسوم الحجز'**
  String get refundHeroTitle;

  /// No description provided for @refundTripRef.
  ///
  /// In ar, this message translates to:
  /// **'الرحلة: {tripRef}'**
  String refundTripRef(String tripRef);

  /// No description provided for @refundContactViaWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'سيتواصل معك فريقنا عبر WhatsApp لإتمام الإجراء.'**
  String get refundContactViaWhatsApp;

  /// No description provided for @refundReasonLabel.
  ///
  /// In ar, this message translates to:
  /// **'سبب طلب الاسترداد'**
  String get refundReasonLabel;

  /// No description provided for @refundReasonHint.
  ///
  /// In ar, this message translates to:
  /// **'اشرح سبب طلبك لاسترداد المبلغ بإيجاز…'**
  String get refundReasonHint;

  /// No description provided for @refundReasonRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى كتابة سبب الطلب'**
  String get refundReasonRequired;

  /// No description provided for @refundReasonTooShort.
  ///
  /// In ar, this message translates to:
  /// **'السبب قصير جداً (10 أحرف على الأقل)'**
  String get refundReasonTooShort;

  /// No description provided for @refundWhatsAppNote.
  ///
  /// In ar, this message translates to:
  /// **'بعد الإرسال، ستُفتح محادثة WhatsApp مع فريق الدعم لإتمام إجراء الاسترداد.'**
  String get refundWhatsAppNote;

  /// No description provided for @refundSubmitButton.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get refundSubmitButton;

  /// No description provided for @chatClosedTripEnded.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الرحلة، ولا يمكن إرسال رسائل جديدة.'**
  String get chatClosedTripEnded;

  /// No description provided for @mustSignInFirst.
  ///
  /// In ar, this message translates to:
  /// **'يجب تسجيل الدخول أولاً'**
  String get mustSignInFirst;

  /// No description provided for @chatCreateFailed.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إنشاء المحادثة'**
  String get chatCreateFailed;

  /// No description provided for @tripChatTitle.
  ///
  /// In ar, this message translates to:
  /// **'محادثة الرحلة'**
  String get tripChatTitle;

  /// No description provided for @chatWithPerson.
  ///
  /// In ar, this message translates to:
  /// **'محادثة مع {name}'**
  String chatWithPerson(String name);

  /// No description provided for @noMessagesYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل بعد'**
  String get noMessagesYet;

  /// No description provided for @startChatNow.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ المحادثة الآن'**
  String get startChatNow;

  /// No description provided for @typeMessage.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة'**
  String get typeMessage;

  /// No description provided for @typeMessageHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة...'**
  String get typeMessageHint;

  /// No description provided for @sendMessage.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرسالة'**
  String get sendMessage;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @selectOriginPoint.
  ///
  /// In ar, this message translates to:
  /// **'اختر نقطة الانطلاق'**
  String get selectOriginPoint;

  /// No description provided for @selectDestination.
  ///
  /// In ar, this message translates to:
  /// **'اختر الوجهة'**
  String get selectDestination;

  /// No description provided for @completeLocationAndTimeData.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إكمال بيانات المواقع والوقت'**
  String get completeLocationAndTimeData;

  /// No description provided for @departureTimeMustBeFuture.
  ///
  /// In ar, this message translates to:
  /// **'وقت الانطلاق يجب أن يكون في المستقبل'**
  String get departureTimeMustBeFuture;

  /// No description provided for @userNotSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم غير مسجل دخول'**
  String get userNotSignedIn;

  /// No description provided for @tripCreatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الرحلة بنجاح'**
  String get tripCreatedSuccess;

  /// No description provided for @tripCreateFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إنشاء الرحلة'**
  String get tripCreateFailed;

  /// No description provided for @weekdaySun.
  ///
  /// In ar, this message translates to:
  /// **'أحد'**
  String get weekdaySun;

  /// No description provided for @weekdayMon.
  ///
  /// In ar, this message translates to:
  /// **'اثنين'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In ar, this message translates to:
  /// **'ثلاثاء'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In ar, this message translates to:
  /// **'أربعاء'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In ar, this message translates to:
  /// **'خميس'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In ar, this message translates to:
  /// **'جمعة'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In ar, this message translates to:
  /// **'سبت'**
  String get weekdaySat;

  /// No description provided for @driverAccountUnderReviewBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً تصفح الرحلات والحجز كراكب.'**
  String get driverAccountUnderReviewBody;

  /// No description provided for @backToHome.
  ///
  /// In ar, this message translates to:
  /// **'العودة للرئيسية'**
  String get backToHome;

  /// No description provided for @createNewTripTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رحلة جديدة'**
  String get createNewTripTitle;

  /// No description provided for @backLabel.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get backLabel;

  /// No description provided for @shareYourNextTrip.
  ///
  /// In ar, this message translates to:
  /// **'شارك رحلتك القادمة'**
  String get shareYourNextTrip;

  /// No description provided for @createTripHeaderSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'قم بتحديد وجهتك ووقت الانطلاق لتبدأ مشاركة رحلتك مع الركاب.'**
  String get createTripHeaderSubtitle;

  /// No description provided for @tripRoute.
  ///
  /// In ar, this message translates to:
  /// **'مسار الرحلة'**
  String get tripRoute;

  /// No description provided for @whereAreYouNow.
  ///
  /// In ar, this message translates to:
  /// **'أين أنت الآن؟'**
  String get whereAreYouNow;

  /// No description provided for @whereIsYourDestination.
  ///
  /// In ar, this message translates to:
  /// **'أين وجهتك؟'**
  String get whereIsYourDestination;

  /// No description provided for @departureAndPriceDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الانطلاق والسعر'**
  String get departureAndPriceDetails;

  /// No description provided for @pricePerSeatHint.
  ///
  /// In ar, this message translates to:
  /// **'السعر لكل مقعد'**
  String get pricePerSeatHint;

  /// No description provided for @enterPrice.
  ///
  /// In ar, this message translates to:
  /// **'أدخل السعر'**
  String get enterPrice;

  /// No description provided for @enterValidNumber.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقماً صحيحاً'**
  String get enterValidNumber;

  /// No description provided for @seatsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} مقعد'**
  String seatsCount(int count);

  /// No description provided for @seatLayoutFromSettings.
  ///
  /// In ar, this message translates to:
  /// **'تخطيط المقاعد ومنع الاختلاط مأخوذان من إعدادات سيارتك ويُطبَّقان على كل رحلاتك.'**
  String get seatLayoutFromSettings;

  /// No description provided for @noSeatLayoutSet.
  ///
  /// In ar, this message translates to:
  /// **'لم تضبط بعد تخطيط مقاعد لسيارتك — سيتم استخدام تخطيط افتراضي. اضبطه من إعدادات السيارة لتجربة أدق.'**
  String get noSeatLayoutSet;

  /// No description provided for @editVehicleSettings.
  ///
  /// In ar, this message translates to:
  /// **'تعديل إعدادات السيارة'**
  String get editVehicleSettings;

  /// No description provided for @confirmAndPublishTrip.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد ونشر الرحلة'**
  String get confirmAndPublishTrip;

  /// No description provided for @stopsLabel.
  ///
  /// In ar, this message translates to:
  /// **'محطات التوقف'**
  String get stopsLabel;

  /// No description provided for @optionalLabel.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get optionalLabel;

  /// No description provided for @addStop.
  ///
  /// In ar, this message translates to:
  /// **'إضافة محطة توقف'**
  String get addStop;

  /// No description provided for @stopsHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف حتى 5 محطات توقف وسيطة على طول الطريق.'**
  String get stopsHint;

  /// No description provided for @deleteStopNumber.
  ///
  /// In ar, this message translates to:
  /// **'حذف المحطة {number}'**
  String deleteStopNumber(int number);

  /// No description provided for @selectStopNumber.
  ///
  /// In ar, this message translates to:
  /// **'اختر محطة توقف {number}'**
  String selectStopNumber(int number);

  /// No description provided for @notesForPassengers.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات للركاب'**
  String get notesForPassengers;

  /// No description provided for @tripNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: التوقف في صيدلية البتراء، لا تأخر أكثر من 5 دقائق...'**
  String get tripNotesHint;

  /// No description provided for @tripRecurrence.
  ///
  /// In ar, this message translates to:
  /// **'تكرار الرحلة'**
  String get tripRecurrence;

  /// No description provided for @enableTripRecurrenceSemantic.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل تكرار الرحلة: {state}'**
  String enableTripRecurrenceSemantic(String state);

  /// No description provided for @recurrenceStateEnabled.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get recurrenceStateEnabled;

  /// No description provided for @recurrenceStateDisabled.
  ///
  /// In ar, this message translates to:
  /// **'معطّل'**
  String get recurrenceStateDisabled;

  /// No description provided for @recurrenceDisabledHint.
  ///
  /// In ar, this message translates to:
  /// **'فعّل هذا الخيار لجدولة الرحلة بشكل تلقائي (يومياً أو أسبوعياً).'**
  String get recurrenceDisabledHint;

  /// No description provided for @recurrenceDaily.
  ///
  /// In ar, this message translates to:
  /// **'يومياً'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعياً'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceDaysLabel.
  ///
  /// In ar, this message translates to:
  /// **'أيام التكرار'**
  String get recurrenceDaysLabel;

  /// No description provided for @weekdaySelectedSemantic.
  ///
  /// In ar, this message translates to:
  /// **'{day} (محدد)'**
  String weekdaySelectedSemantic(String day);

  /// No description provided for @recurrenceUntilHint.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ انتهاء التكرار (اختياري)'**
  String get recurrenceUntilHint;

  /// No description provided for @recurrenceUntilHelp.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ انتهاء التكرار'**
  String get recurrenceUntilHelp;

  /// No description provided for @uploadCarImageFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل رفع صورة السيارة'**
  String get uploadCarImageFailed;

  /// No description provided for @tripUpdatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الرحلة بنجاح'**
  String get tripUpdatedSuccess;

  /// No description provided for @tripUpdateFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحديث الرحلة'**
  String get tripUpdateFailed;

  /// No description provided for @editTripScreenTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرحلة'**
  String get editTripScreenTitle;

  /// No description provided for @editYourTrip.
  ///
  /// In ar, this message translates to:
  /// **'تعديل رحلتك'**
  String get editYourTrip;

  /// No description provided for @updateTripInfo.
  ///
  /// In ar, this message translates to:
  /// **'قم بتحديث معلومات الرحلة'**
  String get updateTripInfo;

  /// No description provided for @tripDetailsSection.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة'**
  String get tripDetailsSection;

  /// No description provided for @originPointLabel.
  ///
  /// In ar, this message translates to:
  /// **'نقطة الانطلاق'**
  String get originPointLabel;

  /// No description provided for @originExampleHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: عمّان'**
  String get originExampleHint;

  /// No description provided for @destinationLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوجهة'**
  String get destinationLabel;

  /// No description provided for @destinationExampleHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: الإسكندرية'**
  String get destinationExampleHint;

  /// No description provided for @pickDateAndTime.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ والوقت'**
  String get pickDateAndTime;

  /// No description provided for @priceExampleHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 100'**
  String get priceExampleHint;

  /// No description provided for @selectOriginValidator.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار نقطة الانطلاق'**
  String get selectOriginValidator;

  /// No description provided for @selectDestinationValidator.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار الوجهة'**
  String get selectDestinationValidator;

  /// No description provided for @selectDepartureTimeValidator.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار وقت الانطلاق'**
  String get selectDepartureTimeValidator;

  /// No description provided for @enterPriceValidator.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال السعر'**
  String get enterPriceValidator;

  /// No description provided for @priceMustBeValidPositive.
  ///
  /// In ar, this message translates to:
  /// **'السعر يجب أن يكون رقم صحيح أكبر من 0'**
  String get priceMustBeValidPositive;

  /// No description provided for @carImageSection.
  ///
  /// In ar, this message translates to:
  /// **'صورة السيارة'**
  String get carImageSection;

  /// No description provided for @optionalParen.
  ///
  /// In ar, this message translates to:
  /// **'(اختياري)'**
  String get optionalParen;

  /// No description provided for @uploadCarImage.
  ///
  /// In ar, this message translates to:
  /// **'رفع صورة السيارة'**
  String get uploadCarImage;

  /// No description provided for @tapToUploadCarImage.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لرفع صورة السيارة'**
  String get tapToUploadCarImage;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديلات'**
  String get saveChanges;

  /// No description provided for @selectFromMap.
  ///
  /// In ar, this message translates to:
  /// **'اختيار من الخريطة'**
  String get selectFromMap;

  /// No description provided for @warningTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحذير'**
  String get warningTitle;

  /// No description provided for @pastDateWarningBody.
  ///
  /// In ar, this message translates to:
  /// **'أنت تختار تاريخ في الماضي. الرحلات في الماضي لن تظهر في نتائج البحث للركاب. هل تريد المتابعة؟'**
  String get pastDateWarningBody;

  /// No description provided for @bookedSeatsEditWarning.
  ///
  /// In ar, this message translates to:
  /// **'هذه الرحلة تحتوي على {count} مقعد محجوز. تعديل بعض المعلومات قد يؤثر على الحجوزات الموجودة. هل تريد المتابعة؟'**
  String bookedSeatsEditWarning(int count);

  /// No description provided for @myTripsTitleLabel.
  ///
  /// In ar, this message translates to:
  /// **'رحلاتي'**
  String get myTripsTitleLabel;

  /// No description provided for @driverAccountUnderReviewTrips.
  ///
  /// In ar, this message translates to:
  /// **'حسابك كسائق قيد المراجعة. لا يمكنك إنشاء أو إدارة رحلات حتى تتم الموافقة عليه.'**
  String get driverAccountUnderReviewTrips;

  /// No description provided for @mustBeApprovedDriver.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن تكون سائقاً معتمداً لعرض الرحلات.'**
  String get mustBeApprovedDriver;

  /// No description provided for @tabActive.
  ///
  /// In ar, this message translates to:
  /// **'نشطة'**
  String get tabActive;

  /// No description provided for @tabHidden.
  ///
  /// In ar, this message translates to:
  /// **'مخفية'**
  String get tabHidden;

  /// No description provided for @tabCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get tabCompleted;

  /// No description provided for @retryLabel.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retryLabel;

  /// No description provided for @noActiveTrips.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات نشطة'**
  String get noActiveTrips;

  /// No description provided for @noHiddenTrips.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات مخفية'**
  String get noHiddenTrips;

  /// No description provided for @noCompletedTrips.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات مكتملة'**
  String get noCompletedTrips;

  /// No description provided for @createTripShort.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رحلة'**
  String get createTripShort;

  /// No description provided for @newTrip.
  ///
  /// In ar, this message translates to:
  /// **'رحلة جديدة'**
  String get newTrip;

  /// No description provided for @createNewTripSemantic.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء رحلة جديدة'**
  String get createNewTripSemantic;

  /// No description provided for @tripFeeInvoiceTitle.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة رسوم الرحلة'**
  String get tripFeeInvoiceTitle;

  /// No description provided for @seatPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر المقعد'**
  String get seatPrice;

  /// No description provided for @seatsCountLabel.
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد'**
  String get seatsCountLabel;

  /// No description provided for @feePercentage.
  ///
  /// In ar, this message translates to:
  /// **'نسبة الرسوم'**
  String get feePercentage;

  /// No description provided for @totalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get totalLabel;

  /// No description provided for @tripFeeDeductExplanation.
  ///
  /// In ar, this message translates to:
  /// **'سيتم خصم الرسوم من محفظتك وفتح بيانات ركاب هذه الرحلة. لا يتم تغيير عدد المقاعد أو الحجوزات.'**
  String get tripFeeDeductExplanation;

  /// No description provided for @payFees.
  ///
  /// In ar, this message translates to:
  /// **'دفع الرسوم'**
  String get payFees;

  /// No description provided for @tripFeePaidSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم دفع رسوم الرحلة بنجاح'**
  String get tripFeePaidSuccess;

  /// No description provided for @payingInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري الدفع...'**
  String get payingInProgress;

  /// No description provided for @unknownLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقع غير معروف'**
  String get unknownLocation;

  /// No description provided for @tripFromToSemantic.
  ///
  /// In ar, this message translates to:
  /// **'رحلة من {from} إلى {to}'**
  String tripFromToSemantic(String from, String to);

  /// No description provided for @statusActive.
  ///
  /// In ar, this message translates to:
  /// **'نشطة'**
  String get statusActive;

  /// No description provided for @statusDraft.
  ///
  /// In ar, this message translates to:
  /// **'مسودة'**
  String get statusDraft;

  /// No description provided for @statusFullyBooked.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة الحجز'**
  String get statusFullyBooked;

  /// No description provided for @statusInProgress.
  ///
  /// In ar, this message translates to:
  /// **'قيد التنفيذ'**
  String get statusInProgress;

  /// No description provided for @statusHidden.
  ///
  /// In ar, this message translates to:
  /// **'مخفية'**
  String get statusHidden;

  /// No description provided for @statusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get statusCancelled;

  /// No description provided for @statusUnknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get statusUnknown;

  /// No description provided for @fromShort.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get fromShort;

  /// No description provided for @toShort.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get toShort;

  /// No description provided for @perSeatSuffix.
  ///
  /// In ar, this message translates to:
  /// **'/ مقعد'**
  String get perSeatSuffix;

  /// No description provided for @seatsWord.
  ///
  /// In ar, this message translates to:
  /// **'مقاعد'**
  String get seatsWord;

  /// No description provided for @tripFeePaidLabel.
  ///
  /// In ar, this message translates to:
  /// **'رسوم الرحلة مدفوعة'**
  String get tripFeePaidLabel;

  /// No description provided for @passengerDetailsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الراكب'**
  String get passengerDetailsTitle;

  /// No description provided for @seatLabelWithValue.
  ///
  /// In ar, this message translates to:
  /// **'مقعد {seat}'**
  String seatLabelWithValue(String seat);

  /// No description provided for @phoneNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneNumberLabel;

  /// No description provided for @privateChatWithSemantic.
  ///
  /// In ar, this message translates to:
  /// **'محادثة خاصة مع {name}'**
  String privateChatWithSemantic(String name);

  /// No description provided for @privateChat.
  ///
  /// In ar, this message translates to:
  /// **'محادثة خاصة'**
  String get privateChat;

  /// No description provided for @messagePerson.
  ///
  /// In ar, this message translates to:
  /// **'مراسلة {name}'**
  String messagePerson(String name);

  /// No description provided for @confirmFinePayment.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد دفع الغرامة'**
  String get confirmFinePayment;

  /// No description provided for @amountDue.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستحق: {amount} د.أ'**
  String amountDue(String amount);

  /// No description provided for @currentWalletBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة الحالي: {amount} د.أ'**
  String currentWalletBalance(String amount);

  /// No description provided for @balanceAfterPayment.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد بعد الدفع: {amount} د.أ'**
  String balanceAfterPayment(String amount);

  /// No description provided for @confirmAndPay.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد ودفع'**
  String get confirmAndPay;

  /// No description provided for @finePaidSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم دفع الغرامة من محفظتك بنجاح'**
  String get finePaidSuccess;

  /// No description provided for @finePartiallyPaid.
  ///
  /// In ar, this message translates to:
  /// **'تم دفع جزء من الرسوم، تبقى رصيد غير كافٍ للباقي'**
  String get finePartiallyPaid;

  /// No description provided for @insufficientBalanceForFine.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد غير كافٍ لدفع الرسوم'**
  String get insufficientBalanceForFine;

  /// No description provided for @chargeKindDriverNoShow.
  ///
  /// In ar, this message translates to:
  /// **'عدم حضور السائق'**
  String get chargeKindDriverNoShow;

  /// No description provided for @chargeKindPassengerNoShow.
  ///
  /// In ar, this message translates to:
  /// **'عدم حضور الراكب'**
  String get chargeKindPassengerNoShow;

  /// No description provided for @chargeKindLateCancellation.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحجز'**
  String get chargeKindLateCancellation;

  /// No description provided for @chargeStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'مستحق'**
  String get chargeStatusPending;

  /// No description provided for @chargeStatusCollected.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع'**
  String get chargeStatusCollected;

  /// No description provided for @chargeStatusWaived.
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get chargeStatusWaived;

  /// No description provided for @noOutstandingCharges.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسوم مستحقة'**
  String get noOutstandingCharges;

  /// No description provided for @accountInGoodStanding.
  ///
  /// In ar, this message translates to:
  /// **'حسابك خالٍ من الرسوم.'**
  String get accountInGoodStanding;

  /// No description provided for @cannotPublishUntilSettled.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك نشر رحلة جديدة قبل التسوية'**
  String get cannotPublishUntilSettled;

  /// No description provided for @totalDue.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي المستحق: {amount} د.أ'**
  String totalDue(String amount);

  /// No description provided for @walletBalanceAmount.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة: {amount} د.أ'**
  String walletBalanceAmount(String amount);

  /// No description provided for @balanceEnoughForFine.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك يكفي لدفع الغرامة من المحفظة.'**
  String get balanceEnoughForFine;

  /// No description provided for @balanceNotEnoughForFine.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك غير كافٍ — اشحن المحفظة لتسوية الغرامة.'**
  String get balanceNotEnoughForFine;

  /// No description provided for @payFine.
  ///
  /// In ar, this message translates to:
  /// **'ادفع الغرامة'**
  String get payFine;

  /// No description provided for @topUpWallet.
  ///
  /// In ar, this message translates to:
  /// **'شحن المحفظة'**
  String get topUpWallet;

  /// No description provided for @amountAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ: {amount} د.أ'**
  String amountAmount(String amount);

  /// No description provided for @walletTitle.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة'**
  String get walletTitle;

  /// No description provided for @pleaseSignIn.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تسجيل الدخول'**
  String get pleaseSignIn;

  /// No description provided for @txTypeTopup.
  ///
  /// In ar, this message translates to:
  /// **'شحن محفظة'**
  String get txTypeTopup;

  /// No description provided for @txTypeTripPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفع رحلة'**
  String get txTypeTripPayment;

  /// No description provided for @txTypeTripDebit.
  ///
  /// In ar, this message translates to:
  /// **'رسوم رحلة'**
  String get txTypeTripDebit;

  /// No description provided for @txTypeRefund.
  ///
  /// In ar, this message translates to:
  /// **'استرداد'**
  String get txTypeRefund;

  /// No description provided for @txTypePayout.
  ///
  /// In ar, this message translates to:
  /// **'سحب أرباح'**
  String get txTypePayout;

  /// No description provided for @txTypeAdjustment.
  ///
  /// In ar, this message translates to:
  /// **'تعديل رصيد'**
  String get txTypeAdjustment;

  /// No description provided for @txTypeHold.
  ///
  /// In ar, this message translates to:
  /// **'حجز مبلغ'**
  String get txTypeHold;

  /// No description provided for @txTypeReleaseHold.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء حجز'**
  String get txTypeReleaseHold;

  /// No description provided for @transactionsLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل الحركات'**
  String get transactionsLog;

  /// No description provided for @topUpShort.
  ///
  /// In ar, this message translates to:
  /// **'شحن'**
  String get topUpShort;

  /// No description provided for @noTransactionsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركات بعد'**
  String get noTransactionsYet;

  /// No description provided for @pendingChargesShortcutTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرسوم المستحقة'**
  String get pendingChargesShortcutTitle;

  /// No description provided for @pendingChargesShortcutSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'عرض الغرامات والرسوم المعلّقة وشحن المحفظة'**
  String get pendingChargesShortcutSubtitle;

  /// No description provided for @freeTripUsed.
  ///
  /// In ar, this message translates to:
  /// **'تم استخدام الرحلة المجانية'**
  String get freeTripUsed;

  /// No description provided for @freeTripAvailableDriver.
  ///
  /// In ar, this message translates to:
  /// **'لديك رحلة مجانية واحدة لفتح بيانات الركاب'**
  String get freeTripAvailableDriver;

  /// No description provided for @vehicleSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات السيارة'**
  String get vehicleSettingsTitle;

  /// No description provided for @seatLayoutSavedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ تخطيط مقاعد السيارة'**
  String get seatLayoutSavedSuccess;

  /// No description provided for @noVehicleRegistered.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تسجيل سيارة بعد'**
  String get noVehicleRegistered;

  /// No description provided for @noVehicleRegisteredBody.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج إلى تسجيل سيارتك من خلال إكمال ملف السائق قبل تخصيص تخطيط المقاعد.'**
  String get noVehicleRegisteredBody;

  /// No description provided for @vehicleDataSection.
  ///
  /// In ar, this message translates to:
  /// **'بيانات السيارة'**
  String get vehicleDataSection;

  /// No description provided for @vehicleModelLabel.
  ///
  /// In ar, this message translates to:
  /// **'الموديل'**
  String get vehicleModelLabel;

  /// No description provided for @vehicleTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get vehicleTypeLabel;

  /// No description provided for @vehiclePlateNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة'**
  String get vehiclePlateNumberLabel;

  /// No description provided for @registeredSeatsCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد المقاعد المسجل'**
  String get registeredSeatsCount;

  /// No description provided for @seatLayoutSection.
  ///
  /// In ar, this message translates to:
  /// **'تخطيط المقاعد'**
  String get seatLayoutSection;

  /// No description provided for @seatLayoutUsedForAllTrips.
  ///
  /// In ar, this message translates to:
  /// **'هذا التخطيط يُستخدم لكل الرحلات التي تنشئها بهذه السيارة.'**
  String get seatLayoutUsedForAllTrips;

  /// No description provided for @gridSystem.
  ///
  /// In ar, this message translates to:
  /// **'نظام الشبكة'**
  String get gridSystem;

  /// No description provided for @customLayout.
  ///
  /// In ar, this message translates to:
  /// **'توزيع مخصص'**
  String get customLayout;

  /// No description provided for @rowsLabel.
  ///
  /// In ar, this message translates to:
  /// **'الصفوف'**
  String get rowsLabel;

  /// No description provided for @perRowLabel.
  ///
  /// In ar, this message translates to:
  /// **'بكل صف'**
  String get perRowLabel;

  /// No description provided for @setSeatsPerRow.
  ///
  /// In ar, this message translates to:
  /// **'حدد عدد المقاعد في كل صف:'**
  String get setSeatsPerRow;

  /// No description provided for @nextToDriver.
  ///
  /// In ar, this message translates to:
  /// **'بجانب السائق'**
  String get nextToDriver;

  /// No description provided for @rowNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'الصف {number}'**
  String rowNumberLabel(int number);

  /// No description provided for @addNewRow.
  ///
  /// In ar, this message translates to:
  /// **'إضافة صف جديد'**
  String get addNewRow;

  /// No description provided for @preventGenderMixing.
  ///
  /// In ar, this message translates to:
  /// **'منع الاختلاط'**
  String get preventGenderMixing;

  /// No description provided for @saveChangesVehicle.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get saveChangesVehicle;

  /// No description provided for @editingForActiveTripsOnly.
  ///
  /// In ar, this message translates to:
  /// **'التعديل متاح للرحلات النشطة فقط'**
  String get editingForActiveTripsOnly;

  /// No description provided for @bookedSeatsManagedByBookings.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد المحجوزة عبر التطبيق تُدار من طلبات الحجز'**
  String get bookedSeatsManagedByBookings;

  /// No description provided for @openSeatTitle.
  ///
  /// In ar, this message translates to:
  /// **'فتح المقعد'**
  String get openSeatTitle;

  /// No description provided for @openSeatBody.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء قفل المقعد رقم {number} ليصبح متاحاً للحجز في التطبيق؟'**
  String openSeatBody(int number);

  /// No description provided for @openSeat.
  ///
  /// In ar, this message translates to:
  /// **'فتح المقعد'**
  String get openSeat;

  /// No description provided for @seatOpenedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم فتح المقعد'**
  String get seatOpenedSuccess;

  /// No description provided for @lockSeatTitle.
  ///
  /// In ar, this message translates to:
  /// **'قفل المقعد'**
  String get lockSeatTitle;

  /// No description provided for @lockSeatBody.
  ///
  /// In ar, this message translates to:
  /// **'قفل المقعد رقم {number}؟ لن يتمكن الركاب من حجزه في التطبيق (مثلاً إذا بيع خارج التطبيق).'**
  String lockSeatBody(int number);

  /// No description provided for @lockSeat.
  ///
  /// In ar, this message translates to:
  /// **'قفل'**
  String get lockSeat;

  /// No description provided for @seatLockedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم قفل المقعد'**
  String get seatLockedSuccess;

  /// No description provided for @enableLocationRequired.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الموقع مطلوب'**
  String get enableLocationRequired;

  /// No description provided for @enableLocationBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن متابعة الرحلة بدون تشغيل خدمات الموقع. يرجى تفعيل GPS الآن.'**
  String get enableLocationBody;

  /// No description provided for @openLocationSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات الموقع'**
  String get openLocationSettings;

  /// No description provided for @checkAgain.
  ///
  /// In ar, this message translates to:
  /// **'تحقق مجددًا'**
  String get checkAgain;

  /// No description provided for @tripManagementTitle.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الرحلة'**
  String get tripManagementTitle;

  /// No description provided for @freeTripDiscountLabel.
  ///
  /// In ar, this message translates to:
  /// **'خصم الرحلة المجانية'**
  String get freeTripDiscountLabel;

  /// No description provided for @freeTripDiscountValue.
  ///
  /// In ar, this message translates to:
  /// **'-{amount} {currency} (100%)'**
  String freeTripDiscountValue(String amount, String currency);

  /// No description provided for @freeTripAvailableExplanation.
  ///
  /// In ar, this message translates to:
  /// **'لديك رحلة مجانية متاحة. سيتم تطبيق خصم 100% ليصبح الإجمالي 0.'**
  String get freeTripAvailableExplanation;

  /// No description provided for @tripFeeFullExplanation.
  ///
  /// In ar, this message translates to:
  /// **'الدفع يخص رسوم الرحلة كاملة ولا يغير عدد المقاعد أو الحجوزات.'**
  String get tripFeeFullExplanation;

  /// No description provided for @hideTripTitle.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الرحلة'**
  String get hideTripTitle;

  /// No description provided for @hideTripConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من إخفاء هذه الرحلة؟'**
  String get hideTripConfirm;

  /// No description provided for @hideAction.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get hideAction;

  /// No description provided for @tripHiddenSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إخفاء الرحلة بنجاح'**
  String get tripHiddenSuccess;

  /// No description provided for @tripShownSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إظهار الرحلة بنجاح'**
  String get tripShownSuccess;

  /// No description provided for @deleteTripTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الرحلة'**
  String get deleteTripTitle;

  /// No description provided for @deleteTripConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف هذه الرحلة؟ لا يمكن التراجع عن هذا الإجراء.'**
  String get deleteTripConfirm;

  /// No description provided for @deleteAction.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get deleteAction;

  /// No description provided for @tripDeletedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الرحلة بنجاح'**
  String get tripDeletedSuccess;

  /// No description provided for @hideTripTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الرحلة'**
  String get hideTripTooltip;

  /// No description provided for @showTripTooltip.
  ///
  /// In ar, this message translates to:
  /// **'إظهار الرحلة'**
  String get showTripTooltip;

  /// No description provided for @deleteTripTooltip.
  ///
  /// In ar, this message translates to:
  /// **'حذف الرحلة'**
  String get deleteTripTooltip;

  /// No description provided for @walletBalanceWithAmount.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة: {amount} {currency}'**
  String walletBalanceWithAmount(String amount, String currency);

  /// No description provided for @freeTripAvailableShort.
  ///
  /// In ar, this message translates to:
  /// **'رحلة مجانية متاحة'**
  String get freeTripAvailableShort;

  /// No description provided for @balanceFromPlatformWallet.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد من محفظة المنصة (المحفظة الموحدة)'**
  String get balanceFromPlatformWallet;

  /// No description provided for @tripFeeLabel.
  ///
  /// In ar, this message translates to:
  /// **'رسوم الرحلة'**
  String get tripFeeLabel;

  /// No description provided for @tripFeeReady.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة رسوم الرحلة جاهزة'**
  String get tripFeeReady;

  /// No description provided for @tripFeeBreakdownWithFreeTrip.
  ///
  /// In ar, this message translates to:
  /// **'الرسوم: 5% × {seats} مقاعد × {price} {currency}، خصم رحلة مجانية 100% = {amount} {currency}'**
  String tripFeeBreakdownWithFreeTrip(
    int seats,
    String price,
    String currency,
    String amount,
  );

  /// No description provided for @tripFeeBreakdown.
  ///
  /// In ar, this message translates to:
  /// **'5% × {seats} مقاعد × {price} {currency} = {amount} {currency}'**
  String tripFeeBreakdown(
    int seats,
    String price,
    String currency,
    String amount,
  );

  /// No description provided for @applyFreeTrip.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق الرحلة المجانية'**
  String get applyFreeTrip;

  /// No description provided for @pendingBookingsCard.
  ///
  /// In ar, this message translates to:
  /// **'حجوزات قيد التأكيد ({count})'**
  String pendingBookingsCard(int count);

  /// No description provided for @confirmBookingUnlocksDetails.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحجز يفتح بيانات الراكب (رحلة مجانية أو خصم من المحفظة مرة واحدة للرحلة)'**
  String get confirmBookingUnlocksDetails;

  /// No description provided for @passengerFallback.
  ///
  /// In ar, this message translates to:
  /// **'راكب'**
  String get passengerFallback;

  /// No description provided for @seatLabelShort.
  ///
  /// In ar, this message translates to:
  /// **'مقعد {seat}'**
  String seatLabelShort(String seat);

  /// No description provided for @chatAvailableAfterFee.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة والتواصل متاحان بعد دفع رسوم الرحلة'**
  String get chatAvailableAfterFee;

  /// No description provided for @awaitingConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار التأكيد'**
  String get awaitingConfirmation;

  /// No description provided for @seatsWithValue.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد: {seat}'**
  String seatsWithValue(String seat);

  /// No description provided for @pendingConfirmationBadge.
  ///
  /// In ar, this message translates to:
  /// **'قيد التأكيد'**
  String get pendingConfirmationBadge;

  /// No description provided for @passengerDetailsButton.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الراكب'**
  String get passengerDetailsButton;

  /// No description provided for @confirmingInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري التأكيد...'**
  String get confirmingInProgress;

  /// No description provided for @rejectingInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري الرفض...'**
  String get rejectingInProgress;

  /// No description provided for @rejectAction.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get rejectAction;

  /// No description provided for @bookingRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الحجز'**
  String get bookingRejected;

  /// No description provided for @bookedSeatsLabel.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد المحجوزة'**
  String get bookedSeatsLabel;

  /// No description provided for @ofCount.
  ///
  /// In ar, this message translates to:
  /// **'من {count}'**
  String ofCount(int count);

  /// No description provided for @revenueLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإيرادات'**
  String get revenueLabel;

  /// No description provided for @confirmArrivalTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الوصول'**
  String get confirmArrivalTitle;

  /// No description provided for @confirmArrivalBody.
  ///
  /// In ar, this message translates to:
  /// **'هل وصلت إلى الوجهة؟ سيتم إنهاء الرحلة ولن يمكن التراجع.'**
  String get confirmArrivalBody;

  /// No description provided for @yesArrived.
  ///
  /// In ar, this message translates to:
  /// **'نعم، وصلت'**
  String get yesArrived;

  /// No description provided for @tripEndedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إنهاء الرحلة بنجاح.'**
  String get tripEndedSuccess;

  /// No description provided for @autoStartHours.
  ///
  /// In ar, this message translates to:
  /// **'ستبدأ الرحلة تلقائياً عند موعد الانطلاق (بعد ~{hours} ساعة). لا حاجة للضغط على زر بدء.'**
  String autoStartHours(int hours);

  /// No description provided for @autoStartMinutes.
  ///
  /// In ar, this message translates to:
  /// **'ستبدأ الرحلة تلقائياً عند موعد الانطلاق (بعد ~{minutes} دقيقة). لا حاجة للضغط على زر بدء.'**
  String autoStartMinutes(int minutes);

  /// No description provided for @tripWillConvertSoon.
  ///
  /// In ar, this message translates to:
  /// **'سيتم تحويل الرحلة إلى «قيد التنفيذ» تلقائياً خلال لحظات.'**
  String get tripWillConvertSoon;

  /// No description provided for @startTripSection.
  ///
  /// In ar, this message translates to:
  /// **'بدء الرحلة'**
  String get startTripSection;

  /// No description provided for @endTripSection.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الرحلة'**
  String get endTripSection;

  /// No description provided for @endTripHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط «تم الوصول للوجهة» بعد إنزال الركاب لإنهاء الرحلة.'**
  String get endTripHint;

  /// No description provided for @endingInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري الإنهاء...'**
  String get endingInProgress;

  /// No description provided for @arrivedAtDestination.
  ///
  /// In ar, this message translates to:
  /// **'تم الوصول للوجهة'**
  String get arrivedAtDestination;

  /// No description provided for @tripStatusLabel.
  ///
  /// In ar, this message translates to:
  /// **'حالة الرحلة'**
  String get tripStatusLabel;

  /// No description provided for @departureTimeDetailLabel.
  ///
  /// In ar, this message translates to:
  /// **'وقت الانطلاق'**
  String get departureTimeDetailLabel;

  /// No description provided for @pricePerSeatLabel.
  ///
  /// In ar, this message translates to:
  /// **'السعر لكل مقعد'**
  String get pricePerSeatLabel;

  /// No description provided for @seatsDetailLabel.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد'**
  String get seatsDetailLabel;

  /// No description provided for @seatsAvailableTotal.
  ///
  /// In ar, this message translates to:
  /// **'{available} متاح / {total} إجمالي'**
  String seatsAvailableTotal(int available, int total);

  /// No description provided for @seatLayoutDetailLabel.
  ///
  /// In ar, this message translates to:
  /// **'تخطيط المقاعد'**
  String get seatLayoutDetailLabel;

  /// No description provided for @yesLabel.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get yesLabel;

  /// No description provided for @noLabel.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get noLabel;

  /// No description provided for @seatLayoutCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'تخطيط المقاعد'**
  String get seatLayoutCardTitle;

  /// No description provided for @seatLayoutLongPressHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطولاً على مقعد أخضر لقفله (حجز خارجي)، أو على مقعد مقفل لفتحه.'**
  String get seatLayoutLongPressHint;

  /// No description provided for @driverSeat.
  ///
  /// In ar, this message translates to:
  /// **'مقعد السائق'**
  String get driverSeat;

  /// No description provided for @legendAvailable.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get legendAvailable;

  /// No description provided for @legendLocked.
  ///
  /// In ar, this message translates to:
  /// **'مقفل'**
  String get legendLocked;

  /// No description provided for @legendBookedMale.
  ///
  /// In ar, this message translates to:
  /// **'محجوز - رجل'**
  String get legendBookedMale;

  /// No description provided for @legendBookedFemale.
  ///
  /// In ar, this message translates to:
  /// **'محجوز - أنثى'**
  String get legendBookedFemale;

  /// No description provided for @passengersCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'الركاب ({count})'**
  String passengersCardTitle(int count);

  /// No description provided for @anonymousPassenger.
  ///
  /// In ar, this message translates to:
  /// **'راكب مجهول'**
  String get anonymousPassenger;

  /// No description provided for @confirmedBadge.
  ///
  /// In ar, this message translates to:
  /// **'مؤكد'**
  String get confirmedBadge;

  /// No description provided for @imageLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحميل الصورة'**
  String get imageLoadFailed;

  /// No description provided for @quickActionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get quickActionsTitle;

  /// No description provided for @shareAction.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get shareAction;

  /// No description provided for @shareFeatureComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريباً: ميزة المشاركة'**
  String get shareFeatureComingSoon;

  /// No description provided for @editAction.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get editAction;

  /// No description provided for @carImage.
  ///
  /// In ar, this message translates to:
  /// **'صورة السيارة'**
  String get carImage;

  /// No description provided for @passengersWithCount.
  ///
  /// In ar, this message translates to:
  /// **'الركاب ({count})'**
  String passengersWithCount(int count);

  /// No description provided for @passengerLabel.
  ///
  /// In ar, this message translates to:
  /// **'راكب'**
  String get passengerLabel;

  /// No description provided for @seatNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'مقعد {number}'**
  String seatNumberLabel(Object number);

  /// No description provided for @confirmedLabel.
  ///
  /// In ar, this message translates to:
  /// **'مؤكد'**
  String get confirmedLabel;

  /// No description provided for @pendingBookingsWithCount.
  ///
  /// In ar, this message translates to:
  /// **'حجوزات قيد التأكيد ({count})'**
  String pendingBookingsWithCount(int count);

  /// No description provided for @pendingBookingHint.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحجز يفتح بيانات الراكب (رحلة مجانية أو خصم من المحفظة مرة واحدة للرحلة)'**
  String get pendingBookingHint;

  /// No description provided for @pendingConfirmation.
  ///
  /// In ar, this message translates to:
  /// **'قيد التأكيد'**
  String get pendingConfirmation;

  /// No description provided for @confirmingBooking.
  ///
  /// In ar, this message translates to:
  /// **'جاري التأكيد...'**
  String get confirmingBooking;

  /// No description provided for @quickActions.
  ///
  /// In ar, this message translates to:
  /// **'إجراءات سريعة'**
  String get quickActions;

  /// No description provided for @bookedSeats.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد المحجوزة'**
  String get bookedSeats;

  /// No description provided for @ofTotalSeats.
  ///
  /// In ar, this message translates to:
  /// **'من {total}'**
  String ofTotalSeats(Object total);

  /// No description provided for @revenue.
  ///
  /// In ar, this message translates to:
  /// **'الإيرادات'**
  String get revenue;

  /// No description provided for @tripDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة'**
  String get tripDetails;

  /// No description provided for @tripDistance.
  ///
  /// In ar, this message translates to:
  /// **'مسافة الرحلة'**
  String get tripDistance;

  /// No description provided for @distanceInKm.
  ///
  /// In ar, this message translates to:
  /// **'{distance} كم'**
  String distanceInKm(String distance);

  /// No description provided for @seatsLabel.
  ///
  /// In ar, this message translates to:
  /// **'المقاعد'**
  String get seatsLabel;

  /// No description provided for @availableOfTotalSeats.
  ///
  /// In ar, this message translates to:
  /// **'{available} متاح / {total} إجمالي'**
  String availableOfTotalSeats(Object available, Object total);

  /// No description provided for @seatLayout.
  ///
  /// In ar, this message translates to:
  /// **'تخطيط المقاعد'**
  String get seatLayout;

  /// No description provided for @tripInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات الرحلة'**
  String get tripInfo;

  /// No description provided for @tripStatusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get tripStatusCompleted;

  /// No description provided for @tripStatusUnknown.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get tripStatusUnknown;

  /// No description provided for @tripStatusTitle.
  ///
  /// In ar, this message translates to:
  /// **'حالة الرحلة'**
  String get tripStatusTitle;

  /// No description provided for @freeTripAvailable.
  ///
  /// In ar, this message translates to:
  /// **'رحلة مجانية متاحة'**
  String get freeTripAvailable;

  /// No description provided for @markAllNotificationsRead.
  ///
  /// In ar, this message translates to:
  /// **'قراءة جميع الإشعارات ({count} غير مقروء)'**
  String markAllNotificationsRead(int count);

  /// No description provided for @allNotificationsRead.
  ///
  /// In ar, this message translates to:
  /// **'تم قراءة جميع الإشعارات'**
  String get allNotificationsRead;

  /// No description provided for @markAllReadCount.
  ///
  /// In ar, this message translates to:
  /// **'قراءة الكل ({count})'**
  String markAllReadCount(int count);

  /// No description provided for @notificationsWillAppearHere.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر الإشعارات هنا عند وصولها'**
  String get notificationsWillAppearHere;

  /// No description provided for @manualPaymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدفع اليدوي'**
  String get manualPaymentTitle;

  /// No description provided for @completePayment.
  ///
  /// In ar, this message translates to:
  /// **'إتمام الدفع'**
  String get completePayment;

  /// No description provided for @walletType.
  ///
  /// In ar, this message translates to:
  /// **'نوع المحفظة'**
  String get walletType;

  /// No description provided for @walletTypeOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get walletTypeOther;

  /// No description provided for @jordan.
  ///
  /// In ar, this message translates to:
  /// **'الأردن'**
  String get jordan;

  /// No description provided for @walletNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم المحفظة'**
  String get walletNumber;

  /// No description provided for @walletNumberHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 0791234567'**
  String get walletNumberHint;

  /// No description provided for @walletNumberRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال رقم المحفظة'**
  String get walletNumberRequired;

  /// No description provided for @walletNumberTooShort.
  ///
  /// In ar, this message translates to:
  /// **'رقم المحفظة يجب أن يكون 8 أرقام على الأقل'**
  String get walletNumberTooShort;

  /// No description provided for @paymentProofImage.
  ///
  /// In ar, this message translates to:
  /// **'صورة إثبات الدفع'**
  String get paymentProofImage;

  /// No description provided for @requiredLabel.
  ///
  /// In ar, this message translates to:
  /// **'(مطلوب)'**
  String get requiredLabel;

  /// No description provided for @requiredWord.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get requiredWord;

  /// No description provided for @uploadPaymentProof.
  ///
  /// In ar, this message translates to:
  /// **'رفع صورة إثبات الدفع'**
  String get uploadPaymentProof;

  /// No description provided for @tapToUploadPaymentProof.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لرفع صورة إثبات الدفع'**
  String get tapToUploadPaymentProof;

  /// No description provided for @notesLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notesLabel;

  /// No description provided for @additionalNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات إضافية'**
  String get additionalNotes;

  /// No description provided for @additionalNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'أي معلومات إضافية...'**
  String get additionalNotesHint;

  /// No description provided for @submitPaymentRequest.
  ///
  /// In ar, this message translates to:
  /// **'إرسال طلب الدفع'**
  String get submitPaymentRequest;

  /// No description provided for @paymentTabAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get paymentTabAll;

  /// No description provided for @paymentStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get paymentStatusPending;

  /// No description provided for @paymentStatusApproved.
  ///
  /// In ar, this message translates to:
  /// **'مقبولة'**
  String get paymentStatusApproved;

  /// No description provided for @paymentStatusRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوضة'**
  String get paymentStatusRejected;

  /// No description provided for @paymentStatusRefunded.
  ///
  /// In ar, this message translates to:
  /// **'مستردة'**
  String get paymentStatusRefunded;

  /// No description provided for @errorLoadingData.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في تحميل البيانات'**
  String get errorLoadingData;

  /// No description provided for @noPayments.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مدفوعات'**
  String get noPayments;

  /// No description provided for @paymentMethodWallet.
  ///
  /// In ar, this message translates to:
  /// **'محفظة التطبيق'**
  String get paymentMethodWallet;

  /// No description provided for @paymentMethodManual.
  ///
  /// In ar, this message translates to:
  /// **'محفظة إلكترونية'**
  String get paymentMethodManual;

  /// No description provided for @paymentMethodCommunicationFee.
  ///
  /// In ar, this message translates to:
  /// **'رسوم تواصل'**
  String get paymentMethodCommunicationFee;

  /// No description provided for @amountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get amountLabel;

  /// No description provided for @purposeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الغرض'**
  String get purposeLabel;

  /// No description provided for @communicationUnlockFee.
  ///
  /// In ar, this message translates to:
  /// **'رسوم فتح التواصل'**
  String get communicationUnlockFee;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get paymentMethodLabel;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الملف الشخصي بنجاح'**
  String get profileUpdatedSuccess;

  /// No description provided for @gallery.
  ///
  /// In ar, this message translates to:
  /// **'المعرض'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get camera;

  /// No description provided for @editProfileTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get editProfileTitle;

  /// No description provided for @chooseProfilePhoto.
  ///
  /// In ar, this message translates to:
  /// **'اختر صورة الملف الشخصي'**
  String get chooseProfilePhoto;

  /// No description provided for @changeProfilePhoto.
  ///
  /// In ar, this message translates to:
  /// **'تغيير صورة الملف الشخصي'**
  String get changeProfilePhoto;

  /// No description provided for @hidePhoneFromDriver.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء رقم الهاتف عن السائق'**
  String get hidePhoneFromDriver;

  /// No description provided for @loadingVersion.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل الإصدار...'**
  String get loadingVersion;

  /// No description provided for @versionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String versionLabel(String version);

  /// No description provided for @aboutAppTagline.
  ///
  /// In ar, this message translates to:
  /// **'منصة تنقل ذكية تربط السائقين والركاب بتجربة عربية واضحة، سريعة، وموثوقة.'**
  String get aboutAppTagline;

  /// No description provided for @whatMakesVisionWaySpecial.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي يميز VisionWay؟'**
  String get whatMakesVisionWaySpecial;

  /// No description provided for @aboutFeatureArabicFirst.
  ///
  /// In ar, this message translates to:
  /// **'واجهة عربية أولًا مع تجربة استخدام واضحة وسريعة.'**
  String get aboutFeatureArabicFirst;

  /// No description provided for @aboutFeatureFlexibleManagement.
  ///
  /// In ar, this message translates to:
  /// **'إدارة مرنة للرحلات والحجوزات والتواصل بين السائق والراكب.'**
  String get aboutFeatureFlexibleManagement;

  /// No description provided for @aboutFeatureTrustDesign.
  ///
  /// In ar, this message translates to:
  /// **'تصميم يركز على الثقة والبساطة وسهولة الوصول للمعلومات المهمة.'**
  String get aboutFeatureTrustDesign;

  /// No description provided for @revokeDeviceTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الجهاز'**
  String get revokeDeviceTitle;

  /// No description provided for @revokeDeviceMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من إلغاء هذا الجهاز؟ ستحتاج إلى تسجيل الدخول مرة أخرى على هذا الجهاز.'**
  String get revokeDeviceMessage;

  /// No description provided for @deviceRevokedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الجهاز بنجاح'**
  String get deviceRevokedSuccess;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @noDevicesRegistered.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أجهزة مسجلة'**
  String get noDevicesRegistered;

  /// No description provided for @deviceLastSeen.
  ///
  /// In ar, this message translates to:
  /// **'آخر نشاط: {date}'**
  String deviceLastSeen(String date);

  /// No description provided for @deviceCurrentBadge.
  ///
  /// In ar, this message translates to:
  /// **'الحالي'**
  String get deviceCurrentBadge;

  /// No description provided for @roleDriver.
  ///
  /// In ar, this message translates to:
  /// **'سائق'**
  String get roleDriver;

  /// No description provided for @rolePassenger.
  ///
  /// In ar, this message translates to:
  /// **'راكب'**
  String get rolePassenger;

  /// No description provided for @manageDevices.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الأجهزة'**
  String get manageDevices;

  /// No description provided for @manageDevicesSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'عرض وإلغاء الأجهزة المرتبطة بحسابك'**
  String get manageDevicesSubtitle;

  /// No description provided for @enterNewPassword.
  ///
  /// In ar, this message translates to:
  /// **'يرجى إدخال كلمة المرور الجديدة'**
  String get enterNewPassword;

  /// No description provided for @passwordChangedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور'**
  String get passwordChangedTitle;

  /// No description provided for @passwordChangedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور بنجاح. يرجى تسجيل الدخول مرة أخرى.'**
  String get passwordChangedMessage;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة المرور الحالية وكلمة المرور الجديدة'**
  String get changePasswordSubtitle;

  /// No description provided for @currentPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الحالية'**
  String get currentPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور الجديدة'**
  String get confirmNewPassword;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In ar, this message translates to:
  /// **'قوية'**
  String get passwordStrengthStrong;

  /// No description provided for @passwordStrengthMedium.
  ///
  /// In ar, this message translates to:
  /// **'متوسطة'**
  String get passwordStrengthMedium;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In ar, this message translates to:
  /// **'ضعيفة'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordPolicyHint.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن تكون 8 أحرف على الأقل مع حرف ورقم'**
  String get passwordPolicyHint;

  /// No description provided for @deleteAccountSecondTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف'**
  String get deleteAccountSecondTitle;

  /// No description provided for @driverSection.
  ///
  /// In ar, this message translates to:
  /// **'السائق'**
  String get driverSection;

  /// No description provided for @vehicleAndSeatLayout.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات السيارة وتخطيط المقاعد'**
  String get vehicleAndSeatLayout;

  /// No description provided for @supportNumberUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'رقم الدعم غير متاح حاليًا'**
  String get supportNumberUnavailable;

  /// No description provided for @supportWhatsAppPrefill.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، أحتاج مساعدة في تطبيق VisionWay.'**
  String get supportWhatsAppPrefill;

  /// No description provided for @cannotOpenWhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح WhatsApp'**
  String get cannotOpenWhatsApp;

  /// No description provided for @cannotOpenEmailApp.
  ///
  /// In ar, this message translates to:
  /// **'تعذر فتح تطبيق البريد الإلكتروني'**
  String get cannotOpenEmailApp;

  /// No description provided for @supportEmailCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ بريد الدعم'**
  String get supportEmailCopied;

  /// No description provided for @supportHeroTitle.
  ///
  /// In ar, this message translates to:
  /// **'نحن هنا لمساعدتك'**
  String get supportHeroTitle;

  /// No description provided for @supportHeroSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'إذا واجهتك مشكلة في الحجز أو الحساب أو المدفوعات، يمكنك التواصل مباشرة مع فريق VisionWay.'**
  String get supportHeroSubtitle;

  /// No description provided for @supportContactEmailTitle.
  ///
  /// In ar, this message translates to:
  /// **'راسلنا عبر البريد الإلكتروني'**
  String get supportContactEmailTitle;

  /// No description provided for @supportContactEmailDescription.
  ///
  /// In ar, this message translates to:
  /// **'أرسل استفسارك وسنراجع الرسالة في أقرب وقت ممكن.'**
  String get supportContactEmailDescription;

  /// No description provided for @supportSendEmail.
  ///
  /// In ar, this message translates to:
  /// **'إرسال بريد'**
  String get supportSendEmail;

  /// No description provided for @supportCopyEmail.
  ///
  /// In ar, this message translates to:
  /// **'نسخ البريد'**
  String get supportCopyEmail;

  /// No description provided for @supportContactWhatsAppTitle.
  ///
  /// In ar, this message translates to:
  /// **'راسلنا عبر WhatsApp'**
  String get supportContactWhatsAppTitle;

  /// No description provided for @supportContactWhatsAppDescription.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مباشرة مع فريق الدعم عبر WhatsApp للحصول على مساعدة فورية.'**
  String get supportContactWhatsAppDescription;

  /// No description provided for @supportHowWeHelpTitle.
  ///
  /// In ar, this message translates to:
  /// **'كيف نساعدك؟'**
  String get supportHowWeHelpTitle;

  /// No description provided for @supportHelpItemLogin.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة في تسجيل الدخول أو تحديث بيانات الحساب'**
  String get supportHelpItemLogin;

  /// No description provided for @supportHelpItemBookings.
  ///
  /// In ar, this message translates to:
  /// **'استفسارات الحجز والرحلات والمدفوعات'**
  String get supportHelpItemBookings;

  /// No description provided for @supportHelpItemTechnical.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة المشاكل الفنية أو الاقتراحات'**
  String get supportHelpItemTechnical;

  /// No description provided for @supportQuickTipTitle.
  ///
  /// In ar, this message translates to:
  /// **'نصيحة سريعة'**
  String get supportQuickTipTitle;

  /// No description provided for @supportTipIncludeContact.
  ///
  /// In ar, this message translates to:
  /// **'اذكر رقم الهاتف أو البريد المسجل داخل التطبيق لتسريع المراجعة.'**
  String get supportTipIncludeContact;

  /// No description provided for @supportTipDescribeProblem.
  ///
  /// In ar, this message translates to:
  /// **'أضف وصفًا مختصرًا للمشكلة والخطوات التي حدثت قبلها.'**
  String get supportTipDescribeProblem;

  /// No description provided for @enterValidAmount.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغاً صحيحاً'**
  String get enterValidAmount;

  /// No description provided for @uploadTransferProofRequired.
  ///
  /// In ar, this message translates to:
  /// **'يرجى رفع صورة إثبات التحويل'**
  String get uploadTransferProofRequired;

  /// No description provided for @enterCliqAliasValue.
  ///
  /// In ar, this message translates to:
  /// **'أدخل قيمة الـ CliQ alias'**
  String get enterCliqAliasValue;

  /// No description provided for @topupRequestSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب الشحن. سيُضاف الرصيد بعد التحقق من التحويل'**
  String get topupRequestSent;

  /// No description provided for @verifyingPaymentStatus.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحقق من حالة الدفع...'**
  String get verifyingPaymentStatus;

  /// No description provided for @verifyingPaymentStatusProgress.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحقق من حالة الدفع... ({attempt}/{total})'**
  String verifyingPaymentStatusProgress(int attempt, int total);

  /// No description provided for @walletToppedUpViaCliq.
  ///
  /// In ar, this message translates to:
  /// **'تم شحن المحفظة بنجاح عبر CliQ'**
  String get walletToppedUpViaCliq;

  /// No description provided for @cliqPaymentFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشلت عملية الدفع عبر CliQ'**
  String get cliqPaymentFailed;

  /// No description provided for @cliqPaymentFailedWithNote.
  ///
  /// In ar, this message translates to:
  /// **'فشلت عملية الدفع: {note}'**
  String cliqPaymentFailedWithNote(String note);

  /// No description provided for @connectionTemporarilyFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال مؤقتاً ({attempt}/{total}). إعادة المحاولة...'**
  String connectionTemporarilyFailed(int attempt, int total);

  /// No description provided for @cannotVerifyPayment.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق من الدفع: {detail}'**
  String cannotVerifyPayment(String detail);

  /// No description provided for @verificationTimedOut.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقت التحقق. إذا اكتمل الدفع عند CliQ سيظهر الرصيد خلال دقائق، أو تحقق من سجل المدفوعات.'**
  String get verificationTimedOut;

  /// No description provided for @walletTopupTitle.
  ///
  /// In ar, this message translates to:
  /// **'شحن المحفظة'**
  String get walletTopupTitle;

  /// No description provided for @pleaseWaitDoNotClose.
  ///
  /// In ar, this message translates to:
  /// **'يرجى الانتظار وعدم إغلاق الشاشة'**
  String get pleaseWaitDoNotClose;

  /// No description provided for @topupMethodManual.
  ///
  /// In ar, this message translates to:
  /// **'تحويل يدوي'**
  String get topupMethodManual;

  /// No description provided for @topupManualDescription.
  ///
  /// In ar, this message translates to:
  /// **'حوّل المبلغ إلى حساب المنصة ثم أدخل المبلغ وارفع صورة واضحة للتحويل. لا يُضاف رصيد تلقائياً قبل مراجعة الطلب.'**
  String get topupManualDescription;

  /// No description provided for @topupCliqDescription.
  ///
  /// In ar, this message translates to:
  /// **'سيتم الدفع مباشرة عبر نظام CliQ. أدخل المبلغ وبيانات حسابك في CliQ وسيُضاف الرصيد تلقائياً عند تأكيد الدفع.'**
  String get topupCliqDescription;

  /// No description provided for @amountWithCurrency.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ ({currency})'**
  String amountWithCurrency(String currency);

  /// No description provided for @transactionReferenceOptional.
  ///
  /// In ar, this message translates to:
  /// **'رقم العملية / المرجع (اختياري)'**
  String get transactionReferenceOptional;

  /// No description provided for @ifAvailable.
  ///
  /// In ar, this message translates to:
  /// **'إن وُجد'**
  String get ifAvailable;

  /// No description provided for @uploadTransferProof.
  ///
  /// In ar, this message translates to:
  /// **'رفع صورة إثبات التحويل'**
  String get uploadTransferProof;

  /// No description provided for @imageSelected.
  ///
  /// In ar, this message translates to:
  /// **'تم اختيار صورة'**
  String get imageSelected;

  /// No description provided for @aliasType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الـ Alias'**
  String get aliasType;

  /// No description provided for @mobileNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الموبايل'**
  String get mobileNumber;

  /// No description provided for @aliasName.
  ///
  /// In ar, this message translates to:
  /// **'اسم مستعار'**
  String get aliasName;

  /// No description provided for @aliasNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم المستعار (Alias)'**
  String get aliasNameLabel;

  /// No description provided for @mobileNumberHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 00962XXXXXXXXX'**
  String get mobileNumberHint;

  /// No description provided for @aliasNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: yourname@cliq'**
  String get aliasNameHint;

  /// No description provided for @enterMobileNumber.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الموبايل'**
  String get enterMobileNumber;

  /// No description provided for @enterAliasName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الاسم المستعار'**
  String get enterAliasName;

  /// No description provided for @submitTopupRequest.
  ///
  /// In ar, this message translates to:
  /// **'إرسال طلب الشحن'**
  String get submitTopupRequest;

  /// No description provided for @payViaCliq.
  ///
  /// In ar, this message translates to:
  /// **'الدفع عبر CliQ'**
  String get payViaCliq;

  /// No description provided for @chatYourMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالتك'**
  String get chatYourMessage;

  /// No description provided for @chatMessageFrom.
  ///
  /// In ar, this message translates to:
  /// **'رسالة من {name}'**
  String chatMessageFrom(String name);

  /// No description provided for @chatYesterdayAt.
  ///
  /// In ar, this message translates to:
  /// **'أمس {time}'**
  String chatYesterdayAt(String time);

  /// No description provided for @chatDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{count} أيام'**
  String chatDaysAgo(int count);

  /// No description provided for @countryCodePickerSemantic.
  ///
  /// In ar, this message translates to:
  /// **'اختر رمز الدولة، الحالي: {country}'**
  String countryCodePickerSemantic(String country);

  /// No description provided for @selectCountry.
  ///
  /// In ar, this message translates to:
  /// **'اختر الدولة'**
  String get selectCountry;

  /// No description provided for @searchCountryHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو رمز الدولة...'**
  String get searchCountryHint;

  /// No description provided for @locationDefaultAmman.
  ///
  /// In ar, this message translates to:
  /// **'عمّان، الأردن'**
  String get locationDefaultAmman;

  /// No description provided for @locationCurrentUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذر الحصول على الموقع الحالي.'**
  String get locationCurrentUnavailable;

  /// No description provided for @locationServicesDisabledEnableGps.
  ///
  /// In ar, this message translates to:
  /// **'خدمات الموقع معطلة. يرجى تفعيل GPS.'**
  String get locationServicesDisabledEnableGps;

  /// No description provided for @locationEnable.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get locationEnable;

  /// No description provided for @locationGrantPermission.
  ///
  /// In ar, this message translates to:
  /// **'منح التصريح'**
  String get locationGrantPermission;

  /// No description provided for @locationSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get locationSettings;

  /// No description provided for @locationUnknown.
  ///
  /// In ar, this message translates to:
  /// **'موقع غير معروف'**
  String get locationUnknown;

  /// No description provided for @locationGetError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في الحصول على الموقع.'**
  String get locationGetError;

  /// No description provided for @locationGrant.
  ///
  /// In ar, this message translates to:
  /// **'منح'**
  String get locationGrant;

  /// No description provided for @locationPermissionDeniedPermanently.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض التصريح بشكل دائم.'**
  String get locationPermissionDeniedPermanently;

  /// No description provided for @locationSearchNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على نتائج. جرّب اسم مكان أو عنوان أوضح.'**
  String get locationSearchNoResults;

  /// No description provided for @locationSearchError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في البحث: {error}'**
  String locationSearchError(String error);

  /// No description provided for @locationUseCurrent.
  ///
  /// In ar, this message translates to:
  /// **'استخدام الموقع الحالي'**
  String get locationUseCurrent;

  /// No description provided for @locationSearchSemantic.
  ///
  /// In ar, this message translates to:
  /// **'البحث عن مكان أو عنوان'**
  String get locationSearchSemantic;

  /// No description provided for @locationSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مكان أو عنوان...'**
  String get locationSearchHint;

  /// No description provided for @locationSearchOnMap.
  ///
  /// In ar, this message translates to:
  /// **'بحث على الخريطة'**
  String get locationSearchOnMap;

  /// No description provided for @locationLoadingMap.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل الخريطة...'**
  String get locationLoadingMap;

  /// No description provided for @locationMapLoadError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في تحميل الخريطة'**
  String get locationMapLoadError;

  /// No description provided for @locationPickOnMap.
  ///
  /// In ar, this message translates to:
  /// **'اختر موقعاً على الخريطة'**
  String get locationPickOnMap;

  /// No description provided for @locationConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الموقع'**
  String get locationConfirm;

  /// No description provided for @notificationDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الإشعار'**
  String get notificationDeleted;

  /// No description provided for @notificationsWithUnread.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات ({count} غير مقروء)'**
  String notificationsWithUnread(int count);

  /// No description provided for @ratingStars.
  ///
  /// In ar, this message translates to:
  /// **'{count} نجوم'**
  String ratingStars(int count);

  /// No description provided for @ratingStarsSelected.
  ///
  /// In ar, this message translates to:
  /// **'{count} نجوم (مختارة)'**
  String ratingStarsSelected(int count);

  /// No description provided for @seatDriverSeat.
  ///
  /// In ar, this message translates to:
  /// **'مقعد السائق'**
  String get seatDriverSeat;

  /// No description provided for @seatStatusAvailable.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get seatStatusAvailable;

  /// No description provided for @seatStatusBooked.
  ///
  /// In ar, this message translates to:
  /// **'محجوز'**
  String get seatStatusBooked;

  /// No description provided for @seatStatusLocked.
  ///
  /// In ar, this message translates to:
  /// **'مقفل'**
  String get seatStatusLocked;

  /// No description provided for @seatStatusUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get seatStatusUnavailable;

  /// No description provided for @seatStatusInvalid.
  ///
  /// In ar, this message translates to:
  /// **'غير صالح'**
  String get seatStatusInvalid;

  /// No description provided for @seatLabelSelected.
  ///
  /// In ar, this message translates to:
  /// **'مقعد {number} {status}، محدد'**
  String seatLabelSelected(int number, String status);

  /// No description provided for @seatLegendSelected.
  ///
  /// In ar, this message translates to:
  /// **'محدد'**
  String get seatLegendSelected;

  /// No description provided for @seatLegendLockedExternal.
  ///
  /// In ar, this message translates to:
  /// **'مقفل (خارج التطبيق)'**
  String get seatLegendLockedExternal;

  /// No description provided for @seatColorGuide.
  ///
  /// In ar, this message translates to:
  /// **'دليل الألوان: {label}'**
  String seatColorGuide(String label);

  /// No description provided for @walletBalanceWithValue.
  ///
  /// In ar, this message translates to:
  /// **'رصيد المحفظة: {balance} {currency}'**
  String walletBalanceWithValue(String balance, String currency);

  /// No description provided for @seatLabelNumbered.
  ///
  /// In ar, this message translates to:
  /// **'مقعد {number} {status}'**
  String seatLabelNumbered(int number, String status);

  /// No description provided for @accountBannedNoReason.
  ///
  /// In ar, this message translates to:
  /// **'تم تعليق حسابك. تواصل مع الدعم لمزيد من التفاصيل.'**
  String get accountBannedNoReason;

  /// No description provided for @bannedWhatsAppPrefill.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً، حسابي على تطبيق VisionWay موقوف وأحتاج مساعدة.'**
  String get bannedWhatsAppPrefill;

  /// No description provided for @followUs.
  ///
  /// In ar, this message translates to:
  /// **'تابعنا'**
  String get followUs;

  /// No description provided for @followOnFacebook.
  ///
  /// In ar, this message translates to:
  /// **'فيسبوك'**
  String get followOnFacebook;

  /// No description provided for @followOnLinkedIn.
  ///
  /// In ar, this message translates to:
  /// **'لينكدإن'**
  String get followOnLinkedIn;

  /// No description provided for @tripGroupChat.
  ///
  /// In ar, this message translates to:
  /// **'محادثة جماعية للرحلة'**
  String get tripGroupChat;

  /// No description provided for @groupChatMembersCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} مشارك'**
  String groupChatMembersCount(int count);

  /// No description provided for @shareTripTrackingTitle.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة تتبع الرحلة'**
  String get shareTripTrackingTitle;

  /// No description provided for @shareTripTrackingMessage.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد مشاركة تتبع رحلتك المباشر مع أحد؟'**
  String get shareTripTrackingMessage;

  /// No description provided for @shareTripTrackingAction.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get shareTripTrackingAction;

  /// No description provided for @shareTripTrackingLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get shareTripTrackingLater;

  /// No description provided for @shareTripTrackingText.
  ///
  /// In ar, this message translates to:
  /// **'تابع رحلتي المباشرة عبر هذا الرابط: {url}'**
  String shareTripTrackingText(String url);

  /// No description provided for @shareTripTrackingError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء رابط المشاركة'**
  String get shareTripTrackingError;

  /// No description provided for @locationAutocompleteSuggestions.
  ///
  /// In ar, this message translates to:
  /// **'اقتراحات الأماكن'**
  String get locationAutocompleteSuggestions;

  /// No description provided for @locationAutocompleteNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أماكن مطابقة. حدد الموقع على الخريطة بدلا من ذلك.'**
  String get locationAutocompleteNoResults;

  /// No description provided for @instantRidesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات المباشرة'**
  String get instantRidesTitle;

  /// No description provided for @instantOnlineReady.
  ///
  /// In ar, this message translates to:
  /// **'متصل — جاهز لاستقبال الطلبات'**
  String get instantOnlineReady;

  /// No description provided for @instantOffline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get instantOffline;

  /// No description provided for @instantOfferTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب رحلة مباشرة'**
  String get instantOfferTitle;

  /// No description provided for @instantRideAcceptedToast.
  ///
  /// In ar, this message translates to:
  /// **'تم قبول الرحلة. توجّه إلى نقطة الانطلاق.'**
  String get instantRideAcceptedToast;

  /// No description provided for @instantOfferCountdown.
  ///
  /// In ar, this message translates to:
  /// **'تنتهي خلال {seconds} ثانية'**
  String instantOfferCountdown(int seconds);

  /// No description provided for @instantDecline.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get instantDecline;

  /// No description provided for @instantAccept.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get instantAccept;

  /// No description provided for @instantRequestNow.
  ///
  /// In ar, this message translates to:
  /// **'اطلب الآن'**
  String get instantRequestNow;

  /// No description provided for @instantRequestNowTitle.
  ///
  /// In ar, this message translates to:
  /// **'اطلب رحلة الآن'**
  String get instantRequestNowTitle;

  /// No description provided for @instantRequestNowSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سائق قريب يصل إليك مباشرة'**
  String get instantRequestNowSubtitle;

  /// No description provided for @instantSelectFromTo.
  ///
  /// In ar, this message translates to:
  /// **'اختر نقطة الانطلاق والوصول.'**
  String get instantSelectFromTo;

  /// No description provided for @instantFromHint.
  ///
  /// In ar, this message translates to:
  /// **'مكان الانطلاق'**
  String get instantFromHint;

  /// No description provided for @instantFromPickerTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر نقطة الانطلاق'**
  String get instantFromPickerTitle;

  /// No description provided for @instantToHint.
  ///
  /// In ar, this message translates to:
  /// **'مكان الوصول'**
  String get instantToHint;

  /// No description provided for @instantToPickerTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر نقطة الوصول'**
  String get instantToPickerTitle;

  /// No description provided for @instantDriverFound.
  ///
  /// In ar, this message translates to:
  /// **'تم العثور على سائق!'**
  String get instantDriverFound;

  /// No description provided for @instantDriverOnTheWay.
  ///
  /// In ar, this message translates to:
  /// **'السائق في طريقه إلى نقطة الانطلاق.'**
  String get instantDriverOnTheWay;

  /// No description provided for @instantTrackTrip.
  ///
  /// In ar, this message translates to:
  /// **'تتبّع الرحلة'**
  String get instantTrackTrip;

  /// No description provided for @instantDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get instantDone;

  /// No description provided for @instantRequestCancelled.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي الطلب'**
  String get instantRequestCancelled;

  /// No description provided for @instantNoDrivers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سائق متاح'**
  String get instantNoDrivers;

  /// No description provided for @instantNoDriversSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من إيجاد سائق قريب الآن. يمكنك المحاولة مرة أخرى.'**
  String get instantNoDriversSubtitle;

  /// No description provided for @instantTryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get instantTryAgain;

  /// No description provided for @instantSearching.
  ///
  /// In ar, this message translates to:
  /// **'نبحث عن أقرب سائق...'**
  String get instantSearching;

  /// No description provided for @instantFareEstimate.
  ///
  /// In ar, this message translates to:
  /// **'الأجرة التقديرية: {fare} {currency}'**
  String instantFareEstimate(String fare, String currency);

  /// No description provided for @instantCancelRequest.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get instantCancelRequest;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
