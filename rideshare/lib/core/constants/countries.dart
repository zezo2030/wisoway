/// قائمة الدول مع رموز الاتصال الدولية (E.164)
/// مصدر: ITU-T E.164
library;

class CountryData {
  final String iso2;
  final String dialCode;
  final String nameEn;
  final String nameAr;

  const CountryData({
    required this.iso2,
    required this.dialCode,
    required this.nameEn,
    required this.nameAr,
  });

  String get displayLabel => '$nameAr ($dialCode)';

  bool matchesQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    return nameEn.toLowerCase().contains(q) ||
        nameAr.contains(query) ||
        dialCode.contains(q) ||
        iso2.toLowerCase().contains(q);
  }
}

/// قائمة جميع الدول مع رموز الاتصال
class Countries {
  Countries._();

  static const List<CountryData> all = [
    // المنطقة العربية - أولوية عالية
    CountryData(iso2: 'EG', dialCode: '+20', nameEn: 'Egypt', nameAr: 'مصر'),
    CountryData(
      iso2: 'SA',
      dialCode: '+966',
      nameEn: 'Saudi Arabia',
      nameAr: 'السعودية',
    ),
    CountryData(
      iso2: 'AE',
      dialCode: '+971',
      nameEn: 'United Arab Emirates',
      nameAr: 'الإمارات',
    ),
    CountryData(
      iso2: 'JO',
      dialCode: '+962',
      nameEn: 'Jordan',
      nameAr: 'الأردن',
    ),
    CountryData(
      iso2: 'KW',
      dialCode: '+965',
      nameEn: 'Kuwait',
      nameAr: 'الكويت',
    ),
    CountryData(iso2: 'QA', dialCode: '+974', nameEn: 'Qatar', nameAr: 'قطر'),
    CountryData(
      iso2: 'BH',
      dialCode: '+973',
      nameEn: 'Bahrain',
      nameAr: 'البحرين',
    ),
    CountryData(iso2: 'OM', dialCode: '+968', nameEn: 'Oman', nameAr: 'عُمان'),
    CountryData(iso2: 'IQ', dialCode: '+964', nameEn: 'Iraq', nameAr: 'العراق'),
    CountryData(iso2: 'SY', dialCode: '+963', nameEn: 'Syria', nameAr: 'سوريا'),
    CountryData(
      iso2: 'LB',
      dialCode: '+961',
      nameEn: 'Lebanon',
      nameAr: 'لبنان',
    ),
    CountryData(iso2: 'YE', dialCode: '+967', nameEn: 'Yemen', nameAr: 'اليمن'),
    CountryData(
      iso2: 'PS',
      dialCode: '+970',
      nameEn: 'Palestine',
      nameAr: 'فلسطين',
    ),
    CountryData(
      iso2: 'MA',
      dialCode: '+212',
      nameEn: 'Morocco',
      nameAr: 'المغرب',
    ),
    CountryData(
      iso2: 'DZ',
      dialCode: '+213',
      nameEn: 'Algeria',
      nameAr: 'الجزائر',
    ),
    CountryData(
      iso2: 'TN',
      dialCode: '+216',
      nameEn: 'Tunisia',
      nameAr: 'تونس',
    ),
    CountryData(iso2: 'LY', dialCode: '+218', nameEn: 'Libya', nameAr: 'ليبيا'),
    CountryData(
      iso2: 'SD',
      dialCode: '+249',
      nameEn: 'Sudan',
      nameAr: 'السودان',
    ),
    CountryData(
      iso2: 'SS',
      dialCode: '+211',
      nameEn: 'South Sudan',
      nameAr: 'جنوب السودان',
    ),
    CountryData(
      iso2: 'MR',
      dialCode: '+222',
      nameEn: 'Mauritania',
      nameAr: 'موريتانيا',
    ),
    CountryData(
      iso2: 'SO',
      dialCode: '+252',
      nameEn: 'Somalia',
      nameAr: 'الصومال',
    ),
    CountryData(
      iso2: 'DJ',
      dialCode: '+253',
      nameEn: 'Djibouti',
      nameAr: 'جيبوتي',
    ),
    CountryData(
      iso2: 'KM',
      dialCode: '+269',
      nameEn: 'Comoros',
      nameAr: 'جزر القمر',
    ),
    // باقي العالم
    CountryData(
      iso2: 'US',
      dialCode: '+1',
      nameEn: 'United States',
      nameAr: 'الولايات المتحدة',
    ),
    CountryData(iso2: 'CA', dialCode: '+1', nameEn: 'Canada', nameAr: 'كندا'),
    CountryData(
      iso2: 'GB',
      dialCode: '+44',
      nameEn: 'United Kingdom',
      nameAr: 'بريطانيا',
    ),
    CountryData(iso2: 'FR', dialCode: '+33', nameEn: 'France', nameAr: 'فرنسا'),
    CountryData(
      iso2: 'DE',
      dialCode: '+49',
      nameEn: 'Germany',
      nameAr: 'ألمانيا',
    ),
    CountryData(
      iso2: 'IT',
      dialCode: '+39',
      nameEn: 'Italy',
      nameAr: 'إيطاليا',
    ),
    CountryData(
      iso2: 'ES',
      dialCode: '+34',
      nameEn: 'Spain',
      nameAr: 'إسبانيا',
    ),
    CountryData(iso2: 'RU', dialCode: '+7', nameEn: 'Russia', nameAr: 'روسيا'),
    CountryData(iso2: 'CN', dialCode: '+86', nameEn: 'China', nameAr: 'الصين'),
    CountryData(iso2: 'IN', dialCode: '+91', nameEn: 'India', nameAr: 'الهند'),
    CountryData(
      iso2: 'JP',
      dialCode: '+81',
      nameEn: 'Japan',
      nameAr: 'اليابان',
    ),
    CountryData(
      iso2: 'KR',
      dialCode: '+82',
      nameEn: 'South Korea',
      nameAr: 'كوريا الجنوبية',
    ),
    CountryData(
      iso2: 'AU',
      dialCode: '+61',
      nameEn: 'Australia',
      nameAr: 'أستراليا',
    ),
    CountryData(
      iso2: 'BR',
      dialCode: '+55',
      nameEn: 'Brazil',
      nameAr: 'البرازيل',
    ),
    CountryData(iso2: 'TR', dialCode: '+90', nameEn: 'Turkey', nameAr: 'تركيا'),
    CountryData(iso2: 'IR', dialCode: '+98', nameEn: 'Iran', nameAr: 'إيران'),
    CountryData(
      iso2: 'PK',
      dialCode: '+92',
      nameEn: 'Pakistan',
      nameAr: 'باكستان',
    ),
    CountryData(
      iso2: 'AF',
      dialCode: '+93',
      nameEn: 'Afghanistan',
      nameAr: 'أفغانستان',
    ),
    CountryData(
      iso2: 'BD',
      dialCode: '+880',
      nameEn: 'Bangladesh',
      nameAr: 'بنغلاديش',
    ),
    CountryData(
      iso2: 'ID',
      dialCode: '+62',
      nameEn: 'Indonesia',
      nameAr: 'إندونيسيا',
    ),
    CountryData(
      iso2: 'MY',
      dialCode: '+60',
      nameEn: 'Malaysia',
      nameAr: 'ماليزيا',
    ),
    CountryData(
      iso2: 'TH',
      dialCode: '+66',
      nameEn: 'Thailand',
      nameAr: 'تايلاند',
    ),
    CountryData(
      iso2: 'VN',
      dialCode: '+84',
      nameEn: 'Vietnam',
      nameAr: 'فيتنام',
    ),
    CountryData(
      iso2: 'PH',
      dialCode: '+63',
      nameEn: 'Philippines',
      nameAr: 'الفلبين',
    ),
    CountryData(
      iso2: 'SG',
      dialCode: '+65',
      nameEn: 'Singapore',
      nameAr: 'سنغافورة',
    ),
    CountryData(
      iso2: 'IL',
      dialCode: '+972',
      nameEn: 'Israel',
      nameAr: 'إسرائيل',
    ),
    CountryData(iso2: 'NP', dialCode: '+977', nameEn: 'Nepal', nameAr: 'نيبال'),
    CountryData(
      iso2: 'LK',
      dialCode: '+94',
      nameEn: 'Sri Lanka',
      nameAr: 'سريلانكا',
    ),
    CountryData(
      iso2: 'MM',
      dialCode: '+95',
      nameEn: 'Myanmar',
      nameAr: 'ميانمار',
    ),
    CountryData(
      iso2: 'MV',
      dialCode: '+960',
      nameEn: 'Maldives',
      nameAr: 'المالديف',
    ),
    CountryData(
      iso2: 'BT',
      dialCode: '+975',
      nameEn: 'Bhutan',
      nameAr: 'بوتان',
    ),
    CountryData(
      iso2: 'MN',
      dialCode: '+976',
      nameEn: 'Mongolia',
      nameAr: 'منغوليا',
    ),
    CountryData(
      iso2: 'TW',
      dialCode: '+886',
      nameEn: 'Taiwan',
      nameAr: 'تايوان',
    ),
    CountryData(
      iso2: 'HK',
      dialCode: '+852',
      nameEn: 'Hong Kong',
      nameAr: 'هونغ كونغ',
    ),
    CountryData(iso2: 'MO', dialCode: '+853', nameEn: 'Macau', nameAr: 'ماكاو'),
    CountryData(
      iso2: 'KZ',
      dialCode: '+7',
      nameEn: 'Kazakhstan',
      nameAr: 'كازاخستان',
    ),
    CountryData(
      iso2: 'UZ',
      dialCode: '+998',
      nameEn: 'Uzbekistan',
      nameAr: 'أوزبكستان',
    ),
    CountryData(
      iso2: 'TM',
      dialCode: '+993',
      nameEn: 'Turkmenistan',
      nameAr: 'تركمانستان',
    ),
    CountryData(
      iso2: 'TJ',
      dialCode: '+992',
      nameEn: 'Tajikistan',
      nameAr: 'طاجيكستان',
    ),
    CountryData(
      iso2: 'KG',
      dialCode: '+996',
      nameEn: 'Kyrgyzstan',
      nameAr: 'قيرغيزستان',
    ),
    CountryData(
      iso2: 'AZ',
      dialCode: '+994',
      nameEn: 'Azerbaijan',
      nameAr: 'أذربيجان',
    ),
    CountryData(
      iso2: 'GE',
      dialCode: '+995',
      nameEn: 'Georgia',
      nameAr: 'جورجيا',
    ),
    CountryData(
      iso2: 'AM',
      dialCode: '+374',
      nameEn: 'Armenia',
      nameAr: 'أرمينيا',
    ),
    CountryData(
      iso2: 'KH',
      dialCode: '+855',
      nameEn: 'Cambodia',
      nameAr: 'كمبوديا',
    ),
    CountryData(iso2: 'LA', dialCode: '+856', nameEn: 'Laos', nameAr: 'لاوس'),
    CountryData(
      iso2: 'BN',
      dialCode: '+673',
      nameEn: 'Brunei',
      nameAr: 'بروناي',
    ),
    CountryData(
      iso2: 'TL',
      dialCode: '+670',
      nameEn: 'Timor-Leste',
      nameAr: 'تيمور الشرقية',
    ),
    CountryData(
      iso2: 'PG',
      dialCode: '+675',
      nameEn: 'Papua New Guinea',
      nameAr: 'بابوا غينيا الجديدة',
    ),
    CountryData(iso2: 'FJ', dialCode: '+679', nameEn: 'Fiji', nameAr: 'فيجي'),
    CountryData(
      iso2: 'NZ',
      dialCode: '+64',
      nameEn: 'New Zealand',
      nameAr: 'نيوزيلندا',
    ),
    // أوروبا
    CountryData(
      iso2: 'NL',
      dialCode: '+31',
      nameEn: 'Netherlands',
      nameAr: 'هولندا',
    ),
    CountryData(
      iso2: 'BE',
      dialCode: '+32',
      nameEn: 'Belgium',
      nameAr: 'بلجيكا',
    ),
    CountryData(
      iso2: 'CH',
      dialCode: '+41',
      nameEn: 'Switzerland',
      nameAr: 'سويسرا',
    ),
    CountryData(
      iso2: 'AT',
      dialCode: '+43',
      nameEn: 'Austria',
      nameAr: 'النمسا',
    ),
    CountryData(
      iso2: 'SE',
      dialCode: '+46',
      nameEn: 'Sweden',
      nameAr: 'السويد',
    ),
    CountryData(
      iso2: 'NO',
      dialCode: '+47',
      nameEn: 'Norway',
      nameAr: 'النرويج',
    ),
    CountryData(
      iso2: 'DK',
      dialCode: '+45',
      nameEn: 'Denmark',
      nameAr: 'الدنمارك',
    ),
    CountryData(
      iso2: 'FI',
      dialCode: '+358',
      nameEn: 'Finland',
      nameAr: 'فنلندا',
    ),
    CountryData(
      iso2: 'PL',
      dialCode: '+48',
      nameEn: 'Poland',
      nameAr: 'بولندا',
    ),
    CountryData(
      iso2: 'GR',
      dialCode: '+30',
      nameEn: 'Greece',
      nameAr: 'اليونان',
    ),
    CountryData(
      iso2: 'PT',
      dialCode: '+351',
      nameEn: 'Portugal',
      nameAr: 'البرتغال',
    ),
    CountryData(
      iso2: 'IE',
      dialCode: '+353',
      nameEn: 'Ireland',
      nameAr: 'أيرلندا',
    ),
    CountryData(
      iso2: 'CZ',
      dialCode: '+420',
      nameEn: 'Czech Republic',
      nameAr: 'التشيك',
    ),
    CountryData(
      iso2: 'RO',
      dialCode: '+40',
      nameEn: 'Romania',
      nameAr: 'رومانيا',
    ),
    CountryData(
      iso2: 'HU',
      dialCode: '+36',
      nameEn: 'Hungary',
      nameAr: 'المجر',
    ),
    CountryData(
      iso2: 'UA',
      dialCode: '+380',
      nameEn: 'Ukraine',
      nameAr: 'أوكرانيا',
    ),
    CountryData(
      iso2: 'BY',
      dialCode: '+375',
      nameEn: 'Belarus',
      nameAr: 'بيلاروسيا',
    ),
    CountryData(
      iso2: 'BG',
      dialCode: '+359',
      nameEn: 'Bulgaria',
      nameAr: 'بلغاريا',
    ),
    CountryData(
      iso2: 'RS',
      dialCode: '+381',
      nameEn: 'Serbia',
      nameAr: 'صربيا',
    ),
    CountryData(
      iso2: 'HR',
      dialCode: '+385',
      nameEn: 'Croatia',
      nameAr: 'كرواتيا',
    ),
    CountryData(
      iso2: 'SK',
      dialCode: '+421',
      nameEn: 'Slovakia',
      nameAr: 'سلوفاكيا',
    ),
    CountryData(
      iso2: 'SI',
      dialCode: '+386',
      nameEn: 'Slovenia',
      nameAr: 'سلوفينيا',
    ),
    CountryData(
      iso2: 'BA',
      dialCode: '+387',
      nameEn: 'Bosnia and Herzegovina',
      nameAr: 'البوسنة',
    ),
    CountryData(
      iso2: 'MK',
      dialCode: '+389',
      nameEn: 'North Macedonia',
      nameAr: 'مقدونيا الشمالية',
    ),
    CountryData(
      iso2: 'AL',
      dialCode: '+355',
      nameEn: 'Albania',
      nameAr: 'ألبانيا',
    ),
    CountryData(
      iso2: 'MD',
      dialCode: '+373',
      nameEn: 'Moldova',
      nameAr: 'مولدوفا',
    ),
    CountryData(
      iso2: 'LT',
      dialCode: '+370',
      nameEn: 'Lithuania',
      nameAr: 'ليتوانيا',
    ),
    CountryData(
      iso2: 'LV',
      dialCode: '+371',
      nameEn: 'Latvia',
      nameAr: 'لاتفيا',
    ),
    CountryData(
      iso2: 'EE',
      dialCode: '+372',
      nameEn: 'Estonia',
      nameAr: 'إستونيا',
    ),
    CountryData(iso2: 'CY', dialCode: '+357', nameEn: 'Cyprus', nameAr: 'قبرص'),
    CountryData(iso2: 'MT', dialCode: '+356', nameEn: 'Malta', nameAr: 'مالطا'),
    CountryData(
      iso2: 'LU',
      dialCode: '+352',
      nameEn: 'Luxembourg',
      nameAr: 'لوكسمبورغ',
    ),
    CountryData(
      iso2: 'IS',
      dialCode: '+354',
      nameEn: 'Iceland',
      nameAr: 'آيسلندا',
    ),
    CountryData(
      iso2: 'ME',
      dialCode: '+382',
      nameEn: 'Montenegro',
      nameAr: 'الجبل الأسود',
    ),
    CountryData(
      iso2: 'XK',
      dialCode: '+383',
      nameEn: 'Kosovo',
      nameAr: 'كوسوفو',
    ),
    CountryData(
      iso2: 'AD',
      dialCode: '+376',
      nameEn: 'Andorra',
      nameAr: 'أندورا',
    ),
    CountryData(
      iso2: 'MC',
      dialCode: '+377',
      nameEn: 'Monaco',
      nameAr: 'موناكو',
    ),
    CountryData(
      iso2: 'SM',
      dialCode: '+378',
      nameEn: 'San Marino',
      nameAr: 'سان مارينو',
    ),
    CountryData(
      iso2: 'VA',
      dialCode: '+379',
      nameEn: 'Vatican City',
      nameAr: 'الفاتيكان',
    ),
    CountryData(
      iso2: 'GI',
      dialCode: '+350',
      nameEn: 'Gibraltar',
      nameAr: 'جبل طارق',
    ),
    // أفريقيا
    CountryData(
      iso2: 'ZA',
      dialCode: '+27',
      nameEn: 'South Africa',
      nameAr: 'جنوب أفريقيا',
    ),
    CountryData(
      iso2: 'NG',
      dialCode: '+234',
      nameEn: 'Nigeria',
      nameAr: 'نيجيريا',
    ),
    CountryData(iso2: 'KE', dialCode: '+254', nameEn: 'Kenya', nameAr: 'كينيا'),
    CountryData(iso2: 'GH', dialCode: '+233', nameEn: 'Ghana', nameAr: 'غانا'),
    CountryData(
      iso2: 'ET',
      dialCode: '+251',
      nameEn: 'Ethiopia',
      nameAr: 'إثيوبيا',
    ),
    CountryData(
      iso2: 'TZ',
      dialCode: '+255',
      nameEn: 'Tanzania',
      nameAr: 'تنزانيا',
    ),
    CountryData(
      iso2: 'UG',
      dialCode: '+256',
      nameEn: 'Uganda',
      nameAr: 'أوغندا',
    ),
    CountryData(
      iso2: 'SN',
      dialCode: '+221',
      nameEn: 'Senegal',
      nameAr: 'السنغال',
    ),
    CountryData(
      iso2: 'CI',
      dialCode: '+225',
      nameEn: 'Ivory Coast',
      nameAr: 'ساحل العاج',
    ),
    CountryData(
      iso2: 'CM',
      dialCode: '+237',
      nameEn: 'Cameroon',
      nameAr: 'الكاميرون',
    ),
    CountryData(
      iso2: 'MG',
      dialCode: '+261',
      nameEn: 'Madagascar',
      nameAr: 'مدغشقر',
    ),
    CountryData(
      iso2: 'MZ',
      dialCode: '+258',
      nameEn: 'Mozambique',
      nameAr: 'موزمبيق',
    ),
    CountryData(
      iso2: 'ZW',
      dialCode: '+263',
      nameEn: 'Zimbabwe',
      nameAr: 'زيمبابوي',
    ),
    CountryData(
      iso2: 'ZM',
      dialCode: '+260',
      nameEn: 'Zambia',
      nameAr: 'زامبيا',
    ),
    CountryData(
      iso2: 'AO',
      dialCode: '+244',
      nameEn: 'Angola',
      nameAr: 'أنغولا',
    ),
    CountryData(
      iso2: 'RW',
      dialCode: '+250',
      nameEn: 'Rwanda',
      nameAr: 'رواندا',
    ),
    CountryData(
      iso2: 'NE',
      dialCode: '+227',
      nameEn: 'Niger',
      nameAr: 'النيجر',
    ),
    CountryData(iso2: 'ML', dialCode: '+223', nameEn: 'Mali', nameAr: 'مالي'),
    CountryData(
      iso2: 'BF',
      dialCode: '+226',
      nameEn: 'Burkina Faso',
      nameAr: 'بوركينا فاسو',
    ),
    CountryData(iso2: 'TG', dialCode: '+228', nameEn: 'Togo', nameAr: 'توغو'),
    CountryData(iso2: 'BJ', dialCode: '+229', nameEn: 'Benin', nameAr: 'بنين'),
    CountryData(
      iso2: 'MU',
      dialCode: '+230',
      nameEn: 'Mauritius',
      nameAr: 'موريشيوس',
    ),
    CountryData(
      iso2: 'LR',
      dialCode: '+231',
      nameEn: 'Liberia',
      nameAr: 'ليبيريا',
    ),
    CountryData(
      iso2: 'SL',
      dialCode: '+232',
      nameEn: 'Sierra Leone',
      nameAr: 'سيراليون',
    ),
    CountryData(
      iso2: 'GN',
      dialCode: '+224',
      nameEn: 'Guinea',
      nameAr: 'غينيا',
    ),
    CountryData(
      iso2: 'GW',
      dialCode: '+245',
      nameEn: 'Guinea-Bissau',
      nameAr: 'غينيا بيساو',
    ),
    CountryData(
      iso2: 'GM',
      dialCode: '+220',
      nameEn: 'Gambia',
      nameAr: 'غامبيا',
    ),
    CountryData(iso2: 'TD', dialCode: '+235', nameEn: 'Chad', nameAr: 'تشاد'),
    CountryData(
      iso2: 'CF',
      dialCode: '+236',
      nameEn: 'Central African Republic',
      nameAr: 'جمهورية أفريقيا الوسطى',
    ),
    CountryData(
      iso2: 'CG',
      dialCode: '+242',
      nameEn: 'Republic of the Congo',
      nameAr: 'الكونغو',
    ),
    CountryData(
      iso2: 'CD',
      dialCode: '+243',
      nameEn: 'DR Congo',
      nameAr: 'الكونغو الديمقراطية',
    ),
    CountryData(
      iso2: 'GA',
      dialCode: '+241',
      nameEn: 'Gabon',
      nameAr: 'الغابون',
    ),
    CountryData(
      iso2: 'GQ',
      dialCode: '+240',
      nameEn: 'Equatorial Guinea',
      nameAr: 'غينيا الاستوائية',
    ),
    CountryData(
      iso2: 'CV',
      dialCode: '+238',
      nameEn: 'Cape Verde',
      nameAr: 'الرأس الأخضر',
    ),
    CountryData(
      iso2: 'ST',
      dialCode: '+239',
      nameEn: 'São Tomé and Príncipe',
      nameAr: 'ساو تومي وبرينسيبي',
    ),
    CountryData(
      iso2: 'SC',
      dialCode: '+248',
      nameEn: 'Seychelles',
      nameAr: 'سيشل',
    ),
    CountryData(
      iso2: 'NA',
      dialCode: '+264',
      nameEn: 'Namibia',
      nameAr: 'ناميبيا',
    ),
    CountryData(
      iso2: 'BW',
      dialCode: '+267',
      nameEn: 'Botswana',
      nameAr: 'بوتسوانا',
    ),
    CountryData(
      iso2: 'LS',
      dialCode: '+266',
      nameEn: 'Lesotho',
      nameAr: 'ليسوتو',
    ),
    CountryData(
      iso2: 'SZ',
      dialCode: '+268',
      nameEn: 'Eswatini',
      nameAr: 'إسواتيني',
    ),
    CountryData(
      iso2: 'ER',
      dialCode: '+291',
      nameEn: 'Eritrea',
      nameAr: 'إريتريا',
    ),
    CountryData(
      iso2: 'EH',
      dialCode: '+212',
      nameEn: 'Western Sahara',
      nameAr: 'الصحراء الغربية',
    ),
    // الأمريكتان
    CountryData(
      iso2: 'MX',
      dialCode: '+52',
      nameEn: 'Mexico',
      nameAr: 'المكسيك',
    ),
    CountryData(
      iso2: 'AR',
      dialCode: '+54',
      nameEn: 'Argentina',
      nameAr: 'الأرجنتين',
    ),
    CountryData(
      iso2: 'CO',
      dialCode: '+57',
      nameEn: 'Colombia',
      nameAr: 'كولومبيا',
    ),
    CountryData(iso2: 'PE', dialCode: '+51', nameEn: 'Peru', nameAr: 'بيرو'),
    CountryData(
      iso2: 'VE',
      dialCode: '+58',
      nameEn: 'Venezuela',
      nameAr: 'فنزويلا',
    ),
    CountryData(iso2: 'CL', dialCode: '+56', nameEn: 'Chile', nameAr: 'تشيلي'),
    CountryData(
      iso2: 'EC',
      dialCode: '+593',
      nameEn: 'Ecuador',
      nameAr: 'الإكوادور',
    ),
    CountryData(
      iso2: 'GT',
      dialCode: '+502',
      nameEn: 'Guatemala',
      nameAr: 'غواتيمالا',
    ),
    CountryData(iso2: 'CU', dialCode: '+53', nameEn: 'Cuba', nameAr: 'كوبا'),
    CountryData(
      iso2: 'BO',
      dialCode: '+591',
      nameEn: 'Bolivia',
      nameAr: 'بوليفيا',
    ),
    CountryData(
      iso2: 'DO',
      dialCode: '+1',
      nameEn: 'Dominican Republic',
      nameAr: 'جمهورية الدومينيكان',
    ),
    CountryData(
      iso2: 'HN',
      dialCode: '+504',
      nameEn: 'Honduras',
      nameAr: 'هندوراس',
    ),
    CountryData(
      iso2: 'PY',
      dialCode: '+595',
      nameEn: 'Paraguay',
      nameAr: 'باراغواي',
    ),
    CountryData(
      iso2: 'SV',
      dialCode: '+503',
      nameEn: 'El Salvador',
      nameAr: 'السلفادور',
    ),
    CountryData(
      iso2: 'NI',
      dialCode: '+505',
      nameEn: 'Nicaragua',
      nameAr: 'نيكاراغوا',
    ),
    CountryData(
      iso2: 'CR',
      dialCode: '+506',
      nameEn: 'Costa Rica',
      nameAr: 'كوستاريكا',
    ),
    CountryData(iso2: 'PA', dialCode: '+507', nameEn: 'Panama', nameAr: 'بنما'),
    CountryData(
      iso2: 'UY',
      dialCode: '+598',
      nameEn: 'Uruguay',
      nameAr: 'أوروغواي',
    ),
    CountryData(
      iso2: 'PR',
      dialCode: '+1',
      nameEn: 'Puerto Rico',
      nameAr: 'بورتوريكو',
    ),
    CountryData(
      iso2: 'JM',
      dialCode: '+1',
      nameEn: 'Jamaica',
      nameAr: 'جامايكا',
    ),
    CountryData(
      iso2: 'TT',
      dialCode: '+1',
      nameEn: 'Trinidad and Tobago',
      nameAr: 'ترينيداد وتوباغو',
    ),
    CountryData(iso2: 'HT', dialCode: '+509', nameEn: 'Haiti', nameAr: 'هايتي'),
    CountryData(iso2: 'BZ', dialCode: '+501', nameEn: 'Belize', nameAr: 'بليز'),
    CountryData(
      iso2: 'BB',
      dialCode: '+1',
      nameEn: 'Barbados',
      nameAr: 'بربادوس',
    ),
    CountryData(
      iso2: 'BS',
      dialCode: '+1',
      nameEn: 'Bahamas',
      nameAr: 'باهاماس',
    ),
    CountryData(
      iso2: 'GY',
      dialCode: '+592',
      nameEn: 'Guyana',
      nameAr: 'غيانا',
    ),
    CountryData(
      iso2: 'SR',
      dialCode: '+597',
      nameEn: 'Suriname',
      nameAr: 'سورينام',
    ),
    CountryData(
      iso2: 'GF',
      dialCode: '+594',
      nameEn: 'French Guiana',
      nameAr: 'غويانا الفرنسية',
    ),
    CountryData(
      iso2: 'MQ',
      dialCode: '+596',
      nameEn: 'Martinique',
      nameAr: 'مارتينيك',
    ),
    CountryData(
      iso2: 'GP',
      dialCode: '+590',
      nameEn: 'Guadeloupe',
      nameAr: 'غوادلوب',
    ),
    CountryData(
      iso2: 'AG',
      dialCode: '+1',
      nameEn: 'Antigua and Barbuda',
      nameAr: 'أنتيغوا وبربودا',
    ),
    CountryData(
      iso2: 'DM',
      dialCode: '+1',
      nameEn: 'Dominica',
      nameAr: 'دومينيكا',
    ),
    CountryData(
      iso2: 'GD',
      dialCode: '+1',
      nameEn: 'Grenada',
      nameAr: 'غرينادا',
    ),
    CountryData(
      iso2: 'LC',
      dialCode: '+1',
      nameEn: 'Saint Lucia',
      nameAr: 'سانت لوسيا',
    ),
    CountryData(
      iso2: 'VC',
      dialCode: '+1',
      nameEn: 'Saint Vincent and the Grenadines',
      nameAr: 'سانت فينسنت والغرينادين',
    ),
    CountryData(
      iso2: 'KN',
      dialCode: '+1',
      nameEn: 'Saint Kitts and Nevis',
      nameAr: 'سانت كيتس ونيفيس',
    ),
    CountryData(
      iso2: 'BQ',
      dialCode: '+599',
      nameEn: 'Caribbean Netherlands',
      nameAr: 'هولندا الكاريبية',
    ),
    CountryData(
      iso2: 'CW',
      dialCode: '+599',
      nameEn: 'Curaçao',
      nameAr: 'كوراساو',
    ),
    CountryData(iso2: 'AW', dialCode: '+297', nameEn: 'Aruba', nameAr: 'أروبا'),
    CountryData(
      iso2: 'KY',
      dialCode: '+1',
      nameEn: 'Cayman Islands',
      nameAr: 'جزر كايمان',
    ),
    CountryData(
      iso2: 'BM',
      dialCode: '+1',
      nameEn: 'Bermuda',
      nameAr: 'برمودا',
    ),
    CountryData(
      iso2: 'VG',
      dialCode: '+1',
      nameEn: 'British Virgin Islands',
      nameAr: 'جزر العذراء البريطانية',
    ),
    CountryData(
      iso2: 'VI',
      dialCode: '+1',
      nameEn: 'U.S. Virgin Islands',
      nameAr: 'جزر العذراء الأمريكية',
    ),
    CountryData(
      iso2: 'TC',
      dialCode: '+1',
      nameEn: 'Turks and Caicos',
      nameAr: 'جزر تركس وكايكوس',
    ),
    CountryData(
      iso2: 'SX',
      dialCode: '+1',
      nameEn: 'Sint Maarten',
      nameAr: 'سانت مارتن',
    ),
    // أوقيانوسيا
    CountryData(
      iso2: 'SB',
      dialCode: '+677',
      nameEn: 'Solomon Islands',
      nameAr: 'جزر سليمان',
    ),
    CountryData(
      iso2: 'VU',
      dialCode: '+678',
      nameEn: 'Vanuatu',
      nameAr: 'فانواتو',
    ),
    CountryData(iso2: 'WS', dialCode: '+685', nameEn: 'Samoa', nameAr: 'ساموا'),
    CountryData(iso2: 'TO', dialCode: '+676', nameEn: 'Tonga', nameAr: 'تونغا'),
    CountryData(
      iso2: 'KI',
      dialCode: '+686',
      nameEn: 'Kiribati',
      nameAr: 'كيريباتي',
    ),
    CountryData(
      iso2: 'FM',
      dialCode: '+691',
      nameEn: 'Micronesia',
      nameAr: 'ميكرونيزيا',
    ),
    CountryData(
      iso2: 'MH',
      dialCode: '+692',
      nameEn: 'Marshall Islands',
      nameAr: 'جزر مارشال',
    ),
    CountryData(iso2: 'PW', dialCode: '+680', nameEn: 'Palau', nameAr: 'بالاو'),
    CountryData(iso2: 'NR', dialCode: '+674', nameEn: 'Nauru', nameAr: 'ناورو'),
    CountryData(
      iso2: 'TV',
      dialCode: '+688',
      nameEn: 'Tuvalu',
      nameAr: 'توفالو',
    ),
    CountryData(
      iso2: 'NC',
      dialCode: '+687',
      nameEn: 'New Caledonia',
      nameAr: 'كاليدونيا الجديدة',
    ),
    CountryData(
      iso2: 'PF',
      dialCode: '+689',
      nameEn: 'French Polynesia',
      nameAr: 'بولينيزيا الفرنسية',
    ),
    CountryData(iso2: 'GU', dialCode: '+1', nameEn: 'Guam', nameAr: 'غوام'),
    CountryData(
      iso2: 'AS',
      dialCode: '+1',
      nameEn: 'American Samoa',
      nameAr: 'ساموا الأمريكية',
    ),
    CountryData(
      iso2: 'MP',
      dialCode: '+1',
      nameEn: 'Northern Mariana Islands',
      nameAr: 'جزر ماريانا الشمالية',
    ),
    CountryData(
      iso2: 'CK',
      dialCode: '+682',
      nameEn: 'Cook Islands',
      nameAr: 'جزر كوك',
    ),
    CountryData(
      iso2: 'WF',
      dialCode: '+681',
      nameEn: 'Wallis and Futuna',
      nameAr: 'واليس وفوتونا',
    ),
  ];

  /// الحصول على الدولة من رمز الاتصال
  static CountryData? getByDialCode(String dialCode) {
    final normalized = dialCode.startsWith('+') ? dialCode : '+$dialCode';
    for (final c in all) {
      if (c.dialCode == normalized) return c;
    }
    return null;
  }

  /// الحصول على الدولة من كود ISO
  static CountryData? getByIso2(String iso2) {
    final upper = iso2.toUpperCase();
    for (final c in all) {
      if (c.iso2.toUpperCase() == upper) return c;
    }
    return null;
  }

  /// البحث في الدول
  static List<CountryData> search(String query) {
    if (query.trim().isEmpty) return all;
    final q = query.trim().toLowerCase();
    return all.where((c) => c.matchesQuery(q)).toList();
  }

  /// الدولة الافتراضية (مصر)
  static const CountryData defaultCountry = CountryData(
    iso2: 'EG',
    dialCode: '+20',
    nameEn: 'Egypt',
    nameAr: 'مصر',
  );
}
