/// Response from GET /wallet/me (Postgres wallet_accounts).
class WalletAccountModel {
  final String? accountId;
  final String accountType;
  final String currency;
  final double balance;
  final bool isActive;

  WalletAccountModel({
    this.accountId,
    required this.accountType,
    required this.currency,
    required this.balance,
    required this.isActive,
  });

  factory WalletAccountModel.fromJson(Map<String, dynamic> json) {
    return WalletAccountModel(
      accountId: json['accountId'] as String?,
      accountType: json['accountType'] as String? ?? 'rider',
      currency: json['currency'] as String? ?? 'EGP',
      balance: (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : double.tryParse('${json['balance']}') ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
