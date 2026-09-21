/// Response from `GET /trips/price-suggestion` — the per-seat price band shown
/// to a driver on step 2 of the create-trip wizard.
///
/// [currency] is derived by the backend from the departure point's country and
/// is the currency the trip will actually be stored in, so the wizard displays
/// it rather than letting the driver pick one.
class TripPriceSuggestion {
  /// Where the band came from: `history` (comparable past trips) or
  /// `distance` (fallback estimate).
  final String basis;
  final String currency;
  final double min;
  final double max;

  const TripPriceSuggestion({
    required this.basis,
    required this.currency,
    required this.min,
    required this.max,
  });

  bool get hasBand => max > min && min > 0;

  factory TripPriceSuggestion.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    return TripPriceSuggestion(
      basis: json['basis'] as String? ?? 'distance',
      currency: json['currency'] as String? ?? 'JOD',
      min: toDouble(json['min']),
      max: toDouble(json['max']),
    );
  }
}
