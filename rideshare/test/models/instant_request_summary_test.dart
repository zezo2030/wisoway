import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/instant_ride_models.dart';

void main() {
  group('InstantQuote', () {
    test('reads the fixed fare and the route metrics', () {
      final quote = InstantQuote.fromJson({
        'recommendedFare': '4.50',
        'minFare': '4.50',
        'maxFare': '4.50',
        'currency': 'JOD',
        'distanceKm': 12.3,
        'durationMinutes': '18',
      });

      expect(quote.recommendedFare, 4.5);
      expect(quote.minFare, quote.recommendedFare);
      expect(quote.maxFare, quote.recommendedFare);
      expect(quote.distanceKm, 12.3);
      expect(quote.durationMinutes, 18);
    });

    test('leaves the metrics empty when the server omits them', () {
      final quote = InstantQuote.fromJson({
        'recommendedFare': 3,
        'minFare': 3,
        'maxFare': 3,
        'currency': 'JOD',
      });

      expect(quote.distanceKm, isNull);
      expect(quote.durationMinutes, isNull);
    });
  });

  group('InstantRequestSummary for the driver offer card', () {
    test('separates the pickup leg from the trip distance', () {
      final summary = InstantRequestSummary.fromJson({
        'id': 'req-1',
        'fromName': 'دسوق',
        'toName': 'دمنهور',
        'currency': 'JOD',
        'seatCount': 1,
        'distanceKm': '20.1',
        'distanceLabel': '20.1 كم',
        'pickupDistanceKm': '2.4',
        'pickupDistanceLabel': '2.4 كم',
        'pickupEtaMinutes': 6,
        'pickup': {'latitude': 31.13, 'longitude': 30.64},
        'dropoff': {'latitude': 31.03, 'longitude': 30.47},
      });

      expect(summary.pickupDistanceLabel, '2.4 كم');
      expect(summary.distanceLabel, '20.1 كم');
      expect(summary.pickupEtaMinutes, 6);
      expect(summary.dropoffLat, 31.03);
      expect(summary.dropoffLng, 30.47);
    });

    test('drops blank optional fields instead of rendering empty rows', () {
      final summary = InstantRequestSummary.fromJson({
        'id': 'req-1',
        'fromName': 'دسوق',
        'toName': 'دمنهور',
        'currency': 'JOD',
        'seatCount': 1,
        'fromAddress': '',
        'pickupDistanceLabel': '',
        'passengerName': '  ',
      });

      expect(summary.fromAddress, isNull);
      expect(summary.pickupDistanceLabel, isNull);
      expect(summary.passengerName, isNull);
    });
  });
}
