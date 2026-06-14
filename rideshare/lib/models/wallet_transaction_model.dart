/// Ledger row from GET /wallet/transactions.
class WalletTransactionModel {
  final String id;
  final String type;
  final String direction;
  final double amount;
  final String currency;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;

  WalletTransactionModel({
    required this.id,
    required this.type,
    required this.direction,
    required this.amount,
    required this.currency,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedAt;
    final raw = json['createdAt'];
    if (raw is String) {
      parsedAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is int) {
      parsedAt = DateTime.fromMillisecondsSinceEpoch(raw);
    } else {
      parsedAt = DateTime.now();
    }
    return WalletTransactionModel(
      id: '${json['id']}',
      type: json['type'] as String? ?? '',
      direction: json['direction'] as String? ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse('${json['amount']}') ?? 0,
      currency: json['currency'] as String? ?? 'JOD',
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
      createdAt: parsedAt,
    );
  }
}
