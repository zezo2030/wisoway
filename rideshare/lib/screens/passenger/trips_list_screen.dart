import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../models/location_model.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/location_service.dart';
import '../../core/services/trip_service.dart';
import '../../widgets/location_picker_widget.dart';
import '../../widgets/notification_icon_button.dart';
import '../../core/theme/colors.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key});

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  final LocationService _locationService = LocationService();
  final TripService _tripService = TripService();
  LocationModel? _userLocation;
  String _filterType = 'nearby'; // 'nearby', 'preferred', 'all'
  bool _isLoadingLocation = false;
  late Future<List<TripModel>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = _fetchTrips();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final location = await _locationService.getCurrentLocation();
      setState(() {
        _userLocation = location;
        _isLoadingLocation = false;
      });
      _reloadTrips();
    } catch (e) {
      print('❌ Error loading location: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _changeLocation() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          title: 'اختر موقعك',
          initialLocation: _userLocation,
          onLocationSelected: (location) {},
        ),
      ),
    );

    if (location != null) {
      setState(() {
        _userLocation = location;
      });
      _reloadTrips();
    }
  }

  void _reloadTrips() {
    setState(() {
      _tripsFuture = _fetchTrips();
    });
  }

  Future<List<TripModel>> _fetchTrips() async {
    if (_filterType == 'preferred' && _userLocation != null) {
      return _tripService.getPreferredTrips(riderLocation: _userLocation!);
    }

    if (_filterType == 'nearby' && _userLocation != null) {
      return _tripService.getNearbyTrips(riderLocation: _userLocation!);
    }

    return _tripService.searchActiveTrips(minDepartureTime: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;

    if (userModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الرحلات المتاحة')),
        body: const Center(child: Text('يجب تسجيل الدخول لعرض الرحلات')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرحلات المتاحة'),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: Colors.transparent,
              iconColor: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _changeLocation,
            tooltip: 'تغيير الموقع',
          ),
        ],
      ),
      body: Column(
        children: [
          // Location Display
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'موقعك الحالي:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _userLocation?.name ?? 'جاري تحديد الموقع...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingLocation)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          // Filters
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FilterChip(
                  label: 'رحلات قريبة',
                  isSelected: _filterType == 'nearby',
                  onTap: () {
                    setState(() => _filterType = 'nearby');
                    _reloadTrips();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'رحلات مفضلة',
                  isSelected: _filterType == 'preferred',
                  onTap: () {
                    setState(() => _filterType = 'preferred');
                    _reloadTrips();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'كل الرحلات',
                  isSelected: _filterType == 'all',
                  onTap: () {
                    setState(() => _filterType = 'all');
                    _reloadTrips();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Trips List
          Expanded(
            child: FutureBuilder<List<TripModel>>(
              future: _tripsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('خطأ: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _reloadTrips,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                final allTrips = snapshot.data ?? [];
                final filteredTrips = allTrips
                    .where((trip) => trip.driverId != userModel.id)
                    .toList();

                if (filteredTrips.isEmpty) {
                  final locationRequired =
                      (_filterType == 'nearby' || _filterType == 'preferred') &&
                      _userLocation == null;

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          locationRequired
                              ? 'فعّل الموقع لعرض هذه الرحلات'
                              : 'لا توجد رحلات متاحة',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          locationRequired
                              ? 'اختر موقعك الحالي ثم أعد المحاولة'
                              : 'جرب تغيير الفلتر أو الموقع',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _reloadTrips,
                          child: const Text('تحديث'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTrips.length,
                  itemBuilder: (context, index) {
                    final trip = filteredTrips[index];
                    return _TripCard(trip: trip);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[800],
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;

  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            RouteNames.tripDetails,
            arguments: trip.id,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route Info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                trip.from.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_city,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                trip.to.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Available Seats Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: trip.hasAvailableSeats
                          ? Colors.green[100]
                          : Colors.red[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${trip.availableSeats}/${trip.totalSeats}',
                      style: TextStyle(
                        color: trip.hasAvailableSeats
                            ? Colors.green[800]
                            : Colors.red[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Trip Details
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.access_time,
                      label: 'الانطلاق',
                      value:
                          '${dateFormat.format(trip.departureTime)}\n${timeFormat.format(trip.departureTime)}',
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.attach_money,
                      label: 'السعر',
                      value: '${trip.price} ${trip.currency}',
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.person,
                      label: 'السائق',
                      value: trip.driverName ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
