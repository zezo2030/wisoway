import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/services/instant_ride_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/theme/colors.dart';
import '../core/ui/error_surface.dart';
import '../l10n/l10n_extensions.dart';
import '../models/instant_ride_models.dart';
import '../screens/driver/instant_offer_details_screen.dart';
import '../screens/driver/widgets/instant_offer_parts.dart';
import '../screens/passenger/trip_details_screen.dart';

/// The card that interrupts a driver with an incoming instant-ride request.
///
/// It is deliberately a summary, not the whole job: the fare, where the trip
/// runs from and to, how far away the passenger is, and how long is left to
/// decide. Anything more — full addresses, the map, the passenger, the fare
/// composer — lives one tap away in [InstantOfferDetailsScreen], because a
/// driver reading this has seconds and usually a road in front of them.
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
  late int _secondsLeft;
  late final int _totalSeconds;
  Timer? _ticker;
  bool _busy = false;

  InstantRequestSummary? get _req => widget.offer.request;

  @override
  void initState() {
    super.initState();
    final expiresAt = widget.offer.expiresAt;
    final remaining = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inSeconds
        : 25;
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

  /// Hands the decision to the details screen. The countdown keeps running
  /// there, so pausing ours avoids two timers racing to dismiss the same offer.
  Future<void> _openDetails({bool countering = false}) async {
    if (_busy) return;
    _ticker?.cancel();
    final outcome = await Navigator.of(context).push<InstantOfferOutcome>(
      MaterialPageRoute(
        builder: (_) => InstantOfferDetailsScreen(
          offer: widget.offer,
          service: widget.service,
          startCountering: countering,
        ),
      ),
    );
    if (!mounted) return;
    if (outcome != null) {
      // Decided (or expired) over there — this card has nothing left to ask.
      Navigator.of(context).pop();
      return;
    }
    // Backed out without deciding: resume where the countdown actually is.
    final expiresAt = widget.offer.expiresAt;
    final remaining = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inSeconds
        : _secondsLeft;
    setState(() => _secondsLeft = remaining);
    if (remaining <= 0) {
      Navigator.of(context).maybePop();
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) {
        _ticker?.cancel();
        Navigator.of(context).maybePop();
      }
    });
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
        SnackBar(content: Text(toast), backgroundColor: AppColors.success),
      );
      final tripId = request.tripId;
      if (tripId != null && tripId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(builder: (_) => TripDetailsScreen(tripId: tripId)),
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
      // The offer may already be gone; dismissing is right either way.
    }
    _ticker?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final req = _req;
    final fare = req?.passengerFare ?? req?.fareEstimate;
    final earnings =
        req?.earningsLabel ??
        (fare != null ? '$fare ${req?.currency ?? ''}' : '—');
    final canCounter = req?.passengerFareValue != null;

    return Dialog(
      backgroundColor: T.surface(context),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, req),
              const SizedBox(height: 14),
              // The whole body is the tap target for the details screen —
              // matching how a driver expects to "open" an incoming job.
              InkWell(
                onTap: _busy ? null : () => _openDetails(),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InstantFareHero(
                        earnings: earnings,
                        label: l10n.instantOfferExpectedEarnings,
                        note: l10n.instantOfferCashNote,
                      ),
                      const SizedBox(height: 14),
                      InstantRouteBlock(
                        fromName: req?.fromName ?? '—',
                        toName: req?.toName ?? '—',
                        compact: true,
                      ),
                      const SizedBox(height: 14),
                      _metricsStrip(context, req),
                      const SizedBox(height: 10),
                      _detailsHint(context),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              InstantCountdownBar(
                secondsLeft: _secondsLeft,
                totalSeconds: _totalSeconds,
              ),
              const SizedBox(height: 14),
              _actions(context, canCounter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, InstantRequestSummary? req) {
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: T.primaryContainer(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            req?.tripTypeLabel ?? l10n.instantOfferBadge,
            style: TextStyle(
              color: T.onPrimaryContainer(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            l10n.instantOfferCardTitle,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: T.onSurface(context),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  /// Pickup leg, trip length and duration in one row — the three figures that
  /// were missing from the old card, which showed the trip only.
  Widget _metricsStrip(BuildContext context, InstantRequestSummary? req) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: InstantMetricTile(
              icon: Icons.my_location,
              label: l10n.instantOfferPickupDistance,
              value: req?.pickupDistanceLabel ?? '—',
              emphasized: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InstantMetricTile(
              icon: Icons.route_outlined,
              label: l10n.instantOfferTripDistance,
              value: req?.distanceLabel ?? '—',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InstantMetricTile(
              icon: Icons.schedule,
              label: l10n.instantOfferDuration,
              value: req?.durationLabel ?? '—',
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsHint(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.instantOfferOpenDetails,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: T.primary(context),
          ),
        ),
        const SizedBox(width: 2),
        Icon(Icons.chevron_left, size: 18, color: T.primary(context)),
      ],
    );
  }

  Widget _actions(BuildContext context, bool canCounter) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _busy ? null : _decline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: T.onSurface(context),
                    side: BorderSide(color: T.outlineVariant(context)),
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
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _busy ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: T.primary(context),
                    foregroundColor: T.onPrimary(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              T.onPrimary(context),
                            ),
                          ),
                        )
                      : Text(
                          l10n.instantOfferAcceptTrip,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        if (canCounter) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _busy ? null : () => _openDetails(countering: true),
            icon: const Icon(Icons.trending_up, size: 19),
            label: Text(l10n.instantProposeFare),
            style: TextButton.styleFrom(foregroundColor: T.primary(context)),
          ),
        ],
      ],
    );
  }
}
