import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/instant_offer_actions.dart';
import '../../../core/services/instant_ride_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/ui/error_surface.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/instant_offer_dialog.dart';
import 'driver_home_cards.dart';

/// Driver-facing instant-ride control: a go-online toggle that, while online,
/// streams the driver's location (heartbeat) and polls for incoming ride
/// offers — presenting each as a countdown accept/decline dialog.
class DriverAvailabilityCard extends StatefulWidget {
  const DriverAvailabilityCard({super.key, this.onOnlineChanged});

  /// Fires whenever the online state settles, so the surrounding dashboard can
  /// mirror it (the header's presence dot).
  final ValueChanged<bool>? onOnlineChanged;

  @override
  State<DriverAvailabilityCard> createState() => _DriverAvailabilityCardState();
}

class _DriverAvailabilityCardState extends State<DriverAvailabilityCard> {
  final InstantRideService _service = InstantRideService();
  final LocationService _location = LocationService();

  bool _isOnline = false;
  bool _busy = true;
  Timer? _heartbeatTimer;
  Timer? _offerPollTimer;
  bool _offerDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _offerPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _service.getAvailability();
      if (!mounted) return;
      setState(() {
        _isOnline = status.isOnline;
        _busy = false;
      });
      widget.onOnlineChanged?.call(_isOnline);
      if (status.isOnline) _startTimers();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        final pos = await _location.getCurrentPosition();
        await _service.setAvailability(
          isOnline: true,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        if (!mounted) return;
        setState(() => _isOnline = true);
        widget.onOnlineChanged?.call(true);
        _startTimers();
      } else {
        _stopTimers();
        await _service.setAvailability(isOnline: false);
        if (!mounted) return;
        setState(() => _isOnline = false);
        widget.onOnlineChanged?.call(false);
      }
    } catch (e) {
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTimers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _sendHeartbeat(),
    );
    _offerPollTimer?.cancel();
    _offerPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollForOffer(),
    );
  }

  void _stopTimers() {
    _heartbeatTimer?.cancel();
    _offerPollTimer?.cancel();
    _heartbeatTimer = null;
    _offerPollTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    try {
      final pos = await _location.getCurrentPosition();
      await _service.heartbeat(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (_) {
      // Transient — the next tick will retry.
    }
  }

  Future<void> _pollForOffer() async {
    if (_offerDialogOpen || InstantOfferActions.isDialogOpen || !mounted) {
      return;
    }
    try {
      final offer = await _service.getPendingOffer();
      if (offer == null || offer.id.isEmpty || !mounted) return;
      _offerDialogOpen = true;
      await PushNotificationService.cancelAndroidInstantOfferNotification(
        offer.id,
      );
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => InstantOfferDialog(offer: offer, service: _service),
      );
      _offerDialogOpen = false;
    } catch (_) {
      _offerDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: DriverHomeCard(
        borderColor: _isOnline
            ? T.primary(context).withValues(alpha: 0.45)
            : T.outline(context),
        child: Column(
          children: [
            Row(
              children: [
                // Contained rather than cropped: the crop filled the box with
                // the illustration's tinted road, which read as a pasted
                // rectangle against the white card.
                Image.asset(
                  'assets/illustrations/driver/driver_home_availability.webp',
                  width: 130,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.driverStatusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: T.onSurfaceVariant(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isOnline ? l10n.instantOnline : l10n.instantOffline,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _isOnline
                              ? AppColors.successDark
                              : T.onSurface(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isOnline
                            ? l10n.instantOnlineHint
                            : l10n.instantOfflineHint,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: T.onSurfaceVariant(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Semantics(
                    label: l10n.instantRidesTitle,
                    toggled: _isOnline,
                    child: Switch(
                      value: _isOnline,
                      onChanged: _toggle,
                      activeThumbColor: AppColors.white,
                      activeTrackColor: T.primary(context),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isOnline
                          ? l10n.instantOnlineReady
                          : l10n.instantGoOnlineHint,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    IconsaxPlusLinear.info_circle,
                    size: 17,
                    color: T.primary(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
