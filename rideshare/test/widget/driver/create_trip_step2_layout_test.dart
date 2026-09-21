import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/driver/create_trip/create_trip_stepper.dart';
import 'package:rideshare/screens/driver/create_trip/create_trip_wizard_state.dart';
import 'package:rideshare/screens/driver/create_trip/step2_details.dart';

/// Notes and recurrence used to sit side by side, which left each card about a
/// third of the screen: both titles truncated and the notes box was unusable.
/// These pin them to a full-width stack.
void main() {
  late CreateTripWizardState wizard;

  setUp(() => wizard = CreateTripWizardState());

  Future<void> pumpStep(WidgetTester tester) async {
    // Tall viewport so the whole step lays out at once and no scrolling is
    // needed to measure a card near the bottom.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Step2Details(
            wizard: wizard,
            isLoadingVehicle: false,
            currency: 'JOD',
            priceSuggestion: null,
            onChanged: () {},
            onPickDate: () {},
            onPickTime: () {},
            onPickRecurrenceUntil: () {},
            onOpenVehicleSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect cardRectFor(WidgetTester tester, String title) {
    return tester.getRect(
      find
          .ancestor(
            of: find.text(title),
            matching: find.byType(CreateTripCard),
          )
          .first,
    );
  }

  group('Step2Details notes and recurrence', () {
    testWidgets('stacks the two cards instead of pairing them in a row', (
      tester,
    ) async {
      await pumpStep(tester);

      final notes = cardRectFor(tester, 'ملاحظات للركاب');
      final recurrence = cardRectFor(tester, 'تكرار الرحلة');

      // Same column, recurrence below notes — not two half-width siblings.
      expect(recurrence.top, greaterThan(notes.bottom));
      expect(recurrence.left, closeTo(notes.left, 1));
      expect(recurrence.width, closeTo(notes.width, 1));
    });

    testWidgets('gives each card the full content width', (tester) async {
      await pumpStep(tester);

      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      final notes = cardRectFor(tester, 'ملاحظات للركاب');

      // 16dp of page padding on each side, nothing else taken by a sibling.
      expect(notes.width, closeTo(screenWidth - 32, 1));
    });

    testWidgets('says what recurrence does while its switch is off', (
      tester,
    ) async {
      await pumpStep(tester);

      expect(find.text('ملاحظات للركاب'), findsOneWidget);
      expect(find.text('تكرار الرحلة'), findsOneWidget);
      expect(find.text('تكرار أسبوعي أو يومي'), findsOneWidget);
    });

    testWidgets('drops the summary line once recurrence is switched on', (
      tester,
    ) async {
      wizard.enableRecurrence = true;
      await pumpStep(tester);

      expect(find.text('تكرار أسبوعي أو يومي'), findsNothing);
      expect(find.text('أيام التكرار'), findsOneWidget);
    });
  });
}
