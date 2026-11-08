import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/constants/route_names.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/booking_model.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/seat_layout_config.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/screens/home/widgets/booking_card.dart';

/// The card's «دردشة» and «اتصال» used to do nothing on the home screen: the
/// tap fell through to the card and opened the trip's details instead.
void main() {
  final now = DateTime.now();
  final trip = TripModel(
    id: 't-1',
    driverId: 'd-1',
    from: LocationModel(name: 'A', latitude: 0, longitude: 0),
    to: LocationModel(name: 'B', latitude: 0, longitude: 0),
    departureTime: now.add(const Duration(hours: 1)),
    price: 25,
    currency: 'SAR',
    totalSeats: 4,
    availableSeats: 2,
    seatLayout: SeatLayoutConfig(rows: 2, seatsPerRow: 2),
    seats: const [],
    createdAt: now,
    updatedAt: now,
  );
  final booking = BookingModel(
    id: 'b-1',
    tripId: 't-1',
    userId: 'u-1',
    hasDriverPaidToContact: true,
    sharePhoneWithDriver: false,
    status: 'pending',
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('«دردشة» opens the chat with the driver, not the details', (
    tester,
  ) async {
    var detailsOpened = 0;
    String? pushed;
    Object? args;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          pushed = settings.name;
          args = settings.arguments;
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingCard(
              booking: booking,
              trip: trip,
              onTap: () => detailsOpened++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('دردشة'));
    await tester.pumpAndSettle();

    expect(detailsOpened, 0);
    expect(pushed, RouteNames.chat);
    expect((args as Map)['driverId'], 'd-1');
  });
}
