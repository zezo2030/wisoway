import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/support_constants.dart';
import '../../core/api/websocket_service.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/active_ride_navigator.dart';
import '../../core/services/route_service.dart';
import '../../core/services/share_link_service.dart';
import '../../core/services/trip_emergency_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/booking_model.dart';
import '../../models/trip_model.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/trip/share_tracking_sheet.dart';

/// Where an instant ride stands. The trip is `in_progress` from the moment a
/// driver accepts, so the status alone can't tell the passenger whether the
/// driver is still coming, waiting outside, or already driving them.
enum _RidePhase { approaching, arrived, riding }

class TripInProgressScreen extends StatefulWidget {
  final String tripId;
  final BookingModel? initialBooking;
  final bool showTrackingShare;

  /// Instant rides: the passenger stays on this screen until the trip ends —
  /// no back navigation — and is moved on to rating when it completes.
  final bool lockedUntilEnd;

  const TripInProgressScreen({
    super.key,
    required this.tripId,
    this.initialBooking,
    this.showTrackingShare = false,
    this.lockedUntilEnd = false,
  });

  @override
  State<TripInProgressScreen> createState() => _TripInProgressScreenState();
}

class _TripInProgressScreenState extends State<TripInProgressScreen> {
  static const _vehicleFallback =
      'assets/images/trip_in_progress/vehicle_fallback.png';
  static const _avatarFallback =
      'assets/images/trip_in_progress/driver_avatar.png';
  static const _mapCarAsset = 'assets/images/presence_map_car.png';

  TripModel? _trip;
  bool _loading = true;
  bool _emergencyLoading = false;
  bool _shareLoading = false;
  GoogleMapController? _mapController;
  BitmapDescriptor? _carIcon;
  LatLng? _liveDriverLocation;
  double? _remainingDistanceKm;
  int? _remainingDurationSeconds;
  DateTime? _etaAt;
  double _progressPercent = 0;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  // Road-following route from the directions API; empty until it arrives
  // (or when it is unavailable, in which case straight segments are drawn).
  List<LatLng> _roadRoute = const [];
  MapType _mapType = MapType.normal;

  final WebSocketService _socketService = WebSocketService();
  final ShareLinkService _shareLinkService = ShareLinkService();
  final TripEmergencyService _emergencyService = TripEmergencyService();
  final RouteService _routeService = RouteService();
  StreamSubscription<Map<String, dynamic>>? _trackingSubscription;
  Timer? _statusPoll;
  bool _leaving = false;

  /// The trip was seen still running here, so its end is this ride's end.
  bool _sawTripLive = false;

  /// Approach speed for the driver→pickup estimate, matching the server's
  /// PICKUP_ETA_SPEED_KMH; the straight line is stretched to road length.
  static const double _approachSpeedKmh = 25;
  static const double _roadFactor = 1.3;

  _RidePhase get _phase {
    final trip = _trip;
    if (trip == null || !trip.isInstant || trip.tripStartedAt != null) {
      return _RidePhase.riding;
    }
    return trip.driverArrivedAt != null
        ? _RidePhase.arrived
        : _RidePhase.approaching;
  }

  /// Road-ish distance from the driver to the pickup, while they approach.
  double? get _approachKm {
    final trip = _trip;
    final car = _liveDriverLocation;
    if (trip == null || car == null) return null;
    final meters = Geolocator.distanceBetween(
      car.latitude,
      car.longitude,
      trip.from.latitude,
      trip.from.longitude,
    );
    return meters * _roadFactor / 1000;
  }

