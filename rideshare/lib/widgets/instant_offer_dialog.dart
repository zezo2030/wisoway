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
import '../core/services/active_ride_navigator.dart';

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

  /// The offer a card is currently showing, whichever path opened it (push
  /// tap or the driver home poll), so a late push for it isn't also posted to
  /// the tray.
  static String? visibleOfferId;

  static _InstantOfferDialogState? _visible;

  /// Closes the card for [offerId] if it is up — the offer died elsewhere
  /// (the passenger cancelled, another driver took it).
  static void dismissOffer(String offerId) {
    final state = _visible;
    if (state != null && state.widget.offer.id == offerId) state._closeDead();
  }

  @override
  State<InstantOfferDialog> createState() => _InstantOfferDialogState();
}

class _InstantOfferDialogState extends State<InstantOfferDialog> {
  late int _secondsLeft;
  late final int _totalSeconds;
  Timer? _ticker;
  Timer? _liveness;
  bool _busy = false;

  /// Set once the card is on its way out, so a late tick or a details screen
  /// returning can't pop whatever route is underneath it.
  bool _closed = false;

  InstantRequestSummary? get _req => widget.offer.request;

  @override
  void initState() {
    super.initState();
    // One deadline shared with the details screen; the bar measures against
    // the whole window, so it never jumps back to full.
    _secondsLeft = widget.offer.secondsLeft();
    _totalSeconds = widget.offer.windowSeconds;
    InstantOfferDialog.visibleOfferId = widget.offer.id;
    InstantOfferDialog._visible = this;
    PushNotificationService.cancelAndroidInstantOfferNotification(
      widget.offer.id,
    );
    // Ring until the driver decides or the window closes.
    PushNotificationService.startInstantOfferRing(
      widget.offer.id,
      widget.offer.deadline ??
          DateTime.now().add(Duration(seconds: _secondsLeft)),
    );
    _startTicker(tickNow: false);
    // The cancel push can be lost or late; the server is the source of truth
    // for whether this offer is still waiting on this driver.
    _liveness = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkStillPending(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _liveness?.cancel();
    if (InstantOfferDialog.visibleOfferId == widget.offer.id) {
      InstantOfferDialog.visibleOfferId = null;
    }
    if (InstantOfferDialog._visible == this) InstantOfferDialog._visible = null;
    PushNotificationService.stopInstantOfferRing(widget.offer.id);
    // The FCM push often lands after the in-app poll has already opened this
    // card, so the cancel in initState misses it. Clear it again on the way
    // out — accepted, declined or expired, the tray entry is stale.
    PushNotificationService.cancelAndroidInstantOfferNotification(
      widget.offer.id,
    );
    super.dispose();
  }

  Future<void> _checkStillPending() async {
    if (_busy || _closed) return;
    try {
      final pending = await widget.service.getPendingOffer();
      if (!mounted || _busy || _closed) return;
      if (pending == null || pending.id != widget.offer.id) _closeDead();
    } catch (_) {
      // Offline for a moment — the countdown still bounds the card.
    }
  }

  /// The offer is gone server-side: stop ringing and take the card down, along
  /// with the details screen if the driver had it open.
  void _closeDead() {
    if (_closed || !mounted) return;
    PushNotificationService.stopInstantOfferRing(widget.offer.id);
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route != null && !route.isCurrent) {
      navigator.popUntil((r) => r == route);
    }
    _close();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    _ticker?.cancel();
    _liveness?.cancel();
    Navigator.of(context).pop();
  }

  /// Hands the decision to the details screen. The countdown keeps running
  /// there, so pausing ours avoids two timers racing to dismiss the same offer.
  Future<void> _openDetails() async {
    if (_busy) return;
    _ticker?.cancel();
    final outcome = await Navigator.of(context).push<InstantOfferOutcome>(
      MaterialPageRoute(
        builder: (_) => InstantOfferDetailsScreen(
          offer: widget.offer,
          service: widget.service,
        ),
      ),
    );
    if (!mounted || _closed) return;
    if (outcome != null) {
      // Decided (or expired) over there — this card has nothing left to ask.
      _close();
      return;
    }
    // Backed out without deciding: pick the shared countdown back up.
    _startTicker();
  }

  /// Re-reads the shared deadline each tick rather than decrementing, so the
  /// count can't drift and agrees with the details screen to the second.
  void _startTicker({bool tickNow = true}) {
    _ticker?.cancel();
    void tick() {
      if (!mounted || _closed) return;
      setState(() => _secondsLeft = widget.offer.secondsLeft());
      if (_secondsLeft <= 0) {
        _ticker?.cancel();
        _close();
      }
    }

    if (tickNow) tick();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => tick());
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final request = await widget.service.acceptOffer(widget.offer.id);
      _ticker?.cancel();
      _liveness?.cancel();
      if (!mounted || _closed) return;
      _closed = true;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final toast = context.l10n.instantRideAcceptedToast;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(toast), backgroundColor: AppColors.success),
      );
      final tripId = request.tripId;
      if (tripId != null && tripId.isNotEmpty) {
        ActiveRideNavigator.enterAsDriver(tripId);
      } else {
        await ActiveRideNavigator.resume();
      }
    } catch (e) {
      _ticker?.cancel();
      _liveness?.cancel();
      if (!mounted || _closed) return;
      _closed = true;
      final failure = ApiClient.mapError(e);
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      // Close the card first; popping after the error surface would close the
      // error instead and leave this card up.
      Navigator.of(context).pop();
      if (rootContext.mounted) ErrorSurface.showFailure(rootContext, failure);
      // The accept may have gone through even though the reply failed.
      await ActiveRideNavigator.resume();
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
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final req = _req;
    final fare = req?.passengerFare ?? req?.fareEstimate;
    final earnings =
        req?.earningsLabel ??
        (fare != null ? '$fare ${req?.currency ?? ''}' : '—');

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
              _actions(context),
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

  Widget _actions(BuildContext context) {
    final l10n = context.l10n;
    return Row(
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
    );
  }
}
