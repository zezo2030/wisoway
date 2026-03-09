import 'package:equatable/equatable.dart';
import 'dart:io';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// Initialize Auth
class AuthInitialized extends AuthEvent {
  const AuthInitialized();
}

// Send OTP
class AuthSendOTP extends AuthEvent {
  final String phoneNumber;

  const AuthSendOTP(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

// Verify OTP
class AuthVerifyOTP extends AuthEvent {
  final String verificationId;
  final String smsCode;

  const AuthVerifyOTP({
    required this.verificationId,
    required this.smsCode,
  });

  @override
  List<Object?> get props => [verificationId, smsCode];
}

// Sign Up with Email and Password
class AuthSignUpWithEmail extends AuthEvent {
  final String email;
  final String password;
  final String? name;
  final String? phoneNumber;
  final String? role;

  const AuthSignUpWithEmail({
    required this.email,
    required this.password,
    this.name,
    this.phoneNumber,
    this.role,
  });

  @override
  List<Object?> get props => [email, password, name, phoneNumber, role];
}

// Sign In with Email and Password
class AuthSignInWithEmail extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInWithEmail({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

// Link Phone Number
class AuthLinkPhoneNumber extends AuthEvent {
  final String verificationId;
  final String smsCode;

  const AuthLinkPhoneNumber({
    required this.verificationId,
    required this.smsCode,
  });

  @override
  List<Object?> get props => [verificationId, smsCode];
}

// Save User Profile
class AuthSaveUserProfile extends AuthEvent {
  final String name;
  final String email;
  final String gender;
  final String role;
  final String? phoneNumber;

  const AuthSaveUserProfile({
    required this.name,
    required this.email,
    required this.gender,
    required this.role,
    this.phoneNumber,
  });

  @override
  List<Object?> get props => [name, email, gender, role, phoneNumber];
}

// Save Driver Profile
class AuthSaveDriverProfile extends AuthEvent {
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final File profileImage;
  final String vehicleType;
  final String plateNumber;
  final String model;
  final int seats;
  final File driverLicenseImage;
  final File vehicleLicenseImage;
  final String? email;
  final String? gender;

  const AuthSaveDriverProfile({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.profileImage,
    required this.vehicleType,
    required this.plateNumber,
    required this.model,
    required this.seats,
    required this.driverLicenseImage,
    required this.vehicleLicenseImage,
    this.email,
    this.gender,
  });

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        phoneNumber,
        profileImage,
        vehicleType,
        plateNumber,
        model,
        seats,
        driverLicenseImage,
        vehicleLicenseImage,
        email,
        gender,
      ];
}

// Sign Out
class AuthSignOut extends AuthEvent {
  const AuthSignOut();
}

// Clear Error
class AuthClearError extends AuthEvent {
  const AuthClearError();
}

// User Changed (from auth state listener)
class AuthUserChanged extends AuthEvent {
  final String userId;

  const AuthUserChanged({required this.userId});

  @override
  List<Object?> get props => [userId];
}

