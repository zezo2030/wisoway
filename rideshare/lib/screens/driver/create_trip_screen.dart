import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vehicle_service.dart';
import '../../models/location_model.dart';
import '../../models/vehicle_model.dart';
import '../../widgets/location_picker_widget.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';

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
  VehicleModel? _vehicle;
  bool _isLoadingVehicle = true;
  bool _isLoading = false;

  // Stops (up to 5 intermediate waypoints)
  final List<LocationModel> _stops = [];

  // Notes
  final TextEditingController _notesController = TextEditingController();

  // Recurrence
  bool _enableRecurrence = false;
  String _recurrenceFrequency = 'weekly'; // 'daily' | 'weekly'
  final Set<String> _selectedWeekdays = {};
  DateTime? _recurrenceUntil;

  static const Map<String, String> _weekdayLabels = {
    'sun': 'أحد',
    'mon': 'اثنين',
    'tue': 'ثلاثاء',
    'wed': 'أربعاء',
    'thu': 'خميس',
    'fri': 'جمعة',
    'sat': 'سبت',
  };

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
      if (mounted) {
        setState(() {
          _vehicle = vehicleInfo;
          _isLoadingVehicle = false;
        });
      }
    } else if (mounted) {
      setState(() => _isLoadingVehicle = false);
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _priceController.dispose();
    _notesController.dispose();
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

      final tripId = await tripProvider.createTrip(
        from: _fromLocation!,
        to: _toLocation!,
        departureTime: _departureTime!,
        price: double.parse(_priceController.text.trim()),
        currency: 'JOD',
        stops: _stops.isNotEmpty ? List.of(_stops) : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        recurrence: _enableRecurrence
            ? {
                'frequency': _recurrenceFrequency,
                if (_recurrenceFrequency == 'weekly' &&
                    _selectedWeekdays.isNotEmpty)
                  'weekdays': _selectedWeekdays.toList(),
                if (_recurrenceUntil != null)
                  'until': DateFormat('yyyy-MM-dd').format(_recurrenceUntil!),
              }
            : null,
      );

      if (tripId != null && mounted) {
        _showSuccess('تم إنشاء الرحلة بنجاح');
        Navigator.pop(context, tripId);
      } else {
        throw Exception('فشل إنشاء الرحلة');
      }
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
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
                        _buildStopsCard(),
                        SizedBox(height: _cardGap(context)),
                        _buildDetailsCard(),
                        SizedBox(height: _cardGap(context)),
                        _buildNotesCard(),
                        SizedBox(height: _cardGap(context)),
                        _buildRecurrenceCard(),
                        SizedBox(height: _cardGap(context)),
                        _buildVehicleSeatingSummaryCard(),
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
            style: AppTextStyles.labelLarge.copyWith(
              color: T.onSurface(context),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: T.surface(context),
              hintText: 'السعر لكل مقعد',
              hintStyle: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.slate400,
              ),
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

  Widget _buildVehicleSeatingSummaryCard() {
    final vehicle = _vehicle;
    final layout = vehicle?.seatLayout;
    final totalSeats = layout != null
        ? (layout.seatsPerRowList != null && layout.seatsPerRowList!.isNotEmpty
              ? layout.seatsPerRowList!.fold<int>(0, (s, v) => s + v)
              : layout.rows * layout.seatsPerRow)
        : (vehicle?.seats ?? 0);

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مقاعد السيارة',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              if (!_isLoadingVehicle && vehicle != null)
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
          const SizedBox(height: 12),
          if (_isLoadingVehicle)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else
            Text(
              layout != null
                  ? 'تخطيط المقاعد ومنع الاختلاط مأخوذان من إعدادات سيارتك ويُطبَّقان على كل رحلاتك.'
                  : 'لم تضبط بعد تخطيط مقاعد لسيارتك — سيتم استخدام تخطيط افتراضي. اضبطه من إعدادات السيارة لتجربة أدق.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(context, RouteNames.vehicleSettings);
              await _loadVehicleInfo();
            },
            icon: Icon(IconsaxPlusBroken.car, color: T.primary(context)),
            label: Text(
              'تعديل إعدادات السيارة',
              style: AppTextStyles.bodyLarge.copyWith(
                color: T.primary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: T.primary(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? T.surface(context) : AppColors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: T.shadow(context),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive
                  ? T.primary(context)
                  : T.onSurfaceVariant(context),
            ),
          ),
        ),
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
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: T.primary(context),
          boxShadow: [
            BoxShadow(
              color: T.primary(context).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Semantics(
          button: true,
          label: 'تأكيد ونشر الرحلة',
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.transparent,
              shadowColor: AppColors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: _isLoading ? null : _createTrip,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.white,
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

  Widget _buildStopsCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'محطات التوقف',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              Row(
                children: [
                  Text(
                    'اختياري',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: T.outlineVariant(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_stops.length < 5)
                    Semantics(
                      button: true,
                      label: 'إضافة محطة توقف',
                      child: GestureDetector(
                        onTap: _addStop,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: T.primary(context).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            color: T.primary(context),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_stops.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'أضف حتى 5 محطات توقف وسيطة على طول الطريق.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...List.generate(_stops.length, (i) {
              final stop = _stops[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: T.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: T.outline(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: T.secondary(context).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: T.secondary(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stop.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: T.onSurface(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'حذف المحطة ${i + 1}',
                        child: GestureDetector(
                          onTap: () => setState(() => _stops.removeAt(i)),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: T.error(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _addStop() async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          title: 'اختر محطة توقف ${_stops.length + 1}',
          onLocationSelected: (_) {},
        ),
      ),
    );
    if (location != null) {
      setState(() => _stops.add(location));
    }
  }

  Widget _buildNotesCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ملاحظات للركاب',
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
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 2000,
            style: AppTextStyles.bodyLarge.copyWith(
              color: T.onSurface(context),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: T.surface(context),
              hintText: 'مثال: التوقف في صيدلية البتراء، لا تأخر أكثر من 5 دقائق...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
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
              counterStyle: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تكرار الرحلة',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              Semantics(
                label: 'تفعيل تكرار الرحلة: ${_enableRecurrence ? "مفعّل" : "معطّل"}',
                child: Switch(
                  value: _enableRecurrence,
                  activeThumbColor: T.primary(context).withValues(alpha: 0.3),
                  onChanged: (v) => setState(() => _enableRecurrence = v),
                ),
              ),
            ],
          ),
          if (!_enableRecurrence)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'فعّل هذا الخيار لجدولة الرحلة بشكل تلقائي (يومياً أو أسبوعياً).',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: T.onSurfaceVariant(context),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 20),

            // Frequency toggle
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
                      title: 'يومياً',
                      isActive: _recurrenceFrequency == 'daily',
                      onTap: () => setState(() {
                        _recurrenceFrequency = 'daily';
                        _selectedWeekdays.clear();
                      }),
                    ),
                  ),
                  Expanded(
                    child: _buildModeToggle(
                      title: 'أسبوعياً',
                      isActive: _recurrenceFrequency == 'weekly',
                      onTap: () =>
                          setState(() => _recurrenceFrequency = 'weekly'),
                    ),
                  ),
                ],
              ),
            ),

            // Weekday chips (only for weekly)
            if (_recurrenceFrequency == 'weekly') ...[
              const SizedBox(height: 16),
              Text(
                'أيام التكرار',
                style: AppTextStyles.labelLarge.copyWith(
                  color: T.onSurface(context).withValues(alpha: 0.54),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekdayLabels.entries.map((entry) {
                  final key = entry.key;
                  final label = entry.value;
                  final selected = _selectedWeekdays.contains(key);
                  return Semantics(
                    button: true,
                    label: '$label ${selected ? "(محدد)" : ""}',
                    child: FilterChip(
                      label: Text(
                        label,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? T.onPrimary(context)
                              : T.onSurface(context),
                        ),
                      ),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedWeekdays.add(key);
                        } else {
                          _selectedWeekdays.remove(key);
                        }
                      }),
                      selectedColor: T.primary(context),
                      checkmarkColor: T.onPrimary(context),
                      backgroundColor: T.surface(context),
                      side: BorderSide(
                        color: selected
                            ? T.primary(context)
                            : T.outline(context),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Until date
            _buildInteractiveField(
              controller: TextEditingController(
                text: _recurrenceUntil != null
                    ? DateFormat('yyyy-MM-dd').format(_recurrenceUntil!)
                    : '',
              ),
              hint: 'تاريخ انتهاء التكرار (اختياري)',
              icon: IconsaxPlusBroken.calendar_1,
              iconColor: T.secondary(context),
              onTap: _selectRecurrenceUntil,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectRecurrenceUntil() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (_recurrenceUntil ?? DateTime.now()).add(
        const Duration(days: 30),
      ),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'تاريخ انتهاء التكرار',
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
    if (picked != null) setState(() => _recurrenceUntil = picked);
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

}
