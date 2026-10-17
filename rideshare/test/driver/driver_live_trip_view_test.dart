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
  TripModel trip({
    String type = 'instant',
    bool arrived = false,
    bool started = false,
  }) => TripModel(
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
    // Shared trips are under way from the start; instant rides move on
    // only when the driver presses «وصلت» / «بدء الرحلة».
    driverArrivedAt: arrived || started ? DateTime.now() : null,
    tripStartedAt: type != 'instant' || started ? DateTime.now() : null,
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
    VoidCallback? onStartRide,
    void Function(LatLng target)? onNavigate,
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
            onArrivedAtPickup: () {},
            onStartRide: onStartRide ?? () {},
            onEnableTracking: () {},
            onChatPassenger: (_) {},
            phoneOf: (_) => null,
            onCall: (_) {},
            onNavigate: onNavigate ?? (_) {},
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
    expect(find.text('وصلت إلى الراكب'), findsOneWidget);
    expect(find.text('تم الوصول للوجهة'), findsNothing);
    // Locked: no way back.
    expect(find.byType(BackButtonIcon), findsNothing);
  });

  testWidgets('instant ride: asks for GPS while tracking is off', (
    tester,
  ) async {
    await pump(tester, trip: trip());

    expect(find.text('فعّل الموقع حتى يرى الراكب مكانك'), findsOneWidget);
  });

  testWidgets('instant ride: being at the pickup does not board the passenger', (
    tester,
  ) async {
    await pump(tester, trip: trip(), driver: const LatLng(26.6001, 37.9001));

    expect(find.text('الراكب معك — في الطريق إلى الوجهة'), findsNothing);
    expect(find.text('وصلت إلى الراكب'), findsOneWidget);
  });

  testWidgets('instant ride: after «وصلت» the driver starts the ride', (
    tester,
  ) async {
    await pump(
      tester,
      trip: trip(arrived: true),
      driver: const LatLng(26.6001, 37.9001),
    );

    expect(find.text('بانتظار ركوب الراكب'), findsOneWidget);
    expect(find.text('بدء الرحلة'), findsOneWidget);
    expect(find.text('تم الوصول للوجهة'), findsNothing);
  });

  testWidgets('instant ride: once started, the passenger is on board', (
    tester,
  ) async {
    await pump(tester, trip: trip(started: true));

    expect(find.text('الراكب معك — في الطريق إلى الوجهة'), findsOneWidget);
    expect(find.text('تم الوصول للوجهة'), findsOneWidget);
  });

  for (final (stage, arrived, started, expected) in [
    ('on the way', false, false, const LatLng(26.6, 37.9)),
    ('waiting at the pickup', true, false, const LatLng(26.6, 37.9)),
    ('ride started', false, true, const LatLng(26.5, 37.95)),
  ]) {
    testWidgets('instant ride: «ملاحة» while $stage goes to $expected', (
      tester,
    ) async {
      LatLng? navigatedTo;
      await pump(
        tester,
        trip: trip(arrived: arrived, started: started),
        // Close to the pickup, so no «start the ride?» prompt pops up.
        driver: const LatLng(26.6001, 37.9001),
        onNavigate: (target) => navigatedTo = target,
      );

      await tester.tap(find.text('ملاحة'));
      await tester.pump();

      // The pickup until the passenger is in, then the destination.
      expect(navigatedTo, expected);
    });
  }

  testWidgets('instant ride: driving off without starting asks to start', (
    tester,
  ) async {
    var started = 0;
    final arrivedTrip = trip(arrived: true);
    await pump(
      tester,
      trip: arrivedTrip,
      driver: const LatLng(26.6001, 37.9001),
      onStartRide: () => started++,
    );
    expect(find.text('هل بدأت الرحلة؟'), findsNothing);

    // ~1 km down the road, still not started.
    await pump(
      tester,
      trip: arrivedTrip,
      driver: const LatLng(26.59, 37.9),
      onStartRide: () => started++,
    );
    await tester.pumpAndSettle();
    expect(find.text('هل بدأت الرحلة؟'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'بدء الرحلة').last);
    await tester.pumpAndSettle();
    expect(started, 1);
  });

  testWidgets('instant ride: no prompt before the driver reached the pickup', (
    tester,
  ) async {
    await pump(tester, trip: trip(), driver: const LatLng(26.7, 37.9));
    await pump(tester, trip: trip(), driver: const LatLng(26.65, 37.9));
    await tester.pumpAndSettle();

    expect(find.text('هل بدأت الرحلة؟'), findsNothing);
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
    expect(find.text('وصلت إلى الراكب'), findsOneWidget);
  });
}
