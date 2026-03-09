import '../../models/booking_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class BookingService {
  final ApiClient _api = ApiClient();

  // Create a booking request
  Future<String> createBooking({
    required String tripId,
    required String seatNumber, // Changed to String "X-Y"
    required bool sharePhoneWithDriver,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.bookings,
        data: {
          'tripId': tripId,
          'seatNumber': seatNumber,
          'sharePhoneWithDriver': sharePhoneWithDriver,
        },
      );

      final data = response['data'] ?? response;
      return data['_id'] ?? data['id'];
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
