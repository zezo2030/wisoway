import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import '../constants/route_names.dart';
import '../services/notification_navigation_service.dart';
import 'api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage = TokenStorage();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final publicPaths = [
      ApiEndpoints.login,
      ApiEndpoints.register,
      ApiEndpoints.sendOtp,
      ApiEndpoints.verifyOtp,
      ApiEndpoints.driverVerifyPhone,
      ApiEndpoints.driverRegister,
      ApiEndpoints.uploadsRegistration,
      ApiEndpoints.forgotPassword,
      ApiEndpoints.verifyResetOtp,
      ApiEndpoints.resetPassword,
      ApiEndpoints.refresh,
    ];

    if (!publicPaths.any((path) => options.path.contains(path))) {
      final token = await _tokenStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // ── 403 ACCOUNT_BANNED: clear session and redirect to ban screen ────────
    if (err.response?.statusCode == 403) {
      final data = err.response?.data;
      final code = data is Map ? data['code'] as String? : null;
      if (code == 'ACCOUNT_BANNED') {
        await _tokenStorage.clearAll();
        final navigator =
            NotificationNavigationService.navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil(
            RouteNames.banned,
            (route) => false,
            arguments: {
              'banReason': data['banReason'] as String?,
              'supportWhatsApp': data['supportWhatsApp'] as String?,
            },
          );
        }
        // Swallow the error — navigation already handled
        return;
      }
    }

    // ── 401: attempt token refresh ────────────────────────────────────────
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains(ApiEndpoints.refresh)) {
      try {
        final refreshToken = await _tokenStorage.getRefreshToken();
        if (refreshToken != null) {
          final dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
          final response = await dio.post(
            ApiEndpoints.refresh,
            data: {'refreshToken': refreshToken},
          );

          final data = response.data['data'] ?? response.data;
          final newAccess = data['accessToken'];
          final newRefresh = data['refreshToken'];

          if (newAccess != null && newRefresh != null) {
            await _tokenStorage.saveTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
            );

            err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';

            final retryDio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
            final retryResponse = await retryDio.fetch(err.requestOptions);
            return handler.resolve(retryResponse);
          }
        }
      } catch (e) {
        await _tokenStorage.clearAll(); // تسجيل خروج عند فشل التجديد
      }
    }
    handler.next(err);
  }
}
