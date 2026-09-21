import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/screens/home/widgets/passenger_avatar_stack.dart';
import 'package:rideshare/screens/home/widgets/suggested_trip_card.dart';

TripModel _trip({
  DateTime? departureTime,
  int availableSeats = 2,
  num price = 65,
  List<String> passengerAvatars = const [],
  int bookedSeats = 0,
}) => TripModel.fromJson({
  'id': 'trip-1',
  'driverId': 'driver-1',
  'fromName': 'العلا',
  'toName': 'تبوك',
  'departureTime': (departureTime ?? DateTime.now().add(const Duration(hours: 3)))
      .toIso8601String(),
  'price': price,
  'currency': 'SAR',
  'totalSeats': 4,
  'availableSeats': availableSeats,
  'bookedSeats': bookedSeats,
  'passengerAvatars': passengerAvatars,
});

Widget _host(TripModel trip, {VoidCallback? onTap}) => MaterialApp(
  locale: const Locale('ar'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SuggestedTripCard(trip: trip, onTap: onTap ?? () {})),
);

void main() {
  group('SuggestedTripCard', () {
    testWidgets('names both ends of the route', (tester) async {
      await tester.pumpWidget(_host(_trip()));

      expect(find.text('العلا'), findsOneWidget);
      expect(find.text('تبوك'), findsOneWidget);
    });

    testWidgets('spells out how many seats are still free', (tester) async {
      await tester.pumpWidget(_host(_trip(availableSeats: 4)));

      expect(find.text('4 مقاعد متاحة'), findsOneWidget);
    });

    testWidgets('prints a whole fare without a trailing decimal', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_trip(price: 65)));

      expect(find.text('65 SAR'), findsOneWidget);
    });

    testWidgets('marks a departure on the current day as today', (
      tester,
    ) async {
      final now = DateTime.now();

      await tester.pumpWidget(
        _host(
          _trip(departureTime: DateTime(now.year, now.month, now.day, 16, 30)),
        ),
      );

      expect(find.textContaining('اليوم'), findsOneWidget);
    });

    testWidgets('dates a departure that is not today', (tester) async {
      await tester.pumpWidget(
        _host(_trip(departureTime: DateTime.now().add(const Duration(days: 3)))),
      );

      expect(find.textContaining('اليوم'), findsNothing);
    });

    testWidgets('carries the passengers already on board', (tester) async {
      await tester.pumpWidget(
        _host(_trip(bookedSeats: 3, passengerAvatars: const ['a.jpg'])),
      );

      final stack = tester.widget<PassengerAvatarStack>(
        find.byType(PassengerAvatarStack),
      );

      expect(stack.avatars, const ['a.jpg']);
      expect(stack.totalPassengers, 3);
    });

    testWidgets('opens the trip when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(_trip(), onTap: () => taps++));

      await tester.tap(find.byType(SuggestedTripCard));

      expect(taps, 1);
    });
  });
}
