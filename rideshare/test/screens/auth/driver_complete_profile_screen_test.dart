import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/screens/auth/driver_complete_profile_screen.dart';
import 'package:rideshare/widgets/auth/auth_step_indicator.dart';
import 'package:rideshare/widgets/auth/security_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The wizard bootstraps through the API client, which reads the token from
    // secure storage; without a stub that channel throws before the first
    // frame the layout assertions need.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  group('DriverCompleteProfileScreen header', () {
    // The header used to be stacked inside a fixed 250px illustration, where it
    // overflowed by 63px and left the stepper captions on top of the driver.
    testWidgets('lays the title block out above the illustration', (
      tester,
    ) async {
      await _pump(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DriverCompleteProfileScreen)),
      );
      final art = tester.getRect(_heroArt);

      for (final above in [
        find.text(l10n.completeDriverProfileTitle),
        find.text(l10n.driverStep2Badge),
        find.byType(SecurityNotice),
      ]) {
        expect(above, findsOneWidget);
        expect(tester.getRect(above).bottom, lessThanOrEqualTo(art.top));
      }
    });

    testWidgets('moves the stepper captions onto the form sheet', (
      tester,
    ) async {
      await _pump(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DriverCompleteProfileScreen)),
      );

      expect(find.byType(AuthStepIndicator), findsOneWidget);
      expect(
        tester.getRect(find.text(l10n.authStepperIdDocs)).top,
        greaterThan(tester.getRect(_heroArt).top),
      );
    });
  });
}

final Finder _heroArt = find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName.contains('auth_driver_step2_header'),
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // google_fonts cannot fetch Tajawal in a test and the fallback font is
        // far wider per glyph, so the text is scaled down to keep the layout
        // representative.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.5,
          maxScaleFactor: 0.5,
          child: child!,
        ),
        home: const DriverCompleteProfileScreen(),
      ),
    ),
  );
  // The wizard shows a spinner until its post-frame bootstrap settles.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}
