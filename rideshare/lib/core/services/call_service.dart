import '../api/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of a successful call initiation.
class CallInitiateResult {
  final String callSessionId;
  final String proxyNumberE164;
  final DateTime expiresAt;

  const CallInitiateResult({
    required this.callSessionId,
    required this.proxyNumberE164,
    required this.expiresAt,
  });

  factory CallInitiateResult.fromJson(Map<String, dynamic> json) {
    return CallInitiateResult(
      callSessionId: json['callSessionId']?.toString() ?? '',
      proxyNumberE164: json['proxyNumberE164']?.toString() ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'].toString())
          : DateTime.now().add(const Duration(hours: 1)),
    );
  }
}

/// Service for initiating in-app calls via the settlement + Twilio proxy flow.
///
/// Usage:
///   final result = await CallService().initiate(bookingId);
///   await CallService().launchCall(result.proxyNumberE164);
class CallService {
  final ApiClient _api = ApiClient();

  /// POST /bookings/:bookingId/calls/initiate
  ///
  /// Returns a [CallInitiateResult] with the proxy number to dial.
  /// Throws on 403 (BOOKING_NOT_SETTLED), 503 (NO_PROXY_NUMBERS_AVAILABLE),
  /// or other API errors.
  Future<CallInitiateResult> initiate(String bookingId) async {
    final response = await _api.post(
      '/bookings/$bookingId/calls/initiate',
      data: {},
    );
    final data = response['data'] ?? response;
    return CallInitiateResult.fromJson(data as Map<String, dynamic>);
  }

  /// Launch the device phone dialer with the given proxy number.
  Future<bool> launchCall(String proxyNumberE164) async {
    final uri = Uri.parse('tel:$proxyNumberE164');
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }
}
