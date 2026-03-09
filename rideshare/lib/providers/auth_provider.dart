import 'package:flutter/foundation.dart';
import 'dart:io';
import '../core/services/auth_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/vehicle_service.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final VehicleService _vehicleService = VehicleService();

  UserModel? _userModel;
  /// Loading state for user-triggered actions (sign in, send OTP, etc.)
  bool _isLoading = false;
  /// true only during initial app bootstrap auth check.
  bool _isInitializing = true;
  String? _errorMessage;

  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _userModel != null;
  bool get hasProfile => _userModel != null;

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
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      _userModel = await _authService.verifyOTP(phoneNumber, smsCode);
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

  Future<Map<String, dynamic>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    String role = 'passenger',
    String? gender,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final response = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phoneNumber: phoneNumber,
        role: role,
        gender: gender,
      );

      _setLoading(false);
      return response;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      _userModel = await _authService.signIn(email: email, password: password);
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

      // 4. Create Vehicle (VehicleService internal uploads the vehicle and driver license images)
      await _vehicleService.addVehicle(
        driverId: _userModel!.id,
        vehicleType: vehicleType,
        plateNumber: plateNumber,
        modelName: model,
        seats: seats,
        licenseImage: driverLicenseImage,
        vehicleLicenseImage: vehicleLicenseImage,
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
}
