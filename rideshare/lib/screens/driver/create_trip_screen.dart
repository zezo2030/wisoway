import 'dart:io';
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

class _CreateTripScreenState extends State<CreateTripScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadVehicleInfo();
  }

  Future<void> _loadVehicleInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;
    if (user != null) {
      final vehicleService = VehicleService();
      final vehicleInfo = await vehicleService.getMyVehicle();
      if (vehicleInfo != null) {
        setState(() {
          _rows = 2; // Default
          _seatsPerRow = (vehicleInfo.seats) ~/ 2; // Use vehicle seats
        });
      }
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickCarImage() async {
    final XFile? image = await _storageService.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      setState(() {
        _carImage = File(image.path);
      });
    }
  }

  Future<void> _selectFromLocation() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          title: 'اختر نقطة الانطلاق',
          initialLocation: _fromLocation,
          onLocationSelected: (location) {
            // Location will be returned via Navigator.pop in _confirmSelection
          },
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
          onLocationSelected: (location) {
            // Location will be returned via Navigator.pop in _confirmSelection
          },
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
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _departureTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نقطة الانطلاق'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_toLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الوجهة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار وقت الانطلاق'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_departureTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('وقت الانطلاق يجب أن يكون في المستقبل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      final user = authProvider.userModel;
      final userModel = authProvider.userModel;

      if (user == null || userModel == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // Use locations directly (they already have coordinates from map picker)
      final fromLocation = _fromLocation!;
      final toLocation = _toLocation!;

      // Create seat layout
      final seatLayout = SeatLayoutConfig(
        rows: _rows,
        seatsPerRow: _seatsPerRow,
        preventGenderMixing: _preventGenderMixing,
      );

      // Create trip
      final tripId = await tripProvider.createTrip(
        from: fromLocation,
        to: toLocation,
        departureTime: _departureTime!,
        price: double.parse(_priceController.text.trim()),
        currency: 'EGP', // TODO: Get from user settings
        seatLayout: seatLayout,
      );

      if (tripId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الرحلة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, tripId);
      } else {
        throw Exception('فشل إنشاء الرحلة');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    if (user != null && !user.canCreateTrips) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Text(
            'إنشاء رحلة',
            style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(IconsaxPlusBold.timer, size: 64, color: Colors.orange.shade700),
                const SizedBox(height: 24),
                Text(
                  'حسابك كسائق قيد المراجعة',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً تصفح الرحلات والحجز كراكب.',
                  style: GoogleFonts.cairo(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('رجوع'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalSeats = _rows * _seatsPerRow;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          'إنشاء رحلة جديدة',
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_road,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ابدأ رحلتك الجديدة',
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'شارك رحلتك مع الآخرين',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Trip Details Card
                _buildSectionCard(
                  title: 'تفاصيل الرحلة',
                  icon: Icons.route,
                  color: Colors.blue,
                  children: [
                    const SizedBox(height: 8),
                    // From Location
                    _buildModernTextField(
                      controller: _fromController,
                      label: 'نقطة الانطلاق',
                      hint: 'مثال: القاهرة',
                      icon: Icons.location_on,
                      color: Colors.red,
                      onTap: _selectFromLocation,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى اختيار نقطة الانطلاق';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Arrow Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_downward,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // To Location
                    _buildModernTextField(
                      controller: _toController,
                      label: 'الوجهة',
                      hint: 'مثال: الإسكندرية',
                      icon: Icons.location_city,
                      color: Colors.green,
                      onTap: _selectToLocation,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى اختيار الوجهة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Departure Time
                    _buildModernTextField(
                      controller: TextEditingController(
                        text: _departureTime != null
                            ? DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(_departureTime!)
                            : '',
                      ),
                      label: 'وقت الانطلاق',
                      hint: 'اختر التاريخ والوقت',
                      icon: Icons.access_time,
                      color: Colors.orange,
                      onTap: _selectDepartureTime,
                      validator: (value) {
                        if (_departureTime == null) {
                          return 'يرجى اختيار وقت الانطلاق';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Price
                    _buildModernTextField(
                      controller: _priceController,
                      label: 'السعر لكل مقعد',
                      hint: 'مثال: 100',
                      icon: Icons.attach_money,
                      color: Colors.green,
                      keyboardType: TextInputType.number,
                      suffixWidget: Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'EGP',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال السعر';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'السعر يجب أن يكون رقم صحيح أكبر من 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Seat Configuration Card
                _buildSectionCard(
                  title: 'إعدادات المقاعد',
                  icon: Icons.event_seat,
                  color: Colors.purple,
                  children: [
                    const SizedBox(height: 8),
                    // Rows
                    _buildCounterRow(
                      label: 'عدد الصفوف',
                      value: _rows,
                      icon: Icons.view_column,
                      min: 1,
                      max: 10,
                      onDecrement: _rows > 1
                          ? () => setState(() => _rows--)
                          : null,
                      onIncrement: _rows < 10
                          ? () => setState(() => _rows++)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Seats Per Row
                    _buildCounterRow(
                      label: 'عدد المقاعد في كل صف',
                      value: _seatsPerRow,
                      icon: Icons.airline_seat_recline_normal,
                      min: 1,
                      max: 10,
                      onDecrement: _seatsPerRow > 1
                          ? () => setState(() => _seatsPerRow--)
                          : null,
                      onIncrement: _seatsPerRow < 10
                          ? () => setState(() => _seatsPerRow++)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Total Seats Display
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade50,
                            Colors.purple.shade100,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.purple.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.confirmation_number,
                                color: Colors.purple.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'إجمالي المقاعد',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalSeats',
                              style: GoogleFonts.cairo(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Prevent Gender Mixing
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'منع الاختلاط',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4, right: 48),
                          child: Text(
                            'منع الجلوس بجانب الجنس الآخر',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        value: _preventGenderMixing,
                        activeThumbColor: Colors.purple.shade700,
                        onChanged: (value) {
                          setState(() => _preventGenderMixing = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Car Image Card
                _buildSectionCard(
                  title: 'صورة السيارة',
                  icon: Icons.car_rental,
                  color: Colors.teal,
                  subtitle: '(اختياري)',
                  children: [
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickCarImage,
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _carImage != null
                                ? Colors.teal.shade300
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: _carImage != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.file(
                                      _carImage!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add_photo_alternate,
                                      color: Colors.teal.shade700,
                                      size: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'اضغط لرفع صورة السيارة',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'اختياري',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Create Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createTrip,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                'إنشاء الرحلة',
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    Widget? suffixWidget,
    String? Function(String?)? validator,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: TextFormField(
          controller: controller,
          readOnly: onTap != null,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400),
            labelStyle: GoogleFonts.cairo(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            suffixIcon: onTap != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      icon: Icon(Icons.map, color: color),
                      onPressed: onTap,
                    ),
                  )
                : suffixWidget != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: suffixWidget,
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterRow({
    required String label,
    required int value,
    required IconData icon,
    required int min,
    required int max,
    VoidCallback? onDecrement,
    VoidCallback? onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.purple.shade700, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDecrement,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Icon(
                        Icons.remove,
                        color: onDecrement != null
                            ? Colors.purple.shade700
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$value',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onIncrement,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Icon(
                        Icons.add,
                        color: onIncrement != null
                            ? Colors.purple.shade700
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
