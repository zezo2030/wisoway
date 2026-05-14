import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/phone_text.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../models/booking_model.dart';
import '../../models/seat_data.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/constants/route_names.dart';
import '../../models/wallet_model.dart';
import '../../models/wallet_account_model.dart';
import '../../widgets/notification_icon_button.dart';
import '../../utils/seat_layout_helpers.dart';
import '../../../widgets/common/section_card.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../core/errors/failure.dart';
import '../../core/services/location_service.dart';
import '../../core/api/websocket_service.dart';
import '../../core/services/trip_service.dart';

class TripManagementScreen extends StatefulWidget {
  final String tripId;

  const TripManagementScreen({super.key, required this.tripId});

  @override
  State<TripManagementScreen> createState() => _TripManagementScreenState();
}

class _TripManagementScreenState extends State<TripManagementScreen> {
  final BookingService _bookingService = BookingService();
  final TripService _tripService = TripService();
  final PaymentService _paymentService = PaymentService();
  final LocationService _locationService = LocationService();
  final WebSocketService _webSocketService = WebSocketService();
  TripModel? _trip;
  bool _isLoading = true;
  WalletModel? _wallet;
  /// Postgres ledger (`/wallet/me`); real balance used for trip charges.
  WalletAccountModel? _walletAccount;
  String _confirmingBookingId = '';
  String _rejectingBookingId = '';
  bool _isPayingTripFee = false;
  Timer? _locationTrackingTimer;
  bool _locationDialogOpen = false;
  bool _markingArrived = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    _locationTrackingTimer?.cancel();
    super.dispose();
  }

  void _syncLiveTrackingState() {
    final trip = _trip;
    if (trip == null) {
      _locationTrackingTimer?.cancel();
      _locationTrackingTimer = null;
      return;
    }

    final isInProgress = trip.status == 'in_progress';
    if (!isInProgress) {
      _locationTrackingTimer?.cancel();
      _locationTrackingTimer = null;
      return;
    }

    _webSocketService.connect();
    _webSocketService.subscribeToTripTracking(trip.id);

    if (_locationTrackingTimer != null) {
      return;
    }

    _pushDriverLocationTick();
    _locationTrackingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pushDriverLocationTick(),
    );
  }

  Future<void> _pushDriverLocationTick() async {
    final trip = _trip;
    if (!mounted || trip == null || trip.status != 'in_progress') {
      return;
    }

    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showEnableLocationDialog();
      return;
    }

    try {
      final position = await _locationService.getCurrentPosition();
      _webSocketService.updateDriverLocation(
        tripId: trip.id,
        latitude: position.latitude,
        longitude: position.longitude,
        speedKph: position.speed > 0 ? position.speed * 3.6 : null,
        heading: position.heading,
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      await _showEnableLocationDialog();
    }
  }

  Future<void> _showEnableLocationDialog() async {
    if (!mounted || _locationDialogOpen) return;
    _locationDialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تفعيل الموقع مطلوب'),
        content: const Text(
          'لا يمكن متابعة الرحلة بدون تشغيل خدمات الموقع. يرجى تفعيل GPS الآن.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _locationService.openLocationSettings();
            },
            child: const Text('فتح إعدادات الموقع'),
          ),
          FilledButton(
            onPressed: () async {
              final enabled = await _locationService.isLocationServiceEnabled();
              if (!ctx.mounted) return;
              if (enabled) {
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('تحقق مجددًا'),
          ),
        ],
      ),
    );

    _locationDialogOpen = false;
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
        _syncLiveTrackingState();
        _loadWallet();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    }
  }

  Future<void> _reloadTrip() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final trip = await tripProvider.getTrip(widget.tripId);
    if (!mounted) return;
    setState(() => _trip = trip);
    _syncLiveTrackingState();
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
        ErrorSurface.showFailure(
          context,
          const Failure(
            category: FailureCategory.validation,
            messageKey: 'errorsValidationGeneric',
            severity: FailureSeverity.warning,
            developerDetail: 'Failed to open seat',
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
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Failed to lock seat',
        ),
      );
    }
  }

  Future<void> _loadWallet() async {
    try {
      final w = await _paymentService.getWalletMe();
      if (mounted) setState(() => _wallet = w);
    } catch (_) {}

    try {
      final acc = await _paymentService.getWalletAccountMe();
      if (mounted) setState(() => _walletAccount = acc);
    } catch (_) {}
  }

  /// `/wallet/me` (ledger) first; fallback to legacy `users.walletBalance` from `/payments/wallet/me`.
  double get _walletDisplayBalance =>
      _walletAccount?.balance ?? _wallet?.balance ?? 0;

  String get _walletDisplayCurrency =>
      _walletAccount?.currency ?? _wallet?.currency ?? 'JOD';

  bool get _hasWalletSummary =>
      _wallet != null || _walletAccount != null;

  double _baseTripFeeAmount(TripModel trip) {
    return ((trip.price * trip.totalSeats * 0.05) * 100).round() / 100;
  }

  bool get _hasAvailableFreeTrip =>
      _wallet != null && !_wallet!.hasUsedLifetimeFreeTrip;

  double _tripFeeAmount(TripModel trip) {
    if (_hasAvailableFreeTrip) return 0;
    return _baseTripFeeAmount(trip);
  }

  Future<void> _showTripFeeInvoice(TripModel trip) async {
    final baseAmount = _baseTripFeeAmount(trip);
    final hasFreeTrip = _hasAvailableFreeTrip;
    final amount = _tripFeeAmount(trip);
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
            if (hasFreeTrip)
              _invoiceRow(
                'خصم الرحلة المجانية',
                '-${baseAmount.toStringAsFixed(2)} ${trip.currency} (100%)',
              ),
            const Divider(height: 24),
            _invoiceRow(
              'الإجمالي',
              '${amount.toStringAsFixed(2)} ${trip.currency}',
              isTotal: true,
            ),
            const SizedBox(height: 12),
            Text(
              hasFreeTrip
                  ? 'لديك رحلة مجانية متاحة. سيتم تطبيق خصم 100% ليصبح الإجمالي 0.'
                  : 'الدفع يخص رسوم الرحلة كاملة ولا يغير عدد المقاعد أو الحجوزات.',
              style: AppTextStyles.bodySmall.copyWith(
                color: T.textSecondary(context),
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
      await _payTripFee(trip);
    }
  }

  Widget _invoiceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payTripFee(TripModel trip) async {
    setState(() => _isPayingTripFee = true);
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
      await _loadTrip();
      await _loadWallet();
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _isPayingTripFee = false);
    }
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
        backgroundColor: T.background(context),
        appBar: AppBar(
          elevation: 0,
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
        backgroundColor: T.background(context),
        appBar: AppBar(
          elevation: 0,
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
                color: T.outlineVariant(context),
              ),
              const SizedBox(height: 16),
              Text(
                'الرحلة غير موجودة',
                style: AppTextStyles.titleMedium.copyWith(
                  color: T.textSecondary(context),
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
      backgroundColor: T.background(context),
      appBar: AppBar(
        elevation: 0,
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
                  if (_hasWalletSummary) ...[
                    _buildWalletCard(),
                    const SizedBox(height: 16),
                  ],

                  // Status Card
                  _buildStatusCard(_trip!),
                  const SizedBox(height: 16),

                  _buildArrivedCard(_trip!),
                  const SizedBox(height: 16),

                  // Trip fee payment
                  _buildTripFeePaymentCard(_trip!),
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
          colors: [
            T.primary(context),
            T.primary(context).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: T.primary(context).withValues(alpha: 0.3),
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
                    color: T.onPrimary(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    IconsaxPlusBold.route_square,
                    color: T.onPrimary(context),
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
                          color: T.onPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: T.onPrimary(context).withValues(alpha: 0.9),
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
                color: T.onPrimary(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: T.success(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconsaxPlusBold.location,
                      color: T.onPrimary(context),
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
                            color: T.onPrimary(context).withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.from.name,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: T.onPrimary(context),
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
                color: T.onPrimary(context).withValues(alpha: 0.7),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            // To Location
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: T.onPrimary(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: T.error(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconsaxPlusBold.location,
                      color: T.onPrimary(context),
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
                            color: T.onPrimary(context).withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.to.name,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: T.onPrimary(context),
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
    final balance = _walletDisplayBalance;
    final cur = _walletDisplayCurrency;
    final freeTripUsed = _wallet?.hasUsedLifetimeFreeTrip ?? false;
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        RouteNames.driverWallet,
      ).then((_) => _loadWallet()),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.primaryContainer(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.primary(context).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                IconsaxPlusBold.wallet_3,
                color: T.primary(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رصيد المحفظة: ${balance.toStringAsFixed(2)} $cur',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_wallet != null)
                    Text(
                      freeTripUsed
                          ? 'تم استخدام الرحلة المجانية'
                          : 'رحلة مجانية متاحة',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.textSecondary(context),
                      ),
                    )
                  else
                    Text(
                      'الرصيد من محفظة المنصة (المحفظة الموحدة)',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_left_2,
              color: T.primary(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripFeePaymentCard(TripModel trip) {
    final isPaid = trip.communicationFeeStatus == 'paid';
    final hasFreeTrip = _hasAvailableFreeTrip;
    final amount = _tripFeeAmount(trip);
    return SectionCard(
      title: 'رسوم الرحلة',
      icon: Icons.receipt_long_outlined,
      iconColor: isPaid ? AppColors.success : AppColors.warning,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isPaid ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPaid ? IconsaxPlusBold.tick_circle : IconsaxPlusBold.wallet_1,
                color: isPaid ? AppColors.success : AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaid ? 'رسوم الرحلة مدفوعة' : 'فاتورة رسوم الرحلة جاهزة',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFreeTrip
                        ? 'الرسوم: 5% × ${trip.totalSeats} مقاعد × ${trip.price} ${trip.currency}، خصم رحلة مجانية 100% = ${amount.toStringAsFixed(2)} ${trip.currency}'
                        : '5% × ${trip.totalSeats} مقاعد × ${trip.price} ${trip.currency} = ${amount.toStringAsFixed(2)} ${trip.currency}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: T.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isPaid) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPayingTripFee
                  ? null
                  : () => _showTripFeeInvoice(trip),
              icon: _isPayingTripFee
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(IconsaxPlusBold.wallet_1),
              label: Text(
                _isPayingTripFee
                    ? 'جاري الدفع...'
                    : hasFreeTrip
                    ? 'تطبيق الرحلة المجانية'
                    : 'دفع الرسوم',
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
        ],
      ],
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
          style: AppTextStyles.bodySmall.copyWith(
            color: T.textSecondary(context),
          ),
        ),
        const SizedBox(height: 16),
        ...pendingBookings.map((b) => _buildPendingBookingItem(b)),
      ],
    );
  }

  Widget _buildPendingBookingItem(BookingModel booking) {
    final isConfirming = _confirmingBookingId == booking.id;
    final isRejecting = _rejectingBookingId == booking.id;
    final seatText = booking.seatSummary.isNotEmpty ? booking.seatSummary : '-';
    final canOpenPassengerDetails =
        booking.hasDriverPaidToContact && booking.userPopulated != null;
    final titleText = canOpenPassengerDetails
        ? (booking.userPopulated?.name ?? 'راكب')
        : 'مقعد $seatText';
    final subtitleText = canOpenPassengerDetails
        ? 'المحادثة والتواصل متاحان بعد دفع رسوم الرحلة'
        : 'بانتظار التأكيد';

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.slate200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        IconsaxPlusLinear.profile_2user,
                        color: AppColors.slate500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المقاعد: $seatText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: T.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        'قيد التأكيد',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.warningDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  subtitleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: T.textSecondary(context),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canOpenPassengerDetails)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          RouteNames.passengerDetails,
                          arguments: booking,
                        ),
                        icon: const Icon(IconsaxPlusLinear.user, size: 16),
                        label: Text(
                          'تفاصيل الراكب',
                          style: AppTextStyles.labelLarge.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: T.primary(context),
                          side: BorderSide(color: T.primary(context)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: (isConfirming || isRejecting)
                          ? null
                          : () => _confirmBooking(booking.id),
                      icon: isConfirming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(IconsaxPlusBold.tick_circle, size: 16),
                      label: Text(
                        isConfirming ? 'جاري التأكيد...' : 'تأكيد الحجز',
                        style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: (isConfirming || isRejecting)
                          ? null
                          : () => _rejectBooking(booking.id),
                      icon: isRejecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(IconsaxPlusBold.close_circle, size: 16),
                      label: Text(
                        isRejecting ? 'جاري الرفض...' : 'رفض',
                        style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }

  Future<void> _confirmBooking(String bookingId) async {
    setState(() => _confirmingBookingId = bookingId);
    try {
      await _bookingService.acceptBooking(bookingId);
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
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _confirmingBookingId = '');
    }
  }

  Future<void> _rejectBooking(String bookingId) async {
    setState(() => _rejectingBookingId = bookingId);
    try {
      await _bookingService.rejectBooking(bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم رفض الحجز'),
          backgroundColor: AppColors.error,
        ),
      );
      _loadTrip();
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _rejectingBookingId = '');
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
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.08),
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
            style: AppTextStyles.bodySmall.copyWith(
              color: T.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(color: color),
          ),
          Text(
            subtitle,
            style: AppTextStyles.labelSmall.copyWith(
              color: T.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onPressArrived(TripModel trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الوصول'),
        content: const Text(
          'هل وصلت إلى الوجهة؟ سيتم إنهاء الرحلة ولن يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('نعم، وصلت'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _markingArrived = true);
    try {
      await _tripService.markTripArrived(trip.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنهاء الرحلة بنجاح.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _reloadTrip();
    } catch (e) {
      if (!mounted) return;
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _markingArrived = false);
    }
  }

  /// Shown while the trip is IN_PROGRESS. The trip transitions to IN_PROGRESS
  /// automatically at departureTime — there is no manual "Start" button.
  Widget _buildArrivedCard(TripModel trip) {
    final s = trip.status;
    if (s == 'completed' || s == 'cancelled') {
      return const SizedBox.shrink();
    }

    if (s == 'draft' || s == 'hidden') {
      return const SizedBox.shrink();
    }

    if (s != 'in_progress') {
      // Trip will auto-start at departureTime. Show a small status hint while
      // the trip is still PUBLISHED/FULLY_BOOKED so drivers know what to expect.
      final now = DateTime.now();
      final departure = trip.departureTime;
      String body;
      if (now.isBefore(departure)) {
        final minutes = departure.difference(now).inMinutes;
        if (minutes >= 60) {
          final hours = (minutes / 60).floor();
          body =
              'ستبدأ الرحلة تلقائياً عند موعد الانطلاق (بعد ~$hours ساعة). لا حاجة للضغط على زر بدء.';
        } else {
          body =
              'ستبدأ الرحلة تلقائياً عند موعد الانطلاق (بعد ~${minutes.clamp(0, 9999)} دقيقة). لا حاجة للضغط على زر بدء.';
        }
      } else {
        body = 'سيتم تحويل الرحلة إلى «قيد التنفيذ» تلقائياً خلال لحظات.';
      }
      return SectionCard(
        title: 'بدء الرحلة',
        icon: IconsaxPlusLinear.clock,
        iconColor: T.primary(context),
        children: [
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.textSecondary(context),
            ),
          ),
        ],
      );
    }

    return SectionCard(
      title: 'إنهاء الرحلة',
      icon: IconsaxPlusBold.tick_circle,
      iconColor: AppColors.success,
      children: [
        Text(
          'اضغط «تم الوصول للوجهة» بعد إنزال الركاب لإنهاء الرحلة.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: T.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                _markingArrived ? null : () => _onPressArrived(trip),
            icon: _markingArrived
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(IconsaxPlusBold.tick_circle),
            label: Text(
              _markingArrived ? 'جاري الإنهاء...' : 'تم الوصول للوجهة',
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
      ],
    );
  }

  Widget _buildStatusCard(TripModel trip) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (trip.status) {
      case 'active':
      case 'published':
        statusColor = AppColors.success;
        statusText = 'نشطة';
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      case 'draft':
        statusColor = T.outlineVariant(context);
        statusText = 'مسودة';
        statusIcon = IconsaxPlusLinear.edit;
        break;
      case 'fully_booked':
        statusColor = AppColors.warning;
        statusText = 'مكتملة الحجز';
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      case 'in_progress':
        statusColor = T.primary(context);
        statusText = 'قيد التنفيذ';
        statusIcon = IconsaxPlusLinear.routing;
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
      case 'cancelled':
        statusColor = T.error(context);
        statusText = 'ملغاة';
        statusIcon = IconsaxPlusLinear.close_circle;
        break;
      default:
        statusColor = T.outlineVariant(context);
        statusText = 'غير معروف';
        statusIcon = IconsaxPlusLinear.info_circle;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.08),
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
                    color: T.textSecondary(context),
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
          value: SeatLayoutHelpers.formatTripSeatLayoutPattern(
            trip.seatLayout,
            trip.seats,
            trip.totalSeats,
          ),
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
              color: T.textSecondary(context),
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
          style: AppTextStyles.bodySmall.copyWith(
            color: T.textSecondary(context),
          ),
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
                  color: T.primaryContainer(context),
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
                  _buildLegendItem(T.secondary(context), 'مقفل'),
                  _buildLegendItem(T.primary(context), 'محجوز - رجل'),
                  _buildLegendItem(T.accentPink(context), 'محجوز - أنثى'),
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
              seatColor = T.secondary(context).withValues(alpha: 0.15);
              borderColor = T.secondary(context).withValues(alpha: 0.5);
              iconColor = T.secondary(context);
              seatIcon = IconsaxPlusBold.lock;
            } else if (!isBooked) {
              seatColor = AppColors.successLight.withValues(alpha: 0.2);
              borderColor = AppColors.successLight;
              iconColor = AppColors.success;
              seatIcon = IconsaxPlusLinear.profile_2user;
            } else if (isMale) {
              seatColor = T.primary(context).withValues(alpha: 0.1);
              borderColor = T.primary(context).withValues(alpha: 0.4);
              iconColor = T.primary(context);
              seatIcon = IconsaxPlusBold.profile;
            } else if (isFemale) {
              seatColor = T.accentPink(context).withValues(alpha: 0.1);
              borderColor = T.accentPink(context).withValues(alpha: 0.4);
              iconColor = T.accentPink(context);
              seatIcon = IconsaxPlusBold.profile;
            } else {
              seatColor = T.surfaceVariant(context);
              borderColor = T.outlineVariant(context);
              iconColor = T.textSecondary(context);
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
    final seatText = booking.seatSummary.isNotEmpty ? booking.seatSummary : '-';

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
          color: T.surfaceVariant(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.outline(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: booking.userPopulated?.gender == 'male'
                    ? T.primary(context).withValues(alpha: 0.1)
                    : T.accentPink(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusBold.profile,
                color: booking.userPopulated?.gender == 'male'
                    ? T.primary(context)
                    : T.accentPink(context),
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
                          : T.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        IconsaxPlusLinear.profile_2user,
                        size: 14,
                        color: T.textSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'مقعد $seatText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: T.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (booking.hasDriverPaidToContact &&
                      booking.sharePhoneWithDriver) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          IconsaxPlusLinear.call,
                          size: 14,
                          color: T.textSecondary(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: PhoneText(
                            booking.userPopulated?.phoneNumber ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: T.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: T.success(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: T.success(context).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'مؤكد',
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.success(context),
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
                  color: T.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      IconsaxPlusLinear.danger,
                      size: 48,
                      color: T.outlineVariant(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'فشل تحميل الصورة',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: T.textSecondary(context),
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
      color: AppColors.transparent,
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
