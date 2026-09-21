import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/route_names.dart';
import '../../core/api/websocket_service.dart';
import '../../core/services/presence_service.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/presence_models.dart';

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
  PassengerPresenceStatus? _selectedStatus;
  PassengerPresenceStatus? _submittingStatus;
  DateTime? _loadedAt;
  Object? _loadError;
  bool _isEditing = true;

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
        _selectedStatus = prompt.declaredStatus;
        _loadedAt = DateTime.now();
        _isEditing = prompt.declaredStatus == null;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _submit(PassengerPresenceStatus status) async {
    final prompt = _prompt;
    if (prompt == null || !_windowIsOpen(prompt)) return;
    setState(() => _submittingStatus = status);

    try {
      final seatNumbers = prompt.seats.map((seat) => seat.seatNumber).toList();
      await _presenceGateway.declare(widget.bookingId, status, seatNumbers);
      if (!mounted) return;
      setState(() {
        _selectedStatus = status;
        _submittingStatus = null;
        _isEditing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.presenceSubmitFailed)),
      );
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

  Duration _windowRemaining(PresencePrompt prompt) {
    final seconds = prompt.window.closesAt.difference(DateTime.now()).inSeconds;
    return Duration(seconds: math.max(seconds, 0));
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
    final windowOpen = _windowIsOpen(prompt);
    if (!windowOpen) {
      return _PresenceClosedCard(selectedStatus: _selectedStatus);
    }
    if (_selectedStatus != null && !_isEditing) {
      return _PresenceConfirmedCard(
        status: _selectedStatus!,
        onEdit: () => setState(() => _isEditing = true),
      );
    }
    return _PresenceQuestionSection(
      selectedStatus: _selectedStatus,
      submittingStatus: _submittingStatus,
      windowRemaining: _windowRemaining(prompt),
      onSelected: _submit,
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
        shape: CircleBorder(
          side: BorderSide(color: T.outlineVariant(context)),
        ),
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
  const _DriverCard({
    required this.prompt,
    required this.departureRemaining,
  });

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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                _vehicleLabel(vehicle),
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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

  String _vehicleLabel(PresenceVehicle? vehicle) {
    final parts = [
      vehicle?.vehicleType,
      vehicle?.model,
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
      final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
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
        final heading = headingRaw is num ? headingRaw.toDouble() : _driverHeading;

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

// ── Question + actions ───────────────────────────────────────────────────────

class _PresenceQuestionSection extends StatelessWidget {
  const _PresenceQuestionSection({
    required this.selectedStatus,
    required this.submittingStatus,
    required this.windowRemaining,
    required this.onSelected,
  });

  final PassengerPresenceStatus? selectedStatus;
  final PassengerPresenceStatus? submittingStatus;
  final Duration windowRemaining;
  final ValueChanged<PassengerPresenceStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: T.primary(context).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            IconsaxPlusBold.notification,
            color: T.primary(context),
            size: 24,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.presenceQuestionTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.presenceQuestionSubtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: T.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        const _PresenceInfoBox(),
        const SizedBox(height: 12),
        _PresenceActions(
          selectedStatus: selectedStatus,
          submittingStatus: submittingStatus,
          onSelected: onSelected,
        ),
        const SizedBox(height: 14),
        const _PrivacyLine(),
        const SizedBox(height: 10),
        _RequestCountdown(remaining: windowRemaining),
      ],
    );
  }
}

class _PresenceInfoBox extends StatelessWidget {
  const _PresenceInfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              context.l10n.presenceInfoBody,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: T.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: T.primary(context),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline, size: 13, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PresenceActions extends StatelessWidget {
  const _PresenceActions({
    required this.selectedStatus,
    required this.submittingStatus,
    required this.onSelected,
  });

  final PassengerPresenceStatus? selectedStatus;
  final PassengerPresenceStatus? submittingStatus;
  final ValueChanged<PassengerPresenceStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _PresenceActionSpec.inVehicle(context),
      _PresenceActionSpec.onMyWay(context),
      _PresenceActionSpec.notRiding(context),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _PresenceActionCard(
                spec: actions[i],
                selectedStatus: selectedStatus,
                submittingStatus: submittingStatus,
                onPressed: () => onSelected(actions[i].status),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresenceActionCard extends StatelessWidget {
  const _PresenceActionCard({
    required this.spec,
    required this.selectedStatus,
    required this.submittingStatus,
    required this.onPressed,
  });

  final _PresenceActionSpec spec;
  final PassengerPresenceStatus? selectedStatus;
  final PassengerPresenceStatus? submittingStatus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = selectedStatus == spec.status;
    final submitting = submittingStatus == spec.status;
    final disabled = submittingStatus != null;
    final filled = spec.status == PassengerPresenceStatus.inVehicle;
    final foreground = filled ? Colors.white : T.onSurface(context);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: filled
            ? T.primary(context)
            : selected
            ? T.primary(context).withValues(alpha: 0.08)
            : T.surface(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled || selected
                    ? T.primary(context)
                    : T.outlineVariant(context),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: filled
                        ? Colors.transparent
                        : spec.tintColor,
                    shape: BoxShape.circle,
                    border: filled
                        ? Border.all(color: Colors.white, width: 1.5)
                        : null,
                  ),
                  child: submitting
                      ? Padding(
                          padding: const EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: filled ? Colors.white : spec.iconColor,
                          ),
                        )
                      : Icon(
                          filled ? Icons.check_rounded : spec.icon,
                          size: 17,
                          color: filled ? Colors.white : spec.iconColor,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  spec.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: filled
                        ? Colors.white.withValues(alpha: 0.85)
                        : T.textSecondary(context),
                    height: 1.2,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 16, color: T.textSecondary(context)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.l10n.presencePrivacyLine,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: T.textSecondary(context),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestCountdown extends StatelessWidget {
  const _RequestCountdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final label = _durationLabel(remaining);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            IconsaxPlusLinear.clock,
            size: 16,
            color: T.textSecondary(context),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.l10n.presenceRequestEndsAfter,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              label,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: T.primary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

class _PresenceConfirmedCard extends StatelessWidget {
  const _PresenceConfirmedCard({required this.status, required this.onEdit});

  final PassengerPresenceStatus status;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusBold.tick_circle,
                size: 34,
                color: T.primary(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.presenceConfirmedTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.presenceConfirmedBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _PresenceStatusPill(status: status),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.l10n.presenceEdit),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenceClosedCard extends StatelessWidget {
  const _PresenceClosedCard({required this.selectedStatus});

  final PassengerPresenceStatus? selectedStatus;

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
            if (selectedStatus != null) ...[
              const SizedBox(height: 14),
              _PresenceStatusPill(status: selectedStatus!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresenceStatusPill extends StatelessWidget {
  const _PresenceStatusPill({required this.status});

  final PassengerPresenceStatus status;

  @override
  Widget build(BuildContext context) {
    final spec = _PresenceActionSpec.forStatus(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: spec.tintColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 18, color: spec.iconColor),
          const SizedBox(width: 6),
          Text(
            spec.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: spec.iconColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

class _PresenceActionSpec {
  const _PresenceActionSpec({
    required this.status,
    required this.title,
    required this.subtitle,
    required this.appearance,
  });

  final PassengerPresenceStatus status;
  final String title;
  final String subtitle;
  final _PresenceActionAppearance appearance;
  IconData get icon => appearance.icon;
  Color get iconColor => appearance.iconColor;
  Color get tintColor => appearance.tintColor;

  factory _PresenceActionSpec.inVehicle(BuildContext context) {
    return _PresenceActionSpec(
      status: PassengerPresenceStatus.inVehicle,
      title: context.l10n.presenceInVehicleTitle,
      subtitle: context.l10n.presenceInVehicleSubtitle,
      appearance: _PresenceActionAppearance(
        icon: Icons.check_rounded,
        iconColor: T.primary(context),
        tintColor: T.primary(context).withValues(alpha: 0.1),
      ),
    );
  }

  factory _PresenceActionSpec.onMyWay(BuildContext context) {
    return _PresenceActionSpec(
      status: PassengerPresenceStatus.onMyWay,
      title: context.l10n.presenceOnMyWayTitle,
      subtitle: context.l10n.presenceOnMyWaySubtitle,
      appearance: _PresenceActionAppearance(
        icon: Icons.directions_walk_rounded,
        iconColor: AppColors.warningDark,
        tintColor: AppColors.warning.withValues(alpha: 0.13),
      ),
    );
  }

  factory _PresenceActionSpec.notRiding(BuildContext context) {
    return _PresenceActionSpec(
      status: PassengerPresenceStatus.notRiding,
      title: context.l10n.presenceNotRidingTitle,
      subtitle: context.l10n.presenceNotRidingSubtitle,
      appearance: _PresenceActionAppearance(
        icon: Icons.close_rounded,
        iconColor: AppColors.errorDark,
        tintColor: AppColors.error.withValues(alpha: 0.12),
      ),
    );
  }

  factory _PresenceActionSpec.forStatus(
    BuildContext context,
    PassengerPresenceStatus status,
  ) {
    return switch (status) {
      PassengerPresenceStatus.inVehicle =>
        _PresenceActionSpec.inVehicle(context),
      PassengerPresenceStatus.onMyWay => _PresenceActionSpec.onMyWay(context),
      PassengerPresenceStatus.notRiding =>
        _PresenceActionSpec.notRiding(context),
    };
  }
}

class _PresenceActionAppearance {
  const _PresenceActionAppearance({
    required this.icon,
    required this.iconColor,
    required this.tintColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color tintColor;
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