  int? get _approachSeconds {
    final km = _approachKm;
    if (km == null) return null;
    return (km / _approachSpeedKmh * 3600).round();
  }

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _loadTrip();
    _initTracking();
    // Every ride ends on the payment screen: shared trips as well as the
    // locked instant ones, so every trip screen watches for the end.
    _statusPoll = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkTripEnded(),
    );
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    ActiveRideNavigator.left(widget.tripId);
    _trackingSubscription?.cancel();
    _socketService.unsubscribeFromTripTracking(widget.tripId);
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCarIcon() async {
    try {
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        _mapCarAsset,
      );
      if (!mounted) return;
      setState(() => _carIcon = icon);
      _rebuildMapOverlays();
    } catch (_) {
      // Fallback to default marker if asset fails.
    }
  }

  Future<void> _loadTrip() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final loaded = await tripProvider.getTrip(widget.tripId);
      if (!mounted) return;
      if (loaded == null) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _trip = loaded;
        _remainingDistanceKm = loaded.remainingDistanceKm;
        _remainingDurationSeconds = loaded.remainingDurationSeconds;
        _etaAt = loaded.etaAt;
        _progressPercent = loaded.routeProgressPercent ?? 0;
        if (loaded.lastDriverLocationLat != null &&
            loaded.lastDriverLocationLng != null) {
          _liveDriverLocation = LatLng(
            loaded.lastDriverLocationLat!,
            loaded.lastDriverLocationLng!,
          );
        }
        _loading = false;
      });
      _rebuildMapOverlays();
      _fitBounds();
      _loadRoadRoute(loaded);
      if (widget.showTrackingShare) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ShareTrackingSheet.show(context, loaded.id);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  Future<void> _loadRoadRoute(TripModel trip) async {
    final result = await _routeService.fetchRoute(
      origin: LatLng(trip.from.latitude, trip.from.longitude),
      destination: LatLng(trip.to.latitude, trip.to.longitude),
    );
    if (!mounted) return;
    if (result is RouteOk && result.polyline.length >= 2) {
      _roadRoute = result.polyline;
      _rebuildMapOverlays();
    }
  }

  /// Index of the route vertex closest to [p] (planar distance is plenty at
  /// this scale).
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

  Set<Polyline> _buildRoutePolylines(LatLng from, LatLng to, LatLng? car) {
    if (_phase != _RidePhase.riding) {
      // The car isn't on the trip route yet: show the whole route ahead and
      // a dashed approach line from the car to the pickup.
      return {
        ..._tripRoutePolylines(from, to, null),
        if (car != null && _phase == _RidePhase.approaching)
          Polyline(
            polylineId: const PolylineId('approach'),
            points: [car, from],
            color: AppColors.slate400,
            width: 4,
            patterns: [PatternItem.dash(18), PatternItem.gap(10)],
          ),
      };
    }
    return _tripRoutePolylines(from, to, car);
  }

  Set<Polyline> _tripRoutePolylines(LatLng from, LatLng to, LatLng? car) {
    final road = _roadRoute;
    if (road.length < 2) {
      final points = <LatLng>[from];
      if (car != null) points.add(car);
      points.add(to);
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: AppColors.teal600,
          width: 5,
        ),
      };
    }

    if (car == null) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: road,
          color: AppColors.teal600,
          width: 5,
        ),
      };
    }

    // Split the road at the car: the stretch already driven is muted, the
    // remainder stays in the brand colour.
    final split = _nearestIndex(road, car);
    return {
      if (split > 0)
        Polyline(
          polylineId: const PolylineId('route_done'),
          points: [...road.sublist(0, split + 1), car],
          color: AppColors.slate400,
          width: 5,
        ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: [car, ...road.sublist(split)],
        color: AppColors.teal600,
        width: 5,
      ),
    };
  }

  /// Once the driver ends the trip, move the passenger on — to the payment
  /// screen when it completed, back home when it was cancelled.
  ///
  /// A shared trip opened after it already ended (from history, say) is left
  /// alone: only an end this screen witnessed counts.
  Future<void> _checkTripEnded() async {
    if (_leaving || !mounted) return;
    try {
      final trip = await Provider.of<TripProvider>(
        context,
        listen: false,
      ).getTrip(widget.tripId);
      if (!mounted || trip == null) return;
      if (!trip.isCompleted && !trip.isCancelled) {
        _sawTripLive = true;
        // The driver marked arrival or started the ride: move the header
        // and the map on to the next stage.
        final previous = _trip;
        if (previous == null ||
            previous.driverArrivedAt != trip.driverArrivedAt ||
            previous.tripStartedAt != trip.tripStartedAt) {
          setState(() => _trip = trip);
          _rebuildMapOverlays();
        }
        return;
      }
      if (!widget.lockedUntilEnd && !_sawTripLive) {
        _statusPoll?.cancel();
        return;
      }
      _leaving = true;
      _statusPoll?.cancel();
      // The driver cancelled before pickup: the server is already searching
      // for another one, so follow that search instead of going home.
      if (trip.isCancelled &&
          widget.lockedUntilEnd &&
          await ActiveRideNavigator.followNewSearch()) {
        return;
      }
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (trip.isCompleted) {
        // Pay first: the amount-due screen holds the passenger until the fare
        // is settled, and moves straight on to rating when it already is.
        navigator.pushNamedAndRemoveUntil(
          RouteNames.ridePaymentDue,
          (route) => route.isFirst,
          arguments: {'tripId': trip.id, 'trip': trip},
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.statusCancelled)));
        navigator.popUntil((route) => route.isFirst);
      }
    } catch (_) {
      // Transient — the next tick retries.
    }
  }

  Future<void> _initTracking() async {
    await _socketService.connect();
    _socketService.subscribeToTripTracking(widget.tripId);
    _trackingSubscription = _socketService.onTrackingUpdate.listen((payload) {
      final payloadTripId = payload['tripId']?.toString();
      if (payloadTripId != widget.tripId) return;

      final lat = payload['latitude'];
      final lng = payload['longitude'];
      if (lat is! num || lng is! num) return;

      setState(() {
        _liveDriverLocation = LatLng(lat.toDouble(), lng.toDouble());
        final remKm = payload['remainingDistanceKm'];
        final remSec = payload['remainingDurationSeconds'];
        final eta = payload['etaAt'];
        final progress = payload['routeProgressPercent'];
        if (remKm is num) _remainingDistanceKm = remKm.toDouble();
        if (remSec is num) _remainingDurationSeconds = remSec.toInt();
        if (eta != null) _etaAt = DateTime.tryParse(eta.toString());
        if (progress is num) _progressPercent = progress.toDouble();
      });
      _rebuildMapOverlays();
    });
  }

  void _rebuildMapOverlays() {
    final trip = _trip;
    if (trip == null) return;

    final from = LatLng(trip.from.latitude, trip.from.longitude);
    final to = LatLng(trip.to.latitude, trip.to.longitude);
    final car = _liveDriverLocation;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('from'),
        position: from,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      Marker(
        markerId: const MarkerId('to'),
        position: to,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: trip.to.name),
      ),
    };

    if (car != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('car'),
          position: car,
          icon:
              _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = _buildRoutePolylines(from, to, car);
    });
  }

  Future<void> _fitBounds() async {
    final trip = _trip;
    final controller = _mapController;
    if (trip == null || controller == null) return;

    final points = <LatLng>[
      LatLng(trip.from.latitude, trip.from.longitude),
      LatLng(trip.to.latitude, trip.to.longitude),
      if (_liveDriverLocation != null) _liveDriverLocation!,
      ..._roadRoute,
    ];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  Future<void> _shareTracking() async {
    setState(() => _shareLoading = true);
    try {
      final url = await _shareLinkService.createTrackingShareUrl(widget.tripId);
      if (!mounted) return;
      await Share.share(context.l10n.shareTripTrackingText(url));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shareTripTrackingError)),
      );
    } finally {
      if (mounted) setState(() => _shareLoading = false);
    }
  }

  Future<void> _confirmEmergency() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.tripInProgressEmergencyConfirmTitle),
        content: Text(ctx.l10n.tripInProgressEmergencyConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.tripInProgressEmergencyCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(ctx.l10n.tripInProgressEmergencyConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // The alert goes out alongside the call, never in its way: the dialer
    // opens at once and the team gets the location in the background.
    unawaited(_sendEmergency());
    await _callSupport();
  }

  /// Opens the dialer on VisionWay's support line, the same number the
  /// support screen shows (the server's configured one when it has it).
  Future<void> _callSupport() async {
    var number = SupportConstants.supportPhone;
    try {
      final config = await ApiClient()
          .get('/support/config')
          .timeout(const Duration(seconds: 2));
      final configured = config is Map ? config['whatsappE164'] : null;
      if (configured is String && configured.trim().isNotEmpty) {
        number = configured.trim();
      }
    } catch (_) {
      // Offline or slow — the built-in number is just as good.
    }
    final phone = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.tripInProgressEmergencyCallFailed(
              SupportConstants.supportPhoneDisplay,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _sendEmergency() async {
    setState(() => _emergencyLoading = true);
    try {
      double? lat = _liveDriverLocation?.latitude;
      double? lng = _liveDriverLocation?.longitude;
      try {
        // Last known fix first: the dialer is about to take the foreground,
        // and a fresh fix may no longer be granted once it does.
        final pos =
            await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 4),
              ),
            );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        // Fall back to last known driver location from tracking.
      }

      await _emergencyService.reportEmergency(
        tripId: widget.tripId,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tripInProgressEmergencySent)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tripInProgressEmergencyError)),
      );
    } finally {
      if (mounted) setState(() => _emergencyLoading = false);
    }
  }

  void _openTripDetails() {
    Navigator.pushNamed(
      context,
      RouteNames.tripDetails,
      arguments: {
        'tripId': widget.tripId,
        'booking': widget.initialBooking,
        'forceDetails': true,
      },
    );
  }

  void _openHelp() {
    Navigator.pushNamed(context, RouteNames.support);
  }

  String _formatRemaining(BuildContext context) {
    final seconds = _phase == _RidePhase.approaching
        ? _approachSeconds
        : _remainingDurationSeconds;
    if (seconds == null) return '—';
    final totalMinutes = (seconds / 60).ceil();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (totalMinutes < 60) {
      return isAr ? '$totalMinutes دقيقة' : '$totalMinutes min';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) {
      return isAr ? '$hours ساعة' : '$hours h';
    }
    return isAr ? '$hours ساعة $mins دقيقة' : '${hours}h ${mins}m';
  }

  String _formatDistance() {
    final km = _phase == _RidePhase.approaching
        ? _approachKm
        : _remainingDistanceKm ?? _trip?.distanceKm;
    if (km == null) return '—';
    if (km >= 10) return '${km.round()} كم';
    return '${km.toStringAsFixed(1)} كم';
  }

  String _formatEta(BuildContext context) {
    final approach = _approachSeconds;
    final eta = _phase == _RidePhase.approaching
        ? (approach == null
              ? null
              : DateTime.now().add(Duration(seconds: approach)))
        : _etaAt;
    if (eta == null) return '—';
    final local = eta.toLocal();
    return DateFormat(
      'h:mm a',
      Localizations.localeOf(context).toString(),
    ).format(local);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final trip = _trip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.tripInProgressTitle)),
        body: Center(child: Text(context.l10n.tripNotFound)),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: !widget.lockedUntilEnd,
      child: Scaffold(
        backgroundColor: AppColors.slate50,
        body: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                mapType: _mapType,
                initialCameraPosition: CameraPosition(
                  target: LatLng(trip.from.latitude, trip.from.longitude),
                  zoom: 9,
                ),
                onMapCreated: (c) {
                  _mapController = c;
                  _fitBounds();
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(12, topInset + 8, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    _buildProgressCard(context, trip),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 290,
              child: Column(
                children: [
                  _MapFab(
                    icon: Icons.layers_outlined,
                    label: context.l10n.tripInProgressLayers,
                    onTap: () {
                      setState(() {
                        _mapType = _mapType == MapType.normal
                            ? MapType.hybrid
                            : MapType.normal;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _MapFab(
                    icon: Icons.my_location,
                    label: context.l10n.tripInProgressRecenter,
                    onTap: _fitBounds,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDriverCard(context, trip),
                    const SizedBox(height: 12),
                    _buildActionButtons(context),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    final phase = _phase;
    final (title, subtitle, dot) = switch (phase) {
      _RidePhase.approaching => (
        l10n.rideApproachingTitle,
        l10n.rideApproachingSubtitle,
        AppColors.warning,
      ),
      _RidePhase.arrived => (
        l10n.rideArrivedTitle,
        l10n.rideArrivedSubtitle,
        AppColors.success,
      ),
      _RidePhase.riding => (
        l10n.tripInProgressTitle,
        l10n.tripInProgressOnTheWay,
        AppColors.success,
      ),
    };
    return Row(
      children: [
        if (widget.lockedUntilEnd)
          const SizedBox(width: 48)
        else
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          ),
        Expanded(
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _openHelp,
          icon: Icon(Icons.headset_mic_outlined, color: AppColors.teal700),
          label: Text(
            context.l10n.tripInProgressHelp,
            style: TextStyle(
              color: AppColors.teal700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, TripModel trip) {
    // Before pickup the car sits at the start: the trip hasn't begun, and
    // the server's progress (driver vs. the trip route) means nothing yet.
    final progress = _phase == _RidePhase.riding
        ? (_progressPercent / 100).clamp(0.05, 0.95)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        trip.from.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        trip.to.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final carLeft = (constraints.maxWidth - 28) * progress;
              return SizedBox(
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 9,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.teal100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      width: carLeft + 14,
                      top: 9,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.teal600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: carLeft,
                      top: 0,
                      child: const Icon(
                        Icons.directions_car_filled,
                        size: 22,
                        color: AppColors.teal800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricColumn(
                  label: context.l10n.tripInProgressEtaLabel,
                  value: _formatEta(context),
                  emphasize: false,
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  label: context.l10n.tripInProgressRemainingDistance,
                  value: _formatDistance(),
                  emphasize: false,
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  label: context.l10n.tripInProgressRemainingTime,
                  value: _formatRemaining(context),
                  emphasize: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(BuildContext context, TripModel trip) {
    final name = trip.driverName?.trim().isNotEmpty == true
        ? trip.driverName!
        : '—';
    final rating = trip.driverRating;
    final model = trip.vehicleModel?.trim().isNotEmpty == true
        ? trip.vehicleModel!
        : '—';
    final plate = trip.vehiclePlateNumber?.trim().isNotEmpty == true
        ? trip.vehiclePlateNumber!
        : '—';
    final photo = trip.driverPhotoUrl;
    final carUrl = trip.carImageUrl;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Material(
                color: AppColors.teal50,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _openTripDetails,
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.teal700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.tripInProgressTripDetails,
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (rating != null && rating > 0) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: Color(0xFFFBBF24),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  model,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.slate300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            height: 52,
            child: carUrl != null && carUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: carUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) =>
                        Image.asset(_vehicleFallback, fit: BoxFit.contain),
                  )
                : Image.asset(_vehicleFallback, fit: BoxFit.contain),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.slate200,
            backgroundImage: photo != null && photo.isNotEmpty
                ? CachedNetworkImageProvider(photo)
                : const AssetImage(_avatarFallback) as ImageProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _shareLoading ? null : _shareTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _shareLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(
                context.l10n.tripInProgressShareTracking,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _emergencyLoading ? null : _confirmEmergency,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _emergencyLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield_outlined),
              label: Text(
                context.l10n.tripInProgressEmergency,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _MetricColumn({
    required this.label,
    required this.value,
    required this.emphasize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: emphasize ? 15 : 14,
            fontWeight: FontWeight.w700,
            color: emphasize ? AppColors.teal600 : AppColors.slate900,
          ),
        ),
      ],
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MapFab({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: AppColors.slate700),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.slate600),
        ),
      ],
    );
  }
}
