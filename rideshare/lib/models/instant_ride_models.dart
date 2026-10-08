// Models for the instant (on-demand) rides feature — "الرحلات المباشرة".

class InstantAvailability {
  final bool isOnline;
  final bool acceptsInstant;
  final double? latitude;
  final double? longitude;

  const InstantAvailability({
    required this.isOnline,
    required this.acceptsInstant,
    this.latitude,
    this.longitude,
  });

  factory InstantAvailability.fromJson(Map<String, dynamic> json) {
    return InstantAvailability(
      isOnline: json['isOnline'] == true,
      acceptsInstant: json['acceptsInstant'] != false,
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
    );
  }
}

/// The fixed, distance-based fare for a route, returned before the passenger
/// submits. [minFare] and [maxFare] equal [recommendedFare] — the passenger
/// can't change the price.
class InstantQuote {
  final double recommendedFare;
  final double minFare;
  final double maxFare;
  final String currency;
  final double? distanceKm;
  final int? durationMinutes;

  const InstantQuote({
    required this.recommendedFare,
    required this.minFare,
    required this.maxFare,
    required this.currency,
    this.distanceKm,
    this.durationMinutes,
  });

  factory InstantQuote.fromJson(Map<String, dynamic> json) {
    double parse(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return InstantQuote(
      recommendedFare: parse(json['recommendedFare']),
      minFare: parse(json['minFare']),
      maxFare: parse(json['maxFare']),
      currency: (json['currency'] ?? 'JOD').toString(),
      distanceKm: _asDouble(json['distanceKm']),
      durationMinutes: _asInt(json['durationMinutes']),
    );
  }
}

/// Matched driver/vehicle details + pickup ETA (inDrive matched state).
class InstantMatch {
  final String? tripId;
  final String? bookingId;
  final String? driverId;
  final String? driverPhotoUrl;
  final String? acceptedFare;
  final String currency;
  final int? pickupEtaSeconds;
  final String? driverName;
  final double? driverRating;
  final int? driverTotalRatings;
  final String? vehicleModel;
  final String? plateNumber;
  final String? carImageUrl;

  const InstantMatch({
    required this.currency,
    this.tripId,
    this.bookingId,
    this.driverId,
    this.driverPhotoUrl,
    this.acceptedFare,
    this.pickupEtaSeconds,
    this.driverName,
    this.driverRating,
    this.driverTotalRatings,
    this.vehicleModel,
    this.plateNumber,
    this.carImageUrl,
  });

  int? get pickupEtaMinutes =>
      pickupEtaSeconds != null ? (pickupEtaSeconds! / 60).ceil() : null;

  factory InstantMatch.fromJson(Map<String, dynamic> json) {
    return InstantMatch(
      tripId: json['tripId']?.toString(),
      acceptedFare: json['acceptedFare']?.toString(),
      currency: (json['currency'] ?? 'JOD').toString(),
      pickupEtaSeconds: _asInt(json['pickupEtaSeconds']),
      driverName: json['driverName']?.toString(),
      driverRating: _asDouble(json['driverRating']),
      driverTotalRatings: _asInt(json['driverTotalRatings']),
      vehicleModel: json['vehicleModel']?.toString(),
      plateNumber: json['plateNumber']?.toString(),
      carImageUrl: json['carImageUrl']?.toString(),
      bookingId: json['bookingId']?.toString(),
      driverId: json['driverId']?.toString(),
      driverPhotoUrl: json['driverPhotoUrl']?.toString(),
    );
  }
}

/// A passenger's instant ride request, as seen by the passenger.
class InstantRequest {
  final String id;
  final String
  status; // searching | offered | accepted | no_drivers | expired | cancelled
  /// no_eligible_drivers | all_declined | ttl_expired | passenger_cancelled.
  /// Null on older backends that don't send it yet.
  final String? terminalReason;
  final bool canRetry;
  final String? retryOfRequestId;
  final String fromName;
  final String toName;
  final String? fareEstimate;
  final String? recommendedFare;
  final String? passengerFare;
  final String? acceptedFare;
  final String currency;
  final int seatCount;
  final String? matchedDriverId;
  final String? tripId;
  final DateTime? expiresAt;
  final InstantMatch? match;

  /// Straight-line route metrics for the searching sheet (newer backends).
  final double? distanceKm;
  final int? durationMinutes;

  /// Equals the fixed fare now that fares aren't negotiable; kept because the
  /// server still sends it.
  final double? maxFare;

  const InstantRequest({
    required this.id,
    required this.status,
    required this.fromName,
    required this.toName,
    required this.currency,
    required this.seatCount,
    this.terminalReason,
    this.canRetry = false,
    this.retryOfRequestId,
    this.fareEstimate,
    this.recommendedFare,
    this.passengerFare,
    this.acceptedFare,
    this.matchedDriverId,
    this.tripId,
    this.expiresAt,
    this.match,
    this.distanceKm,
    this.durationMinutes,
    this.maxFare,
  });

