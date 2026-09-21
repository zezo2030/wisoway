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

/// The pre-departure header used to announce «تم حجز جميع المقاعد بنجاح» no
/// matter what, so a driver opening the trip they had just published was told
/// every seat was taken while the roster underneath read «الركاب المحجوزون
/// (0)». It now has to track the seats actually confirmed.
void main() {
  TripModel trip({required int totalSeats, required int availableSeats}) {
    final now = DateTime.now();
    return TripModel(
      id: 't-1',
      driverId: 'd-1',
      driverName: 'سائق',
      from: LocationModel(name: 'عمان', latitude: 31.9, longitude: 35.9),
      to: LocationModel(name: 'الطفيلة', latitude: 30.8, longitude: 35.6),
      departureTime: now.add(const Duration(days: 2)),
      price: 20,
      currency: 'JOD',
      totalSeats: totalSeats,
      availableSeats: availableSeats,
      status: availableSeats == 0 ? 'fully_booked' : 'active',
      seatLayout: SeatLayoutConfig(rows: 2, seatsPerRow: 2),
      seats: const <SeatData>[],
      createdAt: now,
      updatedAt: now,
      distanceKm: 181,
    );
  }

  List<BookingModel> confirmed(int count) {
    final now = DateTime.now();
    return List.generate(
      count,
      (i) => BookingModel(
        id: 'b-$i',
        tripId: 't-1',
        userId: 'u-$i',
        seatNumber: '${i + 1}',
        status: 'confirmed',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required TripModel value,
    required List<BookingModel> bookings,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1800);
    addTearDown(tester.view.reset);

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
            previewBookings: bookings,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('pre-departure header', () {
    testWidgets('a freshly published trip says it is waiting for bookings', (
      tester,
    ) async {
      await pump(
        tester,
        value: trip(totalSeats: 4, availableSeats: 4),
        bookings: const <BookingModel>[],
      );

      expect(find.text('رحلتك منشورة'), findsOneWidget);
      expect(find.text('في انتظار حجز الركاب'), findsOneWidget);
      // The claim that started this: never shown with an empty roster.
      expect(find.text('تم حجز جميع المقاعد بنجاح'), findsNothing);
      // No tick either — nothing has happened yet.
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('a partly booked trip counts the seats taken', (tester) async {
      await pump(
        tester,
        value: trip(totalSeats: 4, availableSeats: 2),
        bookings: confirmed(2),
      );

      expect(find.text('تم حجز مقاعد في رحلتك'), findsOneWidget);
      expect(find.text('2 من 4 مقاعد محجوزة'), findsOneWidget);
      expect(find.text('تم حجز جميع المقاعد بنجاح'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('a full trip keeps the original congratulation', (
      tester,
    ) async {
      await pump(
        tester,
        value: trip(totalSeats: 4, availableSeats: 0),
        bookings: confirmed(4),
      );

      expect(find.text('تم حجز رحلتك المشتركة'), findsOneWidget);
      expect(find.text('تم حجز جميع المقاعد بنجاح'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('pending requests alone do not count as booked seats', (
      tester,
    ) async {
      final now = DateTime.now();
      // availableSeats drops the moment a booking is created, while it is
      // still pending, so the header must read the roster, not the counter.
      await pump(
        tester,
        value: trip(totalSeats: 4, availableSeats: 0),
        bookings: [
          for (var i = 0; i < 4; i++)
            BookingModel(
              id: 'p-$i',
              tripId: 't-1',
              userId: 'u-$i',
              seatNumber: '${i + 1}',
              status: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
        ],
      );

      expect(find.text('رحلتك منشورة'), findsOneWidget);
      expect(find.text('تم حجز جميع المقاعد بنجاح'), findsNothing);
    });
  });
}
