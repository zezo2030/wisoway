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
import '../../widgets/auth/auth_hero.dart';
import '../../widgets/auth/auth_language_switcher.dart';
import '../../widgets/auth/auth_phone_field.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_step_indicator.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/gender_select_cards.dart';

/// The driver illustration puts its car in the middle band, so the ribbon is
/// cropped just below centre.
const Alignment _heroArtFocus = Alignment(0, 0.3);

/// Driver registration — step 1 of 3 (basic details).
///
/// The OTP screen that follows is *not* one of the three wizard steps: it only
/// verifies the phone and hands back a registration token. Steps 2 and 3 live
/// in [RouteNames.driverCompleteProfile].
class DriverSignUpScreen extends StatefulWidget {
  const DriverSignUpScreen({super.key});

  @override
  State<DriverSignUpScreen> createState() => _DriverSignUpScreenState();
}

class _DriverSignUpScreenState extends State<DriverSignUpScreen>
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
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
      _showSnackBar(context.l10n.selectGenderError, T.error(context));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phoneNumber = AuthPhoneField.composeE164(
        _selectedCountry,
        _phoneController.text,
      );

      await context.read<AuthProvider>().sendOTP(phoneNumber);

      if (mounted) {
        // Downstream (pending registration + register call) still works with a
        // first/last pair, so the single field is split on the first space.
        final fullName = _nameController.text.trim();
        final spaceIndex = fullName.indexOf(' ');

        Navigator.pushReplacementNamed(
          context,
          RouteNames.otpVerification,
          arguments: {
            'phoneNumber': phoneNumber,
            'isRegistration': true,
            'role': AppConstants.roleDriver,
            'name': fullName,
            'firstName': spaceIndex == -1
                ? fullName
                : fullName.substring(0, spaceIndex),
            'lastName': spaceIndex == -1
                ? ''
                : fullName.substring(spaceIndex + 1).trim(),
            'gender': _selectedGender,
            'password': _passwordController.text,
            'afterVerifyRoute': RouteNames.driverCompleteProfile,
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
      backgroundColor: AuthHero.backdrop,
      body: SingleChildScrollView(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildTopBar(),
              AuthHeroTitle(
                icon: IconsaxPlusBold.driving,
                title: l10n.driverSignupTitle,
                subtitle: l10n.driverSignupSubtitle,
              ),
              AuthHeroSheet(
                art: const AuthHeroArt(
                  asset:
                      'assets/illustrations/auth/auth_driver_step1_hero.webp',
                  focus: _heroArtFocus,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthStepIndicator(
                          currentStep: 1,
                          totalSteps: 3,
                          labels: [
                            l10n.authStepperBasicInfo,
                            l10n.authStepperIdDocs,
                            l10n.authStepperVehicleInfo,
                          ],
                        ),
                        const SizedBox(height: 22),
                        AuthTextField(
                          controller: _nameController,
                          label: l10n.fullName,
                          helper: l10n.fullNameIdHint,
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
                          helper: l10n.phoneConfirmCallHint,
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
                        GenderSelectCards(
                          label: l10n.genderRequiredLabel,
                          value: _selectedGender,
                          onChanged: (g) => setState(() => _selectedGender = g),
                        ),
                        const SizedBox(height: 26),
                        AuthPrimaryButton(
                          label: l10n.continueLabel,
                          loading: _isLoading,
                          pinnedArrow: true,
                          onPressed: _isLoading ? null : _signUp,
                        ),
                        const SizedBox(height: 12),
                        _buildSignInRow(),
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

  /// Back chevron and the language pill, on the hero's flat band.
  Widget _buildTopBar() {
    return ColoredBox(
      color: AuthHero.backdrop,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          // The mockup pins this bar physically in both locales: the back
          // chevron on the left, the language pill on the right.
          child: Row(
            textDirection: TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                // chevron_left_rounded carries matchTextDirection, so it needs
                // an explicit LTR scope to keep pointing left under Arabic.
                icon: const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Icon(Icons.chevron_left_rounded, color: AuthHero.ink),
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
              const AuthLanguageSwitcher(),
            ],
          ),
        ),
      ),
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
