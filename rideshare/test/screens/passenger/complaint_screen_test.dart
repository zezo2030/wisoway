import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/passenger/complaint_screen.dart';

void main() {
  testWidgets('opens on «لم أكن في الرحلة» from the trip screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ComplaintScreen(
          tripId: 't-1',
          againstUserId: 'd-1',
          initialCategory: 'not_on_trip',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('لم أكن في الرحلة'), findsWidgets);
  });
}
