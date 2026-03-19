import 'trip_model.dart';
import 'user_model.dart';

class BookingModel {
  final String id;
  final String tripId;
  final String userId;

  // Populated fields from backend (Optional locally)
  final TripModel? tripPopulated;
  final UserModel? userPopulated;

  // Seat Info
  final String seatNumber; // now String "0-0"

  // Privacy
  final bool sharePhoneWithDriver;

  // Contact
  final bool hasDriverPaidToContact;

  // Status
  final String status; // 'pending' | 'confirmed' | 'cancelled' | 'completed'

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy; // 'passenger' | 'driver' | 'system'
  final String? cancellationReason;

  BookingModel({
    required this.id,
    required this.tripId,
    required this.userId,
    this.tripPopulated,
    this.userPopulated,
    required this.seatNumber,
    this.sharePhoneWithDriver = true,
    this.hasDriverPaidToContact = false,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
  });

  static String _str(dynamic v) =>
      v == null ? '' : (v is Map ? (v['_id'] ?? v['id'])?.toString() ?? '' : v.toString());

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // TypeORM returns relation as 'trip', Mongoose may use 'tripId' when populated
    final tripJson = json['trip'] ?? json['tripId'];
    String pTripId = '';
    TripModel? pTripObj;
    if (tripJson is Map) {
      pTripId = _str(tripJson);
      pTripObj = TripModel.fromJson(tripJson as Map<String, dynamic>);
    } else {
      pTripId = _str(json['tripId']);
    }

    // TypeORM returns relation as 'user', Mongoose may use 'userId' when populated
    final userJson = json['user'] ?? json['userId'];
    String pUserId = '';
    UserModel? pUserObj;
    if (userJson is Map) {
      pUserId = _str(userJson);
      pUserObj = UserModel.fromJson(userJson as Map<String, dynamic>);
    } else {
      pUserId = _str(json['userId']);
    }

    return BookingModel(
      id: _str(json['_id'] ?? json['id']),
      tripId: pTripId,
      userId: pUserId,
      tripPopulated: pTripObj,
      userPopulated: pUserObj,
      seatNumber: json['seatNumber'].toString(),
      sharePhoneWithDriver: json['sharePhoneWithDriver'] ?? true,
      hasDriverPaidToContact: json['hasDriverPaidToContact'] ?? false,
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      cancelledBy: json['cancelledBy'],
      cancellationReason: json['cancellationReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'tripId': tripId,
      'userId': userId,
      'seatNumber': seatNumber,
      'sharePhoneWithDriver': sharePhoneWithDriver,
      'hasDriverPaidToContact': hasDriverPaidToContact,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelledBy': cancelledBy,
      'cancellationReason': cancellationReason,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  BookingModel copyWith({
    String? id,
    String? tripId,
    String? userId,
    TripModel? tripPopulated,
    UserModel? userPopulated,
    String? seatNumber,
    bool? sharePhoneWithDriver,
    bool? hasDriverPaidToContact,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? cancellationReason,
  }) {
    return BookingModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      tripPopulated: tripPopulated ?? this.tripPopulated,
      userPopulated: userPopulated ?? this.userPopulated,
      seatNumber: seatNumber ?? this.seatNumber,
      sharePhoneWithDriver: sharePhoneWithDriver ?? this.sharePhoneWithDriver,
      hasDriverPaidToContact:
          hasDriverPaidToContact ?? this.hasDriverPaidToContact,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }

  // Helper getters
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  bool get canBeCancelled => isPending || isConfirmed;
}