  /// The fixed fare for this request, as a number.
  double? get currentFare =>
      double.tryParse(passengerFare ?? fareEstimate ?? '');

  bool get isSearching => status == 'searching' || status == 'offered';
  bool get isMatched => status == 'accepted';
  bool get isFailed =>
      status == 'no_drivers' || status == 'expired' || status == 'cancelled';

  /// The search ended without a match — `expired` is what the server writes
  /// now, `no_drivers` is what older rows and older servers still send.
  bool get isNoDriverFound => status == 'no_drivers' || status == 'expired';

  factory InstantRequest.fromJson(Map<String, dynamic> json) {
    final from = json['from'] is Map ? json['from'] as Map : const {};
    final to = json['to'] is Map ? json['to'] as Map : const {};
    final status = json['status']?.toString() ?? '';
    return InstantRequest(
      id: json['id']?.toString() ?? '',
      status: status,
      terminalReason: json['terminalReason']?.toString(),
      // Older backends omit the flag; fall back to the terminal status.
      canRetry: json['canRetry'] is bool
          ? json['canRetry'] as bool
          : status == 'no_drivers' || status == 'expired',
      retryOfRequestId: json['retryOfRequestId']?.toString(),
      fromName: (from['name'] ?? json['fromName'] ?? '').toString(),
      toName: (to['name'] ?? json['toName'] ?? '').toString(),
      fareEstimate: json['fareEstimate']?.toString(),
      recommendedFare: json['recommendedFare']?.toString(),
      passengerFare: json['passengerFare']?.toString(),
      acceptedFare: json['acceptedFare']?.toString(),
      currency: (json['currency'] ?? 'JOD').toString(),
      seatCount: _asInt(json['seatCount']) ?? 1,
      matchedDriverId: json['matchedDriverId']?.toString(),
      distanceKm: double.tryParse(json['distanceKm']?.toString() ?? ''),
      durationMinutes: _asInt(json['durationMinutes']),
      maxFare: double.tryParse(json['maxFare']?.toString() ?? ''),
      tripId: json['tripId']?.toString(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      match: json['match'] is Map
          ? InstantMatch.fromJson(
              Map<String, dynamic>.from(json['match'] as Map),
            )
          : null,
    );
  }
}

/// The request summary a driver sees when offered a ride.
class InstantRequestSummary {
  final String id;
  final String fromName;
  final String toName;
  final String? fareEstimate;
  final String? passengerFare;
  final String currency;
  final int seatCount;
  final double? pickupLat;
  final double? pickupLng;
  final String? distanceKm;
  final String? durationMinutes;
  final String? distanceLabel;
  final String? durationLabel;
  final String? earningsLabel;
  final String? tripTypeLabel;
  final String? seatCountLabel;

  /// Street lines under each place name, when the geocoder had them.
  final String? fromAddress;
  final String? toAddress;
  final double? dropoffLat;
  final double? dropoffLng;

  /// The driver's own leg to the pickup — distinct from the trip distance and
  /// the number that decides whether the job is worth taking.
  final String? pickupDistanceKm;
  final String? pickupDistanceLabel;
  final int? pickupEtaMinutes;

  /// Who is asking for the ride.
  final String? passengerName;
  final double? passengerRating;
  final int? passengerTotalRatings;
  final String? passengerPhotoUrl;

  const InstantRequestSummary({
    required this.id,
    required this.fromName,
    required this.toName,
    required this.currency,
    required this.seatCount,
    this.fareEstimate,
    this.passengerFare,
    this.pickupLat,
    this.pickupLng,
    this.distanceKm,
    this.durationMinutes,
    this.distanceLabel,
    this.durationLabel,
    this.earningsLabel,
    this.tripTypeLabel,
    this.seatCountLabel,
    this.fromAddress,
    this.toAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.pickupDistanceKm,
    this.pickupDistanceLabel,
    this.pickupEtaMinutes,
    this.passengerName,
    this.passengerRating,
    this.passengerTotalRatings,
    this.passengerPhotoUrl,
  });

