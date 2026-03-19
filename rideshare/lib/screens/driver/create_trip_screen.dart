import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/services/storage_service.dart';
import '../../models/location_model.dart';
import '../../models/seat_layout_config.dart';
import '../../widgets/location_picker_widget.dart';
import '../../core/services/vehicle_service.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _priceController = TextEditingController();

  final StorageService _storageService = StorageService();

  LocationModel? _fromLocation;
  LocationModel? _toLocation;
  DateTime? _departureTime;
  File? _carImage;
  int _rows = 2;
  int _seatsPerRow = 2;
  bool _preventGenderMixing = true;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadVehicleInfo();
  }

  Future<void> _loadVehicleInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    if (user != null) {
      final vehicleService = VehicleService();
      final vehicleInfo = await vehicleService.getMyVehicle();
      if (vehicleInfo != null && mounted) {
        setState(() {
          _rows = 2;
          _seatsPerRow = (vehicleInfo.seats) ~/ 2;
        });
      }
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _priceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickCarImage() async {
    final XFile? image = await _storageService.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _carImage = File(image.path));
    }
  }

  Future<void> _selectFromLocation() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          title: 'اختر نقطة الانطلاق',
          initialLocation: _fromLocation,
          onLocationSelected: (_) {},
        ),
      ),
    );
    if (location != null) {
      setState(() {
        _fromLocation = location;
        _fromController.text = location.name;
      });
    }
  }

  Future<void> _selectToLocation() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          title: 'اختر الوجهة',
          initialLocation: _toLocation,
          onLocationSelected: (_) {},
        ),
      ),
    );
    if (location != null) {
      setState(() {
        _toLocation = location;
        _toController.text = location.name;
      });
    }
  }

  Future<void> _selectDepartureTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF6C63FF),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
               colorScheme: ColorScheme.light(
              primary: const Color(0xFF6C63FF),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _departureTime = DateTime(
            picked.year, picked.month, picked.day, time.hour, time.minute,
          );
        });
      }
    }
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromLocation == null || _toLocation == null || _departureTime == null) {
      _showError('الرجاء إكمال بيانات المواقع والوقت');
      return;
    }
    if (_departureTime!.isBefore(DateTime.now())) {
      _showError('وقت الانطلاق يجب أن يكون في المستقبل');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final user = authProvider.userModel;

      if (user == null) throw Exception('المستخدم غير مسجل دخول');

      final seatLayout = SeatLayoutConfig(
        rows: _rows,
        seatsPerRow: _seatsPerRow,
        preventGenderMixing: _preventGenderMixing,
      );

      final tripId = await tripProvider.createTrip(
        from: _fromLocation!,
        to: _toLocation!,
        departureTime: _departureTime!,
        price: double.parse(_priceController.text.trim()),
        currency: 'EGP',
        seatLayout: seatLayout,
      );

      if (tripId != null && mounted) {
        _showSuccess('تم إنشاء الرحلة بنجاح');
        Navigator.pop(context, tripId);
      } else {
        throw Exception('فشل إنشاء الرحلة');
      }
    } catch (e) {
      if (mounted) _showError('خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.redAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: GoogleFonts.cairo(color: Colors.white))),
        ],
      ),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: GoogleFonts.cairo(color: Colors.white))),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    
    if (user != null && !user.canCreateTrips) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(IconsaxPlusBold.timer, size: 80, color: const Color(0xFF6C63FF)),
                const SizedBox(height: 24),
                Text(
                  'حسابك كسائق قيد المراجعة',
                  style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً تصفح الرحلات والحجز كراكب.',
                  style: GoogleFonts.cairo(fontSize: 15, color: Colors.black54, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text('العودة للرئيسية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C63FF),
        elevation: 0,
        centerTitle: true,
        title: Text('إنشاء رحلة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildHeaderIllustration(),
                      const SizedBox(height: 30),
                      _buildLocationsCard(),
                      const SizedBox(height: 20),
                      _buildDetailsCard(),
                      const SizedBox(height: 20),
                      _buildSeatingCard(),
                      const SizedBox(height: 20),
                      _buildCarImageCard(),
                      const SizedBox(height: 40),
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildHeaderIllustration() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(IconsaxPlusBold.car, color: Color(0xFF6C63FF), size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            'شارك رحلتك القادمة',
            style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF2D3142)),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بتحديد وجهتك ووقت الانطلاق لتبدأ مشاركة رحلتك مع الركاب.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF9098B1), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مسار الرحلة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142))),
          const SizedBox(height: 20),
          Stack(
            children: [
              Positioned(
                left: 23,
                top: 30,
                bottom: 30,
                child: Container(
                  width: 2,
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
              Column(
                children: [
                  _buildInteractiveField(
                    controller: _fromController,
                    hint: 'أين أنت الآن؟',
                    icon: Icons.my_location_rounded,
                    iconColor: const Color(0xFF6C63FF),
                    onTap: _selectFromLocation,
                  ),
                  const SizedBox(height: 16),
                  _buildInteractiveField(
                    controller: _toController,
                    hint: 'أين وجهتك؟',
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFF00C9A7),
                    onTap: _selectToLocation,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تفاصيل الانطلاق والسعر', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142))),
          const SizedBox(height: 20),
          _buildInteractiveField(
            controller: TextEditingController(
              text: _departureTime != null ? DateFormat('yyyy-MM-dd hh:mm a').format(_departureTime!) : '',
            ),
            hint: 'وقت الانطلاق',
            icon: IconsaxPlusBroken.calendar_1,
            iconColor: const Color(0xFFFFA726),
            onTap: _selectDepartureTime,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'السعر لكل مقعد',
              hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
              prefixIcon: const Icon(IconsaxPlusBroken.wallet_1, color: Color(0xFF2D3142)),
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Text('EGP', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'أدخل السعر';
              if (double.tryParse(v) == null) return 'أدخل رقماً صحيحاً';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeatingCard() {
    int totalSeats = _rows * _seatsPerRow;
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('إعدادات المقاعد', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('$totalSeats مقعد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFF6C63FF))),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildCounter(
                  label: 'الصفوف',
                  value: _rows,
                  icon: IconsaxPlusBroken.row_vertical,
                  onDecrease: _rows > 1 ? () => setState(() => _rows--) : null,
                  onIncrease: _rows < 10 ? () => setState(() => _rows++) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCounter(
                  label: 'بكل صف',
                  value: _seatsPerRow,
                  icon: Icons.airline_seat_recline_normal_rounded,
                  onDecrease: _seatsPerRow > 1 ? () => setState(() => _seatsPerRow--) : null,
                  onIncrease: _seatsPerRow < 10 ? () => setState(() => _seatsPerRow++) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFB8500).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.people_outline, color: Color(0xFFFB8500), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('منع الاختلاط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Switch(
                  value: _preventGenderMixing,
                  activeColor: const Color(0xFF6C63FF),
                  onChanged: (v) => setState(() => _preventGenderMixing = v),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCarImageCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('صورة السيارة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D3142))),
              Text('اختياري', style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickCarImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _carImage != null ? const Color(0xFF6C63FF) : Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                image: _carImage != null ? DecorationImage(image: FileImage(_carImage!), fit: BoxFit.cover) : null,
              ),
              child: _carImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(IconsaxPlusBroken.camera, color: Color(0xFF6C63FF), size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text('انقر لإضافة صورة لسيارتك', style: GoogleFonts.cairo(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      ],
                    )
                  : Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF6C63FF),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: _isLoading ? null : _createTrip,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text('تأكيد ونشر الرحلة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInteractiveField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                controller.text.isEmpty ? hint : controller.text,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: controller.text.isEmpty ? FontWeight.normal : FontWeight.w600,
                  color: controller.text.isEmpty ? Colors.grey.shade500 : const Color(0xFF2D3142),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter({
    required String label,
    required int value,
    required IconData icon,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onDecrease,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: onDecrease == null ? Colors.grey.shade100 : Colors.white, border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle),
                  child: Icon(Icons.remove, size: 16, color: onDecrease == null ? Colors.grey.shade400 : const Color(0xFF2D3142)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$value', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              GestureDetector(
                onTap: onIncrease,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: onIncrease == null ? Colors.grey.shade100 : Colors.white, border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle),
                  child: Icon(Icons.add, size: 16, color: onIncrease == null ? Colors.grey.shade400 : const Color(0xFF2D3142)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
