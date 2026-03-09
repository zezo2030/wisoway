import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../storage/token_storage.dart';
import '../constants/app_constants.dart';

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

  // ===== Sign Up =====
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    String role = 'passenger',
    String? gender,
  }) async {
    final response = await _api.post(
      ApiEndpoints.register,
      data: {
        'email': email,
        'password': password,
        'name': name,
        'gender': gender ?? AppConstants.genderMale,
        'phoneNumber': phoneNumber,
        'role': role,
      },
    );

    final data = response['data'] ?? response;
    // Don't save tokens - account doesn't exist yet
    // Return phoneNumber and expiresAt for OTP verification
    return {
      'phoneNumber': data['phoneNumber'],
      'expiresAt': data['expiresAt'],
    };
  }

  // ===== Sign In (Email/Password) =====
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
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

  Future<UserModel?> verifyOTP(String phoneNumber, String code) async {
    try {
      final response = await _api.post(
        ApiEndpoints.verifyOtp,
        data: {'phoneNumber': phoneNumber, 'code': code.trim()},
      );

      final data = response['data'] ?? response;

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
        return _currentUser;
      } else {
        // Just linking the phone
        _currentUser = await getProfile();
        return _currentUser;
      }
    } catch (e) {
      throw Exception('كود التحقق غير صحيح أو منتهي الصلاحية');
    }
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
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null) {
      data['name'] = name;
    }
    if (gender != null) {
      data['gender'] = gender;
    }
    if (profileImageUrl != null) {
      data['photoUrl'] = profileImageUrl; // backend expects 'photoUrl'
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
  Future<void> resetPassword(String email) async {
    // Depending on backend implementation, might require a different endpoint
    // Placeholder based on usual NestJS Auth
    throw Exception('Not implemented in API client yet');
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
