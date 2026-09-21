import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/location_model.dart';
import '../../../models/trip_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/trip_provider.dart';
import '../../../widgets/notification_icon_button.dart';
import '../widgets/default_avatar.dart';
import '../widgets/driver_availability_card.dart';
import '../widgets/driver_home_cards.dart';
import '../widgets/trip_card.dart';

/// Driver-only home tab.
///
/// Follows the driver dashboard mockup: greeting header, the go-online card,
/// the publish-a-trip call to action, the current location card, today's
/// summary and the driver's own active trips.
class DriverHomeContent extends StatefulWidget {
  final UserModel user;
  final LocationModel? userLocation;
  final bool isLoadingLocation;
  final VoidCallback onOpenDrawer;
  final VoidCallback onRefreshLocation;
  final VoidCallback onChangeLocation;
  final Future<void> Function()? onRefreshData;

  const DriverHomeContent({
    super.key,
    required this.user,
    this.userLocation,
    this.isLoadingLocation = false,
    required this.onOpenDrawer,
    required this.onRefreshLocation,
    required this.onChangeLocation,
    this.onRefreshData,
  });

  @override
  State<DriverHomeContent> createState() => _DriverHomeContentState();
}

class _DriverHomeContentState extends State<DriverHomeContent> {
  final BookingService _bookingService = BookingService();

  bool _didFetch = false;

  /// Mirrors the availability card's toggle so the avatar's presence dot stays
  /// in step with it.
  bool _isOnline = false;

  /// When [DriverHomeContent.userLocation] last changed — the card shows the
  /// age of the fix rather than pretending it is always current.
  DateTime _locationStampedAt = DateTime.now();

  /// Trip ids the pending-request count was last computed for, so the per-trip
  /// booking lookups only run when the driver's trip set actually changes.
  String _pendingRequestsKey = '';
  int _pendingRequests = 0;

