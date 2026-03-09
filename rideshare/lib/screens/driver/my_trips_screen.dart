import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../core/constants/route_names.dart';
import '../../widgets/notification_icon_button.dart';
import '../../core/theme/colors.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = 'active';

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
              userModel != null && userModel.isDriver && !userModel.isDriverApproved
                  ? 'حسابك كسائق قيد المراجعة. لا يمكنك إنشاء أو إدارة رحلات حتى تتم الموافقة عليه.'
                  : 'يجب أن تكون سائقاً معتمداً لعرض الرحلات.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلاتي'),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: Colors.transparent,
              iconColor: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, RouteNames.createTrip);
            },
            tooltip: 'إنشاء رحلة جديدة',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedStatus == 'active'
                        ? Icons.directions_car_outlined
                        : _selectedStatus == 'hidden'
                        ? Icons.visibility_off_outlined
                        : Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedStatus == 'active'
                        ? 'لا توجد رحلات نشطة'
                        : _selectedStatus == 'hidden'
                        ? 'لا توجد رحلات مخفية'
                        : 'لا توجد رحلات مكتملة',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedStatus == 'active')
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.createTrip);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('إنشاء رحلة جديدة'),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return _TripCard(trip: trip);
            },
          );
        },
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

    // Define colors based on status
    Color getStatusColor() {
      switch (trip.status) {
        case 'active':
          return const Color(0xFF10B981); // Emerald
        case 'hidden':
          return const Color(0xFFF59E0B); // Amber
        case 'completed':
          return const Color(0xFF3B82F6); // Blue
        default:
          return const Color(0xFF6B7280); // Gray
      }
    }

    final statusColor = getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Navigate to trip management
            Navigator.pushNamed(
              context,
              RouteNames.tripManagement,
              arguments: trip.id,
            );
          },
          splashColor: statusColor.withOpacity(0.1),
          highlightColor: statusColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with route and status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route information
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // From location
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7), // Light green
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.trip_origin,
                                  size: 18,
                                  color: Color(0xFF166534), // Dark green
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trip.from.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF166534),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // To location
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2), // Light red
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: Color(0xFFDC2626), // Dark red
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trip.to.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFFDC2626),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
                          width: 1,
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
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trip.status == 'active'
                                ? 'نشطة'
                                : trip.status == 'hidden'
                                ? 'مخفية'
                                : 'مكتملة',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Trip details in modern layout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // Very light gray
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Departure time
                      Expanded(
                        child: _ModernInfoItem(
                          icon: Icons.access_time_rounded,
                          label: 'الانطلاق',
                          value:
                              '${dateFormat.format(trip.departureTime)}\n${timeFormat.format(trip.departureTime)}',
                          color: const Color(0xFF6366F1), // Indigo
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      // Price
                      Expanded(
                        child: _ModernInfoItem(
                          icon: Icons.attach_money_rounded,
                          label: 'السعر',
                          value: '${trip.price} ${trip.currency}',
                          color: const Color(0xFF10B981), // Emerald
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      // Seats
                      Expanded(
                        child: _ModernInfoItem(
                          icon: Icons.event_seat_rounded,
                          label: 'المقاعد',
                          value: '${trip.availableSeats}/${trip.totalSeats}',
                          color: const Color(0xFFF59E0B), // Amber
                        ),
                      ),
                    ],
                  ),
                ),

                // Warning for past trips
                if (isPast) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7), // Light yellow
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFFD97706), // Dark amber
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الرحلة في الماضي',
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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

class _ModernInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ModernInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon with circular background
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Value
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
