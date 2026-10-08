import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rideshare/core/services/route_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/booking_model.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/seat_data.dart';
import 'package:rideshare/models/seat_layout_config.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/screens/driver/widgets/driver_live_trip_view.dart';

void main() {
  TripModel trip({String type = 'instant'}) => TripModel(
    id: 't-1',
    driverId: 'd-1',
    from: LocationModel(name: 'ساق، العلا', latitude: 26.6, longitude: 37.9),
    to: LocationModel(name: 'العلا', latitude: 26.5, longitude: 37.95),
    departureTime: DateTime.now(),
    price: 7.39,
    currency: 'JOD',
    totalSeats: type == 'instant' ? 1 : 4,
    availableSeats: 0,
    status: 'in_progress',
    tripType: type,
    tripStartedAt: DateTime.now(),
    seatLayout: SeatLayoutConfig(rows: 1, seatsPerRow: 1),
    seats: const <SeatData>[],
    distanceKm: 10.8,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  BookingModel booking(
    String id,
    String name,
    String amount, {
    int seats = 1,
  }) => BookingModel(
    id: id,
    tripId: 't-1',
    userId: 'u-$id',
    seatCount: seats,
    totalAmount: amount,
    status: 'confirmed',
    userPopulated: UserModel(
      id: 'u-$id',
      name: name,
      email: '',
      phoneNumber: '0790000000',
      role: 'passenger',
      gender: 'male',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Future<void> pump(
    WidgetTester tester, {
    required TripModel trip,
    List<BookingModel> bookings = const [],
    LatLng? driver,
    VoidCallback? onBack,
  }) async {
    // A phone-shaped screen: everything must fit without scrolling.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DriverLiveTripView(
            trip: trip,
            bookings: bookings,
            driverPosition: driver,
            trackingActive: driver != null,
            markingArrived: false,
            onArrived: () {},
            onEnableTracking: () {},
            onChatPassenger: (_) {},
            phoneOf: (_) => null,
            onCall: (_) {},
            onNavigate: (_) {},
            onBack: onBack,
            onGroupChat: trip.isInstant ? null : () {},
            routeService: RouteService(
              routeFetcher: ({required origin, required destination}) async =>
                  <String, dynamic>{},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  test('tripType instant is parsed from the API', () {
    final json = trip().toJson();
    expect(TripModel.fromJson(json).isInstant, isTrue);
    json.remove('tripType');
    expect(TripModel.fromJson(json).isInstant, isFalse);
  });

  testWidgets('instant ride: one page with map, passenger, fare and actions', (
    tester,
  ) async {
    await pump(
      tester,
      trip: trip(),
      bookings: [booking('b1', 'ayat', '7.39')],
      driver: const LatLng(26.7, 37.9),
    );

    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('في الطريق إلى الراكب'), findsOneWidget);
    expect(find.text('ayat'), findsOneWidget);
    expect(find.text('7.39 JOD'), findsOneWidget);
    expect(find.text('ملاحة'), findsOneWidget);
    expect(find.text('تم الوصول للوجهة'), findsOneWidget);
    // Locked: no way back.
    expect(find.byType(BackButtonIcon), findsNothing);
  });

  testWidgets('instant ride: asks for GPS while tracking is off', (
    tester,
  ) async {
    await pump(tester, trip: trip());

    expect(find.text('فعّل الموقع حتى يرى الراكب مكانك'), findsOneWidget);
  });

  testWidgets('instant ride: passenger on board once the driver is there', (
    tester,
  ) async {
    await pump(tester, trip: trip(), driver: const LatLng(26.6001, 37.9001));

    expect(find.text('الراكب معك — في الطريق إلى الوجهة'), findsOneWidget);
  });

  testWidgets('shared trip: passengers on board, revenue totals the bookings', (
    tester,
  ) async {
    await pump(
      tester,
      trip: trip(type: 'scheduled'),
      bookings: [
        booking('b1', 'ayat', '10.00', seats: 2),
        booking('b2', 'sara', '5.00'),
      ],
      driver: const LatLng(26.58, 37.91),
      onBack: () {},
    );

    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('في الطريق إلى الوجهة'), findsOneWidget);
    expect(find.text('الركاب: 3'), findsOneWidget);
    expect(find.text('15.00 JOD'), findsOneWidget);
    expect(find.text('الإيرادات'), findsOneWidget);
    expect(find.byType(BackButtonIcon), findsOneWidget);

    await tester.tap(find.text('الركاب: 3'));
    await tester.pumpAndSettle();
    expect(find.text('ركاب الرحلة'), findsOneWidget);
    expect(find.text('sara'), findsOneWidget);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    await pump(tester, trip: trip(), bookings: [booking('b1', 'ayat', '7.39')]);
    // Re-pump at 360x640 with the GPS warning showing — the tallest panel.
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('تم الوصول للوجهة'), findsOneWidget);
  });
}
