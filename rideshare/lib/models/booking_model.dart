import 'trip_model.dart';
import 'user_model.dart';

class BookingModel {
  final String id;
  final String tripId;
  final String userId;
  final String bookingGroupId;

  // Populated fields from backend (Optional locally)
  final TripModel? tripPopulated;
  final UserModel? userPopulated;

  // Seat Info
  final String seatNumber; // now String "0-0"
  final double? seatPriceAtBooking;
  final double? platformAmount;
  final double? driverAmount;

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
    required this.bookingGroupId,
    this.tripPopulated,
    this.userPopulated,
    required this.seatNumber,
    this.seatPriceAtBooking,
    this.platformAmount,
    this.driverAmount,
    this.sharePhoneWithDriver = true,
    this.hasDriverPaidToContact = false,
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
  static double? _dbl(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

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
      bookingGroupId: _str(json['bookingGroupId']).isNotEmpty
          ? _str(json['bookingGroupId'])
          : _str(json['_id'] ?? json['id']),
      tripPopulated: pTripObj,
      userPopulated: pUserObj,
      seatNumber: json['seatNumber'].toString(),
      seatPriceAtBooking: _dbl(json['seatPriceAtBooking']),
      platformAmount: _dbl(json['platformAmount']),
      driverAmount: _dbl(json['driverAmount']),
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
      'bookingGroupId': bookingGroupId,
      'seatNumber': seatNumber,
      'seatPriceAtBooking': seatPriceAtBooking,
      'platformAmount': platformAmount,
      'driverAmount': driverAmount,
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
    String? bookingGroupId,
    TripModel? tripPopulated,
    UserModel? userPopulated,
    String? seatNumber,
    double? seatPriceAtBooking,
    double? platformAmount,
    double? driverAmount,
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
      bookingGroupId: bookingGroupId ?? this.bookingGroupId,
      tripPopulated: tripPopulated ?? this.tripPopulated,
      userPopulated: userPopulated ?? this.userPopulated,
      seatNumber: seatNumber ?? this.seatNumber,
      seatPriceAtBooking: seatPriceAtBooking ?? this.seatPriceAtBooking,
      platformAmount: platformAmount ?? this.platformAmount,
      driverAmount: driverAmount ?? this.driverAmount,
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

class BookingGroupModel {
  final String bookingGroupId;
  final String tripId;
  final String userId;
  final TripModel? trip;
  final List<String> seatNumbers;
  final String status;
  final List<BookingModel> bookings;
  final double platformAmountTotal;
  final double driverAmountTotal;
  final double totalAmount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingGroupModel({
    required this.bookingGroupId,
    required this.tripId,
    required this.userId,
    required this.trip,
    required this.seatNumbers,
    required this.status,
    required this.bookings,
    required this.platformAmountTotal,
    required this.driverAmountTotal,
    required this.totalAmount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  factory BookingGroupModel.fromJson(Map<String, dynamic> json) {
    final rawBookings = (json['bookings'] as List?) ?? const [];
    final bookings = rawBookings
        .whereType<Map>()
        .map((b) => BookingModel.fromJson(Map<String, dynamic>.from(b)))
        .toList();
    final totals = (json['totals'] is Map)
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : <String, dynamic>{};
    final tripJson = json['trip'];
    final trip = tripJson is Map<String, dynamic>
        ? TripModel.fromJson(tripJson)
        : null;

    final seatNumbers = (json['seatNumbers'] as List?)
            ?.map((s) => s.toString())
            .toList() ??
        bookings.map((b) => b.seatNumber).toList();

    return BookingGroupModel(
      bookingGroupId:
          (json['bookingGroupId'] ?? json['_id'] ?? json['id']).toString(),
      tripId: (json['tripId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      trip: trip,
      seatNumbers: seatNumbers,
      status: (json['status'] ?? 'pending').toString(),
      bookings: bookings,
      platformAmountTotal:
          double.tryParse((totals['platformAmount'] ?? 0).toString()) ?? 0,
      driverAmountTotal:
          double.tryParse((totals['driverAmount'] ?? 0).toString()) ?? 0,
      totalAmount: double.tryParse((totals['totalAmount'] ?? 0).toString()) ?? 0,
      currency: (totals['currency'] ?? trip?.currency ?? 'JOD').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (bookings.isNotEmpty ? bookings.last.createdAt : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : (bookings.isNotEmpty ? bookings.first.updatedAt : DateTime.now()),
    );
  }
}
