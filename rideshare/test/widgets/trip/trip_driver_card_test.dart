import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/widgets/trip/trip_driver_card.dart';

TripModel _trip({
  String? driverName = 'mohammad alsharif',
  double? rating = 4.9,
  String? color = 'white',
}) {
  return TripModel.fromJson({
    'id': 't-1',
    'driverId': 'd-1',
    'driverName': driverName,
    'driverRating': rating,
    'vehicleModel': 'Toyota Corolla',
    'vehiclePlateNumber': 'ABC4456',
    'vehicleColor': color,
    'from': {'address': 'A', 'lat': 0, 'lng': 0},
    'to': {'address': 'B', 'lat': 0, 'lng': 0},
    'departureTime': '2026-11-04T10:00:00.000Z',
    'totalSeats': 4,
    'availableSeats': 3,
    'pricePerSeat': 10,
    'status': 'in_progress',
  });
}

Widget _host(Widget card, {double width = 336}) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: card),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the driver, the car and its translated colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TripDriverCard(
          trip: _trip(),
          onDetails: () {},
          onChat: () {},
          onCall: () {},
        ),
      ),
    );

    expect(find.text('mohammad alsharif'), findsOneWidget);
    expect(find.text('Toyota Corolla'), findsOneWidget);
    expect(find.text('ABC4456'), findsOneWidget);
    expect(find.text('أبيض'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('سائقك الآن'), findsOneWidget);
  });

  testWidgets('leaves out a rating and colour the driver does not have', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TripDriverCard(
          trip: _trip(rating: 0, color: null),
          onDetails: () {},
          onChat: () {},
          onCall: () {},
        ),
      ),
    );

    expect(find.text('0.0'), findsNothing);
    expect(find.text('أبيض'), findsNothing);
  });

  testWidgets('each action reaches its handler', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      _host(
        TripDriverCard(
          trip: _trip(),
          onDetails: () => tapped.add('details'),
          onChat: () => tapped.add('chat'),
          onCall: () => tapped.add('call'),
        ),
      ),
    );

    await tester.tap(find.text('التفاصيل'));
    await tester.tap(find.byIcon(Icons.chat_rounded));
    await tester.tap(find.byIcon(Icons.call_rounded));

    expect(tapped, ['details', 'chat', 'call']);
  });

  testWidgets('blocks a second call while one is starting', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        TripDriverCard(
          trip: _trip(),
          onDetails: () {},
          onChat: () {},
          onCall: () => calls++,
          callBusy: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(CircularProgressIndicator));
    expect(calls, 0);
  });

  testWidgets('fits a narrow phone with a long name', (tester) async {
    await tester.pumpWidget(
      _host(
        TripDriverCard(
          trip: _trip(driverName: 'عبد الرحمن بن عبد العزيز الشريف'),
          onDetails: () {},
          onChat: () {},
          onCall: () {},
        ),
        width: 296,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
