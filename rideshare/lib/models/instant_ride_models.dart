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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// Distance-based fare recommendation returned before the passenger submits.
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
      distanceKm: double.tryParse(json['distanceKm']?.toString() ?? ''),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    );
  }
}

/// A driver's counter-offer awaiting the passenger's decision.
class InstantCounterOffer {
  final String id;
  final String? driverName;
  final double? driverRating;
  final int? driverTotalRatings;
  final String? vehicleModel;
  final String? plateNumber;
  final String proposedFare;
  final String currency;
  final DateTime? expiresAt;

  const InstantCounterOffer({
    required this.id,
    required this.proposedFare,
    required this.currency,
    this.driverName,
    this.driverRating,
    this.driverTotalRatings,
    this.vehicleModel,
    this.plateNumber,
    this.expiresAt,
  });

  factory InstantCounterOffer.fromJson(Map<String, dynamic> json) {
    return InstantCounterOffer(
      id: json['id']?.toString() ?? '',
      driverName: json['driverName']?.toString(),
      driverRating: (json['driverRating'] as num?)?.toDouble(),
      driverTotalRatings: (json['driverTotalRatings'] as num?)?.toInt(),
      vehicleModel: json['vehicleModel']?.toString(),
      plateNumber: json['plateNumber']?.toString(),
      proposedFare: json['proposedFare']?.toString() ?? '',
      currency: (json['currency'] ?? 'JOD').toString(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }
}

/// Server-owned "raise your fare" nudge shown while searching.
class InstantNudge {
  final String suggestedFare;
  final String maxFare;
  final String currentFare;
  final String currency;

  const InstantNudge({
    required this.suggestedFare,
    required this.maxFare,
    required this.currentFare,
    required this.currency,
  });

  factory InstantNudge.fromJson(Map<String, dynamic> json) {
    return InstantNudge(
      suggestedFare: json['suggestedFare']?.toString() ?? '',
      maxFare: json['maxFare']?.toString() ?? '',
      currentFare: json['currentFare']?.toString() ?? '',
      currency: (json['currency'] ?? 'JOD').toString(),
    );
  }
}

/// Matched driver/vehicle details + pickup ETA (inDrive matched state).
class InstantMatch {
  final String? tripId;
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
      pickupEtaSeconds: (json['pickupEtaSeconds'] as num?)?.toInt(),
      driverName: json['driverName']?.toString(),
      driverRating: (json['driverRating'] as num?)?.toDouble(),
      driverTotalRatings: (json['driverTotalRatings'] as num?)?.toInt(),
      vehicleModel: json['vehicleModel']?.toString(),
      plateNumber: json['plateNumber']?.toString(),
      carImageUrl: json['carImageUrl']?.toString(),
    );
  }
}

/// A passenger's instant ride request, as seen by the passenger.
class InstantRequest {
  final String id;
  final String status; // searching | offered | accepted | no_drivers | expired | cancelled
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
  final InstantCounterOffer? counterOffer;
  final InstantNudge? nudge;
  final InstantMatch? match;

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
    this.counterOffer,
    this.nudge,
    this.match,
  });

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
      seatCount: (json['seatCount'] as num?)?.toInt() ?? 1,
      matchedDriverId: json['matchedDriverId']?.toString(),
      tripId: json['tripId']?.toString(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      counterOffer: json['counterOffer'] is Map
          ? InstantCounterOffer.fromJson(
              Map<String, dynamic>.from(json['counterOffer'] as Map),
            )
          : null,
      nudge: json['nudge'] is Map
          ? InstantNudge.fromJson(
              Map<String, dynamic>.from(json['nudge'] as Map),
            )
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
  });

  factory InstantRequestSummary.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'] is Map ? json['pickup'] as Map : const {};
    return InstantRequestSummary(
      id: json['id']?.toString() ?? '',
      fromName: (json['fromName'] ?? '').toString(),
      toName: (json['toName'] ?? '').toString(),
      fareEstimate: json['fareEstimate']?.toString(),
      passengerFare:
          (json['passengerFare'] ?? json['fareEstimate'])?.toString(),
      currency: (json['currency'] ?? 'JOD').toString(),
      seatCount: (json['seatCount'] as num?)?.toInt() ?? 1,
      pickupLat: (pickup['latitude'] as num?)?.toDouble(),
      pickupLng: (pickup['longitude'] as num?)?.toDouble(),
    );
  }
}

/// A pending offer presented to a driver.
class InstantOffer {
  final String id;
  final String requestId;
  final DateTime? expiresAt;
  final InstantRequestSummary? request;

  const InstantOffer({
    required this.id,
    required this.requestId,
    this.expiresAt,
    this.request,
  });

  factory InstantOffer.fromJson(Map<String, dynamic> json) {
    final offer = json['offer'] is Map
        ? Map<String, dynamic>.from(json['offer'] as Map)
        : <String, dynamic>{};
    final request = json['request'] is Map
        ? Map<String, dynamic>.from(json['request'] as Map)
        : null;
    return InstantOffer(
      id: offer['id']?.toString() ?? '',
      requestId: offer['requestId']?.toString() ?? '',
      expiresAt: offer['expiresAt'] != null
          ? DateTime.tryParse(offer['expiresAt'].toString())
          : null,
      request: request != null
          ? InstantRequestSummary.fromJson(request)
          : null,
    );
  }
}
