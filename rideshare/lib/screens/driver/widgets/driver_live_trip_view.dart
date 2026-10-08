import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/services/route_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/booking_model.dart';
import '../../../models/trip_model.dart';

/// The driver's page for a trip that is under way — instant or shared.
///
/// One screen, no scrolling: the live map fills the top, and a fixed panel
/// underneath carries only what matters while driving — who is on board, the
/// route, the money, and the two actions (navigate, end the trip). The full
/// management page with seat maps and booking history has no place here.
///
/// Instant rides start with the driver heading to the passenger, so the map
/// shows that leg until the driver reaches the pickup. Shared trips gather
/// before departure, so their passengers are on board from the start.
class DriverLiveTripView extends StatefulWidget {
  const DriverLiveTripView({
    super.key,
    required this.trip,
    required this.bookings,
    required this.driverPosition,
    required this.trackingActive,
    required this.markingArrived,
    required this.onArrived,
    required this.onEnableTracking,
    required this.onChatPassenger,
    required this.phoneOf,
    required this.onCall,
    required this.onNavigate,
    this.onGroupChat,
    this.onBack,
    this.onOpenDetails,
    this.routeService,
  });

  final TripModel trip;

  /// Confirmed bookings on the trip; empty while they load.
  final List<BookingModel> bookings;

  /// The driver's latest GPS fix, fed by the screen's tracking tick.
  final LatLng? driverPosition;
  final bool trackingActive;
  final bool markingArrived;
  final VoidCallback onArrived;
  final VoidCallback onEnableTracking;
  final void Function(BookingModel booking) onChatPassenger;

  /// The passenger's number, or null when they keep it private.
  final String? Function(BookingModel booking) phoneOf;
  final void Function(String phone) onCall;
  final void Function(LatLng target) onNavigate;

  /// Shared trips only.
  final VoidCallback? onGroupChat;

  /// Null when the page is locked until the trip ends (instant rides).
  final VoidCallback? onBack;

  /// Opens the full trip-management page (shared trips).
  final VoidCallback? onOpenDetails;

  @visibleForTesting
  final RouteService? routeService;

  @override
  State<DriverLiveTripView> createState() => _DriverLiveTripViewState();
}

class _DriverLiveTripViewState extends State<DriverLiveTripView> {
  /// Inside this radius of the pickup the passenger is taken to be on board.
  static const _pickupReachedMeters = 150.0;

  /// The driver→pickup leg is re-routed once the driver drifts this far from
  /// where it was last computed.
  static const _rerouteMeters = 400.0;

  late final RouteService _routeService = widget.routeService ?? RouteService();
  GoogleMapController? _mapController;
  bool _cameraFitted = false;

  List<LatLng> _tripRoute = const [];
  List<LatLng> _pickupLeg = const [];
  LatLng? _pickupLegOrigin;
  bool _fetchingPickupLeg = false;
  late bool _passengersOnBoard = !widget.trip.isInstant;

  bool get _isInstant => widget.trip.isInstant;

  LatLng get _pickup =>
      LatLng(widget.trip.from.latitude, widget.trip.from.longitude);
  LatLng get _destination =>
      LatLng(widget.trip.to.latitude, widget.trip.to.longitude);

  @override
  void initState() {
    super.initState();
    _loadTripRoute();
    _onDriverMoved();
  }

