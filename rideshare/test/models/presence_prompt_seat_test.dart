import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/presence_models.dart';

PresencePromptSeat _seat(PassengerPresenceStatus? status) => PresencePromptSeat(
  seatNumber: '1A',
  displayName: 'أحمد',
  isMainBooker: true,
  declaredStatus: status,
);

void main() {
  test('an unanswered seat has every answer open', () {
    expect(_seat(null).openAnswers, PassengerPresenceStatus.values);
    expect(_seat(null).isSettled, isFalse);
  });

  test('someone on the way can only get in the car', () {
    expect(_seat(PassengerPresenceStatus.onMyWay).openAnswers, [
      PassengerPresenceStatus.inVehicle,
    ]);
  });

  test('in the car and not riding are final', () {
    expect(_seat(PassengerPresenceStatus.inVehicle).isSettled, isTrue);
    expect(_seat(PassengerPresenceStatus.notRiding).isSettled, isTrue);
  });

  group('the driver vouching for a seat', () {
    PresencePromptSeat parse(Map<String, dynamic> extra) =>
        PresencePromptSeat.fromJson({
          'seatNumber': '1-0',
          'displayName': 'قصي',
          'isMainBooker': false,
          ...extra,
        });

    test('reads the driver\'s «معي في السيارة» from the prompt', () {
      final seat = parse({'driverConfirmedAt': '2026-11-08T10:00:00Z'});
      expect(seat.driverConfirmedAt, DateTime.utc(2026, 11, 8, 10));
      expect(seat.vouchedByDriverOnly, isTrue);
    });

    test('is not the driver\'s word alone once the passenger confirmed', () {
      expect(
        parse({
          'driverConfirmedAt': '2026-11-08T10:00:00Z',
          'declaredStatus': 'in_vehicle',
          'selfConfirmedAt': '2026-11-08T09:59:00Z',
        }).vouchedByDriverOnly,
        isFalse,
      );
    });

    test('a seat nobody vouched for is not', () {
      expect(parse({}).vouchedByDriverOnly, isFalse);
    });

    test('the booking is vouched for when any of its seats is', () {
      final prompt = PresencePrompt.fromJson({
        'bookingId': 'b-1',
        'tripId': 't-1',
        'seats': [
          {'seatNumber': '0-0', 'displayName': 'سنبل', 'isMainBooker': true},
          {
            'seatNumber': '1-0',
            'displayName': 'قصي',
            'isMainBooker': false,
            'driverConfirmedAt': '2026-11-08T10:00:00Z',
          },
        ],
      });
      expect(prompt.vouchedByDriverOnly, isTrue);
    });
  });
}
