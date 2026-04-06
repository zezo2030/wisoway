/// Response from GET /trips/:id/pricing-preview
class TripPricingPreviewModel {
  final String tripId;
  final PassengerSeatPricingPreview passenger;
  final DriverUnlockPricingPreview driverUnlock;

  TripPricingPreviewModel({
    required this.tripId,
    required this.passenger,
    required this.driverUnlock,
  });

  factory TripPricingPreviewModel.fromJson(Map<String, dynamic> json) {
    return TripPricingPreviewModel(
      tripId: (json['tripId'] ?? '').toString(),
      passenger: PassengerSeatPricingPreview.fromJson(
        json['passenger'] as Map<String, dynamic>? ?? {},
      ),
      driverUnlock: DriverUnlockPricingPreview.fromJson(
        json['driverUnlock'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class PassengerSeatPricingPreview {
  final double seatPrice;
  final double passengerPlatformPercent;
  final double platformAmount;
  final double driverAmount;
  final String currency;
  final bool requiresOnlinePayment;

  PassengerSeatPricingPreview({
    required this.seatPrice,
    required this.passengerPlatformPercent,
    required this.platformAmount,
    required this.driverAmount,
    required this.currency,
    required this.requiresOnlinePayment,
  });

  factory PassengerSeatPricingPreview.fromJson(Map<String, dynamic> json) {
    double p(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return PassengerSeatPricingPreview(
      seatPrice: p(json['seatPrice']),
      passengerPlatformPercent: p(json['passengerPlatformPercent']),
      platformAmount: p(json['platformAmount']),
      driverAmount: p(json['driverAmount']),
      currency: json['currency']?.toString() ?? 'JOD',
      requiresOnlinePayment: json['requiresOnlinePayment'] == true,
    );
  }
}

class DriverUnlockPricingPreview {
  final double feeAmount;
  final String currency;
  final double driverUnlockPercent;
  final double legacyFlatFeeAmount;
  final double seatPrice;
  final int totalSeats;

  DriverUnlockPricingPreview({
    required this.feeAmount,
    required this.currency,
    required this.driverUnlockPercent,
    required this.legacyFlatFeeAmount,
    required this.seatPrice,
    required this.totalSeats,
  });

  factory DriverUnlockPricingPreview.fromJson(Map<String, dynamic> json) {
    double p(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final ts = json['totalSeats'];
    return DriverUnlockPricingPreview(
      feeAmount: p(json['feeAmount']),
      currency: json['currency']?.toString() ?? 'JOD',
      driverUnlockPercent: p(json['driverUnlockPercent']),
      legacyFlatFeeAmount: p(json['legacyFlatFeeAmount']),
      seatPrice: p(json['seatPrice']),
      totalSeats: ts is int ? ts : int.tryParse('$ts') ?? 0,
    );
  }

  bool get usesPercent => driverUnlockPercent > 0;
}
