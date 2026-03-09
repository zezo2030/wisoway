enum PaymentMethod { stripe, paymob, manual, communication_fee, cliq_a2a }

enum PaymentStatus { pending, approved, rejected, refunded }

class PaymentModel {
  final String id;
  final String? tripId;
  final String? bookingId;
  final String userId;
  final String paymentType; // 'trip', 'communication_fee'
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;

  // Flattened structure as in MongoDB
  final String? proofImageUrl;
  final String? walletNumber;
  final String? transactionId;
  final String? paymentGatewayRef;
  final String? adminNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.id,
    this.tripId,
    this.bookingId,
    required this.userId,
    required this.paymentType,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    this.proofImageUrl,
    this.walletNumber,
    this.transactionId,
    this.paymentGatewayRef,
    this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  /// يستخرج معرفاً من حقل قد يكون String أو كائن (populate من الباكند).
  static String? _idFromJson(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map) return (v['_id'] ?? v['id'])?.toString();
    return v.toString();
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    PaymentMethod method = PaymentMethod.manual;
    final methodStr = json['method'] as String? ?? 'manual';
    if (methodStr == 'stripe') {
      method = PaymentMethod.stripe;
    } else if (methodStr == 'paymob') {
      method = PaymentMethod.paymob;
    } else if (methodStr == 'communication_fee') {
      method = PaymentMethod.communication_fee;
    } else if (methodStr == 'cliq_a2a') {
      method = PaymentMethod.cliq_a2a;
    }

    PaymentStatus status = PaymentStatus.pending;
    final statusStr = json['status'] as String? ?? 'pending';
    if (statusStr == 'approved') {
      status = PaymentStatus.approved;
    } else if (statusStr == 'rejected') {
      status = PaymentStatus.rejected;
    } else if (statusStr == 'refunded') {
      status = PaymentStatus.refunded;
    }

    final pUserId = _idFromJson(json['userId']) ?? '';

    return PaymentModel(
      id: _idFromJson(json['_id']) ?? _idFromJson(json['id']) ?? '',
      tripId: _idFromJson(json['tripId']),
      bookingId: _idFromJson(json['bookingId']),
      userId: pUserId,
      paymentType: json['paymentType'] ?? 'trip',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'EGP',
      method: method,
      status: status,
      proofImageUrl: json['proofImageUrl'],
      walletNumber: json['walletNumber'],
      transactionId: json['transactionId'],
      paymentGatewayRef: json['paymentGatewayRef'],
      adminNote: json['adminNote'],
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
      'tripId': tripId,
      'bookingId': bookingId,
      'userId': userId,
      'paymentType': paymentType,
      'amount': amount,
      'currency': currency,
      'method': method.name,
      'status': status.name,
      'proofImageUrl': proofImageUrl,
      'walletNumber': walletNumber,
      'transactionId': transactionId,
      'paymentGatewayRef': paymentGatewayRef,
      'adminNote': adminNote,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  PaymentModel copyWith({
    String? id,
    String? tripId,
    String? bookingId,
    String? userId,
    String? paymentType,
    double? amount,
    String? currency,
    PaymentMethod? method,
    PaymentStatus? status,
    String? proofImageUrl,
    String? walletNumber,
    String? transactionId,
    String? paymentGatewayRef,
    String? adminNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      paymentType: paymentType ?? this.paymentType,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      status: status ?? this.status,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      walletNumber: walletNumber ?? this.walletNumber,
      transactionId: transactionId ?? this.transactionId,
      paymentGatewayRef: paymentGatewayRef ?? this.paymentGatewayRef,
      adminNote: adminNote ?? this.adminNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == PaymentStatus.pending;
  bool get isApproved => status == PaymentStatus.approved;
  bool get isRejected => status == PaymentStatus.rejected;

  bool get isOnlinePayment =>
      method == PaymentMethod.stripe ||
      method == PaymentMethod.paymob ||
      method == PaymentMethod.cliq_a2a;
  bool get isManualPayment => method == PaymentMethod.manual;
}
