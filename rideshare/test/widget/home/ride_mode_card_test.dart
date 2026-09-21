import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/home/widgets/ride_mode_card.dart';

Widget _host(RideMode mode, {VoidCallback? onPressed}) => MaterialApp(
  locale: const Locale('ar'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Row(
      children: [
        Expanded(
          child: RideModeCard(mode: mode, onPressed: onPressed ?? () {}),
        ),
      ],
    ),
  ),
);

void main() {
  group('RideModeCard', () {
    testWidgets('sells the shared ride on price and company', (tester) async {
      await tester.pumpWidget(_host(RideMode.shared));

      expect(find.text('أوفر'), findsOneWidget);
      expect(find.text('رحلة مشتركة'), findsOneWidget);
      expect(find.text('أسعار أقل'), findsOneWidget);
      expect(find.text('ابحث عن رحلة'), findsOneWidget);
    });

    testWidgets('sells the private ride on speed and privacy', (tester) async {
      await tester.pumpWidget(_host(RideMode.private));

      expect(find.text('أسرع'), findsOneWidget);
      expect(find.text('رحلة مع سائق'), findsOneWidget);
      expect(find.text('خصوصية تامة'), findsOneWidget);
      expect(find.text('اطلب الآن'), findsOneWidget);
    });

    testWidgets('opens the flow from the call to action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(RideMode.private, onPressed: () => taps++),
      );

      await tester.tap(find.text('اطلب الآن'));

      expect(taps, 1);
    });

    testWidgets('opens the flow from anywhere on the card', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(RideMode.shared, onPressed: () => taps++));

      await tester.tap(find.text('رحلة مشتركة'));

      expect(taps, 1);
    });

    // Two cards share a 360dp-wide phone, so each gets roughly 160dp.
    for (final mode in RideMode.values) {
      testWidgets('fits a 160dp column in $mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 160,
                child: RideModeCard(mode: mode, onPressed: () {}),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
