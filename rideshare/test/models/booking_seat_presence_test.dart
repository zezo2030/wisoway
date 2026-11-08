import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/booking_model.dart';

BookingSeatModel seat(Map<String, dynamic> extra) => BookingSeatModel.fromJson({
  'id': 's1',
  'bookingId': 'b1',
  'seatNumber': '0-0',
  'displayName': 'Sara',
  'gender': 'female',
  'isMainBooker': true,
  'createdAt': '2026-11-08T10:00:00Z',
  ...extra,
});

void main() {
  group('BookingSeatModel.isPresenceConfirmed (the fare is due)', () {
    test('the passenger confirmed', () {
      expect(
        seat({'passengerSelfConfirmedAt': '2026-11-08T10:05:00Z'})
            .isPresenceConfirmed,
        isTrue,
      );
    });

    test('only the driver vouched «معي في السيارة»', () {
      expect(
        seat({'presenceConfirmedAt': '2026-11-08T10:05:00Z'})
            .isPresenceConfirmed,
        isTrue,
      );
    });

    test('nobody confirmed', () {
      expect(seat({}).isPresenceConfirmed, isFalse);
    });

    test('struck off (absent, or exempted by an admin)', () {
      expect(
        seat({
          'presenceConfirmedAt': '2026-11-08T10:05:00Z',
          'billableOverride': false,
        }).isPresenceConfirmed,
        isFalse,
      );
    });
  });
}
