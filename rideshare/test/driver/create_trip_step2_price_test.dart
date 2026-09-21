import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/trip_price_suggestion.dart';
import 'package:rideshare/screens/driver/create_trip/create_trip_wizard_state.dart';
import 'package:rideshare/screens/driver/create_trip/step2_details.dart';

Widget _host({
  required CreateTripWizardState wizard,
  required String currency,
  TripPriceSuggestion? suggestion,
}) {
  return MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Step2Details(
        wizard: wizard,
        isLoadingVehicle: false,
        currency: currency,
        priceSuggestion: suggestion,
        onChanged: () {},
        onPickDate: () {},
        onPickTime: () {},
        onPickRecurrenceUntil: () {},
        onOpenVehicleSettings: () {},
      ),
    ),
  );
}

void main() {
  late CreateTripWizardState wizard;

  setUp(() {
    wizard = CreateTripWizardState();
  });

  tearDown(() => wizard.dispose());

  testWidgets('shows the suggested band for the route', (tester) async {
    await tester.pumpWidget(
      _host(
        wizard: wizard,
        currency: 'JOD',
        suggestion: const TripPriceSuggestion(
          basis: 'history',
          currency: 'JOD',
          min: 14,
          max: 18,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('14 - 18'), findsOneWidget);
    expect(find.textContaining('السعر المقترح'), findsOneWidget);
  });

  testWidgets('hides the hint when no suggestion is available', (tester) async {
    await tester.pumpWidget(_host(wizard: wizard, currency: 'JOD'));
    await tester.pumpAndSettle();

    expect(find.textContaining('السعر المقترح'), findsNothing);
  });

  testWidgets('hides the hint when the band collapsed', (tester) async {
    await tester.pumpWidget(
      _host(
        wizard: wizard,
        currency: 'JOD',
        suggestion: const TripPriceSuggestion(
          basis: 'distance',
          currency: 'JOD',
          min: 0,
          max: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('السعر المقترح'), findsNothing);
  });

  testWidgets('names the resolved currency instead of hardcoding dinars', (
    tester,
  ) async {
    await tester.pumpWidget(_host(wizard: wizard, currency: 'AED'));
    await tester.pumpAndSettle();

    expect(find.text('AED'), findsOneWidget);
    expect(find.text('درهم إماراتي'), findsOneWidget);
    expect(find.text('دينار أردني'), findsNothing);
  });
}
