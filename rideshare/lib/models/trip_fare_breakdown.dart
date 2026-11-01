/// How an instant ride's metered fare was reached, as the server priced it
/// when the ride ended (InstantMeterService). Amounts are in [currency].
class TripFareBreakdown {
  final String currency;

  /// Driven, from the tracked path — not the route planned at ordering.
  final double distanceKm;
  final int durationMin;
  final int waitingMin;
  final int freeWaitMin;
  final double base;
  final double distanceCharge;
  final double timeCharge;
  final double waitingCharge;

  /// The parts came to less than the tariff's floor, so [minimum] was charged.
  final bool minimumApplied;
  final double minimum;

  /// Added to reach the tariff's rounding step.
  final double rounding;
  final double total;

  const TripFareBreakdown({
    required this.currency,
    required this.distanceKm,
    required this.durationMin,
    required this.waitingMin,
    required this.freeWaitMin,
    required this.base,
    required this.distanceCharge,
    required this.timeCharge,
    required this.waitingCharge,
    required this.minimumApplied,
    required this.minimum,
    required this.rounding,
    required this.total,
  });

  static TripFareBreakdown? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    double d(String key) => (raw[key] as num?)?.toDouble() ?? 0;
    int i(String key) => (raw[key] as num?)?.round() ?? 0;
    return TripFareBreakdown(
      currency: raw['currency']?.toString() ?? '',
      distanceKm: d('distanceKm'),
      durationMin: i('durationMin'),
      waitingMin: i('waitingMin'),
      freeWaitMin: i('freeWaitMin'),
      base: d('base'),
      distanceCharge: d('distanceCharge'),
      timeCharge: d('timeCharge'),
      waitingCharge: d('waitingCharge'),
      minimumApplied: raw['minimumApplied'] == true,
      minimum: d('minimum'),
      rounding: d('rounding'),
      total: d('total'),
    );
  }

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'distanceKm': distanceKm,
    'durationMin': durationMin,
    'waitingMin': waitingMin,
    'freeWaitMin': freeWaitMin,
    'base': base,
    'distanceCharge': distanceCharge,
    'timeCharge': timeCharge,
    'waitingCharge': waitingCharge,
    'minimumApplied': minimumApplied,
    'minimum': minimum,
    'rounding': rounding,
    'total': total,
  };
}
