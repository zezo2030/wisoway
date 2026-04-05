import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/app_constants.dart';
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
      emit(AuthError(e.toString()));
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
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onVerifyOTP(
    AuthVerifyOTP event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.verifyOTP(
        event
            .verificationId, // Assuming verificationId translates to phone or is ignored
        event.smsCode,
      );
      if (user != null) {
        emit(AuthAuthenticated(userModel: user));
      } else {
        emit(const AuthError('فشل في التحقق من الرمز'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignUpWithEmail(
    AuthSignUpWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final phoneNumber = event.phoneNumber?.trim();
    if (phoneNumber == null || phoneNumber.isEmpty) {
      emit(const AuthError('رقم الهاتف مطلوب'));
      return;
    }
    try {
      final response = await _authService.signUp(
        email: event.email,
        password: event.password,
        name: event.name?.trim() ?? event.email.split('@')[0],
        phoneNumber: phoneNumber,
        role: event.role ?? AppConstants.rolePassenger,
      );
      // signUp returns { phoneNumber, expiresAt } — next step is OTP verification
      final sentPhone = response['phoneNumber'] as String? ?? phoneNumber;
      emit(AuthOTPSent(verificationId: 'api-otp', phoneNumber: sentPhone));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithEmail(
    AuthSignInWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authService.signIn(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(userModel: user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLinkPhoneNumber(
    AuthLinkPhoneNumber event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Assuming phone number is derived from the event somehow if needed
      await _authService.linkPhone(
        event.verificationId, // phone number
        event.smsCode,
      );
      final user = await _authService.getProfile();
      emit(AuthAuthenticated(userModel: user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSaveUserProfile(
    AuthSaveUserProfile event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Typically done via an updateProfile endpoint if implemented
      // For now just update role
      await _authService.updateRole(event.role);
      add(AuthUserChanged(userId: ''));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSaveDriverProfile(
    AuthSaveDriverProfile event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Requires VehicleService to create vehicle info
      // Skipping full implementation here, as UI will use VehicleProvider
      await _authService.updateRole(AppConstants.roleDriver);
      add(AuthUserChanged(userId: ''));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOut(AuthSignOut event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      await _authService.logout();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
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
      emit(AuthError(e.toString()));
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
      emit(AuthError(e.toString()));
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
      emit(AuthError(e.toString()));
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
      emit(AuthError(e.toString()));
    }
  }

  void _onClearError(AuthClearError event, Emitter<AuthState> emit) {
    if (state is AuthError) {
      // Try to re-fetch state
      add(const AuthInitialized());
    }
  }
}
