import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_model.dart';
import '../../core/services/booking_service.dart';
import '../../widgets/seat_layout_widget.dart';
import '../../utils/seat_validation.dart';

class SeatSelectionScreen extends StatefulWidget {
  final String tripId;

  const SeatSelectionScreen({super.key, required this.tripId});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final BookingService _bookingService = BookingService();
  TripModel? _trip;
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
      setState(() {
        _trip = trip;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الرحلة: ${e.toString()}'),
            backgroundColor: Colors.red,
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
        const SnackBar(
          content: Text('يجب تسجيل الدخول'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if seat can be selected
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
          backgroundColor: Colors.orange,
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
        const SnackBar(
          content: Text('يرجى اختيار مقعد'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    final userModel = authProvider.userModel;

    if (user == null || userModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is trying to book their own trip
    if (_trip!.driverId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكنك حجز مقعد في رحلتك الخاصة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if seat is still available
    if (!SeatValidation.canSelectSeat(
      trip: _trip!,
      seatNumber: _selectedSeat!,
      userGender: userModel.gender,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المقعد لم يعد متاحاً. يرجى اختيار مقعد آخر'),
          backgroundColor: Colors.red,
        ),
      );
      await _loadTrip(); // Reload trip to get latest data
      return;
    }

    setState(() => _isBooking = true);

    // تحويل رقم المقعد (1-based) إلى تنسيق الباكند row-col (0-based)
    final seatsPerRow = _trip!.seatLayout.seatsPerRow;
    final row = (_selectedSeat! - 1) ~/ seatsPerRow;
    final col = (_selectedSeat! - 1) % seatsPerRow;
    final backendSeatNumber = '$row-$col';

    try {
      final bookingId = await _bookingService.createBooking(
        tripId: _trip!.id,
        seatNumber: backendSeatNumber,
        sharePhoneWithDriver: _sharePhoneWithDriver,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الحجز بنجاح. انتظر تأكيد السائق'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, bookingId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحجز: ${e.toString()}'),
            backgroundColor: Colors.red,
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
            // Trip Info Card
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Seat Layout
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
            // Share Phone Option
            Card(
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
            const SizedBox(height: 24),
            // Selected Seat Info
            if (_selectedSeat != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.event_seat, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'المقعد المحدد: $_selectedSeat',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // Book Button
            ElevatedButton(
              onPressed: _isBooking || _selectedSeat == null ? null : _bookSeat,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'إرسال طلب الحجز',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
            const SizedBox(height: 16),
            // Info Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم إرسال طلب الحجز للسائق. انتظر تأكيده قبل أن يتم تأكيد الحجز.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
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
