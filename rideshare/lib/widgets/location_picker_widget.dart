import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_model.dart';
import '../core/services/location_service.dart';
import '../core/theme/colors.dart';
import '../l10n/l10n_extensions.dart';

class LocationPickerWidget extends StatefulWidget {
  final String title;
  final LocationModel? initialLocation;
  final Function(LocationModel) onLocationSelected;

  const LocationPickerWidget({
    super.key,
    required this.title,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _isGettingAddress = false;
  bool _isSearching = false;
  String? _mapError;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      LatLng initialPosition;

      if (widget.initialLocation != null) {
        initialPosition = LatLng(
          widget.initialLocation!.latitude,
          widget.initialLocation!.longitude,
        );
        final localizedAddress = await _locationService
            .getAddressFromCoordinates(
              latitude: widget.initialLocation!.latitude,
              longitude: widget.initialLocation!.longitude,
            );
        _selectedLocation = initialPosition;
        _selectedAddress = localizedAddress;
        _searchController.text = localizedAddress;
      } else {
        // Get current location
        final currentLocation = await _locationService.getCurrentLocation();
        initialPosition = LatLng(
          currentLocation.latitude,
          currentLocation.longitude,
        );
        _selectedLocation = initialPosition;
        _selectedAddress = currentLocation.address;
      }

      setState(() {
        _isLoading = false;
      });

      // Move camera to initial position
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(initialPosition, 15),
        );
      }
    } catch (e) {
      print('❌ Error initializing location: $e');
      // Default: Amman, Jordan
      final defaultPosition = const LatLng(31.9539, 35.9106);
      setState(() {
        _selectedLocation = defaultPosition;
        _selectedAddress = context.l10n.locationDefaultAmman;
        _isLoading = false;
      });

      // Show user-friendly error message
      if (mounted) {
        String message = context.l10n.locationCurrentUnavailable;
        String actionLabel = context.l10n.close;
        VoidCallback? onAction;

        final errorStr = e.toString();
        if (errorStr.contains('LOCATION_SERVICE_DISABLED')) {
          message = context.l10n.locationServicesDisabledEnableGps;
          actionLabel = context.l10n.locationEnable;
          onAction = () => _locationService.openLocationSettings();
        } else if (errorStr.contains('LOCATION_PERMISSION_DENIED')) {
          message = context.l10n.locationPermissionRequired;
          actionLabel = context.l10n.locationGrantPermission;
          onAction = () => _initializeLocation();
        } else if (errorStr.contains(
          'LOCATION_PERMISSION_PERMANENTLY_DENIED',
        )) {
          message = context.l10n.locationPermissionPermanentlyDenied;
          actionLabel = context.l10n.locationSettings;
          onAction = () => _locationService.openAppSettings();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.warning,
            action: onAction != null
                ? SnackBarAction(
                    label: actionLabel,
                    textColor: T.onPrimary(context),
                    onPressed: onAction,
                  )
                : null,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _mapError = null;
    });

    if (_selectedLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
      );
    }
  }

  void _onMapTap(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _isGettingAddress = true;
    });

    try {
      final address = await _locationService.getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _selectedAddress = address;
        _isGettingAddress = false;
      });
    } catch (e) {
      print('❌ Error getting address: $e');
      setState(() {
        _selectedAddress = context.l10n.locationUnknown;
        _isGettingAddress = false;
      });
    }
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      final location = LocationModel(
        name: _selectedAddress ?? context.l10n.locationUnknown,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        address: _selectedAddress,
      );
      widget.onLocationSelected(location);
      Navigator.pop(context, location);
    }
  }

  void _useCurrentLocation() async {
    try {
      setState(() => _isLoading = true);
      final currentLocation = await _locationService.getCurrentLocation();
      final position = LatLng(
        currentLocation.latitude,
        currentLocation.longitude,
      );

      setState(() {
        _selectedLocation = position;
        _selectedAddress = currentLocation.address;
        _isLoading = false;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String message = context.l10n.locationGetError;
      String actionLabel = context.l10n.close;
      VoidCallback? onAction;

      final errorStr = e.toString();
      if (errorStr.contains('LOCATION_SERVICE_DISABLED')) {
        message = context.l10n.locationServicesDisabled;
        actionLabel = context.l10n.locationEnable;
        onAction = () => _locationService.openLocationSettings();
      } else if (errorStr.contains('LOCATION_PERMISSION_DENIED')) {
        message = context.l10n.locationPermissionRequired;
        actionLabel = context.l10n.locationGrant;
        onAction = () => _useCurrentLocation();
      } else if (errorStr.contains('LOCATION_PERMISSION_PERMANENTLY_DENIED')) {
        message = context.l10n.locationPermissionDeniedPermanently;
        actionLabel = context.l10n.locationSettings;
        onAction = () => _locationService.openAppSettings();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: T.error(context),
          action: onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: T.onError(context),
                  onPressed: onAction,
                )
              : null,
        ),
      );
    }
  }

  Future<void> _searchByAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final location = await _locationService.getCoordinatesFromAddress(query);
      if (!mounted) return;
      if (location != null) {
        final position = LatLng(location.latitude, location.longitude);
        setState(() {
          _selectedLocation = position;
          _selectedAddress = location.address ?? location.name;
          _isSearching = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
        _searchController.text = location.name;
      } else {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.locationSearchNoResults),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.locationSearchError(e.toString())),
            backgroundColor: T.error(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _useCurrentLocation,
            tooltip: context.l10n.locationUseCurrent,
          ),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط البحث عن المكان
          if (!_isLoading && _mapError == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: context.l10n.locationSearchSemantic,
                      textField: true,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: context.l10n.locationSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textDirection: TextDirection.rtl,
                        onSubmitted: (_) => _searchByAddress(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSearching ? null : _searchByAddress,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    tooltip: context.l10n.locationSearchOnMap,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(context.l10n.locationLoadingMap),
                      ],
                    ),
                  )
                : _mapError != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.locationMapLoadError,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _mapError!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _mapError = null;
                              _isLoading = true;
                            });
                            _initializeLocation();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.retry),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target:
                              _selectedLocation ??
                              const LatLng(31.9539, 35.9106),
                          zoom: 15,
                        ),
                        onTap: _onMapTap,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        mapType: MapType.normal,
                        zoomControlsEnabled: false,
                        compassEnabled: true,
                        markers: _selectedLocation != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('selected_location'),
                                  position: _selectedLocation!,
                                  draggable: true,
                                  onDragEnd: (newPosition) {
                                    _onMapTap(newPosition);
                                  },
                                ),
                              }
                            : {},
                        onCameraMoveStarted: () {
                          // Optional: Handle camera movement
                        },
                      ),
                      // Address Card
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: T.surface(context),
                            boxShadow: [
                              BoxShadow(
                                color: T.shadow(context).withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isGettingAddress)
                                const LinearProgressIndicator()
                              else
                                Text(
                                  _selectedAddress ??
                                      context.l10n.locationPickOnMap,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: T.onSurface(context),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _selectedLocation != null
                                    ? _confirmSelection
                                    : null,
                                child: Text(context.l10n.locationConfirm),
                              ),
                            ],
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
