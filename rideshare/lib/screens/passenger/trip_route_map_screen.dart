import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/trip_model.dart';
import '../../core/api/websocket_service.dart';
import '../../core/services/route_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';

class TripRouteMapScreen extends StatefulWidget {
  final TripModel trip;

  const TripRouteMapScreen({super.key, required this.trip});

  @override
  State<TripRouteMapScreen> createState() => _TripRouteMapScreenState();
}

class _TripRouteMapScreenState extends State<TripRouteMapScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final WebSocketService _socketService = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _trackingSubscription;

  final RouteService _routeService = RouteService(
  );

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  LatLng? _driverLocation;
  BitmapDescriptor? _driverIcon;

  String _distance = '';
  String _duration = '';
  bool _isLoadingRoute = true;
  bool _isFollowingDriver = false;

  late LatLng _fromLatLng;
  late LatLng _toLatLng;

  @override
  void initState() {
    super.initState();
    _fromLatLng = LatLng(widget.trip.from.latitude, widget.trip.from.longitude);
    _toLatLng = LatLng(widget.trip.to.latitude, widget.trip.to.longitude);
    _setupMarkers();
    _fetchRoute();
    _initTracking();
  }

  void _setupMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('origin'),
        position: _fromLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: context.l10n.departurePointTitle,
          snippet: widget.trip.from.name,
        ),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _toLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: context.l10n.destinationTitle,
          snippet: widget.trip.to.name,
        ),
      ),
    };
  }

  Future<void> _initTracking() async {
    await _socketService.connect();
    _socketService.subscribeToTripTracking(widget.trip.id);
    _trackingSubscription = _socketService.onTrackingUpdate.listen((payload) {
      final payloadTripId = payload['tripId']?.toString();
      if (payloadTripId != widget.trip.id) return;

      final lat = payload['latitude'];
      final lng = payload['longitude'];
      if (lat is num && lng is num) {
        setState(() {
          _driverLocation = LatLng(lat.toDouble(), lng.toDouble());
          _updateDriverMarker();
        });

        if (_isFollowingDriver && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(_driverLocation!),
          );
        }
      }
    });
  }

  void _updateDriverMarker() {
    if (_driverLocation == null) return;

    final driverMarker = Marker(
      markerId: const MarkerId('driver_live'),
      position: _driverLocation!,
      icon:
          _driverIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(title: context.l10n.driverLocationTitle),
      anchor: const Offset(0.5, 0.5),
    );

    _markers = {
      ..._markers.where((m) => m.markerId.value != 'driver_live'),
      driverMarker,
    };
  }

  Future<void> _fetchRoute() async {
    final result = await _routeService.fetchRoute(
      origin: _fromLatLng,
      destination: _toLatLng,
    );

    if (!mounted) return;

    switch (result) {
      case RouteOk(:final polyline, :final bounds, :final distance, :final duration):
        setState(() {
          _distance = distance;
          _duration = duration;
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: polyline,
              color: AppColors.teal700,
              width: 5,
              patterns: [],
            ),
          };
          _isLoadingRoute = false;
        });
        if (bounds != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 80),
          );
        }
      case RouteUnavailable(:final failure):
        setState(() {
          _isLoadingRoute = false;
        });
        ErrorSurface.showFailure(
          context,
          failure,
          onRetry: _fetchRoute,
        );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  void _fitBounds() {
    if (_mapController == null) return;

    List<LatLng> allPoints = [_fromLatLng, _toLatLng];
    if (_driverLocation != null) {
      allPoints.add(_driverLocation!);
    }

    double minLat = allPoints
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLat = allPoints
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    double minLng = allPoints
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLng = allPoints
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.02, minLng - 0.02),
      northeast: LatLng(maxLat + 0.02, maxLng + 0.02),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _fromLatLng,
              zoom: 10,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                    semanticLabel: context.l10n.back,
                  ),
                  const Spacer(),
                  _CircleButton(
                    icon: Icons.fullscreen,
                    onTap: _fitBounds,
                    semanticLabel: context.l10n.viewFullRoute,
                  ),
                ],
              ),
            ),
          ),

          if (_isLoadingRoute)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Semantics(
                        label: context.l10n.loadingRouteLabel,
                        child: Text(context.l10n.loadingRoute),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomPanel()),
        ],
      ),

      floatingActionButton: _driverLocation != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 200),
              child: Semantics(
                button: true,
                label: _isFollowingDriver
                    ? context.l10n.stopFollowingDriver
                    : context.l10n.followDriver,
                child: FloatingActionButton.small(
                  heroTag: 'follow_driver',
                  backgroundColor: _isFollowingDriver
                      ? AppColors.teal700
                      : AppColors.white,
                  onPressed: () {
                    setState(() {
                      _isFollowingDriver = !_isFollowingDriver;
                    });
                    if (_isFollowingDriver && _driverLocation != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_driverLocation!, 15),
                      );
                    }
                  },
                  child: Icon(
                    Icons.gps_fixed,
                    color: _isFollowingDriver
                        ? AppColors.white
                        : AppColors.teal700,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: T.outlineVariant(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 30,
                        color: T.outlineVariant(context),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: T.error(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.trip.from.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.trip.to.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_distance.isNotEmpty || _duration.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_distance.isNotEmpty)
                      _InfoChip(
                        icon: Icons.straighten,
                        label: _distance,
                        color: AppColors.teal700,
                      ),
                    if (_distance.isNotEmpty && _duration.isNotEmpty)
                      const SizedBox(width: 12),
                    if (_duration.isNotEmpty)
                      _InfoChip(
                        icon: Icons.access_time_filled,
                        label: _duration,
                        color: AppColors.warningDark,
                      ),
                  ],
                ),
              ],

              if (_driverLocation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                      Text(
                        context.l10n.liveTrackingEnabled,
                        style: const TextStyle(
                          color: AppColors.successDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _isFollowingDriver
                            ? Icons.gps_fixed
                            : Icons.gps_not_fixed,
                        color: AppColors.successDark,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socketService.unsubscribeFromTripTracking(widget.trip.id);
    _trackingSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppColors.white,
        elevation: 4,
        shadowColor: AppColors.black.withValues(alpha: 0.26),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
