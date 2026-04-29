import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/api/api_client.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = AuthService();

  AuthBloc() : super(const AuthInitial()) {
    on<AuthInitialized>(_onAuthInitialized);
    on<AuthUserChanged>(_onAuthUserChanged);
    on<AuthSendOTP>(_onSendOTP);
    on<AuthVerifyOTP>(_onVerifyOTP);
    on<AuthSignUpWithEmail>(_onSignUpWithEmail);
    on<AuthSignInWithEmail>(_onSignInWithEmail);
    on<AuthLinkPhoneNumber>(_onLinkPhoneNumber);
    on<AuthSaveUserProfile>(_onSaveUserProfile);
    on<AuthSaveDriverProfile>(_onSaveDriverProfile);
    on<AuthSignOut>(_onSignOut);
    on<AuthForgotPassword>(_onForgotPassword);
    on<AuthVerifyResetOTP>(_onVerifyResetOTP);
    on<AuthResetPassword>(_onResetPassword);
    on<AuthChangePassword>(_onChangePassword);
    on<AuthClearError>(_onClearError);

    add(const AuthInitialized());
  }

  Future<void> _onAuthInitialized(
    AuthInitialized event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.checkAuthState();
      if (user != null) {
        emit(AuthAuthenticated(userModel: user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthUserChanged(
    AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final userModel = await _authService.getProfile();
      emit(AuthAuthenticated(userModel: userModel));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onSendOTP(AuthSendOTP event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await _authService.sendOTP(event.phoneNumber);
      emit(
        AuthOTPSent(verificationId: 'api-otp', phoneNumber: event.phoneNumber),
      );
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onVerifyOTP(
    AuthVerifyOTP event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _authService.verifyOTP(
        event.verificationId,
        event.smsCode,
      );
      if (result.user != null) {
        emit(AuthAuthenticated(userModel: result.user!));

        await _registerDeviceToken();
      } else {
        emit(const AuthError('فشل في التحقق من الرمز'));
      }
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onSignUpWithEmail(
    AuthSignUpWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      const AuthError(
        'تم إلغاء التسجيل بالبريد الإلكتروني. استخدم رقم الهاتف ورمز التحقق OTP.',
      ),
    );
  }

  Future<void> _onSignInWithEmail(
    AuthSignInWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      const AuthError(
        'تم إلغاء تسجيل الدخول بالبريد الإلكتروني. استخدم رقم الهاتف ورمز التحقق OTP.',
      ),
    );
  }

  Future<void> _onLinkPhoneNumber(
    AuthLinkPhoneNumber event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.linkPhone(
        event.verificationId,
        event.smsCode,
      );
      final user = await _authService.getProfile();
      emit(AuthAuthenticated(userModel: user));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onSaveUserProfile(
    AuthSaveUserProfile event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.updateRole(event.role);
      add(AuthUserChanged(userId: ''));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onSaveDriverProfile(
    AuthSaveDriverProfile event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.updateRole(AppConstants.roleDriver);
      add(AuthUserChanged(userId: ''));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onSignOut(AuthSignOut event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await _deregisterDeviceToken();
      await _authService.logout();
      emit(const AuthUnauthenticated());
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _registerDeviceToken() async {
    try {
      await PushNotificationService.initialize();
      final token = await PushNotificationService.getToken();
      if (token != null) {
        final platform = defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android';
        await PushNotificationService.registerDevice(
          token: token,
          platform: platform,
        );

        PushNotificationService.onTokenRefresh((newToken) async {
          await PushNotificationService.registerDevice(
            token: newToken,
            platform: platform,
          );
        });
      }
    } catch (e) {
      // Silently fail - token registration should not block auth
    }
  }

  Future<void> _deregisterDeviceToken() async {
    try {
      final token = await PushNotificationService.getToken();
      if (token != null) {
        await PushNotificationService.deregisterDevice(token);
      }
    } catch (e) {
      // Silently fail - token deregistration should not block logout
    }
  }

  Future<void> _onForgotPassword(
    AuthForgotPassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.forgotPassword(event.phoneNumber);
      emit(AuthPasswordResetSent(phoneNumber: event.phoneNumber));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onVerifyResetOTP(
    AuthVerifyResetOTP event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final resetToken = await _authService.verifyResetOtp(
        event.phoneNumber,
        event.code,
      );
      emit(AuthPasswordResetOTPVerified(resetToken: resetToken));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onResetPassword(
    AuthResetPassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.resetPassword(
        event.resetToken,
        event.newPassword,
      );
      emit(const AuthPasswordResetSuccess());
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onChangePassword(
    AuthChangePassword event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.changePassword(
        event.currentPassword,
        event.newPassword,
      );
      emit(const AuthPasswordChangedSuccess());
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(AuthError(failure.messageKey, failure: failure));
    }
  }

  void _onClearError(AuthClearError event, Emitter<AuthState> emit) {
    if (state is AuthError) {
      // Try to re-fetch state
      add(const AuthInitialized());
    }
  }
}
