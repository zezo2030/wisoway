/// Response from `GET /trips/fee-quote` — the driver-side fee preview shown
/// on the create-trip review step, before the trip exists (so
/// `/trips/:id/pricing-preview` can't be used yet).
///
/// `percent` is the backend's configured `driverUnlockPercent`. Read it from
/// here and never hardcode it on the client.
class TripFeeQuote {
  final double amount;
  final double seatPrice;
  final int totalSeats;
  final double percent;
  final String currency;

  const TripFeeQuote({
    required this.amount,
    this.seatPrice = 0,
    this.totalSeats = 0,
    required this.percent,
    required this.currency,
  });

  factory TripFeeQuote.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    int toInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return TripFeeQuote(
      amount: toDouble(json['amount']),
      seatPrice: toDouble(json['seatPrice']),
      totalSeats: toInt(json['totalSeats']),
      percent: toDouble(json['percent']),
      currency: json['currency'] as String? ?? 'JOD',
    );
  }
}
