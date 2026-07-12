import 'dart:convert';

/// A driver registration that has passed OTP verification but has NOT yet
/// created an account. Persisted in secure storage so an interrupted onboarding
/// (app closed / connection lost) can resume from the "complete profile" step
/// without re-verifying the phone — while the account itself is still only
/// created by the final register call.
class PendingDriverRegistration {
  /// Short-lived token from /auth/driver/verify-phone authorizing the final
  /// register call and the registration image uploads.
  final String registrationToken;
  final int expiresAtEpochMs;

  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String? email;
  final String? gender;
  final String password;

  const PendingDriverRegistration({
    required this.registrationToken,
    required this.expiresAtEpochMs,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.password,
    this.email,
    this.gender,
  });

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= expiresAtEpochMs;

  Map<String, dynamic> toJson() => {
    'registrationToken': registrationToken,
    'expiresAtEpochMs': expiresAtEpochMs,
    'phoneNumber': phoneNumber,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'gender': gender,
    'password': password,
  };

  factory PendingDriverRegistration.fromJson(Map<String, dynamic> json) =>
      PendingDriverRegistration(
        registrationToken: json['registrationToken'] as String,
        expiresAtEpochMs: json['expiresAtEpochMs'] as int,
        phoneNumber: json['phoneNumber'] as String,
        firstName: (json['firstName'] as String?) ?? '',
        lastName: (json['lastName'] as String?) ?? '',
        email: json['email'] as String?,
        gender: json['gender'] as String?,
        password: (json['password'] as String?) ?? '',
      );

  String encode() => jsonEncode(toJson());

  static PendingDriverRegistration? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return PendingDriverRegistration.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }
}
