import '../../models/instant_ride_models.dart';
import '../../models/location_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// Client for the instant (on-demand) rides API — "الرحلات المباشرة".
class InstantRideService {
  final ApiClient _api = ApiClient();

  Map<String, dynamic> _unwrap(dynamic response) {
    if (response is Map) {
      final data = response['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return Map<String, dynamic>.from(response);
    }
    return <String, dynamic>{};
  }

  // ── Driver availability ─────────────────────────────────────────────────────

  Future<InstantAvailability> setAvailability({
    required bool isOnline,
    bool? acceptsInstant,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _api.post(
      ApiEndpoints.instantAvailability,
      data: {
        'isOnline': isOnline,
        if (acceptsInstant != null) 'acceptsInstant': acceptsInstant,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    return InstantAvailability.fromJson(_unwrap(response));
  }

  Future<InstantAvailability> heartbeat({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _api.post(
      ApiEndpoints.instantHeartbeat,
      data: {'latitude': latitude, 'longitude': longitude},
    );
    return InstantAvailability.fromJson(_unwrap(response));
  }

  Future<InstantAvailability> getAvailability() async {
    final response = await _api.get(ApiEndpoints.instantAvailabilityMe);
    return InstantAvailability.fromJson(_unwrap(response));
  }

  // ── Passenger requests ──────────────────────────────────────────────────────

  Map<String, dynamic> _pointJson(LocationModel p) => {
    'name': p.name,
    'latitude': p.latitude,
    'longitude': p.longitude,
    if (p.address != null) 'address': p.address,
  };

  /// Anonymous approximate pins of our online drivers near a point, shown as
  /// car markers on the request map. Returns an empty list on any failure —
  /// the pins are decorative and must never break the request flow.
  Future<List<InstantNearbyDriverPin>> nearbyDriverPins({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _api.get(
        ApiEndpoints.instantNearbyDrivers,
        queryParameters: {'latitude': latitude, 'longitude': longitude},
      );
      dynamic data = response;
      if (response is Map) data = response['data'] ?? response;
      if (data is! List) return const [];
      return [
        for (final item in data)
          if (item is Map)
            InstantNearbyDriverPin.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// The fixed, distance-based fare for this route. The server charges exactly
  /// this amount; the passenger cannot change it.
  Future<InstantQuote> getQuote({
    required LocationModel from,
    required LocationModel to,
  }) async {
    final response = await _api.post(
      ApiEndpoints.instantQuotes,
      data: {'from': _pointJson(from), 'to': _pointJson(to)},
    );
    return InstantQuote.fromJson(_unwrap(response));
  }

  Future<InstantRequest> createRequest({
    required LocationModel from,
    required LocationModel to,
    int seatCount = 1,
  }) async {
    // No fare in the body: the server always charges its own quote.
    final response = await _api.post(
      ApiEndpoints.instantRequests,
      data: {
        'from': _pointJson(from),
        'to': _pointJson(to),
        'seatCount': seatCount,
      },
    );
    return InstantRequest.fromJson(_unwrap(response));
  }

  /// The instant ride the signed-in user is in right now (as driver or
  /// passenger), or null.
  Future<ActiveInstantRide?> getActiveRide() async {
    final response = await _api.get(ApiEndpoints.instantActiveRide);
    final body = response is Map && response.containsKey('data')
        ? response['data']
        : response;
    if (body is! Map) return null;
    return ActiveInstantRide.fromJson(Map<String, dynamic>.from(body));
  }

  Future<InstantRequest> getRequest(String id) async {
    final response = await _api.get(ApiEndpoints.instantRequestById(id));
    return InstantRequest.fromJson(_unwrap(response));
  }

  /// Search again with the same route after no driver was found. The server
  /// re-prices it at the current distance fare.
  Future<InstantRequest> retryRequest(String id) async {
    final response = await _api.post(ApiEndpoints.instantRequestRetry(id));
    return InstantRequest.fromJson(_unwrap(response));
  }

  Future<InstantRequest> cancelRequest(String id) async {
    final response = await _api.delete(ApiEndpoints.instantRequestById(id));
    return InstantRequest.fromJson(_unwrap(response));
  }

  /// Start an in-app call on the matched booking; the backend allocates a
  /// proxy number so neither side sees the other's real phone. Returns the
  /// E.164 number to dial.
  Future<String> initiateCall(String bookingId) async {
    final response = await _api.post(
      '/bookings/$bookingId/calls/initiate',
      data: const <String, dynamic>{},
    );
    final number = _unwrap(response)['proxyNumberE164']?.toString() ?? '';
    if (number.isEmpty) throw StateError('no proxy number');
    return number;
  }

  // ── Driver offers ───────────────────────────────────────────────────────────

  /// Returns the driver's currently outstanding offer, or null if none.
  Future<InstantOffer?> getPendingOffer() async {
    final response = await _api.get(ApiEndpoints.instantPendingOffer);
    final data = _unwrap(response);
    if (data['offer'] == null) return null;
    return InstantOffer.fromJson(data);
  }

  Future<InstantRequest> acceptOffer(String offerId) async {
    final response = await _api.post(ApiEndpoints.instantOfferAccept(offerId));
    return InstantRequest.fromJson(_unwrap(response));
  }

  Future<void> declineOffer(String offerId) async {
    await _api.post(ApiEndpoints.instantOfferDecline(offerId));
  }
}
