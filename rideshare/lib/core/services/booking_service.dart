import '../../models/booking_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class BookingService {
  final ApiClient _api = ApiClient();

  // Create a booking request
  Future<Map<String, dynamic>> createBooking({
    required String tripId,
    String? seatNumber, // Backward compatibility
    List<String>? seatNumbers,
    required bool sharePhoneWithDriver,
    String? walletIdempotencyKey,
  }) async {
    try {
      final resolvedSeatNumbers = (seatNumbers ?? const [])
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toSet()
          .toList();
      if (resolvedSeatNumbers.isEmpty && (seatNumber == null || seatNumber.isEmpty)) {
        throw Exception('At least one seat must be selected');
      }
      final payload = <String, dynamic>{
        'tripId': tripId,
        'sharePhoneWithDriver': sharePhoneWithDriver,
      };
      if (resolvedSeatNumbers.isNotEmpty) {
        payload['seatNumbers'] = resolvedSeatNumbers;
      }
      if (seatNumber != null && seatNumber.isNotEmpty) {
        payload['seatNumber'] = seatNumber;
      }
      if (walletIdempotencyKey != null && walletIdempotencyKey.isNotEmpty) {
        payload['walletIdempotencyKey'] = walletIdempotencyKey;
      }
      final response = await _api.post(
        ApiEndpoints.bookings,
        data: payload,
      );

      final res = response['data'] ?? response;
      if (res is Map<String, dynamic>) {
        return res;
      }
      return <String, dynamic>{};
    } catch (e) {
      print('❌ Error creating booking: $e');
      rethrow;
    }
  }

  // Confirm booking (driver confirms the booking)
  Future<void> confirmBooking(String bookingId) async {
    try {
      await _api.patch(ApiEndpoints.confirmBooking(bookingId));
    } catch (e) {
      print('❌ Error confirming booking: $e');
      rethrow;
    }
  }

  // Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _api.patch(ApiEndpoints.cancelBooking(bookingId));
    } catch (e) {
      print('❌ Error cancelling booking: $e');
      rethrow;
    }
  }

  // Get booking by ID
  Future<BookingModel?> getBooking(String bookingId) async {
    try {
      final response = await _api.get(ApiEndpoints.bookingById(bookingId));
      final data = response['data'] ?? response;
      return BookingModel.fromJson(data);
    } catch (e) {
      print('❌ Error getting booking: $e');
      return null;
    }
  }

  // Get bookings for a trip (driver views passengers)
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
      print('❌ Error getting trip bookings: $e');
      return [];
    }
  }

  /// نفس getMyBookings (للتوافق مع الشاشات).
  Future<List<BookingModel>> getUserBookings({String? status}) =>
      getMyBookings(status: status);

  Future<List<BookingGroupModel>> getMyGroupedBookings({String? status}) async {
    try {
      Map<String, dynamic>? query;
      if (status != null) {
        query = {'status': status};
      }
      final response = await _api.get(
        ApiEndpoints.myGroupedBookings,
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
          .map((json) =>
              BookingGroupModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting grouped bookings: $e');
      return [];
    }
  }

  Future<BookingGroupModel?> getBookingGroupById(String bookingGroupId) async {
    try {
      final response = await _api.get(ApiEndpoints.bookingGroupById(bookingGroupId));
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        return BookingGroupModel.fromJson(data);
      }
      return null;
    } catch (e) {
      print('❌ Error getting booking group details: $e');
      return null;
    }
  }

  // Get user's own bookings
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
        // Backend returns { data: [...], meta: {...} } via TransformInterceptor
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
      print('❌ Error getting user bookings: $e');
      return [];
    }
  }
}
