/// Communication Fees - رسوم فتح التواصل
/// 
/// هذه الرسوم الثابتة التي يدفعها السائق لفتح التواصل مع الركاب المهتمين
/// يتم تحديد المبلغ تلقائياً حسب دولة المستخدم
class CommunicationFees {
  // الرسوم الثابتة حسب رمز البلد
  static const Map<String, double> feesByCountry = {
    'JO': 2.0,   // JOD - الأردن
    'SA': 10.0,  // SAR - السعودية
    'AE': 25.0,  // AED - الإمارات
    'QA': 25.0,  // QAR - قطر
    'EG': 50.0,  // EGP - مصر
  };

  // العملات المقابلة لكل بلد
  static const Map<String, String> currencyByCountry = {
    'JO': 'JOD',
    'SA': 'SAR',
    'AE': 'AED',
    'QA': 'QAR',
    'EG': 'EGP',
  };

  /// الحصول على رسوم التواصل حسب رمز البلد
  /// 
  /// [countryCode] رمز البلد (مثل 'EG', 'JO', 'SA')
  /// 
  /// Returns المبلغ بالعملة المحلية، أو 0.0 إذا لم يتم العثور على البلد
  static double getFeeByCountry(String countryCode) {
    return feesByCountry[countryCode.toUpperCase()] ?? 0.0;
  }

  /// الحصول على العملة حسب رمز البلد
  /// 
  /// [countryCode] رمز البلد (مثل 'EG', 'JO', 'SA')
  /// 
  /// Returns رمز العملة (مثل 'JOD', 'EGP')، أو 'JOD' كقيمة افتراضية
  static String getCurrencyByCountry(String countryCode) {
    return currencyByCountry[countryCode.toUpperCase()] ?? 'JOD';
  }

  /// الحصول على رسوم التواصل والعملة معاً
  /// 
  /// [countryCode] رمز البلد (مثل 'EG', 'JO', 'SA')
  /// 
  /// Returns Map يحتوي على 'fee' و 'currency'
  static Map<String, dynamic> getFeeAndCurrency(String countryCode) {
    final code = countryCode.toUpperCase();
    return {
      'fee': getFeeByCountry(code),
      'currency': getCurrencyByCountry(code),
    };
  }

  /// التحقق من وجود رسوم للبلد
  /// 
  /// [countryCode] رمز البلد
  /// 
  /// Returns true إذا كان البلد مدعوم، false إذا لم يكن
  static bool isCountrySupported(String countryCode) {
    return feesByCountry.containsKey(countryCode.toUpperCase());
  }

  /// الحصول على قائمة جميع البلدان المدعومة
  /// 
  /// Returns List من رموز البلدان
  static List<String> getSupportedCountries() {
    return feesByCountry.keys.toList();
  }
}








