/// One rider's fare on a trip and where it stands — `GET /ride-payments/…`.
///
/// Instant rides and shared trips alike: the passenger chose `cash` (handed
/// to the driver, who confirms it) or `cliq` (a CliQ request-to-pay sent to
/// [payerCliqAlias] when the ride ends; the platform then credits the
/// driver's wallet).
class RidePayment {
  final String bookingId;
  final String tripId;
  final String passengerId;
  final String? passengerName;
  final double amount;
  final double? originalAmount;
  final double discountAmount;
  final String? promoCode;
  final String currency;

  /// `cash` or `cliq`.
  final String method;

  /// `pending` · `requested` (CliQ out) · `failed` (CliQ) · `paid` · `disputed`.
  final String status;
  final String? payerCliqAlias;

  const RidePayment({
    required this.bookingId,
    required this.tripId,
    required this.passengerId,
    required this.amount,
    this.originalAmount,
    this.discountAmount = 0,
    this.promoCode,
    required this.currency,
    required this.method,
    required this.status,
    this.passengerName,
    this.payerCliqAlias,
  });

  bool get isCliq => method == 'cliq';
  bool get isWallet => method == 'wallet';
  bool get isPaid => status == 'paid';
  bool get isDisputed => status == 'disputed';
  bool get isCliqRequested => isCliq && status == 'requested';
  bool get isCliqFailed => isCliq && status == 'failed';

  /// Answered one way or the other — the passenger may move on.
  bool get isSettled => isPaid || isDisputed;

  /// A cash fare the driver still has to confirm.
  bool get awaitsDriver => method == 'cash' && status == 'pending';

  factory RidePayment.fromJson(Map<String, dynamic> json) {
    String? text(dynamic v) {
      final t = v?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    return RidePayment(
      bookingId: json['bookingId']?.toString() ?? '',
      tripId: json['tripId']?.toString() ?? '',
      passengerId: json['passengerId']?.toString() ?? '',
      passengerName: text(json['passengerName']),
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      originalAmount: double.tryParse(json['originalAmount']?.toString() ?? ''),
      discountAmount:
          double.tryParse(json['discountAmount']?.toString() ?? '') ?? 0,
      promoCode: text(json['promoCode']),
      currency: text(json['currency']) ?? 'JOD',
      method: text(json['method']) ?? 'cash',
      status: text(json['status']) ?? 'pending',
      payerCliqAlias: text(json['payerCliqAlias']),
    );
  }
}
