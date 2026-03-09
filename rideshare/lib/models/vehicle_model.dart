class VehicleModel {
  final String id;
  final String driverId; // User ID of the driver
  final String vehicleType; // 'sedan', 'suv', 'van', 'truck', etc.
  final String plateNumber;
  final String model;
  final int seats;
  final String? licenseImageUrl; // Driver's license image
  final String? vehicleLicenseImageUrl; // Vehicle license image
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleModel({
    required this.id,
    required this.driverId,
    required this.vehicleType,
    required this.plateNumber,
    required this.model,
    required this.seats,
    this.licenseImageUrl,
    this.vehicleLicenseImageUrl,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert from JSON (REST API)
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['_id'] ?? json['id'] ?? '',
      driverId: json['driverId'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      model: json['model'] ?? '',
      seats: json['seats'] ?? 4,
      licenseImageUrl: json['licenseImageUrl'],
      vehicleLicenseImageUrl: json['vehicleLicenseImageUrl'],
      isVerified: json['isVerified'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'driverId': driverId,
      'vehicleType': vehicleType,
      'plateNumber': plateNumber,
      'model': model,
      'seats': seats,
      'licenseImageUrl': licenseImageUrl,
      'vehicleLicenseImageUrl': vehicleLicenseImageUrl,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Convert to Map (for local use)
  Map<String, dynamic> toMap() => toJson();

  // Create a copy with updated fields
  VehicleModel copyWith({
    String? id,
    String? driverId,
    String? vehicleType,
    String? plateNumber,
    String? model,
    int? seats,
    String? licenseImageUrl,
    String? vehicleLicenseImageUrl,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      vehicleType: vehicleType ?? this.vehicleType,
      plateNumber: plateNumber ?? this.plateNumber,
      model: model ?? this.model,
      seats: seats ?? this.seats,
      licenseImageUrl: licenseImageUrl ?? this.licenseImageUrl,
      vehicleLicenseImageUrl:
          vehicleLicenseImageUrl ?? this.vehicleLicenseImageUrl,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
