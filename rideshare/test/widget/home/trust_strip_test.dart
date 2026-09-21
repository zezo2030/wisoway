import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/home/widgets/trust_strip.dart';

Widget _host({Size size = const Size(360, 800)}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: TrustStrip()),
  ),
);

void main() {
  group('TrustStrip', () {
    testWidgets('states the four promises the app makes', (tester) async {
      await tester.pumpWidget(_host());

      expect(find.text('رحلة آمنة'), findsOneWidget);
      expect(find.text('دعم 24/7'), findsOneWidget);
      expect(find.text('خيارات دفع متعددة'), findsOneWidget);
      expect(find.text('في موعدك'), findsOneWidget);
    });

    testWidgets('fits a narrow phone without overflowing', (tester) async {
      await tester.pumpWidget(_host(size: const Size(320, 640)));

      expect(tester.takeException(), isNull);
    });
  });
}
