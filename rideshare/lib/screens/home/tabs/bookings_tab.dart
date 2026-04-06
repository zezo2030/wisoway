import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../models/booking_model.dart';
import '../../../models/trip_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/trip_provider.dart';
import '../../../core/services/booking_service.dart';
import '../../../widgets/notification_icon_button.dart';
import '../widgets/booking_card.dart';
import '../widgets/trip_card.dart';
import '../../../widgets/common/empty_state.dart';

class BookingsTab extends StatefulWidget {
  final UserModel? user;

  const BookingsTab({super.key, this.user});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  bool _didFetchDriverTrips = false;
  int _passengerBookingsRefreshKey = 0;
  late final DateTime _bookingsMinDepartureTime;

  @override
  void initState() {
    super.initState();
    _bookingsMinDepartureTime = DateTime.now().subtract(
      const Duration(days: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user?.canCreateTrips == true) {
      return _buildDriverTripsPage(context);
    } else {
      return _buildPassengerBookingsPage(context);
    }
  }

  Widget _buildDriverTripsPage(BuildContext context) {
    final user = widget.user!;

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
      backgroundColor: T.surface(context),
      appBar: AppBar(
        title: Text(
          'رحلاتي',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: AppColors.transparent,
              iconColor: T.onSurface(context),
            ),
          ),
          Semantics(
            label: 'إنشاء رحلة جديدة',
            button: true,
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(IconsaxPlusBold.add_circle),
                color: T.primary(context),
                onPressed: () {
                  Navigator.pushNamed(context, RouteNames.createTrip);
                },
                tooltip: 'إنشاء رحلة جديدة',
              ),
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
                valueColor: AlwaysStoppedAnimation<Color>(T.primary(context)),
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
            color: T.primary(context),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                return TripCard(
                  trip: trips[index],
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      RouteNames.tripManagement,
                      arguments: trips[index].id,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPassengerBookingsPage(BuildContext context) {
    const pageBackground = AppColors.slate100;

    if (widget.user == null) {
      return Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          title: Text(
            'حجوزاتي',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: NotificationIconButton(
                backgroundColor: AppColors.transparent,
                iconColor: T.onSurface(context),
              ),
            ),
          ],
        ),
        body: const Center(child: Text('يجب تسجيل الدخول')),
      );
    }

    return Scaffold(
      backgroundColor: pageBackground,
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
        ).getActiveTripsStream(minDepartureTime: _bookingsMinDepartureTime),
        builder: (context, tripsSnapshot) {
          final bookingService = BookingService();
          return FutureBuilder<List<BookingGroupModel>>(
            key: ValueKey(_passengerBookingsRefreshKey),
            future: bookingService.getMyGroupedBookings(),
            builder: (context, bookingsSnapshot) {
              if (bookingsSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      T.primary(context),
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

              final groupedBookings = bookingsSnapshot.data ?? [];

              if (groupedBookings.isEmpty) {
                return EmptyState(
                  icon: IconsaxPlusBold.bookmark,
                  title: 'حجوزاتي',
                  subtitle: 'لا توجد حجوزات حالياً',
                  action: Semantics(
                    label: 'تصفح الرحلات',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.tripsList);
                      },
                      icon: const Icon(IconsaxPlusBold.search_normal),
                      label: const Text('تصفح الرحلات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: T.primary(context),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final tripsMap = <String, TripModel>{
                for (final trip in (tripsSnapshot.data ?? <TripModel>[])) trip.id: trip,
              };
              final upcoming = <BookingGroupModel>[];
              final past = <BookingGroupModel>[];
              for (final group in groupedBookings) {
                final trip = tripsMap[group.tripId] ?? group.trip;
                final isPast =
                    group.isCancelled ||
                    group.isCompleted ||
                    (trip != null &&
                        (!trip.departureTime.isAfter(DateTime.now()) ||
                            const {'completed', 'cancelled', 'expired'}.contains(
                              trip.status,
                            )));
                if (isPast) {
                  past.add(group);
                } else {
                  upcoming.add(group);
                }
              }

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _passengerBookingsRefreshKey++);
                },
                color: T.primary(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (upcoming.isNotEmpty) ...[
                      _buildSectionTitle('قادمة'),
                      const SizedBox(height: 12),
                      ...upcoming.map((group) {
                        final trip = tripsMap[group.tripId] ?? group.trip;
                        return BookingCard(
                          group: group,
                          trip: trip,
                          isPastTrip: false,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              RouteNames.bookingDetails,
                              arguments: group.bookingGroupId,
                            );
                          },
                        );
                      }),
                    ],
                    if (past.isNotEmpty) ...[
                      if (upcoming.isNotEmpty) const SizedBox(height: 24),
                      _buildSectionTitle('سابقة'),
                      const SizedBox(height: 12),
                      ...past.map((group) {
                        final trip = tripsMap[group.tripId] ?? group.trip;
                        return BookingCard(
                          group: group,
                          trip: trip,
                          isPastTrip: true,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              RouteNames.bookingDetails,
                              arguments: group.bookingGroupId,
                            );
                          },
                        );
                      }),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.tajawal(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: T.onSurface(context),
      ),
    );
  }

  Widget _buildEmptyTripsState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 200,
        padding: const EdgeInsets.all(20),
        child: EmptyState(
          icon: IconsaxPlusBold.car,
          title: 'لا توجد رحلات',
          subtitle: 'ابدأ بإنشاء رحلة جديدة وشارك\nرحلتك مع الآخرين',
          action: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [T.primary(context), AppColors.teal700],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: T.primary(context).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, RouteNames.createTrip);
              },
              icon: const Icon(
                IconsaxPlusBold.add_circle,
                color: AppColors.white,
              ),
              label: const Text('إنشاء رحلة جديدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.transparent,
                shadowColor: AppColors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ),
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
                color: T.error(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusBold.danger,
                size: 64,
                color: T.error(context),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: T.onSurface(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: T.onSurfaceVariant(context),
              ),
            ),
            const SizedBox(height: 32),
            Semantics(
              label: 'إعادة المحاولة',
              button: true,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.primary(context),
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
            ),
          ],
        ),
      ),
    );
  }
}
