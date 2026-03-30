import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/trip_service.dart';
import '../../widgets/seat_layout_widget.dart';
import '../../utils/seat_layout_helpers.dart';
import '../../utils/seat_validation.dart';
import '../../core/theme/colors.dart';
import 'package:uuid/uuid.dart';

class SeatSelectionScreen extends StatefulWidget {
  final String tripId;

  const SeatSelectionScreen({super.key, required this.tripId});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final BookingService _bookingService = BookingService();
  final TripService _tripService = TripService();
  TripModel? _trip;
  Map<String, dynamic>? _pricingPreview;
  int? _selectedSeat;
  bool _sharePhoneWithDriver = true;
  bool _isLoading = true;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final trip = await tripProvider.getTrip(widget.tripId);
      Map<String, dynamic>? preview;
      if (trip != null) {
        preview = await _tripService.getTripPricingPreview(trip.id);
      }
      setState(() {
        _trip = trip;
        _pricingPreview = preview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الرحلة: ${e.toString()}'),
            backgroundColor: T.error(context),
          ),
        );
      }
    }
  }

  void _onSeatTap(int seatNumber) {
    if (_trip == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = authProvider.userModel;

    if (userModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يجب تسجيل الدخول'),
          backgroundColor: T.error(context),
        ),
      );
      return;
    }

    if (!SeatValidation.canSelectSeat(
      trip: _trip!,
      seatNumber: seatNumber,
      userGender: userModel.gender,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن اختيار هذا المقعد (قد يكون محجوزاً أو يوجد تعارض في الجنس)',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _selectedSeat = seatNumber;
    });
  }

  Future<void> _bookSeat() async {
    if (_trip == null || _selectedSeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار مقعد'),
          backgroundColor: T.error(context),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    final userModel = authProvider.userModel;

    if (user == null || userModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يجب تسجيل الدخول'),
          backgroundColor: T.error(context),
        ),
      );
      return;
    }

    if (_trip!.driverId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('لا يمكنك حجز مقعد في رحلتك الخاصة'),
          backgroundColor: T.error(context),
        ),
      );
      return;
    }

    if (!SeatValidation.canSelectSeat(
      trip: _trip!,
      seatNumber: _selectedSeat!,
      userGender: userModel.gender,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('المقعد لم يعد متاحاً. يرجى اختيار مقعد آخر'),
          backgroundColor: T.error(context),
        ),
      );
      await _loadTrip();
      return;
    }

    setState(() => _isBooking = true);

    final backendSeatNumber = SeatLayoutHelpers.displayIndexToBackendSeatId(
      _selectedSeat!,
      _trip!.seatLayout,
    );

    try {
      final passenger = _pricingPreview?['passenger'];
      final requiresOnline =
          passenger is Map && passenger['requiresOnlinePayment'] == true;

      final walletIdempotencyKey = requiresOnline ? const Uuid().v4() : null;

      final bookingId = await _bookingService.createBooking(
        tripId: _trip!.id,
        seatNumber: backendSeatNumber,
        sharePhoneWithDriver: _sharePhoneWithDriver,
        walletIdempotencyKey: walletIdempotencyKey,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الحجز بنجاح. انتظر تأكيد السائق'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, bookingId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحجز: ${e.toString()}'),
            backgroundColor: T.error(context),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('اختيار المقعد')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('اختيار المقعد')),
        body: const Center(child: Text('الرحلة غير موجودة')),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;

    if (userModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('اختيار المقعد')),
        body: const Center(child: Text('يجب تسجيل الدخول')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('اختيار المقعد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات الرحلة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('من: ${_trip!.from.name}'),
                    Text('إلى: ${_trip!.to.name}'),
                    Text('السعر: ${_trip!.price} ${_trip!.currency}'),
                    if (_pricingPreview != null) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      Builder(
                        builder: (context) {
                          final p = _pricingPreview!['passenger'];
                          if (p is! Map) return const SizedBox.shrink();
                          final platform = p['platformAmount'];
                          final driver = p['driverAmount'];
                          final online = p['requiresOnlinePayment'] == true;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                online
                                    ? 'للتطبيق (من المحفظة): $platform ${_trip!.currency}'
                                    : 'لا يوجد رسم منصة لهذه الرحلة',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (online)
                                Text(
                                  'للسائق (نقداً): $driver ${_trip!.currency}',
                                  style: TextStyle(
                                    color: T.onSurfaceVariant(context),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'اختر مقعدك',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SeatLayoutWidget(
              trip: _trip!,
              selectedSeat: _selectedSeat,
              userGender: userModel.gender,
              onSeatTap: _onSeatTap,
            ),
            const SizedBox(height: 24),
            Card(
              child: Semantics(
                label:
                    'مشاركة رقم الهاتف مع السائق: ${_sharePhoneWithDriver ? "مفعّل" : "معطّل"}',
                child: SwitchListTile(
                  title: const Text('مشاركة رقم الهاتف مع السائق'),
                  subtitle: const Text('السماح للسائق برؤية رقم هاتفك للتواصل'),
                  value: _sharePhoneWithDriver,
                  onChanged: (value) {
                    setState(() {
                      _sharePhoneWithDriver = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_pricingPreview != null &&
                _pricingPreview!['passenger'] is Map &&
                (_pricingPreview!['passenger']
                        as Map)['requiresOnlinePayment'] ==
                    true) ...[
              Card(
                color: T.primaryContainer(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: T.primary(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'سيتم خصم حصة التطبيق من محفظتك عند إرسال الحجز. تأكد من كفاية الرصيد من «محفظتي» في القائمة.',
                          style: TextStyle(
                            fontSize: 14,
                            color: T.onPrimaryContainer(context),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_selectedSeat != null)
              Card(
                color: AppColors.success.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.event_seat, color: AppColors.successDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'المقعد المحدد: $_selectedSeat',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'إرسال طلب الحجز',
              child: Tooltip(
                message: 'إرسال طلب حجز للمقعد المحدد',
                child: ElevatedButton(
                  onPressed: _isBooking || _selectedSeat == null
                      ? null
                      : _bookSeat,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isBooking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'إرسال طلب الحجز',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: T.primaryContainer(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: T.primary(context), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم إرسال طلب الحجز للسائق. انتظر تأكيده قبل أن يتم تأكيد الحجز.',
                      style: TextStyle(
                        fontSize: 12,
                        color: T.onPrimaryContainer(context),
                      ),
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
}
