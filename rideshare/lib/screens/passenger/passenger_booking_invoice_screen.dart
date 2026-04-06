import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../models/trip_model.dart';
import '../../models/trip_pricing_preview_model.dart';
import '../../models/wallet_model.dart';

/// Invoice + wallet check before creating a booking (platform fee held until driver confirms).
class PassengerBookingInvoiceScreen extends StatefulWidget {
  final String tripId;
  final List<String> seatNumbers;
  final bool sharePhoneWithDriver;

  const PassengerBookingInvoiceScreen({
    super.key,
    required this.tripId,
    required this.seatNumbers,
    required this.sharePhoneWithDriver,
  });

  @override
  State<PassengerBookingInvoiceScreen> createState() =>
      _PassengerBookingInvoiceScreenState();
}

class _PassengerBookingInvoiceScreenState
    extends State<PassengerBookingInvoiceScreen> {
  final TripService _tripService = TripService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  TripModel? _trip;
  TripPricingPreviewModel? _preview;
  WalletModel? _wallet;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  int get _seatCount => widget.seatNumbers.length;

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
      final preview = await _tripService.getTripPricingPreviewModel(widget.tripId);
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

  double get _totalHoldAmount {
    final p = _preview?.passenger;
    if (p == null || !p.requiresOnlinePayment) return 0;
    return (p.platformAmount * _seatCount);
  }

  bool get _canAfford =>
      _totalHoldAmount <= 0 ||
      (_wallet != null && _wallet!.balance >= _totalHoldAmount);

  Future<void> _onConfirm() async {
    if (!_canAfford || _submitting) return;
    setState(() => _submitting = true);
    try {
      final requiresOnline = _preview?.passenger.requiresOnlinePayment == true;
      final walletIdempotencyKey = requiresOnline ? const Uuid().v4() : null;

      final bookingResponse = await _bookingService.createBooking(
        tripId: widget.tripId,
        seatNumber: widget.seatNumbers.first,
        seatNumbers: widget.seatNumbers,
        sharePhoneWithDriver: widget.sharePhoneWithDriver,
        walletIdempotencyKey: walletIdempotencyKey,
      );
      final bookingGroupId =
          (bookingResponse['bookingGroupId'] ??
                  bookingResponse['_id'] ??
                  bookingResponse['id'])
              ?.toString();

      if (!mounted) return;
      Navigator.pop(context, bookingGroupId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Insufficient') || raw.contains('balance')) {
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
          'فاتورة الحجز',
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
    final passenger = _preview!.passenger;
    final w = _wallet!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: T.primaryContainer(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: T.primary(context).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(IconsaxPlusBold.info_circle, color: T.primary(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          passenger.requiresOnlinePayment
                              ? 'سيتم حجز المبلغ التالي من محفظتك الآن كضمان. عند تأكيد السائق لحجزك يُثبت السحب؛ إذا انتهى وقت المغادرة دون تأكيد يُعاد المبلغ تلقائياً.'
                              : 'لا تُفرض رسوم منصة على هذا الحجز عبر المحفظة.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: T.onPrimaryContainer(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
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
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${trip.from.name} → ${trip.to.name}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'المقاعد: ${widget.seatNumbers.join('، ')}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: T.onSurfaceVariant(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
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
                        'تفاصيل الرسوم',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (passenger.requiresOnlinePayment) ...[
                        _row(
                          context,
                          'سعر المقعد',
                          '${passenger.seatPrice.toStringAsFixed(2)} ${passenger.currency}',
                        ),
                        _row(
                          context,
                          'نسبة المنصة',
                          '${passenger.passengerPlatformPercent.toStringAsFixed(0)}%',
                        ),
                        _row(
                          context,
                          'رسوم المنصة لكل مقعد',
                          '${passenger.platformAmount.toStringAsFixed(2)} ${passenger.currency}',
                        ),
                        _row(context, 'عدد المقاعد', '$_seatCount'),
                        const Divider(height: 24),
                        _row(
                          context,
                          'المجموع المحجوز من المحفظة',
                          '${_totalHoldAmount.toStringAsFixed(2)} ${passenger.currency}',
                          emphasize: true,
                        ),
                      ] else
                        Text(
                          'لا يوجد خصم من المحفظة لهذا الحجز.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: T.onSurfaceVariant(context),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
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
                          RouteNames.passengerWallet,
                        ).then((_) => _load()),
                        child: const Text('شحن'),
                      ),
                    ],
                  ),
                ),
                if (!_canAfford && passenger.requiresOnlinePayment) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: T.error(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: T.error(context).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: T.error(context)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'رصيدك لا يكفي لحجز ${_totalHoldAmount.toStringAsFixed(2)} ${passenger.currency}.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: T.onSurface(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
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
                    onPressed:
                        (_canAfford || !passenger.requiresOnlinePayment) &&
                            !_submitting
                        ? _onConfirm
                        : null,
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
                        : const Text('تأكيد الحجز'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
}
