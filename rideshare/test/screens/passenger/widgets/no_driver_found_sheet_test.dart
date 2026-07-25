import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/passenger/widgets/no_driver_found_sheet.dart';

void main() {
  testWidgets('shows illustration, copy, both actions and the support link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        NoDriverFoundSheet(
          onRetry: () async {},
          onClose: () {},
          onSupport: () {},
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text("We couldn't find a driver right now"), findsOneWidget);
    expect(
      find.text('All nearby drivers may be busy, or none may be close to you.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tip: Try again in a few minutes; a nearby driver may become available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);
    expect(find.text('Need help?'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
  });

  testWidgets('taps route to the matching callbacks', (tester) async {
    var retries = 0;
    var closes = 0;
    var supports = 0;

    await tester.pumpWidget(
      _host(
        NoDriverFoundSheet(
          onRetry: () async => retries++,
          onClose: () => closes++,
          onSupport: () => supports++,
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.tap(find.text('Cancel request'));
    await tester.tap(find.text('Contact support'));
    await tester.pump();

    expect(retries, 1);
    expect(closes, 1);
    expect(supports, 1);
  });

  testWidgets('while retrying both buttons are disabled and a spinner shows', (
    tester,
  ) async {
    var retries = 0;
    var closes = 0;

    await tester.pumpWidget(
      _host(
        NoDriverFoundSheet(
          retrying: true,
          onRetry: () async => retries++,
          onClose: () => closes++,
          onSupport: () {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.tap(find.text('Cancel request'));
    await tester.pump();

    expect(retries, 0);
    expect(closes, 0);
  });

  testWidgets('exposes the failure copy and button names to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        NoDriverFoundSheet(
          onRetry: () async {},
          onClose: () {},
          onSupport: () {},
        ),
      ),
    );

    expect(
      find.bySemanticsLabel("We couldn't find a driver right now"),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('No driver found'), findsOneWidget);
    expect(find.bySemanticsLabel('Try again'), findsOneWidget);
    expect(find.bySemanticsLabel('Cancel request'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('fits a small viewport at 1.3x text scale without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        NoDriverFoundSheet(
          onRetry: () async {},
          onClose: () {},
          onSupport: () {},
        ),
        textScale: 1.3,
        scrollable: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders right-to-left in Arabic', (tester) async {
    await tester.pumpWidget(
      _host(
        NoDriverFoundSheet(
          onRetry: () async {},
          onClose: () {},
          onSupport: () {},
        ),
        locale: const Locale('ar'),
      ),
    );

    expect(find.text('لم نتمكن من العثور على سائق حاليًا'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('إعادة المحاولة'))),
      TextDirection.rtl,
    );
  });

  testWidgets('golden — Arabic', (tester) async {
    await _pumpGolden(tester, const Locale('ar'));
    await expectLater(
      find.byType(NoDriverFoundSheet),
      matchesGoldenFile('goldens/no_driver_found_sheet_ar.png'),
    );
  });

  testWidgets('golden — English', (tester) async {
    await _pumpGolden(tester, const Locale('en'));
    await expectLater(
      find.byType(NoDriverFoundSheet),
      matchesGoldenFile('goldens/no_driver_found_sheet_en.png'),
    );
  });
}

/// Lays the sheet out at a 390x844 phone width with the illustration actually
/// decoded — `Image.asset` needs real async to resolve inside a test.
Future<void> _pumpGolden(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _host(
      NoDriverFoundSheet(
        onRetry: () async {},
        onClose: () {},
        onSupport: () {},
      ),
      locale: locale,
    ),
  );

  final context = tester.element(find.byType(NoDriverFoundSheet));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/illustrations/no_driver_found.png'),
      context,
    ),
  );
  await tester.pumpAndSettle();
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  bool scrollable = false,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, widget) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: widget!,
    ),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: scrollable
            ? SingleChildScrollView(child: child)
            : Center(child: child),
      ),
    ),
  );
}
