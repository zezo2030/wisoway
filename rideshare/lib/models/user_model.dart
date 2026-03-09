import '../core/constants/app_constants.dart';
import '../core/utils/backend_url_resolver.dart';

class UserModel {
  final String id;
  final String phoneNumber;
  final String email;
  final String name;
  final String gender; // 'male' or 'female'
  final String role; // 'passenger', 'driver', or 'admin'
  final bool isPhoneVerified;
  final bool isEmailVerified;
  final bool isDriverApproved;
  final bool isActive;
  final double rating;
  final int totalRatings;
  final String? fcmToken;
  final String? photoUrl; // For social login profile picture
  final String? provider; // 'email', 'phone', 'google', 'facebook'
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.email,
    required this.name,
    required this.gender,
    required this.role,
    this.isPhoneVerified = false,
    this.isEmailVerified = false,
    this.isDriverApproved = false,
    this.isActive = true,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.fcmToken,
    this.photoUrl,
    this.provider,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  // Convert from JSON (REST API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      gender: json['gender']?.toString() ?? AppConstants.genderMale,
      role: json['role']?.toString() ?? AppConstants.rolePassenger,
      isPhoneVerified: json['isPhoneVerified'] == true,
      isEmailVerified: json['isEmailVerified'] == true,
      isDriverApproved: json['isDriverApproved'] == true,
      isActive: json['isActive'] != false,
      rating: double.tryParse((json['rating'] ?? 0).toString()) ?? 0.0,
      totalRatings: int.tryParse((json['totalRatings'] ?? 0).toString()) ?? 0,
      fcmToken: json['fcmToken']?.toString(),
      photoUrl: BackendUrlResolver.normalize(json['photoUrl']?.toString()),
      provider: json['provider']?.toString(),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'phoneNumber': phoneNumber,
      'email': email,
      'name': name,
      'gender': gender,
      'role': role,
      'isPhoneVerified': isPhoneVerified,
      'isEmailVerified': isEmailVerified,
      'isDriverApproved': isDriverApproved,
      'isActive': isActive,
      'rating': rating,
      'totalRatings': totalRatings,
      'fcmToken': fcmToken,
      'photoUrl': photoUrl,
      'provider': provider,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Convert to Map (for local use / backward compatibility)
  Map<String, dynamic> toMap() => toJson();

  // Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? email,
    String? name,
    String? gender,
    String? role,
    bool? isPhoneVerified,
    bool? isEmailVerified,
    bool? isDriverApproved,
    bool? isActive,
    double? rating,
    int? totalRatings,
    String? fcmToken,
    String? photoUrl,
    String? provider,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isDriverApproved: isDriverApproved ?? this.isDriverApproved,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      fcmToken: fcmToken ?? this.fcmToken,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Check if user is driver
  bool get isDriver => role == AppConstants.roleDriver;

  // Check if user is passenger
  bool get isPassenger => role == AppConstants.rolePassenger;

  // Check if user is admin
  bool get isAdmin => role == AppConstants.roleAdmin;

  // Check if user can book trips (passenger or driver - drivers can also book trips)
  bool get canBookTrips => isPassenger || isDriver;

  // Driver approved by admin; only approved drivers can create trips
  bool get isApprovedDriver => isDriver && isDriverApproved;

  // Check if user can create trips (approved driver only)
  bool get canCreateTrips => isApprovedDriver;

  // Check if user is male
  bool get isMale => gender == AppConstants.genderMale;

  // Check if user is female
  bool get isFemale => gender == AppConstants.genderFemale;
}
