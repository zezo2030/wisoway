import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../models/payment_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../l10n/l10n_extensions.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late TabController _tabController;
  PaymentStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedStatus = null;
            break;
          case 1:
            _selectedStatus = PaymentStatus.pending;
            break;
          case 2:
            _selectedStatus = PaymentStatus.approved;
            break;
          case 3:
            _selectedStatus = PaymentStatus.rejected;
            break;
        }
      });
    });
    _selectedStatus = null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            context.l10n.paymentHistory,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(child: Text(context.l10n.pleaseSignIn)),
      );
    }

    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        title: Text(
          context.l10n.paymentHistory,
          style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: T.primary(context),
          unselectedLabelColor: T.onSurfaceVariant(context),
          indicatorColor: T.primary(context),
          labelStyle: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(text: context.l10n.paymentTabAll),
            Tab(text: context.l10n.paymentStatusPending),
            Tab(text: context.l10n.paymentStatusApproved),
            Tab(text: context.l10n.paymentStatusRejected),
          ],
        ),
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: _paymentService.getPaymentHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    IconsaxPlusLinear.danger,
                    size: 64,
                    color: T.onSurfaceVariant(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.errorLoadingData,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                ],
              ),
            );
          }

          final allPayments = snapshot.data ?? [];
          final payments = _selectedStatus == null
              ? allPayments
              : allPayments.where((p) => p.status == _selectedStatus).toList();

          if (payments.isEmpty) {
            return EmptyState(
              icon: IconsaxPlusLinear.wallet,
              title: context.l10n.noPayments,
              showCircleBackground: false,
              iconSize: 64,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                return _buildPaymentCard(context, payments[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, PaymentModel payment) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (payment.status) {
      case PaymentStatus.pending:
        statusColor = AppColors.warning;
        statusText = context.l10n.paymentStatusPending;
        statusIcon = IconsaxPlusLinear.clock;
        break;
      case PaymentStatus.approved:
        statusColor = AppColors.success;
        statusText = context.l10n.paymentStatusApproved;
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      case PaymentStatus.rejected:
        statusColor = T.error(context);
        statusText = context.l10n.paymentStatusRejected;
        statusIcon = IconsaxPlusLinear.danger;
        break;
      case PaymentStatus.refunded:
        statusColor = T.primary(context);
        statusText = context.l10n.paymentStatusRefunded;
        statusIcon = IconsaxPlusLinear.wallet;
        break;
    }

    String methodText;
    IconData methodIcon;
    Color methodColor;

    switch (payment.method) {
      case PaymentMethod.wallet:
        methodText = context.l10n.paymentMethodWallet;
        methodIcon = IconsaxPlusBold.wallet_3;
        methodColor = T.primary(context);
        break;
      case PaymentMethod.paymob:
        methodText = 'Paymob';
        methodIcon = IconsaxPlusBold.card;
        methodColor = AppColors.success;
        break;
      case PaymentMethod.manual:
        methodText = context.l10n.paymentMethodManual;
        methodIcon = IconsaxPlusBold.wallet;
        methodColor = T.primary(context);
        break;
      case PaymentMethod.communication_fee:
        methodText = context.l10n.paymentMethodCommunicationFee;
        methodIcon = IconsaxPlusBold.wallet;
        methodColor = T.primary(context);
        break;
      case PaymentMethod.cliq_a2a:
        methodText = 'CliQ';
        methodIcon = IconsaxPlusBold.wallet;
        methodColor = T.primary(context);
        break;
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Semantics(
      label:
          '$methodText - $statusText - ${payment.amount.toStringAsFixed(2)} ${payment.currency}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: methodColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(methodIcon, color: methodColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          methodText,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(payment.createdAt),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: T.onSurfaceVariant(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.amountLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                  Text(
                    '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.purposeLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                  Text(
                    context.l10n.communicationUnlockFee,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: T.onSurface(context),
                    ),
                  ),
                ],
              ),

              if (payment.isManualPayment && payment.walletNumber != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.paymentMethodLabel,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                    Text(
                      payment.method.name,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: T.onSurface(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.walletNumber,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                    Text(
                      payment.walletNumber!,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: T.onSurface(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
