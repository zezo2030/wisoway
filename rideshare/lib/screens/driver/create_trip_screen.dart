import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/services/storage_service.dart';
import '../../models/location_model.dart';
import '../../models/seat_layout_config.dart';
import '../../widgets/location_picker_widget.dart';
import '../../core/services/vehicle_service.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/colors.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen>
    with SingleTickerProviderStateMixin {
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
  bool _isCustomLayout = false;
  final List<int> _customRowConfigs = [1, 3];
  bool _preventGenderMixing = true;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
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
    final XFile? image = await _storageService.pickImage(
      source: ImageSource.gallery,
    );
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
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: T.primary(context),
              onPrimary: T.onPrimary(context),
              onSurface: T.onSurface(context).withValues(alpha: 0.87),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: T.primary(context),
                onPrimary: T.onPrimary(context),
                onSurface: T.onSurface(context).withValues(alpha: 0.87),
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        if (!mounted) return;
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
    if (_fromLocation == null ||
        _toLocation == null ||
        _departureTime == null) {
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
        seatsPerRowList: _isCustomLayout ? _customRowConfigs : null,
        preventGenderMixing: _preventGenderMixing,
      );

      final tripId = await tripProvider.createTrip(
        from: _fromLocation!,
        to: _toLocation!,
        departureTime: _departureTime!,
        price: double.parse(_priceController.text.trim()),
        currency: 'JOD',
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.error(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(Icons.error_outline, color: T.onError(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: T.onError(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: T.success(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: T.onPrimary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: T.onPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    if (user != null && !user.canCreateTrips) {
      return Scaffold(
        backgroundColor: T.background(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  IconsaxPlusBold.timer,
                  size: 80,
                  color: T.primary(context),
                ),
                const SizedBox(height: 24),
                Text(
                  'حسابك كسائق قيد المراجعة',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context).withValues(alpha: 0.87),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً تصفح الرحلات والحجز كراكب.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    color: T.onSurface(context).withValues(alpha: 0.54),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    'العودة للرئيسية',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: T.primary(context),
                    foregroundColor: T.onPrimary(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        backgroundColor: T.primary(context),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'إنشاء رحلة جديدة',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: T.onPrimary(context),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: T.onPrimary(context)),
          tooltip: 'رجوع',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: _horizontalPadding(context),
              vertical: _verticalSpacing(context),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _maxContentWidth(context),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildHeaderIllustration(),
                      SizedBox(height: _verticalSpacing(context)),
                      _buildLocationsCard(),
                      SizedBox(height: _cardGap(context)),
                      _buildDetailsCard(),
                      SizedBox(height: _cardGap(context)),
                      _buildSeatingCard(),
                      SizedBox(height: _cardGap(context)),
                      _buildCarImageCard(),
                      SizedBox(height: _verticalSpacing(context) * 1.5),
                      _buildSubmitButton(),
                      SizedBox(height: _verticalSpacing(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) return 40;
    if (width >= 600) return 24;
    return 16;
  }

  double _maxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 600;
    if (width >= 900) return 500;
    if (width >= 600) return double.infinity;
    return double.infinity;
  }

  double _cardGap(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return 16;
    return 16;
  }

  double _verticalSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return 24;
    return 20;
  }

  Widget _buildHeaderIllustration() {
    final iconSize = _iconSize(context);
    return Container(
      padding: EdgeInsets.all(_cardPadding(context)),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: T.outline(context)),
        boxShadow: [
          BoxShadow(
            color: T.surface(context).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconsaxPlusBold.car,
              color: T.primary(context),
              size: iconSize,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'شارك رحلتك القادمة',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بتحديد وجهتك ووقت الانطلاق لتبدأ مشاركة رحلتك مع الركاب.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }

  double _iconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 36;
    if (width >= 600) return 56;
    return 48;
  }

  Widget _buildLocationsCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مسار الرحلة',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Positioned(
                left: 23,
                top: 30,
                bottom: 30,
                child: Container(
                  width: 2,
                  color: T.outlineVariant(context).withValues(alpha: 0.3),
                ),
              ),
              Column(
                children: [
                  _buildInteractiveField(
                    controller: _fromController,
                    hint: 'أين أنت الآن؟',
                    icon: Icons.my_location_rounded,
                    iconColor: T.primary(context),
                    onTap: _selectFromLocation,
                  ),
                  const SizedBox(height: 16),
                  _buildInteractiveField(
                    controller: _toController,
                    hint: 'أين وجهتك؟',
                    icon: Icons.location_on_rounded,
                    iconColor: T.primary(context),
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
          Text(
            'تفاصيل الانطلاق والسعر',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 20),
          _buildInteractiveField(
            controller: TextEditingController(
              text: _departureTime != null
                  ? DateFormat('yyyy-MM-dd hh:mm a').format(_departureTime!)
                  : '',
            ),
            hint: 'وقت الانطلاق',
            icon: IconsaxPlusBroken.calendar_1,
            iconColor: T.secondary(context),
            onTap: _selectDepartureTime,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            style: AppTextStyles.labelLargeWithContext(context),
            decoration: InputDecoration(
              filled: true,
              fillColor: T.surface(context),
              hintText: 'السعر لكل مقعد',
              hintStyle: AppTextStyles.bodyLargeWithContext(
                context,
              ).copyWith(color: T.onSurfaceVariant(context)),
              prefixIcon: Icon(
                IconsaxPlusBroken.wallet_1,
                color: T.onSurface(context),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                child: Text(
                  'JOD',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.primary(context),
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: T.outline(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: T.primary(context), width: 2),
              ),
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
    int totalSeats = _isCustomLayout
        ? _customRowConfigs.fold(0, (sum, item) => sum + item)
        : _rows * _seatsPerRow;

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إعدادات المقاعد',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalSeats مقعد',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: T.surfaceVariant(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeToggle(
                    title: 'نظام الشبكة',
                    isActive: !_isCustomLayout,
                    onTap: () => setState(() => _isCustomLayout = false),
                  ),
                ),
                Expanded(
                  child: _buildModeToggle(
                    title: 'توزيع مخصص',
                    isActive: _isCustomLayout,
                    onTap: () => setState(() => _isCustomLayout = true),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (!_isCustomLayout) ...[
            Row(
              children: [
                Expanded(
                  child: _buildCounter(
                    label: 'الصفوف',
                    value: _rows,
                    icon: IconsaxPlusBroken.row_vertical,
                    onDecrease: _rows > 1
                        ? () => setState(() => _rows--)
                        : null,
                    onIncrease: _rows < 10
                        ? () => setState(() => _rows++)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCounter(
                    label: 'بكل صف',
                    value: _seatsPerRow,
                    icon: Icons.airline_seat_recline_normal_rounded,
                    onDecrease: _seatsPerRow > 1
                        ? () => setState(() => _seatsPerRow--)
                        : null,
                    onIncrease: _seatsPerRow < 10
                        ? () => setState(() => _seatsPerRow++)
                        : null,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'حدد عدد المقاعد في كل صف:',
              style: AppTextStyles.labelLargeWithContext(
                context,
              ).copyWith(color: T.onSurfaceVariant(context)),
            ),
            const SizedBox(height: 12),
            ...List.generate(_customRowConfigs.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: T.primary(context).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: T.primary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCounter(
                        label: index == 0
                            ? 'بجانب السائق'
                            : 'الصف ${index + 1}',
                        value: _customRowConfigs[index],
                        icon: Icons.airline_seat_recline_normal_rounded,
                        onDecrease: _customRowConfigs[index] > 0
                            ? () => setState(() => _customRowConfigs[index]--)
                            : null,
                        onIncrease: _customRowConfigs[index] < 4
                            ? () => setState(() => _customRowConfigs[index]++)
                            : null,
                      ),
                    ),
                    if (_customRowConfigs.length > 1)
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: T.error(context),
                        ),
                        onPressed: () =>
                            setState(() => _customRowConfigs.removeAt(index)),
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _customRowConfigs.add(3)),
              icon: Icon(Icons.add_circle_outline, color: T.primary(context)),
              label: Text(
                'إضافة صف جديد',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: T.primary(context),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          _buildMixingToggle(),
        ],
      ),
    );
  }

  Widget _buildModeToggle({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title ${isActive ? "(محدد)" : ""}',
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: T.primary(context).withValues(alpha: 0.08),
          highlightColor: T.primary(context).withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? T.primaryContainer(context)
                  : AppColors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? T.primary(context).withValues(alpha: 0.35)
                    : AppColors.transparent,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                title,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? T.onPrimaryContainer(context)
                      : T.onSurfaceVariant(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMixingToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: T.secondary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline,
                  color: T.secondary(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'منع الاختلاط',
                style: AppTextStyles.bodyLargeWithContext(context).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
            ],
          ),
          Semantics(
            label: 'منع الاختلاط: ${_preventGenderMixing ? "مفعّل" : "معطّل"}',
            child: Switch(
              value: _preventGenderMixing,
              // activeThumbColor: T.primary(context),
              activeThumbColor: T.primary(context).withValues(alpha: 0.3),
              onChanged: (v) => setState(() => _preventGenderMixing = v),
            ),
          ),
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
              Text(
                'صورة السيارة',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              Text(
                'اختياري',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: T.outlineVariant(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'إضافة صورة للسيارة',
            child: GestureDetector(
              onTap: _pickCarImage,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: _carImageHeight(context),
                  maxHeight: _carImageHeight(context) * 1.5,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: T.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _carImage != null
                          ? T.primary(context)
                          : T.outline(context),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    image: _carImage != null
                        ? DecorationImage(
                            image: FileImage(_carImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _carImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: T
                                    .primary(context)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                IconsaxPlusBroken.camera,
                                color: T.primary(context),
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'انقر لإضافة صورة لسيارتك',
                              style: AppTextStyles.labelLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: T.textSecondary(context),
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: AppColors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _carImageHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 120;
    if (width >= 600) return 180;
    return 160;
  }

  Widget _buildSubmitButton() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _maxContentWidth(context)),
      child: Semantics(
        button: true,
        label: 'تأكيد ونشر الرحلة',
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              elevation: 0,
              shadowColor: AppColors.transparent,
              backgroundColor: T.primary(context),
              foregroundColor: T.onPrimary(context),
              disabledBackgroundColor: T.primary(context).withValues(alpha: 0.38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            onPressed: _isLoading ? null : _createTrip,
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: T.onPrimary(context),
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    'تأكيد ونشر الرحلة',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: T.onPrimary(context),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(_cardPadding(context)),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: T.outline(context)),
        boxShadow: [
          BoxShadow(
            color: T.surface(context).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  double _cardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return 28;
    return 20;
  }

  Widget _buildInteractiveField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: hint,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: T.outline(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  controller.text.isEmpty ? hint : controller.text,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    fontWeight: controller.text.isEmpty
                        ? FontWeight.normal
                        : FontWeight.w600,
                    color: controller.text.isEmpty
                        ? T.textSecondary(context)
                        : T.onSurface(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: T.outlineVariant(context),
              ),
            ],
          ),
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
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: T.primary(context), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelLargeWithContext(
                    context,
                  ).copyWith(fontSize: 13, color: T.onSurface(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: onDecrease != null,
                    label: 'تقليل $label',
                    child: GestureDetector(
                      onTap: onDecrease,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: onDecrease == null
                              ? T.surfaceVariant(context)
                              : T.surface(context),
                          border: Border.all(color: T.outlineVariant(context)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.remove,
                          size: 20,
                          color: onDecrease == null
                              ? T.textDisabled(context)
                              : T.onSurface(context),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$value',
                      style: AppTextStyles.titleSmallWithContext(context)
                          .copyWith(
                            fontWeight: FontWeight.bold,
                            color: T.onSurface(context),
                          ),
                    ),
                  ),
                  Semantics(
                    button: onIncrease != null,
                    label: 'زيادة $label',
                    child: GestureDetector(
                      onTap: onIncrease,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: onIncrease == null
                              ? T.surfaceVariant(context)
                              : T.surface(context),
                          border: Border.all(color: T.outlineVariant(context)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 20,
                          color: onIncrease == null
                              ? T.textDisabled(context)
                              : T.onSurface(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
