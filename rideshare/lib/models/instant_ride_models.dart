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

/// A passenger's instant ride request, as seen by the passenger.
class InstantRequest {
  final String id;
  final String status; // searching | offered | accepted | no_drivers | expired | cancelled
  final String fromName;
  final String toName;
  final String? fareEstimate;
  final String currency;
  final int seatCount;
  final String? matchedDriverId;
  final String? tripId;
  final DateTime? expiresAt;

  const InstantRequest({
    required this.id,
    required this.status,
    required this.fromName,
    required this.toName,
    required this.currency,
    required this.seatCount,
    this.fareEstimate,
    this.matchedDriverId,
    this.tripId,
    this.expiresAt,
  });

  bool get isSearching => status == 'searching' || status == 'offered';
  bool get isMatched => status == 'accepted';
  bool get isFailed =>
      status == 'no_drivers' || status == 'expired' || status == 'cancelled';

  factory InstantRequest.fromJson(Map<String, dynamic> json) {
    final from = json['from'] is Map ? json['from'] as Map : const {};
    final to = json['to'] is Map ? json['to'] as Map : const {};
    return InstantRequest(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      fromName: (from['name'] ?? json['fromName'] ?? '').toString(),
      toName: (to['name'] ?? json['toName'] ?? '').toString(),
      fareEstimate: json['fareEstimate']?.toString(),
      currency: (json['currency'] ?? 'JOD').toString(),
      seatCount: (json['seatCount'] as num?)?.toInt() ?? 1,
      matchedDriverId: json['matchedDriverId']?.toString(),
      tripId: json['tripId']?.toString(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
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
