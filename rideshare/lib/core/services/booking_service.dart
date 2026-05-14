import '../../models/booking_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../errors/failure.dart';

/// Payload for a single seat within a v2 multi-seat booking.
class BookingSeatRequest {
  final String seatNumber;
  final String displayName;
  final String gender; // 'male' | 'female'
  final bool isMainBooker;

  const BookingSeatRequest({
    required this.seatNumber,
    required this.displayName,
    required this.gender,
    this.isMainBooker = false,
  });

  Map<String, dynamic> toJson() => {
        'seatNumber': seatNumber,
        'displayName': displayName,
        'gender': gender,
        'isMainBooker': isMainBooker,
      };
}

class BookingService {
  final ApiClient _api = ApiClient();

  Map<String, dynamic> _unwrapMap(dynamic response) {
    final raw = response is Map ? (response['data'] ?? response) : response;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  BookingModel _bookingFromResponse(
    dynamic response, {
    required String tripId,
    required List<BookingSeatRequest> seats,
    required bool sharePhoneWithDriver,
  }) {
    final data = _unwrapMap(response);
    try {
      if (data.isNotEmpty) return BookingModel.fromJson(data);
    } catch (e) {
      print('Booking created but response parsing failed: $e');
    }

    final now = DateTime.now();
    return BookingModel(
      id: (data['_id'] ?? data['id'] ?? '').toString(),
      tripId: tripId,
      userId: (data['userId'] ?? '').toString(),
      seatNumber: seats.isNotEmpty ? seats.first.seatNumber : null,
      seatCount: seats.length,
      sharePhoneWithDriver: sharePhoneWithDriver,
      status: (data['status'] ?? 'pending').toString(),
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── v1 legacy ──────────────────────────────────────────────────────────────

  /// @deprecated Use [createMultiSeat] instead.
  Future<String> createBooking({
    required String tripId,
    required String seatNumber,
    required bool sharePhoneWithDriver,
    String? walletIdempotencyKey,
  }) async {
    try {
      final payload = <String, dynamic>{
        'tripId': tripId,
        'seatNumber': seatNumber,
        'sharePhoneWithDriver': sharePhoneWithDriver,
      };

      if (walletIdempotencyKey != null && walletIdempotencyKey.isNotEmpty) {
        payload['walletIdempotencyKey'] = walletIdempotencyKey;
      }

      final response = await _api.post(ApiEndpoints.bookings, data: payload);
      final res = response['data'] ?? response;
      return res['_id'] ?? res['id'];
    } catch (e) {
      if (e is Failure) {
        print('Error creating booking: ${e.developerDetail}');
      } else {
        print('Error creating booking: $e');
      }
      rethrow;
    }
  }

  // ── v2 multi-seat ──────────────────────────────────────────────────────────

  /// Create a multi-seat booking via POST /v2/bookings.
  Future<BookingModel> createMultiSeat({
    required String tripId,
    required List<BookingSeatRequest> seats,
    bool sharePhoneWithDriver = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        'tripId': tripId,
        'seats': seats.map((s) => s.toJson()).toList(),
        'sharePhoneWithDriver': sharePhoneWithDriver,
      };
      final response = await _api.post(ApiEndpoints.bookingsV2, data: payload);
      return _bookingFromResponse(
        response,
        tripId: tripId,
        seats: seats,
        sharePhoneWithDriver: sharePhoneWithDriver,
      );
    } catch (e) {
      if (e is Failure) print('Error createMultiSeat: ${e.developerDetail}');
      rethrow;
    }
  }

  /// Auto-pick seats via POST /v2/bookings/auto-pick.
  Future<BookingModel> autoPick({
    required String tripId,
    required int seatCount,
    required List<BookingSeatRequest> passengers,
    bool sharePhoneWithDriver = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        'tripId': tripId,
        'seatCount': seatCount,
        'passengers': passengers.map((p) => p.toJson()).toList(),
        'sharePhoneWithDriver': sharePhoneWithDriver,
      };
      final response =
          await _api.post(ApiEndpoints.bookingsV2AutoPick, data: payload);
      return _bookingFromResponse(
        response,
        tripId: tripId,
        seats: passengers,
        sharePhoneWithDriver: sharePhoneWithDriver,
      );
    } catch (e) {
      if (e is Failure) print('Error autoPick: ${e.developerDetail}');
      rethrow;
    }
  }

  /// Driver accepts a booking via PATCH /v2/bookings/:id/accept.
  Future<BookingModel> acceptBooking(String bookingId) async {
    try {
      final response =
          await _api.patch(ApiEndpoints.acceptBooking(bookingId));
      final res = response['data'] ?? response;
      return BookingModel.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      if (e is Failure) print('Error acceptBooking: ${e.developerDetail}');
      rethrow;
    }
  }

  /// Driver rejects a booking via PATCH /v2/bookings/:id/reject.
  Future<BookingModel> rejectBooking(String bookingId, {String? reason}) async {
    try {
      final response = await _api.patch(
        ApiEndpoints.rejectBooking(bookingId),
        data: reason != null ? {'reason': reason} : null,
      );
      final res = response['data'] ?? response;
      return BookingModel.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      if (e is Failure) print('Error rejectBooking: ${e.developerDetail}');
      rethrow;
    }
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  Future<void> confirmBooking(String bookingId) async {
    try {
      await _api.patch(ApiEndpoints.confirmBooking(bookingId));
    } catch (e) {
      print('Error confirming booking: $e');
      rethrow;
    }
  }

  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    try {
      await _api.patch(
        ApiEndpoints.cancelBooking(bookingId),
        data: reason != null ? {'reason': reason} : null,
      );
    } catch (e) {
      print('Error cancelling booking: $e');
      rethrow;
    }
  }

  Future<BookingModel?> getBooking(String bookingId) async {
    try {
      final response = await _api.get(ApiEndpoints.bookingById(bookingId));
      final data = response['data'] ?? response;
      return BookingModel.fromJson(data);
    } catch (e) {
      print('Error getting booking: $e');
      return null;
    }
  }

  Future<List<BookingModel>> getTripBookings(String tripId) async {
    try {
      final response = await _api.get(ApiEndpoints.tripBookings(tripId));
      final raw = response['data'];
      List<dynamic> list;

      if (raw is List) {
        list = raw;
      } else if (raw is Map<String, dynamic>) {
        list =
            raw['data'] ??
            raw['bookings'] ??
            raw['items'] ??
            raw['results'] ??
            [];
      } else {
        list = [];
      }

      return list
          .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting trip bookings: $e');
      return [];
    }
  }

  Future<List<BookingModel>> getUserBookings({String? status}) =>
      getMyBookings(status: status);

  Future<List<BookingModel>> getMyBookings({String? status}) async {
    try {
      Map<String, dynamic>? query;
      if (status != null) {
        query = {'status': status};
      }

      final response = await _api.get(
        ApiEndpoints.myBookings,
        queryParameters: query,
      );
      final raw = response['data'];
      List<dynamic> list;

      if (raw is List) {
        list = raw;
      } else if (raw is Map<String, dynamic>) {
        list =
            raw['data'] ??
            raw['bookings'] ??
            raw['items'] ??
            raw['results'] ??
            [];
      } else {
        list = [];
      }

      return list
          .map((json) => BookingModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting user bookings: $e');
      return [];
    }
  }

  /// Trigger wallet collection of the caller's pending charges.
  /// Returns a summary: applied/skipped counts and totals.
  Future<Map<String, dynamic>> collectMyPendingCharges() async {
    final response = await _api.post(ApiEndpoints.myPendingChargesCollect);
    final raw = response is Map ? (response['data'] ?? response) : response;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  /// Fetch outstanding pending charges for the current user.
  Future<List<Map<String, dynamic>>> getMyPendingCharges() async {
    try {
      final response = await _api.get(ApiEndpoints.myPendingCharges);
      final raw = response['data'];
      if (raw is Map<String, dynamic>) {
        final items = raw['data'] ?? raw['items'] ?? [];
        return List<Map<String, dynamic>>.from(items);
      }
      return [];
    } catch (e) {
      print('Error getting pending charges: $e');
      return [];
    }
  }

}
