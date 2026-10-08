import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/booking_model.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/seat_layout_config.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/screens/driver/widgets/trip_passenger_seat_row.dart';

/// The design locks the roster to one row per *seat*, not per booking: a
/// passenger who books two seats brings a companion, and both must appear.
void main() {
  final now = DateTime.now();

  UserModel booker({String name = 'أحمد محمود', double rating = 4.5}) =>
      UserModel(
        id: 'u-1',
        phoneNumber: '0790000000',
        email: 'ahmad@example.com',
        name: name,
        gender: 'male',
        role: 'passenger',
        rating: rating,
        createdAt: now,
        updatedAt: now,
      );

  BookingSeatModel seat(String number, String displayName) => BookingSeatModel(
    id: 'seat-$number',
    bookingId: 'b-1',
    seatNumber: number,
    displayName: displayName,
    gender: 'male',
    isMainBooker: number == 'A1',
    createdAt: now,
  );

  BookingModel bookingWith(List<BookingSeatModel> seats) => BookingModel(
    id: 'b-1',
    tripId: 't-1',
    userId: 'u-1',
    hasDriverPaidToContact: false,
    sharePhoneWithDriver: true,
    seatNumber: seats.isEmpty ? 'A1' : seats.first.seatNumber,
    status: 'confirmed',
    createdAt: now,
    updatedAt: now,
    seats: seats,
    userPopulated: booker(),
  );

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  test('a booking of two seats expands to two entries', () {
    final entries = passengerSeatEntries([
      bookingWith([seat('A1', 'أحمد محمود'), seat('A2', 'سارة أحمد')]),
    ], fallbackName: 'راكب');

    expect(entries, hasLength(2));
    expect(entries.map((e) => e.seatNumber), ['A1', 'A2']);
    expect(entries.map((e) => e.displayName), ['أحمد محمود', 'سارة أحمد']);
    // Both seats stay attached to the booker for contact purposes.
    expect(entries.every((e) => e.userId == 'u-1'), isTrue);
    expect(entries.every((e) => e.phoneNumber == '0790000000'), isTrue);
  });

  test('with the trip, seat ids read as the seat-map numbers', () {
    // 1 front + 3 back: "0-0" is seat 1, "1-0" is seat 2.
    final trip = TripModel(
      id: 't-1',
      driverId: 'd-1',
      from: LocationModel(name: 'A', latitude: 0, longitude: 0),
      to: LocationModel(name: 'B', latitude: 0, longitude: 0),
      departureTime: now,
      price: 5,
      currency: 'JOD',
      totalSeats: 4,
      availableSeats: 2,
      seatLayout: SeatLayoutConfig(
        rows: 2,
        seatsPerRow: 3,
        seatsPerRowList: const [1, 3],
      ),
      seats: const [],
      createdAt: now,
      updatedAt: now,
    );

    final entries = passengerSeatEntries(
      [
        bookingWith([seat('0-0', 'ayat'), seat('1-0', 'محمد')]),
      ],
      fallbackName: 'راكب',
      trip: trip,
    );

    expect(entries.map((e) => e.seatNumber), ['1', '2']);
  });

  test('a seat with no display name falls back to the booker', () {
    final entries = passengerSeatEntries([
      bookingWith([seat('A1', 'أحمد محمود'), seat('A2', '  ')]),
    ], fallbackName: 'راكب');

    expect(entries[1].displayName, 'أحمد محمود');
  });

  test('a booking with no seats list still yields one entry', () {
    final entries = passengerSeatEntries([
      bookingWith(const []),
    ], fallbackName: 'راكب');

    expect(entries, hasLength(1));
    expect(entries.single.seatNumber, 'A1');
  });

  testWidgets('a two-seat booking renders two roster rows', (tester) async {
    final entries = passengerSeatEntries([
      bookingWith([seat('A1', 'أحمد محمود'), seat('A2', 'سارة أحمد')]),
    ], fallbackName: 'راكب');

    await tester.pumpWidget(
      wrap(
        Column(
          children: entries
              .map(
                (e) => TripPassengerSeatRow(
                  displayName: e.displayName,
                  seatNumber: e.seatNumber,
                  rating: e.rating,
                  photoUrl: e.photoUrl,
                  onChat: () {},
                  onCall: () {},
                ),
              )
              .toList(),
        ),
      ),
    );

    expect(find.byType(TripPassengerSeatRow), findsNWidgets(2));
    expect(find.text('أحمد محمود'), findsOneWidget);
    expect(find.text('سارة أحمد'), findsOneWidget);
    expect(find.text('مقعد A1'), findsOneWidget);
    expect(find.text('مقعد A2'), findsOneWidget);
    // Contact is ungated: every seat gets both actions unconditionally.
    expect(find.byTooltip('دردشة'), findsNWidgets(2));
    expect(find.byTooltip('اتصال'), findsNWidgets(2));
  });
}
