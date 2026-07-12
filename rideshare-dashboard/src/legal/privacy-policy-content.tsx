// Static privacy policy copy (EN / AR) for the public /privacy page.
// Aligns with VisionWay rideshare features described in the platform (trips, bookings, payments, chat, notifications, location).

import type { ReactNode } from "react"

type Locale = "en" | "ar"

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-bold text-slate-900 dark:text-white border-b border-slate-200 dark:border-slate-700 pb-2">
        {title}
      </h2>
      <div className="space-y-3 text-sm leading-relaxed text-slate-600 dark:text-slate-300">{children}</div>
    </section>
  )
}

export function PrivacyPolicyContent({ locale }: { locale: Locale }) {
  if (locale === "ar") {
    return (
      <div className="space-y-10">
        <Section title="من نحن">
          <p>
            تشرح هذه السياسة كيفية جمع واستخدام ومشاركة وحماية معلوماتك عند استخدام تطبيق وخدمات VisionWay
            لمشاركة الرحلات (الركاب والسائقين والحجوزات والمدفوعات والمحادثات داخل التطبيق).
          </p>
        </Section>
        <Section title="البيانات التي نجمعها">
          <ul className="list-disc ps-5 space-y-2">
            <li>
              <strong className="text-slate-800 dark:text-slate-200">بيانات الحساب:</strong> الاسم، رقم الهاتف،
              البريد الإلكتروني عند توفره، الصورة، الجنس عند التسجيل، وبيانات التحقق من الهوية عند طلبها.
            </li>
            <li>
              <strong className="text-slate-800 dark:text-slate-200">بيانات الرحلة والموقع:</strong> نقاط الانطلاق
              والوصول، مسار الرحلة عند الحاجة، وحالة الحجز، لتمكين المطابقة، التسعير، والسلامة التشغيلية.
            </li>
            <li>
              <strong className="text-slate-800 dark:text-slate-200">بيانات المركبة والوثائق:</strong> معلومات
              المركبة والصور أو المستندات التي ترفعها كسائق لأغراض التحقق.
            </li>
            <li>
              <strong className="text-slate-800 dark:text-slate-200">المدفوعات والمحفظة:</strong> سجل المعاملات،
              طريقة الدفع، وحالة الموافقة؛ قد تتم معالجة جزء من الدفع عبر مزوّدين خارجيين (مثل بوابات الدفع أو
              تحويلات بنكية وفق الإعدادات المتاحة في منطقتك).
            </li>
            <li>
              <strong className="text-slate-800 dark:text-slate-200">الاتصالات والدعم:</strong> رسائل الدردشة داخل
              التطبيق المتعلقة بالرحلات، والبلاغات أو الطلبات المرسلة للدعم.
            </li>
            <li>
              <strong className="text-slate-800 dark:text-slate-200">الجهاز والتشغيل:</strong> معرفات الجهاز
              والنظام لأغراض الأمان، منع الاحتيال، وإرسال الإشعارات الفورية.
            </li>
          </ul>
        </Section>
        <Section title="كيف نستخدم البيانات">
          <ul className="list-disc ps-5 space-y-2">
            <li>إنشاء الحسابات وتوفير الخدمة (نشر الرحلات، الحجز، التقييم، المحفظة).</li>
            <li>التحقق عبر رمز قصير إلى هاتفك (SMS) عند الحاجة.</li>
            <li>إرسال إشعارات متعلقة بالرحلة أو الحساب عبر خدمات الإشعارات الفورية.</li>
            <li>منع الإساءة، الاحتيال، وانتهاك الشروط؛ وإدارة النزاعات والغرامات أو الرسوم عندما تنطبق السياسات.</li>
            <li>الامتثال للقانون والطلبات النظامية عند الاقتضاء.</li>
          </ul>
        </Section>
        <Section title="المشاركة مع أطراف ثالثة">
          <p>
            لا نبيع بياناتك الشخصية. قد نشارك بياناتاً محدودة مع مزوّدي بنية تحتية موثوقين (مثل استضافة الخادم،
            رسائل SMS، الإشعارات الفورية، بوابات الدفع، وخرائط الموقع) بقدر ما يلزم لتشغيل الخدمة، مع التزامات
            تعاقدية مناسبة حيثما ينطبق ذلك.
          </p>
        </Section>
        <Section title="الاحتفاظ والأمان">
          <p>
            نحتفظ بالبيانات للمدة اللازمة لتقديم الخدمة والالتزامات القانونية وحل النزاعات. نطبّق إجراءات أمنية
            معقولة تقنياً وتنظيمياً؛ ولا يوجد أي نظام خالٍ تماماً من المخاطر.
          </p>
        </Section>
        <Section title="حقوقك">
          <p>
            حسب القانون المعمول به، قد يشمل ذلك طلب الوصول أو التصحيح أو الحذف أو تقييد المعالجة أو الاعتراض؛
            يمكنك التواصل معنا عبر قنوات الدعم داخل التطبيق أو البريد المخصص للخصوصية إن وُجد.
          </p>
        </Section>
        <Section title="التغييرات على هذه السياسة">
          <p>
            قد نحدّث هذه السياسة من وقت لآخر. سنوضح تاريخ &quot;آخر تحديث&quot; أعلى الصفحة؛ الاستمرار في استخدام
            التطبيق بعد التحديث يعني موافقتك حيث يسمح القانون بذلك.
          </p>
        </Section>
      </div>
    )
  }

  return (
    <div className="space-y-10">
      <Section title="Who we are">
        <p>
          This policy describes how VisionWay collects, uses, shares, and protects your information when you use our
          ridesharing services (passengers and drivers, trip listings, bookings, in-app payments and wallet, chat, and
          related features).
        </p>
      </Section>
      <Section title="Information we collect">
        <ul className="list-disc ps-5 space-y-2">
          <li>
            <strong className="text-slate-800 dark:text-slate-200">Account data:</strong> name, phone number, email
            when provided, profile photo, gender if collected at registration, and identity-related information when
            required for verification.
          </li>
          <li>
            <strong className="text-slate-800 dark:text-slate-200">Trip and location data:</strong> pickup and drop-off
            details, route or trip-related location as needed for matching, pricing, safety, and service quality.
          </li>
          <li>
            <strong className="text-slate-800 dark:text-slate-200">Vehicle and documents:</strong> vehicle information
            and images or documents you upload as a driver for verification.
          </li>
          <li>
            <strong className="text-slate-800 dark:text-slate-200">Payments and wallet:</strong> transaction history,
            payment method, and approval status; parts of payment processing may be handled by third-party payment or
            banking providers available in your region.
          </li>
          <li>
            <strong className="text-slate-800 dark:text-slate-200">Communications:</strong> in-app trip-related chat and
            messages you send to support or complaints workflows.
          </li>
          <li>
            <strong className="text-slate-800 dark:text-slate-200">Device and operations:</strong> device and OS
            identifiers for security, fraud prevention, and push notifications.
          </li>
        </ul>
      </Section>
      <Section title="How we use information">
        <ul className="list-disc ps-5 space-y-2">
          <li>Provide and improve the service (trips, bookings, ratings, wallet).</li>
          <li>Send SMS one-time codes for verification when applicable.</li>
          <li>Send push notifications related to trips or your account.</li>
          <li>Detect abuse, fraud, and policy violations; operate fines, fees, or dispute flows where applicable.</li>
          <li>Comply with law and lawful requests when required.</li>
        </ul>
      </Section>
      <Section title="Sharing with third parties">
        <p>
          We do not sell your personal information. We may share limited data with infrastructure and service providers
          (for example hosting, SMS, push notifications, payment gateways, and mapping) strictly as needed to operate
          the platform, subject to appropriate contractual safeguards where applicable.
        </p>
      </Section>
      <Section title="Retention and security">
        <p>
          We retain data for as long as needed to provide the service, meet legal obligations, and resolve disputes. We
          apply reasonable technical and organizational measures; no method of transmission or storage is 100% secure.
        </p>
      </Section>
      <Section title="Your rights">
        <p>
          Depending on applicable law, you may have rights to access, correct, delete, restrict, or object to certain
          processing. Contact us through in-app support or your designated privacy contact if one is published by your
          operator.
        </p>
      </Section>
      <Section title="Changes">
        <p>
          We may update this policy from time to time. The &quot;Last updated&quot; date at the top of this page will
          change; continued use of the app after updates constitutes your agreement where permitted by law.
        </p>
      </Section>
    </div>
  )
}
