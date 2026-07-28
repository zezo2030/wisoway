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

  // Trip lifecycle timestamps
  final DateTime? tripStartedAt;
  final DateTime? tripCompletedAt;

  // Presence settlement (012)
  final DateTime? presenceSettledAt;
  final int? billableSeatCount;
  final double? capturedFeeAmount;

  // Distance (km, from PostGIS)
  final double? distanceKm;

  // Stops (up to 5 intermediate waypoints)
  final List<LocationModel> stops;

  // Driver notes visible to passengers
  final String? notes;

  // Recurrence rule that spawned this trip (if any)
  final String? recurrenceRuleId;

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
    this.tripStartedAt,
    this.tripCompletedAt,
    this.presenceSettledAt,
    this.billableSeatCount,
    this.capturedFeeAmount,
    this.distanceKm,
    this.stops = const [],
    this.notes,
    this.recurrenceRuleId,
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
      currency: json['currency'] ?? 'JOD',
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
      tripStartedAt: json['tripStartedAt'] != null
          ? DateTime.tryParse(json['tripStartedAt'].toString())
          : null,
      tripCompletedAt: json['tripCompletedAt'] != null
          ? DateTime.tryParse(json['tripCompletedAt'].toString())
          : null,
      presenceSettledAt: json['presenceSettledAt'] != null
          ? DateTime.tryParse(json['presenceSettledAt'].toString())
          : null,
      billableSeatCount: json['billableSeatCount'] != null
          ? _parseInt(json['billableSeatCount'])
          : null,
      capturedFeeAmount: json['capturedFeeAmount'] != null
          ? _parseDouble(json['capturedFeeAmount'])
          : null,
      distanceKm: json['distanceKm'] != null
          ? _parseDouble(json['distanceKm'])
          : null,
      stops: (json['stops'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((s) => LocationModel.fromStopMap(s))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      recurrenceRuleId: json['recurrenceRuleId']?.toString(),
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
      if (tripStartedAt != null)
        'tripStartedAt': tripStartedAt!.toIso8601String(),
      if (tripCompletedAt != null)
        'tripCompletedAt': tripCompletedAt!.toIso8601String(),
      if (presenceSettledAt != null)
        'presenceSettledAt': presenceSettledAt!.toIso8601String(),
      if (billableSeatCount != null) 'billableSeatCount': billableSeatCount,
      if (capturedFeeAmount != null) 'capturedFeeAmount': capturedFeeAmount,
      if (distanceKm != null) 'distanceKm': distanceKm,
      if (stops.isNotEmpty)
        'stops': stops.asMap().entries
            .map((e) => e.value.toStopMap(order: e.key + 1))
            .toList(),
      if (notes != null) 'notes': notes,
      if (recurrenceRuleId != null) 'recurrenceRuleId': recurrenceRuleId,
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
    DateTime? tripStartedAt,
    DateTime? tripCompletedAt,
    DateTime? presenceSettledAt,
    int? billableSeatCount,
    double? capturedFeeAmount,
    double? distanceKm,
    List<LocationModel>? stops,
    String? notes,
    String? recurrenceRuleId,
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
      tripStartedAt: tripStartedAt ?? this.tripStartedAt,
      tripCompletedAt: tripCompletedAt ?? this.tripCompletedAt,
      presenceSettledAt: presenceSettledAt ?? this.presenceSettledAt,
      billableSeatCount: billableSeatCount ?? this.billableSeatCount,
      capturedFeeAmount: capturedFeeAmount ?? this.capturedFeeAmount,
      distanceKm: distanceKm ?? this.distanceKm,
      stops: stops ?? this.stops,
      notes: notes ?? this.notes,
      recurrenceRuleId: recurrenceRuleId ?? this.recurrenceRuleId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getters
  // Backend uses 'published' as the canonical "active" state; 'active' is
  // kept as a deprecated alias for older rows.
  bool get isActive => status == 'active' || status == 'published';
  bool get isHidden => status == 'hidden';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired';

  bool get hasAvailableSeats => availableSeats > 0;
  bool get isFull => availableSeats == 0;

  bool get isPast => departureTime.isBefore(DateTime.now());
  bool get isUpcoming => departureTime.isAfter(DateTime.now());

  /// Same window as backend `POST /trips/:id/start`.
  static const int driverStartTripEarlyMinutes = 15;
  static const int driverStartTripLateMinutes = 30;

  /// Live GPS sharing must be on from presence window until trip ends.
  static const int driverTrackingEarlyMinutes = 60;

  DateTime get driverStartWindowOpens => departureTime.subtract(
        const Duration(minutes: driverStartTripEarlyMinutes),
      );

  DateTime get driverStartWindowCloses => departureTime.add(
        const Duration(minutes: driverStartTripLateMinutes),
      );

  DateTime get driverTrackingWindowOpens => departureTime.subtract(
        const Duration(minutes: driverTrackingEarlyMinutes),
      );

  bool get isDriverLiveTrackingRequired {
    if (status == 'completed' ||
        status == 'cancelled' ||
        status == 'expired') {
      return false;
    }
    if (status == 'in_progress') return true;
    if (!(status == 'published' ||
        status == 'fully_booked' ||
        status == 'active')) {
      return false;
    }
    return !DateTime.now().isBefore(driverTrackingWindowOpens);
  }

  bool get _canDriverAttemptStartStatus =>
      status == 'published' ||
      status == 'fully_booked' ||
      status == 'active';

  bool get isDriverStartWindowActive {
    if (!_canDriverAttemptStartStatus) return false;
    final n = DateTime.now();
    return !n.isBefore(driverStartWindowOpens) &&
        !n.isAfter(driverStartWindowCloses);
  }

  /// True when the server-side start window has closed and the trip was never started.
  bool get isDriverStartDeadlinePassed {
    if (status == 'in_progress' ||
        status == 'completed' ||
        status == 'cancelled') {
      return false;
    }
    if (!(status == 'published' ||
        status == 'fully_booked' ||
        status == 'active' ||
        status == 'hidden')) {
      return false;
    }
    return DateTime.now().isAfter(driverStartWindowCloses);
  }

  /// Red banner on driver-facing cards: only after the real deadline, not at raw departure instant.
  bool get driverShowsStartDeadlinePassedBanner =>
      isDriverStartDeadlinePassed;

  bool get isLocked => (isActive && isPast) || isExpired;

  bool get canBeBooked => isActive && !isPast && hasAvailableSeats;

  int get bookedSeatsCount => totalSeats - availableSeats;

  double get totalRevenue => bookedSeatsCount * price;

  String get fromDisplayName =>
      from.name.isNotEmpty ? from.name : (from.address ?? 'موقع غير معروف');

  String get toDisplayName =>
      to.name.isNotEmpty ? to.name : (to.address ?? 'موقع غير معروف');

  String get statusDisplayText {
    switch (status) {
      case 'active':
      case 'published':
        return 'نشطة';
      case 'fully_booked':
        return 'مكتملة الحجز';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'draft':
        return 'مسودة';
      case 'hidden':
        return 'مخفية';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      case 'expired':
        return 'منتهية';
      default:
        return status;
    }
  }
}
