import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/trip_fee_quote.dart';
import 'package:rideshare/screens/driver/create_trip/create_trip_wizard_state.dart';
import 'package:rideshare/screens/driver/create_trip/step3_review.dart';

void main() {
  testWidgets('review step shows the fee and when it will be charged', (
    tester,
  ) async {
    final wizard = CreateTripWizardState();
    addTearDown(wizard.dispose);
    wizard.priceController.text = '4.0';
    wizard.availableSeatCount = 4;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Step3Review(
            wizard: wizard,
            vehicle: null,
            currency: 'JOD',
            feeQuote: const TripFeeQuote(amount: 1.6, percent: 10, currency: 'JOD'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1.60'), findsOneWidget);
    expect(find.textContaining('عند انطلاق الرحلة'), findsOneWidget);
  });
}
