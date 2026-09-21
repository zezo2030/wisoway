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
import '../../../core/services/location_service.dart';
import '../../../widgets/notification_icon_button.dart';
import '../widgets/default_avatar.dart';
import '../widgets/nearby_trip_card.dart';
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
  final LocationService _locationService = LocationService();
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
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              SliverToBoxAdapter(child: _buildInstantRideCta(context)),
              SliverToBoxAdapter(child: _buildLocationSection(context)),
              SliverToBoxAdapter(child: _buildNearbyTripsSection(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  /// "اطلب الآن" entry — opens the on-demand instant-ride request flow.
  Widget _buildInstantRideCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Material(
        color: T.primary(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InstantRideRequestScreen(
                initialFrom: widget.userLocation,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: T.onPrimary(context).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.electric_bolt,
                    color: T.onPrimary(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.instantRequestNowTitle,
                        style: TextStyle(
                          color: T.onPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.instantRequestNowSubtitle,
                        style: TextStyle(
                          color: T.onPrimary(context).withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  IconsaxPlusBold.arrow_left_2,
                  color: T.onPrimary(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.whereDoYouWantToGo,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: T.onSurface(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: NotificationIconButton(
              iconColor: T.onSurface(context),
              backgroundColor: AppColors.transparent,
              iconSize: 28,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: T.primary(context),
                border: Border.all(color: T.outline(context), width: 2),
              ),
              child:
                  widget.user?.photoUrl != null &&
                      widget.user!.photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.user!.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const DefaultAvatar(),
                      ),
                    )
                  : const DefaultAvatar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                IconsaxPlusLinear.microphone,
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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              IconsaxPlusBold.location,
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
                  context.l10n.currentLocation,
                  style: TextStyle(
                    fontSize: 12,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userLocation?.name ??
                      context.l10n.determiningLocation,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.isLoadingLocation)
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
                    color: T.primary(context),
                    size: 20,
                  ),
                  onPressed: widget.onRefreshLocation,
                  tooltip: context.l10n.detectLocationAutomatically,
                ),
                IconButton(
                  icon: Icon(
                    IconsaxPlusBold.map,
                    color: T.primary(context),
                    size: 20,
                  ),
                  onPressed: widget.onChangeLocation,
                  tooltip: context.l10n.chooseLocationManually,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNearbyTripsSection(BuildContext context) {
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
                context.l10n.nearbyTrips,
                style: TextStyle(
                  fontSize: 22,
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
                    fontSize: 16,
                    color: T.primary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<TripModel>>(
            stream:
                widget.userLocation != null &&
                    Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).userModel !=
                        null
                ? Provider.of<TripProvider>(
                    context,
                    listen: false,
                  ).getNearbyTripsStream(
                    excludeDriverId: Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).userModel!.id,
                    userLocation: widget.userLocation!,
                    minDepartureTime: _activeTripsMinDepartureTime,
                  )
                : Provider.of<TripProvider>(
                    context,
                    listen: false,
                  ).getActiveTripsStream(
                    minDepartureTime: _activeTripsMinDepartureTime,
                  ),
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

              final displayedTrips = trips.take(5).toList();

              return Column(
                children: [
                  ...displayedTrips.map((trip) {
                    final distance = _locationService
                        .calculateDistanceBetweenLocations(
                          widget.userLocation!,
                          trip.from,
                        );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NearbyTripCard(
                        trip: trip,
                        distance: distance,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.tripDetails,
                            arguments: trip.id,
                          );
                        },
                      ),
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
                          child: Text(
                            context.l10n.showMoreTrips(trips.length - 5),
                          ),
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
}
