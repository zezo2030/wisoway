import '../../models/presence_models.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

abstract class PresenceGateway {
  Future<PresencePrompt> getPrompt(String bookingId);

  /// The prompt for the signed-in passenger's booking, or null without one.
  Future<PresencePrompt?> getPromptForTrip(String tripId);

  Future<void> declare(
    String bookingId,
    PassengerPresenceStatus status,
    List<String> seatNumbers,
  );
}

class PresenceService implements PresenceGateway {
  PresenceService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<PresencePrompt> getPrompt(String bookingId) async {
    final response = await _apiClient.get(
      ApiEndpoints.presencePrompt(bookingId),
    );
    return PresencePrompt.fromJson(_unwrapMap(response));
  }

  @override
  Future<PresencePrompt?> getPromptForTrip(String tripId) async {
    final response = await _apiClient.get(
      ApiEndpoints.tripPresencePrompt(tripId),
    );
    final payload = response is Map ? response['data'] : response;
    return payload == null
        ? null
        : PresencePrompt.fromJson(_unwrapMap(payload));
  }

  @override
  Future<void> declare(
    String bookingId,
    PassengerPresenceStatus status,
    List<String> seatNumbers,
  ) async {
    await _apiClient.post(
      ApiEndpoints.presenceDeclare(bookingId),
      data: {
        'status': status.wireValue,
        if (seatNumbers.isNotEmpty) 'seatNumbers': seatNumbers,
      },
    );
  }

  Map<String, dynamic> _unwrapMap(dynamic response) {
    final payload = response is Map ? (response['data'] ?? response) : response;
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw const FormatException('Presence response must be a JSON object');
  }
}
