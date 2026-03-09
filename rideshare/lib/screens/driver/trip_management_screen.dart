import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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
            backgroundColor: Colors.red,
          ),
        );
      }
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
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
          const SnackBar(
            content: Text('تم إخفاء الرحلة بنجاح'),
            backgroundColor: Colors.green,
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
        const SnackBar(
          content: Text('تم إظهار الرحلة بنجاح'),
          backgroundColor: Colors.green,
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
          const SnackBar(
            content: Text('تم حذف الرحلة بنجاح'),
            backgroundColor: Colors.green,
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
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Text(
            'إدارة الرحلة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Text(
            'إدارة الرحلة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(IconsaxPlusLinear.danger, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'الرحلة غير موجودة',
                style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey[600]),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          'إدارة الرحلة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: Colors.transparent,
              iconColor: Colors.black87,
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
            color: Colors.red,
          ),
        ],
      ),
      body: FutureBuilder<List<BookingModel>>(
        future: _bookingService.getTripBookings(widget.tripId),
        builder: (context, bookingsSnapshot) {
          final bookings = bookingsSnapshot.data ?? [];
          final pendingBookings = bookings.where((b) => b.isPending).toList();
          final confirmedBookings = bookings.where((b) => b.isConfirmed).toList();

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
            color: Colors.blue.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    IconsaxPlusBold.route_square,
                    color: Colors.white,
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
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
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
                color: Colors.white.withOpacity(0.15),
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
                      color: Colors.white,
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
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.from.name,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                color: Colors.white.withOpacity(0.7),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            // To Location
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
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
                      color: Colors.white,
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
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.to.name,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
      onTap: () => Navigator.pushNamed(context, RouteNames.driverWallet).then((_) => _loadWallet()),
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
              child: Icon(IconsaxPlusBold.wallet_3, color: Colors.orange.shade700, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رصيد المحفظة: ${w.balance.toStringAsFixed(0)} ${w.currency}',
                    style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    w.hasUsedLifetimeFreeTrip ? 'تم استخدام الرحلة المجانية' : 'رحلة مجانية متاحة',
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Icon(IconsaxPlusLinear.arrow_left_2, color: Colors.orange.shade700, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBookingsCard(List<BookingModel> pendingBookings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(IconsaxPlusBold.clock, color: Colors.amber.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'حجوزات قيد التأكيد (${pendingBookings.length})',
                style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'تأكيد الحجز يفتح بيانات الراكب (رحلة مجانية أو خصم من المحفظة مرة واحدة للرحلة)',
            style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ...pendingBookings.map((b) => _buildPendingBookingItem(b)),
        ],
      ),
    );
  }

  Widget _buildPendingBookingItem(BookingModel booking) {
    final isConfirming = _confirmingBookingId == booking.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(IconsaxPlusLinear.profile_2user, color: Colors.grey[600], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مقعد ${booking.seatNumber}', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                Text('بانتظار التأكيد', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isConfirming
                ? null
                : () => _confirmBooking(booking.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isConfirming
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('تأكيد الحجز', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
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
        const SnackBar(content: Text('تم تأكيد الحجز'), backgroundColor: Colors.green),
      );
      _loadTrip();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final insufficient = msg.contains('Insufficient') || msg.contains('wallet') || msg.contains('balance') || msg.contains('شحن');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(insufficient ? 'رصيد المحفظة غير كافٍ. يرجى شحن المحفظة ثم تأكيد الحجز.' : msg),
          backgroundColor: Colors.red,
          action: insufficient
              ? SnackBarAction(
                  label: 'شحن المحفظة',
                  textColor: Colors.white,
                  onPressed: () => Navigator.pushNamed(context, RouteNames.driverWallet),
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
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: IconsaxPlusBold.dollar_circle,
            label: 'الإيرادات',
            value: totalRevenue.toStringAsFixed(0),
            subtitle: trip.currency,
            color: Colors.green,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey[500]),
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
        statusColor = Colors.green;
        statusText = 'نشطة';
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      case 'hidden':
        statusColor = Colors.orange;
        statusText = 'مخفية';
        statusIcon = IconsaxPlusLinear.eye_slash;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'مكتملة';
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'غير معروف';
        statusIcon = IconsaxPlusLinear.info_circle;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: statusColor.withOpacity(0.1),
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
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
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
                  style: GoogleFonts.cairo(
                    fontSize: 12,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  IconsaxPlusLinear.info_circle,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'تفاصيل الرحلة',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(
            icon: IconsaxPlusBold.clock,
            label: 'وقت الانطلاق',
            value:
                '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
            color: Colors.orange,
          ),
          const Divider(height: 32),
          _buildDetailRow(
            icon: IconsaxPlusBold.dollar_circle,
            label: 'السعر لكل مقعد',
            value: '${trip.price} ${trip.currency}',
            color: Colors.green,
          ),
          const Divider(height: 32),
          _buildDetailRow(
            icon: IconsaxPlusBold.profile_2user,
            label: 'المقاعد',
            value: '${trip.availableSeats} متاح / ${trip.totalSeats} إجمالي',
            color: Colors.purple,
          ),
          const Divider(height: 32),
          _buildDetailRow(
            icon: IconsaxPlusLinear.grid_1,
            label: 'تخطيط المقاعد',
            value:
                '${trip.seatLayout.rows} صف × ${trip.seatLayout.seatsPerRow} مقعد',
            color: Colors.indigo,
          ),
          const Divider(height: 32),
          _buildDetailRow(
            icon: IconsaxPlusLinear.people,
            label: 'منع الاختلاط',
            value: trip.seatLayout.preventGenderMixing ? 'نعم' : 'لا',
            color: trip.seatLayout.preventGenderMixing
                ? Colors.red
                : Colors.grey,
          ),
        ],
      ),
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.cairo(fontSize: 15, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildSeatLayoutCard(TripModel trip) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  IconsaxPlusBold.profile_2user,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'تخطيط المقاعد',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Seat Layout Visualization
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        IconsaxPlusBold.car,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'مقعد السائق',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Seats grid
                ...List.generate(trip.seatLayout.rows, (rowIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(trip.seatLayout.seatsPerRow, (
                        seatIndex,
                      ) {
                        final seatNumber =
                            rowIndex * trip.seatLayout.seatsPerRow +
                            seatIndex +
                            1;
                        final seatKey = seatNumber.toString();
                        final matches = trip.seats.where(
                          (s) => s.seatNumber == seatKey,
                        );
                        final seatData = matches.isNotEmpty
                            ? matches.first
                            : SeatData.empty(seatKey);
                        final isBooked = seatData.isBooked;
                        final isMale = seatData.gender == 'male';
                        final isFemale = seatData.gender == 'female';

                        // Determine colors and icon based on seat status
                        Color seatColor;
                        Color borderColor;
                        Color iconColor;
                        IconData seatIcon;

                        if (!isBooked) {
                          // Empty seat
                          seatColor = Colors.green.shade100;
                          borderColor = Colors.green.shade300;
                          iconColor = Colors.green.shade700;
                          seatIcon = IconsaxPlusLinear.profile_2user;
                        } else if (isMale) {
                          // Booked by male
                          seatColor = Colors.blue.shade100;
                          borderColor = Colors.blue.shade300;
                          iconColor = Colors.blue.shade700;
                          seatIcon = IconsaxPlusBold.profile;
                        } else if (isFemale) {
                          // Booked by female
                          seatColor = Colors.pink.shade100;
                          borderColor = Colors.pink.shade300;
                          iconColor = Colors.pink.shade700;
                          seatIcon = IconsaxPlusBold.profile;
                        } else {
                          // Fallback (shouldn't happen)
                          seatColor = Colors.grey.shade100;
                          borderColor = Colors.grey.shade300;
                          iconColor = Colors.grey.shade700;
                          seatIcon = IconsaxPlusBold.profile;
                        }

                        return Container(
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
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: iconColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                // Legend
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem(Colors.green, 'متاح'),
                    _buildLegendItem(Colors.blue, 'محجوز - رجل'),
                    _buildLegendItem(Colors.pink, 'محجوز - أنثى'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildPassengersCard(List<BookingModel> bookings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  IconsaxPlusBold.profile_2user,
                  color: Colors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'الركاب (${bookings.length})',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...bookings.map((booking) => _buildPassengerItem(booking)),
        ],
      ),
    );
  }

  Widget _buildPassengerItem(BookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: booking.userPopulated?.gender == 'male'
                  ? Colors.blue.shade100
                  : Colors.pink.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              booking.userPopulated?.gender == 'male'
                  ? IconsaxPlusBold.profile
                  : IconsaxPlusBold.profile,
              color: booking.userPopulated?.gender == 'male'
                  ? Colors.blue.shade700
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
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: booking.hasDriverPaidToContact
                        ? Colors.black87
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      IconsaxPlusLinear.profile_2user,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'مقعد ${booking.seatNumber}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    // Show phone only if driver has paid AND passenger allows sharing
                    if (booking.hasDriverPaidToContact &&
                        booking.sharePhoneWithDriver) ...[
                      const SizedBox(width: 12),
                      Icon(
                        IconsaxPlusLinear.call,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        booking.userPopulated?.phoneNumber ?? '',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.grey[600],
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
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              'مؤكد',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarImageCard(TripModel trip) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  IconsaxPlusBold.car,
                  color: Colors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'صورة السيارة',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              trip.carImageUrl!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        IconsaxPlusLinear.danger,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'فشل تحميل الصورة',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(TripModel trip) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  IconsaxPlusLinear.setting_2,
                  color: Colors.indigo,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'إجراءات سريعة',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: IconsaxPlusLinear.share,
                  label: 'مشاركة',
                  color: Colors.blue,
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
                  color: Colors.orange,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: IconsaxPlusLinear.message,
                  label: 'المحادثة',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      RouteNames.driverChat,
                      arguments: {'tripId': widget.tripId, 'trip': _trip},
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
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
