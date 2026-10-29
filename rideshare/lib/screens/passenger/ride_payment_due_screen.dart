import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/active_ride_navigator.dart';
import '../../core/services/ride_payment_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/ride_payment.dart';
import '../../models/trip_model.dart';
import '../../providers/trip_provider.dart';

/// The passenger's end of a ride — instant or shared: the fare and how it is
/// being paid.
///
///  * cash: «الرجاء دفع تكلفة الرحلة للسائق» until the driver confirms;
///  * CliQ: the request-to-pay is out — approve it in the bank app; if it
///    fails, ask again or pay the driver cash instead.
///
/// It can't be left until the fare is settled, so nobody walks off unpaid.
class RidePaymentDueScreen extends StatefulWidget {
  const RidePaymentDueScreen({
    super.key,
    required this.tripId,
    this.trip,
    this.service,
  });

  final String tripId;

  /// The completed trip, when the caller already has it.
  final TripModel? trip;

  @visibleForTesting
  final RidePaymentService? service;

  @override
  State<RidePaymentDueScreen> createState() => _RidePaymentDueScreenState();
}

class _RidePaymentDueScreenState extends State<RidePaymentDueScreen> {
  static const _pollEvery = Duration(seconds: 4);

  late final RidePaymentService _service =
      widget.service ?? RidePaymentService();
  TripModel? _trip;
  RidePayment? _payment;
  Timer? _poll;
  bool _leaving = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _check();
    _poll = Timer.periodic(_pollEvery, (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    ActiveRideNavigator.left(ActiveRideNavigator.paymentKey(widget.tripId));
    super.dispose();
  }

  Future<void> _check() async {
    if (_leaving || !mounted) return;
    try {
      final payment = await _service.getMine(widget.tripId);
      if (!mounted) return;
      setState(() => _payment = payment);
      if (_trip == null) unawaited(_loadTrip());
      if (payment.isPaid) {
        await _leaveToRating();
      } else if (payment.isDisputed) {
        await _leaveDisputed();
      }
    } catch (_) {
      // Transient — the next tick retries.
    }
  }

  Future<void> _loadTrip() async {
    final trip = await Provider.of<TripProvider>(
      context,
      listen: false,
    ).getTrip(widget.tripId);
    if (mounted && trip != null) setState(() => _trip = trip);
  }

  Future<void> _leaveToRating() async {
    _leaving = true;
    _poll?.cancel();
    final trip =
        _trip ??
        await Provider.of<TripProvider>(
          context,
          listen: false,
        ).getTrip(widget.tripId);
    if (!mounted) return;
    if (trip == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.rating,
      (route) => route.isFirst,
      arguments: {
        'tripId': trip.id,
        'trip': trip,
        'driverId': trip.driverId,
        'driverName': trip.driverName ?? '',
      },
    );
  }

  Future<void> _leaveDisputed() async {
    _leaving = true;
    _poll?.cancel();
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          IconsaxPlusBold.info_circle,
          color: AppColors.warning,
          size: 32,
        ),
        title: Text(l10n.ridePaymentDisputedTitle),
        content: Text(l10n.ridePaymentDisputedBody),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _act(Future<RidePayment> Function() call) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final payment = await call();
      if (mounted) setState(() => _payment = payment);
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    return PopScope(
      // Locked until the fare is settled.
      canPop: false,
      child: Scaffold(
        backgroundColor: T.background(context),
        body: SafeArea(
          child: payment == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 28),
                      _buildAmountCard(context, payment),
                      const SizedBox(height: 16),
                      ..._buildState(context, payment),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        const Icon(
          IconsaxPlusBold.tick_circle,
          color: AppColors.success,
          size: 64,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.ridePaymentArrivedTitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: T.onSurface(context),
          ),
        ),
        // No destination name: the passenger may have changed their mind on
        // the way, so the requested one can be wrong.
      ],
    );
  }

  Widget _buildAmountCard(BuildContext context, RidePayment payment) {
    final l10n = context.l10n;
    final amount = payment.amount == payment.amount.roundToDouble()
        ? payment.amount.toStringAsFixed(0)
        : payment.amount.toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: T.primary(context).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: T.primary(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            payment.isCliq || payment.isWallet
                ? l10n.ridePaymentAmountDue
                : l10n.ridePaymentPayDriverTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.textSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$amount ${payment.currency}',
            key: const ValueKey('payment-due-amount'),
            style: AppTextStyles.headlineLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 10),
          if (payment.discountAmount > 0)
            Text(
              '${Localizations.localeOf(context).languageCode == 'ar' ? 'السعر قبل الخصم' : 'Original fare'}: ${payment.originalAmount?.toStringAsFixed(2)} ${payment.currency}\n${payment.promoCode}: -${payment.discountAmount.toStringAsFixed(2)} ${payment.currency}',
              textAlign: TextAlign.center,
            ),
          _MethodChip(isCliq: payment.isCliq, isWallet: payment.isWallet),
        ],
      ),
    );
  }

  List<Widget> _buildState(BuildContext context, RidePayment payment) {
    final l10n = context.l10n;

    if (payment.isWallet) {
      final ar = Localizations.localeOf(context).languageCode == 'ar';
      return [
        Text(
          ar
              ? 'اشحن محفظتك إذا كان الرصيد غير كافٍ، ثم أعد محاولة الدفع.'
              : 'Top up your wallet if needed, then retry payment.',
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _act(() => _service.payFromWallet(widget.tripId)),
          child: Text(ar ? 'الدفع من المحفظة' : 'Pay from wallet'),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/passenger-wallet'),
          child: Text(l10n.walletTitle),
        ),
      ];
    }

    if (payment.isCliqFailed) {
      return [
        _Notice(
          icon: IconsaxPlusLinear.danger,
          color: AppColors.error,
          text: l10n.ridePaymentCliqFailed,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          key: const ValueKey('payment-retry-cliq'),
          onPressed: _busy
              ? null
              : () => _act(() => _service.retryCliq(payment.bookingId)),
          icon: const Icon(IconsaxPlusLinear.refresh),
          label: Text(l10n.ridePaymentRetryCliq),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('payment-switch-cash'),
          onPressed: _busy
              ? null
              : () => _act(() => _service.switchToCash(payment.bookingId)),
          icon: const Icon(IconsaxPlusLinear.money_3),
          label: Text(l10n.ridePaymentPayCashInstead),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ];
    }

    if (payment.isCliq) {
      return [
        _Notice(
          icon: IconsaxPlusLinear.mobile,
          color: T.primary(context),
          text: payment.payerCliqAlias != null
              ? l10n.ridePaymentCliqRequested(payment.payerCliqAlias!)
              : l10n.ridePaymentCliqRequestedNoAlias,
        ),
        const SizedBox(height: 28),
        _Waiting(text: l10n.ridePaymentWaitingBank),
        const SizedBox(height: 16),
        TextButton(
          key: const ValueKey('payment-switch-cash'),
          onPressed: _busy
              ? null
              : () => _act(() => _service.switchToCash(payment.bookingId)),
          child: Text(l10n.ridePaymentPayCashInstead),
        ),
      ];
    }

    return [
      _Notice(
        icon: IconsaxPlusLinear.money_3,
        color: T.primary(context),
        text: l10n.ridePaymentCashInstruction,
      ),
      const SizedBox(height: 28),
      _Waiting(text: l10n.ridePaymentWaitingDriver),
    ];
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.isCliq, this.isWallet = false});

  final bool isCliq;
  final bool isWallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCliq ? Icons.account_balance_outlined : Icons.payments_outlined,
            size: 16,
            color: T.primary(context),
          ),
          const SizedBox(width: 6),
          Text(
            isWallet
                ? context.l10n.walletTitle
                : isCliq
                ? context.l10n.paymentMethodCliq
                : context.l10n.paymentMethodCash,
            style: AppTextStyles.labelLarge.copyWith(
              color: T.primary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}
