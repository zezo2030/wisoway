import '../../models/ride_payment.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// Ride fares at the end of a trip — instant rides and shared trips alike.
class RidePaymentService {
  RidePaymentService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Passenger: my fare on this trip.
  Future<RidePayment> getMine(String tripId) async {
    final response = await _api.get(ApiEndpoints.ridePaymentMine(tripId));
    return RidePayment.fromJson(_unwrapMap(response));
  }

  /// Passenger: CliQ failed or was ignored — send the request again.
  Future<RidePayment> retryCliq(
    String bookingId, {
    String? payerCliqAlias,
  }) async {
    final response = await _api.post(
      ApiEndpoints.ridePaymentRetryCliq(bookingId),
      data: {
        if (payerCliqAlias != null && payerCliqAlias.trim().isNotEmpty)
          'payerCliqAlias': payerCliqAlias.trim(),
      },
    );
    return RidePayment.fromJson(_unwrapMap(response));
  }

  /// Passenger: pay the driver cash instead.
  Future<RidePayment> switchToCash(String bookingId) async {
    final response = await _api.post(
      ApiEndpoints.ridePaymentSwitchToCash(bookingId),
    );
    return RidePayment.fromJson(_unwrapMap(response));
  }

  /// Driver: every rider's fare on the trip.
  Future<List<RidePayment>> forTrip(String tripId) async {
    final response = await _api.get(ApiEndpoints.ridePaymentsForTrip(tripId));
    final body = response is Map && response.containsKey('data')
        ? response['data']
        : response;
    if (body is! List) return const [];
    return body
        .whereType<Map>()
        .map((m) => RidePayment.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Driver: cash received, or the passenger didn't pay (reported to support).
  Future<RidePayment> confirmCash(
    String bookingId, {
    required bool received,
    String? note,
  }) async {
    final response = await _api.post(
      ApiEndpoints.ridePaymentCash(bookingId),
      data: {
        'received': received,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return RidePayment.fromJson(_unwrapMap(response));
  }

  static Map<String, dynamic> _unwrapMap(dynamic response) {
    final body = response is Map && response['data'] is Map
        ? response['data']
        : response;
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }
}
