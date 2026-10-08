import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/constants/route_names.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/auth/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LocalizationService(),
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const WelcomeScreen(),
        routes: {
          RouteNames.driverSignUp: (_) =>
              const Scaffold(body: Text('driver sign-up')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('no welcome headline and no descriptions under the tiles', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844));

    expect(find.textContaining('مرحباً بك في'), findsNothing);
    for (final body in [
      'رحلتك الخاصة مباشرة وسريعة ومريحة',
      'شارك الرحلة ووفر أكثر صديق للبيئة',
      'أسعار عادلة بدون مفاجآت',
      'احجز رحلتك في خطوات بسيطة',
      'سائقون موثوقون ورحلات آمنة',
    ]) {
      expect(find.text(body), findsNothing);
    }
    // The tiles keep only their titles.
    expect(find.text('رحلات مباشرة'), findsOneWidget);
    expect(find.text('رحلات مشتركة'), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    testWidgets('fits ${size.width.toInt()}×${size.height.toInt()} '
        'without scrolling', (tester) async {
      await _pump(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      final create = tester.getRect(find.text('إنشاء حساب جديد'));
      expect(create.bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('"انضم كسائق 🚗" opens driver sign-up directly', (tester) async {
    await _pump(tester, const Size(390, 844));

    await tester.tap(find.text('انضم كسائق 🚗'));
    await tester.pumpAndSettle();

    expect(find.text('driver sign-up'), findsOneWidget);
  });
}
