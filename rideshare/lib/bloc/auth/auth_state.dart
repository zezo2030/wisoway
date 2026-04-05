import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

// Initial State
class AuthInitial extends AuthState {
  const AuthInitial();
}

// Loading State
class AuthLoading extends AuthState {
  const AuthLoading();
}

// Authenticated State
class AuthAuthenticated extends AuthState {
  final UserModel userModel;

  const AuthAuthenticated({required this.userModel});

  @override
  List<Object?> get props => [userModel];
}

// Authenticated but no profile
class AuthAuthenticatedNoProfile extends AuthState {
  // Can store user id if needed, but simple state is mostly enough
  const AuthAuthenticatedNoProfile();

  @override
  List<Object?> get props => [];
}

// Authenticated driver but incomplete profile (missing vehicle info)
class AuthDriverIncompleteProfile extends AuthState {
  final UserModel userModel;

  const AuthDriverIncompleteProfile({required this.userModel});

  @override
  List<Object?> get props => [userModel];
}

// Unauthenticated State
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

// Error State
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// OTP Sent State
class AuthOTPSent extends AuthState {
  final String verificationId;
  final String phoneNumber;

  const AuthOTPSent({required this.verificationId, required this.phoneNumber});

  @override
  List<Object?> get props => [verificationId, phoneNumber];
}

// Profile Saved State
class AuthProfileSaved extends AuthState {
  final UserModel userModel;

  const AuthProfileSaved({required this.userModel});

  @override
  List<Object?> get props => [userModel];
}

// Password Reset OTP Sent State
class AuthPasswordResetSent extends AuthState {
  final String phoneNumber;

  const AuthPasswordResetSent({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

// Password Reset OTP Verified State (has resetToken for setting new password)
class AuthPasswordResetOTPVerified extends AuthState {
  final String resetToken;

  const AuthPasswordResetOTPVerified({required this.resetToken});

  @override
  List<Object?> get props => [resetToken];
}

// Password Reset Success State
class AuthPasswordResetSuccess extends AuthState {
  const AuthPasswordResetSuccess();
}

// Password Changed Success State
class AuthPasswordChangedSuccess extends AuthState {
  const AuthPasswordChangedSuccess();
}