  @override
  void didUpdateWidget(covariant DriverLiveTripView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.driverPosition != oldWidget.driverPosition) {
      _onDriverMoved();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Route & map ───────────────────────────────────────────────────────────

  Future<void> _loadTripRoute() async {
    final result = await _routeService.fetchRoute(
      origin: _pickup,
      destination: _destination,
    );
    if (!mounted) return;
    if (result is RouteOk && result.polyline.length >= 2) {
      setState(() => _tripRoute = result.polyline);
      if (!_cameraFitted) _fitCamera();
    }
  }

  void _onDriverMoved() {
    final car = widget.driverPosition;
    if (car == null) return;

    if (!_passengersOnBoard &&
        _distanceMeters(car, _pickup) <= _pickupReachedMeters) {
      setState(() => _passengersOnBoard = true);
    }

    if (!_passengersOnBoard) {
      final origin = _pickupLegOrigin;
      if (origin == null || _distanceMeters(origin, car) > _rerouteMeters) {
        _loadPickupLeg(car);
      }
    }

    if (!_cameraFitted) _fitCamera();
  }

  Future<void> _loadPickupLeg(LatLng car) async {
    if (_fetchingPickupLeg) return;
    _fetchingPickupLeg = true;
    _pickupLegOrigin = car;
    final result = await _routeService.fetchRoute(
      origin: car,
      destination: _pickup,
    );
    _fetchingPickupLeg = false;
    if (!mounted) return;
    if (result is RouteOk && result.polyline.length >= 2) {
      setState(() => _pickupLeg = result.polyline);
    }
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static int _nearestIndex(List<LatLng> route, LatLng p) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < route.length; i++) {
      final dLat = route[i].latitude - p.latitude;
      final dLng = route[i].longitude - p.longitude;
      final d = dLat * dLat + dLng * dLng;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  Set<Marker> _markers(BuildContext context) {
    return {
      if (!_passengersOnBoard)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: context.l10n.instantTripPassengerMarker,
            snippet: widget.trip.from.name,
          ),
        ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.trip.to.name),
      ),
    };
  }

  Set<Polyline> _polylines() {
    final car = widget.driverPosition;
    final tripRoute = _tripRoute.length >= 2
        ? _tripRoute
        : [_pickup, _destination];

    if (!_passengersOnBoard) {
      return {
        // Where the passenger is going, muted until they are on board.
        Polyline(
          polylineId: const PolylineId('trip'),
          points: tripRoute,
          color: AppColors.slate400,
          width: 4,
        ),
        if (car != null)
          Polyline(
            polylineId: const PolylineId('to_pickup'),
            points: _pickupLeg.length >= 2
                ? [car, ..._pickupLeg]
                : [car, _pickup],
            color: AppColors.teal600,
            width: 6,
          ),
      };
    }

    if (car == null) {
      return {
        Polyline(
          polylineId: const PolylineId('trip'),
          points: tripRoute,
          color: AppColors.teal600,
          width: 6,
        ),
      };
    }

    final split = _nearestIndex(tripRoute, car);
    return {
      Polyline(
        polylineId: const PolylineId('trip'),
        points: [car, ...tripRoute.sublist(split)],
        color: AppColors.teal600,
        width: 6,
      ),
    };
  }

  Future<void> _fitCamera() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[
      _destination,
      if (!_passengersOnBoard) _pickup,
      if (widget.driverPosition != null) widget.driverPosition!,
      if (_passengersOnBoard) ..._tripRoute else ..._pickupLeg,
    ];

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    _cameraFitted = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          56,
        ),
      );
    } catch (_) {
      // The map may not be laid out yet; the next fit will catch up.
      _cameraFitted = false;
    }
  }

  String _formatDistance(BuildContext context, double meters) {
    if (meters < 1000) {
      return context.l10n.distanceMetersShort(meters.round().toString());
    }
    return context.l10n.distanceKmShort((meters / 1000).toStringAsFixed(1));
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final target = _passengersOnBoard ? _destination : _pickup;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.driverPosition ?? _pickup,
                    zoom: 14,
                  ),
                  onMapCreated: (c) {
                    _mapController = c;
                    _fitCamera();
                  },
                  padding: EdgeInsets.only(top: media.padding.top + 60),
                  markers: _markers(context),
                  polylines: _polylines(),
                  myLocationEnabled: widget.trackingActive,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                ),
              ),
              Positioned(
                top: media.padding.top + 8,
                left: 12,
                right: 12,
                child: _buildTopBar(context),
              ),
            ],
          ),
        ),
        _buildPanel(context, media, target),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        if (widget.onBack != null) ...[
          _RoundButton(
            icon: const BackButtonIcon(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: widget.onBack!,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: _floatingDecoration(context, radius: 22),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_isInstant ? l10n.instantOfferBadge : l10n.bookingRequestBadge}'
                    ' · ${l10n.statusInProgress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.onOpenDetails != null) ...[
          const SizedBox(width: 8),
          _RoundButton(
            icon: const Icon(IconsaxPlusLinear.document_text),
            tooltip: l10n.liveTripDetails,
            onTap: widget.onOpenDetails!,
          ),
        ],
        const SizedBox(width: 8),
        _RoundButton(
          icon: const Icon(Icons.my_location),
          tooltip: l10n.tripInProgressRecenter,
          onTap: _fitCamera,
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context, MediaQueryData media, LatLng target) {
    final l10n = context.l10n;
    final car = widget.driverPosition;
    final stageText = !_passengersOnBoard
        ? l10n.instantTripHeadingToPickup
        : _isInstant
        ? l10n.instantTripPassengerOnBoard
        : l10n.liveTripHeadingToDestination;
    final away = car == null
        ? null
        : l10n.instantTripAway(
            _formatDistance(context, _distanceMeters(car, target)),
          );

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + media.padding.bottom),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _passengersOnBoard
                    ? IconsaxPlusBold.routing
                    : IconsaxPlusBold.location,
                color: T.primary(context),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stageText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
              if (away != null)
                Text(
                  away,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.primary(context),
                  ),
                ),
            ],
          ),
          if (!widget.trackingActive) ...[
            const SizedBox(height: 10),
            _buildGpsWarning(context),
          ],
          const SizedBox(height: 12),
          _isInstant
              ? _buildSinglePassenger(context)
              : _buildPassengerGroup(context),
          const SizedBox(height: 12),
          _buildRouteLine(context),
          const SizedBox(height: 12),
          _buildFacts(context),
          const SizedBox(height: 14),
          _buildActions(context, target),
        ],
      ),
    );
  }

  Widget _buildGpsWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            IconsaxPlusLinear.location_slash,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.instantTripGpsOff,
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onSurface(context),
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onEnableTracking,
            child: Text(context.l10n.instantTripEnableGps),
          ),
        ],
      ),
    );
  }

  /// Instant ride: the one passenger, with chat and call at hand.
  Widget _buildSinglePassenger(BuildContext context) {
    final booking = widget.bookings.firstOrNull;
    final user = booking?.userPopulated;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name
        : context.l10n.passengerFallback;
    final rating = user?.rating ?? 0;
    final seats = booking?.seatCount ?? widget.trip.totalSeats;
    final phone = booking == null ? null : widget.phoneOf(booking);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Avatar(url: user?.photoUrl, radius: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (rating > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: Color(0xFFFBBF24),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: T.onSurface(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      context.l10n.instantOfferPassengerCount(seats),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _CircleAction(
            icon: IconsaxPlusBold.message,
            tooltip: context.l10n.chat,
            onTap: booking == null
                ? null
                : () => widget.onChatPassenger(booking),
          ),
          const SizedBox(width: 8),
          _CircleAction(
            icon: IconsaxPlusBold.call,
            tooltip: context.l10n.call,
            onTap: phone == null ? null : () => widget.onCall(phone),
          ),
        ],
      ),
    );
  }

  /// Shared trip: everyone on board at a glance; tap for the list with chat
  /// and call per passenger.
  Widget _buildPassengerGroup(BuildContext context) {
    final bookings = widget.bookings;
    final seats = bookings.fold<int>(0, (sum, b) => sum + b.seatCount);
    final shown = bookings.take(4).toList();

    return Material(
      color: T.surfaceVariant(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: bookings.isEmpty ? null : () => _showPassengers(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: shown.isEmpty ? 44 : 44 + (shown.length - 1) * 26.0,
                height: 44,
                child: Stack(
                  children: [
                    if (shown.isEmpty)
                      const _Avatar(url: null, radius: 22)
                    else
                      for (var i = 0; i < shown.length; i++)
                        PositionedDirectional(
                          start: i * 26.0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: T.surfaceVariant(context),
                              shape: BoxShape.circle,
                            ),
                            child: _Avatar(
                              url: shown[i].userPopulated?.photoUrl,
                              radius: 20,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bookings.isEmpty
                      ? context.l10n.liveTripNoPassengers
                      : context.l10n.liveTripPassengersCount(seats),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
              if (widget.onGroupChat != null)
                _CircleAction(
                  icon: IconsaxPlusBold.messages_2,
                  tooltip: context.l10n.tripGroupChat,
                  onTap: widget.onGroupChat,
                ),
              if (bookings.isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_left,
                  color: T.textSecondary(context),
                  textDirection: Directionality.of(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPassengers(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: T.surface(context),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.liveTripPassengersSheetTitle,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.bookings.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: T.outline(context)),
                  itemBuilder: (_, i) {
                    final b = widget.bookings[i];
                    final user = b.userPopulated;
                    final phone = widget.phoneOf(b);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          _Avatar(url: user?.photoUrl, radius: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name.trim().isNotEmpty == true
                                      ? user!.name
                                      : context.l10n.passengerFallback,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: T.onSurface(context),
                                  ),
                                ),
                                Text(
                                  context.l10n.instantOfferPassengerCount(
                                    b.seatCount,
                                  ),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: T.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _CircleAction(
                            icon: IconsaxPlusBold.message,
                            tooltip: context.l10n.chat,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              widget.onChatPassenger(b);
                            },
                          ),
                          const SizedBox(width: 8),
                          _CircleAction(
                            icon: IconsaxPlusBold.call,
                            tooltip: context.l10n.call,
                            onTap: phone == null
                                ? null
                                : () => widget.onCall(phone),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteLine(BuildContext context) {
    Widget stop(Color color, String name, {bool done = false}) {
      return Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: done ? T.textSecondary(context) : T.onSurface(context),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        stop(
          AppColors.success,
          widget.trip.from.name,
          done: _passengersOnBoard,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4.5),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(width: 2, height: 10, color: T.outline(context)),
          ),
        ),
        stop(AppColors.error, widget.trip.to.name),
      ],
    );
  }

  Widget _buildFacts(BuildContext context) {
    final l10n = context.l10n;
    final double money;
    if (_isInstant) {
      money =
          double.tryParse(widget.bookings.firstOrNull?.totalAmount ?? '') ??
          widget.trip.price;
    } else {
      money = widget.bookings.fold<double>(
        0,
        (sum, b) => sum + (double.tryParse(b.totalAmount ?? '') ?? 0),
      );
    }
    final started = widget.trip.tripStartedAt?.toLocal();
    final km = widget.trip.distanceKm;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: T.outline(context)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Fact(
              label: _isInstant
                  ? l10n.instantTripFareLabel
                  : l10n.liveTripRevenueLabel,
              value: '${money.toStringAsFixed(2)} ${widget.trip.currency}',
              caption: _isInstant ? l10n.instantTripCashNote : null,
              emphasize: true,
            ),
          ),
          Expanded(
            child: _Fact(
              label: l10n.tripDistanceShortLabel,
              value: km == null
                  ? '—'
                  : l10n.distanceKmShort(km.toStringAsFixed(1)),
            ),
          ),
          Expanded(
            child: _Fact(
              label: l10n.instantTripStartedLabel,
              value: started == null
                  ? '—'
                  : DateFormat(
                      'h:mm a',
                      Localizations.localeOf(context).toString(),
                    ).format(started),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, LatLng target) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => widget.onNavigate(target),
              icon: const Icon(IconsaxPlusLinear.routing_2),
              label: Text(context.l10n.instantTripNavigate),
              style: OutlinedButton.styleFrom(
                foregroundColor: T.primary(context),
                side: BorderSide(color: T.primary(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: widget.markingArrived ? null : widget.onArrived,
              icon: widget.markingArrived
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(IconsaxPlusBold.tick_circle),
              label: Text(
                widget.markingArrived
                    ? context.l10n.endingInProgress
                    : context.l10n.arrivedAtDestination,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

BoxDecoration _floatingDecoration(BuildContext context, {double radius = 22}) {
  return BoxDecoration(
    color: T.surface(context),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: T.shadow(context).withValues(alpha: 0.12),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.radius});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: T.primaryContainer(context),
      backgroundImage: hasPhoto ? CachedNetworkImageProvider(url!) : null,
      child: hasPhoto
          ? null
          : Icon(
              IconsaxPlusBold.profile,
              color: T.primary(context),
              size: radius,
            ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: _floatingDecoration(context),
      child: IconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: onTap,
        color: T.onSurface(context),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? T.primaryContainer(context)
            : T.outline(context).withValues(alpha: 0.3),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 19,
              color: enabled ? T.primary(context) : T.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.caption,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: T.textSecondary(context),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: emphasize ? T.primary(context) : T.onSurface(context),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 1),
          Text(
            caption!,
            style: AppTextStyles.labelSmall.copyWith(
              color: T.textSecondary(context),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}
