import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/booking_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/screens/driver/widgets/boarding_people.dart';

/// The driver's boarding card lists the people booked for, not the accounts
/// that booked them: one booking of three seats is three names.
void main() {
  final now = DateTime.now();

  BookingSeatModel seat(
    String number,
    String name, {
    bool main = false,
    String? declared,
    DateTime? selfConfirmed,
    DateTime? vouched,
  }) => BookingSeatModel(
    id: 'seat-$number',
    bookingId: 'b-1',
    seatNumber: number,
    displayName: name,
    gender: 'male',
    isMainBooker: main,
    passengerDeclaredStatus: declared,
    passengerSelfConfirmedAt: selfConfirmed,
    presenceConfirmedAt: vouched,
    createdAt: now,
  );

  BookingModel booking(List<BookingSeatModel> seats) => BookingModel(
    id: 'b-1',
    tripId: 't-1',
    userId: 'u-1',
    hasDriverPaidToContact: true,
    sharePhoneWithDriver: false,
    status: 'confirmed',
    createdAt: now,
    updatedAt: now,
    seats: seats,
    userPopulated: UserModel(
      id: 'u-1',
      phoneNumber: '0500000000',
      email: 'b@example.com',
      name: 'سنبل',
      gender: 'male',
      role: 'passenger',
      createdAt: now,
      updatedAt: now,
    ),
  );

  test('one booking of three seats is three people, by their own names', () {
    final people = boardingPeople([
      booking([
        seat('0-0', 'سنبل', main: true),
        seat('1-0', 'قصي'),
        seat('1-1', 'محمد'),
      ]),
    ]);

    expect(people.map((p) => p.name('راكب')), ['سنبل', 'قصي', 'محمد']);
    expect(people.map((p) => p.seat?.seatNumber), ['0-0', '1-0', '1-1']);
  });

  test('a seat without a name falls back to the booker', () {
    final people = boardingPeople([
      booking([seat('0-0', '  ', main: true)]),
    ]);
    expect(people.single.name('راكب'), 'سنبل');
  });

  test('each person boards on their own', () {
    final people = boardingPeople([
      booking([
        seat('0-0', 'سنبل', main: true, selfConfirmed: now),
        seat('1-0', 'قصي', vouched: now),
        seat('1-1', 'محمد', declared: 'not_riding'),
        seat('1-2', 'علي'),
      ]),
    ]);

    expect(people.map((p) => p.hasBoarded), [true, true, false, false]);
    expect(people.map((p) => p.isNotRiding), [false, false, true, false]);
  });

  test('a booking without seat rows stays one person', () {
    final people = boardingPeople([booking(const [])]);
    expect(people.single.seat, isNull);
    expect(people.single.name('راكب'), 'سنبل');
    expect(people.single.hasBoarded, isFalse);
  });
}
