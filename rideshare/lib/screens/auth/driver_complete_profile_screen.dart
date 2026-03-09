import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/colors.dart';

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

  File? _profileImage;
  File? _driverLicenseImage;
  File? _vehicleLicenseImage;
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

    // If no arguments, load from AuthProvider (REST API)
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.only(
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: AppColors.secondary,
                  ),
                ),
                title: const Text('من المعرض'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(
                    source: ImageSource.gallery,
                    onImagePicked: onImagePicked,
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: AppColors.secondary,
                  ),
                ),
                title: const Text('من الكاميرا'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(
                    source: ImageSource.camera,
                    onImagePicked: onImagePicked,
                  );
                },
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى رفع الصورة الشخصية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_driverLicenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى رفع صورة رخصة القيادة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_vehicleLicenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى رفع صورة رخصة المركبة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedVehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نوع المركبة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await _saveDriverProfile();
  }

  Future<void> _saveDriverProfile() async {
    setState(() => _isLoading = true);

    try {
      // Check if user is authenticated
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userModel == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // Save driver profile with all information
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
        email: _email,
        gender: _gender, // Pass gender from step 1
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم رفع بياناتك بنجاح. طلبك قيد المراجعة من الإدارة؛ سيتم اعتمادك قريباً وستستطيع إنشاء رحلات بعد الاعتماد.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        // Navigate to home - AuthWrapper will now show home since profile is complete
        Navigator.pushReplacementNamed(context, RouteNames.home);
      }
    } catch (e) {
      print('❌ Error completing driver profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إكمال الملف الشخصي: ${e.toString()}'),
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
    // Show loading while fetching user data
    if (_isLoadingUserData) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.secondary,
                AppColors.secondaryDark,
                AppColors.secondaryLight,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
              AppColors.secondary,
              AppColors.secondaryDark,
              AppColors.secondaryLight,
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
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.drive_eta,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'إكمال الملف الشخصي',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'الخطوة 2 من 2: المعلومات الإضافية',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Form Card
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.only(
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
                                        color: AppColors.secondary,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.secondary
                                              .withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 57,
                                      backgroundColor: AppColors.background,
                                      backgroundImage: _profileImage != null
                                          ? FileImage(_profileImage!)
                                          : null,
                                      child: _profileImage == null
                                          ? Icon(
                                              Icons.person,
                                              size: 60,
                                              color: AppColors.textSecondary,
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.secondary,
                                            AppColors.secondaryDark,
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.secondary
                                                .withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
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
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text(
                                'الصورة الشخصية *',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const SizedBox(height: 8),
                            // Vehicle Type
                            DropdownButtonFormField<String>(
                              initialValue: _selectedVehicleType,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'نوع المركبة *',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.secondary,
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
                                setState(() => _selectedVehicleType = value);
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'يرجى اختيار نوع المركبة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Plate Number
                            TextFormField(
                              controller: _plateNumberController,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'رقم اللوحة *',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.confirmation_number,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.secondary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال رقم اللوحة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Model
                            TextFormField(
                              controller: _modelController,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'موديل السيارة *',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.car_repair,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.secondary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال موديل السيارة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Seats
                            TextFormField(
                              controller: _seatsController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'عدد المقاعد *',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.event_seat,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.secondary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال عدد المقاعد';
                                }
                                final seats = int.tryParse(value);
                                if (seats == null || seats < 1) {
                                  return 'عدد المقاعد يجب أن يكون رقم صحيح أكبر من 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            // Driver License Image
                            _buildImagePicker(
                              title: 'رخصة القيادة *',
                              image: _driverLicenseImage,
                              onImagePicked: (image) {
                                setState(() => _driverLicenseImage = image);
                              },
                            ),
                            const SizedBox(height: 20),
                            // Vehicle License Image
                            _buildImagePicker(
                              title: 'رخصة المركبة *',
                              image: _vehicleLicenseImage,
                              onImagePicked: (image) {
                                setState(() => _vehicleLicenseImage = image);
                              },
                            ),
                            const SizedBox(height: 32),
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.secondary,
                                    AppColors.secondaryDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _completeProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
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
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'إنشاء الحساب',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showImageSourceDialog(onImagePicked),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: image != null ? Colors.transparent : AppColors.background,
              border: Border.all(
                color: image != null ? AppColors.secondary : AppColors.border,
                width: image != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: image != null
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.2),
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
                              color: AppColors.secondary.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
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
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add_photo_alternate,
                            color: AppColors.secondary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'اضغط لرفع الصورة',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
