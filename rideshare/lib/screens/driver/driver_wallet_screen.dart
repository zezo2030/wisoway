import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/route_names.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../models/wallet_account_model.dart';
import '../../models/wallet_transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../l10n/l10n_extensions.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  final PaymentService _paymentService = PaymentService();
  WalletAccountModel? _walletAccount;
  List<WalletTransactionModel> _transactions = [];
  bool _loading = true;
  bool _loadingTransactions = false;
  List<Map<String, dynamic>> _payouts = [];
  bool _payoutBusy = false;

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
          _walletAccount = account;
          _loading = false;
        });
      }

      _loadTransactions();
      final response = await ApiClient().get('/wallet/driver/payout-requests');
      final rows = response is Map ? response['data'] : response;
      if (mounted && rows is List)
        setState(
          () => _payouts = rows
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
        );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
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

  Future<void> _openTopUp({bool viaCliq = false}) async {
    final result = await Navigator.pushNamed(
      context,
      RouteNames.driverWalletTopup,
      arguments: viaCliq ? 'cliq' : null,
    );
    if (result == true && mounted) _load();
  }

  String _typeLabel(BuildContext context, String type) {
    switch (type) {
      case 'topup':
        return context.l10n.txTypeTopup;
      case 'trip_payment':
        return context.l10n.txTypeTripPayment;
      case 'trip_debit':
        return context.l10n.txTypeTripDebit;
      case 'refund':
        return context.l10n.txTypeRefund;
      case 'payout':
        return context.l10n.txTypePayout;
      case 'adjustment':
        return context.l10n.txTypeAdjustment;
      case 'hold':
        return context.l10n.txTypeHold;
      case 'release_hold':
        return context.l10n.txTypeReleaseHold;
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
            context.l10n.walletTitle,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(child: Text(context.l10n.pleaseSignIn)),
      );
    }

    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        title: Text(
          context.l10n.walletTitle,
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
                    if (_walletAccount?.currency == 'JOD') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openTopUp(viaCliq: true),
                          icon: const Icon(IconsaxPlusLinear.flash),
                          label: Text(
                            _ar ? 'شحن عبر كليك' : 'Top up with CliQ',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildPendingChargesShortcut(context),
                    const SizedBox(height: 16),
                    _buildEarningsCard(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.transactionsLog,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Semantics(
                          label: context.l10n.topUpWallet,
                          button: true,
                          child: TextButton.icon(
                            onPressed: _openTopUp,
                            icon: const Icon(
                              IconsaxPlusLinear.add_circle,
                              size: 20,
                            ),
                            label: Text(
                              context.l10n.topUpWallet,
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
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: EmptyState(
                              title: context.l10n.noTransactionsYet,
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
        label: context.l10n.topUpWallet,
        button: true,
        child: FloatingActionButton.extended(
          onPressed: _openTopUp,
          icon: const Icon(IconsaxPlusBold.wallet_add),
          label: Text(
            context.l10n.topUpShort,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.warning,
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
                      context.l10n.pendingChargesShortcutTitle,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.pendingChargesShortcutSubtitle,
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
                context.l10n.walletBalanceLabel,
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

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  Widget _buildEarningsCard() {
    final a = _walletAccount;
    final currency = a?.currency ?? 'JOD';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _ar ? 'الأرباح والسحب' : 'Earnings and withdrawals',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _ar
                  ? 'رصيد ترحيبي عند اعتماد السائق: 5 دنانير أو 25 ريالاً أو ما يعادل 5 دنانير للعملات الأخرى. تُخصم العمولة من المحفظة عند انتهاء الرحلة.'
                  : 'Approved drivers receive 5 JOD, 25 SAR, or the equivalent of 5 JOD in other currencies. Commission is charged at trip completion.',
            ),
            Text(
              '${_ar ? 'الحد الأدنى للشحن والرصيد المتبقي بعد السحب' : 'Minimum top-up and retained balance'}: ${a?.minimumRetainedBalance.toStringAsFixed(2) ?? '—'} $currency',
            ),
            Text(
              '${_ar ? 'محجوز للسحب' : 'Reserved'}: ${a?.reservedBalance.toStringAsFixed(2) ?? '0'} $currency',
            ),
            Text(
              '${_ar ? 'متاح للسحب' : 'Available to withdraw'}: ${a?.withdrawableBalance.toStringAsFixed(2) ?? '0'} $currency',
            ),
            if (a?.rechargeRequired == true)
              Text(
                _ar
                    ? 'اشحن المحفظة بالحد الأدنى وسدد أي مستحقات لاستقبال الرحلات وإنشائها.'
                    : 'Top up at least the minimum and clear any debt to receive or create rides.',
                style: const TextStyle(color: Colors.red),
              ),
            if (a?.exchangeRateProvider != null)
              TextButton(
                onPressed: () =>
                    launchUrl(Uri.parse('https://www.exchangerate-api.com')),
                child: const Text('Rates by ExchangeRate-API'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _payoutBusy || (a?.withdrawableBalance ?? 0) <= 0
                  ? null
                  : _requestPayout,
              child: Text(
                _ar ? 'طلب سحب الأرباح عبر CliQ' : 'Request a CliQ withdrawal',
              ),
            ),
            for (final p in _payouts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${p['amount']} ${p['currency']}'),
                subtitle: Text('${p['bankAccountRef'] ?? ''}'),
                trailing: Text(
                  _ar
                      ? ({
                              'pending': 'قيد المراجعة',
                              'approved': 'تمت الموافقة',
                              'paid': 'تم التحويل',
                              'rejected': 'مرفوض',
                            }[p['status']] ??
                            '${p['status']}')
                      : '${p['status']}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPayout() async {
    var amountText = '';
    var accountText = '';
    final formKey = GlobalKey<FormState>();
    final max = _walletAccount!.withdrawableBalance;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_ar ? 'طلب سحب الأرباح' : 'Withdraw earnings'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                onChanged: (value) => amountText = value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      '${_ar ? 'المبلغ — الحد الأقصى' : 'Amount — maximum'} $max',
                ),
                validator: (s) {
                  final n = double.tryParse(s ?? '');
                  return n == null || !n.isFinite || n <= 0 || n > max
                      ? (_ar
                            ? 'أدخل مبلغاً ضمن الرصيد المتاح'
                            : 'Enter an amount within your available balance')
                      : null;
                },
              ),
              TextFormField(
                onChanged: (value) => accountText = value,
                decoration: InputDecoration(
                  labelText: _ar
                      ? 'حساب CliQ أو رقم الهاتف'
                      : 'CliQ alias or phone',
                ),
                validator: (s) => s == null || s.trim().isEmpty
                    ? (_ar
                          ? 'أدخل حساب الاستلام'
                          : 'Enter the receiving account')
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(_ar ? 'إرسال الطلب' : 'Submit'),
          ),
        ],
      ),
    );
    final requestedAmount = double.tryParse(amountText);
    final bankAccountRef = accountText.trim();
    if (result != true || !mounted) return;
    setState(() => _payoutBusy = true);
    try {
      await ApiClient().post(
        '/wallet/driver/payout-requests',
        data: {
          'amount': requestedAmount,
          'currency': _walletAccount!.currency,
          'bankAccountRef': bankAccountRef,
        },
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _payoutBusy = false);
    }
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
                  _typeLabel(context, tx.type),
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
