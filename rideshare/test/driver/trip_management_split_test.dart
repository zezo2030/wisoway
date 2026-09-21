import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/booking_model.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/seat_data.dart';
import 'package:rideshare/models/seat_layout_config.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/providers/trip_provider.dart';
import 'package:rideshare/screens/driver/trip_management_screen.dart';
import 'package:rideshare/screens/driver/widgets/trip_fare_breakdown_card.dart';
import 'package:rideshare/screens/driver/widgets/trip_route_card.dart';

/// The whole task rests on one invariant: `tripStartedAt == null` renders the
/// design's pre-departure composition, and anything else keeps the original
/// live-tracking / «وصلت» body. Both directions are asserted here because the
/// invariant otherwise lives only in a pair of ternaries.
void main() {
  TripModel trip({DateTime? startedAt}) => TripModel(
    id: 't-1',
    driverId: 'd-1',
    driverName: 'سائق',
    from: LocationModel(name: 'عمان', latitude: 31.9, longitude: 35.9),
    to: LocationModel(name: 'الطفيلة', latitude: 30.8, longitude: 35.6),
    departureTime: DateTime.now().add(const Duration(days: 2)),
    price: 4,
    currency: 'JOD',
    totalSeats: 4,
    availableSeats: 0,
    status: 'fully_booked',
    seatLayout: SeatLayoutConfig(rows: 2, seatsPerRow: 2),
    seats: const <SeatData>[],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    tripStartedAt: startedAt,
    distanceKm: 181,
  );

  Future<void> pump(WidgetTester tester, TripModel value) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<TripProvider>(create: (_) => TripProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripManagementScreen(
            tripId: 't-1',
            previewTrip: value,
            previewBookings: const <BookingModel>[],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('before departure the screen renders the design composition', (
    tester,
  ) async {
    await pump(tester, trip());

    expect(find.byType(TripRouteCard), findsOneWidget);
    expect(find.byType(TripFareBreakdownCard), findsOneWidget);
    expect(find.byType(TripFeeNotice), findsOneWidget);
    // The fixture carries no bookings, so the header is the waiting one. It
    // used to assert the fully-booked wording here, which is what let the
    // header congratulate a driver on an empty car — see
    // trip_management_header_test.dart for the state-by-state cases.
    expect(find.text('رحلتك منشورة'), findsOneWidget);
  });

  testWidgets('after departure the original body returns', (tester) async {
    await pump(tester, trip(startedAt: DateTime.now()));

    // The design's pre-departure sections are gone…
    expect(find.byType(TripRouteCard), findsNothing);
    expect(find.byType(TripFareBreakdownCard), findsNothing);
    expect(find.byType(TripFeeNotice), findsNothing);
    expect(find.text('رحلتك منشورة'), findsNothing);

    // …and the original composition is back, AppBar and all.
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('إدارة الرحلة'), findsOneWidget);
  });
}
