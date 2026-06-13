import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/trip_provider.dart';
import '../../core/services/storage_service.dart';
import '../../models/location_model.dart';
import '../../models/trip_model.dart';
import '../../widgets/location_picker_widget.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/colors.dart';
import '../../../widgets/common/section_card.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../core/errors/failure.dart';
import '../../l10n/l10n_extensions.dart';

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
          _existingCarImageUrl = trip.carImageUrl;
          _fromController.text = trip.from.name;
          _toController.text = trip.to.name;
          _isLoadingTrip = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoadingTrip = false);
          ErrorSurface.showFailure(
            context,
            const Failure(
              category: FailureCategory.validation,
              messageKey: 'errorsValidationGeneric',
              severity: FailureSeverity.warning,
              developerDetail: 'Trip not found',
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTrip = false);
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
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
          title: context.l10n.selectOriginPoint,
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
          title: context.l10n.selectDestination,
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
              title: Text(context.l10n.warningTitle),
              content: Text(context.l10n.pastDateWarningBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(context.l10n.continueLabel),
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
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Origin location is missing',
        ),
      );
      return;
    }

    if (_toLocation == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Destination location is missing',
        ),
      );
      return;
    }

    if (_departureTime == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Departure time is missing',
        ),
      );
      return;
    }

    final bool isPastTrip =
        _trip != null &&
        (_trip!.isCompleted || _trip!.isPast || _trip!.isLocked);

    if (!isPastTrip && _departureTime!.isBefore(DateTime.now())) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Departure time must be in the future for active trips',
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
            title: Text(context.l10n.warningTitle),
            content: Text(
              context.l10n.bookedSeatsEditWarning(bookedSeats),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.white,
                ),
                child: Text(context.l10n.continueLabel),
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

      final updates = {
        'from': _fromLocation!.toMap(),
        'to': _toLocation!.toMap(),
        'departureTime': _departureTime!,
        'price': double.parse(_priceController.text.trim()),
        if (carImageUrl != null) 'carImage': carImageUrl,
      };

      final success = await tripProvider.updateTrip(widget.tripId, updates);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.tripUpdatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('فشل تحديث الرحلة');
      }
    } catch (e) {
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
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
            context.l10n.editTripScreenTitle,
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
            context.l10n.editTripScreenTitle,
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(child: Text(context.l10n.tripNotFound)),
      );
    }

    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          context.l10n.editTripScreenTitle,
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
                        context.l10n.editYourTrip,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: T.onPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.updateTripInfo,
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
                  title: context.l10n.tripDetailsSection,
                  icon: Icons.route,
                  iconColor: T.info(context),
                  children: [
                    const SizedBox(height: 8),
                    _buildModernTextField(
                      controller: _fromController,
                      label: context.l10n.originPointLabel,
                      hint: context.l10n.originExampleHint,
                      icon: Icons.trip_origin,
                      color: T.success(context),
                      onTap: _selectFromLocation,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.l10n.selectOriginValidator;
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
                      label: context.l10n.destinationLabel,
                      hint: context.l10n.destinationExampleHint,
                      icon: Icons.location_on,
                      color: T.error(context),
                      onTap: _selectToLocation,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.l10n.selectDestinationValidator;
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
                      label: context.l10n.departureTimeLabel,
                      hint: context.l10n.pickDateAndTime,
                      icon: Icons.access_time,
                      color: T.secondary(context),
                      onTap: _selectDepartureTime,
                      validator: (value) {
                        if (_departureTime == null) {
                          return context.l10n.selectDepartureTimeValidator;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _priceController,
                      label: context.l10n.pricePerSeatLabel,
                      hint: context.l10n.priceExampleHint,
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
                          return context.l10n.enterPriceValidator;
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return context.l10n.priceMustBeValidPositive;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SectionCard(
                  title: context.l10n.carImageSection,
                  icon: Icons.car_rental,
                  iconColor: T.primary(context),
                  subtitle: context.l10n.optionalParen,
                  children: [
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: context.l10n.uploadCarImage,
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
                                      context.l10n.tapToUploadCarImage,
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: T.textSecondary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.optionalLabel,
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
                    label: context.l10n.saveChanges,
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
                                  context.l10n.saveChanges,
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
                      tooltip: context.l10n.selectFromMap,
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

}
