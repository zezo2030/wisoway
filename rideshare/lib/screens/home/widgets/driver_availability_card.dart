import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/instant_offer_actions.dart';
import '../../../core/services/instant_ride_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/ui/error_surface.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/instant_offer_dialog.dart';

/// Driver-facing instant-ride control: a go-online toggle that, while online,
/// streams the driver's location (heartbeat) and polls for incoming ride
/// offers — presenting each as a countdown accept/decline dialog.
class DriverAvailabilityCard extends StatefulWidget {
  const DriverAvailabilityCard({super.key});

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
        _startTimers();
      } else {
        _stopTimers();
        await _service.setAvailability(isOnline: false);
        if (!mounted) return;
        setState(() => _isOnline = false);
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
    if (_offerDialogOpen ||
        InstantOfferActions.isDialogOpen ||
        !mounted) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isOnline
                ? T.primary(context).withValues(alpha: 0.6)
                : T.outline(context),
            width: _isOnline ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_isOnline ? AppColors.success : T.onSurfaceVariant(context))
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.electric_bolt,
                color: _isOnline ? AppColors.success : T.onSurfaceVariant(context),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.instantRidesTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isOnline
                        ? context.l10n.instantOnlineReady
                        : context.l10n.instantOffline,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isOnline
                          ? AppColors.success
                          : T.onSurfaceVariant(context),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(
                value: _isOnline,
                onChanged: _toggle,
                activeThumbColor: AppColors.success,
              ),
          ],
        ),
      ),
    );
  }
}
