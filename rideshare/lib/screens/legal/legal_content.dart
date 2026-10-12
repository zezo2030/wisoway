/// Text of the Terms of Use and Privacy Policy, kept in the app so both are
/// readable offline and before sign-in.
///
/// Update [kLegalLastUpdated] whenever either document changes.
library;

const String kLegalLastUpdated = '2026-10-09';

class LegalSection {
  const LegalSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

class LegalDocumentContent {
  const LegalDocumentContent({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;
}

enum LegalDocumentKind { terms, privacy }

LegalDocumentContent legalContent(LegalDocumentKind kind, String languageCode) {
  final arabic = languageCode != 'en';
  switch (kind) {
    case LegalDocumentKind.terms:
      return arabic ? _termsAr : _termsEn;
    case LegalDocumentKind.privacy:
      return arabic ? _privacyAr : _privacyEn;
  }
}

// ── Terms of Use — Arabic ───────────────────────────────────────────────────

const _termsAr = LegalDocumentContent(
  title: 'شروط الاستخدام',
  intro:
      'مرحباً بك في تطبيق VisionWay. باستخدامك للتطبيق أو إنشاء حساب فيه فإنك '
      'توافق على هذه الشروط. إن لم توافق عليها، يُرجى عدم استخدام التطبيق.',
  sections: [
    LegalSection('١. طبيعة الخدمة', [
      'VisionWay منصة تقنية تربط بين سائقين يعرضون مقاعد في رحلاتهم وركاب يرغبون '
          'في الانضمام إليها، سواء في رحلات مشتركة مجدولة مسبقاً أو رحلات فورية.',
      'المنصة ليست شركة نقل ولا تملك المركبات ولا توظّف السائقين. السائق هو '
          'المسؤول عن قيادة المركبة وسلامتها وصلاحية تراخيصها وتأمينها.',
    ]),
    LegalSection('٢. الأهلية والحساب', [
      'يجب أن يكون عمرك ١٨ عاماً على الأقل لاستخدام التطبيق.',
      'يتم التسجيل برقم هاتف يُتحقق منه برمز يُرسل إليه، وأنت مسؤول عن صحة '
          'بياناتك والحفاظ على سرية الوصول إلى حسابك وعن كل نشاط يتم من خلاله.',
      'لا يجوز إنشاء أكثر من حساب للشخص نفسه أو استخدام حساب شخص آخر.',
    ]),
    LegalSection('٣. شروط خاصة بالسائقين', [
      'يلتزم السائق بتقديم رخصة قيادة سارية ورخصة مركبة ووثائق صحيحة، وتخضع '
          'هذه الوثائق لمراجعة الإدارة قبل تفعيل حساب السائق.',
      'يلتزم السائق بقواعد السير، وبالحضور في الموعد ونقطة الالتقاء المحددين، '
          'وبعدد المقاعد ونوع المركبة المعلن عنهما، وبالأجرة المعروضة للراكب.',
      'تُحتسب على السائق رسوم منصة عن كل رحلة مشتركة وفق النسبة المعروضة في '
          'التطبيق عند نشر الرحلة، وتُخصم من محفظته عند بدء الرحلة. إذا لم يكفِ '
          'الرصيد يُسجَّل الفرق مستحقاً عليه ويجب سداده قبل نشر رحلات جديدة.',
      'قد تكون الرحلة الأولى معفاة من الرسوم حسب ما يظهر في التطبيق.',
    ]),
    LegalSection('٤. شروط خاصة بالركاب', [
      'يلتزم الراكب بالحضور في الموعد ونقطة الالتقاء، وبعدد المقاعد المحجوزة، '
          'وبالتعامل باحترام مع السائق وباقي الركاب.',
      'يحق للسائق رفض طلب الحجز أو إنهاء الرحلة لراكب يخالف هذه الشروط أو '
          'يعرّض السلامة للخطر.',
    ]),
    LegalSection('٥. الأجرة والدفع', [
      'تُعرض الأجرة قبل تأكيد الحجز أو الرحلة. يتم الدفع نقداً للسائق أو '
          'إلكترونياً عبر CliQ حيث تتوفر هذه الخدمة.',
      'الرسوم والغرامات المستحقة للمنصة تُسدَّد من المحفظة داخل التطبيق، ويتم '
          'شحن المحفظة بالطرق المتاحة فيه. تظهر المبالغ بعملة البلد الذي تتم فيه '
          'الرحلة.',
    ]),
    LegalSection('٦. الإلغاء وعدم الحضور', [
      'يمكن إلغاء الحجز وفق المهلة والقواعد المعروضة في التطبيق وقت الإلغاء. '
          'قد تترتب رسوم على الإلغاء المتأخر أو على عدم الحضور، سواء من الراكب أو '
          'السائق، وتظهر قيمتها قبل تأكيد الإلغاء.',
    ]),
    LegalSection('٧. السلوك المحظور', [
      'يُحظر استخدام التطبيق لأي غرض غير مشروع، أو لنقل مواد ممنوعة، أو '
          'للتحرش أو الإساءة أو التمييز، أو لنشر بيانات مضللة، أو للتواصل '
          'بهدف إتمام الرحلات خارج التطبيق للتهرب من الرسوم، أو لمحاولة '
          'اختراق التطبيق أو إساءة استخدامه.',
    ]),
    LegalSection('٨. التقييمات والمحادثات', [
      'يمكن للركاب والسائقين تقييم بعضهم بعد الرحلة. يجب أن تكون التقييمات '
          'والرسائل صادقة ولائقة، ويحق لنا حذف ما يخالف ذلك.',
      'تتم المحادثات والمكالمات عبر التطبيق دون كشف رقم هاتف الطرف الآخر.',
    ]),
    LegalSection('٩. إيقاف الحساب وإنهاؤه', [
      'يحق لنا تعليق الحساب أو إيقافه عند مخالفة هذه الشروط أو وجود شكاوى '
          'متكررة أو نشاط يعرّض المستخدمين للخطر.',
      'يمكنك حذف حسابك في أي وقت من الإعدادات، مع بقاء التزامك بسداد أي مبالغ '
          'مستحقة قبل الحذف.',
    ]),
    LegalSection('١٠. حدود المسؤولية', [
      'نبذل جهدنا لتكون الخدمة متاحة ودقيقة، لكنها تُقدَّم "كما هي" دون ضمان '
          'عدم انقطاعها. لا تتحمل المنصة المسؤولية عن تصرفات السائقين أو الركاب '
          'أو عن الحوادث أو التأخير أو الأضرار الناتجة عن الرحلة، وذلك في حدود '
          'ما يسمح به القانون.',
    ]),
    LegalSection('١١. تعديل الشروط', [
      'قد نحدّث هذه الشروط من وقت لآخر، وسنُعلمك بالتغييرات الجوهرية داخل '
          'التطبيق. استمرارك في استخدام التطبيق بعد التحديث يعني موافقتك عليه.',
    ]),
    LegalSection('١٢. القانون المطبق', [
      'تخضع هذه الشروط لقوانين المملكة الأردنية الهاشمية، وتختص محاكمها بالنظر '
          'في أي نزاع ينشأ عنها.',
    ]),
    LegalSection('١٣. التواصل', [
      'لأي استفسار حول هذه الشروط تواصل معنا عبر صفحة "تواصل معنا" في التطبيق '
          'أو على البريد support@vision-way.com.',
    ]),
  ],
);

// ── Terms of Use — English ──────────────────────────────────────────────────

const _termsEn = LegalDocumentContent(
  title: 'Terms of Use',
  intro:
      'Welcome to VisionWay. By using the app or creating an account you agree '
      'to these terms. If you do not agree, please do not use the app.',
  sections: [
    LegalSection('1. The service', [
      'VisionWay is a technology platform that connects drivers offering seats '
          'on their trips with passengers who want to join them, on scheduled '
          'shared trips or on-demand instant rides.',
      'The platform is not a transport company: it does not own vehicles or '
          'employ drivers. Drivers are responsible for driving, for their '
          "vehicle's safety, and for valid licences and insurance.",
    ]),
    LegalSection('2. Eligibility and your account', [
      'You must be at least 18 years old to use the app.',
      'You register with a phone number verified by a code sent to it. You are '
          'responsible for the accuracy of your details, for keeping access to '
          'your account secure, and for all activity on it.',
      'One account per person; you may not use someone else\'s account.',
    ]),
    LegalSection('3. Drivers', [
      "Drivers must provide a valid driving licence, vehicle licence and "
          'accurate documents, which are reviewed before a driver account is '
          'activated.',
      'Drivers must follow traffic laws and keep to the advertised time, '
          'meeting point, number of seats, vehicle type and fare.',
      'A platform fee is charged for each shared trip at the rate shown in the '
          "app when the trip is published, deducted from the driver's wallet "
          'when the trip starts. If the balance does not cover it, the '
          'difference is recorded as owed and must be settled before publishing '
          'new trips.',
      'The first trip may be free of charge, as shown in the app.',
    ]),
    LegalSection('4. Passengers', [
      'Passengers must be on time at the meeting point, keep to the seats they '
          'booked, and treat the driver and other passengers with respect.',
      'A driver may decline a booking or end a ride for a passenger who '
          'breaches these terms or endangers safety.',
    ]),
    LegalSection('5. Fares and payment', [
      'The fare is shown before a booking or ride is confirmed. It is paid in '
          'cash to the driver, or electronically via CliQ where available.',
      "Fees and charges owed to the platform are paid from the in-app wallet, "
          'which can be topped up by the methods offered in the app. Amounts are '
          'shown in the currency of the country where the trip takes place.',
    ]),
    LegalSection('6. Cancellations and no-shows', [
      'Bookings can be cancelled within the window and rules shown in the app at '
          'the time. A late cancellation or a no-show, by a passenger or a '
          'driver, may incur a fee, which is shown before you confirm.',
    ]),
    LegalSection('7. Prohibited conduct', [
      'You may not use the app for anything unlawful, to carry prohibited items, '
          'to harass, abuse or discriminate, to give misleading information, to '
          'arrange trips outside the app to avoid fees, or to attack or misuse '
          'the app.',
    ]),
    LegalSection('8. Ratings and messages', [
      'Passengers and drivers can rate each other after a trip. Ratings and '
          'messages must be honest and appropriate; we may remove any that are '
          'not.',
      "Chats and calls go through the app without revealing the other party's "
          'phone number.',
    ]),
    LegalSection('9. Suspension and termination', [
      'We may suspend or close an account that breaches these terms, attracts '
          'repeated complaints, or puts other users at risk.',
      'You can delete your account at any time from Settings; any amounts you '
          'owe remain payable.',
    ]),
    LegalSection('10. Limitation of liability', [
      'We work to keep the service available and accurate, but it is provided '
          '"as is" without a guarantee of uninterrupted operation. To the extent '
          'permitted by law, the platform is not liable for the conduct of '
          'drivers or passengers, or for accidents, delays or damage arising from '
          'a trip.',
    ]),
    LegalSection('11. Changes to these terms', [
      'We may update these terms from time to time and will tell you about '
          'material changes in the app. Continuing to use the app after an update '
          'means you accept it.',
    ]),
    LegalSection('12. Governing law', [
      'These terms are governed by the laws of the Hashemite Kingdom of Jordan, '
          'whose courts have jurisdiction over any dispute arising from them.',
    ]),
    LegalSection('13. Contact', [
      'For any question about these terms, use "Contact us" in the app or write '
          'to support@vision-way.com.',
    ]),
  ],
);

// ── Privacy Policy — Arabic ─────────────────────────────────────────────────

const _privacyAr = LegalDocumentContent(
  title: 'سياسة الخصوصية',
  intro:
      'توضح هذه السياسة البيانات التي يجمعها تطبيق VisionWay، وكيف نستخدمها '
      'ونحميها، وحقوقك فيما يخصها.',
  sections: [
    LegalSection('١. البيانات التي نجمعها', [
      'بيانات الحساب: الاسم، رقم الهاتف، الجنس، المدينة، والصورة الشخصية.',
      'بيانات السائق: رخصة القيادة، رخصة المركبة، نوع المركبة ولونها ورقم '
          'لوحتها، وصور الوثائق المرفوعة للمراجعة.',
      'بيانات الموقع: موقعك عند البحث عن رحلة أو طلبها، ومسار السائق وموقعه '
          'أثناء الرحلة لعرضه للركاب. لا نتتبع موقعك خارج استخدام هذه الميزات.',
      'بيانات الرحلات والدفع: الحجوزات، الرحلات، الأجرة، حركات المحفظة، '
          'الرسوم، وطلبات الشحن وإثباتاتها.',
      'المحادثات والتقييمات والشكاوى التي ترسلها عبر التطبيق.',
      'بيانات الجهاز: نوع الجهاز ونظامه ومعرّف للإشعارات ومعرّف أمني للجهاز '
          'لحماية حسابك ومنع إساءة الاستخدام.',
    ]),
    LegalSection('٢. كيف نستخدم البيانات', [
      'لتشغيل الخدمة: ربط الركاب بالسائقين، عرض الرحلات، تنفيذ الحجوزات، '
          'وحساب الأجرة والرسوم.',
      'للسلامة والأمان: التحقق من الهوية والوثائق، منع الاحتيال، ومعالجة '
          'البلاغات والشكاوى.',
      'للتواصل معك: رموز التحقق، إشعارات الرحلات والحجوزات، ورسائل الدعم.',
      'لتحسين التطبيق وفهم طريقة استخدامه.',
    ]),
    LegalSection('٣. مشاركة البيانات', [
      'مع الطرف الآخر في الرحلة: يرى الراكب اسم السائق وصورته وتقييمه وبيانات '
          'مركبته وموقعه أثناء الرحلة، ويرى السائق اسم الراكب وصورته وتقييمه '
          'ونقطة الالتقاء. لا يُكشف رقم الهاتف للطرف الآخر.',
      'مع مزودي خدمات نعتمد عليهم: إرسال رسائل التحقق النصية، الإشعارات، '
          'الخرائط وتحديد المواقع، والدفع الإلكتروني عبر البنوك وCliQ. يحصل '
          'هؤلاء فقط على ما يلزم لتقديم خدمتهم.',
      'مع الجهات الرسمية عندما يفرض القانون ذلك أو لحماية سلامة المستخدمين.',
      'لا نبيع بياناتك الشخصية لأي طرف.',
    ]),
    LegalSection('٤. حفظ البيانات وحمايتها', [
      'تُحفظ البيانات على خوادم محمية، وتُنقل عبر اتصال مشفّر.',
      'نحتفظ بالبيانات طوال مدة وجود حسابك. عند حذف الحساب نحذف بياناتك أو '
          'نجعلها غير مرتبطة بك، باستثناء ما يلزمنا القانون بالاحتفاظ به، مثل '
          'سجلات المعاملات المالية.',
    ]),
    LegalSection('٥. حقوقك', [
      'يمكنك الاطلاع على بياناتك وتعديلها من الملف الشخصي.',
      'يمكنك التحكم في مشاركة الموقع والإشعارات من إعدادات التطبيق وإعدادات '
          'الجهاز.',
      'يمكنك حذف حسابك من الإعدادات، أو طلب نسخة من بياناتك أو حذفها عبر '
          'التواصل معنا.',
    ]),
    LegalSection('٦. الأطفال', [
      'التطبيق غير موجّه لمن هم دون ١٨ عاماً، ولا نجمع بياناتهم عن قصد.',
    ]),
    LegalSection('٧. تحديث السياسة', [
      'قد نحدّث هذه السياسة، وسنُعلمك بالتغييرات الجوهرية داخل التطبيق.',
    ]),
    LegalSection('٨. التواصل', [
      'لأي استفسار عن خصوصيتك تواصل معنا عبر صفحة "تواصل معنا" أو على البريد '
          'support@vision-way.com.',
    ]),
  ],
);

// ── Privacy Policy — English ────────────────────────────────────────────────

const _privacyEn = LegalDocumentContent(
  title: 'Privacy Policy',
  intro:
      'This policy explains what data VisionWay collects, how we use and '
      'protect it, and your rights over it.',
  sections: [
    LegalSection('1. Data we collect', [
      'Account data: name, phone number, gender, city and profile photo.',
      "Driver data: driving licence, vehicle licence, vehicle type, colour and "
          'plate number, and the document photos uploaded for review.',
      'Location: your location when you search for or request a trip, and the '
          "driver's location and route during a trip so passengers can follow it. "
          'We do not track your location outside these features.',
      'Trips and payments: bookings, trips, fares, wallet transactions, fees, '
          'and top-up requests with their proof.',
      'Chats, ratings and complaints you send through the app.',
      'Device data: device model and operating system, a notification token, '
          'and a security identifier for the device used to protect your account '
          'and prevent misuse.',
    ]),
    LegalSection('2. How we use it', [
      'To run the service: matching passengers with drivers, showing trips, '
          'handling bookings, and calculating fares and fees.',
      'For safety and security: verifying identity and documents, preventing '
          'fraud, and handling reports and complaints.',
      'To contact you: verification codes, trip and booking notifications, and '
          'support messages.',
      'To improve the app and understand how it is used.',
    ]),
    LegalSection('3. Sharing', [
      "With the other party on a trip: passengers see the driver's name, photo, "
          "rating, vehicle details and location during the trip; drivers see the "
          "passenger's name, photo, rating and meeting point. Phone numbers are "
          'never shown to the other party.',
      'With service providers we rely on, for verification text messages, '
          'notifications, maps and location, and electronic payment through banks '
          'and CliQ. They receive only what they need to provide their service.',
      'With authorities when the law requires it or to protect users\' safety.',
      'We do not sell your personal data.',
    ]),
    LegalSection('4. Storage and protection', [
      'Data is stored on protected servers and sent over encrypted connections.',
      'We keep data for as long as your account exists. When you delete your '
          'account we delete your data or make it no longer linked to you, except '
          'what the law requires us to keep, such as financial transaction '
          'records.',
    ]),
    LegalSection('5. Your rights', [
      'You can view and edit your data from your profile.',
      'You control location sharing and notifications in the app settings and '
          'your device settings.',
      'You can delete your account from Settings, or ask us for a copy of your '
          'data or for its deletion by contacting us.',
    ]),
    LegalSection('6. Children', [
      'The app is not intended for anyone under 18, and we do not knowingly '
          'collect their data.',
    ]),
    LegalSection('7. Changes to this policy', [
      'We may update this policy and will tell you about material changes in '
          'the app.',
    ]),
    LegalSection('8. Contact', [
      'For any privacy question, use "Contact us" in the app or write to '
          'support@vision-way.com.',
    ]),
  ],
);
