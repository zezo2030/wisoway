import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/booking_model.dart';
import '../../../models/trip_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/trip_provider.dart';
import '../../../core/services/booking_service.dart';
import '../../../widgets/notification_icon_button.dart';
import '../widgets/booking_card.dart';
import '../widgets/trip_card.dart';
import '../../../widgets/common/empty_state.dart';
import '../../../core/ui/error_surface.dart';
import '../../../core/api/api_client.dart';

class BookingsTab extends StatefulWidget {
  final UserModel? user;

  const BookingsTab({super.key, this.user});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  bool _didFetchDriverTrips = false;
  late final DateTime _bookingsMinDepartureTime;
  final BookingService _bookingService = BookingService();
  late Future<List<BookingModel>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsMinDepartureTime = DateTime.now().subtract(
      const Duration(days: 1),
    );
    _bookingsFuture = _bookingService.getUserBookings();
  }

  void _refreshBookings() {
    setState(() {
      _bookingsFuture = _bookingService.getUserBookings();
    });
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
          context.l10n.myTripsTitle,
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
            label: context.l10n.createNewTrip,
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
                tooltip: context.l10n.createNewTrip,
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
    if (widget.user == null) {
      return Scaffold(
        backgroundColor: T.surface(context),
        appBar: AppBar(
          title: Text(
            context.l10n.myBookings,
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
        body: Center(child: Text(context.l10n.mustSignIn)),
      );
    }

    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        title: Text(
          context.l10n.myBookings,
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: FutureBuilder<List<BookingModel>>(
        future: _bookingsFuture,
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

          final bookings = bookingsSnapshot.data ?? [];

          if (bookings.isEmpty) {
            return EmptyState(
              icon: IconsaxPlusBold.bookmark,
              title: context.l10n.myBookings,
              subtitle: context.l10n.noBookingsCurrently,
              action: Semantics(
                label: context.l10n.browseTrips,
                button: true,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, RouteNames.tripsList);
                  },
                  icon: const Icon(IconsaxPlusBold.search_normal),
                  label: Text(context.l10n.browseTrips),
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

          return StreamBuilder<List<TripModel>>(
            stream: Provider.of<TripProvider>(
              context,
              listen: false,
            ).getActiveTripsStream(minDepartureTime: _bookingsMinDepartureTime),
            builder: (context, tripsSnapshot) {
              final tripsMap = <String, TripModel>{};
              for (final booking in bookings) {
                final trip = booking.tripPopulated;
                if (trip != null) {
                  tripsMap[booking.tripId] = trip;
                }
              }
              for (final trip in tripsSnapshot.data ?? <TripModel>[]) {
                tripsMap.putIfAbsent(trip.id, () => trip);
              }

              final (:upcoming, :past) = BookingModel.categorizeBookings(
                bookings,
                tripsMap,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  _refreshBookings();
                },
                color: T.primary(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (upcoming.isNotEmpty) ...[
                      _buildSectionTitle(context.l10n.upcoming),
                      const SizedBox(height: 12),
                      ...upcoming.map((booking) {
                        final trip =
                            tripsMap[booking.tripId] ?? booking.tripPopulated;
                        return BookingCard(
                          booking: booking,
                          trip: trip,
                          isPastTrip: false,
                          onTap: trip != null
                              ? () {
                                  Navigator.pushNamed(
                                    context,
                                    RouteNames.tripDetails,
                                    arguments: {
                                      'tripId': trip.id,
                                      'booking': booking,
                                    },
                                  );
                                }
                              : null,
                          onCancel: () => _showCancelDialog(booking, trip),
                        );
                      }),
                    ],
                    if (past.isNotEmpty) ...[
                      if (upcoming.isNotEmpty) const SizedBox(height: 24),
                      _buildSectionTitle(context.l10n.past),
                      const SizedBox(height: 12),
                      ...past.map((booking) {
                        final trip =
                            tripsMap[booking.tripId] ?? booking.tripPopulated;
                        return BookingCard(
                          booking: booking,
                          trip: trip,
                          isPastTrip: true,
                          onTap: trip != null
                              ? () {
                                  Navigator.pushNamed(
                                    context,
                                    RouteNames.tripDetails,
                                    arguments: {
                                      'tripId': trip.id,
                                      'booking': booking,
                                    },
                                  );
                                }
                              : null,
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

  Future<void> _showCancelDialog(BookingModel booking, TripModel? trip) async {
    final now = DateTime.now();
    final departureTime = trip?.departureTime;
    final hoursUntilDeparture = departureTime != null
        ? departureTime.difference(now).inHours
        : null;

    // Check 12-hour restriction client-side
    if (hoursUntilDeparture != null && hoursUntilDeparture < 12) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(IconsaxPlusBold.warning_2, color: AppColors.error, size: 22),
              const SizedBox(width: 8),
              Text(context.l10n.cannotCancel,
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            context.l10n.cannotCancelWithin12Hours(
              departureTime != null
                  ? _formatDeparture(departureTime)
                  : context.l10n.unknown,
            ),
            style: GoogleFonts.tajawal(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.ok,
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // Show warning dialog with fee info
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(IconsaxPlusBold.warning_2, color: AppColors.warning, size: 22),
            const SizedBox(width: 8),
            Text(context.l10n.confirmCancelBooking,
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (booking.isConfirmed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(IconsaxPlusBold.info_circle,
                        color: AppColors.warningDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.cancellationFeeNotice,
                        style: GoogleFonts.tajawal(
                          color: AppColors.warningDark,
                          height: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              context.l10n.confirmCancelBookingQuestion,
              style: GoogleFonts.tajawal(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.goBack,
                style: GoogleFonts.tajawal(color: T.onSurfaceVariant(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n.cancelBooking,
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _bookingService.cancelBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.bookingCancelledSuccess,
              style: GoogleFonts.tajawal()),
          backgroundColor: AppColors.success,
        ),
      );
      _refreshBookings();
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  String _formatDeparture(DateTime dt) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} - $h:$m';
  }

  Widget _buildEmptyTripsState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 200,
        padding: const EdgeInsets.all(20),
        child: EmptyState(
          icon: IconsaxPlusBold.car,
          title: context.l10n.noTripsTitle,
          subtitle: context.l10n.noTripsSubtitle,
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
              label: Text(context.l10n.createNewTrip),
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
              context.l10n.errorOccurred,
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
              label: context.l10n.tryAgain,
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
                  context.l10n.tryAgain,
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
