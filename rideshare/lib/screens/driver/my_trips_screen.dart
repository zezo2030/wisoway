import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../core/constants/route_names.dart';
import '../../widgets/notification_icon_button.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/empty_state.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = 'active';

  Future<void> _refreshTrips() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    if (user == null) return;

    await Provider.of<TripProvider>(context, listen: false).fetchDriverTrips(
      driverId: user.id,
      status: _selectedStatus,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedStatus = 'active';
            break;
          case 1:
            _selectedStatus = 'hidden';
            break;
          case 2:
            _selectedStatus = 'completed';
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final userModel = authProvider.userModel;

    if (user == null || userModel == null || !userModel.canCreateTrips) {
      return Scaffold(
        appBar: AppBar(title: const Text('رحلاتي')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              userModel != null &&
                      userModel.isDriver &&
                      !userModel.isDriverApproved
                  ? 'حسابك كسائق قيد المراجعة. لا يمكنك إنشاء أو إدارة رحلات حتى تتم الموافقة عليه.'
                  : 'يجب أن تكون سائقاً معتمداً لعرض الرحلات.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'رحلاتي',
          style: TextStyle(
            color: T.onSurface(context),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(iconColor: T.onSurface(context)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: T.primary(context),
          unselectedLabelColor: T.onSurfaceVariant(context),
          indicatorColor: T.primary(context),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'نشطة'),
            Tab(text: 'مخفية'),
            Tab(text: 'مكتملة'),
          ],
        ),
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: Provider.of<TripProvider>(
          context,
          listen: false,
        ).getDriverTripsStream(user.id, status: _selectedStatus),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('خطأ: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final trips = snapshot.data ?? [];

          if (trips.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshTrips,
              color: T.primary(context),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: EmptyState(
                    icon: _selectedStatus == 'active'
                        ? Icons.directions_car_outlined
                        : _selectedStatus == 'hidden'
                        ? Icons.visibility_off_outlined
                        : Icons.check_circle_outline,
                    title: _selectedStatus == 'active'
                        ? 'لا توجد رحلات نشطة'
                        : _selectedStatus == 'hidden'
                        ? 'لا توجد رحلات مخفية'
                        : 'لا توجد رحلات مكتملة',
                    showCircleBackground: false,
                    iconSize: 64,
                    action: _selectedStatus == 'active'
                        ? ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                RouteNames.createTrip,
                              );
                            },
                            icon: const Icon(IconsaxPlusBold.add_circle),
                            label: const Text('إنشاء رحلة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: T.primary(context),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshTrips,
            color: T.primary(context),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return _TripCard(trip: trip);
              },
            ),
          );
        },
      ),
      floatingActionButton: Semantics(
        button: true,
        label: 'إنشاء رحلة جديدة',
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, RouteNames.createTrip);
          },
          tooltip: 'رحلة جديدة',
          backgroundColor: T.primary(context),
          icon: const Icon(IconsaxPlusBold.add, color: AppColors.white),
          label: const Text(
            'رحلة جديدة',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
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
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');
    final isPast = trip.departureTime.isBefore(DateTime.now());

    Color getStatusColor() {
      switch (trip.status) {
        case 'active':
          return AppColors.success;
        case 'hidden':
          return AppColors.warning;
        case 'completed':
          return AppColors.info;
        default:
          return T.onSurfaceVariant(context);
      }
    }

    final statusColor = getStatusColor();

    final String fromName = trip.from.name.isNotEmpty
        ? trip.from.name
        : (trip.from.address ?? 'موقع غير معروف');
    final String toName = trip.to.name.isNotEmpty
        ? trip.to.name
        : (trip.to.address ?? 'موقع غير معروف');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.slate200.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: Semantics(
          button: true,
          label: 'رحلة من ${trip.from.name} إلى ${trip.to.name}',
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.tripManagement,
                arguments: trip.id,
              );
            },
            splashColor: statusColor.withOpacity(0.1),
            highlightColor: statusColor.withOpacity(0.05),
            child: Column(
              children: [
                // ---------------- TOP PART: Status & Time ----------------
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: statusColor.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trip.status == 'active'
                                  ? Icons.circle
                                  : trip.status == 'hidden'
                                  ? Icons.visibility_off
                                  : Icons.check_circle,
                              size: 10,
                              color: statusColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              trip.status == 'active'
                                  ? 'نشطة'
                                  : trip.status == 'hidden'
                                  ? 'مخفية'
                                  : 'مكتملة',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Date & Time
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusLinear.clock,
                            color: T.onSurfaceVariant(context),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${dateFormat.format(trip.departureTime)} • ${timeFormat.format(trip.departureTime)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: T.onSurfaceVariant(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ---------------- MIDDLE PART: Route (Horizontal) ----------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      // FROM
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'من',
                              style: TextStyle(
                                fontSize: 13,
                                color: T.onSurfaceVariant(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fromName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: T.onSurface(context),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // CAR ICON Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Icon(
                              IconsaxPlusBold.car,
                              color: T.primary(context),
                              size: 28,
                            ),
                            Container(
                              width: 60,
                              height: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: T.primary(context).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // TO
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'إلى',
                              style: TextStyle(
                                fontSize: 13,
                                color: T.onSurfaceVariant(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              toName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: T.onSurface(context),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Dotted Divider
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: List.generate(
                          (constraints.constrainWidth() / 10).floor(),
                          (index) => Expanded(
                            child: Container(
                              height: 1.5,
                              color: index % 2 == 0
                                  ? AppColors.slate400.withValues(alpha: 0.3)
                                  : AppColors.transparent,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ---------------- BOTTOM PART: Price & Seats ----------------
                Container(
                  decoration: BoxDecoration(
                    color: T.surface(context).withOpacity(0.6),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              IconsaxPlusBold.wallet_1,
                              color: AppColors.success,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سعر المقعد',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: T.onSurfaceVariant(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${trip.price} ${trip.currency}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Seats
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'المقاعد',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: T.onSurfaceVariant(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${trip.availableSeats} من ${trip.totalSeats}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: T.primary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: T.primary(context).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              IconsaxPlusBold.people,
                              color: T.primary(context),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Warning for past trips
                if (isPast) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          IconsaxPlusBold.info_circle,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'هذه الرحلة في الماضي',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
