import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class TripEmergencyService {
  final ApiClient _api = ApiClient();

  Future<void> reportEmergency({
    required String tripId,
    double? latitude,
    double? longitude,
  }) async {
    await _api.post(
      ApiEndpoints.tripEmergency(tripId),
      data: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }
}
