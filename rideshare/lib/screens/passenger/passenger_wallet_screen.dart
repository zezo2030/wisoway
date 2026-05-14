import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../models/wallet_account_model.dart';
import '../../models/wallet_transaction_model.dart';
import '../../widgets/common/empty_state.dart';

class PassengerWalletScreen extends StatefulWidget {
  const PassengerWalletScreen({super.key});

  @override
  State<PassengerWalletScreen> createState() => _PassengerWalletScreenState();
}

class _PassengerWalletScreenState extends State<PassengerWalletScreen> {
  final PaymentService _paymentService = PaymentService();
  WalletAccountModel? _account;
  List<WalletTransactionModel> _transactions = [];
  bool _loading = true;
  bool _loadingTx = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final account = await _paymentService.getWalletAccountMe();
      if (mounted) {
        setState(() {
          _account = account;
          _loading = false;
        });
      }
      _loadTransactions();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loadingTx = true);
    try {
      final list = await _paymentService.getWalletLedgerTransactions(limit: 50);
      if (mounted) {
        setState(() {
          _transactions = list;
          _loadingTx = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTx = false);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'topup':
        return 'شحن';
      case 'trip_payment':
        return 'دفع رحلة';
      case 'trip_debit':
        return 'خصم رحلة';
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

  Future<void> _openTopUpRequest() async {
    final result = await Navigator.pushNamed(
      context,
      RouteNames.driverWalletTopup,
    );
    if (result == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        title: Text(
          'محفظتي',
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
                    const SizedBox(height: 12),
                    _buildPendingChargesShortcut(context),
                    const SizedBox(height: 8),
                    Text(
                      'تُستخدم لدفع تكلفة الحجز عند تفعيل الدفع من المحفظة. الشحن بالدينار الأردني (JOD) عبر CliQ أو تحويل يدوي مع إثبات؛ يُضاف الرصيد بعد التأكد أو موافقة الإدارة حسب الطريقة.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
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
                            onPressed: _openTopUpRequest,
                            icon: const Icon(
                              IconsaxPlusLinear.add_circle,
                              size: 20,
                            ),
                            label: Text(
                              'شحن',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _loadingTx
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
                                _tile(_transactions[i]),
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: Semantics(
        label: 'شحن المحفظة',
        button: true,
        child: FloatingActionButton.extended(
          onPressed: _openTopUpRequest,
          icon: const Icon(IconsaxPlusBold.wallet_add),
          label: Text(
            'شحن',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: T.primary(context),
        ),
      ),
    );
  }

  Widget _buildPendingChargesShortcut(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(context, RouteNames.pendingCharges);
          if (mounted) _load();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: T.surfaceVariant(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: T.outline(context).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                IconsaxPlusBold.warning_2,
                color: AppColors.warning,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرسوم المستحقة',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'عرض الغرامات والرسوم المعلّقة وشحن المحفظة',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                IconsaxPlusLinear.arrow_left_2,
                size: 18,
                color: T.onSurfaceVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _account?.balance ?? 0;
    final currency = _account?.currency ?? 'JOD';
    final active = _account?.isActive ?? true;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.teal700, AppColors.teal400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal600.withValues(alpha: 0.28),
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
              const Icon(
                IconsaxPlusBold.wallet_3,
                color: AppColors.white,
                size: 28,
              ),
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
          if (!active) ...[
            const SizedBox(height: 8),
            Text(
              'الحساب غير مفعّل — تواصل مع الدعم',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(WalletTransactionModel t) {
    final isCredit = t.direction == 'credit';
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
                  _typeLabel(t.type),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}-${t.createdAt.day.toString().padLeft(2, '0')}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${t.amount.toStringAsFixed(2)} ${t.currency}',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: isCredit ? AppColors.successDark : AppColors.warningDark,
            ),
          ),
        ],
      ),
    );
  }
}
