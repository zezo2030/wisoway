import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/colors.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../models/booking_model.dart';
import '../../models/seat_data.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/constants/route_names.dart';
import '../../models/wallet_model.dart';
import '../../widgets/notification_icon_button.dart';
import '../../utils/seat_layout_helpers.dart';
import '../../../widgets/common/section_card.dart';

class TripManagementScreen extends StatefulWidget {
  final String tripId;

  const TripManagementScreen({super.key, required this.tripId});

  @override
  State<TripManagementScreen> createState() => _TripManagementScreenState();
}

class _TripManagementScreenState extends State<TripManagementScreen> {
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();
  TripModel? _trip;
  bool _isLoading = true;
  WalletModel? _wallet;
  String _confirmingBookingId = '';

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final trip = await tripProvider.getTrip(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _isLoading = false;
        });
        _loadWallet();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الرحلة: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _reloadTrip() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final trip = await tripProvider.getTrip(widget.tripId);
    if (!mounted) return;
    setState(() => _trip = trip);
  }

  Future<void> _onDriverSeatLongPress({
    required TripModel trip,
    required SeatData seatData,
    required String backendSeatId,
    required int displaySeatNumber,
  }) async {
    if (!trip.isActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('التعديل متاح للرحلات النشطة فقط'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (seatData.isBooked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المقاعد المحجوزة عبر التطبيق تُدار من طلبات الحجز'),
        ),
      );
      return;
    }

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    if (seatData.isLocked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('فتح المقعد'),
          content: Text(
            'إلغاء قفل المقعد رقم $displaySeatNumber ليصبح متاحاً للحجز في التطبيق؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('فتح المقعد'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      tripProvider.clearError();
      final success = await tripProvider.setSeatLock(
        trip.id,
        seatNumber: backendSeatId,
        locked: false,
      );
      if (!mounted) return;
      if (success) {
        await _reloadTrip();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم فتح المقعد'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tripProvider.errorMessage ?? 'فشل فتح المقعد'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('قفل المقعد'),
        content: Text(
          'قفل المقعد رقم $displaySeatNumber؟ لن يتمكن الركاب من حجزه في التطبيق (مثلاً إذا بيع خارج التطبيق).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('قفل'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    tripProvider.clearError();
    final success = await tripProvider.setSeatLock(
      trip.id,
      seatNumber: backendSeatId,
      locked: true,
    );
    if (!mounted) return;
    if (success) {
      await _reloadTrip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم قفل المقعد'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tripProvider.errorMessage ?? 'فشل قفل المقعد'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadWallet() async {
    try {
      final w = await _paymentService.getWalletMe();
      if (mounted) setState(() => _wallet = w);
    } catch (_) {}
  }

  Future<void> _hideTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إخفاء الرحلة'),
        content: const Text('هل أنت متأكد من إخفاء هذه الرحلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.white,
            ),
            child: const Text('إخفاء'),
          ),
        ],
      ),
    );

    if (confirmed == true && _trip != null) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final success = await tripProvider.hideTrip(_trip!.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إخفاء الرحلة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showTrip() async {
    if (_trip == null) return;

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final success = await tripProvider.showTrip(_trip!.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إظهار الرحلة بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTrip();
    }
  }

  Future<void> _deleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الرحلة'),
        content: const Text(
          'هل أنت متأكد من حذف هذه الرحلة؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && _trip != null) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final success = await tripProvider.deleteTrip(_trip!.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الرحلة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  int _getBookedSeatsCount() {
    if (_trip == null) return 0;
    return _trip!.seats.where((seat) => seat.isBooked).length;
  }

  double _getTotalRevenue() {
    if (_trip == null) return 0.0;
    return _getBookedSeatsCount() * _trip!.price;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.slate50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.white,
          foregroundColor: T.onSurface(context).withValues(alpha: 0.87),
          title: Text(
            'إدارة الرحلة',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        backgroundColor: AppColors.slate50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.white,
          foregroundColor: T.onSurface(context).withValues(alpha: 0.87),
          title: Text(
            'إدارة الرحلة',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                IconsaxPlusLinear.danger,
                size: 64,
                color: AppColors.slate300,
              ),
              const SizedBox(height: 16),
              Text(
                'الرحلة غير موجودة',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');
    final bookedSeats = _getBookedSeatsCount();
    final totalRevenue = _getTotalRevenue();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        foregroundColor: T.onSurface(context).withValues(alpha: 0.87),
        title: Text(
          'إدارة الرحلة',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: AppColors.transparent,
              iconColor: T.onSurface(context).withValues(alpha: 0.87),
            ),
          ),
          if (_trip!.isActive)
            IconButton(
              icon: const Icon(IconsaxPlusLinear.eye_slash),
              onPressed: _hideTrip,
              tooltip: 'إخفاء الرحلة',
            )
          else if (_trip!.isHidden)
            IconButton(
              icon: const Icon(IconsaxPlusLinear.eye),
              onPressed: _showTrip,
              tooltip: 'إظهار الرحلة',
            ),
          IconButton(
            icon: const Icon(IconsaxPlusLinear.trash),
            onPressed: _deleteTrip,
            tooltip: 'حذف الرحلة',
            color: AppColors.error,
          ),
        ],
      ),
      body: FutureBuilder<List<BookingModel>>(
        future: _bookingService.getTripBookings(widget.tripId),
        builder: (context, bookingsSnapshot) {
          final bookings = bookingsSnapshot.data ?? [];
          final pendingBookings = bookings.where((b) => b.isPending).toList();
          final confirmedBookings = bookings
              .where((b) => b.isConfirmed)
              .toList();

          return RefreshIndicator(
            onRefresh: _loadTrip,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card with Route
                  _buildHeaderCard(_trip!, dateFormat, timeFormat),
                  const SizedBox(height: 16),

                  // Statistics Cards
                  _buildStatisticsRow(_trip!, bookedSeats, totalRevenue),
                  const SizedBox(height: 16),

                  // Wallet summary (driver)
                  if (_wallet != null) ...[
                    _buildWalletCard(),
                    const SizedBox(height: 16),
                  ],

                  // Status Card
                  _buildStatusCard(_trip!),
                  const SizedBox(height: 16),

                  // Trip Details Card
                  _buildTripDetailsCard(_trip!, dateFormat, timeFormat),
                  const SizedBox(height: 16),

                  // Seat Layout Visualization
                  _buildSeatLayoutCard(_trip!),
                  const SizedBox(height: 16),

                  // Pending bookings (confirm to unlock passenger data / use free trip or wallet)
                  if (pendingBookings.isNotEmpty) ...[
                    _buildPendingBookingsCard(pendingBookings),
                    const SizedBox(height: 16),
                  ],

                  // Passengers List (confirmed)
                  if (confirmedBookings.isNotEmpty) ...[
                    _buildPassengersCard(confirmedBookings),
                    const SizedBox(height: 16),
                  ],

                  // Car Image
                  if (_trip!.carImageUrl != null) ...[
                    _buildCarImageCard(_trip!),
                    const SizedBox(height: 16),
                  ],

                  // Quick Actions
                  _buildQuickActionsCard(_trip!),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(
    TripModel trip,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    IconsaxPlusBold.route_square,
                    color: AppColors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات الرحلة',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 20,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // From Location
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      IconsaxPlusBold.location,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'من',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.from.name,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Icon(
                IconsaxPlusLinear.arrow_down_1,
                color: AppColors.white.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            // To Location
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      IconsaxPlusBold.location,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إلى',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.to.name,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    final w = _wallet!;
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        RouteNames.driverWallet,
      ).then((_) => _loadWallet()),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                IconsaxPlusBold.wallet_3,
                color: Colors.orange.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رصيد المحفظة: ${w.balance.toStringAsFixed(0)} ${w.currency}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    w.hasUsedLifetimeFreeTrip
                        ? 'تم استخدام الرحلة المجانية'
                        : 'رحلة مجانية متاحة',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_left_2,
              color: Colors.orange.shade700,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBookingsCard(List<BookingModel> pendingBookings) {
    return SectionCard(
      title: 'حجوزات قيد التأكيد (${pendingBookings.length})',
      icon: IconsaxPlusBold.clock,
      iconColor: AppColors.warning,
      children: [
        Text(
          'تأكيد الحجز يفتح بيانات الراكب (رحلة مجانية أو خصم من المحفظة مرة واحدة للرحلة)',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate400),
        ),
        const SizedBox(height: 16),
        ...pendingBookings.map((b) => _buildPendingBookingItem(b)),
      ],
    );
  }

  Widget _buildPendingBookingItem(BookingModel booking) {
    final isConfirming = _confirmingBookingId == booking.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Icon(
            IconsaxPlusLinear.profile_2user,
            color: AppColors.slate400,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مقعد ${booking.seatNumber}',
                  style: AppTextStyles.labelLarge,
                ),
                Text(
                  'بانتظار التأكيد',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isConfirming ? null : () => _confirmBooking(booking.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isConfirming
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'تأكيد الحجز',
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking(String bookingId) async {
    setState(() => _confirmingBookingId = bookingId);
    try {
      await _bookingService.confirmBooking(bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تأكيد الحجز'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTrip();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final insufficient =
          msg.contains('Insufficient') ||
          msg.contains('wallet') ||
          msg.contains('balance') ||
          msg.contains('شحن');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            insufficient
                ? 'رصيد المحفظة غير كافٍ. يرجى شحن المحفظة ثم تأكيد الحجز.'
                : msg,
          ),
          backgroundColor: AppColors.error,
          action: insufficient
              ? SnackBarAction(
                  label: 'شحن المحفظة',
                  textColor: AppColors.white,
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.driverWallet),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingBookingId = '');
    }
  }

  Widget _buildStatisticsRow(
    TripModel trip,
    int bookedSeats,
    double totalRevenue,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: IconsaxPlusBold.profile_2user,
            label: 'المقاعد المحجوزة',
            value: '$bookedSeats',
            subtitle: 'من ${trip.totalSeats}',
            color: T.primary(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: IconsaxPlusBold.dollar_circle,
            label: 'الإيرادات',
            value: totalRevenue.toStringAsFixed(0),
            subtitle: trip.currency,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate400),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(color: color),
          ),
          Text(
            subtitle,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(TripModel trip) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (trip.status) {
      case 'active':
        statusColor = AppColors.success;
        statusText = 'نشطة';
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      case 'hidden':
        statusColor = AppColors.warning;
        statusText = 'مخفية';
        statusIcon = IconsaxPlusLinear.eye_slash;
        break;
      case 'completed':
        statusColor = T.primary(context);
        statusText = 'مكتملة';
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      default:
        statusColor = T.outlineVariant(context);
        statusText = 'غير معروف';
        statusIcon = IconsaxPlusLinear.info_circle;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة الرحلة',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: AppTextStyles.titleMedium.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsCard(
    TripModel trip,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    return SectionCard(
      title: 'تفاصيل الرحلة',
      icon: IconsaxPlusLinear.info_circle,
      iconColor: T.primary(context),
      children: [
        if (trip.distanceKm != null) ...[
          _buildDetailRow(
            icon: IconsaxPlusBold.routing_2,
            label: 'مسافة الرحلة',
            value: '${trip.distanceKm!.toStringAsFixed(1)} كم',
            color: T.primary(context),
          ),
          const Divider(height: 32),
        ],
        _buildDetailRow(
          icon: IconsaxPlusBold.clock,
          label: 'وقت الانطلاق',
          value:
              '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
          color: AppColors.warning,
        ),
        const Divider(height: 32),
        _buildDetailRow(
          icon: IconsaxPlusBold.dollar_circle,
          label: 'السعر لكل مقعد',
          value: '${trip.price} ${trip.currency}',
          color: AppColors.success,
        ),
        const Divider(height: 32),
        _buildDetailRow(
          icon: IconsaxPlusBold.profile_2user,
          label: 'المقاعد',
          value: '${trip.availableSeats} متاح / ${trip.totalSeats} إجمالي',
          color: T.primary(context),
        ),
        const Divider(height: 32),
        _buildDetailRow(
          icon: IconsaxPlusLinear.grid_1,
          label: 'تخطيط المقاعد',
          value:
              trip.seatLayout.seatsPerRowList != null &&
                  trip.seatLayout.seatsPerRowList!.isNotEmpty
              ? 'مخصص: ${trip.seatLayout.seatsPerRowList!.join('، ')}'
              : '${trip.seatLayout.rows} صف × ${trip.seatLayout.seatsPerRow} مقعد',
          color: T.primary(context),
        ),
        const Divider(height: 32),
        _buildDetailRow(
          icon: IconsaxPlusLinear.people,
          label: 'منع الاختلاط',
          value: trip.seatLayout.preventGenderMixing ? 'نعم' : 'لا',
          color: trip.seatLayout.preventGenderMixing
              ? AppColors.error
              : T.outlineVariant(context),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 15,
              color: AppColors.slate500,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: T.onSurface(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSeatLayoutCard(TripModel trip) {
    return SectionCard(
      title: 'تخطيط المقاعد',
      icon: IconsaxPlusBold.profile_2user,
      iconColor: T.primary(context),
      children: [
        Text(
          'اضغط مطولاً على مقعد أخضر لقفله (حجز خارجي)، أو على مقعد مقفل لفتحه.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate400),
        ),
        const SizedBox(height: 20),
        // Seat Layout Visualization
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate200),
          ),
          child: Column(
            children: [
              // Driver seat indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.teal50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      IconsaxPlusBold.car,
                      size: 16,
                      color: T.primary(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'مقعد السائق',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.primary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Seats grid (irregular rows use same order as API + passenger UI)
              ..._driverSeatLayoutRows(trip),
              const SizedBox(height: 12),
              // Legend
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildLegendItem(AppColors.success, 'متاح'),
                  _buildLegendItem(Colors.amber.shade200, 'مقفل'),
                  _buildLegendItem(T.primary(context), 'محجوز - رجل'),
                  _buildLegendItem(Colors.pink, 'محجوز - أنثى'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _driverSeatLayoutRows(TripModel trip) {
    final rowConfigs = SeatLayoutHelpers.rowSeatCounts(trip.seatLayout);
    var displayIndex = 0;
    return rowConfigs.map((seatsInRow) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(seatsInRow, (_) {
            displayIndex++;
            final seatNumber = displayIndex;
            final backendId = SeatLayoutHelpers.displayIndexToBackendSeatId(
              seatNumber,
              trip.seatLayout,
            );
            final matches = trip.seats.where((s) => s.seatNumber == backendId);
            final seatData = matches.isNotEmpty
                ? matches.first
                : SeatData.empty(backendId);
            final isBooked = seatData.isBooked;
            final isLocked = seatData.isLocked;
            final isMale = seatData.gender == 'male';
            final isFemale = seatData.gender == 'female';

            Color seatColor;
            Color borderColor;
            Color iconColor;
            IconData seatIcon;

            if (isLocked) {
              seatColor = Colors.amber.shade100;
              borderColor = Colors.amber.shade400;
              iconColor = Colors.amber.shade900;
              seatIcon = IconsaxPlusBold.lock;
            } else if (!isBooked) {
              seatColor = AppColors.successLight.withValues(alpha: 0.2);
              borderColor = AppColors.successLight;
              iconColor = AppColors.success;
              seatIcon = IconsaxPlusLinear.profile_2user;
            } else if (isMale) {
              seatColor = T.primary(context).withValues(alpha: 0.1);
              borderColor = AppColors.teal300;
              iconColor = T.primary(context);
              seatIcon = IconsaxPlusBold.profile;
            } else if (isFemale) {
              seatColor = Colors.pink.shade100;
              borderColor = Colors.pink.shade300;
              iconColor = Colors.pink.shade700;
              seatIcon = IconsaxPlusBold.profile;
            } else {
              seatColor = AppColors.slate100;
              borderColor = AppColors.slate300;
              iconColor = AppColors.slate500;
              seatIcon = IconsaxPlusBold.profile;
            }

            return GestureDetector(
              onLongPress: () => _onDriverSeatLongPress(
                trip: trip,
                seatData: seatData,
                backendSeatId: backendId,
                displaySeatNumber: seatNumber,
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: seatColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(seatIcon, size: 20, color: iconColor),
                    const SizedBox(height: 2),
                    Text(
                      '$seatNumber',
                      style: AppTextStyles.overline.copyWith(
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      );
    }).toList();
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }

  Widget _buildPassengersCard(List<BookingModel> bookings) {
    return SectionCard(
      title: 'الركاب (${bookings.length})',
      icon: IconsaxPlusBold.profile_2user,
      iconColor: T.primary(context),
      children: [...bookings.map((booking) => _buildPassengerItem(booking))],
    );
  }

  Widget _buildPassengerItem(BookingModel booking) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        RouteNames.passengerDetails,
        arguments: booking,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: booking.userPopulated?.gender == 'male'
                    ? T.primary(context).withValues(alpha: 0.1)
                    : Colors.pink.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                booking.userPopulated?.gender == 'male'
                    ? IconsaxPlusBold.profile
                    : IconsaxPlusBold.profile,
                color: booking.userPopulated?.gender == 'male'
                    ? T.primary(context)
                    : Colors.pink.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show passenger name only if driver has paid to contact
                  Text(
                    booking.hasDriverPaidToContact
                        ? (booking.userPopulated?.name ?? 'راكب')
                        : 'راكب مجهول',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: booking.hasDriverPaidToContact
                          ? T.onSurface(context).withValues(alpha: 0.87)
                          : AppColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        IconsaxPlusLinear.profile_2user,
                        size: 14,
                        color: AppColors.slate400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'مقعد ${booking.seatNumber}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.slate400,
                        ),
                      ),
                      // Show phone only if driver has paid AND passenger allows sharing
                      if (booking.hasDriverPaidToContact &&
                          booking.sharePhoneWithDriver) ...[
                        const SizedBox(width: 12),
                        Icon(
                          IconsaxPlusLinear.call,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.userPopulated?.phoneNumber ?? '',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.slate400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.teal50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.successLight.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'مؤكد',
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarImageCard(TripModel trip) {
    return SectionCard(
      title: 'صورة السيارة',
      icon: IconsaxPlusBold.car,
      iconColor: T.primary(context),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: trip.carImageUrl!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      IconsaxPlusLinear.danger,
                      size: 48,
                      color: AppColors.slate300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'فشل تحميل الصورة',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard(TripModel trip) {
    return SectionCard(
      title: 'إجراءات سريعة',
      icon: IconsaxPlusLinear.setting_2,
      iconColor: T.primary(context),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: IconsaxPlusLinear.share,
                label: 'مشاركة',
                color: T.primary(context),
                onTap: () {
                  // TODO: Implement share functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('قريباً: ميزة المشاركة')),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: IconsaxPlusLinear.edit,
                label: 'تعديل',
                color: AppColors.warning,
                onTap: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    RouteNames.editTrip,
                    arguments: widget.tripId,
                  );
                  if (result == true) {
                    // Reload trip after successful edit
                    _loadTrip();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
