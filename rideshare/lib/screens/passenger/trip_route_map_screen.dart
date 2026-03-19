import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../models/trip_model.dart';
import '../../core/api/websocket_service.dart';

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

  // Route data
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Driver live location
  LatLng? _driverLocation;
  BitmapDescriptor? _driverIcon;

  // Route info
  String _distance = '';
  String _duration = '';
  bool _isLoadingRoute = true;
  bool _isFollowingDriver = false;

  // Google Maps Directions API key (same key used in AndroidManifest.xml)
  static const String _apiKey = 'AIzaSyBS4ULytH5msEGRECGedllgf3ziF1Q5Itw';

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
          title: 'نقطة الانطلاق',
          snippet: widget.trip.from.name,
        ),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _toLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'الوجهة',
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
      icon: _driverIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'موقع السائق'),
      anchor: const Offset(0.5, 0.5),
      zIndex: 3,
    );

    _markers.removeWhere((m) => m.markerId.value == 'driver_live');
    _markers.add(driverMarker);
  }

  Future<void> _fetchRoute() async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${_fromLatLng.latitude},${_fromLatLng.longitude}'
          '&destination=${_toLatLng.latitude},${_toLatLng.longitude}'
          '&key=$_apiKey'
          '&language=ar';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final overviewPolyline = route['overview_polyline']['points'];
          final legs = route['legs'][0];

          final points = _decodePolyline(overviewPolyline);

          setState(() {
            _distance = legs['distance']['text'];
            _duration = legs['duration']['text'];
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: const Color(0xFF1565C0),
                width: 5,
                patterns: [],
              ),
            };
            _isLoadingRoute = false;
          });
        } else {
          // No route found, draw straight line
          _drawStraightLine();
        }
      } else {
        _drawStraightLine();
      }
    } catch (e) {
      _drawStraightLine();
    }
  }

  void _drawStraightLine() {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_fromLatLng, _toLatLng],
          color: const Color(0xFF1565C0),
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
      _isLoadingRoute = false;
    });
  }

  /// Decode Google's encoded polyline string into a list of LatLng points
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
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

    double minLat = allPoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = allPoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = allPoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = allPoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.02, minLng - 0.02),
      northeast: LatLng(maxLat + 0.02, maxLng + 0.02),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen Google Map ──
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

          // ── Top Safe Area Controls ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Back button
                  _CircleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Fit bounds button
                  _CircleButton(
                    icon: Icons.fullscreen,
                    onTap: _fitBounds,
                  ),
                ],
              ),
            ),
          ),

          // ── Loading indicator for route ──
          if (_isLoadingRoute)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('جاري تحميل المسار...'),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom Info Panel ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),

      // ── Follow driver FAB ──
      floatingActionButton: _driverLocation != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 200),
              child: FloatingActionButton.small(
                heroTag: 'follow_driver',
                backgroundColor: _isFollowingDriver
                    ? const Color(0xFF1565C0)
                    : Colors.white,
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
                      ? Colors.white
                      : const Color(0xFF1565C0),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
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
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // From - To
              Row(
                children: [
                  // Route indicator dots
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 30,
                        color: Colors.grey[300],
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF44336),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Location names
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
                // Distance & Duration chips
                Row(
                  children: [
                    if (_distance.isNotEmpty)
                      _InfoChip(
                        icon: Icons.straighten,
                        label: _distance,
                        color: const Color(0xFF1565C0),
                      ),
                    if (_distance.isNotEmpty && _duration.isNotEmpty)
                      const SizedBox(width: 12),
                    if (_duration.isNotEmpty)
                      _InfoChip(
                        icon: Icons.access_time_filled,
                        label: _duration,
                        color: const Color(0xFFE65100),
                      ),
                  ],
                ),
              ],

              // Live tracking status
              if (_driverLocation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'التتبع المباشر مفعل',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _isFollowingDriver
                            ? Icons.gps_fixed
                            : Icons.gps_not_fixed,
                        color: const Color(0xFF2E7D32),
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

// ── Reusable Circle Button ──
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

// ── Info Chip ──
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
