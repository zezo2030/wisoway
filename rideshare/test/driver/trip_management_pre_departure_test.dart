import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/driver/widgets/trip_facts_strip.dart';
import 'package:rideshare/screens/driver/widgets/trip_fare_breakdown_card.dart';
import 'package:rideshare/screens/driver/widgets/trip_route_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('route card shows origin and destination names', (tester) async {
    await tester.pumpWidget(
      wrap(const TripRouteCard(fromName: 'عمان', toName: 'الطفيلة')),
    );

    expect(find.text('عمان'), findsOneWidget);
    expect(find.text('الطفيلة'), findsOneWidget);
  });

  testWidgets('facts strip falls back to the origin name with no address', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TripFactsStrip(
          departureTime: DateTime(2024, 7, 26, 7, 0),
          meetingPoint: null,
          originName: 'عمان',
          distanceKm: 181,
          bookedSeats: 4,
          totalSeats: 4,
        ),
      ),
    );

    expect(find.text('عمان'), findsOneWidget);
    expect(find.textContaining('181'), findsOneWidget);
    expect(find.text('4 من 4'), findsOneWidget);
    expect(find.text('مكتملة'), findsOneWidget);
  });

  testWidgets('facts strip hides the complete badge when seats remain', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TripFactsStrip(
          departureTime: DateTime(2024, 7, 26, 7, 0),
          meetingPoint: 'دوار المدينة الرياضية',
          originName: 'عمان',
          distanceKm: 181,
          bookedSeats: 2,
          totalSeats: 4,
        ),
      ),
    );

    expect(find.text('دوار المدينة الرياضية'), findsOneWidget);
    expect(find.text('2 من 4'), findsOneWidget);
    expect(find.text('مكتملة'), findsNothing);
  });

  testWidgets('fare breakdown multiplies by booked seats and shows the fee', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TripFareBreakdownCard(
          seatPrice: 4.0,
          bookedSeats: 4,
          feeAmount: 1.6,
          feePercent: 10,
          currency: 'JOD',
        ),
      ),
    );

    expect(find.textContaining('4.00'), findsWidgets);
    expect(find.textContaining('16.00'), findsOneWidget);
    expect(find.textContaining('1.60'), findsOneWidget);
    expect(find.textContaining('10'), findsWidgets);
  });

  testWidgets('the fee notice says at trip start, not at trip end', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const TripFeeNotice()));

    expect(find.textContaining('عند انطلاق الرحلة'), findsOneWidget);
    expect(find.textContaining('عند انتهاء الرحلة'), findsNothing);
  });
}
