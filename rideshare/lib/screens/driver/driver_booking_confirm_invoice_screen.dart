import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../models/trip_model.dart';
import '../../models/trip_pricing_preview_model.dart';
import '../../models/wallet_model.dart';
import '../../core/constants/route_names.dart';

/// Shows driver unlock fee breakdown before confirming the first booking on a trip.
class DriverBookingConfirmInvoiceScreen extends StatefulWidget {
  final String tripId;
  final String bookingId;

  const DriverBookingConfirmInvoiceScreen({
    super.key,
    required this.tripId,
    required this.bookingId,
  });

  @override
  State<DriverBookingConfirmInvoiceScreen> createState() =>
      _DriverBookingConfirmInvoiceScreenState();
}

class _DriverBookingConfirmInvoiceScreenState
    extends State<DriverBookingConfirmInvoiceScreen> {
  final TripService _tripService = TripService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  TripModel? _trip;
  TripPricingPreviewModel? _preview;
  WalletModel? _wallet;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final trip = await _tripService.getTrip(widget.tripId);
      final preview = await _tripService.getTripPricingPreviewModel(
        widget.tripId,
      );
      final wallet = await _paymentService.getWalletMe();
      if (!mounted) return;
      if (trip == null || preview == null) {
        setState(() {
          _error = 'تعذر تحميل بيانات الرحلة أو التسعير.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _trip = trip;
        _preview = preview;
        _wallet = wallet;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Amount actually debited from wallet (server uses lifetime free & zero fee rules).
  double get _effectiveCharge {
    final w = _wallet;
    final p = _preview;
    if (w == null || p == null) return 0;
    if (!w.hasUsedLifetimeFreeTrip) return 0;
    final raw = p.driverUnlock.feeAmount;
    return raw < 0 ? 0 : raw;
  }

  bool get _canAfford =>
      _effectiveCharge <= 0 ||
      (_wallet != null && _wallet!.balance >= _effectiveCharge);

  Future<void> _onConfirm() async {
    if (!_canAfford || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _bookingService.confirmBooking(widget.bookingId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_messageForError(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageForError(String raw) {
    if (raw.contains('Insufficient') ||
        raw.contains('balance') ||
        raw.contains('wallet')) {
      return 'رصيد المحفظة غير كافٍ. شحن المحفظة ثم أعد المحاولة.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        title: Text(
          'تأكيد الحجز والدفع',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: T.onPrimary(context),
          ),
        ),
        backgroundColor: T.primary(context),
        foregroundColor: T.onPrimary(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: T.error(context)),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final trip = _trip!;
    final preview = _preview!;
    final w = _wallet!;
    final du = preview.driverUnlock;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoBanner(context),
                const SizedBox(height: 16),
                _tripSummary(context, trip),
                const SizedBox(height: 16),
                _feeBreakdown(context, du),
                const SizedBox(height: 16),
                _walletCard(context, w),
                if (!_canAfford) ...[
                  const SizedBox(height: 12),
                  _insufficientBanner(context),
                ],
              ],
            ),
          ),
        ),
        _bottomBar(context),
      ],
    );
  }

  Widget _infoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.primaryContainer(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.primary(context).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(IconsaxPlusBold.info_circle, color: T.primary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'تأكيد أول حجز على هذه الرحلة يفعّل التواصل مع الركاب ويخصم رسوم فتح الرحلة مرة واحدة من محفظتك (أو يُستخدم عرض الرحلة المجانية إن وُجد).',
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onPrimaryContainer(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripSummary(BuildContext context, TripModel trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الرحلة',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${trip.from.name} → ${trip.to.name}',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'سعر المقعد: ${trip.price.toStringAsFixed(2)} ${trip.currency} · عدد المقاعد: ${trip.totalSeats}',
            style: AppTextStyles.bodySmall.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeBreakdown(BuildContext context, DriverUnlockPricingPreview du) {
    final w = _wallet!;
    final usesFree = !w.hasUsedLifetimeFreeTrip;
    final listed = du.feeAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل رسوم فتح الرحلة',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 12),
          if (usesFree) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(IconsaxPlusBold.gift, color: T.secondary(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لديك رحلة مجانية متاحة: لن يُخصم من محفظتك عند التأكيد.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _row(
            context,
            'أساس الحساب',
            du.usesPercent
                ? 'سعر المقعد × عدد المقاعد × النسبة'
                : 'رسم ثابت حسب المنصة',
          ),
          if (du.usesPercent) ...[
            _row(
              context,
              'سعر المقعد',
              '${du.seatPrice.toStringAsFixed(2)} ${du.currency}',
            ),
            _row(context, 'عدد المقاعد', '${du.totalSeats}'),
            _row(
              context,
              'نسبة رسوم السائق',
              '${du.driverUnlockPercent.toStringAsFixed(0)}%',
            ),
          ] else ...[
            _row(
              context,
              'الرسم الثابت',
              '${du.legacyFlatFeeAmount.toStringAsFixed(2)} ${du.currency}',
            ),
          ],
          const Divider(height: 24),
          _row(
            context,
            'المبلغ المستحق حسب التسعير',
            '${listed.toStringAsFixed(2)} ${du.currency}',
            emphasize: true,
          ),
          if (!usesFree && listed > 0) ...[
            const SizedBox(height: 8),
            Text(
              'سيتم خصم هذا المبلغ من محفظتك عند الضغط على تأكيد.',
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
          ],
          if (usesFree && listed > 0) ...[
            const SizedBox(height: 8),
            Text(
              'بعد استخدام العرض المجاني لن يُطبق هذا المبلغ على هذه العملية.',
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
                color: emphasize ? T.primary(context) : T.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletCard(BuildContext context, WalletModel w) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Row(
        children: [
          Icon(IconsaxPlusBold.wallet_3, color: T.primary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رصيد المحفظة',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                Text(
                  '${w.balance.toStringAsFixed(2)} ${w.currency}',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              RouteNames.driverWallet,
            ).then((_) => _load()),
            child: const Text('شحن'),
          ),
        ],
      ),
    );
  }

  Widget _insufficientBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.error(context).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.error(context).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: T.error(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'رصيدك لا يكفي لخصم ${_effectiveCharge.toStringAsFixed(2)} ${_wallet?.currency ?? 'JOD'}. شحن المحفظة ثم أكد.',
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final canSubmit = _canAfford && !_submitting;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: const Text('رجوع'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: canSubmit ? _onConfirm : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: T.onPrimary(context),
                        ),
                      )
                    : const Text('أؤكد الدفع وتأكيد الحجز'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