  factory InstantRequestSummary.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'] is Map ? json['pickup'] as Map : const {};
    final dropoff = json['dropoff'] is Map ? json['dropoff'] as Map : const {};
    // Push payloads carry everything as strings, the REST body as numbers —
    // one parser so both shapes land in the same fields.
    double? asDouble(dynamic v) => v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '');
    int? asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    String? asText(dynamic v) {
      final text = v?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }
    final seats =
        _asInt(json['seatCount']) ??
        int.tryParse(json['seatCount']?.toString() ?? '') ??
        1;
    return InstantRequestSummary(
      id: json['id']?.toString() ?? '',
      fromName: (json['fromName'] ?? '').toString(),
      toName: (json['toName'] ?? '').toString(),
      fareEstimate: json['fareEstimate']?.toString(),
      passengerFare: (json['passengerFare'] ?? json['fareEstimate'])
          ?.toString(),
      currency: (json['currency'] ?? 'JOD').toString(),
      seatCount: seats,
      pickupLat: _asDouble(pickup['latitude']),
      pickupLng: _asDouble(pickup['longitude']),
      distanceKm: json['distanceKm']?.toString(),
      durationMinutes: json['durationMinutes']?.toString(),
      distanceLabel: json['distanceLabel']?.toString(),
      durationLabel: json['durationLabel']?.toString(),
      earningsLabel: json['earningsLabel']?.toString(),
      tripTypeLabel: json['tripTypeLabel']?.toString(),
      seatCountLabel: json['seatCountLabel']?.toString(),
      fromAddress: asText(json['fromAddress']),
      toAddress: asText(json['toAddress']),
      dropoffLat: asDouble(dropoff['latitude']),
      dropoffLng: asDouble(dropoff['longitude']),
      pickupDistanceKm: asText(json['pickupDistanceKm']),
      pickupDistanceLabel: asText(json['pickupDistanceLabel']),
      pickupEtaMinutes: asInt(json['pickupEtaMinutes']),
      passengerName: asText(json['passengerName']),
      passengerRating: asDouble(json['passengerRating']),
      passengerTotalRatings: asInt(json['passengerTotalRatings']),
      passengerPhotoUrl: asText(json['passengerPhotoUrl']),
    );
  }
}

/// A pending offer presented to a driver.
class InstantOffer {
  /// Used when the server doesn't say how long the window was.
  static const int defaultWindowSeconds = 40;

  final String id;
  final String requestId;
  final DateTime? expiresAt;
  final InstantRequestSummary? request;

  /// When the offer closes, on this phone's clock — the server deadline
  /// shifted by how far the phone's clock is off from the server's.
  final DateTime? deadline;

  /// The whole response window, so every countdown bar measures against the
  /// same length instead of restarting from whatever was left.
  final int windowSeconds;

  const InstantOffer({
    required this.id,
    required this.requestId,
    this.expiresAt,
    this.request,
    DateTime? deadline,
    this.windowSeconds = defaultWindowSeconds,
  }) : deadline = deadline ?? expiresAt;

  /// Whole seconds left to answer, from the one shared deadline.
  int secondsLeft([DateTime? now]) {
    final d = deadline;
    if (d == null) return windowSeconds;
    final ms = d.difference(now ?? DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  factory InstantOffer.fromJson(Map<String, dynamic> json) {
    final offer = json['offer'] is Map
        ? Map<String, dynamic>.from(json['offer'] as Map)
        : <String, dynamic>{};
    final request = json['request'] is Map
        ? Map<String, dynamic>.from(json['request'] as Map)
        : null;
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    final expiresAt = parse(offer['expiresAt']);
    final offeredAt = parse(offer['offeredAt']);
    final serverNow = parse(offer['serverNow']);

    // Server clock minus ours: a phone running ahead would otherwise see the
    // offer expire early. A one-second margin keeps the card from outliving
    // the server's own timeout.
    DateTime? deadline;
    if (expiresAt != null) {
      final skew = serverNow != null
          ? serverNow.difference(DateTime.now())
          : Duration.zero;
      deadline = expiresAt.subtract(skew).subtract(const Duration(seconds: 1));
    }
    final window = expiresAt != null && offeredAt != null
        ? expiresAt.difference(offeredAt).inSeconds
        : 0;

    return InstantOffer(
      id: offer['id']?.toString() ?? '',
      requestId: offer['requestId']?.toString() ?? '',
      expiresAt: expiresAt,
      deadline: deadline,
      windowSeconds: window > 0 ? window : defaultWindowSeconds,
      request: request != null ? InstantRequestSummary.fromJson(request) : null,
    );
  }
}

/// Anonymous, approximate position of one of our online drivers, shown as a
/// car pin on the passenger's instant-ride map. Carries no identity on
/// purpose — the backend only returns coarse coordinates.
class InstantNearbyDriverPin {
  final double latitude;
  final double longitude;

  const InstantNearbyDriverPin({
    required this.latitude,
    required this.longitude,
  });

  factory InstantNearbyDriverPin.fromJson(Map<String, dynamic> json) {
    return InstantNearbyDriverPin(
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
    );
  }
}

/// A matched instant ride the user is part of, from `GET /instant-rides/active`.
class ActiveInstantRide {
  final String tripId;
  final bool isDriver;
  final String? requestId;

  const ActiveInstantRide({
    required this.tripId,
    required this.isDriver,
    this.requestId,
  });

  static ActiveInstantRide? fromJson(Map<String, dynamic> json) {
    final tripId = json['tripId']?.toString() ?? '';
    if (tripId.isEmpty) return null;
    return ActiveInstantRide(
      tripId: tripId,
      isDriver: json['role'] == 'driver',
      requestId: json['requestId']?.toString(),
    );
  }
}

/// The API sends some numbers as strings (Postgres `decimal` columns such as
/// ratings arrive as "4.50"), so numeric fields accept either shape.
double? _asDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

int? _asInt(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
