import 'package:flutter/foundation.dart';
import 'dart:io';
import '../core/services/auth_service.dart';
import '../core/services/device_fingerprint_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/vehicle_service.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DeviceFingerprintService _deviceService = DeviceFingerprintService();
  final StorageService _storageService = StorageService();
  final VehicleService _vehicleService = VehicleService();

  UserModel? _userModel;

  /// Loading state for user-triggered actions (sign in, send OTP, etc.)
  bool _isLoading = false;

  /// true only during initial app bootstrap auth check.
  bool _isInitializing = true;
  String? _errorMessage;

  /// Backend safety signals from the last verifyOTP call.
  String _accountState = 'active'; // 'active' | 'restricted' | 'banned'
  String _deviceState = 'new'; // 'trusted' | 'new' | 'revoked'
  bool _pendingPhoneLinkRequired = false;

  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _userModel != null;
  bool get hasProfile => _userModel != null;
  String get accountState => _accountState;
  String get deviceState => _deviceState;
  bool get pendingPhoneLinkRequired => _pendingPhoneLinkRequired;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _setInitializing(true);
    _setLoading(true);
    try {
      _userModel = await _authService.checkAuthState();
    } catch (e) {
      _userModel = null;
    } finally {
      _setLoading(false);
      _setInitializing(false);
    }
  }

  Future<void> loadUserProfile() async {
    try {
      _setLoading(true);
      _userModel = await _authService.getProfile();
      _setError(null);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendOTP(String phoneNumber) async {
    try {
      _setLoading(true);
      _setError(null);
      await _authService.sendOTP(phoneNumber);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> verifyOTP({
    required String phoneNumber,
    required String smsCode,
    String? name,
    String? gender,
    String? role,
    String? password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Build the device block, including FCM token if available.
      String? fcmToken;
      try {
        await PushNotificationService.initialize();
        fcmToken = await PushNotificationService.getToken();
      } catch (_) {
        // FCM is optional — never block auth if push isn't available.
      }

      final devicePayload = await _deviceService.buildPayload(
        fcmToken: fcmToken,
      );

      final result = await _authService.verifyOTP(
        phoneNumber,
        smsCode,
        device: devicePayload,
        name: name,
        gender: gender,
        role: role,
        password: password,
      );

      _userModel = result.user;
      _accountState = result.accountState;
      _deviceState = result.deviceState;
      _pendingPhoneLinkRequired = result.pendingPhoneLinkRequired;

      // Register push token after successful login if FCM was available.
      if (_userModel != null) {
        await _registerDeviceToken(existingToken: fcmToken);
      }
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  /// Link phone to current user (after OTP verification). Requires user to be logged in.
  Future<void> linkPhone({
    required String phoneNumber,
    required String smsCode,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      _userModel = await _authService.linkPhone(phoneNumber, smsCode);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> signInWithPhoneAndPassword({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      _userModel = await _authService.signIn(
        phoneNumber: phoneNumber,
        password: password,
      );
      await _registerDeviceToken();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> forgotPassword(String phoneNumber) async {
    try {
      _setLoading(true);
      _setError(null);
      await _authService.forgotPassword(phoneNumber);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<String> verifyResetOtp(String phoneNumber, String code) async {
    try {
      _setLoading(true);
      _setError(null);
      final resetToken = await _authService.verifyResetOtp(phoneNumber, code);
      _setLoading(false);
      return resetToken;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> resetPassword(String resetToken, String newPassword) async {
    try {
      _setLoading(true);
      _setError(null);
      await _authService.resetPassword(resetToken, newPassword);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      _setLoading(true);
      _setError(null);
      await _authService.changePassword(currentPassword, newPassword);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> saveUserProfile({
    required String name,
    required String email,
    String? phoneNumber,
    String? gender,
    String? role,
    File? profileImage,
    bool? hidePhoneNumber,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      String? profileImageUrl;
      if (profileImage != null && _userModel != null) {
        profileImageUrl = await _storageService.uploadProfilePicture(
          imageFile: profileImage,
          userId: _userModel!.id,
        );
      }

      await _authService.updateProfile(
        name: name,
        email: email,
        gender: gender,
        profileImageUrl: profileImageUrl,
        hidePhoneNumber: hidePhoneNumber,
      );

      // Update role explicitly if not passenger yet or if role is specifically provided
      final targetRole = role ?? AppConstants.rolePassenger;
      if (_userModel?.role != targetRole &&
          _userModel?.role != AppConstants.roleAdmin) {
        await _authService.updateRole(targetRole);
      } else {
        await loadUserProfile();
      }

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> saveDriverProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required File profileImage,
    required String vehicleType,
    required String plateNumber,
    required String model,
    required int seats,
    required File driverLicenseImage,
    required File vehicleLicenseImage,
    required File carImage,
    String? email,
    String? gender,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      if (_userModel == null) throw Exception('المستخدم غير مسجل دخول');

      // 1. Upload Profile Image
      final profileImageUrl = await _storageService.uploadProfilePicture(
        imageFile: profileImage,
        userId: _userModel!.id,
      );

      // 2. Update user profile
      await _authService.updateProfile(
        name: '$firstName $lastName'.trim(),
        email: email,
        gender: gender,
        profileImageUrl: profileImageUrl,
      );

      // 3. Update role to Driver
      await _authService.updateRole(AppConstants.roleDriver);

      // 4. Create Vehicle (VehicleService internally uploads the car photo plus
      //    the vehicle and driver license images).
      await _vehicleService.addVehicle(
        driverId: _userModel!.id,
        vehicleType: vehicleType,
        plateNumber: plateNumber,
        modelName: model,
        seats: seats,
        licenseImage: driverLicenseImage,
        vehicleLicenseImage: vehicleLicenseImage,
        carImage: carImage,
      );

      await loadUserProfile(); // Refresh user details

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> updateRole(String role) async {
    try {
      _setLoading(true);
      await _authService.updateRole(role);
      await loadUserProfile();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      _setError(null);
      await _deregisterDeviceToken();
      await _authService.logout();
      _userModel = null;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _setInitializing(bool value) {
    _isInitializing = value;
    notifyListeners();
  }

  void clearError() {
    _setError(null);
  }

  Future<void> _registerDeviceToken({String? existingToken}) async {
    try {
      await PushNotificationService.initialize();
      final token = existingToken ?? await PushNotificationService.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

      await PushNotificationService.registerDevice(
        token: token,
        platform: platform,
      );

      await _authService.updateFcmToken(token);

      await PushNotificationService.onTokenRefresh((newToken) async {
        await PushNotificationService.registerDevice(
          token: newToken,
          platform: platform,
        );
        await _authService.updateFcmToken(newToken);
      });
    } catch (_) {
      // Push registration should never block auth.
    }
  }

  Future<void> _deregisterDeviceToken() async {
    try {
      final token = await PushNotificationService.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await PushNotificationService.deregisterDevice(token);
    } catch (_) {
      // Push deregistration should never block logout.
    }
  }
}
