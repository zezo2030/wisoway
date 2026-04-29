import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/payment_service.dart';
import '../../core/api/api_client.dart';
import '../../core/ui/error_surface.dart';
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
                return _TripCard(trip: trip, onPaid: _refreshTrips);
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

class _TripCard extends StatefulWidget {
  final TripModel trip;
  final Future<void> Function() onPaid;

  const _TripCard({required this.trip, required this.onPaid});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  final PaymentService _paymentService = PaymentService();
  bool _isPaying = false;

  TripModel get trip => widget.trip;

  double get _tripFeeAmount => ((trip.price * trip.totalSeats * 0.05) * 100).round() / 100;

  Future<void> _showFeeInvoice() async {
    final amount = _tripFeeAmount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فاتورة رسوم الرحلة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _invoiceRow('سعر المقعد', '${trip.price} ${trip.currency}'),
            _invoiceRow('عدد المقاعد', '${trip.totalSeats}'),
            _invoiceRow('نسبة الرسوم', '5%'),
            const Divider(height: 24),
            _invoiceRow(
              'الإجمالي',
              '${amount.toStringAsFixed(2)} ${trip.currency}',
              isTotal: true,
            ),
            const SizedBox(height: 12),
            Text(
              'سيتم خصم الرسوم من محفظتك وفتح بيانات ركاب هذه الرحلة. لا يتم تغيير عدد المقاعد أو الحجوزات.',
              style: TextStyle(
                color: T.onSurfaceVariant(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('دفع الرسوم'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _payTripFee();
    }
  }

  Widget _invoiceRow(String label, String value, {bool isTotal = false}) {
    final style = TextStyle(
      fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
      fontSize: isTotal ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Future<void> _payTripFee() async {
    setState(() => _isPaying = true);
    try {
      await _paymentService.chargeDriverTrip(
        tripId: trip.id,
        idempotencyKey:
            'driver-trip-fee:${trip.id}:${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم دفع رسوم الرحلة بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      await widget.onPaid();
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');
    final isPast = trip.departureTime.isBefore(DateTime.now());

    Color getStatusColor() {
      switch (trip.status) {
        case 'active':
        case 'published':
          return AppColors.success;
        case 'fully_booked':
        case 'hidden':
          return AppColors.warning;
        case 'in_progress':
        case 'completed':
          return AppColors.info;
        case 'cancelled':
          return T.error(context);
        case 'draft':
        default:
          return T.onSurfaceVariant(context);
      }
    }

    String getStatusLabel() {
      switch (trip.status) {
        case 'active':
        case 'published':
          return 'نشطة';
        case 'draft':
          return 'مسودة';
        case 'fully_booked':
          return 'مكتملة الحجز';
        case 'in_progress':
          return 'قيد التنفيذ';
        case 'hidden':
          return 'مخفية';
        case 'completed':
          return 'مكتملة';
        case 'cancelled':
          return 'ملغاة';
        default:
          return 'غير معروف';
      }
    }

    IconData getStatusIcon() {
      switch (trip.status) {
        case 'active':
        case 'published':
          return Icons.circle;
        case 'hidden':
          return Icons.visibility_off;
        case 'cancelled':
          return Icons.cancel;
        case 'in_progress':
          return Icons.directions_car;
        default:
          return Icons.check_circle;
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
        color: AppColors.teal50,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: T.primary(context).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: AppColors.teal200,
          width: 1.7,
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
                              getStatusIcon(),
                              size: 10,
                              color: statusColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              getStatusLabel(),
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

                if (trip.communicationFeeStatus != 'paid')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isPaying ? null : _showFeeInvoice,
                        icon: _isPaying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(IconsaxPlusBold.receipt_2),
                        label: Text(
                          _isPaying ? 'جاري الدفع...' : 'دفع الرسوم',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (trip.communicationFeeStatus == 'paid')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          IconsaxPlusBold.tick_circle,
                          size: 18,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'رسوم الرحلة مدفوعة',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
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
