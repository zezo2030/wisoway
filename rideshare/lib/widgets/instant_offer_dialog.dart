import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/services/instant_ride_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/theme/colors.dart';
import '../core/ui/error_surface.dart';
import '../l10n/l10n_extensions.dart';
import '../models/instant_ride_models.dart';
import '../screens/passenger/trip_details_screen.dart';

/// Rich instant-offer card shown in-app (matches VisionWay driver offer UI).
class InstantOfferDialog extends StatefulWidget {
  final InstantOffer offer;
  final InstantRideService service;

  const InstantOfferDialog({
    super.key,
    required this.offer,
    required this.service,
  });

  @override
  State<InstantOfferDialog> createState() => _InstantOfferDialogState();
}

class _InstantOfferDialogState extends State<InstantOfferDialog> {
  static const Color _brand = Color(0xFF007D69);
  static const Color _brandSoft = Color(0xFFE6F4F1);

  late int _secondsLeft;
  late final int _totalSeconds;
  Timer? _ticker;
  bool _busy = false;
  bool _countering = false;
  double? _counterAmount;

  InstantRequestSummary? get _req => widget.offer.request;

  double? get _passengerFare {
    final req = _req;
    return double.tryParse(req?.passengerFare ?? req?.fareEstimate ?? '');
  }

  double get _counterMax {
    final fare = _passengerFare ?? 0;
    return (fare * 1.5 * 100).floorToDouble() / 100;
  }

  double get _counterStep {
    final fare = _passengerFare ?? 0;
    if (fare >= 100) return 5;
    if (fare >= 20) return 1;
    return 0.25;
  }

  @override
  void initState() {
    super.initState();
    final expiresAt = widget.offer.expiresAt;
    final remaining = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inSeconds
        : 12;
    _secondsLeft = remaining.clamp(1, 120);
    _totalSeconds = _secondsLeft;
    PushNotificationService.cancelAndroidInstantOfferNotification(
      widget.offer.id,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) {
        _ticker?.cancel();
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final request = await widget.service.acceptOffer(widget.offer.id);
      _ticker?.cancel();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final toast = context.l10n.instantRideAcceptedToast;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(toast),
          backgroundColor: AppColors.success,
        ),
      );
      final tripId = request.tripId;
      if (tripId != null && tripId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => TripDetailsScreen(tripId: tripId),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.declineOffer(widget.offer.id);
    } catch (_) {
      // ignore
    }
    _ticker?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  void _bumpCounter(double direction) {
    final fare = _passengerFare;
    if (fare == null) return;
    final min = fare + _counterStep;
    final current = _counterAmount ?? min;
    final next = (current + direction * _counterStep).clamp(min, _counterMax);
    setState(() => _counterAmount = (next * 100).roundToDouble() / 100);
  }

  Future<void> _sendCounter() async {
    final amount = _counterAmount;
    if (_busy || amount == null) return;
    setState(() => _busy = true);
    try {
      await widget.service.counterOffer(widget.offer.id, amount);
      _ticker?.cancel();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.instantCounterSentToast),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final req = _req;
    final fare = req?.passengerFare ?? req?.fareEstimate;
    final currency = req?.currency ?? '';
    final earnings = req?.earningsLabel ??
        (fare != null
            ? '$fare ${currency == 'JOD' ? 'د.أ' : currency == 'SAR' ? 'ر.س' : currency}'
            : '—');
    final distance = req?.distanceLabel ??
        (req?.distanceKm != null ? '${req!.distanceKm} كم' : '—');
    final duration = req?.durationLabel ??
        (req?.durationMinutes != null ? '${req!.durationMinutes} د' : '—');
    final seats = req?.seatCount ?? 1;
    final passengers =
        req?.seatCountLabel ?? l10n.instantOfferPassengerCount(seats);

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _brandSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.instantOfferBadge,
                  style: const TextStyle(
                    color: _brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.instantOfferCardTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.instantOfferDirectSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.45),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _RouteBlock(
                    from: req?.fromName ?? '—',
                    to: req?.toName ?? '—',
                    fromLabel: l10n.fromLabel,
                    toLabel: l10n.toLabel,
                    brand: _brand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetricBlock(
                        label: l10n.instantOfferDistance,
                        value: distance,
                      ),
                      const SizedBox(height: 14),
                      _MetricBlock(
                        label: l10n.instantOfferDuration,
                        value: duration,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE8EEF0)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.instantOfferExpectedEarnings,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        earnings,
                        style: const TextStyle(
                          color: _brand,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.instantOfferIncludesFees,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.instantOfferPassengersLabel,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 18,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          passengers,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (fare != null) ...[
              const SizedBox(height: 10),
              if (_countering)
                _buildCounterSection(context, currency)
              else
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _busy || _passengerFare == null
                        ? null
                        : () => setState(() {
                              _countering = true;
                              _counterAmount ??=
                                  ((_passengerFare! + _counterStep) * 100)
                                          .roundToDouble() /
                                      100;
                            }),
                    icon: const Icon(Icons.trending_up, size: 18),
                    label: Text(l10n.instantProposeFare),
                    style: TextButton.styleFrom(foregroundColor: _brand),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.instantOfferCountdown(_secondsLeft),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _totalSeconds == 0 ? 0 : _secondsLeft / _totalSeconds,
                minHeight: 6,
                backgroundColor: _brandSoft,
                color: _brand,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _decline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brand,
                        side: const BorderSide(color: _brand, width: 1.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.instantOfferIgnore,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : (_countering ? _sendCounter : _accept),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _countering
                                        ? l10n.instantSendOffer
                                        : l10n.instantOfferAcceptTrip,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (!_countering) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right, size: 22),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterSection(BuildContext context, String currency) {
    final fare = _passengerFare ?? 0;
    final amount = _counterAmount ?? fare + _counterStep;
    final canDecrease = amount - _counterStep >= fare + _counterStep - 0.001;
    final canIncrease = amount + _counterStep <= _counterMax + 0.001;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _brandSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed:
                    canDecrease && !_busy ? () => _bumpCounter(-1) : null,
                icon: const Icon(Icons.remove, color: _brand),
              ),
              Text(
                '${amount.toStringAsFixed(2)} $currency',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              IconButton(
                onPressed:
                    canIncrease && !_busy ? () => _bumpCounter(1) : null,
                icon: const Icon(Icons.add, color: _brand),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.instantCounterMaxHint(
            _counterMax.toStringAsFixed(2),
            currency,
          ),
          style: TextStyle(
            fontSize: 11,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _RouteBlock extends StatelessWidget {
  final String from;
  final String to;
  final String fromLabel;
  final String toLabel;
  final Color brand;

  const _RouteBlock({
    required this.from,
    required this.to,
    required this.fromLabel,
    required this.toLabel,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: brand,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 34,
              margin: const EdgeInsets.symmetric(vertical: 3),
              color: const Color(0xFFD7E4E0),
            ),
            const Icon(
              Icons.location_on,
              size: 16,
              color: AppColors.error,
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fromLabel,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                from,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                toLabel,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                to,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
