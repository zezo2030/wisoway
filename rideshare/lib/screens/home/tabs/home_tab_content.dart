import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/location_model.dart';
import '../../../models/trip_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../widgets/notification_icon_button.dart';
import '../widgets/default_avatar.dart';
import '../widgets/ride_mode_card.dart';
import '../widgets/suggested_trips_carousel.dart';
import '../widgets/trust_strip.dart';
import '../../../widgets/common/empty_state.dart';
import '../../passenger/instant_ride_request_screen.dart';

class HomeTabContent extends StatefulWidget {
  final UserModel? user;
  final LocationModel? userLocation;
  final bool isLoadingLocation;
  final VoidCallback onOpenDrawer;
  final VoidCallback onRefreshLocation;
  final VoidCallback onChangeLocation;
  final Future<void> Function()? onRefreshData;

  const HomeTabContent({
    super.key,
    this.user,
    this.userLocation,
    this.isLoadingLocation = false,
    required this.onOpenDrawer,
    required this.onRefreshLocation,
    required this.onChangeLocation,
    this.onRefreshData,
  });

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  /// How many suggested trips the carousel carries before "view all" takes over.
  static const int _maxSuggestedTrips = 8;

  late final DateTime _activeTripsMinDepartureTime;

  @override
  void initState() {
    super.initState();
    _activeTripsMinDepartureTime = DateTime.now();
  }

  Future<void> _handleRefresh() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    await Future.wait([
      tripProvider.fetchActiveTrips(
        minDepartureTime: _activeTripsMinDepartureTime,
      ),
      if (widget.onRefreshData != null) widget.onRefreshData!(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
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
              SliverToBoxAdapter(child: _buildRideModes(context)),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              SliverToBoxAdapter(child: _buildLocationSection(context)),
              SliverToBoxAdapter(child: _buildSuggestedTripsSection(context)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: TrustStrip(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => Semantics(
                  label: context.l10n.openMenu,
                  button: true,
                  child: IconButton(
                    icon: const Icon(IconsaxPlusLinear.menu_1, size: 28),
                    onPressed: widget.onOpenDrawer,
                    color: T.onSurface(context),
                    tooltip: context.l10n.sideMenu,
                  ),
                ),
              ),
              const Spacer(),
              NotificationIconButton(
                iconColor: T.onSurface(context),
                backgroundColor: AppColors.transparent,
                iconSize: 28,
              ),
              const SizedBox(width: 8),
              _buildAvatar(context),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.whereDoYouWantToGo,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.homeChooseModeSubtitle,
            style: TextStyle(fontSize: 14, color: T.onSurfaceVariant(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final photoUrl = widget.user?.photoUrl;

    return GestureDetector(
      onTap: widget.onOpenDrawer,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: T.primary(context),
          border: Border.all(color: T.outline(context), width: 2),
        ),
        child: photoUrl != null && photoUrl.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const DefaultAvatar(),
                ),
              )
            : const DefaultAvatar(),
      ),
    );
  }

  /// The two ways to travel: join a published trip, or hail a driver now.
  Widget _buildRideModes(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RideModeCard(
                mode: RideMode.shared,
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.tripsList),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RideModeCard(
                mode: RideMode.private,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InstantRideRequestScreen(
                      initialFrom: widget.userLocation,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: context.l10n.haveAPlaceInMind,
            hintStyle: TextStyle(
              color: T.onSurfaceVariant(context).withValues(alpha: 0.6),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              IconsaxPlusLinear.search_normal,
              color: T.onSurfaceVariant(context),
            ),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusLinear.gps,
                color: T.primary(context),
                size: 20,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: T.surface(context),
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
    final l10n = context.l10n;
    final hasLocation = widget.userLocation != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outlineVariant(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: T.primary(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        IconsaxPlusBold.location,
                        color: T.primary(context),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            widget.userLocation?.name ??
                                l10n.determiningLocation,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: T.onSurface(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (widget.isLoadingLocation)
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                  ),
                                )
                              else
                                Icon(
                                  hasLocation
                                      ? Icons.check_circle
                                      : Icons.error_outline,
                                  size: 12,
                                  color: hasLocation
                                      ? AppColors.success
                                      : T.onSurfaceVariant(context),
                                ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.isLoadingLocation
                                      ? l10n.determiningLocation
                                      : hasLocation
                                      ? l10n.homeLocationAccurate
                                      : l10n.homeLocationUnknown,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: hasLocation
                                        ? AppColors.success
                                        : T.onSurfaceVariant(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _locationAction(
              context,
              icon: IconsaxPlusLinear.location,
              label: l10n.changeLocation,
              onTap: widget.onChangeLocation,
              tooltip: l10n.chooseLocationManually,
            ),
            _locationAction(
              context,
              icon: IconsaxPlusLinear.gps,
              label: l10n.homeDetectMyLocation,
              onTap: widget.isLoadingLocation ? null : widget.onRefreshLocation,
              tooltip: l10n.detectLocationAutomatically,
            ),
          ],
        ),
      ),
    );
  }

  /// One of the two labelled actions beside the current location.
  Widget _locationAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Container(
      width: 84,
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: T.outlineVariant(context)),
        ),
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: T.primary(context)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: T.onSurface(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedTripsSection(BuildContext context) {
    if (widget.userLocation == null) {
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
              Text(
                context.l10n.suggestedTripsTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, RouteNames.tripsList);
                },
                child: Text(
                  context.l10n.viewAll,
                  style: TextStyle(
                    fontSize: 15,
                    color: T.primary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<TripModel>>(
            stream: _suggestedTripsStream(context),
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
                          color: T.error(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.errorLoadingTrips,
                          style: TextStyle(color: T.onSurfaceVariant(context)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final trips = snapshot.data ?? [];

              if (trips.isEmpty) {
                return EmptyState(
                  icon: IconsaxPlusBold.location,
                  title: context.l10n.noNearbyTripsTitle,
                  subtitle: context.l10n.noNearbyTripsSubtitle,
                  showCircleBackground: false,
                  iconSize: 48,
                  action: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, RouteNames.tripsList);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.primary(context),
                    ),
                    child: Text(context.l10n.viewAllTrips),
                  ),
                );
              }

              return SuggestedTripsCarousel(
                trips: trips.take(_maxSuggestedTrips).toList(),
                onTripTap: (trip) => Navigator.pushNamed(
                  context,
                  RouteNames.tripDetails,
                  arguments: trip.id,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Stream<List<TripModel>> _suggestedTripsStream(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    final location = widget.userLocation;

    if (location == null || user == null) {
      return tripProvider.getActiveTripsStream(
        minDepartureTime: _activeTripsMinDepartureTime,
      );
    }

    return tripProvider.getNearbyTripsStream(
      excludeDriverId: user.id,
      userLocation: location,
      minDepartureTime: _activeTripsMinDepartureTime,
    );
  }
}
