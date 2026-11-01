import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_endpoints.dart';

class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  final _storage = const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _pendingDriverRegistrationKey = 'pending_driver_registration';

  static const _nativeChannel = MethodChannel(
    'com.abdelaziz.visionway/booking_notification',
  );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _shareWithOfferOverlay(accessToken);
  }

  /// Hands the current access token (in memory only) to the Android ride
  /// offer card drawn over other apps, so «تجاهل» there can decline without
  /// opening the app. Call at start-up too.
  Future<void> syncOfferOverlayAuth() async =>
      _shareWithOfferOverlay(await getAccessToken());

  Future<void> _shareWithOfferOverlay(String? accessToken) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _nativeChannel.invokeMethod('setOfferApiAuth', {
        'baseUrl': ApiEndpoints.baseUrl,
        'token': accessToken,
      });
    } catch (_) {
      // No activity yet — the next save or start-up shares it.
    }
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);
  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  // ── Pending driver registration (pre-account onboarding state) ───────────
  Future<void> savePendingDriverRegistration(String json) async {
    await _storage.write(key: _pendingDriverRegistrationKey, value: json);
  }

  Future<String?> getPendingDriverRegistration() =>
      _storage.read(key: _pendingDriverRegistrationKey);

  Future<void> clearPendingDriverRegistration() async {
    await _storage.delete(key: _pendingDriverRegistrationKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
    await _shareWithOfferOverlay(null);
  }

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
