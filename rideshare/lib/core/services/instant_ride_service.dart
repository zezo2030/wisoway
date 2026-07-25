import 'package:dio/dio.dart';

import '../../models/instant_ride_models.dart';
import '../../models/location_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// The retried route no longer prices at the passenger's old fare, so they
/// have to confirm the new one instead of the app changing it silently.
class InstantRetryFareChangedException implements Exception {
  final InstantQuote? quote;

  const InstantRetryFareChangedException(this.quote);

  @override
  String toString() => 'InstantRetryFareChangedException';
}

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

  /// Distance-based recommended fare + allowed bounds for this route.
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
    double? passengerFare,
  }) async {
    final response = await _api.post(
      ApiEndpoints.instantRequests,
      data: {
        'from': _pointJson(from),
        'to': _pointJson(to),
        'seatCount': seatCount,
        if (passengerFare != null) 'passengerFare': passengerFare,
      },
    );
    return InstantRequest.fromJson(_unwrap(response));
  }

  // ── Passenger: counter-offer decisions ─────────────────────────────────────

  Future<InstantRequest> acceptCounterOffer(
    String requestId,
    String offerId,
  ) async {
    final response = await _api.post(
      ApiEndpoints.instantCounterAccept(requestId, offerId),
    );
    return InstantRequest.fromJson(_unwrap(response));
  }

  Future<InstantRequest> declineCounterOffer(
    String requestId,
    String offerId,
  ) async {
    final response = await _api.post(
      ApiEndpoints.instantCounterDecline(requestId, offerId),
    );
    return InstantRequest.fromJson(_unwrap(response));
  }

  Future<InstantRequest> getRequest(String id) async {
    final response = await _api.get(ApiEndpoints.instantRequestById(id));
    return InstantRequest.fromJson(_unwrap(response));
  }

  /// Raise the asking fare while searching (re-invites decliners).
  Future<InstantRequest> updateFare(String id, double passengerFare) async {
    final response = await _api.patch(
      ApiEndpoints.instantRequestFare(id),
      data: {'passengerFare': passengerFare},
    );
    return InstantRequest.fromJson(_unwrap(response));
  }

  /// Search again with the same route after no driver was found.
  ///
  /// Throws [InstantRetryFareChangedException] when the server needs the
  /// passenger to confirm a re-priced fare before the new attempt starts.
  Future<InstantRequest> retryRequest(String id) async {
    try {
      final response = await _api.dio.post(ApiEndpoints.instantRequestRetry(id));
      return InstantRequest.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      final body = e.response?.data;
      final data = body is Map ? Map<String, dynamic>.from(body) : null;
      if (data?['code'] == _fareReconfirmationCode) {
        throw InstantRetryFareChangedException(
          data?['quote'] is Map
              ? InstantQuote.fromJson(
                  Map<String, dynamic>.from(data!['quote'] as Map),
                )
              : null,
        );
      }
      throw ApiClient.mapError(e);
    }
  }

  static const String _fareReconfirmationCode =
      'INSTANT_RETRY_FARE_RECONFIRMATION_REQUIRED';

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

  /// Driver proposes a higher fare instead of accepting the passenger's.
  Future<void> counterOffer(String offerId, double amount) async {
    await _api.post(
      ApiEndpoints.instantOfferRespond(offerId),
      data: {'responseType': 'counter', 'amount': amount},
    );
  }
}
