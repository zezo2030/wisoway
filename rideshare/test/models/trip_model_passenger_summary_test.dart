import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/trip_model.dart';

/// The trip list endpoints (`/trips/nearby`, `/trips/preferred`) attach a
/// passenger summary to every card so the home carousel can show who is
/// already on board.
void main() {
  Map<String, dynamic> listPayload([Map<String, dynamic> extra = const {}]) => {
    'id': 'trip-1',
    'driverId': 'driver-1',
    'fromName': 'العلا',
    'toName': 'تبوك',
    'departureTime': '2026-09-01T16:30:00.000Z',
    'price': 65,
    'totalSeats': 4,
    'availableSeats': 2,
    ...extra,
  };

  group('TripModel passenger summary', () {
    test('parses the booked seats and passenger avatars', () {
      final trip = TripModel.fromJson(
        listPayload({
          'bookedSeats': 2,
          'passengerAvatars': [
            'https://cdn.example.com/a.jpg',
            'https://cdn.example.com/b.jpg',
          ],
        }),
      );

      expect(trip.bookedSeats, 2);
      expect(trip.passengerAvatars, [
        'https://cdn.example.com/a.jpg',
        'https://cdn.example.com/b.jpg',
      ]);
    });

    test('resolves avatar paths served relative to the backend', () {
      final trip = TripModel.fromJson(
        listPayload({
          'passengerAvatars': ['/uploads/general/a.jpg'],
        }),
      );

      expect(trip.passengerAvatars.single, endsWith('/uploads/general/a.jpg'));
      expect(trip.passengerAvatars.single, startsWith('http'));
    });

    test('drops avatar entries that resolve to nothing', () {
      final trip = TripModel.fromJson(
        listPayload({
          'passengerAvatars': ['', '   ', 'https://cdn.example.com/a.jpg'],
        }),
      );

      expect(trip.passengerAvatars, ['https://cdn.example.com/a.jpg']);
    });

    test('falls back to an empty summary when the payload omits it', () {
      final trip = TripModel.fromJson(listPayload());

      expect(trip.bookedSeats, 0);
      expect(trip.passengerAvatars, isEmpty);
    });
  });
}
