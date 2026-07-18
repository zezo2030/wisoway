import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/services/instant_ride_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/route_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/instant_ride_models.dart';
import '../../models/location_model.dart';
import '../../widgets/location_autocomplete_field.dart';
import 'trip_details_screen.dart';

/// Passenger "اطلب الآن" flow, inDrive-style: a full-screen map with a pinned
/// bottom sheet for pickup + destination, then the live search progress
/// (searching → matched / no drivers) shown over the same map.
class InstantRideRequestScreen extends StatefulWidget {
  final LocationModel? initialFrom;

  const InstantRideRequestScreen({super.key, this.initialFrom});

  @override
  State<InstantRideRequestScreen> createState() =>
      _InstantRideRequestScreenState();
}

class _InstantRideRequestScreenState extends State<InstantRideRequestScreen> {
  static const LatLng _fallbackCenter = LatLng(31.9539, 35.9106); // Amman

  final InstantRideService _service = InstantRideService();
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng _mapCenter = _fallbackCenter;
  bool _locatingMe = false;

  List<LatLng> _routePoints = const [];
  String _routeDistance = '';
  String _routeDuration = '';
  int _routeRequestSeq = 0;

  LocationModel? _from;
  LocationModel? _to;
  bool _submitting = false;
  InstantRequest? _request;
  Timer? _poll;
  Timer? _countdownTicker;

