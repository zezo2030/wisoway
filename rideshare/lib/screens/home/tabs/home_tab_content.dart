import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
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

class HomeTabContent extends StatefulWidget {
  final UserModel? user;
  final LocationModel? userLocation;
  final bool isLoadingLocation;
  final VoidCallback onOpenDrawer;
  final VoidCallback onRefreshLocation;
  final VoidCallback onChangeLocation;

  const HomeTabContent({
    super.key,
    this.user,
    this.userLocation,
    this.isLoadingLocation = false,
    required this.onOpenDrawer,
    required this.onRefreshLocation,
    required this.onChangeLocation,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate100,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildSearchBar(context)),
            SliverToBoxAdapter(child: _buildLocationSection(context)),
            SliverToBoxAdapter(child: _buildNearbyTripsSection(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
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
              label: 'فتح القائمة',
              button: true,
              child: IconButton(
                icon: const Icon(IconsaxPlusLinear.menu_1, size: 28),
                onPressed: widget.onOpenDrawer,
                color: T.onSurface(context),
                tooltip: 'القائمة الجانبية',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'إلى أين تريد الذهاب؟',
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
            hintText: 'هل لديك مكان في الاعتبار؟',
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
                  'موقعك الحالي',
                  style: TextStyle(
                    fontSize: 12,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userLocation?.name ?? 'جاري تحديد الموقع...',
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
                  tooltip: 'تحديد الموقع تلقائياً',
                ),
                IconButton(
                  icon: Icon(
                    IconsaxPlusBold.map,
                    color: T.primary(context),
                    size: 20,
                  ),
                  onPressed: widget.onChangeLocation,
                  tooltip: 'اختيار الموقع يدوياً',
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
                'رحلات قريبة منك',
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
                  'عرض الكل',
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
                          'خطأ في تحميل الرحلات',
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
                  title: 'لا توجد رحلات قريبة',
                  subtitle: 'جرب تغيير موقعك أو عرض جميع الرحلات',
                  showCircleBackground: false,
                  iconSize: 48,
                  action: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, RouteNames.tripsList);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.primary(context),
                    ),
                    child: const Text('عرض جميع الرحلات'),
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
}
