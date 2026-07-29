import 'seat_layout_config.dart';

class VehicleModel {
  final String id;
  final String driverId; // User ID of the driver
  final String vehicleType; // 'sedan', 'suv', 'van', 'truck', etc.
  final String plateNumber;
  final String model;
  final int seats;
  final SeatLayoutConfig? seatLayout;
  final String? licenseImageUrl; // Driver's license image
  final String? vehicleLicenseImageUrl; // Vehicle license image
  final String? carImageUrl; // Photo of the car itself
  final String? insuranceImageUrl; // Vehicle insurance document
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
    this.seatLayout,
    this.licenseImageUrl,
    this.vehicleLicenseImageUrl,
    this.carImageUrl,
    this.insuranceImageUrl,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    SeatLayoutConfig? layout;
    final raw = json['seatLayout'];
    if (raw is Map) {
      layout = SeatLayoutConfig.fromMap(Map<String, dynamic>.from(raw));
    }

    return VehicleModel(
      id: json['_id'] ?? json['id'] ?? '',
      driverId: json['driverId'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      model: json['model'] ?? '',
      seats: json['seats'] ?? 4,
      seatLayout: layout,
      licenseImageUrl: json['licenseImageUrl'],
      vehicleLicenseImageUrl: json['vehicleLicenseImageUrl'],
      carImageUrl: json['carImageUrl'],
      insuranceImageUrl: json['insuranceImageUrl'],
      isVerified: json['isVerified'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'driverId': driverId,
      'vehicleType': vehicleType,
      'plateNumber': plateNumber,
      'model': model,
      'seats': seats,
      'seatLayout': seatLayout?.toMap(),
      'licenseImageUrl': licenseImageUrl,
      'vehicleLicenseImageUrl': vehicleLicenseImageUrl,
      'carImageUrl': carImageUrl,
      'insuranceImageUrl': insuranceImageUrl,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  VehicleModel copyWith({
    String? id,
    String? driverId,
    String? vehicleType,
    String? plateNumber,
    String? model,
    int? seats,
    SeatLayoutConfig? seatLayout,
    String? licenseImageUrl,
    String? vehicleLicenseImageUrl,
    String? carImageUrl,
    String? insuranceImageUrl,
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
      seatLayout: seatLayout ?? this.seatLayout,
      licenseImageUrl: licenseImageUrl ?? this.licenseImageUrl,
      vehicleLicenseImageUrl:
          vehicleLicenseImageUrl ?? this.vehicleLicenseImageUrl,
      carImageUrl: carImageUrl ?? this.carImageUrl,
      insuranceImageUrl: insuranceImageUrl ?? this.insuranceImageUrl,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
