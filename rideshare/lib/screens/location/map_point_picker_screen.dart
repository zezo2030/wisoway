import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/services/location_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/location_model.dart';

/// Pick an exact point by moving the map under a fixed centre pin.
///
/// The pin never moves and the map is not tappable — the user drags the map
/// beneath it and confirms, which is the inDrive interaction. There is no
/// search field here on purpose: text search lives in the route search screen,
/// so a query only ever hits one code path.
///
/// Pops a [LocationModel] on confirm, or null when the user backs out.
class MapPointPickerScreen extends StatefulWidget {
  const MapPointPickerScreen({
    super.key,
    required this.confirmLabel,
    this.title,
    this.initialLocation,
    this.fallbackCenter,
    this.locationService,
  });

  /// Text on the confirm button, e.g. "Confirm pickup point".
  final String confirmLabel;
  final String? title;

  /// Point the map opens on, when the field already holds a place.
  final LocationModel? initialLocation;

  /// Where to open when there is no field value and no device location —
  /// typically the chosen city's centre. Shown for orientation only; it is
  /// never returned unless the user confirms it.
  final LatLng? fallbackCenter;

  final LocationService? locationService;

  @override
  State<MapPointPickerScreen> createState() => _MapPointPickerScreenState();
}

class _MapPointPickerScreenState extends State<MapPointPickerScreen> {
  /// Country-level view used when nothing better is known, so the user can see
  /// where they are before zooming in.
  static const LatLng _wideFallbackCenter = LatLng(31.9539, 35.9106);
  static const double _pointZoom = 16;
  static const double _cityZoom = 12;
  static const double _wideZoom = 7;

  /// Settle time after the camera stops before asking for an address, so a
  /// drag that passes over ten neighbourhoods only costs one request.
  static const Duration _idleDelay = Duration(milliseconds: 400);

  late final LocationService _locationService =
      widget.locationService ?? LocationService();

  GoogleMapController? _mapController;
  Timer? _idleTimer;
  CancelToken? _addressRequest;

  LatLng? _center;
  ReverseGeocodeResult? _address;
  bool _isMoving = false;
  bool _isResolvingAddress = false;
  bool _isReady = false;

  /// Incremented per address lookup; a response for an older sequence is
  /// dropped so a slow reply cannot relabel a point the user has left.
  int _addressSequence = 0;