  @override
  void didUpdateWidget(covariant DriverHomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userLocation != oldWidget.userLocation) {
      _locationStampedAt = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_didFetch) {
      _didFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TripProvider>().fetchDriverTrips(
          driverId: widget.user.id,
          driverName: widget.user.name,
        );
      });
    }

    return Container(
      color: T.surface(context),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: T.primary(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(
                child: DriverAvailabilityCard(
                  onOnlineChanged: (value) {
                    if (mounted && value != _isOnline) {
                      setState(() => _isOnline = value);
                    }
                  },
                ),
              ),
              SliverToBoxAdapter(child: _buildPublishTripCta(context)),
              SliverToBoxAdapter(child: _buildLocationCard(context)),
              SliverToBoxAdapter(child: _buildTripsAndSummary(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    _pendingRequestsKey = '';
    await Future.wait([
      context.read<TripProvider>().fetchDriverTrips(
        driverId: widget.user.id,
        driverName: widget.user.name,
      ),
      if (widget.onRefreshData != null) widget.onRefreshData!(),
    ]);
  }

  // ---------------------------------------------------------------- header

  Widget _buildHeader(BuildContext context) {
    final l10n = context.l10n;
    final firstName = widget.user.name.trim().split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(context),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.homeGreeting} $firstName 👋',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: T.onSurfaceVariant(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.driverHomeReadyTitle,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.driverHomeReadySubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          NotificationIconButton(
            iconColor: T.onSurface(context),
            backgroundColor: AppColors.transparent,
            iconSize: 26,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final photo = widget.user.photoUrl;

    return Semantics(
      label: widget.user.name,
      child: SizedBox(
        width: 58,
        height: 58,
        child: Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: T.surfaceVariant(context),
                border: Border.all(color: T.surface(context), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: T.shadow(context).withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: photo != null && photo.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photo,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const DefaultAvatar(),
                      ),
                    )
                  : const DefaultAvatar(),
            ),
            // Presence dot, driven by the availability toggle below it.
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: _isOnline
                      ? AppColors.success
                      : T.onSurfaceVariant(context).withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: T.surface(context), width: 2.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- cta

  Widget _buildPublishTripCta(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Material(
        color: T.primary(context),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pushNamed(context, RouteNames.createTrip),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: T.primary(context).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Faint route doodle, the way the mockup dresses the tile.
                PositionedDirectional(
                  end: 0,
                  top: 0,
                  bottom: 0,
                  width: 160,
                  child: CustomPaint(
                    painter: RouteDoodlePainter(
                      color: T.onPrimary(context).withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.publishSharedTrip,
                              style: TextStyle(
                                color: T.onPrimary(context),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              l10n.publishSharedTripSubtitle,
                              style: TextStyle(
                                color: T
                                    .onPrimary(context)
                                    .withValues(alpha: 0.88),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: T.onPrimary(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 28,
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
    );
  }

  // -------------------------------------------------------------- location

  Widget _buildLocationCard(BuildContext context) {
    final l10n = context.l10n;
    final minutes = DateTime.now().difference(_locationStampedAt).inMinutes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: DriverHomeCard(
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                IconsaxPlusBold.gps,
                color: T.primary(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.currentLocation,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.userLocation?.name ?? l10n.determiningLocation,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: T.onSurface(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.userLocation != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            minutes < 1
                                ? l10n.locationUpdatedJustNow
                                : l10n.locationUpdatedMinutesAgo(minutes),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: T.primary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (widget.isLoadingLocation)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              DriverHomeMiniAction(
                icon: IconsaxPlusLinear.map,
                label: l10n.showOnMapAction,
                onTap: widget.onChangeLocation,
              ),
              const SizedBox(width: 8),
              DriverHomeMiniAction(
                icon: IconsaxPlusLinear.gps,
                label: l10n.updateLocationAction,
                onTap: widget.onRefreshLocation,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------- summary + own trips

  Widget _buildTripsAndSummary(BuildContext context) {
    return StreamBuilder<List<TripModel>>(
      stream: context.read<TripProvider>().getDriverTripsStream(
        widget.user.id,
        driverName: widget.user.name,
      ),
      builder: (context, snapshot) {
        final upcoming = _upcoming(snapshot.data ?? const <TripModel>[]);
        _refreshPendingRequests(upcoming);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummary(context, upcoming),
            _buildMyTripsSection(context, snapshot, upcoming),
          ],
        );
      },
    );
  }

  List<TripModel> _upcoming(List<TripModel> trips) {
    final now = DateTime.now();
    return trips.where((t) {
      if (t.status == 'completed' || t.status == 'cancelled') return false;
      return t.departureTime.isAfter(now.subtract(const Duration(hours: 2)));
    }).toList()..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  }

  /// Counts bookings still awaiting the driver's reply. There is no
  /// driver-wide bookings endpoint, so this asks per trip — capped, and only
  /// when the trip set changes.
  Future<void> _refreshPendingRequests(List<TripModel> trips) async {
    final capped = trips.take(8).toList();
    final key = capped.map((t) => t.id).join(',');
    if (key == _pendingRequestsKey) return;
    _pendingRequestsKey = key;

    if (capped.isEmpty) {
      if (mounted && _pendingRequests != 0) {
        setState(() => _pendingRequests = 0);
      }
      return;
    }

    final lists = await Future.wait(
      capped.map((t) => _bookingService.getTripBookings(t.id)),
    );
    final count = lists
        .expand((bookings) => bookings)
        .where((booking) => booking.isPending)
        .length;

    if (mounted && count != _pendingRequests) {
      setState(() => _pendingRequests = count);
    }
  }

  Widget _buildSummary(BuildContext context, List<TripModel> upcoming) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final todayTrips = upcoming
        .where(
          (t) =>
              t.departureTime.year == now.year &&
              t.departureTime.month == now.month &&
              t.departureTime.day == now.day,
        )
        .length;
    final bookedSeats = upcoming.fold<int>(
      0,
      (sum, t) => sum + (t.totalSeats - t.availableSeats),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriverHomeSectionHeader(
            icon: IconsaxPlusBold.chart_2,
            title: l10n.todaySummary,
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DriverHomeStatCard(
                    icon: IconsaxPlusBold.notification,
                    accent: AppColors.warning,
                    label: l10n.statNewRequests,
                    value: '$_pendingRequests',
                    hint: l10n.statNewRequestsHint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DriverHomeStatCard(
                    icon: IconsaxPlusBold.car,
                    accent: AppColors.info,
                    label: l10n.statTodayTrips,
                    value: '$todayTrips',
                    hint: l10n.statTodayTripsHint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DriverHomeStatCard(
                    icon: IconsaxPlusBold.profile_2user,
                    accent: T.primary(context),
                    label: l10n.statBookings,
                    value: '$bookedSeats',
                    hint: l10n.statBookingsHint,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, RouteNames.myTrips),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.viewAllStats,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: T.primary(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: T.primary(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTripsSection(
    BuildContext context,
    AsyncSnapshot<List<TripModel>> snapshot,
    List<TripModel> upcoming,
  ) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DriverHomeSectionHeader(
            icon: IconsaxPlusBold.car,
            title: l10n.driverCurrentTripsTitle,
            action: upcoming.isEmpty
                ? null
                : DriverHomeSectionLink(
                    label: l10n.viewAll,
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.myTrips),
                  ),
          ),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (snapshot.hasError)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    IconsaxPlusBold.danger,
                    size: 44,
                    color: T.error(context),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.errorLoadingTrips,
                    style: TextStyle(color: T.onSurfaceVariant(context)),
                  ),
                ],
              ),
            )
          else if (upcoming.isEmpty)
            DriverHomeNoTripsCard(
              onPublish: () =>
                  Navigator.pushNamed(context, RouteNames.createTrip),
            )
          else
            ...upcoming
                .take(5)
                .map(
                  (trip) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TripCard(
                      trip: trip,
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.tripDetails,
                        arguments: trip,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
