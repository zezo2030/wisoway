import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/booking_model.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/seat_data.dart';
import 'package:rideshare/models/seat_layout_config.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/providers/trip_provider.dart';
import 'package:rideshare/screens/driver/trip_management_screen.dart';

/// A request for two seats — the booker and a companion — must read as seat
/// numbers from the seat map with the companion marked, not as raw `row-col`
/// ids ("0-0, 0-1") that hide who is travelling.
void main() {
  final now = DateTime.now();

  final trip = TripModel(
    id: 't-1',
    driverId: 'd-1',
    from: LocationModel(name: 'حي ساق، العلا', latitude: 26.6, longitude: 37.9),
    to: LocationModel(name: 'Tabuk', latitude: 28.4, longitude: 36.6),
    departureTime: now.add(const Duration(days: 1)),
    price: 5,
    currency: 'JOD',
    totalSeats: 3,
    availableSeats: 1,
    status: 'published',
    seatLayout: SeatLayoutConfig(
      rows: 2,
      seatsPerRow: 3,
      seatsPerRowList: const [1, 3],
    ),
    seats: const <SeatData>[],
    createdAt: now,
    updatedAt: now,
  );

  BookingSeatModel seat(String number, String name, bool main) =>
      BookingSeatModel(
        id: 's-$number',
        bookingId: 'b-1',
        seatNumber: number,
        displayName: name,
        gender: 'female',
        isMainBooker: main,
        createdAt: now,
      );

  final pending = BookingModel(
    id: 'b-1',
    tripId: 't-1',
    userId: 'u-1',
    status: 'pending',
    seatCount: 2,
    seats: [seat('0-0', 'ayat', true), seat('1-0', 'محمد', false)],
    userPopulated: UserModel(
      id: 'u-1',
      phoneNumber: '0790000000',
      email: '',
      name: 'ayat',
      gender: 'female',
      role: 'passenger',
      createdAt: now,
      updatedAt: now,
    ),
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('a pending two-seat request shows seat numbers and the companion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
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
            previewTrip: trip,
            previewBookings: [pending],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('0-0'), findsNothing);
    expect(find.text('مقعد 1 · ayat'), findsOneWidget);
    expect(find.text('مقعد 2 · محمد'), findsOneWidget);
    expect(find.text('مرافق'), findsOneWidget);
  });
}
