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
  String _filterType = 'nearby';
  bool _isLoadingLocation = false;
  late Future<List<TripModel>> _tripsFuture;

  // Advanced filters
  LocationModel? _fromFilter;
  LocationModel? _toFilter;
  String _cityFilter = '';
  DateTime? _selectedDate;
  String _sortBy = 'nearest'; // 'nearest' | 'newest'

  @override
  void initState() {
    super.initState();
    _tripsFuture = _fetchTrips();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _userLocation = location;
        _isLoadingLocation = false;
      });
      _reloadTrips();
    } catch (e) {
      if (!mounted) return;
      print('❌ Error loading location: $e');
      setState(() => _isLoadingLocation = false);

      String message = 'تعذر الحصول على الموقع.';
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
        onAction = () => _loadUserLocation();
      } else if (errorStr.contains('LOCATION_PERMISSION_PERMANENTLY_DENIED')) {
        message = 'تم رفض التصريح بشكل دائم.';
        actionLabel = 'الإعدادات';
        onAction = () => _locationService.openAppSettings();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.warning,
          action: onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: AppColors.white,
                  onPressed: onAction,
                )
              : null,
        ),
      );
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

  Future<void> _handleRefresh() async {
    if ((_filterType == 'nearby' || _filterType == 'preferred') &&
        _userLocation == null) {
      await _loadUserLocation();
      return;
    }

    setState(() {
      _tripsFuture = _fetchTrips();
    });

    await _tripsFuture;
  }

  Future<List<TripModel>> _fetchTrips() async {
    if (_filterType == 'preferred' && _userLocation != null) {
      return _tripService.getPreferredTrips(riderLocation: _userLocation!);
    }

    if (_filterType == 'nearby' && _userLocation != null) {
      return _tripService.getNearbyTrips(riderLocation: _userLocation!);
    }

    return _tripService.searchActiveTrips(
      from: _fromFilter,
      to: _toFilter,
      minDepartureTime: DateTime.now(),
    );
  }

  bool get _hasActiveFilters =>
      _fromFilter != null ||
      _toFilter != null ||
      _cityFilter.trim().isNotEmpty ||
      _selectedDate != null ||
      _sortBy != 'nearest';

  String get _activeFiltersText {
    final parts = <String>[];
    if (_fromFilter != null) parts.add('من: ${_fromFilter!.name}');
    if (_toFilter != null) parts.add('إلى: ${_toFilter!.name}');
    if (_cityFilter.trim().isNotEmpty) parts.add('مدينة: $_cityFilter');
    if (_selectedDate != null) {
      parts.add('تاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}');
    }
    if (_sortBy == 'newest') parts.add('ترتيب: الأحدث');
    return parts.join(' • ');
  }

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<_FilterSheetResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FilterSheet(
        initialFrom: _fromFilter,
        initialTo: _toFilter,
        initialCity: _cityFilter,
        initialDate: _selectedDate,
        initialSort: _sortBy,
      ),
    );

    if (result == null) return;

    if (result.applied) {
      setState(() {
        _fromFilter = result.from;
        _toFilter = result.to;
        _cityFilter = result.city;
        _selectedDate = result.date;
        _sortBy = result.sort;
      });
    } else {
      setState(() {
        _fromFilter = null;
        _toFilter = null;
        _cityFilter = '';
        _selectedDate = null;
        _sortBy = 'nearest';
      });
    }
    _reloadTrips();
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: AppColors.transparent,
              iconColor: T.onSurface(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _changeLocation,
            tooltip: 'تغيير الموقع',
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showFilterSheet,
                tooltip: 'تصفية وترتيب',
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: T.primary(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: T.surfaceVariant(context),
            child: Row(
              children: [
                Icon(Icons.location_on, color: T.primary(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'موقعك الحالي:',
                        style: TextStyle(
                          fontSize: 12,
                          color: T.onSurfaceVariant(context),
                        ),
                      ),
                      Text(
                        _userLocation?.name ?? 'جاري تحديد الموقع...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: T.onSurface(context),
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
          if (_hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: T.primaryContainer(context).withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 14, color: T.primary(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _activeFiltersText,
                      style: TextStyle(fontSize: 12, color: T.primary(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _fromFilter = null;
                        _toFilter = null;
                        _cityFilter = '';
                        _selectedDate = null;
                        _sortBy = 'nearest';
                      });
                      _reloadTrips();
                    },
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: T.primary(context),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<TripModel>>(
              future: _tripsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: T.primary(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: T.error(context),
                                ),
                                const SizedBox(height: 16),
                                Text('خطأ: ${snapshot.error}'),
                                const SizedBox(height: 16),
                                Semantics(
                                  button: true,
                                  label: 'إعادة المحاولة',
                                  child: ElevatedButton(
                                    onPressed: _reloadTrips,
                                    child: const Text('إعادة المحاولة'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allTrips = snapshot.data ?? [];
                var filteredTrips = allTrips
                    .where((trip) => trip.driverId != userModel.id)
                    .toList();

                // City filter (client-side)
                if (_cityFilter.trim().isNotEmpty) {
                  final city = _cityFilter.trim().toLowerCase();
                  filteredTrips = filteredTrips
                      .where(
                        (t) =>
                            t.from.name.toLowerCase().contains(city) ||
                            t.to.name.toLowerCase().contains(city),
                      )
                      .toList();
                }

                // Date filter (client-side: match exact day)
                if (_selectedDate != null) {
                  filteredTrips = filteredTrips
                      .where(
                        (t) =>
                            t.departureTime.year == _selectedDate!.year &&
                            t.departureTime.month == _selectedDate!.month &&
                            t.departureTime.day == _selectedDate!.day,
                      )
                      .toList();
                }

                // Sort
                if (_sortBy == 'newest') {
                  filteredTrips.sort(
                    (a, b) => a.departureTime.compareTo(b.departureTime),
                  );
                } else {
                  // nearest: by distanceKm if available, else by departure time
                  filteredTrips.sort((a, b) {
                    final da = a.distanceKm;
                    final db = b.distanceKm;
                    if (da != null && db != null) return da.compareTo(db);
                    return a.departureTime.compareTo(b.departureTime);
                  });
                }

                if (filteredTrips.isEmpty) {
                  final locationRequired =
                      (_filterType == 'nearby' || _filterType == 'preferred') &&
                      _userLocation == null;

                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: T.primary(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_car_outlined,
                                  size: 64,
                                  color: T.outlineVariant(context),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  locationRequired
                                      ? 'فعّل الموقع لعرض هذه الرحلات'
                                      : 'لا توجد رحلات متاحة',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: T.onSurfaceVariant(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  locationRequired
                                      ? 'اختر موقعك الحالي ثم أعد المحاولة'
                                      : 'جرب تغيير الفلتر أو الموقع',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: T.outlineVariant(context),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Semantics(
                                  button: true,
                                  label: 'تحديث قائمة الرحلات',
                                  child: ElevatedButton(
                                    onPressed: _reloadTrips,
                                    child: const Text('تحديث'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: T.primary(context),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTrips.length,
                    itemBuilder: (context, index) {
                      final trip = filteredTrips[index];
                      return _TripCard(trip: trip);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheetResult {
  final bool applied;
  final LocationModel? from;
  final LocationModel? to;
  final String city;
  final DateTime? date;
  final String sort;

  const _FilterSheetResult({
    required this.applied,
    this.from,
    this.to,
    this.city = '',
    this.date,
    this.sort = 'nearest',
  });
}

class _FilterSheet extends StatefulWidget {
  final LocationModel? initialFrom;
  final LocationModel? initialTo;
  final String initialCity;
  final DateTime? initialDate;
  final String initialSort;

  const _FilterSheet({
    required this.initialFrom,
    required this.initialTo,
    required this.initialCity,
    required this.initialDate,
    required this.initialSort,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late LocationModel? _tmpFrom = widget.initialFrom;
  late LocationModel? _tmpTo = widget.initialTo;
  late String _tmpCity = widget.initialCity;
  late DateTime? _tmpDate = widget.initialDate;
  late String _tmpSort = widget.initialSort;
  late final TextEditingController _cityController =
      TextEditingController(text: widget.initialCity);

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تصفية وترتيب الرحلات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: T.onSurface(ctx),
              ),
            ),
            const SizedBox(height: 20),
            // From location
            Text(
              'من',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: T.onSurfaceVariant(ctx),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final loc = await Navigator.push<LocationModel>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => LocationPickerWidget(
                      title: 'اختر نقطة الانطلاق',
                      initialLocation: _tmpFrom,
                      onLocationSelected: (_) {},
                    ),
                  ),
                );
                if (loc != null) setState(() => _tmpFrom = loc);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trip_origin,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tmpFrom?.name ?? 'اختر نقطة الانطلاق',
                        style: TextStyle(
                          color: _tmpFrom != null
                              ? T.onSurface(ctx)
                              : Colors.grey,
                        ),
                      ),
                    ),
                    if (_tmpFrom != null)
                      GestureDetector(
                        onTap: () => setState(() => _tmpFrom = null),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // To location
            Text(
              'إلى',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: T.onSurfaceVariant(ctx),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final loc = await Navigator.push<LocationModel>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => LocationPickerWidget(
                      title: 'اختر الوجهة',
                      initialLocation: _tmpTo,
                      onLocationSelected: (_) {},
                    ),
                  ),
                );
                if (loc != null) setState(() => _tmpTo = loc);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 18, color: T.error(ctx)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tmpTo?.name ?? 'اختر الوجهة',
                        style: TextStyle(
                          color: _tmpTo != null
                              ? T.onSurface(ctx)
                              : Colors.grey,
                        ),
                      ),
                    ),
                    if (_tmpTo != null)
                      GestureDetector(
                        onTap: () => setState(() => _tmpTo = null),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // City filter
            Text(
              'المدينة',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: T.onSurfaceVariant(ctx),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المدينة',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                suffixIcon: _tmpCity.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _cityController.clear();
                          setState(() => _tmpCity = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _tmpCity = v),
            ),
            const SizedBox(height: 12),
            // Date filter
            Text(
              'التاريخ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: T.onSurfaceVariant(ctx),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: _tmpDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _tmpDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tmpDate != null
                            ? DateFormat('yyyy-MM-dd').format(_tmpDate!)
                            : 'اختر التاريخ',
                        style: TextStyle(
                          color: _tmpDate != null
                              ? T.onSurface(ctx)
                              : Colors.grey,
                        ),
                      ),
                    ),
                    if (_tmpDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _tmpDate = null),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Sort options
            Text(
              'الترتيب',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: T.onSurfaceVariant(ctx),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SortOptionChip(
                    label: 'الأقرب',
                    icon: Icons.near_me,
                    isSelected: _tmpSort == 'nearest',
                    onTap: () => setState(() => _tmpSort = 'nearest'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SortOptionChip(
                    label: 'الأحدث',
                    icon: Icons.schedule,
                    isSelected: _tmpSort == 'newest',
                    onTap: () => setState(() => _tmpSort = 'newest'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(
                      ctx,
                      const _FilterSheetResult(applied: false),
                    ),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E0D8)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'مسح الكل',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555550),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(
                      ctx,
                      _FilterSheetResult(
                        applied: true,
                        from: _tmpFrom,
                        to: _tmpTo,
                        city: _tmpCity,
                        date: _tmpDate,
                        sort: _tmpSort,
                      ),
                    ),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E0D8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'تطبيق',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222220),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      selectedColor: T.primaryContainer(context),
      checkmarkColor: T.primary(context),
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
      color: AppColors.teal50,
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.teal200, width: 1.4),
      ),
      child: Semantics(
        button: true,
        label: 'تفاصيل الرحلة من ${trip.from.name} إلى ${trip.to.name}',
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
                                color: AppColors.success,
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
                                color: T.error(context),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: trip.hasAvailableSeats
                            ? AppColors.success.withValues(alpha: 0.12)
                            : T.error(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${trip.availableSeats}/${trip.totalSeats}',
                        style: TextStyle(
                          color: trip.hasAvailableSeats
                              ? AppColors.successDark
                              : AppColors.errorDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
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
        Icon(icon, size: 20, color: T.primary(context)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: T.onSurfaceVariant(context)),
        ),
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

class _SortOptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOptionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? T.primaryContainer(context) : Colors.transparent,
          border: Border.all(
            color: isSelected ? T.primary(context) : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? T.primary(context) : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? T.primary(context) : T.onSurface(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
