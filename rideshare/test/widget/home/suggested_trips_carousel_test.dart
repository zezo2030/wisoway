import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/screens/home/widgets/suggested_trip_card.dart';
import 'package:rideshare/screens/home/widgets/suggested_trips_carousel.dart';

TripModel _trip(String id) => TripModel.fromJson({
  'id': id,
  'driverId': 'driver-1',
  'fromName': 'العلا',
  'toName': 'تبوك',
  'departureTime': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
  'price': 65,
  'currency': 'SAR',
  'totalSeats': 4,
  'availableSeats': 2,
});

Widget _host(List<TripModel> trips, {void Function(TripModel)? onTripTap}) =>
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SuggestedTripsCarousel(
          trips: trips,
          onTripTap: onTripTap ?? (_) {},
        ),
      ),
    );

double _dotWidth(WidgetTester tester, int index) =>
    tester.getSize(find.byKey(ValueKey('suggested-dot-$index'))).width;

void main() {
  group('SuggestedTripsCarousel', () {
    testWidgets('draws a card per suggested trip', (tester) async {
      await tester.pumpWidget(_host([_trip('a'), _trip('b'), _trip('c')]));

      expect(find.byType(SuggestedTripCard), findsNWidgets(3));
    });

    testWidgets('pages the carousel with one dot per trip', (tester) async {
      await tester.pumpWidget(_host([_trip('a'), _trip('b')]));

      expect(find.byKey(const ValueKey('suggested-dot-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggested-dot-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggested-dot-2')), findsNothing);
    });

    testWidgets('starts with the first dot active', (tester) async {
      await tester.pumpWidget(_host([_trip('a'), _trip('b')]));

      expect(_dotWidth(tester, 0), greaterThan(_dotWidth(tester, 1)));
    });

    testWidgets('moves the active dot as the carousel scrolls', (tester) async {
      // Enough cards to overflow the test viewport, otherwise there is nothing
      // to scroll.
      await tester.pumpWidget(
        _host(List.generate(8, (index) => _trip('trip-$index'))),
      );

      // Arabic reads right-to-left, so the carousel advances with a rightward
      // drag.
      await tester.drag(
        find.byType(SuggestedTripsCarousel),
        const Offset(SuggestedTripCard.cardWidth, 0),
      );
      await tester.pump();

      expect(_dotWidth(tester, 1), greaterThan(_dotWidth(tester, 0)));
    });

    testWidgets('opens the trip that was tapped', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _host([_trip('a'), _trip('b')], onTripTap: (t) => tapped.add(t.id)),
      );

      await tester.tap(find.byType(SuggestedTripCard).first);

      expect(tapped, ['a']);
    });
  });
}
