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
import '../../core/constants/route_names.dart';
import '../../core/theme/colors.dart';

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
  final Set<int> _selectedSeats = <int>{};
  bool _sharePhoneWithDriver = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final trip = await tripProvider.getTrip(widget.tripId);
      Map<String, dynamic>? preview;
      if (trip != null) {
        preview = await _tripService.getTripPricingPreview(trip.id);
        if (auth.userModel != null) {
          final existing = await _bookingService.getMyBookings();
          final already = existing.any(
            (b) =>
                b.tripId == trip.id &&
                b.status != 'cancelled',
          );
          if (already && mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'لديك حجز مسبق على هذه الرحلة. لا يُسمح إلا بحجز واحد لكل رحلة.',
                ),
                backgroundColor: AppColors.warning,
              ),
            );
            Navigator.of(context).pop();
            return;
          }
        }
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
      currentUserId: userModel.id,
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

    final next = Set<int>.from(_selectedSeats);
    if (next.contains(seatNumber)) {
      next.remove(seatNumber);
    } else {
      next.add(seatNumber);
    }
    if (next.isNotEmpty &&
        next.length > 1 &&
        !SeatValidation.isContiguousSeatGroup(_trip!, next)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يجب أن تكون المقاعد المختارة متجاورة (مجموعة واحدة متصلة).',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _selectedSeats
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _openBookingInvoice() async {
    if (_trip == null || _selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار مقعد واحد على الأقل'),
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

    final hasInvalidSelectedSeat = _selectedSeats.any(
      (seat) => !SeatValidation.canSelectSeat(
        trip: _trip!,
        seatNumber: seat,
        userGender: userModel.gender,
        currentUserId: userModel.id,
      ),
    );
    if (hasInvalidSelectedSeat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('أحد المقاعد المحددة لم يعد متاحاً. اختر مرة أخرى'),
          backgroundColor: T.error(context),
        ),
      );
      await _loadTrip();
      return;
    }

    if (_selectedSeats.length > 1 &&
        !SeatValidation.isContiguousSeatGroup(_trip!, _selectedSeats)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يجب أن تكون المقاعد متجاورة في مجموعة واحدة.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final backendSeatNumbers = _selectedSeats.toList()
      ..sort((a, b) => a.compareTo(b));
    final backendSeatIds = backendSeatNumbers
        .map((seat) => SeatLayoutHelpers.displayIndexToBackendSeatId(
              seat,
              _trip!.seatLayout,
            ))
        .toList();

    final bookingGroupId = await Navigator.pushNamed<String?>(
      context,
      RouteNames.passengerBookingInvoice,
      arguments: <String, dynamic>{
        'tripId': _trip!.id,
        'seatNumbers': backendSeatIds,
        'sharePhoneWithDriver': _sharePhoneWithDriver,
      },
    );

    if (!mounted) return;
    if (bookingGroupId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال طلب حجز ${backendSeatIds.length} مقعد. انتظر تأكيد السائق',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, bookingGroupId);
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
              selectedSeats: _selectedSeats,
              userGender: userModel.gender,
              currentUserId: userModel.id,
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
                          'بعد اختيار المقاعد ستفتح صفحة فاتورة؛ يُحجز المبلغ من المحفظة ثم يُثبت عند تأكيد السائق. إذا غادرت الرحلة دون تأكيد يُعاد المبلغ.',
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
            if (_selectedSeats.isNotEmpty)
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
                          'المقاعد المحددة: ${_selectedSeats.toList()..sort()}',
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
              label: 'مراجعة الفاتورة ثم الحجز',
              child: Tooltip(
                message: 'عرض تفاصيل الدفع ثم تأكيد الحجز',
                child: ElevatedButton(
                  onPressed:
                      _selectedSeats.isEmpty ? null : _openBookingInvoice,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(
                    _selectedSeats.isEmpty
                        ? 'مراجعة الفاتورة والحجز'
                        : 'مراجعة الفاتورة (${_selectedSeats.length}) مقعد',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
            if (_pricingPreview != null &&
                _pricingPreview!['passenger'] is Map &&
                _selectedSeats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final p = _pricingPreview!['passenger'] as Map;
                  final platform =
                      double.tryParse('${p['platformAmount'] ?? 0}') ?? 0;
                  final driver = double.tryParse('${p['driverAmount'] ?? 0}') ?? 0;
                  final count = _selectedSeats.length;
                  final platformTotal = platform * count;
                  final driverTotal = driver * count;
                  final total = platformTotal + driverTotal;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: T.primaryContainer(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملخص الدفع لـ $count مقعد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: T.onPrimaryContainer(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'للتطبيق: ${platformTotal.toStringAsFixed(2)} ${_trip!.currency}',
                        ),
                        Text(
                          'للسائق: ${driverTotal.toStringAsFixed(2)} ${_trip!.currency}',
                        ),
                        Text(
                          'الإجمالي: ${total.toStringAsFixed(2)} ${_trip!.currency}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
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
                      'بعد الفاتورة يُرسل طلب الحجز للسائق. تأكيده يثبت السحب من محفظتك.',
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
