import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/screens/auth/driver_sign_up_screen.dart';
import 'package:rideshare/widgets/auth/auth_language_switcher.dart';
import 'package:rideshare/widgets/auth/security_notice.dart';
import 'package:rideshare/widgets/country_code_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DriverSignUpScreen hero top bar', () {
    // The mockup keeps this bar physically fixed, so the assertions are about
    // screen coordinates rather than start/end.
    for (final locale in const [Locale('ar'), Locale('en')]) {
      final code = locale.languageCode;

      testWidgets('puts back on the left and the language pill on the right '
          'in $code', (tester) async {
        await _pump(tester, locale);

        final back = find.byIcon(Icons.chevron_left_rounded);
        final pill = find.byType(AuthLanguageSwitcher);

        expect(back, findsOneWidget);
        expect(pill, findsOneWidget);
        expect(tester.getCenter(back).dx, lessThan(tester.getCenter(pill).dx));
      });
    }

    testWidgets('never mirrors the back chevron', (tester) async {
      await _pump(tester, const Locale('ar'));

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      // chevron_left_rounded has matchTextDirection: true and would render as
      // ">" under Arabic, so the LTR scope around it is the real assertion.
      expect(
        Directionality.of(
          tester.element(find.byIcon(Icons.chevron_left_rounded)),
        ),
        TextDirection.ltr,
      );
    });

    testWidgets('dial code and phone hint read left-to-right in Arabic', (
      tester,
    ) async {
      await _pump(tester, const Locale('ar'));

      expect(
        Directionality.of(tester.element(find.text('+962'))),
        TextDirection.ltr,
      );
      expect(
        Directionality.of(
          tester.element(
            find.descendant(
              of: find.byType(CountryCodePicker),
              matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
        ),
        TextDirection.ltr,
      );
    });
  });

  group('DriverSignUpScreen hero header', () {
    // The header used to be stacked over the illustration, which left the
    // subtitle and the privacy line sitting on the car and unreadable.
    for (final locale in const [Locale('ar'), Locale('en')]) {
      final code = locale.languageCode;

      testWidgets('keeps the title block clear of the illustration in $code', (
        tester,
      ) async {
        await _pump(tester, locale);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(DriverSignUpScreen)),
        );
        final art = tester.getRect(_heroArt);

        for (final above in [
          find.text(l10n.driverSignupTitle),
          find.text(l10n.driverSignupSubtitle),
          find.byType(SecurityNotice),
        ]) {
          expect(above, findsOneWidget);
          expect(tester.getRect(above).bottom, lessThanOrEqualTo(art.top));
        }
      });
    }

    testWidgets('keeps the header ink dark under the dark theme', (
      tester,
    ) async {
      // The hero holds the illustration's light backdrop in both themes, so
      // scheme-driven ink would turn the whole header white-on-white.
      await _pump(tester, const Locale('ar'), theme: AppTheme.darkTheme);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DriverSignUpScreen)),
      );

      for (final text in [l10n.driverSignupTitle, l10n.driverSignupSubtitle]) {
        final style = tester.widget<Text>(find.text(text)).style!;
        expect(style.color!.computeLuminance(), lessThan(0.2));
      }
    });
  });

  testWidgets('continue button keeps the mockup arrow in Arabic', (
    tester,
  ) async {
    await _pump(tester, const Locale('ar'));

    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });
}

final Finder _heroArt = find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName.contains('auth_driver_step1_hero'),
);

Future<void> _pump(
  WidgetTester tester,
  Locale locale, {
  ThemeData? theme,
}) async {
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
        theme: theme ?? AppTheme.lightTheme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // The app renders in Tajawal, which google_fonts cannot fetch in a
        // test; the fallback test font is far wider per glyph and would
        // overflow the hero purely as a metrics artifact. Scaling the text
        // down keeps the layout representative for the icon positions this
        // test is about.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.5,
          maxScaleFactor: 0.5,
          child: child!,
        ),
        home: const DriverSignUpScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
