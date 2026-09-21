import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../storage/token_storage.dart';
import '../constants/app_constants.dart';
import 'device_fingerprint_service.dart';

/// Result returned by [AuthService.verifyOTP].
/// Carries the authenticated user plus backend safety signals.
class VerifyOtpResult {
  final UserModel? user;
  final String accountState; // 'active' | 'restricted' | 'banned'
  final String deviceState; // 'trusted' | 'new' | 'revoked'
  final bool pendingPhoneLinkRequired;

  const VerifyOtpResult({
    required this.user,
    this.accountState = 'active',
    this.deviceState = 'new',
    this.pendingPhoneLinkRequired = false,
  });
}

class AuthService {
  final ApiClient _api = ApiClient();
  final TokenStorage _tokenStorage = TokenStorage();

  // Instance properties that were previously used
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // ===== Initialize Auth =====
  Future<UserModel?> checkAuthState() async {
    final hasTokens = await _tokenStorage.hasTokens();
    if (hasTokens) {
      try {
        _currentUser = await getProfile();
        return _currentUser;
      } catch (e) {
        // If profile fetch fails, token might be invalid/expired even after refresh attempts
        await logout();
      }
    }
    return null;
  }

  // ===== Sign In (Phone/Password) =====
  Future<UserModel> signIn({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _api.post(
      ApiEndpoints.login,
      data: {'phoneNumber': phoneNumber, 'password': password},
    );

    final data = response['data'] ?? response;
    await _tokenStorage.saveTokens(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
    );
    await _tokenStorage.saveUserId(data['user']['_id'] ?? data['user']['id']);

    _currentUser = UserModel.fromJson(data['user']);
    return _currentUser!;
  }

  // ===== OTP / Phone Auth =====
  Future<void> sendOTP(String phoneNumber) async {
    if (AppConstants.skipOTP) {
      if (kDebugMode) print('Development mode: Skipping actual SMS generation');
      return;
    }

    try {
      await _api.post(ApiEndpoints.sendOtp, data: {'phoneNumber': phoneNumber});
    } catch (e) {
      throw Exception('فشل إرسال كود التحقق. الرجاء المحاولة مرة أخرى.');
    }
  }

  Future<VerifyOtpResult> verifyOTP(
    String phoneNumber,
    String code, {
    DevicePayload? device,
    String? name,
    String? gender,
    String? role,
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{
        'phoneNumber': phoneNumber,
        'code': code.trim(),
      };
      if (device != null) {
        body['device'] = device.toJson();
      }
      // First-time sign-up bootstrap fields. Backend ignores them when an
      // account already exists for the phone.
      if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
      if (gender != null && gender.isNotEmpty) body['gender'] = gender;
      if (role != null && role.isNotEmpty) body['role'] = role;
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }

      final response = await _api.post(ApiEndpoints.verifyOtp, data: body);

      final data = response['data'] ?? response;

      final accountState = (data['accountState'] as String?) ?? 'active';
      final deviceState = (data['deviceState'] as String?) ?? 'new';
      final pendingPhoneLinkRequired =
          (data['pendingPhoneLinkRequired'] as bool?) ?? false;

      // Verification might just return success status without tokens if it's for
      // an existing logged-in user confirming their phone number
      if (data['accessToken'] != null) {
        await _tokenStorage.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );
        await _tokenStorage.saveUserId(
          data['user']['_id'] ?? data['user']['id'],
        );
        _currentUser = UserModel.fromJson(data['user']);
        return VerifyOtpResult(
          user: _currentUser,
          accountState: accountState,
          deviceState: deviceState,
          pendingPhoneLinkRequired: pendingPhoneLinkRequired,
        );
      } else {
        // Just linking the phone — no new tokens; refresh profile
        _currentUser = await getProfile();
        return VerifyOtpResult(
          user: _currentUser,
          accountState: accountState,
          deviceState: deviceState,
          pendingPhoneLinkRequired: pendingPhoneLinkRequired,
        );
      }
    } catch (e) {
      throw Exception('كود التحقق غير صحيح أو منتهي الصلاحية');
    }
  }

  // ===== Deferred driver registration =====

  /// Step 1: verify the driver's phone via OTP WITHOUT creating an account.
  /// Returns a short-lived registration token used by the final register call.
  Future<({String registrationToken, int expiresIn})> verifyDriverPhone(
    String phoneNumber,
    String code,
  ) async {
    final response = await _api.post(
      ApiEndpoints.driverVerifyPhone,
      data: {'phoneNumber': phoneNumber, 'code': code.trim()},
    );
    final data = response['data'] ?? response;
    final token = data['registrationToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Failed to start driver registration');
    }
    return (
      registrationToken: token,
      expiresIn: (data['expiresIn'] as int?) ?? 1800,
    );
  }

  /// Upload a registration image before the account exists, authorized by the
  /// registration token instead of a session access token.
  Future<String> uploadRegistrationFile(
    File file,
    String registrationToken,
  ) async {
    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
      'registrationToken': registrationToken,
    });
    final response = await _api.post(
      ApiEndpoints.uploadsRegistration,
      data: formData,
    );
    final url = response['url'] ?? response['data']?['url'];
    if (url == null) {
      throw Exception('Failed to upload registration image');
    }
    return url as String;
  }

  /// Step 2 (final): create the driver account AND vehicle atomically. The
  /// account only exists once this succeeds.
  Future<VerifyOtpResult> registerDriver({
    required String registrationToken,
    required String name,
    required String password,
    required String vehicleType,
    required String plateNumber,
    required String model,
    required int seats,
    required String carImageUrl,
    required String insuranceImageUrl,
    String? gender,
    String? photoUrl,
    String? licenseImageUrl,
    String? vehicleLicenseImageUrl,
    DevicePayload? device,
  }) async {
    final body = <String, dynamic>{
      'registrationToken': registrationToken,
      'name': name,
      'password': password,
      'vehicleType': vehicleType,
      'plateNumber': plateNumber,
      'model': model,
      'seats': seats,
      'carImageUrl': carImageUrl,
      'insuranceImageUrl': insuranceImageUrl,
    };
    if (gender != null && gender.isNotEmpty) body['gender'] = gender;
    if (photoUrl != null) body['photoUrl'] = photoUrl;
    if (licenseImageUrl != null) body['licenseImageUrl'] = licenseImageUrl;
    if (vehicleLicenseImageUrl != null) {
      body['vehicleLicenseImageUrl'] = vehicleLicenseImageUrl;
    }
    if (device != null) body['device'] = device.toJson();

    final response = await _api.post(ApiEndpoints.driverRegister, data: body);
    final data = response['data'] ?? response;

    await _tokenStorage.saveTokens(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
    );
    await _tokenStorage.saveUserId(data['user']['_id'] ?? data['user']['id']);
    _currentUser = UserModel.fromJson(data['user']);

    return VerifyOtpResult(
      user: _currentUser,
      accountState: (data['accountState'] as String?) ?? 'active',
      deviceState: (data['deviceState'] as String?) ?? 'new',
      pendingPhoneLinkRequired:
          (data['pendingPhoneLinkRequired'] as bool?) ?? false,
    );
  }

  /// Update the submitted driver details/documents while the account is still
  /// awaiting approval. The backend rejects this once the driver is approved.
  Future<void> updatePendingDriverRegistration(
    Map<String, dynamic> data,
  ) async {
    await _api.patch(ApiEndpoints.driverPendingRegistration, data: data);
    _currentUser = await getProfile();
  }

  // ===== Profile Operations =====
  Future<UserModel> getProfile() async {
    final response = await _api.get(ApiEndpoints.me);
    final data = response['data'] ?? response;
    _currentUser = UserModel.fromJson(data);
    return _currentUser!;
  }

  Future<void> updateRole(String role) async {
    await _api.patch(ApiEndpoints.meRole, data: {'role': role});
    _currentUser = await getProfile(); // Refresh profile
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? gender,
    String? profileImageUrl,
    String? city,
    bool? hidePhoneNumber,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null) {
      data['name'] = name;
    }
    if (gender != null) {
      data['gender'] = gender;
    }
    if (city != null) {
      data['city'] = city;
    }
    if (profileImageUrl != null) {
      data['photoUrl'] = profileImageUrl; // backend expects 'photoUrl'
    }
    if (hidePhoneNumber != null) {
      data['hidePhoneNumber'] = hidePhoneNumber;
    }
    // Note: email update is not supported in UpdateUserDto (read-only after registration)

    await _api.patch(ApiEndpoints.me, data: data);

    // Refresh the profile locally
    _currentUser = await getProfile();
  }

  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _api.patch(ApiEndpoints.meFcmToken, data: {'fcmToken': fcmToken});
      _currentUser = _currentUser?.copyWith(fcmToken: fcmToken);
    } catch (e) {
      if (kDebugMode) print('Failed to update FCM token on server');
    }
  }

  // ===== Profile Linking (verify OTP then link phone for current user) =====
  Future<UserModel?> linkPhone(String phoneNumber, String code) async {
    await _api.patch(
      ApiEndpoints.linkPhone,
      data: {'phoneNumber': phoneNumber, 'code': code.trim()},
    );
    _currentUser = await getProfile();
    return _currentUser;
  }

  // ===== Password Reset =====
  Future<void> forgotPassword(String phoneNumber) async {
    await _api.post(
      ApiEndpoints.forgotPassword,
      data: {'phoneNumber': phoneNumber},
    );
  }

  Future<String> verifyResetOtp(String phoneNumber, String code) async {
    final response = await _api.post(
      ApiEndpoints.verifyResetOtp,
      data: {'phoneNumber': phoneNumber, 'code': code.trim()},
    );

    final data = response['data'] ?? response;
    return data['resetToken'];
  }

  Future<void> resetPassword(String resetToken, String newPassword) async {
    await _api.post(
      ApiEndpoints.resetPassword,
      data: {'resetToken': resetToken, 'newPassword': newPassword},
    );
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _api.post(
      ApiEndpoints.changePassword,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  // ===== Admin & Driver actions =====
  Future<List<UserModel>> getAllUsers({String? role}) async {
    // Requires Admin privileges in new API
    return [];
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _api.get(ApiEndpoints.userById(userId));
      final data = response['data'] ?? response;
      return UserModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  // ===== Logout =====
  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.logout); // Inform server
    } catch (e) {
      // Ignored if token expired etc
    } finally {
      await _tokenStorage.clearAll();
      _currentUser = null;
    }
  }
}
