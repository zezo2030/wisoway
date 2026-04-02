import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/trip_provider.dart';
import '../../core/services/storage_service.dart';
import '../../models/location_model.dart';
import '../../models/seat_layout_config.dart';
import '../../models/trip_model.dart';
import '../../widgets/location_picker_widget.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/colors.dart';
import '../../../widgets/common/section_card.dart';

class EditTripScreen extends StatefulWidget {
  final String tripId;

  const EditTripScreen({super.key, required this.tripId});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _priceController = TextEditingController();

  final StorageService _storageService = StorageService();

  TripModel? _trip;
  LocationModel? _fromLocation;
  LocationModel? _toLocation;
  DateTime? _departureTime;
  File? _carImage;
  String? _existingCarImageUrl;
  int _rows = 2;
  int _seatsPerRow = 2;
  bool _preventGenderMixing = true;
  bool _isLoading = false;
  bool _isLoadingTrip = true;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final trip = await tripProvider.getTrip(widget.tripId);

      if (trip != null && mounted) {
        setState(() {
          _trip = trip;
          _fromLocation = trip.from;
          _toLocation = trip.to;
          _departureTime = trip.departureTime;
          _priceController.text = trip.price.toString();
          _rows = trip.seatLayout.rows;
          _seatsPerRow = trip.seatLayout.seatsPerRow;
          _preventGenderMixing = trip.seatLayout.preventGenderMixing;
          _existingCarImageUrl = trip.carImageUrl;
          _fromController.text = trip.from.name;
          _toController.text = trip.to.name;
          _isLoadingTrip = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoadingTrip = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الرحلة غير موجودة'),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTrip = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الرحلة: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
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
        _existingCarImageUrl = null;
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
          onLocationSelected: (location) {},
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
          onLocationSelected: (location) {},
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
    final bool allowPastDates =
        _trip != null &&
        (_trip!.isCompleted || _trip!.isPast || _trip!.isLocked);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _departureTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: allowPastDates
          ? DateTime.now().subtract(const Duration(days: 365))
          : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: _departureTime != null
            ? TimeOfDay.fromDateTime(_departureTime!)
            : TimeOfDay.now(),
      );

      if (time != null) {
        final selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );

        if (!allowPastDates && selectedDateTime.isBefore(DateTime.now())) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('تحذير'),
              content: const Text(
                'أنت تختار تاريخ في الماضي. '
                'الرحلات في الماضي لن تظهر في نتائج البحث للركاب. '
                'هل تريد المتابعة؟',
              ),
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
                  child: const Text('متابعة'),
                ),
              ],
            ),
          );

          if (confirmed != true) return;
        }

        setState(() {
          _departureTime = selectedDateTime;
        });
      }
    }
  }

  Future<void> _updateTrip() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نقطة الانطلاق'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_toLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الوجهة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار وقت الانطلاق'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bool isPastTrip =
        _trip != null &&
        (_trip!.isCompleted || _trip!.isPast || _trip!.isLocked);

    if (!isPastTrip && _departureTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('وقت الانطلاق يجب أن يكون في المستقبل للرحلات النشطة'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_trip != null) {
      final bookedSeats = _trip!.seats.where((seat) => seat.isBooked).length;
      if (bookedSeats > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('تحذير'),
            content: Text(
              'هذه الرحلة تحتوي على $bookedSeats مقعد محجوز. '
              'تعديل بعض المعلومات قد يؤثر على الحجوزات الموجودة. '
              'هل تريد المتابعة؟',
            ),
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
                child: const Text('متابعة'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      String? carImageUrl = _existingCarImageUrl;
      if (_carImage != null) {
        carImageUrl = await _storageService.uploadImage(
          imageFile: _carImage!,
          folder: 'trip_images',
          fileName: 'trip_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (carImageUrl == null) {
          throw Exception('فشل رفع صورة السيارة');
        }
      }

      final seatLayout = SeatLayoutConfig(
        rows: _rows,
        seatsPerRow: _seatsPerRow,
        preventGenderMixing: _preventGenderMixing,
      );

      final newTotalSeats = _rows * _seatsPerRow;

      final existingBookedSeats =
          _trip?.seats.where((seat) => seat.isBooked).length ?? 0;
      final newAvailableSeats = newTotalSeats - existingBookedSeats;

      final updates = {
        'from': _fromLocation!.toMap(),
        'to': _toLocation!.toMap(),
        'departureTime': _departureTime!,
        'price': double.parse(_priceController.text.trim()),
        'seatLayout': seatLayout.toMap(),
        'totalSeats': newTotalSeats,
        'availableSeats': newAvailableSeats > 0 ? newAvailableSeats : 0,
        if (carImageUrl != null) 'carImage': carImageUrl,
      };

      final success = await tripProvider.updateTrip(widget.tripId, updates);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الرحلة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('فشل تحديث الرحلة');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: AppColors.error,
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
    if (_isLoadingTrip) {
      return Scaffold(
        backgroundColor: T.background(context),
        appBar: AppBar(
          elevation: 0,
          title: Text(
            'تعديل الرحلة',
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
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
            'تعديل الرحلة',
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(child: Text('الرحلة غير موجودة')),
      );
    }

    final totalSeats = _rows * _seatsPerRow;

    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'تعديل الرحلة',
          style: AppTextStyles.titleMedium.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        T.secondary(context),
                        T.secondary(context).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: T.secondary(context).withValues(alpha: 0.3),
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
                          color: T.onPrimary(context).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 48,
                          color: T.onPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'تعديل رحلتك',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: T.onPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'قم بتحديث معلومات الرحلة',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: T.onPrimary(context).withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SectionCard(
                  title: 'تفاصيل الرحلة',
                  icon: Icons.route,
                  iconColor: T.info(context),
                  children: [
                    const SizedBox(height: 8),
                    _buildModernTextField(
                      controller: _fromController,
                      label: 'نقطة الانطلاق',
                      hint: 'مثال: عمّان',
                      icon: Icons.location_on,
                      color: T.error(context),
                      onTap: _selectFromLocation,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى اختيار نقطة الانطلاق';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: T.primary(context).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_downward,
                          color: T.primary(context),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _toController,
                      label: 'الوجهة',
                      hint: 'مثال: الإسكندرية',
                      icon: Icons.location_city,
                      color: T.success(context),
                      onTap: _selectToLocation,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى اختيار الوجهة';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
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
                      color: T.secondary(context),
                      onTap: _selectDepartureTime,
                      validator: (value) {
                        if (_departureTime == null) {
                          return 'يرجى اختيار وقت الانطلاق';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _priceController,
                      label: 'السعر لكل مقعد',
                      hint: 'مثال: 100',
                      icon: Icons.attach_money,
                      color: T.success(context),
                      keyboardType: TextInputType.number,
                      suffixWidget: Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: T.success(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _trip?.currency ?? 'JOD',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: T.success(context),
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

                SectionCard(
                  title: 'إعدادات المقاعد',
                  icon: Icons.event_seat,
                  iconColor: T.primary(context),
                  children: [
                    const SizedBox(height: 8),
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: T.primaryContainer(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: T.primary(context).withValues(alpha: 0.3),
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
                                color: T.primary(context),
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'إجمالي المقاعد',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: T.primary(context),
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
                              color: T.primary(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalSeats',
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: T.onPrimary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: T.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: T.outline(context)),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              color: T.primary(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'منع الاختلاط',
                              style: AppTextStyles.titleSmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4, right: 48),
                          child: Text(
                            'منع الجلوس بجانب الجنس الآخر',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 13,
                              color: T.textSecondary(context),
                            ),
                          ),
                        ),
                        value: _preventGenderMixing,
                        activeThumbColor: T.primary(context),
                        onChanged: (value) {
                          setState(() => _preventGenderMixing = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SectionCard(
                  title: 'صورة السيارة',
                  icon: Icons.car_rental,
                  iconColor: T.primary(context),
                  subtitle: '(اختياري)',
                  children: [
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: 'رفع صورة السيارة',
                      child: GestureDetector(
                        onTap: _pickCarImage,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: T.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  (_carImage != null ||
                                      _existingCarImageUrl != null)
                                  ? T.primary(context)
                                  : T.outline(context),
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
                                          color: AppColors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          color: T.onPrimary(context),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : _existingCarImageUrl != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: _existingCarImageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: T.surfaceVariant(context),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: T.surfaceVariant(context),
                                              child: Icon(
                                                Icons.error,
                                                color: T.error(context),
                                              ),
                                            ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          color: T.onPrimary(context),
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
                                        color: T.primaryContainer(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate,
                                        color: T.primary(context),
                                        size: 48,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'اضغط لرفع صورة السيارة',
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: T.textSecondary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'اختياري',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: T.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: T.secondary(context).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Semantics(
                    button: true,
                    label: 'حفظ التعديلات',
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateTrip,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: T.secondary(context),
                        foregroundColor: T.onPrimary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  T.onPrimary(context),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  'حفظ التعديلات',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
          color: T.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.outline(context), width: 1.5),
        ),
        child: TextFormField(
          controller: controller,
          readOnly: onTap != null,
          keyboardType: keyboardType,
          validator: validator,
          style: AppTextStyles.bodyLarge.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: AppTextStyles.bodyLarge.copyWith(
              color: T.outlineVariant(context),
            ),
            labelStyle: AppTextStyles.labelLarge.copyWith(
              color: T.textSecondary(context),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
                      tooltip: 'اختيار من الخريطة',
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
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: T.primary(context), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyLarge.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: T.onSurface(context),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: T.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.outlineVariant(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: AppColors.transparent,
                  child: Semantics(
                    button: onDecrement != null,
                    label: 'تقليل $label',
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
                              ? T.primary(context)
                              : T.textDisabled(context),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$value',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: T.primary(context),
                    ),
                  ),
                ),
                Material(
                  color: AppColors.transparent,
                  child: Semantics(
                    button: onIncrement != null,
                    label: 'زيادة $label',
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
                              ? T.primary(context)
                              : T.textDisabled(context),
                          size: 20,
                        ),
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
