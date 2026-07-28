import 'trip_model.dart';
import 'user_model.dart';

/// A single seat within a multi-seat booking (mirrors BookingSeatEntity).
class BookingSeatModel {
  final String id;
  final String bookingId;
  final String seatNumber;
  final String displayName;
  final String gender;
  final bool isMainBooker;
  final DateTime? markedAbsentAt;
  final DateTime? passengerSelfConfirmedAt;
  final String? passengerDeclaredStatus;
  final bool? billableOverride;
  final DateTime createdAt;

  const BookingSeatModel({
    required this.id,
    required this.bookingId,
    required this.seatNumber,
    required this.displayName,
    required this.gender,
    required this.isMainBooker,
    this.markedAbsentAt,
    this.passengerSelfConfirmedAt,
    this.passengerDeclaredStatus,
    this.billableOverride,
    required this.createdAt,
  });

  /// Passenger confirmed presence (or seat remains billable by default).
  bool get isPresenceConfirmed {
    if (passengerSelfConfirmedAt != null && billableOverride != false) {
      return true;
    }
    if (passengerDeclaredStatus == 'in_vehicle' && billableOverride != false) {
      return true;
    }
    if (markedAbsentAt != null || billableOverride == false) return false;
    if (billableOverride == true) return true;
    return false;
  }

  factory BookingSeatModel.fromJson(Map<String, dynamic> json) {
    return BookingSeatModel(
      id: json['id']?.toString() ?? '',
      bookingId: json['bookingId']?.toString() ?? '',
      seatNumber: json['seatNumber']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      isMainBooker: json['isMainBooker'] ?? false,
      markedAbsentAt: BookingModel._dateOrNull(json['markedAbsentAt']),
      passengerSelfConfirmedAt:
          BookingModel._dateOrNull(json['passengerSelfConfirmedAt']),
      passengerDeclaredStatus: json['passengerDeclaredStatus']?.toString(),
      billableOverride: json['billableOverride'] as bool?,
      createdAt: BookingModel._dateOrNow(json['createdAt']),
    );
  }
}

class BookingModel {
  final String id;
  final String tripId;
  final String userId;

  // Populated fields from backend (Optional locally)
  final TripModel? tripPopulated;
  final UserModel? userPopulated;

  // Seat Info — legacy v1 (single seat); nullable for v2 bookings
  final String? seatNumber;

  // Multi-seat v2 fields
  final int seatCount;
  final String? totalAmount;
  final DateTime? expiresAt;
  final List<BookingSeatModel> seats;

  // Privacy
  final bool sharePhoneWithDriver;

  // Contact
  final bool hasDriverPaidToContact;

  // Status
  final String status; // 'pending' | 'confirmed' | 'cancelled' | 'rejected' | 'completed' | 'no_show'

  /// Whether chat/call contact is allowed (post-settlement reveal).
  final bool chatEnabled;
  final bool callEnabled;

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
    this.seatNumber,
    this.seatCount = 1,
    this.totalAmount,
    this.expiresAt,
    this.seats = const [],
    this.sharePhoneWithDriver = true,
    this.hasDriverPaidToContact = false,
    this.chatEnabled = false,
    this.callEnabled = false,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
  });

  static String _str(dynamic v) => v == null
      ? ''
      : (v is Map ? (v['_id'] ?? v['id'])?.toString() ?? '' : v.toString());

  static DateTime? _dateOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static DateTime _dateOrNow(dynamic value) {
    return _dateOrNull(value) ?? DateTime.now();
  }

  static int _intOr(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

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

    final seatsJson = json['seats'];
    final List<BookingSeatModel> parsedSeats = seatsJson is List
        ? seatsJson
            .whereType<Map<String, dynamic>>()
            .map(BookingSeatModel.fromJson)
            .toList()
        : [];

    return BookingModel(
      id: _str(json['_id'] ?? json['id']),
      tripId: pTripId,
      userId: pUserId,
      tripPopulated: pTripObj,
      userPopulated: pUserObj,
      seatNumber: json['seatNumber']?.toString(),
      seatCount: _intOr(json['seatCount'], 1),
      totalAmount: json['totalAmount']?.toString(),
      expiresAt: _dateOrNull(json['expiresAt']),
      seats: parsedSeats,
      sharePhoneWithDriver: json['sharePhoneWithDriver'] ?? true,
      hasDriverPaidToContact: json['hasDriverPaidToContact'] ?? false,
      chatEnabled: json['chatEnabled'] ?? false,
      callEnabled: json['callEnabled'] ?? false,
      status: json['status'] ?? 'pending',
      createdAt: _dateOrNow(json['createdAt']),
      updatedAt: _dateOrNow(json['updatedAt']),
      cancelledAt: _dateOrNull(json['cancelledAt']),
      cancelledBy: json['cancelledBy'],
      cancellationReason: json['cancellationReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'tripId': tripId,
      'userId': userId,
      if (seatNumber != null) 'seatNumber': seatNumber,
      'seatCount': seatCount,
      if (totalAmount != null) 'totalAmount': totalAmount,
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
    int? seatCount,
    String? totalAmount,
    DateTime? expiresAt,
    List<BookingSeatModel>? seats,
    bool? sharePhoneWithDriver,
    bool? hasDriverPaidToContact,
    bool? chatEnabled,
    bool? callEnabled,
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
      seatCount: seatCount ?? this.seatCount,
      totalAmount: totalAmount ?? this.totalAmount,
      expiresAt: expiresAt ?? this.expiresAt,
      seats: seats ?? this.seats,
      sharePhoneWithDriver: sharePhoneWithDriver ?? this.sharePhoneWithDriver,
      hasDriverPaidToContact:
          hasDriverPaidToContact ?? this.hasDriverPaidToContact,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      callEnabled: callEnabled ?? this.callEnabled,
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
  bool get isRejected => status == 'rejected';
  bool get isNoShow => status == 'no_show';

  bool get canBeCancelled => isPending || isConfirmed;

  /// Display seat info: prefer seats list (v2), fall back to seatNumber (v1).
  String get seatSummary {
    if (seats.isNotEmpty) {
      return seats.map((s) => s.seatNumber).join(', ');
    }
    return seatNumber ?? '';
  }

  static bool isPastBooking(BookingModel booking, TripModel? trip) {
    if (booking.isCancelled || booking.isCompleted) return true;
    if (trip != null) {
      const ended = {'completed', 'cancelled', 'expired'};
      if (ended.contains(trip.status)) return true;
      if (!trip.departureTime.isAfter(DateTime.now())) return true;
    }
    return false;
  }

  static ({List<BookingModel> upcoming, List<BookingModel> past})
  categorizeBookings(
    List<BookingModel> bookings,
    Map<String, TripModel> tripsMap,
  ) {
    final upcoming = <BookingModel>[];
    final past = <BookingModel>[];
    for (final b in bookings) {
      final trip = tripsMap[b.tripId] ?? b.tripPopulated;
      if (isPastBooking(b, trip)) {
        past.add(b);
      } else {
        upcoming.add(b);
      }
    }
    return (upcoming: upcoming, past: past);
  }

  static Map<String, TripModel> buildTripsMap(
    List<BookingModel> bookings,
    List<TripModel> trips,
  ) {
    final tripIds = bookings.map((b) => b.tripId).toSet();
    final tripsMap = <String, TripModel>{};
    for (var trip in trips) {
      if (tripIds.contains(trip.id)) {
        tripsMap[trip.id] = trip;
      }
    }
    return tripsMap;
  }
}
