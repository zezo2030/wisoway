import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/api/api_client.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/booking_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/ui/error_surface.dart';
import '../../widgets/common/empty_state.dart';

class PendingChargesScreen extends StatefulWidget {
  const PendingChargesScreen({super.key});

  @override
  State<PendingChargesScreen> createState() => _PendingChargesScreenState();
}

class _PendingChargesScreenState extends State<PendingChargesScreen> {
  final BookingService _bookingService = BookingService();
  List<Map<String, dynamic>> _charges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final charges = await _bookingService.getMyPendingCharges();
      if (!mounted) return;
      setState(() {
        _charges = charges;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  bool _isAr(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  String _kindLabel(String? kind, bool ar) {
    switch (kind) {
      case 'driver_no_show':
        return ar ? 'عدم حضور السائق' : 'Driver No-Show';
      case 'passenger_no_show':
        return ar ? 'عدم حضور الراكب' : 'Passenger No-Show';
      case 'passenger_cancellation':
        return ar ? 'إلغاء الحجز' : 'Late Cancellation';
      default:
        return kind ?? '';
    }
  }

  String _statusLabel(String? status, bool ar) {
    switch (status) {
      case 'pending':
        return ar ? 'مستحق' : 'Pending';
      case 'applied':
        return ar ? 'مدفوع' : 'Collected';
      case 'waived':
        return ar ? 'ملغى' : 'Waived';
      default:
        return status ?? '';
    }
  }

  Color _statusColor(BuildContext context, String? status) {
    switch (status) {
      case 'pending':
        return T.error(context);
      case 'applied':
        return T.primary(context);
      case 'waived':
        return T.onSurfaceVariant(context);
      default:
        return T.onSurfaceVariant(context);
    }
  }

  double _totalOutstanding() {
    return _charges
        .where((c) => c['status'] == 'pending')
        .fold<double>(
          0,
          (sum, c) =>
              sum + (double.tryParse('${c['amount'] ?? '0'}') ?? 0).toDouble(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final ar = _isAr(context);
    final outstanding = _totalOutstanding();

    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        title: Text(
          ar ? 'الرسوم المستحقة' : 'Pending Charges',
          style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _charges.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: EmptyState(
                            icon: IconsaxPlusBold.tick_circle,
                            title: ar
                                ? 'لا توجد رسوم مستحقة'
                                : 'No outstanding charges',
                            subtitle: ar
                                ? 'حسابك خالٍ من الرسوم.'
                                : 'Your account is in good standing.',
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (outstanding > 0)
                          _OutstandingBanner(
                            total: outstanding,
                            ar: ar,
                            onTopUp: () => Navigator.pushNamed(
                              context,
                              RouteNames.driverWalletTopup,
                            ),
                          ),
                        const SizedBox(height: 12),
                        ..._charges.map((c) => _ChargeCard(
                              charge: c,
                              kindLabel: _kindLabel(c['kind'] as String?, ar),
                              statusLabel:
                                  _statusLabel(c['status'] as String?, ar),
                              statusColor:
                                  _statusColor(context, c['status'] as String?),
                              ar: ar,
                            )),
                      ],
                    ),
            ),
    );
  }
}

class _OutstandingBanner extends StatelessWidget {
  final double total;
  final bool ar;
  final VoidCallback onTopUp;

  const _OutstandingBanner({
    required this.total,
    required this.ar,
    required this.onTopUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.error(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.error(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(IconsaxPlusBold.warning_2, color: T.error(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ar
                      ? 'لا يمكنك نشر رحلة جديدة قبل التسوية'
                      : "You can't publish a new trip until settled",
                  style: AppTextStyles.titleMedium.copyWith(
                    color: T.error(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ar
                ? 'الإجمالي المستحق: ${total.toStringAsFixed(2)} د.أ'
                : 'Total due: ${total.toStringAsFixed(2)} JOD',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            ar
                ? 'سيتم خصم الرسوم تلقائيًا عند توفر رصيد كافٍ في محفظتك.'
                : 'Charges are deducted automatically once your wallet has enough balance.',
            style: AppTextStyles.bodySmall.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTopUp,
              icon: const Icon(IconsaxPlusBold.wallet_add),
              label: Text(ar ? 'شحن المحفظة' : 'Top Up Wallet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: T.error(context),
                foregroundColor: T.onError(context),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeCard extends StatelessWidget {
  final Map<String, dynamic> charge;
  final String kindLabel;
  final String statusLabel;
  final Color statusColor;
  final bool ar;

  const _ChargeCard({
    required this.charge,
    required this.kindLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.ar,
  });

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse('${charge['amount'] ?? '0'}') ?? 0;
    final createdAtRaw = charge['createdAt'] as String?;
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw)
        : null;
    final dateText = createdAt != null
        ? DateFormat('dd MMM yyyy · HH:mm').format(createdAt.toLocal())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kindLabel,
                  style: AppTextStyles.titleMedium
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ar
                ? 'المبلغ: ${amount.toStringAsFixed(2)} د.أ'
                : 'Amount: ${amount.toStringAsFixed(2)} JOD',
            style: AppTextStyles.bodyLarge,
          ),
          if (dateText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              dateText,
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
