import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// Sends the passenger's position during a shared trip so the server can prove
/// they rode with the driver.
///
/// Outlives the trip screen, so leaving it does not interrupt the check. It
/// stops when the server says so: the ride is proven or the trip is over.
class PassengerTripLocationReporter {
  PassengerTripLocationReporter._();

  static final instance = PassengerTripLocationReporter._();

  static const _sendEvery = Duration(seconds: 30);

  /// A backstop for a trip the app never hears the end of.
  static const _longestRun = Duration(hours: 6);

  final ApiClient _api = ApiClient();
  final Set<String> _settledTrips = {};

  StreamSubscription<Position>? _positions;
  Timer? _backstop;
  String? _tripId;
  DateTime? _lastSentAt;
  bool _sending = false;

  /// The trip screen is shared, so its driver opens it too. Compares against
  /// this trip rather than the account role: a driver can ride as a passenger
  /// on someone else's trip.
  static bool isPassengerOf(String tripDriverId, String? userId) =>
      userId != null && userId != tripDriverId;

  /// Whether this trip needs nothing more: running, finished or declined.
  bool isHandled(String tripId) =>
      _tripId == tripId || _settledTrips.contains(tripId);

  /// The passenger said no; ask again on their next trip, not this one.
  void skip(String tripId) => _settledTrips.add(tripId);

  void start({required String tripId, required LocationSettings settings}) {
    if (isHandled(tripId)) return;
    stop();
    _tripId = tripId;
    _backstop = Timer(_longestRun, stop);
    _positions = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPosition, onError: (_) => stop());
  }

  void stop() {
    final tripId = _tripId;
    if (tripId != null) _settledTrips.add(tripId);
    _positions?.cancel();
    _positions = null;
    _backstop?.cancel();
    _backstop = null;
    _tripId = null;
    _lastSentAt = null;
  }

  Future<void> _onPosition(Position position) async {
    final tripId = _tripId;
    if (tripId == null || _sending) return;
    final last = _lastSentAt;
    if (last != null && DateTime.now().difference(last) < _sendEvery) return;

    _sending = true;
    _lastSentAt = DateTime.now();
    try {
      final response = await _api.post(
        ApiEndpoints.trackingPassengerLocation,
        data: {
          'tripId': tripId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
          'isMockLocation': position.isMocked,
        },
      );
      if (!shouldKeepSending(response) && _tripId == tripId) stop();
    } catch (_) {
      // A missed reading only delays the proof; the next one tries again.
    } finally {
      _sending = false;
    }
  }

  @visibleForTesting
  static bool shouldKeepSending(dynamic response) {
    final data = response is Map ? (response['data'] ?? response) : null;
    return data is Map ? data['tracking'] != false : true;
  }
}
