/// Response from GET /wallet/me (Postgres wallet_accounts).
class WalletAccountModel {
  final String? accountId;
  final String accountType;
  final String currency;
  final double balance;
  final bool isActive;
  final double minimumTopup;
  final double minimumRetainedBalance;
  final double withdrawableBalance;
  final double reservedBalance;
  final bool rechargeRequired;
  final String? exchangeRateProvider;

  WalletAccountModel({
    this.accountId,
    required this.accountType,
    required this.currency,
    required this.balance,
    required this.isActive,
    this.minimumTopup = 0,
    this.minimumRetainedBalance = 0,
    this.withdrawableBalance = 0,
    this.reservedBalance = 0,
    this.rechargeRequired = false,
    this.exchangeRateProvider,
  });

  factory WalletAccountModel.fromJson(Map<String, dynamic> json) {
    return WalletAccountModel(
      accountId: json['accountId'] as String?,
      accountType: json['accountType'] as String? ?? 'rider',
      currency: json['currency'] as String? ?? 'JOD',
      balance: (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : double.tryParse('${json['balance']}') ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      minimumTopup: double.tryParse('${json['minimumTopup']}') ?? 0,
      minimumRetainedBalance:
          double.tryParse('${json['minimumRetainedBalance']}') ?? 0,
      withdrawableBalance:
          double.tryParse('${json['withdrawableBalance']}') ?? 0,
      reservedBalance: double.tryParse('${json['reservedBalance']}') ?? 0,
      rechargeRequired: json['rechargeRequired'] == true,
      exchangeRateProvider: json['exchangeRateProvider'] as String?,
    );
  }
}
