import 'location_model.dart';
import 'seat_layout_config.dart';
import 'seat_data.dart';
import '../core/utils/backend_url_resolver.dart';

class TripModel {
  final String id;
  final String driverId;
  final String? driverName;
  final String? driverPhone;

  // Location
  final LocationModel from;
  final LocationModel to;

  // Time
  final DateTime departureTime;

  // Pricing
  final double price;
  final String currency;

  // Seats
  final int totalSeats;
  final int availableSeats;

  // Seat Layout
  final SeatLayoutConfig seatLayout;

  // Seats Data
  final List<SeatData> seats;

  // Car Image
  final String? carImageUrl;

  // Status and visibility
  final String
  status; // 'active', 'hidden', 'completed', 'cancelled', 'expired'
  final bool isVisible;

  // Communication Fee Status
  final String communicationFeeStatus; // 'not_paid', 'paid'

  // Distance (km, from PostGIS)
  final double? distanceKm;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  TripModel({
    required this.id,
    required this.driverId,
    this.driverName,
    this.driverPhone,
    required this.from,
    required this.to,
    required this.departureTime,
    required this.price,
    required this.currency,
    required this.totalSeats,
    required this.availableSeats,
    required this.seatLayout,
    required this.seats,
    this.carImageUrl,
    this.status = 'active',
    this.isVisible = true,
    this.communicationFeeStatus = 'not_paid',
    this.distanceKm,
    required this.createdAt,
    required this.updatedAt,
  });

  static double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  factory TripModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> fromMap = json['from'] as Map<String, dynamic>? ?? {};
    if (fromMap.isEmpty && json['fromName'] != null) {
      final fromPoint = json['fromPoint'] as Map<String, dynamic>?;
      final coords = fromPoint?['coordinates'] as List<dynamic>?;
      fromMap = {
        'name': json['fromName'],
        'address': json['fromAddress'],
        'longitude': coords != null && coords.isNotEmpty ? coords[0] : 0.0,
        'latitude': coords != null && coords.length > 1 ? coords[1] : 0.0,
      };
    }

    Map<String, dynamic> toMap = json['to'] as Map<String, dynamic>? ?? {};
    if (toMap.isEmpty && json['toName'] != null) {
      final toPoint = json['toPoint'] as Map<String, dynamic>?;
      final coords = toPoint?['coordinates'] as List<dynamic>?;
      toMap = {
        'name': json['toName'],
        'address': json['toAddress'],
        'longitude': coords != null && coords.isNotEmpty ? coords[0] : 0.0,
        'latitude': coords != null && coords.length > 1 ? coords[1] : 0.0,
      };
    }

    final from = LocationModel.fromMap(fromMap);
    final to = LocationModel.fromMap(toMap);

    final seatLayoutMap = json['seatLayout'] as Map<String, dynamic>? ?? {};
    final seatLayout = SeatLayoutConfig.fromMap(seatLayoutMap);

    final seatsList = json['seats'] as List? ?? [];
    final seats = seatsList
        .whereType<Map<String, dynamic>>()
        .map((e) => SeatData.fromJson(e))
        .toList();

    // Support nested driver object population
    String drvId = json['driverId'] is Map
        ? (json['driverId']['_id'] ?? json['driverId']['id'])?.toString() ?? ''
        : (json['driverId'] ?? '').toString();
    String? drvName = json['driverId'] is Map
        ? json['driverId']['name'] as String?
        : json['driverName'] as String?;
    String? drvPhone = json['driverId'] is Map
        ? json['driverId']['phoneNumber'] as String?
        : json['driverPhone'] as String?;

    return TripModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      driverId: drvId,
      driverName: drvName,
      driverPhone: drvPhone,
      from: from,
      to: to,
      departureTime: json['departureTime'] != null
          ? DateTime.parse(json['departureTime'])
          : DateTime.now(),
      price: _parseDouble(json['price']),
      currency: json['currency'] ?? 'EGP',
      totalSeats: _parseInt(json['totalSeats']),
      availableSeats: _parseInt(json['availableSeats']),
      seatLayout: seatLayout,
      seats: seats,
      carImageUrl: BackendUrlResolver.normalize(
        (json['carImageUrl'] ?? json['carImage'])?.toString(),
      ),
      status: json['status'] ?? 'active',
      isVisible: json['isVisible'] ?? true,
      communicationFeeStatus: json['communicationFeeStatus'] ?? 'not_paid',
      distanceKm: json['distanceKm'] != null
          ? _parseDouble(json['distanceKm'])
          : null,
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
      'driverName': driverName,
      'from': from.toMap(),
      'to': to.toMap(),
      'departureTime': departureTime.toIso8601String(),
      'price': price,
      'currency': currency,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'seatLayout': seatLayout.toMap(),
      'seats': seats.map((e) => e.toJson()).toList(),
      'carImageUrl': carImageUrl,
      'status': status,
      'isVisible': isVisible,
      'communicationFeeStatus': communicationFeeStatus,
      if (distanceKm != null) 'distanceKm': distanceKm,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  TripModel copyWith({
    String? id,
    String? driverId,
    String? driverName,
    LocationModel? from,
    LocationModel? to,
    DateTime? departureTime,
    double? price,
    String? currency,
    int? totalSeats,
    int? availableSeats,
    SeatLayoutConfig? seatLayout,
    List<SeatData>? seats,
    String? carImageUrl,
    String? status,
    bool? isVisible,
    String? communicationFeeStatus,
    double? distanceKm,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      from: from ?? this.from,
      to: to ?? this.to,
      departureTime: departureTime ?? this.departureTime,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      seatLayout: seatLayout ?? this.seatLayout,
      seats: seats ?? this.seats,
      carImageUrl: carImageUrl ?? this.carImageUrl,
      status: status ?? this.status,
      isVisible: isVisible ?? this.isVisible,
      communicationFeeStatus:
          communicationFeeStatus ?? this.communicationFeeStatus,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getters
  bool get isActive => status == 'active';
  bool get isHidden => status == 'hidden';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired';

  bool get hasAvailableSeats => availableSeats > 0;
  bool get isFull => availableSeats == 0;

  bool get isPast => departureTime.isBefore(DateTime.now());
  bool get isUpcoming => departureTime.isAfter(DateTime.now());

  bool get isLocked => (isActive && isPast) || isExpired;

  bool get canBeBooked => isActive && !isPast && hasAvailableSeats;
}
