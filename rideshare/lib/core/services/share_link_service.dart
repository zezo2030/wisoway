import '../api/api_client.dart';
import '../api/api_endpoints.dart';

/// Creates public, read-only trip share links and resolves them to an absolute
/// URL that opens the live-tracking web page (`{origin}/share/{token}`).
class ShareLinkService {
  final ApiClient _api = ApiClient();

  /// Creates a share link for [tripId] and returns the absolute, openable URL.
  Future<String> createTrackingShareUrl(String tripId) async {
    final response = await _api.post(ApiEndpoints.shareLink(tripId));
    final data = response is Map ? (response['data'] ?? response) : response;
    final token = (data is Map ? data['token'] : null)?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Share link token missing in response');
    }
    return '${_webOrigin()}/share/$token';
  }

  /// The public web origin (API base URL with the `/api/...` prefix stripped),
  /// where the static `share.html` tracking page is served.
  String _webOrigin() {
    final base = ApiEndpoints.baseUrl;
    final idx = base.indexOf('/api/');
    return idx > 0 ? base.substring(0, idx) : base;
  }
}
