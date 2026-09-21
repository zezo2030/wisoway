import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/route_names.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/booking_service.dart';
import '../../core/services/instant_counter_offer_actions.dart';
import '../../core/services/instant_ride_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/route_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/instant_ride_models.dart';
import '../../models/location_model.dart';
import '../../core/services/saved_places_scope.dart';
import '../../widgets/location/place_field_block.dart';
import '../../widgets/trip/share_tracking_sheet.dart';
import '../location/map_point_picker_screen.dart';
import '../location/route_search_screen.dart';
import 'trip_details_screen.dart';
import 'widgets/instant_map_markers.dart';
import 'widgets/no_driver_found_sheet.dart';
import 'widgets/route_endpoint_label.dart';

/// Passenger "اطلب الآن" flow, inDrive-style: a full-screen map with a pinned
/// bottom sheet for pickup + destination, then the live search progress
/// (searching → matched / no drivers) shown over the same map.
class InstantRideRequestScreen extends StatefulWidget {
  final LocationModel? initialFrom;
  final LocationModel? initialTo;

  /// Open straight onto an existing request instead of the input form —
  /// used to resume a search, and by tests to land on a given state.
  final InstantRequest? initialRequest;

  /// Overridable so tests can drive the flow without the network.
  final InstantRideService? service;

  const InstantRideRequestScreen({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.initialRequest,
    this.service,
  });

  @override
  State<InstantRideRequestScreen> createState() =>
      _InstantRideRequestScreenState();
}

