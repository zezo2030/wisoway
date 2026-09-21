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
import '../../widgets/auth/auth_phone_field.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_step_indicator.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/gender_select_cards.dart';

/// Passenger registration — step 1 of 3 (basic details).
///
/// Steps: 1 this screen → 2 OTP → 3 photo + city. The step metadata travels
/// with the navigation arguments so the OTP screen can render the same chrome.
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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
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

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String role = args?['accountType'] ?? AppConstants.rolePassenger;
    final phoneNumber = AuthPhoneField.composeE164(
      _selectedCountry,
      _phoneController.text,
    );

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
            'accountType': role,
            'name': _nameController.text.trim(),
            'gender': _selectedGender,
            'password': _passwordController.text,
            'afterVerifyRoute': RouteNames.profileSetup,
            // Renders the same 1/2/3 chrome on the OTP screen.
            'authStep': 2,
            'authTotalSteps': 3,
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
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: T.surface(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(),
                  _buildHero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthTextField(
                          controller: _nameController,
                          label: l10n.fullName,
                          hint: l10n.fullNameHint,
                          icon: IconsaxPlusLinear.user,
                          validator: (v) => (v == null || v.trim().length < 3)
                              ? l10n.validNameRequired
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AuthPhoneField(
                          controller: _phoneController,
                          country: _selectedCountry,
                          onCountryChanged: (c) =>
                              setState(() => _selectedCountry = c),
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _passwordController,
                          label: l10n.password,
                          helper: l10n.passwordMinLengthHint,
                          icon: IconsaxPlusLinear.lock,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          suffix: _visibilityToggle(
                            obscured: _obscurePassword,
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return l10n.passwordRequired;
                            }
                            if (!RegExp(
                              r'^(?=.*[A-Za-z])(?=.*\d).{8,}$',
                            ).hasMatch(v)) {
                              return l10n.passwordPolicyError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _confirmPasswordController,
                          label: l10n.confirmPassword,
                          helper: l10n.confirmPasswordReenterHint,
                          icon: IconsaxPlusLinear.lock,
                          obscureText: _obscureConfirmPassword,
                          textDirection: TextDirection.ltr,
                          suffix: _visibilityToggle(
                            obscured: _obscureConfirmPassword,
                            onTap: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return l10n.confirmPasswordRequired;
                            }
                            if (v != _passwordController.text) {
                              return l10n.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l10n.genderRequiredLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: T.onSurface(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GenderSelectCards(
                          value: _selectedGender,
                          onChanged: (g) => setState(() => _selectedGender = g),
                        ),
                        const SizedBox(height: 26),
                        AuthPrimaryButton(
                          label: l10n.continueLabel,
                          loading: _isLoading,
                          onPressed: _isLoading ? null : _signUp,
                        ),
                        const SizedBox(height: 14),
                        _buildSignInRow(),
                      ],
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              color: T.onSurface(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: AuthStepIndicator(currentStep: 1, totalSteps: 3),
            ),
          ),
          Text(
            context.l10n.authStepOf(1, 3),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: T.primary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0.9,
          child: Image.asset(
            'assets/illustrations/auth/auth_passenger_signup_hero.png',
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.passengerSignupTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: T.onSurface(context),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                context.l10n.passengerSignupSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: T.onSurfaceVariant(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _visibilityToggle({
    required bool obscured,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: T.onSurfaceVariant(context),
      ),
    );
  }

  Widget _buildSignInRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.alreadyHaveAccount,
          style: TextStyle(color: T.onSurfaceVariant(context), fontSize: 14),
        ),
        Semantics(
          button: true,
          label: context.l10n.signIn,
          child: TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, RouteNames.signIn),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(
              context.l10n.signIn,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: T.primary(context),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
