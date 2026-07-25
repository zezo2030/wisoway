import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../models/location_model.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/location_service.dart';
import '../../core/services/trip_service.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../widgets/location_picker_widget.dart';
import '../../widgets/notification_icon_button.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

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

      String message = context.l10n.locationUnavailable;
      String actionLabel = context.l10n.close;
      VoidCallback? onAction;

      final errorStr = e.toString();
      if (errorStr.contains('LOCATION_SERVICE_DISABLED')) {
        message = context.l10n.locationServicesDisabled;
        actionLabel = context.l10n.enableAction;
        onAction = () => _locationService.openLocationSettings();
      } else if (errorStr.contains('LOCATION_PERMISSION_DENIED')) {
        message = context.l10n.locationPermissionRequired;
        actionLabel = context.l10n.grantAction;
        onAction = () => _loadUserLocation();
      } else if (errorStr.contains('LOCATION_PERMISSION_PERMANENTLY_DENIED')) {
        message = context.l10n.locationPermissionPermanentlyDenied;
        actionLabel = context.l10n.settings;
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
          title: context.l10n.chooseYourLocation,
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

  String _activeFiltersText(BuildContext context) {
    final parts = <String>[];
    if (_fromFilter != null) {
      parts.add(context.l10n.filterFromValue(_fromFilter!.name));
    }
    if (_toFilter != null) {
      parts.add(context.l10n.filterToValue(_toFilter!.name));
    }
    if (_cityFilter.trim().isNotEmpty) {
      parts.add(context.l10n.filterCityValue(_cityFilter));
    }
    if (_selectedDate != null) {
      parts.add(
        context.l10n.filterDateValue(
          DateFormat('yyyy-MM-dd').format(_selectedDate!),
        ),
      );
    }
    if (_sortBy == 'newest') parts.add(context.l10n.filterSortNewest);
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
        appBar: AppBar(title: Text(context.l10n.availableTripsTitle)),
        body: Center(child: Text(context.l10n.signInToViewTrips)),
      );
    }

    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        title: Text(context.l10n.availableTripsTitle),
        actions: [
          NotificationIconButton(
            backgroundColor: AppColors.transparent,
            iconColor: T.onSurface(context),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(IconsaxPlusLinear.filter),
                onPressed: _showFilterSheet,
                tooltip: context.l10n.filterAndSort,
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: T.primary(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: T.surface(context), width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: T.primary(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Material(
                    color: T.surface(context),
                    child: InkWell(
                      onTap: _changeLocation,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: T.primaryContainer(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                IconsaxPlusBold.gps,
                                size: 18,
                                color: T.primary(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.currentLocationLabel,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: T.onSurfaceVariant(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _userLocation?.name ??
                                        context.l10n.detectingLocation,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: T.onSurface(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isLoadingLocation)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: T.primary(context),
                                ),
                              )
                            else
                              Icon(
                                Directionality.of(context) ==
                                        TextDirection.rtl
                                    ? IconsaxPlusLinear.arrow_left_2
                                    : IconsaxPlusLinear.arrow_right_2,
                                size: 18,
                                color: T.outlineVariant(context),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _SegmentedFilter(
                      value: _filterType,
                      segments: [
                        _SegmentOption(
                          'nearby',
                          context.l10n.nearbyTrips,
                          IconsaxPlusBold.routing,
                        ),
                        _SegmentOption(
                          'preferred',
                          context.l10n.preferredTrips,
                          IconsaxPlusBold.heart,
                        ),
                        _SegmentOption(
                          'all',
                          context.l10n.allTrips,
                          IconsaxPlusBold.category,
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _filterType = value);
                        _reloadTrips();
                      },
                    ),
                  ),
                  if (_hasActiveFilters)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      color: T.primaryContainer(
                        context,
                      ).withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          Icon(
                            IconsaxPlusBold.filter_search,
                            size: 14,
                            color: T.primary(context),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _activeFiltersText(context),
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: T.primary(context),
                              ),
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
                              IconsaxPlusLinear.close_circle,
                              size: 16,
                              color: T.primary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                ],
              ),
            ),
            FutureBuilder<List<TripModel>>(
              future: _tripsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: T.error(context).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              IconsaxPlusBold.danger,
                              size: 40,
                              color: T.error(context),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                            ),
                            child: Text(
                              context.l10n.errorWithDetail(
                                '${snapshot.error}',
                              ),
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: T.onSurfaceVariant(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            button: true,
                            label: context.l10n.tryAgain,
                            child: FilledButton.icon(
                              onPressed: _reloadTrips,
                              icon: const Icon(
                                IconsaxPlusLinear.refresh,
                                size: 18,
                              ),
                              label: Text(context.l10n.tryAgain),
                              style: FilledButton.styleFrom(
                                backgroundColor: T.primary(context),
                                foregroundColor: T.onPrimary(context),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: T.primaryContainer(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              IconsaxPlusBold.routing_2,
                              size: 40,
                              color: T.primary(context),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            locationRequired
                                ? context.l10n.enableLocationForTrips
                                : context.l10n.noTripsAvailable,
                            style: GoogleFonts.tajawal(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: T.onSurface(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                            ),
                            child: Text(
                              locationRequired
                                  ? context.l10n.chooseLocationThenRetry
                                  : context.l10n.tryChangingFilterOrLocation,
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: T.onSurfaceVariant(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            button: true,
                            label: context.l10n.refreshTripsList,
                            child: FilledButton.icon(
                              onPressed: _reloadTrips,
                              icon: const Icon(
                                IconsaxPlusLinear.refresh,
                                size: 18,
                              ),
                              label: Text(context.l10n.refresh),
                              style: FilledButton.styleFrom(
                                backgroundColor: T.primary(context),
                                foregroundColor: T.onPrimary(context),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _TripCard(trip: filteredTrips[index]),
                      childCount: filteredTrips.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
  late final TextEditingController _fromController =
      TextEditingController(text: widget.initialFrom?.name ?? '');
  late final TextEditingController _toController =
      TextEditingController(text: widget.initialTo?.name ?? '');
  late final TextEditingController _cityController =
      TextEditingController(text: widget.initialCity);

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
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
              ctx.l10n.filterAndSortTrips,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: T.onSurface(ctx),
              ),
            ),
            const SizedBox(height: 20),
            // From location
            Text(
              ctx.l10n.fromLabel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: T.onSurfaceVariant(ctx),
              ),
            ),
            const SizedBox(height: 6),
            LocationAutocompleteField(
              controller: _fromController,
              hint: ctx.l10n.chooseDeparturePoint,
              mapPickerTitle: ctx.l10n.chooseDeparturePoint,
              icon: Icons.trip_origin,
              iconColor: AppColors.success,
              initialLocation: _tmpFrom,
              onLocationSelected: (location) {
                setState(() => _tmpFrom = location);
              },
            ),
            const SizedBox(height: 12),
            // To location
            Text(
              ctx.l10n.toLabel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: T.onSurfaceVariant(ctx),
              ),
            ),
            const SizedBox(height: 6),
            LocationAutocompleteField(
              controller: _toController,
              hint: ctx.l10n.chooseDestination,
              mapPickerTitle: ctx.l10n.chooseDestination,
              icon: Icons.location_on,
              iconColor: T.error(ctx),
              initialLocation: _tmpTo,
              onLocationSelected: (location) {
                setState(() => _tmpTo = location);
              },
            ),
            const SizedBox(height: 12),
            // City filter
            Text(
              ctx.l10n.cityLabel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: T.onSurfaceVariant(ctx),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: ctx.l10n.searchByCityName,
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
              ctx.l10n.dateLabel,
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
                            : ctx.l10n.chooseDate,
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
              ctx.l10n.sortLabel,
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
                    label: ctx.l10n.sortNearest,
                    icon: Icons.near_me,
                    isSelected: _tmpSort == 'nearest',
                    onTap: () => setState(() => _tmpSort = 'nearest'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SortOptionChip(
                    label: ctx.l10n.sortNewest,
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
                      child: Text(
                        ctx.l10n.clearAll,
                        style: const TextStyle(
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
                      child: Text(
                        ctx.l10n.apply,
                        style: const TextStyle(
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

class _SegmentOption {
  final String value;
  final String label;
  final IconData icon;

  const _SegmentOption(this.value, this.label, this.icon);
}

class _SegmentedFilter extends StatelessWidget {
  final String value;
  final List<_SegmentOption> segments;
  final ValueChanged<String> onChanged;

  const _SegmentedFilter({
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment(
                label: segment.label,
                icon: segment.icon,
                isSelected: segment.value == value,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? T.primary(context) : T.onSurfaceVariant(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: T.surface(context).withValues(alpha: isSelected ? 1 : 0),
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: T.shadow(context).withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;

  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat(
      'd MMM',
      Localizations.localeOf(context).languageCode,
    );
    final distanceKm = trip.distanceKm;
    final driverName = trip.driverName;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              RouteNames.tripDetails,
              arguments: trip.id,
            ),
            splashColor: T.primary(context).withValues(alpha: 0.08),
            highlightColor: T.primary(context).withValues(alpha: 0.04),
            child: Semantics(
              button: true,
              label: context.l10n.tripDetailsFromTo(
                trip.from.name,
                trip.to.name,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow: distance-from-me pin (this screen's whole reason
                  // for existing) or a plain date when distance isn't known.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: T.primaryContainer(context),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  IconsaxPlusBold.location,
                                  size: 13,
                                  color: T.primary(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  context.l10n.distanceKm(
                                    distanceKm.toStringAsFixed(1),
                                  ),
                                  style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: T.primary(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                IconsaxPlusLinear.calendar,
                                size: 13,
                                color: T.onSurfaceVariant(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateFormat.format(trip.departureTime),
                                style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: T.onSurfaceVariant(context),
                                ),
                              ),
                            ],
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: trip.hasAvailableSeats
                                ? AppColors.success.withValues(alpha: 0.1)
                                : T.error(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${trip.availableSeats}/${trip.totalSeats}',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: trip.hasAvailableSeats
                                  ? AppColors.successDark
                                  : AppColors.errorDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Route: vertical timeline (from -> to), the app's
                  // established route motif.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: T.primary(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 28,
                              color: T.primary(context).withValues(alpha: 0.25),
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.success,
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
                                trip.fromDisplayName,
                                style: GoogleFonts.tajawal(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: T.onSurface(context),
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                trip.toDisplayName,
                                style: GoogleFonts.tajawal(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: T.onSurface(context),
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Footer: time, driver, price (price is the loudest figure).
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: T.surfaceVariant(context).withValues(alpha: 0.4),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          IconsaxPlusLinear.clock,
                          size: 15,
                          color: T.primary(context),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timeFormat.format(trip.departureTime),
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: T.primary(context),
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (driverName != null && driverName.isNotEmpty) ...[
                          Icon(
                            IconsaxPlusLinear.profile_2user,
                            size: 15,
                            color: T.onSurfaceVariant(context),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              driverName,
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: T.onSurfaceVariant(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        Text(
                          '${trip.price.toStringAsFixed(0)} ${trip.currency}',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: T.primary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
