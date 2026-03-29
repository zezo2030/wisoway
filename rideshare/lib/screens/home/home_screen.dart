import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/notification_provider.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/colors.dart';
import '../../models/trip_model.dart';
import '../../models/booking_model.dart';
import '../../models/location_model.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/location_service.dart';
import '../../widgets/location_picker_widget.dart';
import '../../widgets/notification_icon_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  LocationModel? _userLocation;
  bool _isLoadingLocation = false;
  bool _didFetchDriverTrips = false;
  final LocationService _locationService = LocationService();
  late final DateTime _activeTripsMinDepartureTime;
  late final DateTime _bookingsMinDepartureTime;

  @override
  void initState() {
    super.initState();
    _activeTripsMinDepartureTime = DateTime.now();
    _bookingsMinDepartureTime = DateTime.now().subtract(const Duration(days: 1));
    _loadUserLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    final notificationProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );
    await notificationProvider.initialize();
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
    } catch (e) {
      if (!mounted) return;
      print('❌ Error loading location: $e');
      setState(() => _isLoadingLocation = false);
      
      final errorStr = e.toString();
      if (errorStr.contains('LOCATION_SERVICE_DISABLED')) {
        _showLocationRequirementDialog(
          title: 'خدمات الموقع معطلة',
          message: 'يرجى تفعيل خدمات الموقع (GPS) لتتمكن من استخدام التطبيق ومشاركة موقعك.',
          onAction: () async {
            await _locationService.openLocationSettings();
            _loadUserLocation();
          },
          actionLabel: 'تفعيل',
        );
      } else if (errorStr.contains('LOCATION_PERMISSION_DENIED') || 
                 errorStr.contains('LOCATION_PERMISSION_PERMANENTLY_DENIED')) {
        _showLocationRequirementDialog(
          title: 'تصريح الموقع مطلوب',
          message: 'يحتاج التطبيق إلى تصريح الوصول للموقع لتتمكن من مشاركة رحلاتك.',
          onAction: () async {
            if (errorStr.contains('PERMANENTLY_DENIED')) {
              await _locationService.openAppSettings();
            } else {
              _loadUserLocation();
            }
          },
          actionLabel: 'منح التصريح',
        );
      }

      // Default to Cairo if GPS fails
      setState(() {
        _userLocation = LocationModel(
          name: 'القاهرة',
          latitude: 30.0444,
          longitude: 31.2357,
          address: 'القاهرة، مصر',
        );
      });
    }
  }

  void _showLocationRequirementDialog({
    required String title,
    required String message,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.tajawal()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('لاحقاً', style: GoogleFonts.tajawal(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAction();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(actionLabel, style: GoogleFonts.tajawal(color: Colors.white)),
          ),
        ],
      ),
    );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    // Pages for bottom navigation
    final pages = [
      _buildHomePage(context, user),
      _buildSearchPage(),
      _buildBookingsPage(context, user),
      _buildProfilePage(context, user),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _buildBottomNavigationBar(context, user),
      drawer: _buildDrawer(context, user),
    );
  }

  Widget _buildHomePage(BuildContext context, user) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header Section
            SliverToBoxAdapter(child: _buildHeader(context, user)),
            // Search Bar
            SliverToBoxAdapter(child: _buildSearchBar(context)),
            // Location Section
            SliverToBoxAdapter(child: _buildLocationSection(context)),
            // Nearby Trips Section
            SliverToBoxAdapter(child: _buildNearbyTripsSection(context, user)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث عن رحلة'),
        automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: Colors.transparent,
              iconColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconsaxPlusLinear.search_normal,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'ابحث عن رحلة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'عرض جميع الرحلات المتاحة',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, RouteNames.tripsList);
              },
              icon: const Icon(IconsaxPlusBold.search_normal),
              label: const Text('عرض الرحلات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsPage(BuildContext context, user) {
    if (user?.canCreateTrips == true) {
      return _buildDriverTripsPage(context, user);
    } else {
      return _buildPassengerBookingsPage(context);
    }
  }

  Widget _buildDriverTripsPage(BuildContext context, user) {
    if (!_didFetchDriverTrips) {
      _didFetchDriverTrips = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TripProvider>().fetchDriverTrips(
          driverId: user.id,
          driverName: user.name,
        );
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'رحلاتي',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: Colors.transparent,
              iconColor: AppColors.textPrimary,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(IconsaxPlusBold.add_circle),
              color: AppColors.primary,
              onPressed: () {
                Navigator.pushNamed(context, RouteNames.createTrip);
              },
              tooltip: 'إنشاء رحلة جديدة',
            ),
          ),
        ],
        elevation: 0,
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: Provider.of<TripProvider>(
          context,
          listen: false,
        ).getDriverTripsStream(user.id, driverName: user.name),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(context, snapshot.error.toString());
          }

          final trips = snapshot.data ?? [];

          if (trips.isEmpty) {
            return _buildEmptyTripsState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await context.read<TripProvider>().fetchDriverTrips(
                driverId: user.id,
                driverName: user.name,
              );
            },
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                return _buildTripCard(context, trips[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPassengerBookingsPage(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final userModel = authProvider.userModel;

    if (user == null || userModel == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'حجوزاتي',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: NotificationIconButton(
                backgroundColor: Colors.transparent,
                iconColor: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        body: const Center(child: Text('يجب تسجيل الدخول')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'حجوزاتي',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: Provider.of<TripProvider>(
          context,
          listen: false,
        ).getActiveTripsStream(
          minDepartureTime: _bookingsMinDepartureTime,
        ),
        builder: (context, tripsSnapshot) {
          // Get user bookings
          final bookingService = BookingService();
          return FutureBuilder<List<BookingModel>>(
            future: bookingService.getUserBookings(),
            builder: (context, bookingsSnapshot) {
              if (bookingsSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                );
              }

              if (bookingsSnapshot.hasError) {
                return _buildErrorState(
                  context,
                  bookingsSnapshot.error.toString(),
                );
              }

              final bookings = bookingsSnapshot.data ?? [];

              if (bookings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          IconsaxPlusBold.bookmark,
                          size: 80,
                          color: AppColors.primary.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'حجوزاتي',
                        style: GoogleFonts.tajawal(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'لا توجد حجوزات حالياً',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, RouteNames.tripsList);
                        },
                        icon: const Icon(IconsaxPlusBold.search_normal),
                        label: const Text('تصفح الرحلات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Get trip details for each booking
              final tripIds = bookings.map((b) => b.tripId).toSet();
              final tripsMap = <String, TripModel>{};

              if (tripsSnapshot.hasData) {
                for (var trip in tripsSnapshot.data!) {
                  if (tripIds.contains(trip.id)) {
                    tripsMap[trip.id] = trip;
                  }
                }
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    final trip = tripsMap[booking.tripId];
                    return _buildBookingCard(context, booking, trip);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    BookingModel booking,
    TripModel? trip,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    final timeFormat = DateFormat('HH:mm', 'ar');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: trip != null
              ? () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.tripDetails,
                    arguments: trip.id,
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (trip != null) ...[
                            Row(
                              children: [
                                Icon(
                                  IconsaxPlusBold.location,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trip.from.name,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
                                  IconsaxPlusBold.location,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trip.to.name,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              'رحلة غير متاحة',
                              style: GoogleFonts.tajawal(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
                        color: booking.isPending
                            ? Colors.orange[100]
                            : booking.isConfirmed
                            ? Colors.green[100]
                            : Colors.red[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        booking.isPending
                            ? 'قيد الانتظار'
                            : booking.isConfirmed
                            ? 'مؤكد'
                            : 'ملغي',
                        style: TextStyle(
                          color: booking.isPending
                              ? Colors.orange[800]
                              : booking.isConfirmed
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildBookingInfoItem(
                        icon: IconsaxPlusBold.calendar,
                        label: 'التاريخ',
                        value: trip != null
                            ? dateFormat.format(trip.departureTime)
                            : '-',
                      ),
                    ),
                    Expanded(
                      child: _buildBookingInfoItem(
                        icon: IconsaxPlusBold.clock,
                        label: 'الوقت',
                        value: trip != null
                            ? timeFormat.format(trip.departureTime)
                            : '-',
                      ),
                    ),
                    Expanded(
                      child: _buildBookingInfoItem(
                        icon: IconsaxPlusBold.profile_2user,
                        label: 'المقعد',
                        value: booking.seatNumber,
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

  Widget _buildBookingInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEmptyTripsState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusBold.car,
                size: 100,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'لا توجد رحلات',
              style: GoogleFonts.tajawal(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ابدأ بإنشاء رحلة جديدة وشارك\nرحلتك مع الآخرين',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, RouteNames.createTrip);
                },
                icon: const Icon(
                  IconsaxPlusBold.add_circle,
                  color: Colors.white,
                  size: 24,
                ),
                label: Text(
                  'إنشاء رحلة جديدة',
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusBold.danger,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                'إعادة المحاولة',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, TripModel trip) {
    final dateFormat = DateFormat('EEEE، d MMMM', 'ar');
    final timeFormat = DateFormat('hh:mm a', 'ar');
    final isPast = trip.departureTime.isBefore(DateTime.now());

    Color statusColor;
    String statusText;

    if (trip.status == 'active') {
      statusColor = AppColors.success;
      statusText = 'نشطة';
    } else if (trip.status == 'hidden') {
      statusColor = AppColors.warning;
      statusText = 'مخفية';
    } else {
      statusColor = AppColors.primary;
      statusText = 'مكتملة';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.tripManagement,
                arguments: trip.id,
              );
            },
            child: Column(
              children: [
                // 1. Top Bar: Minimal Status & Date
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: statusColor),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        dateFormat.format(trip.departureTime),
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Main Content: Horizontal Route Flow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Row(
                    children: [
                      // Locations
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.from.name,
                              style: GoogleFonts.tajawal(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(IconsaxPlusLinear.arrow_right_3, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trip.to.name,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
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
                      
                      // Price Tag (Vertical)
                      Container(
                        height: 70,
                        width: 1,
                        color: Colors.grey.withOpacity(0.15),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${trip.price}',
                            style: GoogleFonts.tajawal(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            trip.currency,
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Footer: Horizontal Pills
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildInfoPill(
                        icon: IconsaxPlusLinear.clock,
                        text: timeFormat.format(trip.departureTime),
                        color: Colors.blue,
                      ),
                      _buildInfoPill(
                        icon: IconsaxPlusLinear.profile_2user,
                        text: '${trip.availableSeats} متاح',
                        color: Colors.orange,
                      ),
                      _buildInfoPill(
                        icon: IconsaxPlusLinear.money_tick,
                        text: trip.communicationFeeStatus == 'paid' ? 'مدفوعة' : 'مستحقة',
                        color: trip.communicationFeeStatus == 'paid' ? AppColors.success : AppColors.error,
                      ),
                    ],
                  ),
                ),

                if (isPast)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      border: Border(top: BorderSide(color: AppColors.error.withOpacity(0.1))),
                    ),
                    child: Center(
                      child: Text(
                        'انتهى وقت الرحلة',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Renaming the old helper to avoid confusion if needed, or just delete it.
  Widget _buildTripInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return const SizedBox.shrink(); // Not used in this design
  }
  Widget _buildProfilePage(BuildContext context, user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: Colors.transparent,
              iconColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Picture
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primary,
                child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          user.photoUrl!,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                IconsaxPlusBold.profile,
                                size: 60,
                                color: Colors.white,
                              ),
                        ),
                      )
                    : const Icon(
                        IconsaxPlusBold.profile,
                        size: 60,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'المستخدم',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              if (user != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: user.isDriver
                        ? AppColors.secondary.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.isDriver ? 'سائق' : 'راكب',
                    style: TextStyle(
                      color: user.isDriver
                          ? AppColors.secondary
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (user != null && user.isDriver) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: user.isDriverApproved
                        ? AppColors.success.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: user.isDriverApproved
                          ? AppColors.success.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            user.isDriverApproved
                                ? IconsaxPlusBold.tick_circle
                                : IconsaxPlusBold.timer,
                            color: user.isDriverApproved
                                ? AppColors.success
                                : Colors.orange.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            user.isDriverApproved
                                ? 'تمت الموافقة على بياناتك'
                                : 'حسابك كسائق قيد المراجعة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: user.isDriverApproved
                                  ? AppColors.success
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.isDriverApproved
                            ? 'يمكنك إنشاء رحلات وإدارتها من تبويب "رحلاتي".'
                            : 'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً الحجز كراكب.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!user.isDriverApproved) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                RouteNames.driverPendingApproval,
                              );
                            },
                            icon: const Icon(
                              IconsaxPlusLinear.info_circle,
                              size: 18,
                            ),
                            label: const Text('معرفة حالة التوثيق'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                              side: BorderSide(
                                color: Colors.orange.shade300,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Menu Items
              _buildProfileMenuItem(
                icon: IconsaxPlusLinear.edit,
                title: 'تعديل الملف الشخصي',
                onTap: () {
                  // TODO: Navigate to edit profile
                },
              ),
              const SizedBox(height: 12),
              _buildProfileMenuItem(
                icon: IconsaxPlusLinear.setting_2,
                title: 'الإعدادات',
                onTap: () {
                  // TODO: Navigate to settings
                },
              ),
              const SizedBox(height: 12),
              _buildProfileMenuItem(
                icon: IconsaxPlusLinear.message_question,
                title: 'المساعدة والدعم',
                onTap: () {
                  // TODO: Navigate to help
                },
              ),
              const SizedBox(height: 12),
              _buildProfileMenuItem(
                icon: IconsaxPlusLinear.info_circle,
                title: 'حول التطبيق',
                onTap: () {
                  // TODO: Show about dialog
                },
              ),
              const SizedBox(height: 24),
              // Logout Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: _buildProfileMenuItem(
                  icon: IconsaxPlusLinear.logout,
                  title: 'تسجيل الخروج',
                  iconColor: AppColors.error,
                  textColor: AppColors.error,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('تسجيل الخروج'),
                        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('إلغاء'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      context.read<AuthBloc>().add(const AuthSignOut());
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(
                          context,
                          RouteNames.signIn,
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_left_2,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          // Hamburger Menu
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(IconsaxPlusLinear.menu_1, size: 28),
              onPressed: () => Scaffold.of(context).openDrawer(),
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              'إلى أين تريد الذهاب؟',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Notification Icon
          const NotificationIconButton(
            iconColor: AppColors.textPrimary,
            backgroundColor: Colors.transparent,
            iconSize: 28,
            padding: EdgeInsets.all(8),
          ),
          const SizedBox(width: 8),
          // Profile Picture
          GestureDetector(
            onTap: () {
              // TODO: Navigate to profile
            },
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        user.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildDefaultAvatar(),
                      ),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return const Icon(IconsaxPlusBold.profile, color: Colors.white, size: 28);
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'هل لديك مكان في الاعتبار؟',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.6),
              fontSize: 16,
            ),
            prefixIcon: const Icon(
              IconsaxPlusLinear.search_normal,
              color: AppColors.textSecondary,
            ),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                IconsaxPlusLinear.microphone,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          onTap: () {
            Navigator.pushNamed(context, RouteNames.tripsList);
          },
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              IconsaxPlusBold.location,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'موقعك الحالي',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userLocation?.name ?? 'جاري تحديد الموقع...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isLoadingLocation)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    IconsaxPlusBold.gps,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: _loadUserLocation,
                  tooltip: 'تحديد الموقع تلقائياً',
                ),
                IconButton(
                  icon: Icon(
                    IconsaxPlusBold.map,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: _changeLocation,
                  tooltip: 'اختيار الموقع يدوياً',
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDiscoverCard({
    required String title,
    required double rating,
    required Gradient gradient,
    String? imageUrl,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            Navigator.pushNamed(context, RouteNames.tripsList);
          },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Image Placeholder
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(0.1),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      )
                    : null,
              ),
            ),
            // Rating Badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      IconsaxPlusBold.star,
                      color: Colors.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Title
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                  ),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyTripsSection(BuildContext context, user) {
    if (_userLocation == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'رحلات قريبة منك',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, RouteNames.tripsList);
                },
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<TripModel>>(
            stream: Provider.of<TripProvider>(
              context,
              listen: false,
            ).getActiveTripsStream(minDepartureTime: _activeTripsMinDepartureTime)
                .map((trips) {
                  // Filter out driver's own trips
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final firebaseUser = authProvider.userModel;
                  if (firebaseUser != null) {
                    trips = trips
                        .where((trip) => trip.driverId != firebaseUser.id)
                        .toList();
                  }

                  // Calculate distances and sort by proximity
                  if (_userLocation != null) {
                    final tripsWithDistance = trips.map((trip) {
                      final distance = _locationService
                          .calculateDistanceBetweenLocations(
                            _userLocation!,
                            trip.from,
                          );
                      return MapEntry(trip, distance);
                    }).toList();

                    // Sort by distance (closest first)
                    tripsWithDistance.sort(
                      (a, b) => a.value.compareTo(b.value),
                    );

                    // Filter trips within 100km radius
                    tripsWithDistance.removeWhere((entry) => entry.value > 100);

                    // Return only trips (without distances)
                    return tripsWithDistance.map((entry) => entry.key).toList();
                  }

                  return trips;
                }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          IconsaxPlusBold.danger,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'خطأ في تحميل الرحلات',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final trips = snapshot.data ?? [];

              if (trips.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        IconsaxPlusBold.location,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد رحلات قريبة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'جرب تغيير موقعك أو عرض جميع الرحلات',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, RouteNames.tripsList);
                        },
                        child: const Text('عرض جميع الرحلات'),
                      ),
                    ],
                  ),
                );
              }

              // Show only first 5 trips
              final displayedTrips = trips.take(5).toList();

              return Column(
                children: [
                  ...displayedTrips.map((trip) {
                    final distance = _locationService
                        .calculateDistanceBetweenLocations(
                          _userLocation!,
                          trip.from,
                        );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildNearbyTripCard(context, trip, distance),
                    );
                  }),
                  if (trips.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, RouteNames.tripsList);
                          },
                          child: Text('عرض ${trips.length - 5} رحلة أخرى'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyTripCard(
    BuildContext context,
    TripModel trip,
    double distance,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              RouteNames.tripDetails,
              arguments: trip.id,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Route Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusBold.location,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trip.from.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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
                            IconsaxPlusBold.location,
                            size: 14,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trip.to.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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
                            IconsaxPlusBold.clock,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            IconsaxPlusBold.dollar_circle,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${trip.price} ${trip.currency}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Distance & Seats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            IconsaxPlusBold.location,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} كم',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: trip.hasAvailableSeats
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${trip.availableSeats}/${trip.totalSeats}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: trip.hasAvailableSeats
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
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

  Widget _buildBottomNavigationBar(BuildContext context, user) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 12,
      ),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(IconsaxPlusLinear.home),
          activeIcon: Icon(IconsaxPlusBold.home, color: AppColors.primary),
          label: 'الرئيسية',
        ),
        const BottomNavigationBarItem(
          icon: Icon(IconsaxPlusLinear.search_normal),
          activeIcon: Icon(
            IconsaxPlusBold.search_normal,
            color: AppColors.primary,
          ),
          label: 'بحث',
        ),
        BottomNavigationBarItem(
          icon: user?.canCreateTrips == true
              ? const Icon(IconsaxPlusLinear.car)
              : const Icon(IconsaxPlusLinear.bookmark),
          activeIcon: user?.canCreateTrips == true
              ? const Icon(IconsaxPlusBold.car, color: AppColors.primary)
              : const Icon(IconsaxPlusBold.bookmark, color: AppColors.primary),
          label: user?.canCreateTrips == true ? 'رحلاتي' : 'حجوزاتي',
        ),
        const BottomNavigationBarItem(
          icon: Icon(IconsaxPlusLinear.profile),
          activeIcon: Icon(IconsaxPlusBold.profile, color: AppColors.primary),
          label: 'الملف الشخصي',
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, user) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header - Enhanced Design
            Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                    AppColors.primaryLight,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Picture with Badge
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child:
                              user?.photoUrl != null &&
                                  user.photoUrl!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    user.photoUrl!,
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              IconsaxPlusBold.profile,
                                              size: 50,
                                              color: AppColors.primary,
                                            ),
                                  ),
                                )
                              : const Icon(
                                  IconsaxPlusBold.profile,
                                  size: 50,
                                  color: AppColors.primary,
                                ),
                        ),
                      ),
                      // Status Badge
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const SizedBox(width: 12, height: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // User Name
                  Text(
                    user?.name ?? 'المستخدم',
                    style: GoogleFonts.tajawal(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // User Email
                  if (user?.email != null && user!.email.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          IconsaxPlusLinear.sms,
                          size: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user.email,
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  // Role Badge
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user.isDriver
                                ? IconsaxPlusBold.car
                                : IconsaxPlusBold.profile_2user,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            user.isDriver ? 'سائق' : 'راكب',
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerMenuItem(
                    icon: IconsaxPlusLinear.home,
                    title: 'الرئيسية',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentIndex = 0;
                      });
                    },
                  ),
                  // Browse Trips (available for both driver and passenger)
                  _buildDrawerMenuItem(
                    icon: IconsaxPlusLinear.search_normal,
                    title: 'تصفح الرحلات',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.tripsList);
                    },
                  ),
                  if (user?.canCreateTrips == true) ...[
                    _buildDrawerMenuItem(
                      icon: IconsaxPlusLinear.add_circle,
                      title: 'إنشاء رحلة',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, RouteNames.createTrip);
                      },
                    ),
                    _buildDrawerMenuItem(
                      icon: IconsaxPlusLinear.car,
                      title: 'رحلاتي',
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentIndex = 2;
                        });
                      },
                    ),
                    _buildDrawerMenuItem(
                      icon: IconsaxPlusLinear.wallet,
                      title: 'محفظتي',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, RouteNames.driverWallet);
                      },
                    ),
                  ],
                  _buildDrawerMenuItem(
                    icon: IconsaxPlusLinear.profile,
                    title: 'الملف الشخصي',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentIndex = 3;
                      });
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: IconsaxPlusLinear.setting_2,
                    title: 'الإعدادات',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to settings
                    },
                  ),
                  const Divider(
                    height: 32,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  _buildDrawerMenuItem(
                    icon: IconsaxPlusLinear.logout,
                    title: 'تسجيل الخروج',
                    iconColor: AppColors.error,
                    textColor: AppColors.error,
                    onTap: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            'تسجيل الخروج',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            'هل أنت متأكد من تسجيل الخروج؟',
                            style: GoogleFonts.tajawal(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                'إلغاء',
                                style: GoogleFonts.tajawal(),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              child: Text(
                                'تسجيل الخروج',
                                style: GoogleFonts.tajawal(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        context.read<AuthBloc>().add(const AuthSignOut());
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(
                            context,
                            RouteNames.signIn,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.transparent,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor ?? AppColors.textPrimary,
          ),
        ),
        trailing: Icon(
          IconsaxPlusLinear.arrow_left_2,
          size: 18,
          color: AppColors.textSecondary.withOpacity(0.5),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
