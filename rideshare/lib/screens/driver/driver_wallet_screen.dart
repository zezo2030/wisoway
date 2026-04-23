import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../core/constants/route_names.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../models/wallet_account_model.dart';
import '../../models/wallet_model.dart';
import '../../models/wallet_transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/empty_state.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  final PaymentService _paymentService = PaymentService();
  WalletModel? _wallet;
  WalletAccountModel? _walletAccount;
  List<WalletTransactionModel> _transactions = [];
  bool _loading = true;
  bool _loadingTransactions = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _paymentService.getWalletMe(),
        _paymentService.getWalletAccountMe(),
      ]);

      if (mounted) {
        setState(() {
          _wallet = results[0] as WalletModel;
          _walletAccount = results[1] as WalletAccountModel;
          _loading = false;
        });
      }

      _loadTransactions();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: T.error(context),
          ),
        );
      }
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loadingTransactions = true);
    try {
      final list = await _paymentService.getWalletLedgerTransactions(limit: 50);
      if (mounted) {
        setState(() {
          _transactions = list;
          _loadingTransactions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTransactions = false);
    }
  }

  Future<void> _openTopUp() async {
    final result = await Navigator.pushNamed(
      context,
      RouteNames.driverWalletTopup,
    );
    if (result == true && mounted) _load();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'topup':
        return 'شحن محفظة';
      case 'trip_payment':
        return 'دفع رحلة';
      case 'trip_debit':
        return 'رسوم رحلة';
      case 'refund':
        return 'استرداد';
      case 'payout':
        return 'سحب أرباح';
      case 'adjustment':
        return 'تعديل رصيد';
      case 'hold':
        return 'حجز مبلغ';
      case 'release_hold':
        return 'إلغاء حجز';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.userModel == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'المحفظة',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(child: Text('يرجى تسجيل الدخول')),
      );
    }

    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        title: Text(
          'المحفظة',
          style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 16),
                    _buildFreeTripCard(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'سجل الحركات',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Semantics(
                          label: 'شحن المحفظة',
                          button: true,
                          child: TextButton.icon(
                            onPressed: _openTopUp,
                            icon: const Icon(
                              IconsaxPlusLinear.add_circle,
                              size: 20,
                            ),
                            label: Text(
                              'شحن المحفظة',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _loadingTransactions
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _transactions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: EmptyState(
                              title: 'لا توجد حركات بعد',
                              icon: IconsaxPlusLinear.wallet,
                              showCircleBackground: false,
                              iconSize: 48,
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) =>
                                _buildTransactionTile(_transactions[i]),
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: Semantics(
        label: 'شحن المحفظة',
        button: true,
        child: FloatingActionButton.extended(
          onPressed: _openTopUp,
          icon: const Icon(IconsaxPlusBold.wallet_add),
          label: Text(
            'شحن',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.warning,
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _walletAccount?.balance ?? 0.0;
    final currency = _walletAccount?.currency ?? 'JOD';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.warning, AppColors.warningLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(IconsaxPlusBold.wallet_3, color: AppColors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'رصيد المحفظة',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${balance.toStringAsFixed(2)} $currency',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTripCard() {
    final used = _wallet?.hasUsedLifetimeFreeTrip ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: used
            ? AppColors.slate200
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: used
              ? AppColors.slate400
              : AppColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            used ? IconsaxPlusLinear.tick_circle : IconsaxPlusBold.gift,
            color: used ? T.onSurfaceVariant(context) : AppColors.success,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              used
                  ? 'تم استخدام الرحلة المجانية'
                  : 'لديك رحلة مجانية واحدة لفتح بيانات الركاب',
              style: AppTextStyles.labelLarge.copyWith(
                color: used ? AppColors.slate700 : AppColors.successDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(WalletTransactionModel tx) {
    final isCredit = tx.direction == 'credit';
    final color = isCredit ? AppColors.success : AppColors.warning;
    final prefix = isCredit ? '+' : '-';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit
                  ? IconsaxPlusBold.wallet_add
                  : IconsaxPlusBold.wallet_minus,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(tx.type),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${tx.createdAt.year}-${tx.createdAt.month.toString().padLeft(2, '0')}-${tx.createdAt.day.toString().padLeft(2, '0')}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${tx.amount.toStringAsFixed(2)} ${tx.currency}',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: isCredit ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
