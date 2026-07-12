import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/instant_ride_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/ui/error_surface.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/instant_ride_models.dart';

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
    if (_offerDialogOpen || !mounted) return;
    try {
      final offer = await _service.getPendingOffer();
      if (offer == null || offer.id.isEmpty || !mounted) return;
      _offerDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _InstantOfferDialog(offer: offer, service: _service),
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

/// Modal shown to a driver for an incoming instant offer, with a live countdown.
class _InstantOfferDialog extends StatefulWidget {
  final InstantOffer offer;
  final InstantRideService service;

  const _InstantOfferDialog({required this.offer, required this.service});

  @override
  State<_InstantOfferDialog> createState() => _InstantOfferDialogState();
}

class _InstantOfferDialogState extends State<_InstantOfferDialog> {
  late int _secondsLeft;
  late final int _totalSeconds;
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final expiresAt = widget.offer.expiresAt;
    final remaining = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inSeconds
        : 12;
    _secondsLeft = remaining.clamp(1, 60);
    _totalSeconds = _secondsLeft;
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
      await widget.service.acceptOffer(widget.offer.id);
      _ticker?.cancel();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.instantRideAcceptedToast),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
      // Offer likely taken/expired — close so polling can resume.
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.declineOffer(widget.offer.id);
    } catch (_) {
      // ignore — closing either way
    }
    _ticker?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.offer.request;
    final fare = req?.fareEstimate;
    return AlertDialog(
      title: Text(context.l10n.instantOfferTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(context, Icons.trip_origin, req?.fromName ?? '—'),
          const SizedBox(height: 8),
          _line(context, Icons.location_on, req?.toName ?? '—'),
          if (fare != null) ...[
            const SizedBox(height: 8),
            _line(
              context,
              Icons.payments_outlined,
              '$fare ${req?.currency ?? ''}',
            ),
          ],
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _totalSeconds == 0 ? 0 : _secondsLeft / _totalSeconds,
            backgroundColor: T.outline(context).withValues(alpha: 0.3),
            color: T.primary(context),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              context.l10n.instantOfferCountdown(_secondsLeft),
              style: TextStyle(fontSize: 12, color: T.onSurfaceVariant(context)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _decline,
          child: Text(context.l10n.instantDecline),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _accept,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Text(context.l10n.instantAccept),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: T.primary(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: T.onSurface(context))),
        ),
      ],
    );
  }
}
