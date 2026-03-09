import '../api/api_endpoints.dart';

class BackendUrlResolver {
  static String _backendOrigin() {
    final uri = Uri.parse(ApiEndpoints.baseUrl);
    final hasDefaultPort =
        (uri.scheme == 'http' && uri.port == 80) ||
        (uri.scheme == 'https' && uri.port == 443);
    final portPart = (uri.hasPort && !hasDefaultPort) ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portPart';
  }

  static String? normalize(String? rawUrl) {
    if (rawUrl == null) return null;

    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    // Relative URLs returned by backend, e.g. /uploads/general/file.jpg
    if (trimmed.startsWith('/')) {
      return '${_backendOrigin()}$trimmed';
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    // Device cannot reach backend files via localhost/127.0.0.1.
    final isLocalHost = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (!isLocalHost) return trimmed;

    final backend = Uri.parse(_backendOrigin());
    return uri.replace(
      scheme: backend.scheme,
      host: backend.host,
      port: backend.hasPort ? backend.port : null,
    ).toString();
  }
}
