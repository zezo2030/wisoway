import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_model.dart';
import '../core/services/location_service.dart';

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
        _selectedLocation = initialPosition;
        _selectedAddress =
            widget.initialLocation!.address ?? widget.initialLocation!.name;
        _searchController.text = widget.initialLocation!.name;
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
      // Default to Cairo, Egypt
      final defaultPosition = const LatLng(30.0444, 31.2357);
      setState(() {
        _selectedLocation = defaultPosition;
        _selectedAddress = 'القاهرة، مصر';
        _isLoading = false;
      });

      // Show user-friendly error message
      if (mounted) {
        String message = 'تعذر الحصول على الموقع الحالي.';
        String actionLabel = 'إغلاق';
        VoidCallback? onAction;

        final errorStr = e.toString();
        if (errorStr.contains('LOCATION_SERVICE_DISABLED')) {
          message = 'خدمات الموقع معطلة. يرجى تفعيل GPS.';
          actionLabel = 'تفعيل';
          onAction = () => _locationService.openLocationSettings();
        } else if (errorStr.contains('LOCATION_PERMISSION_DENIED')) {
          message = 'تصريح الموقع مطلوب.';
          actionLabel = 'منح التصريح';
          onAction = () => _initializeLocation();
        } else if (errorStr.contains(
          'LOCATION_PERMISSION_PERMANENTLY_DENIED',
        )) {
          message = 'تم رفض تصريح الموقع بشكل دائم. افتح الإعدادات لمنحه.';
          actionLabel = 'الإعدادات';
          onAction = () => _locationService.openAppSettings();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            action: onAction != null
                ? SnackBarAction(
                    label: actionLabel,
                    textColor: Colors.white,
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
        _selectedAddress = 'موقع غير معروف';
        _isGettingAddress = false;
      });
    }
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      final location = LocationModel(
        name: _selectedAddress ?? 'موقع غير معروف',
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

      String message = 'خطأ في الحصول على الموقع.';
      String actionLabel = 'إغلاق';
      VoidCallback? onAction;

      final errorStr = e.toString();
      if (errorStr.contains('LOCATION_SERVICE_DISABLED')) {
        message = 'خدمات الموقع معطلة.';
        actionLabel = 'تفعيل';
        onAction = () => _locationService.openLocationSettings();
      } else if (errorStr.contains('LOCATION_PERMISSION_DENIED')) {
        message = 'تصريح الموقع مطلوب.';
        actionLabel = 'منح';
        onAction = () => _useCurrentLocation();
      } else if (errorStr.contains('LOCATION_PERMISSION_PERMANENTLY_DENIED')) {
        message = 'تم رفض التصريح بشكل دائم.';
        actionLabel = 'الإعدادات';
        onAction = () => _locationService.openAppSettings();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          action: onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: Colors.white,
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
          const SnackBar(
            content: Text(
              'لم يتم العثور على نتائج. جرّب اسم مكان أو عنوان أوضح.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في البحث: ${e.toString()}'),
            backgroundColor: Colors.red,
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
            tooltip: 'استخدام الموقع الحالي',
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
                      label: 'البحث عن مكان أو عنوان',
                      textField: true,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن مكان أو عنوان...',
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
                        textDirection: TextDirection.ltr,
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
                    tooltip: 'بحث على الخريطة',
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('جاري تحميل الخريطة...'),
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
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'خطأ في تحميل الخريطة',
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
                          label: const Text('إعادة المحاولة'),
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
                              const LatLng(30.0444, 31.2357),
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
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
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
                                  _selectedAddress ?? 'اختر موقعاً على الخريطة',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _selectedLocation != null
                                    ? _confirmSelection
                                    : null,
                                child: const Text('تأكيد الموقع'),
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
