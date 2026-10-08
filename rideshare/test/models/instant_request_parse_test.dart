import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/instant_ride_models.dart';

void main() {
  // The accepted-request body as the backend sent it: `users.rating` is a
  // Postgres decimal, so TypeORM serialises it as a string. A strict `as num`
  // cast threw here, the passenger's poll swallowed the error, and the screen
  // sat on 'searching' after the driver had already accepted.
  Map<String, dynamic> acceptedBody() => {
    'id': 'r-1',
    'status': 'accepted',
    'from': {'name': 'ساق، العلا'},
    'to': {'name': 'العلا'},
    'seatCount': 1,
    'currency': 'JOD',
    'tripId': 't-1',
    'match': {
      'tripId': 't-1',
      'bookingId': 'b-1',
      'acceptedFare': '7.39',
      'currency': 'JOD',
      'pickupEtaSeconds': 240,
      'driverId': 'd-1',
      'driverName': 'mohammad banat',
      'driverRating': '0.00',
      'driverTotalRatings': 0,
    },
  };

  test('an accepted request with a string rating parses as matched', () {
    final request = InstantRequest.fromJson(acceptedBody());

    expect(request.isMatched, isTrue);
    expect(request.isSearching, isFalse);
    expect(request.match?.tripId, 't-1');
    expect(request.match?.driverRating, 0);
  });

  test('numbers sent as strings are accepted across the match', () {
    final body = acceptedBody();
    (body['match'] as Map)['pickupEtaSeconds'] = '240';
    (body['match'] as Map)['driverTotalRatings'] = '12';

    final match = InstantRequest.fromJson(body).match!;

    expect(match.pickupEtaSeconds, 240);
    expect(match.driverTotalRatings, 12);
  });

  test('the active-ride endpoint maps role and trip', () {
    final driver = ActiveInstantRide.fromJson({
      'tripId': 't-1',
      'role': 'driver',
      'requestId': 'r-1',
    });
    expect(driver?.isDriver, isTrue);
    expect(driver?.tripId, 't-1');

    final passenger = ActiveInstantRide.fromJson({
      'tripId': 't-2',
      'role': 'passenger',
    });
    expect(passenger?.isDriver, isFalse);

    expect(ActiveInstantRide.fromJson(const {}), isNull);
  });
}
