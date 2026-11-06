import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/passenger_trip_location_reporter.dart';

void main() {
  test('stops only when the server says so', () {
    bool keep(Object? response) =>
        PassengerTripLocationReporter.shouldKeepSending(response);

    expect(
      keep({
        'success': true,
        'data': {'tracking': true, 'verified': false},
      }),
      isTrue,
    );
    expect(
      keep({
        'success': true,
        'data': {'tracking': false, 'verified': true},
      }),
      isFalse,
    );
    expect(keep(null), isTrue);
  });

  test('a declined trip is not asked about again', () {
    final reporter = PassengerTripLocationReporter.instance;

    expect(reporter.isHandled('trip-declined'), isFalse);
    reporter.skip('trip-declined');
    expect(reporter.isHandled('trip-declined'), isTrue);
  });
}
