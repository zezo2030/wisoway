import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../errors/exception_mapper.dart';
import '../errors/failure.dart';

sealed class RouteResult {}

class RouteOk extends RouteResult {
  final List<LatLng> polyline;
  final LatLngBounds? bounds;
  final String distance;
  final String duration;

  RouteOk({
    required this.polyline,
    this.bounds,
    this.distance = '',
    this.duration = '',
  });
}

class RouteUnavailable extends RouteResult {
  final Failure failure;

  RouteUnavailable(this.failure);
}

class RouteService {
  final ApiClient _apiClient;
  final RouteFetcher? _routeFetcher;

  RouteService({
    ApiClient? apiClient,
    RouteFetcher? routeFetcher,
  })  : _apiClient = apiClient ?? ApiClient(),
        _routeFetcher = routeFetcher;

  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final rawResponse = await (_routeFetcher?.call(
            origin: origin,
            destination: destination,
          ) ??
          _fetchRouteFromBackend(
            origin: origin,
            destination: destination,
          ));
      final data = (rawResponse['data'] ?? rawResponse) as Map<String, dynamic>;

      final overviewPolyline = data['overviewPolyline'] as String?;
      if (overviewPolyline == null || overviewPolyline.isEmpty) {
        return RouteUnavailable(Failure(
          category: FailureCategory.server,
          messageKey: 'errorsRouteUnavailable',
          severity: FailureSeverity.warning,
          developerDetail: 'Route API returned an empty overview polyline.',
        ));
      }

      final points = decodePolyline(overviewPolyline);
      if (points.isEmpty) {
        return RouteUnavailable(Failure(
          category: FailureCategory.server,
          messageKey: 'errorsRouteUnavailable',
          severity: FailureSeverity.warning,
          developerDetail: 'Decoded route polyline is empty.',
        ));
      }

      final bounds = computeBounds(points);

      return RouteOk(
        polyline: points,
        bounds: bounds,
        distance: (data['distanceText'] as String?) ?? '',
        duration: (data['durationText'] as String?) ?? '',
      );
    } catch (e, st) {
      return RouteUnavailable(ExceptionMapper.fromError(e, st).copyWith(
        messageKey: 'errorsRouteUnavailable',
        severity: FailureSeverity.warning,
      ));
    }
  }

  Future<Map<String, dynamic>> _fetchRouteFromBackend({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.locationsRoute,
      queryParameters: {
        'fromLatitude': origin.latitude,
        'fromLongitude': origin.longitude,
        'toLatitude': destination.latitude,
        'toLongitude': destination.longitude,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  static LatLngBounds computeBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat - 0.02, minLng - 0.02),
      northeast: LatLng(maxLat + 0.02, maxLng + 0.02),
    );
  }
}

typedef RouteFetcher =
    Future<Map<String, dynamic>> Function({
      required LatLng origin,
      required LatLng destination,
    });

extension FailureCopyWith on Failure {
  Failure copyWith({
    FailureCategory? category,
    String? messageKey,
    List<String>? messageArgs,
    FailureSeverity? severity,
    FailureAction? nextAction,
    String? developerDetail,
  }) {
    return Failure(
      category: category ?? this.category,
      messageKey: messageKey ?? this.messageKey,
      messageArgs: messageArgs ?? this.messageArgs,
      severity: severity ?? this.severity,
      nextAction: nextAction ?? this.nextAction,
      developerDetail: developerDetail ?? this.developerDetail,
    );
  }
}
