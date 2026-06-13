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
import '../../../providers/trip_provider.dart';
import '../../../widgets/notification_icon_button.dart';
import '../widgets/default_avatar.dart';
import '../widgets/trip_card.dart';
import '../../../widgets/common/empty_state.dart';

/// Driver-only home tab. Mirrors the passenger [HomeTabContent] layout
/// (same header, same card shapes, same spacing) but swaps the search bar
/// for a "Create trip" CTA and replaces the "nearby trips" feed with the
/// driver's own upcoming trips.
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
  bool _didFetch = false;

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
              SliverToBoxAdapter(child: _buildCreateTripCta(context)),
              SliverToBoxAdapter(child: _buildLocationSection(context)),
              SliverToBoxAdapter(child: _buildMyTripsSection(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      context.read<TripProvider>().fetchDriverTrips(
        driverId: widget.user.id,
        driverName: widget.user.name,
      ),
      if (widget.onRefreshData != null) widget.onRefreshData!(),
    ]);
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
              context.l10n.whereWillYourTripStart,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: T.onSurface(context),
              ),
              maxLines: 2,
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
                  widget.user.photoUrl != null &&
                      widget.user.photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.user.photoUrl!,
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

  /// Same shape/shadow/radius as the passenger search bar — but a CTA tile
  /// that opens the create-trip flow.
  Widget _buildCreateTripCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Material(
        color: T.primary(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, RouteNames.createTrip),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: T.primary(context).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: T.onPrimary(context).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconsaxPlusBold.add_circle,
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
                        context.l10n.createNewTrip,
                        style: TextStyle(
                          color: T.onPrimary(context),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.createTripCtaSubtitle,
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

  Widget _buildMyTripsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.myActiveTrips,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<TripModel>>(
            stream: context.read<TripProvider>().getDriverTripsStream(
              widget.user.id,
              driverName: widget.user.name,
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
                          style: TextStyle(
                            color: T.onSurfaceVariant(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final now = DateTime.now();
              final upcoming =
                  (snapshot.data ?? [])
                      .where((t) {
                        if (t.status == 'completed' ||
                            t.status == 'cancelled') {
                          return false;
                        }
                        return t.departureTime.isAfter(
                          now.subtract(const Duration(hours: 2)),
                        );
                      })
                      .toList()
                    ..sort(
                      (a, b) => a.departureTime.compareTo(b.departureTime),
                    );

              if (upcoming.isEmpty) {
                return EmptyState(
                  icon: IconsaxPlusBold.calendar_remove,
                  title: context.l10n.noActiveTripsTitle,
                  subtitle: context.l10n.noActiveTripsSubtitle,
                  showCircleBackground: false,
                  iconSize: 48,
                  action: ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, RouteNames.createTrip),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.primary(context),
                    ),
                    child: Text(context.l10n.createTripTitle),
                  ),
                );
              }

              final displayed = upcoming.take(5).toList();

              return Column(
                children: [
                  ...displayed.map(
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
              );
            },
          ),
        ],
      ),
    );
  }
}
