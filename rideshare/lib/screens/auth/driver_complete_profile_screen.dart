import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vehicle_service.dart';
import '../../models/vehicle_type_template.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../core/errors/failure.dart';
import '../../l10n/l10n_extensions.dart';

class DriverCompleteProfileScreen extends StatefulWidget {
  const DriverCompleteProfileScreen({super.key});

  @override
  State<DriverCompleteProfileScreen> createState() =>
      _DriverCompleteProfileScreenState();
}

class _DriverCompleteProfileScreenState
    extends State<DriverCompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _plateNumberController = TextEditingController();
  final _modelController = TextEditingController();
  final _seatsController = TextEditingController();

  final StorageService _storageService = StorageService();
  final VehicleService _vehicleService = VehicleService();

  // Seat layout is derived from the vehicle type. Templates come from the
  // backend catalog (with a local fallback if the network is unavailable) so
  // selecting a car type fills the seat count automatically.
  Map<String, VehicleTypeTemplate> _templatesByType = {};
  static const Map<String, int> _fallbackSeatsByType = {
    'sedan': 3,
    'suv': 5,
    'van': 7,
    'truck': 2,
    'bus': 20,
    'motorcycle': 1,
  };

  File? _profileImage;
  File? _driverLicenseImage;
  File? _vehicleLicenseImage;
  File? _carImage;
  String? _selectedVehicleType;
  bool _isLoading = false;
  bool _isLoadingUserData = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String? _firstName;
  String? _lastName;
  String? _email;
  String? _gender;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Get arguments from previous screen or load from Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
    _loadVehicleTemplates();
  }

  Future<void> _loadVehicleTemplates() async {
    try {
      final templates = await _vehicleService.getVehicleTypes();
      if (!mounted) return;
      setState(() {
        _templatesByType = {for (final t in templates) t.type: t};
        // Refresh the auto-filled seat count if a type is already chosen.
        final seats = _seatsForType(_selectedVehicleType);
        if (seats != null) _seatsController.text = seats.toString();
      });
    } catch (_) {
      // Network unavailable on first run — the local fallback seat counts
      // below keep the auto-fill working.
    }
  }

  /// Default seat count for a vehicle type, from the backend catalog when
  /// available, otherwise the local fallback. Returns null for unknown types.
  int? _seatsForType(String? type) {
    if (type == null) return null;
    return _templatesByType[type]?.seats ?? _fallbackSeatsByType[type];
  }

  Future<void> _loadUserData() async {
    // First, try to get data from arguments (if coming from sign up screen)
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['firstName'] != null) {
      setState(() {
        _firstName = args['firstName'];
        _lastName = args['lastName'];
        _email = args['email'];
        _gender = args['gender'];
        _isLoadingUserData = false;
      });
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Brand-new driver registration (no account yet): basic info comes from the
    // pending registration saved at the OTP step, which survives app restarts.
    final pending = authProvider.pendingDriverRegistration;
    if (!authProvider.isAuthenticated && pending != null) {
      setState(() {
        _firstName = pending.firstName.isNotEmpty ? pending.firstName : null;
        _lastName = pending.lastName.isNotEmpty ? pending.lastName : null;
        _email = (pending.email?.isNotEmpty ?? false) ? pending.email : null;
        _gender = (pending.gender?.isNotEmpty ?? false) ? pending.gender : null;
        _isLoadingUserData = false;
      });
      return;
    }

    // Existing user upgrading to driver: load from AuthProvider (REST API).
    try {
      if (authProvider.userModel == null) {
        await authProvider.loadUserProfile();
      }

      final userModel = authProvider.userModel;
      if (userModel != null) {
        // Extract firstName and lastName from name
        final nameParts = userModel.name.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        final lastName = nameParts.length > 1
            ? nameParts.sublist(1).join(' ')
            : '';

        setState(() {
          _firstName = firstName.isNotEmpty ? firstName : null;
          _lastName = lastName.isNotEmpty ? lastName : null;
          _email = userModel.email.isNotEmpty ? userModel.email : null;
          _gender = userModel.gender.isNotEmpty ? userModel.gender : null;
          _isLoadingUserData = false;
        });
        return;
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }

    // If we can't load data, set loading to false
    setState(() {
      _isLoadingUserData = false;
    });
  }

  @override
  void dispose() {
    _plateNumberController.dispose();
    _modelController.dispose();
    _seatsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required ImageSource source,
    required Function(File) onImagePicked,
  }) async {
    final XFile? image = await _storageService.pickImage(source: source);
    if (image != null) {
      onImagePicked(File(image.path));
    }
  }

  Future<void> _showImageSourceDialog(Function(File) onImagePicked) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: T.outline(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Semantics(
                button: true,
                label: context.l10n.pickImageFromGallery,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: T.secondary(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: T.secondary(context),
                    ),
                  ),
                  title: Text(context.l10n.fromGallery),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(
                      source: ImageSource.gallery,
                      onImagePicked: onImagePicked,
                    );
                  },
                ),
              ),
              Semantics(
                button: true,
                label: context.l10n.captureImageFromCamera,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: T.secondary(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.camera_alt, color: T.secondary(context)),
                  ),
                  title: Text(context.l10n.fromCamera),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(
                      source: ImageSource.camera,
                      onImagePicked: onImagePicked,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate images
    if (_profileImage == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Personal photo not uploaded',
        ),
      );
      return;
    }

    if (_driverLicenseImage == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Driver license photo not uploaded',
        ),
      );
      return;
    }

    if (_vehicleLicenseImage == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Vehicle license photo not uploaded',
        ),
      );
      return;
    }

    if (_carImage == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Car photo not uploaded',
        ),
      );
      return;
    }

    if (_selectedVehicleType == null) {
      ErrorSurface.showFailure(
        context,
        const Failure(
          category: FailureCategory.validation,
          messageKey: 'errorsValidationGeneric',
          severity: FailureSeverity.warning,
          developerDetail: 'Vehicle type not selected',
        ),
      );
      return;
    }
    await _saveDriverProfile();
  }

  Future<void> _saveDriverProfile() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isAuthenticated) {
        // Existing user upgrading to driver — the account already exists.
        await authProvider.saveDriverProfile(
          firstName: _firstName ?? '',
          lastName: _lastName ?? '',
          phoneNumber: authProvider.userModel?.phoneNumber ?? '',
          profileImage: _profileImage!,
          vehicleType: _selectedVehicleType!,
          plateNumber: _plateNumberController.text.trim(),
          model: _modelController.text.trim(),
          seats: int.parse(_seatsController.text.trim()),
          driverLicenseImage: _driverLicenseImage!,
          vehicleLicenseImage: _vehicleLicenseImage!,
          carImage: _carImage!,
          email: _email,
          gender: _gender, // Pass gender from step 1
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.driverProfileSubmittedFull),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 5),
            ),
          );
          // AuthWrapper will now show home since the profile is complete.
          Navigator.pushReplacementNamed(context, RouteNames.home);
        }
        return;
      }

      // Brand-new driver: this is the final step — the account and vehicle are
      // created atomically here. If anything failed earlier, no account exists.
      await authProvider.registerDriver(
        profileImage: _profileImage!,
        vehicleType: _selectedVehicleType!,
        plateNumber: _plateNumberController.text.trim(),
        model: _modelController.text.trim(),
        seats: int.parse(_seatsController.text.trim()),
        driverLicenseImage: _driverLicenseImage!,
        vehicleLicenseImage: _vehicleLicenseImage!,
        carImage: _carImage!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.driverProfileSubmitted),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.driverPendingApproval,
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error completing driver profile: $e');
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
    // Show loading while fetching user data
    if (_isLoadingUserData) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                T.secondary(context),
                AppColors.teal700,
                AppColors.teal300,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              T.secondary(context),
              AppColors.teal700,
              AppColors.teal300,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 30,
                      horizontal: 24,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.drive_eta,
                            size: 50,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.l10n.driverCompleteProfileTitle,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            context.l10n.driverProfileStep2,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: T.surface(context),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            // Profile Image
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: T.secondary(context),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: T
                                              .secondary(context)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 57,
                                      backgroundColor: T.surface(context),
                                      backgroundImage: _profileImage != null
                                          ? FileImage(_profileImage!)
                                          : null,
                                      child: _profileImage == null
                                          ? Icon(
                                              Icons.person,
                                              size: 60,
                                              color: T.onSurfaceVariant(
                                                context,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            T.secondary(context),
                                            AppColors.teal700,
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: T
                                                .secondary(context)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Tooltip(
                                        message: context.l10n.uploadProfilePhoto,
                                        child: Semantics(
                                          button: true,
                                          label: context.l10n.uploadProfilePhoto,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.camera_alt,
                                              color: AppColors.white,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _showImageSourceDialog((image) {
                                                  setState(
                                                    () => _profileImage = image,
                                                  );
                                                }),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                context.l10n.profilePhotoRequired,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: T.onSurfaceVariant(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const SizedBox(height: 8),
                            // Vehicle Type
                            Semantics(
                              label: context.l10n.vehicleType,
                              textField: true,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedVehicleType,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: T.onSurface(context),
                                ),
                                decoration: InputDecoration(
                                  labelText: context.l10n.vehicleTypeRequired,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: T
                                          .secondary(context)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.directions_car,
                                      color: T.secondary(context),
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.outline(context),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.outline(context),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.secondary(context),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: AppConstants.vehicleTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      AppConstants.vehicleTypeLabels[type] ??
                                          type,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedVehicleType = value;
                                    // Seat count (and the seat layout stored on
                                    // the backend) follow the chosen type.
                                    final seats = _seatsForType(value);
                                    if (seats != null) {
                                      _seatsController.text = seats.toString();
                                    }
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return context.l10n.vehicleTypeValidation;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Plate Number
                            Semantics(
                              label: context.l10n.vehiclePlate,
                              textField: true,
                              child: TextFormField(
                                controller: _plateNumberController,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: context.l10n.vehiclePlateRequiredLabel,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: T
                                          .secondary(context)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.confirmation_number,
                                      color: T.secondary(context),
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.outline(context),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.outline(context),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.secondary(context),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return context.l10n.vehiclePlateRequired;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Model
                            Semantics(
                              label: context.l10n.vehicleModel,
                              textField: true,
                              child: TextFormField(
                                controller: _modelController,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: context.l10n.vehicleModelRequiredLabel,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: T
                                          .secondary(context)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.car_repair,
                                      color: T.secondary(context),
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.outline(context),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.outline(context),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.secondary(context),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return context.l10n.vehicleModelRequired;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Seats
                            Semantics(
                              label: context.l10n.vehicleSeats,
                              textField: true,
                              child: TextFormField(
                                controller: _seatsController,
                                keyboardType: TextInputType.number,
                                // Seats are set automatically from the selected
                                // vehicle type, so this field is read-only.
                                readOnly: true,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: context.l10n.vehicleSeatsRequiredLabel,
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: T
                                          .secondary(context)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.event_seat,
                                      color: T.secondary(context),
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.outline(context),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.outline(context),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: T.secondary(context),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return context.l10n.vehicleSeatsRequired;
                                  }
                                  final seats = int.tryParse(value);
                                  if (seats == null || seats < 1) {
                                    return context.l10n.vehicleSeatsInvalid;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Driver License Image
                            _buildImagePicker(
                              title: context.l10n.driverLicenseRequired,
                              image: _driverLicenseImage,
                              onImagePicked: (image) {
                                setState(() => _driverLicenseImage = image);
                              },
                            ),
                            const SizedBox(height: 20),
                            // Vehicle License Image
                            _buildImagePicker(
                              title: context.l10n.vehicleLicenseRequired,
                              image: _vehicleLicenseImage,
                              onImagePicked: (image) {
                                setState(() => _vehicleLicenseImage = image);
                              },
                            ),
                            const SizedBox(height: 20),
                            // Car Photo (mandatory — shown on every trip)
                            _buildImagePicker(
                              title: context.l10n.carPhotoRequired,
                              image: _carImage,
                              onImagePicked: (image) {
                                setState(() => _carImage = image);
                              },
                            ),
                            const SizedBox(height: 32),
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    T.secondary(context),
                                    AppColors.teal700,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: T
                                        .secondary(context)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Semantics(
                                button: true,
                                label: context.l10n.createNewAccount,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _completeProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.transparent,
                                    shadowColor: AppColors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          context.l10n.createNewAccount,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker({
    required String title,
    required File? image,
    required Function(File) onImagePicked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: context.l10n.uploadFileLabel(title),
          child: GestureDetector(
            onTap: () => _showImageSourceDialog(onImagePicked),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: image != null
                    ? AppColors.transparent
                    : T.surface(context),
                border: Border.all(
                  color: image != null
                      ? T.secondary(context)
                      : T.outline(context),
                  width: image != null ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: image != null
                    ? [
                        BoxShadow(
                          color: T.secondary(context).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Image.file(
                            image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: T
                                    .secondary(context)
                                    .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: AppColors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: T
                                  .secondary(context)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.add_photo_alternate,
                              color: T.secondary(context),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.tapToUpload,
                            style: TextStyle(
                              color: T.onSurfaceVariant(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