  @override
  void initState() {
    super.initState();
    _resolveInitialCamera();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _addressRequest?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _resolveInitialCamera() async {
    final initial = widget.initialLocation;
    if (initial != null) {
      _center = LatLng(initial.latitude, initial.longitude);
      setState(() => _isReady = true);
      _requestAddress(_center!);
      return;
    }

    // Do not block the map on GPS: show the fallback immediately and move to
    // the device location if it arrives.
    _center = widget.fallbackCenter ?? _wideFallbackCenter;
    setState(() => _isReady = true);

    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      final target = LatLng(position.latitude, position.longitude);
      _center = target;
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, _pointZoom),
      );
      _requestAddress(target);
    } catch (_) {
      if (!mounted) return;
      // No device location: the fallback stays on screen purely as a view.
      // It is not treated as a chosen point — the user must still confirm.
      _requestAddress(_center!);
    }
  }

  double get _initialZoom {
    if (widget.initialLocation != null) return _pointZoom;
    if (widget.fallbackCenter != null) return _cityZoom;
    return _wideZoom;
  }

  void _onCameraMoveStarted() {
    _idleTimer?.cancel();
    // Abandon the in-flight lookup: its answer is about a point the user has
    // already moved away from.
    _addressRequest?.cancel();
    _addressSequence++;
    if (_isMoving && _address == null) return;
    setState(() {
      _isMoving = true;
      _address = null;
      _isResolvingAddress = false;
    });
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
  }

  void _onCameraIdle() {
    setState(() => _isMoving = false);
    final target = _center;
    if (target == null) return;

    _idleTimer?.cancel();
    _idleTimer = Timer(_idleDelay, () => _requestAddress(target));
  }

  Future<void> _requestAddress(LatLng target) async {
    final sequence = ++_addressSequence;
    final cancelToken = CancelToken();
    _addressRequest?.cancel();
    _addressRequest = cancelToken;

    setState(() => _isResolvingAddress = true);

    try {
      final result = await _locationService.reverseGeocode(
        latitude: target.latitude,
        longitude: target.longitude,
        cancelToken: cancelToken,
      );
      // A newer lookup started while this one was in flight.
      if (!mounted || sequence != _addressSequence) return;
      setState(() {
        _address = result;
        _isResolvingAddress = false;
      });
    } catch (_) {
      if (!mounted || sequence != _addressSequence) return;
      // The point stays confirmable; only its label is missing.
      setState(() {
        _address = null;
        _isResolvingAddress = false;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          _pointZoom,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.locationCurrentUnavailable)),
      );
    }
  }

  void _confirm() {
    final target = _center;
    if (target == null) return;

    final address = _address;
    final name = address != null && !address.isEmpty
        ? (address.primaryText.isNotEmpty
              ? address.primaryText
              : address.label)
        // No address: name the point by its coordinates so the trip still has
        // a readable label the driver can recognise.
        : '${target.latitude.toStringAsFixed(5)}, '
              '${target.longitude.toStringAsFixed(5)}';

    Navigator.of(context).pop(
      LocationModel(
        name: name,
        latitude: target.latitude,
        longitude: target.longitude,
        address: address != null && !address.isEmpty ? address.label : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: !_isReady
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  _buildMap(),
                  _buildCenterPin(),
                  _buildTopBar(context),
                  _buildBottomPanel(context),
                ],
              ),
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _center ?? _wideFallbackCenter,
        zoom: _initialZoom,
      ),
      onMapCreated: (controller) => _mapController = controller,
      onCameraMoveStarted: _onCameraMoveStarted,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }

  /// The pin is a widget over the map, not a marker: it must stay pinned to
  /// the screen centre while the map moves under it.
  ///
  /// The address rides on the pin in a small bubble, as it does in inDrive —
  /// the name of the point and the point itself stay in one place, so the eye
  /// never leaves the spot it is choosing.
  Widget _buildCenterPin() {
    return IgnorePointer(
      child: Center(
        child: Padding(
          // Lift by half the pin height so its tip, not its middle, marks the
          // point the camera is centred on.
          padding: const EdgeInsets.only(bottom: 44),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 150),
            offset: _isMoving ? const Offset(0, -0.12) : Offset.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPinBubble(context),
                const SizedBox(height: 2),
                Icon(
                  Icons.location_on,
                  size: 44,
                  color: T.primary(context),
                  shadows: const [
                    Shadow(blurRadius: 6, color: Color(0x55000000)),
                  ],
                ),
                Container(
                  width: 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The label above the pin: the street the pin is on, or why it has no name
  /// yet. Kept to one short line — the full address sits in the panel below.
  Widget _buildPinBubble(BuildContext context) {
    final address = _address;
    final label = _isMoving || _isResolvingAddress
        ? context.l10n.routeSearchLoadingAddress
        : (address == null || address.isEmpty
              ? context.l10n.routeSearchAddressUnavailable
              : (address.primaryText.isNotEmpty
                    ? address.primaryText
                    : address.label));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Material(
            color: T.primary(context),
            borderRadius: BorderRadius.circular(10),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onPrimary(context),
                ),
              ),
            ),
          ),
        ),
        // The bubble's tail, pointing down at the pin.
        Transform.translate(
          offset: const Offset(0, -3),
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(width: 8, height: 8, color: T.primary(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // Just the way back: the address travels with the pin now, so the top of
    // the map stays clear and the user can see where they are dragging to.
    return PositionedDirectional(
      top: 12,
      start: 12,
      child: Material(
        color: T.surface(context),
        shape: const CircleBorder(),
        elevation: 2,
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// The full address, spelled out under the map next to the confirm button —
  /// the detail the one-line bubble on the pin has to leave out.
  Widget _buildAddressCard(BuildContext context) {
    final address = _address;
    final showLoading = _isMoving || _isResolvingAddress;

    return Material(
      color: T.surface(context),
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.place_outlined, color: T.primary(context), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: showLoading
                  ? Text(
                      context.l10n.routeSearchLoadingAddress,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: T.onSurfaceVariant(context),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          address == null || address.isEmpty
                              ? context.l10n.routeSearchAddressUnavailable
                              : (address.primaryText.isNotEmpty
                                    ? address.primaryText
                                    : address.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: T.onSurface(context),
                          ),
                        ),
                        if (address != null &&
                            address.secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            address.secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: T.onSurfaceVariant(context),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    // Confirm stays disabled while the address is still resolving, so the
    // user never confirms a point whose label is about to change.
    final canConfirm = _center != null && !_isMoving && !_isResolvingAddress;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: T.surface(context),
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: context.l10n.routeSearchMyLocation,
              onPressed: _goToMyLocation,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: _buildAddressCard(context)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canConfirm ? _confirm : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                widget.confirmLabel,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  // The shared style carries a dark colour that would win over
                  // the button's own foreground, so state it here.
                  color: canConfirm
                      ? T.onPrimary(context)
                      : T.onPrimary(context).withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
