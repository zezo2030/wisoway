import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/countries.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../l10n/l10n_extensions.dart';
import '../../widgets/common/form_components.dart';
import '../../widgets/country_code_picker.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  CountryData _selectedCountry = Countries.defaultCountry;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      _showSnackBar(context.l10n.selectGenderError, AppColors.error);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar(context.l10n.passwordsDoNotMatch, AppColors.error);
      return;
    }

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String role = args?['accountType'] ?? AppConstants.rolePassenger;

    String cleanedPhone = _phoneController.text.trim();
    if (!cleanedPhone.startsWith('+') && cleanedPhone.startsWith('0')) {
      cleanedPhone = cleanedPhone.substring(1);
    }
    final phoneNumber = '${_selectedCountry.dialCode}$cleanedPhone';

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().sendOTP(phoneNumber);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          RouteNames.otpVerification,
          arguments: {
            'phoneNumber': phoneNumber,
            'isRegistration': true,
            'role': role,
            'name': _nameController.text.trim(),
            'gender': _selectedGender,
            'password': _passwordController.text,
            'afterVerifyRoute': RouteNames.profileSetup,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String roleTitle = (args?['accountType'] == AppConstants.roleDriver)
        ? context.l10n.accountTypeDriver
        : context.l10n.accountTypePassenger;

    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            IconsaxPlusLinear.arrow_right_3,
            color: T.onSurface(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: T.primary(context).withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        // Header Icon Section
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: T
                                      .primary(context)
                                      .withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: T
                                      .primary(context)
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: T
                                          .primary(context)
                                          .withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  IconsaxPlusBold.user_add,
                                  size: 36,
                                  color: T.primary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          context.l10n.createNewAccount,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: T.onSurface(context),
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.signUpAs(roleTitle),
                          style: TextStyle(
                            fontSize: 15,
                            color: T.textSecondary(context),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // Form Fields
                        ModernInputField(
                          controller: _nameController,
                          label: context.l10n.fullName,
                          hint: context.l10n.fullNameHint,
                          icon: IconsaxPlusLinear.user,
                          validator: (v) => (v == null || v.trim().length < 3)
                              ? context.l10n.validNameRequired
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // Cohesive Phone Input
                        Container(
                          decoration: BoxDecoration(
                            color: T.surface(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: T.outline(context).withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.03),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CountryCodePicker(
                                selectedCountry: _selectedCountry,
                                onCountryChanged: (country) =>
                                    setState(() => _selectedCountry = country),
                                borderColor: Colors.transparent,
                                width: 110,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: T
                                    .outline(context)
                                    .withValues(alpha: 0.3),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: T.onSurface(context),
                                    letterSpacing: 1,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '123456789',
                                    hintStyle: TextStyle(
                                      color: T
                                          .onSurfaceVariant(context)
                                          .withValues(alpha: 0.4),
                                      fontSize: 16,
                                      letterSpacing: 1,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    prefixIcon: Icon(
                                      IconsaxPlusLinear.call,
                                      color: T.primary(context),
                                      size: 20,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return context.l10n.phoneNumberRequired;
                                    }
                                    if (!RegExp(r'^\d{7,15}$').hasMatch(
                                      v.replaceAll(RegExp(r'\s+'), ''),
                                    )) {
                                      return context.l10n.invalidPhoneNumber;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ModernInputField(
                          controller: _passwordController,
                          label: context.l10n.password,
                          hint: context.l10n.passwordHint,
                          icon: IconsaxPlusLinear.password_check,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return context.l10n.passwordRequired;
                            }
                            if (!RegExp(
                              r'^(?=.*[A-Za-z])(?=.*\d).{8,}$',
                            ).hasMatch(v)) {
                              return context.l10n.passwordPolicyError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ModernInputField(
                          controller: _confirmPasswordController,
                          label: context.l10n.confirmPassword,
                          hint: context.l10n.confirmPasswordHint,
                          icon: IconsaxPlusLinear.password_check,
                          obscureText: _obscureConfirmPassword,
                          textDirection: TextDirection.ltr,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return context.l10n.confirmPasswordRequired;
                            }
                            if (v != _passwordController.text) {
                              return context.l10n.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        SectionTitle(title: context.l10n.gender, isRequired: true),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ModernSelectionCard(
                                icon: IconsaxPlusLinear.man,
                                title: context.l10n.male,
                                isSelected:
                                    _selectedGender == AppConstants.genderMale,
                                onTap: () => setState(
                                  () =>
                                      _selectedGender = AppConstants.genderMale,
                                ),
                                color: T.primary(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ModernSelectionCard(
                                icon: IconsaxPlusLinear.woman,
                                title: context.l10n.female,
                                isSelected:
                                    _selectedGender ==
                                    AppConstants.genderFemale,
                                onTap: () => setState(
                                  () => _selectedGender =
                                      AppConstants.genderFemale,
                                ),
                                color: T.secondary(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),

                        PrimaryGradientButton(
                          onPressed: _isLoading ? null : _signUp,
                          text: AppConstants.skipOTP
                              ? context.l10n.createAccountDev
                              : context.l10n.sendOtpAndCreateAccount,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 32),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.alreadyHaveAccount,
                              style: TextStyle(
                                color: T.textSecondary(context),
                                fontSize: 15,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                RouteNames.signIn,
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: Text(
                                context.l10n.signIn,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: T.primary(context),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
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
}
