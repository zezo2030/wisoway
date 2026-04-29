import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/colors.dart';
import '../../core/services/storage_service.dart';
import '../../widgets/common/form_components.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _storageService = StorageService();

  String? _selectedGender;
  File? _profileImage;
  String? _currentPhotoUrl;
  bool _hidePhoneNumber = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _nameController.text = user.name;
      _selectedGender = user.gender;
      _currentPhotoUrl = user.photoUrl;
      _hidePhoneNumber = user.hidePhoneNumber;
      setState(() {});
    }
  }

  Future<void> _pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(IconsaxPlusLinear.gallery),
              title: Text('المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(IconsaxPlusLinear.camera),
              title: Text('الكاميرا'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final xFile = await _storageService.pickImage(source: source);
    if (xFile != null && mounted) {
      setState(() => _profileImage = File(xFile.path));
    }
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      _showSnackBar(AppStrings.genderRequired, AppColors.warning);
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.saveUserProfile(
        name: _nameController.text.trim(),
        email: authProvider.userModel?.email ?? '',
        gender: _selectedGender,
        role: authProvider.userModel?.role ?? AppConstants.rolePassenger,
        profileImage: _profileImage,
        hidePhoneNumber: _hidePhoneNumber,
      );

      if (mounted) {
        _showSnackBar('تم تحديث الملف الشخصي بنجاح', AppColors.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), T.error(context));
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              T.primary(context).withValues(alpha: 0.1),
              T.surface(context),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildProfileAvatar(),
                        const SizedBox(height: 32),
                        _buildFormFields(),
                        const SizedBox(height: 40),
                        _buildSaveButton(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'رجوع',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(IconsaxPlusLinear.arrow_right_2),
            style: IconButton.styleFrom(
              backgroundColor: T.surface(context),
              shadowColor: AppColors.black.withValues(alpha: 0.1),
              elevation: 2,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'تعديل الملف الشخصي',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        Semantics(
          button: true,
          label: 'اختر صورة الملف الشخصي',
          child: GestureDetector(
            onTap: _pickProfileImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: T.primary(context), width: 4),
                gradient: _profileImage != null || _currentPhotoUrl != null
                    ? null
                    : LinearGradient(
                        colors: [T.primary(context), AppColors.teal700],
                      ),
                color: _profileImage != null || _currentPhotoUrl != null
                    ? AppColors.white
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: T.primary(context).withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: _profileImage != null
                    ? Image.file(_profileImage!, fit: BoxFit.cover)
                    : _currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _currentPhotoUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        IconsaxPlusBold.profile,
                        size: 60,
                        color: AppColors.white,
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Semantics(
            button: true,
            label: 'تغيير صورة الملف الشخصي',
            child: GestureDetector(
              onTap: _pickProfileImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  IconsaxPlusBold.camera,
                  color: T.primary(context),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    final user = context.watch<AuthProvider>().userModel;

    return Column(
      children: [
        ModernInputField(
          controller: _nameController,
          label: AppStrings.fullName,
          hint: AppStrings.fullNameHint,
          icon: IconsaxPlusLinear.user,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? AppStrings.nameRequired : null,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  IconsaxPlusLinear.sms,
                  color: T.primary(context),
                  size: 20,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: T.onSurface(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                IconsaxPlusLinear.lock,
                size: 18,
                color: T.onSurfaceVariant(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionTitle(title: AppStrings.gender, isRequired: true),
        const SizedBox(height: 12),
        _buildGenderCards(),
        const SizedBox(height: 28),
        _buildHidePhoneToggle(),
      ],
    );
  }

  Widget _buildHidePhoneToggle() {
    return Container(
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Semantics(
        toggled: _hidePhoneNumber,
        label: 'إخفاء رقم الهاتف عن السائق',
        child: SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          secondary: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              IconsaxPlusLinear.call_slash,
              color: T.primary(context),
              size: 20,
            ),
          ),
          title: Text(
            'إخفاء رقم الهاتف',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: T.onSurface(context),
            ),
          ),
          subtitle: Text(
            'استخدام الاتصال المخفي بدلاً من مشاركة رقمك الحقيقي',
            style: TextStyle(
              fontSize: 12,
              color: T.onSurfaceVariant(context),
            ),
          ),
          value: _hidePhoneNumber,
          onChanged: (val) => setState(() => _hidePhoneNumber = val),
          activeColor: T.primary(context),
        ),
      ),
    );
  }

  Widget _buildGenderCards() {
    return Row(
      children: [
        Expanded(
          child: ModernSelectionCard(
            icon: IconsaxPlusLinear.man,
            title: AppStrings.male,
            isSelected: _selectedGender == AppConstants.genderMale,
            onTap: () =>
                setState(() => _selectedGender = AppConstants.genderMale),
            color: T.primary(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ModernSelectionCard(
            icon: IconsaxPlusLinear.woman,
            title: AppStrings.female,
            isSelected: _selectedGender == AppConstants.genderFemale,
            onTap: () =>
                setState(() => _selectedGender = AppConstants.genderFemale),
            color: const Color(0xFFE91E63),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Semantics(
          button: true,
          label: 'حفظ التغييرات',
          child: PrimaryGradientButton(
            onPressed: authProvider.isLoading ? null : _onSavePressed,
            text: 'حفظ التغييرات',
            isLoading: authProvider.isLoading,
            trailingIcon: IconsaxPlusLinear.arrow_left_2,
          ),
        );
      },
    );
  }
}