class _InstantRideRequestScreenState extends State<InstantRideRequestScreen>
    with SingleTickerProviderStateMixin {
  static const LatLng _fallbackCenter = LatLng(31.9539, 35.9106); // Amman

  late final InstantRideService _service =
      widget.service ?? InstantRideService();
  final LocationService _locationService = LocationService();
  final BookingService _bookingService = BookingService();
  final RouteService _routeService = RouteService();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _fareController = TextEditingController();
  final FocusNode _fareFocus = FocusNode();

  GoogleMapController? _mapController;
  LatLng _mapCenter = _fallbackCenter;
  bool _locatingMe = false;

  List<LatLng> _routePoints = const [];
  int _routeRequestSeq = 0;

  LocationModel? _from;
  LocationModel? _to;
  bool _submitting = false;
  InstantRequest? _request;
  Timer? _poll;
  Timer? _countdownTicker;

  /// Real nearby online drivers of ours, drawn as car pins on the map.
  List<InstantNearbyDriverPin> _nearbyDrivers = const [];
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;

  /// Drives the expanding search ring around the pickup while searching.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..addListener(() => setState(() {}));
  Timer? _nearbyRefresh;

  InstantQuote? _quote;
  double? _fare;
  bool _quoteLoading = false;
  int _quoteSeq = 0;
  bool _counterBusy = false;
  bool _nudgeBusy = false;
  bool _retrying = false;
  bool _callBusy = false;
  bool _cancelBusy = false;

  /// Measured height of the bottom sheet, used to keep the route and the
  /// Google logo clear of it instead of guessing a fraction of the screen.
  final GlobalKey _sheetKey = GlobalKey();
  double _sheetHeight = 0;

  /// Screen positions of the pickup / drop-off name cards, recomputed as the
  /// camera moves. Null while off-screen or before the map reports them.
  Offset? _fromLabelAt;
  Offset? _toLabelAt;
  bool _labelLookupInFlight = false;

  /// Suggested fare the user chose to keep ignoring ("Keep Y").
  String? _dismissedNudgeFare;

  @override
  void initState() {
    super.initState();
    if (widget.initialFrom != null) {
      _from = widget.initialFrom;
      _fromController.text = widget.initialFrom!.name;
      _mapCenter = LatLng(
        widget.initialFrom!.latitude,
        widget.initialFrom!.longitude,
      );
    } else {
      _resolveCurrentLocation();
    }
    if (widget.initialTo != null) {
      _to = widget.initialTo;
      _toController.text = widget.initialTo!.name;
    }
    final resumed = widget.initialRequest;
    if (resumed != null) {
      _request = resumed;
      if (resumed.isSearching) _startPolling();
    }
    _loadMarkerIcons();
    _refreshNearbyDrivers();
    _nearbyRefresh = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshNearbyDrivers(),
    );
  }

  @override
  void dispose() {
    // Hand counter-offers back to the push handler on the way out.
    InstantCounterOfferActions.setInlineHandler(null);
    _poll?.cancel();
    _countdownTicker?.cancel();
    _nearbyRefresh?.cancel();
    _pulse.dispose();
    _mapController?.dispose();
    _fromController.dispose();
    _toController.dispose();
    _fareController.dispose();
    _fareFocus.dispose();
    super.dispose();
  }

  // ── Map ─────────────────────────────────────────────────────────────────────

  /// Marker sprites, drawn once: dark top-view cars for nearby drivers and
  /// ring pins for the endpoints (see InstantMapMarkers).
  Future<void> _loadMarkerIcons() async {
    try {
      final results = await Future.wait([
        InstantMapMarkers.car(),
        InstantMapMarkers.pickup(),
        InstantMapMarkers.destination(),
      ]);
      if (!mounted) return;
      setState(() {
        _carIcon = results[0];
        _pickupIcon = results[1];
        _destinationIcon = results[2];
      });
    } catch (_) {
      // Fall back to the default pins; the driver cars are simply omitted.
    }
  }

  /// Pull anonymous pins of our online drivers around the pickup (or the map
  /// center before a pickup is chosen). Failures leave the last pins in place.
  Future<void> _refreshNearbyDrivers() async {
    final anchor = _from != null
        ? LatLng(_from!.latitude, _from!.longitude)
        : _mapCenter;
    final pins = await _service.nearbyDriverPins(
      latitude: anchor.latitude,
      longitude: anchor.longitude,
    );
    if (!mounted) return;
    setState(() => _nearbyDrivers = pins);
  }

  Future<void> _resolveCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      final target = LatLng(location.latitude, location.longitude);
      setState(() => _mapCenter = target);
      if (_from == null && _request == null) {
        _applyEndpoints(location, _to);
      } else {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
      }
    } catch (_) {
      // Keep the fallback center; the user can search or pick on the map.
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _focusCamera();
  }

  /// Frame whatever we know: a drawn route → its bounds, both endpoints →
  /// straight bounds, one → centered, else map center.
  void _focusCamera() {
    final controller = _mapController;
    if (controller == null) return;

    if (_routePoints.length >= 2) {
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          RouteService.computeBounds(_routePoints),
          60,
        ),
      );
      return;
    }

    if (_from != null && _to != null) {
      final a = LatLng(_from!.latitude, _from!.longitude);
      final b = LatLng(_to!.latitude, _to!.longitude);
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              math.min(a.latitude, b.latitude),
              math.min(a.longitude, b.longitude),
            ),
            northeast: LatLng(
              math.max(a.latitude, b.latitude),
              math.max(a.longitude, b.longitude),
            ),
          ),
          90,
        ),
      );
      return;
    }

    final single = _to ?? _from;
    final target = single != null
        ? LatLng(single.latitude, single.longitude)
        : _mapCenter;
    controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  /// Draw the road route between pickup and destination. Falls back to a
  /// straight line if the routing backend can't return geometry.
  Future<void> _updateRoute() async {
    if (_from == null || _to == null) {
      if (_routePoints.isNotEmpty) {
        setState(() {
          _routePoints = const [];
        });
      }
      return;
    }

    final origin = LatLng(_from!.latitude, _from!.longitude);
    final destination = LatLng(_to!.latitude, _to!.longitude);
    final seq = ++_routeRequestSeq;

    final result = await _routeService.fetchRoute(
      origin: origin,
      destination: destination,
    );
    // Ignore stale responses if the endpoints changed meanwhile.
    if (!mounted || seq != _routeRequestSeq) return;

    setState(() {
      if (result is RouteOk && result.polyline.length >= 2) {
        _routePoints = result.polyline;
      } else {
        _routePoints = [origin, destination];
      }
    });
    _focusCamera();
  }

  /// inDrive's expanding ring around the pickup while a request is out —
  /// a soft disc that grows toward the dispatch radius and fades.
  Set<Circle> _buildPulseCircles() {
    final from = _from;
    if (from == null || !_isSearching) return const {};
    final t = _pulse.value;
    final primary = T.primary(context);
    return {
      Circle(
        circleId: const CircleId('search-pulse'),
        center: LatLng(from.latitude, from.longitude),
        radius: instantPulseRadiusMeters(t),
        fillColor: primary.withValues(alpha: instantPulseAlpha(t)),
        strokeColor: primary.withValues(alpha: instantPulseStrokeAlpha(t)),
        strokeWidth: 2,
      ),
      Circle(
        circleId: const CircleId('search-core'),
        center: LatLng(from.latitude, from.longitude),
        radius: 120,
        fillColor: primary.withValues(alpha: 0.18),
        strokeColor: primary.withValues(alpha: 0.5),
        strokeWidth: 1,
      ),
    };
  }

  bool get _isSearching => _request?.isSearching ?? false;

  /// Run the ring only while a search is live; called from build so every
  /// state transition (submit, resume, cancel, match) is covered.
  void _syncPulse() {
    if (_isSearching) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  Set<Polyline> _buildPolylines() {
    if (_routePoints.length < 2) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: T.primary(context),
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locatingMe = true);
    await _resolveCurrentLocation();
    if (mounted) setState(() => _locatingMe = false);
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_from != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('from'),
          position: LatLng(_from!.latitude, _from!.longitude),
          icon:
              _pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 1),
          infoWindow: InfoWindow(title: _from!.name),
        ),
      );
    }
    if (_to != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('to'),
          position: LatLng(_to!.latitude, _to!.longitude),
          icon:
              _destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1),
          infoWindow: InfoWindow(title: _to!.name),
        ),
      );
    }
    final carIcon = _carIcon;
    if (carIcon != null) {
      for (var i = 0; i < _nearbyDrivers.length; i++) {
        final pin = _nearbyDrivers[i];
        markers.add(
          Marker(
            markerId: MarkerId('nearby_driver_$i'),
            position: LatLng(pin.latitude, pin.longitude),
            icon: carIcon,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            // Varied deterministic headings so the cars read as live traffic,
            // matching the reference art. The pins are anonymous — no tap.
            rotation: instantCarHeading(i),
            consumeTapEvents: true,
            zIndexInt: -1,
          ),
        );
      }
    }
    return markers;
  }

  // ── Fare quote ────────────────────────────────────────────────────────────────

  /// Fetch the distance-based fare recommendation once both points are set.
  Future<void> _updateQuote() async {
    if (_from == null || _to == null) {
      _quoteSeq++;
      if (_quote != null || _quoteLoading) {
        setState(() {
          _quote = null;
          _setFare(null);
          _quoteLoading = false;
        });
      }
      return;
    }
    final seq = ++_quoteSeq;
    setState(() => _quoteLoading = true);
    try {
      final quote = await _service.getQuote(from: _from!, to: _to!);
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = quote;
        _setFare(quote.recommendedFare);
        _quoteLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _quoteSeq) return;
      // Keep any previous quote; the server re-validates on submit anyway.
      setState(() => _quoteLoading = false);
    }
  }

  // ── Request lifecycle ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.instantSelectFromTo)));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final request = await _service.createRequest(
        from: _from!,
        to: _to!,
        passengerFare: _typedFare ?? _fare,
      );
      if (!mounted) return;
      setState(() => _request = request);
      // While this screen is up it owns counter-offers for the request, so the
      // push handler must not stack a modal on top of the inline card.
      InstantCounterOfferActions.setInlineHandler(request.id);
      _startPolling();
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final current = _request;
      if (current == null) return;
      try {
        final updated = await _service.getRequest(current.id);
        if (!mounted) return;
        setState(() => _request = updated);
        if (!updated.isSearching) {
          _poll?.cancel();
          _countdownTicker?.cancel();
        }
      } catch (_) {
        // transient — keep polling
      }
    });
    // 1s repaint so the counter-offer countdown reads smoothly.
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _request?.counterOffer != null) setState(() {});
    });
  }

  Future<void> _acceptCounter() async {
    final request = _request;
    final offer = request?.counterOffer;
    if (request == null || offer == null || _counterBusy) return;
    setState(() => _counterBusy = true);
    try {
      final updated = await _service.acceptCounterOffer(request.id, offer.id);
      if (!mounted) return;
      setState(() => _request = updated);
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
      await _refreshRequest(request.id);
    } finally {
      if (mounted) setState(() => _counterBusy = false);
    }
  }

  Future<void> _declineCounter() async {
    final request = _request;
    final offer = request?.counterOffer;
    if (request == null || offer == null || _counterBusy) return;
    setState(() => _counterBusy = true);
    try {
      final updated = await _service.declineCounterOffer(request.id, offer.id);
      if (!mounted) return;
      setState(() => _request = updated);
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
      await _refreshRequest(request.id);
    } finally {
      if (mounted) setState(() => _counterBusy = false);
    }
  }

  Future<void> _refreshRequest(String id) async {
    try {
      final updated = await _service.getRequest(id);
      if (mounted) setState(() => _request = updated);
    } catch (_) {
      // keep last known state
    }
  }

  /// "Raise to X" — bump the asking fare so more drivers qualify.
  Future<void> _raiseFare(String suggestedFare) async {
    final request = _request;
    final amount = double.tryParse(suggestedFare);
    if (request == null || amount == null || _nudgeBusy) return;
    setState(() => _nudgeBusy = true);
    try {
      final updated = await _service.updateFare(request.id, amount);
      if (!mounted) return;
      setState(() {
        _request = updated;
        _dismissedNudgeFare = null;
      });
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
      await _refreshRequest(request.id);
    } finally {
      if (mounted) setState(() => _nudgeBusy = false);
    }
  }

  Future<void> _cancel() async {
    final current = _request;
    _poll?.cancel();
    _countdownTicker?.cancel();
    if (current != null && current.isSearching) {
      try {
        await _service.cancelRequest(current.id);
      } catch (_) {
        // ignore
      }
    }
    if (mounted) {
      setState(() {
        _request = null;
        _pendingFare = null;
      });
    }
  }

  void _reset() {
    _poll?.cancel();
    _countdownTicker?.cancel();
    setState(() {
      _request = null;
      _pendingFare = null;
    });
  }

  /// "Try again" on the no-driver sheet: server clones the finished request
  /// and we jump straight back into searching, skipping the input form.
  Future<void> _retry() async {
    final current = _request;
    if (current == null || _retrying) return;
    setState(() => _retrying = true);
    try {
      final next = await _service.retryRequest(current.id);
      if (!mounted) return;
      setState(() => _request = next);
      _startPolling();
    } on InstantRetryFareChangedException catch (e) {
      if (!mounted) return;
      // The fare has to be re-confirmed, so drop back to the form with the
      // new bounds rather than silently re-pricing the ride.
      setState(() {
        _request = null;
        if (e.quote != null) {
          _quote = e.quote;
          _setFare(e.quote!.recommendedFare);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.instantRetryFareChanged)),
      );
    } catch (e) {
      // Keep the failure sheet and its trip details on screen.
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  /// True once the search has ended without a match — the state the
  /// no-driver sheet, endpoint labels and safety badge belong to.
  /// Name cards float over the pins on the form and on the failure sheet.
  bool get _isMatched => _request?.isMatched ?? false;

  bool get _showEndpointLabels =>
      _request == null || _isSearching || _isMatched || _showingNoDriverFound;

  bool get _showingNoDriverFound => _request?.isNoDriverFound ?? false;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSheet());
    _syncPulse();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          if (_showEndpointLabels) ..._buildEndpointLabels(context),
          _buildTopBar(context),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: KeyedSubtree(
                key: _sheetKey,
                child: _request == null
                    ? _buildFormSheet(context)
                    : _buildStatusSheet(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Keep [_sheetHeight] in sync with what the sheet actually laid out to, so
  /// the map padding follows a taller failure sheet or a scaled-up font.
  void _measureSheet() {
    final box = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final height = box.size.height;
    if ((height - _sheetHeight).abs() < 1) return;
    setState(() => _sheetHeight = height);
    _updateEndpointLabels();
  }

  Widget _buildMap() {
    // Leave room so the bottom sheet doesn't cover the Google logo / markers.
    // Falls back to a fraction of the screen for the first frame, before the
    // sheet has been measured.
    final bottomPadding = _sheetHeight > 0
        ? _sheetHeight
        : MediaQuery.of(context).size.height * 0.42;

    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(target: _mapCenter, zoom: 14),
      markers: _buildMarkers(),
      polylines: _buildPolylines(),
      circles: _buildPulseCircles(),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      padding: EdgeInsets.only(bottom: bottomPadding),
      onCameraMove: (_) => _updateEndpointLabels(),
      onCameraIdle: _updateEndpointLabels,
      onTap: (_) => FocusScope.of(context).unfocus(),
    );
  }

  /// Ask the map where the endpoints currently sit on screen. Anything outside
  /// the part of the map not covered by the sheet is dropped, so a label never
  /// floats over the sheet or off the viewport.
  Future<void> _updateEndpointLabels() async {
    // onCameraMove fires every frame of a pan; one in-flight lookup at a time
    // keeps the platform-channel traffic bounded.
    if (_labelLookupInFlight) return;
    final controller = _mapController;
    if (controller == null || !_showEndpointLabels) {
      if (_fromLabelAt != null || _toLabelAt != null) {
        setState(() {
          _fromLabelAt = null;
          _toLabelAt = null;
        });
      }
      return;
    }

    final ratio = MediaQuery.of(context).devicePixelRatio;
    final size = MediaQuery.of(context).size;
    final topLimit = MediaQuery.of(context).padding.top + 62;
    final bottomLimit = size.height - _sheetHeight - 12;

    Future<Offset?> at(LocationModel? point) async {
      if (point == null) return null;
      final screen = await controller.getScreenCoordinate(
        LatLng(point.latitude, point.longitude),
      );
      final offset = Offset(screen.x / ratio, screen.y / ratio);
      final visible =
          offset.dy >= topLimit &&
          offset.dy <= bottomLimit &&
          offset.dx >= 0 &&
          offset.dx <= size.width;
      return visible ? offset : null;
    }

    _labelLookupInFlight = true;
    Offset? from;
    Offset? to;
    try {
      from = await at(_from);
      to = await at(_to);
    } finally {
      _labelLookupInFlight = false;
    }
    if (!mounted || from == _fromLabelAt && to == _toLabelAt) return;
    setState(() {
      _fromLabelAt = from;
      _toLabelAt = to;
    });
  }

  List<Widget> _buildEndpointLabels(BuildContext context) {
    Widget? label(Offset? at, String? name, String caption, Color dot) {
      if (at == null || name == null || name.isEmpty) return null;
      return Positioned(
        // Sit just above the marker pin and roughly centred on it.
        left: at.dx - 95,
        top: at.dy - 62,
        width: 190,
        child: Align(
          child: RouteEndpointLabel(
            name: name,
            caption: caption,
            dotColor: dot,
          ),
        ),
      );
    }

    return [
      label(
        _fromLabelAt,
        _from?.name,
        context.l10n.instantPickupPoint,
        AppColors.success,
      ),
      label(
        _toLabelAt,
        _to?.name,
        context.l10n.instantDropoffPoint,
        AppColors.error,
      ),
    ].whereType<Widget>().toList();
  }

  Widget _buildTopBar(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 8;
    return Stack(
      children: [
        PositionedDirectional(
          top: top,
          start: 12,
          child: _circleButton(
            context,
            icon: _request == null ? Icons.keyboard_arrow_down : Icons.close,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        if (_showingNoDriverFound || _isSearching || _isMatched)
          PositionedDirectional(
            top: top,
            end: 12,
            child: _safetyBadge(context),
          ),
      ],
    );
  }

  /// Reassurance chip, deliberately not a button — there is no safety screen
  /// behind it, and support has its own link in the sheet.
  Widget _safetyBadge(BuildContext context) {
    return Material(
      color: T.surface(context),
      elevation: 4,
      shadowColor: T.shadow(context).withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(23),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 18, color: T.primary(context)),
            const SizedBox(width: 6),
            Text(
              context.l10n.instantRideSafety,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: T.onSurface(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return Material(
      color: T.surface(context),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: T.shadow(context).withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: child ?? Icon(icon, color: T.onSurface(context)),
        ),
      ),
    );
  }

  Widget _sheetContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _grabHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      decoration: BoxDecoration(
        color: T.outlineVariant(context),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Form sheet ─────────────────────────────────────────────────────────────────

  /// Both endpoints as they stand after any picker closes.
  void _applyEndpoints(LocationModel? from, LocationModel? to) {
    setState(() {
      _from = from;
      _to = to;
      _fromController.text = from?.name ?? '';
      _toController.text = to?.name ?? '';
    });
    if (from != null || to != null) _focusCamera();
    _updateRoute();
    _updateQuote();
    _refreshNearbyDrivers();
  }

  Future<void> _openSearch(RouteField field) async {
    FocusScope.of(context).unfocus();
    final selection = await Navigator.of(context).push<RouteSelection>(
      MaterialPageRoute(
        builder: (_) => RouteSearchScreen(
          focusField: field,
          savedPlaces: savedPlacesFor(context),
          from: _from,
          to: _to,
        ),
      ),
    );
    if (selection == null || !mounted) return;
    _applyEndpoints(selection.from, selection.to);
  }

  /// "حدد على الخريطة" — drop the destination pin straight on a map.
  Future<void> _pickDestinationOnMap() async {
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final anchor = _from;
    final location = await Navigator.of(context).push<LocationModel>(
      MaterialPageRoute(
        builder: (_) => MapPointPickerScreen(
          confirmLabel: l10n.routeSearchConfirmDestination,
          initialLocation: _to,
          fallbackCenter: anchor != null
              ? LatLng(anchor.latitude, anchor.longitude)
              : _mapCenter,
        ),
      ),
    );
    if (location == null || !mounted) return;
    _applyEndpoints(_from, location);
  }

  Widget _buildFormSheet(BuildContext context) {
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.72;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 16, bottom: 12),
          child: _circleButton(
            context,
            icon: Icons.my_location,
            onTap: _locatingMe ? () {} : _goToMyLocation,
            child: _locatingMe
                ? Padding(
                    padding: const EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: T.primary(context),
                    ),
                  )
                : null,
          ),
        ),
        _sheetContainer(
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _grabHandle(),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.instantRequestNowTitle,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: T.onSurface(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.instantRequestNowSubtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: T.onSurfaceVariant(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildEndpointRows(context),
                          const SizedBox(height: 14),
                          _buildMetricsCard(context),
                          if (_quote != null || _quoteLoading) ...[
                            const SizedBox(height: 14),
                            _buildFareInput(context),
                          ],
                          const SizedBox(height: 16),
                          _buildPrimaryCta(context),
                          const SizedBox(height: 18),
                          _buildTrustRow(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// "من" / "إلى" blocks with their side actions: change the pickup, or drop
  /// the destination pin on the map.
  Widget _buildEndpointRows(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        PlaceFieldBlock(
          label: l10n.instantFormFromLabel,
          value: _from?.name,
          hint: l10n.instantFromHint,
          indicator: RouteEndpointRing(color: T.success(context)),
          busy: _locatingMe && _from == null,
          trailing: _endpointAction(
            context,
            icon: Icons.edit_outlined,
            label: l10n.instantFormChange,
            onTap: () => _openSearch(RouteField.origin),
          ),
          onTap: () => _openSearch(RouteField.origin),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 22,
            top: 4,
            bottom: 4,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              children: List.generate(
                3,
                (_) => Container(
                  width: 3,
                  height: 3,
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  decoration: BoxDecoration(
                    color: T.outline(context),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
        PlaceFieldBlock(
          label: l10n.instantFormToLabel,
          value: _to?.name,
          hint: l10n.instantFormToHint,
          indicator: Icon(Icons.location_on, size: 20, color: T.error(context)),
          trailing: _endpointAction(
            context,
            icon: Icons.map_outlined,
            label: l10n.instantFormPickOnMap,
            onTap: _pickDestinationOnMap,
          ),
          onTap: () => _openSearch(RouteField.destination),
        ),
      ],
    );
  }

  Widget _endpointAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: T.surface(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: T.outlineVariant(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: T.onSurface(context)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: T.onSurface(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Minutes until the nearest online driver could reach the pickup, from the
  /// anonymous pins already on the map. Null until both are known.
  int? get _driverEtaMinutes {
    final from = _from;
    if (from == null || _nearbyDrivers.isEmpty) return null;
    var nearestKm = double.infinity;
    for (final pin in _nearbyDrivers) {
      final km = _haversineKm(
        from.latitude,
        from.longitude,
        pin.latitude,
        pin.longitude,
      );
      if (km < nearestKm) nearestKm = km;
    }
    if (!nearestKm.isFinite) return null;
    // Same urban approach speed the backend uses for pickup ETAs.
    return math.max(1, (nearestKm / 25 * 60).ceil());
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// Three-up strip: driver ETA / distance / trip duration, with a footer
  /// explaining that the fare appears once the destination is set.
  Widget _buildMetricsCard(BuildContext context) {
    final l10n = context.l10n;
    final quote = _quote;
    final eta = _driverEtaMinutes;
    final distance = quote?.distanceKm;
    final duration = quote?.durationMinutes;

    String fmt(num? v) {
      if (v == null) return '--';
      return v == v.roundToDouble()
          ? v.round().toString()
          : v.toStringAsFixed(1);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outlineVariant(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _metricCell(
                    context,
                    icon: Icons.directions_car_outlined,
                    label: l10n.instantFormDriverArrives,
                    value: fmt(eta),
                    unit: l10n.instantFormMinutesUnit,
                  ),
                  _metricDivider(context),
                  _metricCell(
                    context,
                    icon: Icons.route_outlined,
                    label: l10n.instantFormDistance,
                    value: fmt(distance),
                    unit: l10n.instantFormKmUnit,
                  ),
                  _metricDivider(context),
                  _metricCell(
                    context,
                    icon: Icons.schedule,
                    label: l10n.instantFormDuration,
                    value: fmt(duration),
                    unit: l10n.instantFormMinutesUnit,
                  ),
                ],
              ),
            ),
          ),
          if (quote == null)
            Container(
              width: double.infinity,
              color: T.surfaceVariant(context),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: T.onSurfaceVariant(context),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.instantFormPriceAfterDestination,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricDivider(BuildContext context) =>
      VerticalDivider(width: 1, thickness: 1, color: T.outlineVariant(context));

  Widget _metricCell(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: T.onSurfaceVariant(context)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11.5,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fare input ───────────────────────────────────────────────────────────────

  static String _formatFare(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  /// Keep the model and the text field in step.
  void _setFare(double? value) {
    _fare = value;
    final text = value == null ? '' : _formatFare(value);
    if (_fareController.text != text) {
      _fareController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  /// The fare as typed, accepting Arabic-Indic digits and a comma decimal.
  double? get _typedFare {
    final text = _fareController.text.trim();
    if (text.isEmpty) return null;
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final sb = StringBuffer();
    for (final ch in text.characters) {
      final i = arabic.indexOf(ch);
      if (i >= 0) {
        sb.write(i);
      } else if (ch == '،' || ch == ',') {
        sb.write('.');
      } else {
        sb.write(ch);
      }
    }
    return double.tryParse(sb.toString());
  }

  bool get _fareValid {
    final quote = _quote;
    if (quote == null) return true;
    final fare = _typedFare;
    return fare != null &&
        fare >= quote.minFare - 0.001 &&
        fare <= quote.maxFare + 0.001;
  }

  /// Stepper increment scaled to the fare magnitude (0.25 for JOD-level fares).
  double get _fareStep {
    final rec = _quote?.recommendedFare ?? 0;
    if (rec >= 100) return 5;
    if (rec >= 20) return 1;
    return 0.25;
  }

  void _bumpFare(double direction) {
    final quote = _quote;
    if (quote == null) return;
    final current = _typedFare ?? _fare ?? quote.recommendedFare;
    final next = (current + direction * _fareStep).clamp(
      quote.minFare,
      quote.maxFare,
    );
    setState(() => _setFare((next * 100).roundToDouble() / 100));
  }

  /// The passenger writes their own fare, inDrive style, with − / + nudges
  /// around it and the server's recommendation as a reference.
  Widget _buildFareInput(BuildContext context) {
    final quote = _quote;
    final l10n = context.l10n;
    if (quote == null) {
      return const Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final typed = _typedFare;
    final valid = _fareValid;
    final canDecrease =
        (typed ?? quote.recommendedFare) - _fareStep >= quote.minFare - 0.001;
    final canIncrease =
        (typed ?? quote.recommendedFare) + _fareStep <= quote.maxFare + 0.001;
    final borderColor = valid ? T.outlineVariant(context) : T.error(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.instantFormYourFareTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: T.onSurfaceVariant(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _fareStepButton(
                context,
                icon: Icons.remove,
                enabled: canDecrease,
                onTap: () => _bumpFare(-1),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey('instant-fare-field'),
                  controller: _fareController,
                  focusNode: _fareFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _fare = _typedFare),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.instantFormFareHint,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: T.onSurfaceVariant(context),
                    ),
                    suffixText: quote.currency,
                    suffixStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T.onSurfaceVariant(context),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: T.surface(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: valid ? T.primary(context) : T.error(context),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _fareStepButton(
                context,
                icon: Icons.add,
                enabled: canIncrease,
                onTap: () => _bumpFare(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valid
                ? l10n.instantRecommendedFare(
                    _formatFare(quote.recommendedFare),
                    quote.currency,
                  )
                : l10n.instantFormFareOutOfRange(
                    _formatFare(quote.minFare),
                    _formatFare(quote.maxFare),
                    quote.currency,
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: valid ? FontWeight.normal : FontWeight.w600,
              color: valid ? T.onSurfaceVariant(context) : T.error(context),
            ),
          ),
          if (valid) ...[
            const SizedBox(height: 2),
            Text(
              l10n.instantFormFareRange(
                _formatFare(quote.minFare),
                _formatFare(quote.maxFare),
                quote.currency,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            l10n.instantFormFareNote,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareStepButton(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: T.surface(context),
      shape: const CircleBorder(),
      elevation: enabled ? 2 : 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: enabled
                ? T.onSurface(context)
                : T.onSurfaceVariant(context).withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  // ── CTA + trust row ───────────────────────────────────────────────────────────

  Widget _buildPrimaryCta(BuildContext context) {
    final l10n = context.l10n;
    final needsDestination = _to == null;
    final ready =
        _from != null &&
        _to != null &&
        !_submitting &&
        !_quoteLoading &&
        _fareValid;

    final label = needsDestination
        ? l10n.instantFormChooseDestinationCta
        : l10n.instantRequestNow;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: ready ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: T.primary(context),
          disabledBackgroundColor: needsDestination
              ? T.primary(context).withValues(alpha: 0.85)
              : T.primary(context).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_submitting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            else
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  needsDestination
                      ? (isRtl ? Icons.arrow_back : Icons.arrow_forward)
                      : Icons.electric_bolt,
                  size: 18,
                  color: T.primary(context),
                ),
              ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustRow(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (Icons.lock_outline, l10n.instantTrustCash, l10n.instantTrustCashSub),
      (
        Icons.map_outlined,
        l10n.instantTrustTracking,
        l10n.instantTrustTrackingSub,
      ),
      (
        Icons.verified_user_outlined,
        l10n.instantTrustSafe,
        l10n.instantTrustSafeSub,
      ),
      (
        Icons.headset_mic_outlined,
        l10n.instantTrustSupport,
        l10n.instantTrustSupportSub,
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, title, subtitle) in items)
          Expanded(
            child: Column(
              children: [
                Icon(icon, size: 24, color: T.primary(context)),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Status sheet ───────────────────────────────────────────────────────────────

  Widget _buildStatusSheet(BuildContext context) {
    final request = _request!;

    Widget content;
    if (request.isMatched) {
      final match = request.match;
      if (match != null) {
        content = _buildMatchedView(context, request, match);
      } else {
        final tripId = request.tripId;
        final hasTrip = tripId != null && tripId.isNotEmpty;
        content = _statusView(
          context,
          icon: Icons.check_circle,
          color: AppColors.success,
          title: context.l10n.instantDriverFound,
          subtitle: context.l10n.instantDriverOnTheWay,
          primaryLabel: hasTrip
              ? context.l10n.instantTrackTrip
              : context.l10n.instantDone,
          onPrimary: () {
            if (hasTrip) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => TripDetailsScreen(tripId: tripId),
                ),
              );
            } else {
              Navigator.of(context).pop();
            }
          },
        );
      }
    } else if (request.isNoDriverFound) {
      content = NoDriverFoundSheet(
        retrying: _retrying,
        terminalReason: request.terminalReason,
        searchRadiusKm: request.searchRadiusKm,
        onRetry: _retry,
        // The request is already terminal, so this just leaves the flow.
        onClose: () => Navigator.of(context).maybePop(),
        onSupport: () => Navigator.of(context).pushNamed(RouteNames.support),
      );
    } else if (request.isFailed) {
      content = _statusView(
        context,
        icon: Icons.cancel,
        color: AppColors.error,
        title: context.l10n.instantRequestCancelled,
        subtitle: '',
        primaryLabel: context.l10n.instantTryAgain,
        onPrimary: _reset,
      );
    } else {
      content = _buildSearchingView(context, request);
    }

    // Cap the sheet so a long failure state still leaves the route visible,
    // and let it scroll on short screens or at large text scales.
    final maxHeight = MediaQuery.of(context).size.height * 0.72;

    return _sheetContainer(
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_grabHandle(), content],
            ),
          ),
        ),
      ),
    );
  }

  // ── Fare while searching (inDrive: − / fare / + and "Raise fare") ─────────────

  /// The fare the passenger is lining up to send, if they nudged it above
  /// what drivers currently see. Null means "no pending raise".
  double? _pendingFare;

  double _searchStepFor(double base) {
    if (base >= 100) return 5;
    if (base >= 20) return 1;
    return 0.25;
  }

  void _nudgeSearchFare(InstantRequest request, double direction) {
    final current = request.currentFare;
    final max = request.maxFare;
    if (current == null) return;
    final step = _searchStepFor(
      request.recommendedFare != null
          ? double.tryParse(request.recommendedFare!) ?? current
          : current,
    );
    final from = _pendingFare ?? current;
    var next = from + direction * step;
    if (max != null && next > max) next = max;
    if (next <= current) next = current;
    next = (next * 100).roundToDouble() / 100;
    setState(() => _pendingFare = next > current ? next : null);
  }

  Future<void> _submitPendingFare(InstantRequest request) async {
    final pending = _pendingFare;
    if (pending == null || _nudgeBusy) return;
    setState(() => _nudgeBusy = true);
    try {
      final updated = await _service.updateFare(request.id, pending);
      if (!mounted) return;
      setState(() {
        _request = updated;
        _pendingFare = null;
        _dismissedNudgeFare = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.instantFareRaisedToast)),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
      await _refreshRequest(request.id);
    } finally {
      if (mounted) setState(() => _nudgeBusy = false);
    }
  }

  /// inDrive's fare block on the waiting screen: the fare drivers see, − / +
  /// to line up a higher one, and a "Raise fare" button that only lights up
  /// once the pending fare is above the current one.
  Widget _buildSearchFareCard(BuildContext context, InstantRequest request) {
    final l10n = context.l10n;
    final current = request.currentFare;
    if (current == null) return const SizedBox.shrink();
    final max = request.maxFare;
    // The backend only takes a raise while no offer is outstanding.
    final locked = request.status == 'offered';
    final shown = _pendingFare ?? current;
    final atMax = max != null && shown >= max - 0.001;
    final canRaise = _pendingFare != null && !locked && !_nudgeBusy;

    final String hint;
    if (locked) {
      hint = l10n.instantFareLockedWhileOffered;
    } else if (atMax && _pendingFare == null) {
      hint = l10n.instantFareMaxReached;
    } else {
      hint = l10n.instantFareRaiseHint;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 16,
                color: T.primary(context),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.instantYourFareLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: T.onSurfaceVariant(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _fareStepButton(
                context,
                icon: Icons.remove,
                enabled: !locked && _pendingFare != null,
                onTap: () => _nudgeSearchFare(request, -1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_formatFare(shown)} ${request.currency}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: T.onSurface(context),
                      ),
                    ),
                    if (_pendingFare != null)
                      Text(
                        l10n.instantYourFareValue(
                          _formatFare(current),
                          request.currency,
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: T.onSurfaceVariant(context),
                        ),
                      ),
                  ],
                ),
              ),
              _fareStepButton(
                context,
                icon: Icons.add,
                enabled: !locked && !atMax,
                onTap: () => _nudgeSearchFare(request, 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: canRaise ? () => _submitPendingFare(request) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: T.primary(context),
                disabledBackgroundColor: T
                    .primary(context)
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _nudgeBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    )
                  : Text(
                      _pendingFare != null
                          ? l10n.instantRaiseTo(
                              _formatFare(_pendingFare!),
                              request.currency,
                            )
                          : l10n.instantRaiseFare,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingView(BuildContext context, InstantRequest request) {
    final l10n = context.l10n;
    final counter = request.counterOffer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (counter != null) ...[
          _buildCounterOfferCard(context, request, counter),
          const SizedBox(height: 14),
        ] else ...[
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: T.primary(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.instantSearching,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.instantSearchingSubtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        _buildSearchingMetrics(context, request),
        const SizedBox(height: 12),
        _buildSearchFareCard(context, request),
        if (request.nudge != null &&
            request.nudge!.suggestedFare != _dismissedNudgeFare) ...[
          const SizedBox(height: 12),
          _buildNudgeCard(context, request.nudge!),
        ] else ...[
          const SizedBox(height: 12),
          _buildSearchingTip(context),
        ],
        const SizedBox(height: 14),
        Divider(height: 1, color: T.outlineVariant(context)),
        const SizedBox(height: 14),
        _buildProgressSteps(context, request),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _counterBusy || _nudgeBusy ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              l10n.instantCancelRequest,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Expected pickup / distance / duration, each in its own outlined card.
  /// Distance and duration come with the request from newer backends, else
  /// from the quote taken just before it was sent.
  Widget _buildSearchingMetrics(BuildContext context, InstantRequest request) {
    final l10n = context.l10n;
    final eta = _driverEtaMinutes;
    final distance = request.distanceKm ?? _quote?.distanceKm;
    final duration = request.durationMinutes ?? _quote?.durationMinutes;

    String km(double? v) => v == null
        ? '--'
        : l10n.instantSearchingKm(
            v == v.roundToDouble()
                ? v.round().toString()
                : v.toStringAsFixed(1),
          );
    String min(int? v) =>
        v == null ? '--' : l10n.instantSearchingMinutes(v.toString());

    return Row(
      children: [
        Expanded(
          child: _searchingMetricCard(
            context,
            icon: Icons.schedule,
            label: l10n.instantSearchingEta,
            value: min(eta),
            caption: l10n.instantSearchingApprox,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _searchingMetricCard(
            context,
            icon: Icons.route_outlined,
            label: l10n.instantFormDistance,
            value: km(distance),
            caption: '',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _searchingMetricCard(
            context,
            icon: Icons.timer_outlined,
            label: l10n.instantFormDuration,
            value: min(duration),
            caption: l10n.instantSearchingApprox,
          ),
        ),
      ],
    );
  }

  Widget _searchingMetricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String caption,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.outlineVariant(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: T.primary(context)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption.isEmpty ? ' ' : caption,
            style: TextStyle(fontSize: 11, color: T.onSurfaceVariant(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingTip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: T.primary(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.primary(context).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 20, color: T.primary(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.instantSearchingTip,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: T.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Where the request stands: sent → finding a driver → driver offer →
  /// driver on the way. Only stages this flow actually goes through.
  Widget _buildProgressSteps(BuildContext context, InstantRequest request) {
    final l10n = context.l10n;
    final hasOffer = request.counterOffer != null;
    final matched = request.isMatched;

    final steps = [
      (Icons.check, l10n.instantStepRequested, _StepState.done),
      (
        Icons.search,
        l10n.instantStepSearching,
        hasOffer || matched ? _StepState.done : _StepState.active,
      ),
      (
        Icons.local_offer_outlined,
        l10n.instantStepDriverOffer,
        matched
            ? _StepState.done
            : hasOffer
            ? _StepState.active
            : _StepState.upcoming,
      ),
      (
        Icons.directions_car_outlined,
        l10n.instantStepDriverOnWay,
        matched ? _StepState.active : _StepState.upcoming,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Container(
                  height: 2,
                  color: steps[i - 1].$3 == _StepState.done
                      ? T.primary(context)
                      : T.outlineVariant(context),
                ),
              ),
            ),
          _progressStep(context, steps[i].$1, steps[i].$2, steps[i].$3),
        ],
      ],
    );
  }

  Widget _progressStep(
    BuildContext context,
    IconData icon,
    String label,
    _StepState state,
  ) {
    final primary = T.primary(context);
    final Color fill;
    final Color ring;
    final Color fg;
    switch (state) {
      case _StepState.done:
        fill = primary;
        ring = primary;
        fg = AppColors.white;
      case _StepState.active:
        fill = primary.withValues(alpha: 0.12);
        ring = primary;
        fg = primary;
      case _StepState.upcoming:
        fill = T.surface(context);
        ring = T.outlineVariant(context);
        fg = T.onSurfaceVariant(context);
    }
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 2),
            ),
            child: Icon(
              state == _StepState.done ? Icons.check : icon,
              size: 18,
              color: fg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: state == _StepState.upcoming
                  ? FontWeight.normal
                  : FontWeight.w600,
              color: state == _StepState.upcoming
                  ? T.onSurfaceVariant(context)
                  : T.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }

  /// inDrive-style nudge: "Try raising your fare — [Raise to X] [Keep Y]".
  Widget _buildNudgeCard(BuildContext context, InstantNudge nudge) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            context.l10n.instantNudgeTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.instantNudgeSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: T.onSurfaceVariant(context)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _nudgeBusy
                  ? null
                  : () => _raiseFare(nudge.suggestedFare),
              style: ElevatedButton.styleFrom(
                backgroundColor: T.primary(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _nudgeBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    )
                  : Text(
                      context.l10n.instantRaiseTo(
                        nudge.suggestedFare,
                        nudge.currency,
                      ),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _nudgeBusy
                ? null
                : () =>
                      setState(() => _dismissedNudgeFare = nudge.suggestedFare),
            child: Text(
              context.l10n.instantKeepFare(nudge.currentFare, nudge.currency),
              style: TextStyle(color: T.onSurfaceVariant(context)),
            ),
          ),
        ],
      ),
    );
  }

  /// inDrive-style bid card: the driver's counter fare with Accept/Decline.
  Widget _buildCounterOfferCard(
    BuildContext context,
    InstantRequest request,
    InstantCounterOffer offer,
  ) {
    final remaining = offer.expiresAt != null
        ? offer.expiresAt!.difference(DateTime.now()).inSeconds
        : 0;
    final yourFare = request.passengerFare ?? request.fareEstimate;
    final vehicleLine = [
      if (offer.vehicleModel != null && offer.vehicleModel!.isNotEmpty)
        offer.vehicleModel!,
      if (offer.plateNumber != null && offer.plateNumber!.isNotEmpty)
        offer.plateNumber!,
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.primary(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.instantDriverOfferTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
              if (remaining > 0)
                Text(
                  context.l10n.instantOfferCountdown(remaining),
                  style: TextStyle(
                    fontSize: 12,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: T.primary(context).withValues(alpha: 0.12),
                child: Icon(Icons.person, color: T.primary(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.driverName ?? '—',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (offer.driverRating != null) ...[
                          const Icon(
                            Icons.star,
                            size: 15,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            offer.driverRating!.toStringAsFixed(1) +
                                (offer.driverTotalRatings != null
                                    ? ' (${offer.driverTotalRatings})'
                                    : ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: T.onSurfaceVariant(context),
                            ),
                          ),
                        ],
                        if (vehicleLine.isNotEmpty) ...[
                          if (offer.driverRating != null)
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              vehicleLine,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: T.onSurfaceVariant(context),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${offer.proposedFare} ${offer.currency}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: T.primary(context),
                ),
              ),
              const SizedBox(width: 10),
              if (yourFare != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    context.l10n.instantYourFareValue(
                      yourFare,
                      request.currency,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _counterBusy ? null : _declineCounter,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.l10n.instantDecline,
                    style: TextStyle(color: T.onSurface(context)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _counterBusy ? null : _acceptCounter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _counterBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : Text(
                          context.l10n.instantAccept,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Matched ──────────────────────────────────────────────────────────────────

  String? _matchedTripId(InstantRequest request, InstantMatch match) {
    final id = match.tripId ?? request.tripId;
    return id == null || id.isEmpty ? null : id;
  }

  void _openChat(InstantRequest request, InstantMatch match) {
    final tripId = _matchedTripId(request, match);
    if (tripId == null) return;
    Navigator.pushNamed(
      context,
      RouteNames.chat,
      arguments: {
        'tripId': tripId,
        'driverId': match.driverId ?? request.matchedDriverId ?? '',
        'driverName': match.driverName ?? '',
      },
    );
  }

  /// In-app call through the booking's proxy number, then hand off to the
  /// phone dialler.
  Future<void> _callDriver(InstantMatch match) async {
    final bookingId = match.bookingId;
    if (_callBusy) return;
    if (bookingId == null || bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.instantMatchedCallFailed)),
      );
      return;
    }
    setState(() => _callBusy = true);
    try {
      final number = await _service.initiateCall(bookingId);
      final launched = await launchUrl(Uri(scheme: 'tel', path: number));
      if (!launched) throw StateError('dialler unavailable');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.instantMatchedCallFailed)),
      );
    } finally {
      if (mounted) setState(() => _callBusy = false);
    }
  }

  void _shareTrip(InstantRequest request, InstantMatch match) {
    final tripId = _matchedTripId(request, match);
    if (tripId == null) return;
    ShareTrackingSheet.show(context, tripId);
  }

  void _trackTrip(InstantRequest request, InstantMatch match) {
    final tripId = _matchedTripId(request, match);
    if (tripId == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TripDetailsScreen(tripId: tripId)),
    );
  }

  /// After a match the request itself is final; cancelling means cancelling
  /// the booking the accept created, which also frees the driver.
  Future<void> _cancelMatched(InstantMatch match) async {
    final bookingId = match.bookingId;
    if (bookingId == null || bookingId.isEmpty || _cancelBusy) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.instantMatchedCancelTitle),
        content: Text(l10n.instantMatchedCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.instantMatchedKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.cancelBooking,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelBusy = true);
    try {
      await _bookingService.cancelBooking(bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookingCancelledSuccess)));
      _reset();
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _cancelBusy = false);
    }
  }

  /// "تم العثور على سائق": check header, ETA / distance / duration strip,
  /// driver card with chat + call, share-with-contact row, track CTA, cancel.
  Widget _buildMatchedView(
    BuildContext context,
    InstantRequest request,
    InstantMatch match,
  ) {
    final l10n = context.l10n;
    final canCancel = match.bookingId != null && match.bookingId!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: T.primary(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppColors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.instantDriverFound,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.instantMatchedSubtitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildMatchedMetrics(context, request, match),
        const SizedBox(height: 12),
        _buildDriverCard(context, request, match),
        const SizedBox(height: 12),
        _buildShareRow(context, request, match),
        const SizedBox(height: 14),
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: () => _trackTrip(request, match),
            style: ElevatedButton.styleFrom(
              backgroundColor: T.primary(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.instantTrackTrip,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n.instantMatchedTrackSubtitle,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (canCancel) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _cancelBusy ? null : () => _cancelMatched(match),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.instantCancelRequest,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMatchedMetrics(
    BuildContext context,
    InstantRequest request,
    InstantMatch match,
  ) {
    final l10n = context.l10n;
    final eta = match.pickupEtaMinutes ?? _driverEtaMinutes;
    final distance = request.distanceKm ?? _quote?.distanceKm;
    final duration = request.durationMinutes ?? _quote?.durationMinutes;

    String km(double? v) => v == null
        ? '--'
        : l10n.instantSearchingKm(
            v == v.roundToDouble()
                ? v.round().toString()
                : v.toStringAsFixed(1),
          );
    String min(int? v) =>
        v == null ? '--' : l10n.instantSearchingMinutes(v.toString());

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.outlineVariant(context)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _matchedMetric(
                context,
                icon: Icons.schedule,
                label: l10n.instantMatchedArrival,
                value: min(eta),
                caption: l10n.instantSearchingApprox,
              ),
            ),
            _metricDivider(context),
            Expanded(
              child: _matchedMetric(
                context,
                icon: Icons.route_outlined,
                label: l10n.instantFormDistance,
                value: km(distance),
                caption: '',
              ),
            ),
            _metricDivider(context),
            Expanded(
              child: _matchedMetric(
                context,
                icon: Icons.timer_outlined,
                label: l10n.instantFormDuration,
                value: min(duration),
                caption: l10n.instantSearchingApprox,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchedMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String caption,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: T.primary(context)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: T.onSurfaceVariant(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption.isEmpty ? ' ' : caption,
          style: TextStyle(fontSize: 11, color: T.onSurfaceVariant(context)),
        ),
      ],
    );
  }

  Widget _buildDriverCard(
    BuildContext context,
    InstantRequest request,
    InstantMatch match,
  ) {
    final l10n = context.l10n;
    final photo = match.driverPhotoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final plate = match.plateNumber;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outlineVariant(context)),
      ),
      child: Row(
        children: [
          _driverAction(
            context,
            icon: Icons.phone_outlined,
            label: l10n.call,
            busy: _callBusy,
            onTap: () => _callDriver(match),
          ),
          const SizedBox(width: 10),
          _driverAction(
            context,
            icon: Icons.chat_bubble_outline,
            label: l10n.chat,
            onTap: () => _openChat(request, match),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.driverName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: T.onSurface(context),
                  ),
                ),
                if (match.driverRating != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.star, size: 15, color: T.primary(context)),
                      const SizedBox(width: 3),
                      Text(
                        match.driverRating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: T.primary(context),
                        ),
                      ),
                    ],
                  ),
                ],
                if (match.vehicleModel != null &&
                    match.vehicleModel!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    match.vehicleModel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                ],
                if (plate != null && plate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: T.outline(context)),
                    ),
                    child: Text(
                      plate,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: T.onSurface(context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: T.primary(context).withValues(alpha: 0.12),
                backgroundImage: hasPhoto ? NetworkImage(photo) : null,
                child: hasPhoto
                    ? null
                    : Icon(Icons.person, color: T.primary(context), size: 30),
              ),
              if (match.acceptedFare != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${match.acceptedFare} ${match.currency}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: T.primary(context),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _driverAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: T.primary(context).withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : onTap,
            child: SizedBox(
              width: 50,
              height: 50,
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(15),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: T.primary(context),
                      ),
                    )
                  : Icon(icon, color: T.primary(context), size: 22),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: T.onSurface(context)),
        ),
      ],
    );
  }

  Widget _buildShareRow(
    BuildContext context,
    InstantRequest request,
    InstantMatch match,
  ) {
    return Material(
      color: T.primary(context).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _shareTrip(request, match),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: T.primary(context), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.instantMatchedShareTitle,
                  style: TextStyle(fontSize: 12.5, color: T.onSurface(context)),
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: T.onSurfaceVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusView(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String primaryLabel,
    required VoidCallback onPrimary,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: T.onSurface(context),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: T.onSurfaceVariant(context)),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: T.primary(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              primaryLabel,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Visual state of one stage in the searching sheet's progress row.
enum _StepState { done, active, upcoming }
