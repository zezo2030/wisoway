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
}
