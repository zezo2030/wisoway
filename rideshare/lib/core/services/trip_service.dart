import '../../models/trip_model.dart';
import '../../models/location_model.dart';
import '../../models/seat_layout_config.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class TripService {
  final ApiClient _api = ApiClient();

  List<TripModel> _extractTrips(dynamic response) {
    dynamic payload = response;
    if (response is Map<String, dynamic>) {
      payload = response['data'] ?? response;
    }

    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map((json) => TripModel.fromJson(json))
          .toList();
    }

    if (payload is Map<String, dynamic>) {
      final dynamic listPayload =
          payload['data'] ??
          payload['trips'] ??
          payload['items'] ??
          payload['results'];

      if (listPayload is List) {
        return listPayload
            .whereType<Map<String, dynamic>>()
            .map((json) => TripModel.fromJson(json))
            .toList();
      }
    }

    return [];
  }

  // Create a new trip
  Future<String> createTrip({
    required LocationModel from,
    required LocationModel to,
    required DateTime departureTime,
    required double price,
    required String currency,
    required SeatLayoutConfig seatLayout,
    String? carImageUrl,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.trips,
        data: {
          'from': from.toMap(),
          'to': to.toMap(),
          'departureTime': departureTime.toIso8601String(),
          'price': price,
          'currency': currency,
          'totalSeats': seatLayout.totalSeats,
          'seatLayout': seatLayout.toMap(),
          'carImageUrl': carImageUrl,
        },
      );

      final data = response['data'] ?? response;
      return data['_id'] ?? data['id'];
    } catch (e) {
      print('❌ Error creating trip: $e');
      rethrow;
    }
  }

  // Get trip by ID
  Future<TripModel?> getTrip(String tripId) async {
    try {
      final response = await _api.get(ApiEndpoints.tripById(tripId));
      final data = response['data'] ?? response;
      return TripModel.fromJson(data);
    } catch (e) {
      print('❌ Error getting trip: $e');
      return null;
    }
  }

  // Get driver's trips
  Future<List<TripModel>> getDriverTrips({
    String? status,
    String? driverId,
    String? driverName,
  }) async {
    bool sameDriverName(TripModel trip) {
      if (driverName == null || driverName.trim().isEmpty) return false;
      final a = trip.driverName?.trim().toLowerCase();
      final b = driverName.trim().toLowerCase();
      return a != null && a.isNotEmpty && a == b;
    }

    bool sameDriver(TripModel trip) {
      final hasDriverId = driverId != null && driverId.isNotEmpty;
      if (hasDriverId && trip.driverId == driverId) return true;
      return sameDriverName(trip);
    }

    Future<List<TripModel>> fallbackFromPublicTrips() async {
      final Map<String, dynamic> fallbackQuery = {};
      if (status != null && status.isNotEmpty) {
        fallbackQuery['status'] = status;
      }
      final fallbackResponse = await _api.get(
        ApiEndpoints.trips,
        queryParameters: fallbackQuery.isEmpty ? null : fallbackQuery,
      );
      final fallbackTrips = _extractTrips(fallbackResponse);
      if ((driverId == null || driverId.isEmpty) &&
          (driverName == null || driverName.trim().isEmpty)) {
        return fallbackTrips;
      }
      return fallbackTrips.where(sameDriver).toList();
    }

    try {
      final Map<String, dynamic> query = {};
      if (status != null && status.isNotEmpty) {
        query['status'] = status;
      }
      final response = await _api.get(
        ApiEndpoints.myTrips,
        queryParameters: query.isEmpty ? null : query,
      );
      final trips = _extractTrips(response);
      // Some backend versions ignore status on /trips/my; enforce locally.
      final filteredTrips = (status == null || status.isEmpty)
          ? trips
          : trips.where((trip) => trip.status == status).toList();
      if (filteredTrips.isNotEmpty ||
          ((driverId == null || driverId.isEmpty) &&
              (driverName == null || driverName.trim().isEmpty))) {
        return filteredTrips;
      }
      return fallbackFromPublicTrips();
    } catch (e) {
      print('❌ Error getting driver trips: $e');
      if (driverId != null && driverId.isNotEmpty) {
        try {
          return await fallbackFromPublicTrips();
        } catch (_) {
          return [];
        }
      }
      return [];
    }
  }

  // Search/Get active trips (for passengers)
  Future<List<TripModel>> searchActiveTrips({
    LocationModel? from,
    LocationModel? to,
    DateTime? minDepartureTime,
  }) async {
    try {
      final Map<String, dynamic> query = {'status': 'active'};

      if (from != null) {
        query['fromLatitude'] = from.latitude;
        query['fromLongitude'] = from.longitude;
      }
      if (to != null) {
        query['toLatitude'] = to.latitude;
        query['toLongitude'] = to.longitude;
      }
      if (minDepartureTime != null) {
        query['departureDate'] = minDepartureTime.toIso8601String();
      }

      final response = await _api.get(
        ApiEndpoints.trips,
        queryParameters: query,
      );
      return _extractTrips(response);
    } catch (e) {
      print('❌ Error getting active trips: $e');
      return [];
    }
  }

  Future<List<TripModel>> getNearbyTrips({
    required LocationModel riderLocation,
    double radiusKm = 50,
  }) async {
    try {
      final response = await _api.get(
        ApiEndpoints.nearbyTrips,
        queryParameters: {
          'latitude': riderLocation.latitude,
          'longitude': riderLocation.longitude,
          'radiusKm': radiusKm,
          'limit': 20,
        },
      );
      return _extractTrips(response);
    } catch (e) {
      print('❌ Error getting nearby trips: $e');
      return [];
    }
  }

  Future<List<TripModel>> getPreferredTrips({
    required LocationModel riderLocation,
    double radiusKm = 80,
  }) async {
    try {
      final response = await _api.get(
        ApiEndpoints.preferredTrips,
        queryParameters: {
          'latitude': riderLocation.latitude,
          'longitude': riderLocation.longitude,
          'radiusKm': radiusKm,
          'limit': 20,
        },
      );
      return _extractTrips(response);
    } catch (e) {
      print('❌ Error getting preferred trips: $e');
      return [];
    }
  }

  // Hide trip
  Future<void> hideTrip(String tripId) async {
    await _api.patch(ApiEndpoints.hideTrip(tripId));
  }

  // Show trip (unhide)
  Future<void> showTrip(String tripId) async {
    await _api.patch(ApiEndpoints.showTrip(tripId));
  }

  // Cancel/Delete trip
  Future<void> cancelTrip(String tripId) async {
    await _api.delete(ApiEndpoints.cancelTrip(tripId));
  }

  // Complete trip
  Future<void> completeTrip(String tripId) async {
    await _api.patch(ApiEndpoints.completeTrip(tripId));
  }
}
