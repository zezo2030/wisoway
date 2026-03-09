/// Response from GET /payments/wallet/me
class WalletModel {
  final double balance;
  final String currency;
  final bool hasUsedLifetimeFreeTrip;

  WalletModel({
    required this.balance,
    required this.currency,
    required this.hasUsedLifetimeFreeTrip,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      balance: (json['balance'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'EGP',
      hasUsedLifetimeFreeTrip: json['hasUsedLifetimeFreeTrip'] ?? false,
    );
  }
}
