import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/colors.dart';
import '../../widgets/common/form_components.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedGender;
  String? _selectedRole;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. Data from User Model (Backend integration)
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.userModel;

      if (user != null) {
        if (user.name.isNotEmpty && _nameController.text.isEmpty) {
          _nameController.text = user.name;
        }
        if (user.email.isNotEmpty && _emailController.text.isEmpty) {
          _emailController.text = user.email;
        }
      }

      // 2. Data from Navigation Arguments (e.g. Sign Up flow fallback)
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        if (args['name'] != null) _nameController.text = args['name'];
        if (args['email'] != null) _emailController.text = args['email'];
        if (args['gender'] != null) _selectedGender = args['gender'];
        if (args['role'] != null) _selectedRole = args['role'];
        setState(() {});
      }
    });
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      _showSnackBar(AppStrings.genderRequired, AppColors.warning);
      return;
    }
    if (_selectedRole == null) {
      _showSnackBar(AppStrings.userTypeRequired, AppColors.warning);
      return;
    }

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final phoneNumber = args?['phoneNumber'];

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.saveUserProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        gender: _selectedGender!,
        role: _selectedRole!,
        phoneNumber: phoneNumber != null ? phoneNumber as String : null,
      );

      if (mounted) {
        if (_selectedRole == AppConstants.roleDriver) {
          Navigator.pushReplacementNamed(
            context,
            RouteNames.driverCompleteProfile,
          );
        } else {
          await authProvider.loadUserProfile();
          if (mounted && !(authProvider.userModel?.isPhoneVerified ?? true)) {
            Navigator.pushReplacementNamed(
              context,
              RouteNames.phoneAuth,
              arguments: {'isLinkPhone': true},
            );
          } else if (mounted) {
            Navigator.pushReplacementNamed(context, RouteNames.home);
          }
        }
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
      backgroundColor: T.surface(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),
                        _buildFields(),
                        const SizedBox(height: 40),
                        _buildSubmitButton(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 40, bottom: 32),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  T.primary(context),
                  T.primary(context).withValues(alpha: 0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: T.primary(context).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              IconsaxPlusBold.user_edit,
              size: 48,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            AppStrings.profileSetupTitle,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.profileSetupSubtitle,
            style: TextStyle(color: T.onSurfaceVariant(context), fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final userModel = authProvider.userModel;

        final bool isEmailFixed =
            userModel != null && userModel.email.isNotEmpty;
        final bool isNameFixed = userModel != null && userModel.name.isNotEmpty;

        return Column(
          children: [
            ModernInputField(
              controller: _nameController,
              label: AppStrings.fullName,
              hint: AppStrings.fullNameHint,
              icon: IconsaxPlusLinear.user,
              readOnly: isNameFixed,
              enabled: !isNameFixed,
              validator: (v) =>
                  (v == null || v.isEmpty) ? AppStrings.nameRequired : null,
            ),
            const SizedBox(height: 20),
            ModernInputField(
              controller: _emailController,
              label: AppStrings.email,
              hint: AppStrings.emailHint,
              icon: IconsaxPlusLinear.sms,
              keyboardType: TextInputType.emailAddress,
              readOnly: isEmailFixed,
              enabled: !isEmailFixed,
              validator: (v) => (v == null || !v.contains('@'))
                  ? AppStrings.emailInvalid
                  : null,
            ),
            const SizedBox(height: 28),
            const SectionTitle(title: AppStrings.gender, isRequired: true),
            const SizedBox(height: 12),
            _buildGenderCards(),
            const SizedBox(height: 28),
            if (_selectedRole == null) ...[
              const SectionTitle(title: AppStrings.userType, isRequired: true),
              const SizedBox(height: 12),
              _buildRoleCards(),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      IconsaxPlusLinear.info_circle,
                      color: T.primary(context),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'لقد اخترت دور: ${_selectedRole == AppConstants.roleDriver ? AppStrings.tripOwner : AppStrings.passenger}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: T.primary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
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
            color: T.error(context),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCards() {
    return Column(
      children: [
        ModernSelectionCard(
          icon: IconsaxPlusLinear.user,
          title: AppStrings.passenger,
          subtitle: AppStrings.passengerDescription,
          isSelected: _selectedRole == AppConstants.rolePassenger,
          onTap: () =>
              setState(() => _selectedRole = AppConstants.rolePassenger),
          color: T.primary(context),
          isVertical: false,
        ),
        const SizedBox(height: 12),
        ModernSelectionCard(
          icon: IconsaxPlusLinear.car,
          title: AppStrings.tripOwner,
          subtitle: AppStrings.tripOwnerDescription,
          isSelected: _selectedRole == AppConstants.roleDriver,
          onTap: () => setState(() => _selectedRole = AppConstants.roleDriver),
          color: T.primary(context),
          isVertical: false,
        ),
        if (_selectedRole == AppConstants.roleDriver)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: InfoCard(message: AppStrings.tripOwnerNote),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final bool isLoading = authProvider.isLoading;
        return PrimaryGradientButton(
          onPressed: isLoading ? null : _onSavePressed,
          text: AppStrings.saveAndComplete,
          isLoading: isLoading,
          trailingIcon: IconsaxPlusLinear.arrow_left_2,
        );
      },
    );
  }
}
