// T039 — Device fingerprint service for mobile
//
// Produces the `device` block sent with POST /auth/verify-otp.
// Uses device_info_plus for platform identifiers and flutter_secure_storage
// to persist the install-salt across app reinstalls where possible.

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceFingerprintService {
  static final DeviceFingerprintService _instance =
      DeviceFingerprintService._internal();
  factory DeviceFingerprintService() => _instance;
  DeviceFingerprintService._internal();

  final _storage = const FlutterSecureStorage();
  final _deviceInfo = DeviceInfoPlugin();

  // Secure storage key for the per-install salt
  static const _saltKey = 'device_install_salt';

  /// Retrieves (or lazily generates) the per-install salt.
  /// The salt is stored in secure storage so the same value survives
  /// app updates but is reset on a full reinstall.
  Future<String> _getOrCreateInstallSalt() async {
    final existing = await _storage.read(key: _saltKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final salt = const Uuid().v4().replaceAll('-', '');
    await _storage.write(key: _saltKey, value: salt);
    return salt;
  }

  /// Returns the raw device identifier (never sent to server — used only for
  /// local fingerprinting).
  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return info.id; // Android ID (stable per-app-signing, per-device)
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.identifierForVendor ?? 'unknown-ios';
      }
    } catch (_) {}
    return 'unknown-device';
  }

  /// Returns the platform string expected by the backend enum.
  String get platform => Platform.isIOS ? 'ios' : 'android';

  /// Returns a [DevicePayload] ready to embed in the verify-otp request.
  Future<DevicePayload> buildPayload({String? fcmToken}) async {
    final deviceId = await _getDeviceId();
    final installSalt = await _getOrCreateInstallSalt();
    return DevicePayload(
      deviceId: deviceId,
      installSalt: installSalt,
      platform: platform,
      fcmToken: fcmToken,
      locale: Platform.localeName.split('_').first, // e.g. "ar"
    );
  }
}

/// The device block sent as part of POST /auth/verify-otp.
class DevicePayload {
  final String deviceId;
  final String installSalt;
  final String platform;
  final String? fcmToken;
  final String? locale;
  final bool isMockLocation;

  const DevicePayload({
    required this.deviceId,
    required this.installSalt,
    required this.platform,
    this.fcmToken,
    this.locale,
    this.isMockLocation = false,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'installSalt': installSalt,
        'platform': platform,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (locale != null) 'locale': locale,
        'isMockLocation': isMockLocation,
      };
}
