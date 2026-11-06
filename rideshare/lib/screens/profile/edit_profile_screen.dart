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
import '../../l10n/l10n_extensions.dart';
import '../../core/api/api_client.dart';
import '../../core/ui/error_surface.dart';
import '../../utils/email_format.dart';
import '../../utils/western_digits.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cliqAliasController = TextEditingController();
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
    _emailController.dispose();
    _cliqAliasController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _nameController.text = user.name;
      _selectedGender = user.hasChosenGender ? user.gender : null;
      _currentPhotoUrl = user.photoUrl;
      _hidePhoneNumber = user.hidePhoneNumber;
      _cliqAliasController.text = user.cliqAlias ?? '';
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
              title: Text(context.l10n.gallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(IconsaxPlusLinear.camera),
              title: Text(context.l10n.camera),
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
        email: _emailController.text.trim(),
        gender: _selectedGender,
        role: authProvider.userModel?.role ?? AppConstants.rolePassenger,
        profileImage: _profileImage,
        hidePhoneNumber: authProvider.userModel?.isDriver == true
            ? false
            : _hidePhoneNumber,
        // Passengers only (drivers are paid into their wallet).
        cliqAlias: authProvider.userModel?.isDriver == true
            ? null
            : toWesternDigits(_cliqAliasController.text.trim()),
      );

      if (mounted) {
        _showSnackBar(context.l10n.profileUpdatedSuccess, AppColors.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
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
            tooltip: context.l10n.back,
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
            context.l10n.editProfileTitle,
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
          label: context.l10n.chooseProfilePhoto,
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
            label: context.l10n.changeProfilePhoto,
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

  Widget _buildLockedField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
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
            child: Icon(icon, color: T.primary(context), size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
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
    );
  }

  Widget _buildFormFields() {
    final user = context.watch<AuthProvider>().userModel;

    return Column(
      children: [
        // Fixed at registration, except a phone number standing in for a name.
        if (user != null && user.name != user.phoneNumber)
          _buildLockedField(
            label: AppStrings.fullName,
            value: user.name,
            icon: IconsaxPlusLinear.user,
          )
        else
          ModernInputField(
            controller: _nameController,
            label: AppStrings.fullName,
            hint: AppStrings.fullNameHint,
            icon: IconsaxPlusLinear.user,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.nameRequired
                : null,
          ),
        const SizedBox(height: 20),
        if ((user?.email ?? '').isNotEmpty)
          _buildLockedField(
            label: AppStrings.email,
            value: user!.email,
            icon: IconsaxPlusLinear.sms,
          )
        else
          ModernInputField(
            controller: _emailController,
            label: AppStrings.email,
            hint: AppStrings.emailHint,
            icon: IconsaxPlusLinear.sms,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            validator: (v) {
              final text = v?.trim() ?? '';
              return text.isEmpty || isValidEmail(text)
                  ? null
                  : AppStrings.emailInvalid;
            },
          ),
        // Fixed once set: it decides seat placement, and the server refuses it.
        if (user != null && user.hasChosenGender) ...[
          const SizedBox(height: 20),
          _buildLockedField(
            label: AppStrings.gender,
            value: user.isFemale ? AppStrings.female : AppStrings.male,
            icon: user.isFemale
                ? IconsaxPlusLinear.woman
                : IconsaxPlusLinear.man,
          ),
        ] else ...[
          const SizedBox(height: 28),
          const SectionTitle(title: AppStrings.gender, isRequired: true),
          const SizedBox(height: 12),
          _buildGenderCards(),
        ],
        // Passengers only: a passenger must always be able to call the driver.
        if (user != null && !user.isDriver) ...[
          const SizedBox(height: 28),
          _buildHidePhoneToggle(),
        ],
        // Where CliQ fare requests go when the passenger pays by CliQ.
        if (user != null && !user.isDriver) ...[
          const SizedBox(height: 28),
          ModernInputField(
            controller: _cliqAliasController,
            label: context.l10n.cliqPayerAliasLabel,
            hint: context.l10n.cliqPayerAliasHint,
            icon: IconsaxPlusLinear.wallet_money,
            textDirection: TextDirection.ltr,
            validator: (v) {
              final text = toWesternDigits(v?.trim() ?? '');
              if (text.isEmpty) return null;
              return RegExp(r'^[A-Za-z0-9._@\-+ ]{3,100}$').hasMatch(text)
                  ? null
                  : context.l10n.cliqAliasInvalid;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context.l10n.cliqPayerAliasHelp,
              style: TextStyle(
                fontSize: 12,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ),
        ],
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
        label: context.l10n.hidePhoneFromDriver,
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
            context.l10n.hidePhoneNumberToggle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: T.onSurface(context),
            ),
          ),
          subtitle: Text(
            context.l10n.hidePhoneNumberSubtitle,
            style: TextStyle(fontSize: 12, color: T.onSurfaceVariant(context)),
          ),
          value: _hidePhoneNumber,
          onChanged: (val) => setState(() => _hidePhoneNumber = val),
          activeThumbColor: T.primary(context),
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
          label: context.l10n.saveChanges,
          child: PrimaryGradientButton(
            onPressed: authProvider.isLoading ? null : _onSavePressed,
            text: context.l10n.saveChanges,
            isLoading: authProvider.isLoading,
            trailingIcon: IconsaxPlusLinear.arrow_left_2,
          ),
        );
      },
    );
  }
}
