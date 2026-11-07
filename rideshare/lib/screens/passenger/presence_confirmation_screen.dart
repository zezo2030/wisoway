import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/constants/route_names.dart';
import '../../core/api/websocket_service.dart';
import '../../core/services/presence_service.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/presence_models.dart';
import '../../models/vehicle_colors.dart';
import 'widgets/seat_presence_panel.dart';

class PresenceConfirmationScreen extends StatefulWidget {
  const PresenceConfirmationScreen({
    super.key,
    required this.bookingId,
    this.presenceGateway,
  });

  final String bookingId;
  final PresenceGateway? presenceGateway;

  @override
  State<PresenceConfirmationScreen> createState() =>
      _PresenceConfirmationScreenState();
}

class _PresenceConfirmationScreenState
    extends State<PresenceConfirmationScreen> {
  late final PresenceGateway _presenceGateway;
  late final Timer _clock;
  PresencePrompt? _prompt;
  DateTime? _loadedAt;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _presenceGateway = widget.presenceGateway ?? PresenceService();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _prompt != null) setState(() {});
    });
    _loadPrompt();
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _loadPrompt() async {
    setState(() => _loadError = null);
    try {
      final prompt = await _presenceGateway.getPrompt(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _prompt = prompt;
        _loadedAt = DateTime.now();
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  bool _windowIsOpen(PresencePrompt prompt) {
    final now = DateTime.now();
    return prompt.window.isOpen &&
        !now.isBefore(prompt.window.opensAt) &&
        !now.isAfter(prompt.window.closesAt);
  }

  Duration _departureRemaining(PresencePrompt prompt) {
    final loadedAt = _loadedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(loadedAt).inSeconds;
    return Duration(
      seconds: math.max(prompt.secondsUntilDeparture - elapsed, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const _PresenceHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return _PresenceLoadError(onRetry: _loadPrompt);
    }
    final prompt = _prompt;
    if (prompt == null) return const _PresenceLoading();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _DriverCard(
          prompt: prompt,
          departureRemaining: _departureRemaining(prompt),
        ),
        const SizedBox(height: 12),
        _PickupMapCard(prompt: prompt),
        const SizedBox(height: 16),
        _buildQuestionSection(prompt),
      ],
    );
  }

  Widget _buildQuestionSection(PresencePrompt prompt) {
    if (!prompt.needsAnswers) return const _PresenceConfirmedCard();
    if (!_windowIsOpen(prompt)) return const _PresenceClosedCard();
    return SeatPresencePanel(
      prompt: prompt,
      gateway: _presenceGateway,
      onChanged: (prompt) => setState(() => _prompt = prompt),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _PresenceHeader extends StatelessWidget {
  const _PresenceHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            semanticsLabel: MaterialLocalizations.of(context).closeButtonLabel,
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Text(
                  context.l10n.presenceScreenTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.presenceScreenSubtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: T.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HelpChip(
            onPressed: () => Navigator.pushNamed(context, RouteNames.support),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: T.surface(context),
        shape: CircleBorder(side: BorderSide(color: T.outlineVariant(context))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 26, color: T.onSurface(context)),
          ),
        ),
      ),
    );
  }
}

class _HelpChip extends StatelessWidget {
  const _HelpChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.teal50,
      shape: StadiumBorder(side: BorderSide(color: AppColors.teal200)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.headset_mic_outlined,
                size: 15,
                color: AppColors.teal600,
              ),
              const SizedBox(width: 4),
              Text(
                context.l10n.presenceHelp,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.teal600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Driver card ──────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.prompt, required this.departureRemaining});

  final PresencePrompt prompt;
  final Duration departureRemaining;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: _DriverIdentity(
                driver: prompt.driver,
                vehicle: prompt.vehicle,
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(width: 88, height: 64, child: _VehicleImage()),
            const SizedBox(width: 8),
            Container(width: 1, height: 72, color: T.outlineVariant(context)),
            const SizedBox(width: 8),
            SizedBox(
              width: 86,
              child: _DepartureCountdown(remaining: departureRemaining),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverIdentity extends StatelessWidget {
  const _DriverIdentity({required this.driver, required this.vehicle});

  final PresenceDriver? driver;
  final PresenceVehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DriverAvatar(photoUrl: driver?.photoUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver?.name.isNotEmpty == true ? driver!.name : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _ratingLabel(driver),
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: T.textSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _vehicleLabel(context, vehicle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: T.textSecondary(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: T.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: T.outlineVariant(context)),
                ),
                child: Text(
                  vehicle?.plateNumber.isNotEmpty == true
                      ? vehicle!.plateNumber
                      : '—',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _ratingLabel(PresenceDriver? driver) {
    final rating = driver?.rating;
    if (rating == null) return '—';
    return '${rating.toStringAsFixed(1)} (${driver?.ratingCount ?? 0})';
  }

  /// "سيدان • كامري • أبيض": the colour last, as the passenger looks for it.
  String _vehicleLabel(BuildContext context, PresenceVehicle? vehicle) {
    final color = vehicle?.color;
    final parts = <String?>[
      vehicle?.vehicleType,
      vehicle?.model,
      if (color != null) vehicleColorLabel(context.l10n, color),
    ].where((part) => part?.trim().isNotEmpty == true);
    return parts.map((part) => part!.trim()).join(' • ');
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/presence_driver_fallback.png',
      fit: BoxFit.cover,
    );
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: T.outlineVariant(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl?.isNotEmpty == true
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage();

  @override
  Widget build(BuildContext context) {
    // TEMP: design mock car until vehicle photos are reliable.
    return const Image(
      image: AssetImage('assets/images/presence_vehicle_fallback.png'),
      fit: BoxFit.contain,
    );
  }
}

class _DepartureCountdown extends StatelessWidget {
  const _DepartureCountdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _durationLabel(remaining);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.presenceDriverStartsAfter,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: T.textSecondary(context),
            height: 1.2,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          label: timeLabel,
          child: Text(
            timeLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: T.primary(context),
              fontWeight: FontWeight.w800,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(IconsaxPlusLinear.clock, size: 12, color: T.primary(context)),
            const SizedBox(width: 3),
            Text(
              context.l10n.presenceMinutes,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: T.textSecondary(context),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Pickup + map ─────────────────────────────────────────────────────────────

class _PickupMapCard extends StatelessWidget {
  const _PickupMapCard({required this.prompt});

  final PresencePrompt prompt;

  @override
  Widget build(BuildContext context) {
    final address = prompt.pickup.address?.trim();

    return _CardShell(
      child: SizedBox(
        height: 132,
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.teal50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconsaxPlusBold.location,
                            size: 13,
                            color: T.primary(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.presencePickupTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: T.primary(context),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prompt.pickup.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (address != null && address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '($address)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: T.textSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: _PresenceMap(
                tripId: prompt.tripId,
                pickup: prompt.pickup,
                initialDriverLocation: prompt.driverLocation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenceMap extends StatefulWidget {
  const _PresenceMap({
    required this.tripId,
    required this.pickup,
    this.initialDriverLocation,
  });

  final String tripId;
  final PresencePoint pickup;
  final PresenceDriverLocation? initialDriverLocation;

  @override
  State<_PresenceMap> createState() => _PresenceMapState();
}

class _PresenceMapState extends State<_PresenceMap> {
  final WebSocketService _socketService = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _trackingSubscription;

  GoogleMapController? _controller;
  BitmapDescriptor? _carIcon;
  bool _iconReady = false;
  LatLng? _driverLatLng;
  double _driverHeading = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDriverLocation;
    if (initial != null) {
      _driverLatLng = LatLng(initial.latitude, initial.longitude);
    }
    _loadCarIcon();
    _startLiveTracking();
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    if (widget.tripId.isNotEmpty) {
      _socketService.unsubscribeFromTripTracking(widget.tripId);
    }
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadCarIcon() async {
    try {
      final data = await rootBundle.load('assets/images/presence_map_car.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 84,
      );
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (bytes == null || !mounted) return;
      setState(() {
        _carIcon = BitmapDescriptor.bytes(
          bytes.buffer.asUint8List(),
          imagePixelRatio: 3,
        );
        _iconReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _iconReady = true);
    }
  }

  Future<void> _startLiveTracking() async {
    if (widget.tripId.isEmpty) return;
    try {
      await _socketService.connect();
      _socketService.subscribeToTripTracking(widget.tripId);
      _trackingSubscription = _socketService.onTrackingUpdate.listen((payload) {
        final payloadTripId = payload['tripId']?.toString();
        if (payloadTripId != null && payloadTripId != widget.tripId) return;

        final lat = payload['latitude'];
        final lng = payload['longitude'];
        if (lat is! num || lng is! num) return;

        final next = LatLng(lat.toDouble(), lng.toDouble());
        final headingRaw = payload['heading'];
        final heading = headingRaw is num
            ? headingRaw.toDouble()
            : _driverHeading;

        if (!mounted) return;
        setState(() {
          _driverLatLng = next;
          _driverHeading = heading;
        });
        _followDriver(next);
      });
    } catch (_) {
      // Keep last known location from the presence prompt if socket fails.
    }
  }

  Future<void> _followDriver(LatLng driver) async {
    final controller = _controller;
    if (controller == null || !widget.pickup.hasCoordinates) return;
    try {
      final pickup = LatLng(widget.pickup.latitude!, widget.pickup.longitude!);
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              math.min(pickup.latitude, driver.latitude),
              math.min(pickup.longitude, driver.longitude),
            ),
            northeast: LatLng(
              math.max(pickup.latitude, driver.latitude),
              math.max(pickup.longitude, driver.longitude),
            ),
          ),
          40,
        ),
      );
    } catch (_) {
      await controller.animateCamera(CameraUpdate.newLatLng(driver));
    }
  }

  LatLng get _pickup =>
      LatLng(widget.pickup.latitude!, widget.pickup.longitude!);

  Set<Marker> get _markers {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: widget.pickup.name),
      ),
    };

    final driver = _driverLatLng;
    if (driver != null && _iconReady) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver-live'),
          position: driver,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _driverHeading,
          icon:
              _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: context.l10n.driverLocationTitle),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pickup.hasCoordinates) {
      return ColoredBox(
        color: T.surfaceVariant(context),
        child: Icon(IconsaxPlusBold.location, color: T.primary(context)),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _driverLatLng ?? _pickup,
        zoom: 15.6,
      ),
      markers: _markers,
      circles: {
        Circle(
          circleId: const CircleId('radius'),
          center: _pickup,
          radius: 65,
          fillColor: AppColors.teal500.withValues(alpha: 0.15),
          strokeColor: AppColors.teal600.withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      },
      onMapCreated: (controller) async {
        _controller = controller;
        final driver = _driverLatLng;
        if (driver != null) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (mounted) await _followDriver(driver);
        }
      },
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: false,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

class _PresenceConfirmedCard extends StatelessWidget {
  const _PresenceConfirmedCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              IconsaxPlusBold.tick_circle,
              size: 48,
              color: T.primary(context),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.presenceConfirmedTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.presenceConfirmedBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenceClosedCard extends StatelessWidget {
  const _PresenceClosedCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              IconsaxPlusLinear.clock,
              color: T.textSecondary(context),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.presenceWindowClosedTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.presenceWindowClosedBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenceLoading extends StatelessWidget {
  const _PresenceLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: T.primary(context)),
          const SizedBox(height: 12),
          Text(context.l10n.loading),
        ],
      ),
    );
  }
}

class _PresenceLoadError extends StatelessWidget {
  const _PresenceLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconsaxPlusLinear.info_circle,
              size: 48,
              color: T.error(context),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.presenceLoadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outlineVariant(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _durationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
