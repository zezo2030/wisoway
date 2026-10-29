import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/websocket_service.dart';
import '../../../core/errors/failure.dart';
import '../../../core/services/instant_offer_actions.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/instant_ride_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/ui/error_surface.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/instant_offer_dialog.dart';
import 'driver_home_cards.dart';

/// Driver-facing instant-ride control: a go-online toggle that, while online,
/// streams the driver's location (heartbeat) and polls for incoming ride
/// offers — presenting each as a countdown accept/decline dialog.
class DriverAvailabilityCard extends StatefulWidget {
  const DriverAvailabilityCard({
    super.key,
    this.onOnlineChanged,
    this.onLocationSent,
  });

  /// Every location the server accepted while online — the dashboard's
  /// location card shows this, the position rides are dispatched by.
  final void Function(double latitude, double longitude)? onLocationSent;

  /// Fires whenever the online state settles, so the surrounding dashboard can
  /// mirror it (the header's presence dot).
  final ValueChanged<bool>? onOnlineChanged;

  @override
  State<DriverAvailabilityCard> createState() => _DriverAvailabilityCardState();
}

class _DriverAvailabilityCardState extends State<DriverAvailabilityCard>
    with WidgetsBindingObserver {
  final InstantRideService _service = InstantRideService();
  final LocationService _location = LocationService();

  bool _isOnline = false;
  bool _busy = true;
  Timer? _heartbeatTimer;
  Timer? _offerPollTimer;

  /// While online, a location stream — on Android a foreground service with
  /// an «أنت متصل» notification. It keeps the heartbeat going with the screen
  /// locked or the app in the background; without it the server stopped
  /// seeing the driver a minute after the screen went off, and offers never
  /// reached them.
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  DateTime? _lastHeartbeatAt;

  /// Last time the server accepted the driver's location.
  DateTime? _lastLocationSentAt;
  bool _offerDialogOpen = false;

  bool get _appVisible =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  final WebSocketService _socket = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _offerSub;
  StreamSubscription<Map<String, dynamic>>? _offerClosedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
    // The socket tells an open app about an offer the moment it is made, so
    // the card doesn't wait for the next poll or a slow push.
    _socket.connect();
    _offerSub = _socket.onInstantOffer.listen((_) {
      if (_isOnline) _pollForOffer();
    });
    _offerClosedSub = _socket.onInstantOfferClosed.listen((data) {
      final offerId = data['offerId']?.toString() ?? '';
      if (offerId.isEmpty) return;
      InstantOfferDialog.dismissOffer(offerId);
      PushNotificationService.cancelAndroidInstantOfferNotification(offerId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offerSub?.cancel();
    _offerClosedSub?.cancel();
    _heartbeatTimer?.cancel();
    _offerPollTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background or the lock screen: an offer that rang in the
    // tray meanwhile should be on screen now, not up to a poll interval later.
    if (state == AppLifecycleState.resumed) unawaited(_loadStatus());
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
      if (status.isOnline) {
        _startTimers();
        unawaited(_pollForOffer());
        // Drivers who stay online never toggle: check once per app run.
        if (!_offerDeliveryChecked) unawaited(_checkOfferDelivery());
      } else {
        _stopTimers();
      }
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
        final status = await _service.setAvailability(
          isOnline: true,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        if (!mounted) return;
        // Going online carried a location too.
        _lastLocationSentAt = DateTime.now();
        widget.onLocationSent?.call(pos.latitude, pos.longitude);
        setState(() => _isOnline = status.isOnline);
        widget.onOnlineChanged?.call(status.isOnline);
        if (status.isOnline) {
          _startTimers();
          unawaited(_checkOfferDelivery());
        } else {
          _stopTimers();
        }
      } else {
        _stopTimers();
        await _service.setAvailability(isOnline: false);
        if (!mounted) return;
        setState(() => _isOnline = false);
        widget.onOnlineChanged?.call(false);
      }
    } catch (e) {
      if (mounted) {
        final failure = ApiClient.mapError(e);
        if (failure.nextAction == FailureAction.topUpWallet) {
          _stopTimers();
          setState(() => _isOnline = false);
          widget.onOnlineChanged?.call(false);
        }
        ErrorSurface.showFailure(context, failure);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTimers() {
    _startLocationStream();
    // Report straight away rather than 12 s from now, so a driver back from a
    // closed app is visible to dispatch at once.
    unawaited(_sendHeartbeat());
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
    _positionSub?.cancel();
    _positionSub = null;
    _lastPosition = null;
  }

  void _startLocationStream() {
    if (_positionSub != null) return;
    final l10n = context.l10n;
    final LocationSettings settings =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 30,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: l10n.driverOnlineServiceTitle,
              notificationText: l10n.driverOnlineServiceText,
              notificationChannelName: l10n.driverOnlineServiceTitle,
              notificationIcon: const AndroidResource(
                name: 'notification_icon',
                defType: 'drawable',
              ),
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 30,
          );
    try {
      _positionSub = Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            (pos) {
              _lastPosition = pos;
              // A moving driver reports promptly; a parked one still gets the
              // timer's heartbeat.
              final last = _lastHeartbeatAt;
              if (last == null ||
                  DateTime.now().difference(last).inSeconds >= 10) {
                _sendHeartbeat();
              }
            },
            onError: (_) {
              // Permission or GPS trouble: the timer falls back to one-off fixes.
            },
          );
    } catch (_) {
      _positionSub = null;
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      // The stream's last fix works with the screen off; a one-off fix
      // (needs the app in the foreground) is only the fallback.
      final last = _lastPosition;
      final fresh =
          last != null &&
          DateTime.now().difference(last.timestamp).inSeconds < 60;
      final pos = fresh ? last : await _location.getCurrentPosition();
      _lastHeartbeatAt = DateTime.now();
      final status = await _service.heartbeat(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (!mounted) return;
      if (!status.isOnline) {
        _stopTimers();
        setState(() => _isOnline = false);
        widget.onOnlineChanged?.call(false);
        return;
      }
      _lastLocationSentAt = DateTime.now();
      widget.onLocationSent?.call(pos.latitude, pos.longitude);
    } catch (_) {
      // Transient — the next tick will retry.
    }
    // Re-evaluate the "requests may not reach you" warning either way.
    if (mounted) setState(() {});
  }

  /// The server stops offering rides to a driver whose location is older than
  /// this (DriverAvailabilityService.staleThresholdMs) — past it, the driver
  /// looks online here but is invisible to dispatch.
  static const _serverStaleAfter = Duration(seconds: 60);

  bool get _locationStale {
    if (!_isOnline) return false;
    final sent = _lastLocationSentAt;
    return sent == null || DateTime.now().difference(sent) > _serverStaleAfter;
  }

  /// Android 14+: without full-screen notifications an offer can't wake a
  /// locked phone. Ask the driver to allow it when they go online.
  /// Everything a ride request needs to reach a driver whose app is closed:
  /// notifications on, no battery optimization (Android otherwise puts the
  /// app to sleep and drops its pushes), and full-screen notifications.
  static bool _offerDeliveryChecked = false;

  Future<void> _checkOfferDelivery() async {
    _offerDeliveryChecked = true;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _checkNotificationsAllowed();
      await _checkBatteryOptimization();
    }
    await _checkOverLockScreen();
  }

  Future<void> _checkNotificationsAllowed() async {
    try {
      var status = await Permission.notification.status;
      if (status.isGranted) return;
      status = await Permission.notification.request();
      if (status.isGranted || !mounted) return;
      final l10n = context.l10n;
      final open = await _askToFix(
        title: l10n.offersNotificationsTitle,
        body: l10n.offersNotificationsBody,
        action: l10n.offersOverLockAction,
      );
      if (open) await openAppSettings();
    } catch (_) {}
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      if (await Permission.ignoreBatteryOptimizations.isGranted) return;
      if (!mounted) return;
      final l10n = context.l10n;
      final allow = await _askToFix(
        title: l10n.offersBatteryTitle,
        body: l10n.offersBatteryBody,
        action: l10n.offersBatteryAction,
      );
      if (allow) await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}
  }

  Future<bool> _askToFix({
    required String title,
    required String body,
    required String action,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(IconsaxPlusBold.notification_bing, size: 32),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.close),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return yes == true;
  }

  Future<void> _checkOverLockScreen() async {
    if (await PushNotificationService.canShowOffersOverLockScreen()) return;
    if (!mounted) return;
    final l10n = context.l10n;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(IconsaxPlusBold.notification_bing, size: 32),
        title: Text(l10n.offersOverLockTitle),
        content: Text(l10n.offersOverLockBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.close),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.offersOverLockAction),
          ),
        ],
      ),
    );
    if (open == true)
      await PushNotificationService.openOverLockScreenSettings();
  }

  Future<void> _pollForOffer() async {
    if (_offerDialogOpen ||
        InstantOfferActions.isDialogOpen ||
        InstantOfferDialog.visibleOfferId != null ||
        !mounted) {
      return;
    }
    // Timers keep firing while the app is backgrounded or the screen is
    // locked. Opening the card then would take down the ringing tray
    // notification for a dialog nobody can see — leave the offer to the
    // notification, and pick it up here once the driver is back.
    if (!_appVisible) return;
    try {
      final offer = await _service.getPendingOffer();
      if (offer == null || offer.id.isEmpty || !mounted || !_appVisible) {
        return;
      }
      if (InstantOfferDialog.visibleOfferId != null) return;
      _offerDialogOpen = true;
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
                      _locationStale
                          ? l10n.instantLocationNotReaching
                          : _isOnline
                          ? l10n.instantOnlineReady
                          : l10n.instantGoOnlineHint,
                      key: const ValueKey('availability-status-line'),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: _locationStale ? FontWeight.w700 : null,
                        color: _locationStale
                            ? AppColors.error
                            : T.onSurfaceVariant(context),
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