  InstantQuote? _quote;
  double? _fare;
  bool _quoteLoading = false;
  int _quoteSeq = 0;
  bool _counterBusy = false;

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
  }

  @override
  void dispose() {
    _poll?.cancel();
    _countdownTicker?.cancel();
    _mapController?.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  // ── Map ─────────────────────────────────────────────────────────────────────

  Future<void> _resolveCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      final target = LatLng(location.latitude, location.longitude);
      setState(() => _mapCenter = target);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
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
          _routeDistance = '';
          _routeDuration = '';
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
        _routeDistance = result.distance;
        _routeDuration = result.duration;
      } else {
        _routePoints = [origin, destination];
        _routeDistance = '';
        _routeDuration = '';
      }
    });
    _focusCamera();
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: _from!.name),
        ),
      );
    }
    if (_to != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('to'),
          position: LatLng(_to!.latitude, _to!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _to!.name),
        ),
      );
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
          _fare = null;
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
        _fare = quote.recommendedFare;
        _quoteLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _quoteSeq) return;
      // Keep any previous quote; the server re-validates on submit anyway.
      setState(() => _quoteLoading = false);
    }
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
    final current = _fare ?? quote.recommendedFare;
    final next = (current + direction * _fareStep)
        .clamp(quote.minFare, quote.maxFare);
    setState(() => _fare = (next * 100).roundToDouble() / 100);
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
        passengerFare: _fare,
      );
      if (!mounted) return;
      setState(() => _request = request);
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
    if (mounted) setState(() => _request = null);
  }

  void _reset() {
    _poll?.cancel();
    _countdownTicker?.cancel();
    setState(() => _request = null);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          _buildTopBar(context),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _request == null
                  ? _buildFormSheet(context)
                  : _buildStatusSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(target: _mapCenter, zoom: 14),
      markers: _buildMarkers(),
      polylines: _buildPolylines(),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      // Leave room so the bottom sheet doesn't cover the Google logo / markers.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.42,
      ),
      onTap: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return PositionedDirectional(
      top: MediaQuery.of(context).padding.top + 8,
      start: 12,
      child: _circleButton(
        context,
        icon: Icons.arrow_back,
        onTap: () => Navigator.of(context).maybePop(),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _grabHandle() {
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(
        color: T.outline(context),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // ── Form sheet ─────────────────────────────────────────────────────────────────

  Widget _buildFormSheet(BuildContext context) {
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.6;
    final ready = _from != null && _to != null && !_submitting;

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      context.l10n.instantRequestNowTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: T.onSurface(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LocationAutocompleteField(
                            controller: _fromController,
                            hint: context.l10n.instantFromHint,
                            mapPickerTitle: context.l10n.instantFromPickerTitle,
                            icon: Icons.trip_origin,
                            iconColor: AppColors.success,
                            initialLocation: _from,
                            onLocationSelected: (loc) {
                              setState(() => _from = loc);
                              if (loc != null) _focusCamera();
                              _updateRoute();
                              _updateQuote();
                            },
                          ),
                          const SizedBox(height: 12),
                          LocationAutocompleteField(
                            controller: _toController,
                            hint: context.l10n.instantToHint,
                            mapPickerTitle: context.l10n.instantToPickerTitle,
                            icon: Icons.location_on,
                            iconColor: AppColors.error,
                            initialLocation: _to,
                            onLocationSelected: (loc) {
                              setState(() => _to = loc);
                              if (loc != null) _focusCamera();
                              _updateRoute();
                              _updateQuote();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildRouteSummary(context),
                _buildFareStepper(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: ready ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: T.primary(context),
                        disabledBackgroundColor: T
                            .primary(context)
                            .withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _submitting
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
                          : const Icon(
                              Icons.electric_bolt,
                              color: AppColors.white,
                            ),
                      label: Text(
                        context.l10n.instantRequestNow,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
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

  /// Distance + estimated duration strip, shown once a route is available.
  Widget _buildRouteSummary(BuildContext context) {
    if (_routeDistance.isEmpty && _routeDuration.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_routeDuration.isNotEmpty)
            _routeMetric(context, Icons.schedule, _routeDuration),
          if (_routeDuration.isNotEmpty && _routeDistance.isNotEmpty)
            const SizedBox(width: 20),
          if (_routeDistance.isNotEmpty)
            _routeMetric(context, Icons.straighten, _routeDistance),
        ],
      ),
    );
  }

  /// inDrive-style fare row: − / + steppers around the passenger's fare,
  /// seeded with the server's distance-based recommendation.
  Widget _buildFareStepper(BuildContext context) {
    final quote = _quote;
    if (quote == null) {
      if (!_quoteLoading) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final fare = _fare ?? quote.recommendedFare;
    final canDecrease = fare - _fareStep >= quote.minFare - 0.001;
    final canIncrease = fare + _fareStep <= quote.maxFare + 0.001;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: T.surfaceVariant(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _fareStepButton(
              context,
              icon: Icons.remove,
              enabled: canDecrease,
              onTap: () => _bumpFare(-1),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${fare.toStringAsFixed(2)} ${quote.currency}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.instantRecommendedFare(
                      quote.recommendedFare.toStringAsFixed(2),
                      quote.currency,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                ],
              ),
            ),
            _fareStepButton(
              context,
              icon: Icons.add,
              enabled: canIncrease,
              onTap: () => _bumpFare(1),
            ),
          ],
        ),
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

  Widget _routeMetric(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: T.primary(context)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: T.onSurface(context),
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
    } else if (request.isFailed) {
      final isCancelled = request.status == 'cancelled';
      content = _statusView(
        context,
        icon: isCancelled ? Icons.cancel : Icons.search_off,
        color: AppColors.error,
        title: isCancelled
            ? context.l10n.instantRequestCancelled
            : context.l10n.instantNoDrivers,
        subtitle: isCancelled ? '' : context.l10n.instantNoDriversSubtitle,
        primaryLabel: context.l10n.instantTryAgain,
        onPrimary: _reset,
      );
    } else {
      content = _buildSearchingView(context, request);
    }

    return _sheetContainer(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_grabHandle(), content],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingView(BuildContext context, InstantRequest request) {
    final counter = request.counterOffer;
    final yourFare = request.passengerFare ?? request.fareEstimate;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (counter != null)
          _buildCounterOfferCard(context, request, counter)
        else ...[
          const SizedBox(height: 8),
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 5),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.instantSearching,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${request.fromName} ← ${request.toName}',
            textAlign: TextAlign.center,
            style: TextStyle(color: T.onSurfaceVariant(context)),
          ),
          if (yourFare != null) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.instantYourFareValue(yourFare, request.currency),
              style: TextStyle(color: T.onSurfaceVariant(context)),
            ),
          ],
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: _counterBusy ? null : _cancel,
          child: Text(
            context.l10n.instantCancelRequest,
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
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
