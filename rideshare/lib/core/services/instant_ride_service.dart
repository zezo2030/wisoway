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

  Future<InstantRequest> createRequest({
    required LocationModel from,
    required LocationModel to,
    int seatCount = 1,
  }) async {
    final response = await _api.post(
      ApiEndpoints.instantRequests,
      data: {
        'from': {
          'name': from.name,
          'latitude': from.latitude,
          'longitude': from.longitude,
          if (from.address != null) 'address': from.address,
        },
        'to': {
          'name': to.name,
          'latitude': to.latitude,
          'longitude': to.longitude,
          if (to.address != null) 'address': to.address,
        },
        'seatCount': seatCount,
      },
    );
    return InstantRequest.fromJson(_unwrap(response));
  }

  Future<InstantRequest> getRequest(String id) async {
    final response = await _api.get(ApiEndpoints.instantRequestById(id));
    return InstantRequest.fromJson(_unwrap(response));
  }

  Future<InstantRequest> cancelRequest(String id) async {
    final response = await _api.delete(ApiEndpoints.instantRequestById(id));
    return InstantRequest.fromJson(_unwrap(response));
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
