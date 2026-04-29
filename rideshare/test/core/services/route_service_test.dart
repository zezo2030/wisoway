import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:rideshare/core/services/route_service.dart';
import 'package:rideshare/core/errors/failure.dart';

void main() {
  group('RouteService', () {
    group('fetchRoute', () {
      const origin = LatLng(31.9454, 35.9284);
      const destination = LatLng(31.9534, 35.9404);

      test('returns RouteOk with decoded polyline on successful response', () async {
        final encodedPolyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

        final service = RouteService(
          routeFetcher: ({
            required LatLng origin,
            required LatLng destination,
          }) async =>
              {
                'overviewPolyline': encodedPolyline,
                'distanceText': '5.2 km',
                'durationText': '12 mins',
              },
        );

        final result = await service.fetchRoute(
          origin: origin,
          destination: destination,
        );

        expect(result, isA<RouteOk>());
        final ok = result as RouteOk;
        expect(ok.polyline, isNotEmpty);
        expect(ok.distance, '5.2 km');
        expect(ok.duration, '12 mins');
        expect(ok.bounds, isNotNull);
      });

      test('returns RouteOk with correct bounds encompassing all points', () async {
        final encodedPolyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

        final service = RouteService(
          routeFetcher: ({
            required LatLng origin,
            required LatLng destination,
          }) async =>
              {
                'overviewPolyline': encodedPolyline,
                'distanceText': '1 km',
                'durationText': '3 mins',
              },
        );

        final result = await service.fetchRoute(
          origin: origin,
          destination: destination,
        );

        final ok = result as RouteOk;
        final points = ok.polyline;
        final bounds = ok.bounds!;

        for (final p in points) {
          expect(p.latitude, greaterThanOrEqualTo(bounds.southwest.latitude));
          expect(p.latitude, lessThanOrEqualTo(bounds.northeast.latitude));
          expect(p.longitude, greaterThanOrEqualTo(bounds.southwest.longitude));
          expect(p.longitude, lessThanOrEqualTo(bounds.northeast.longitude));
        }
      });

      test('returns RouteUnavailable when API returns an empty polyline', () async {
        final service = RouteService(
          routeFetcher: ({
            required LatLng origin,
            required LatLng destination,
          }) async =>
              {
                'overviewPolyline': '',
                'distanceText': '',
                'durationText': '',
              },
        );

        final result = await service.fetchRoute(
          origin: origin,
          destination: destination,
        );

        expect(result, isA<RouteUnavailable>());
        final unavailable = result as RouteUnavailable;
        expect(unavailable.failure.category, FailureCategory.server);
        expect(unavailable.failure.messageKey, 'errorsRouteUnavailable');
      });

      test('returns RouteUnavailable when route fetcher throws', () async {
        final service = RouteService(
          routeFetcher: ({
            required LatLng origin,
            required LatLng destination,
          }) async {
            throw Exception('Connection refused');
          },
        );

        final result = await service.fetchRoute(
          origin: origin,
          destination: destination,
        );

        expect(result, isA<RouteUnavailable>());
        final unavailable = result as RouteUnavailable;
        expect(unavailable.failure.category, FailureCategory.server);
      });
    });

    group('decodePolyline', () {
      test('decodes a known encoded polyline to correct LatLng list', () {
        final points = RouteService.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

        expect(points.length, 3);
        expect(points[0].latitude, closeTo(38.5, 0.001));
        expect(points[0].longitude, closeTo(-120.2, 0.001));
        expect(points[1].latitude, closeTo(40.7, 0.001));
        expect(points[1].longitude, closeTo(-120.95, 0.001));
        expect(points[2].latitude, closeTo(43.252, 0.001));
        expect(points[2].longitude, closeTo(-126.453, 0.001));
      });

      test('returns empty list for empty string', () {
        final points = RouteService.decodePolyline('');
        expect(points, isEmpty);
      });

      test('handles short polyline with one point', () {
        final points = RouteService.decodePolyline('_p~iF~ps|U');
        expect(points.length, 1);
        expect(points[0].latitude, closeTo(38.5, 0.001));
        expect(points[0].longitude, closeTo(-120.2, 0.001));
      });
    });

    group('computeBounds', () {
      test('computes correct bounds for a set of points', () {
        final points = [
          const LatLng(31.9454, 35.9284),
          const LatLng(31.9534, 35.9404),
          const LatLng(31.9400, 35.9500),
        ];

        final bounds = RouteService.computeBounds(points);

        expect(bounds.southwest.latitude, closeTo(31.9200, 0.001));
        expect(bounds.southwest.longitude, closeTo(35.9084, 0.001));
        expect(bounds.northeast.latitude, closeTo(31.9734, 0.001));
        expect(bounds.northeast.longitude, closeTo(35.9700, 0.001));
      });

      test('returns tight bounds for two-point route', () {
        final points = [
          const LatLng(31.9454, 35.9284),
          const LatLng(31.9534, 35.9404),
        ];

        final bounds = RouteService.computeBounds(points);

        expect(bounds.southwest.latitude, lessThan(31.9454));
        expect(bounds.northeast.latitude, greaterThan(31.9534));
        expect(bounds.southwest.longitude, lessThan(35.9284));
        expect(bounds.northeast.longitude, greaterThan(35.9404));
      });
    });
  });
}
