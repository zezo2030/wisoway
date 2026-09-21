import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/instant_ride_models.dart';

void main() {
  group('InstantCounterOffer from an FCM payload', () {
    // What the backend actually puts on the wire: FCM data values are always
    // strings, and absent fields arrive as empty ones rather than missing keys.
    Map<String, dynamic> push({String proposed = '18.00'}) => {
      'id': 'offer-1',
      'requestId': 'req-1',
      'offerId': 'offer-1',
      'proposedFare': proposed,
      'passengerFare': '12.00',
      'currency': 'JOD',
      'driverName': 'سامي',
      'driverRating': '4.8',
      'driverTotalRatings': '132',
      'driverPhotoUrl': '',
      'vehicleModel': 'Hyundai Accent',
      'plateNumber': '',
      'fromName': 'دسوق',
      'toName': 'دمنهور',
      'expiresAt': DateTime.now()
          .add(const Duration(seconds: 30))
          .toIso8601String(),
    };

    test('parses ratings that arrive as strings', () {
      final offer = InstantCounterOffer.fromJson(push());

      expect(offer.driverRating, 4.8);
      expect(offer.driverTotalRatings, 132);
      expect(offer.driverName, 'سامي');
      expect(offer.vehicleModel, 'Hyundai Accent');
    });

    test('treats empty strings as absent so the card omits the row', () {
      final offer = InstantCounterOffer.fromJson(push());

      expect(offer.driverPhotoUrl, isNull);
      expect(offer.plateNumber, isNull);
    });

    test('keeps the passenger fare for the struck-through comparison', () {
      final offer = InstantCounterOffer.fromJson(push());

      expect(offer.proposedFare, '18.00');
      expect(offer.passengerFare, '12.00');
    });

    test('still parses the REST shape, where ratings are numbers', () {
      final offer = InstantCounterOffer.fromJson({
        'id': 'offer-2',
        'proposedFare': '20.00',
        'currency': 'JOD',
        'driverRating': 4.5,
        'driverTotalRatings': 10,
      });

      expect(offer.driverRating, 4.5);
      expect(offer.driverTotalRatings, 10);
    });
  });

  group('InstantCounterOffer.secondsLeft', () {
    test('counts down to the deadline', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final offer = InstantCounterOffer(
        id: 'o',
        proposedFare: '18.00',
        currency: 'JOD',
        expiresAt: now.add(const Duration(seconds: 17)),
      );

      expect(offer.secondsLeft(now), 17);
    });

    test('floors at zero once the offer is dead', () {
      // The sheet uses this to refuse to open on a bid the server has already
      // dropped, so a negative value must never leak through.
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final offer = InstantCounterOffer(
        id: 'o',
        proposedFare: '18.00',
        currency: 'JOD',
        expiresAt: now.subtract(const Duration(seconds: 5)),
      );

      expect(offer.secondsLeft(now), 0);
    });

    test('reports zero when the server sent no deadline', () {
      const offer = InstantCounterOffer(
        id: 'o',
        proposedFare: '18.00',
        currency: 'JOD',
      );

      expect(offer.secondsLeft(), 0);
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

    test('exposes the passenger fare as a number for the counter bounds', () {
      final summary = InstantRequestSummary.fromJson({
        'id': 'req-1',
        'fromName': 'دسوق',
        'toName': 'دمنهور',
        'currency': 'JOD',
        'seatCount': 1,
        'passengerFare': '12.50',
      });

      expect(summary.passengerFareValue, 12.5);
    });
  });
}
