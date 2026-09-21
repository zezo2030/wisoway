import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/countries.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../l10n/l10n_extensions.dart';
import '../../widgets/auth/auth_language_switcher.dart';
import '../../widgets/common/form_components.dart';
import '../../widgets/country_code_picker.dart';

/// Password sign-in, laid out to the VisionWay sign-in mockup: cityscape
/// header, brand lockup, phone + password fields, and the three trust badges
/// above the "new here?" bar.
///
/// Signing in is password-only. Phone verification still has its own entry
/// points — after a sign-in with an unverified phone, and from the profile and
/// security screens — so removing the OTP shortcut here does not strand anyone.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

/// The trust badges keep their own accents, matching the mockup.
const Color _trustedAccent = Color(0xFFE0A63C);
const Color _fastAccent = Color(0xFF7C5CBF);

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  CountryData _selectedCountry = Countries.defaultCountry;
  bool _isLoading = false;
  bool _obscurePassword = true;

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
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final phoneNumber = _phoneController.text.trim();

      String cleanedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+') && phoneNumber.startsWith('0')) {
        cleanedPhone = phoneNumber.substring(1);
      }

      final formattedPhone = '${_selectedCountry.dialCode}$cleanedPhone';

      await authProvider.signInWithPhoneAndPassword(
        phoneNumber: formattedPhone,
        password: _passwordController.text,
      );

      if (mounted) {
        final nextRoute = authProvider.userModel?.isPhoneVerified ?? false
            ? RouteNames.home
            : RouteNames.phoneAuth;
        Navigator.pushNamedAndRemoveUntil(
          context,
          nextRoute,
          (route) => false,
          arguments: nextRoute == RouteNames.phoneAuth
              ? {'isLinkPhone': true}
              : null,
        );
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

  Future<void> _handleForgotPassword() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      ErrorSurface.showInfo(context, context.l10n.phoneNumberFirst);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      String cleanedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+') && phoneNumber.startsWith('0')) {
        cleanedPhone = phoneNumber.substring(1);
      }
      final formattedPhone = '${_selectedCountry.dialCode}$cleanedPhone';

      await authProvider.forgotPassword(formattedPhone);
      if (mounted) {
        // OTP sent — open the reset flow (OTP entry → new password),
        // carrying the phone number so the code can be verified.
        Navigator.pushNamed(
          context,
          RouteNames.resetPassword,
          arguments: {'phoneNumber': formattedPhone},
        );
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
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: T.surface(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    T.primary(context).withValues(alpha: 0.05),
                    T.surface(context),
                    T.primary(context).withValues(alpha: 0.02),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Pale halo behind the language pill.
          Positioned(
            top: -110,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: T.primary(context).withValues(alpha: 0.06),
              ),
            ),
          ),

          // Cityscape + car header bleeding off the leading edge.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.6, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/illustrations/auth/auth_signin_header.png',
                width: screenWidth,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: const AuthLanguageSwitcher(),
                      ),
                      const SizedBox(height: 6),
                      _buildBrandLockup(),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.signInWelcomeBack,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: T.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.signInSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: T.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildPhoneField(),
                            const SizedBox(height: 14),
                            _buildPasswordField(),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : _handleForgotPassword,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    context.l10n.forgotPassword,
                                    style: TextStyle(
                                      color: T.primary(context),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            PrimaryGradientButton(
                              onPressed: _isLoading ? null : _handleSignIn,
                              text: context.l10n.signIn,
                              isLoading: _isLoading,
                              trailingIcon:
                                  Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? Icons.arrow_back_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                            const SizedBox(height: 22),
                            _buildTrustRow(),
                            const SizedBox(height: 18),
                            _buildSignUpBar(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandLockup() {
    return Column(
      children: [
        Image.asset(
          'assets/illustrations/auth/auth_visionway_logo.webp',
          height: 62,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 6),
        Text(
          'VisionWay',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          context.l10n.welcomeBrandTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: T.primary(context),
          ),
        ),
      ],
    );
  }

  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: T.surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: T.outline(context).withValues(alpha: 0.6)),
      boxShadow: [
        BoxShadow(
          color: T.shadow(context).withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  InputDecoration _fieldInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: T.onSurfaceVariant(context).withValues(alpha: 0.55),
        fontSize: 15,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 19),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: _fieldDecoration(),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(IconsaxPlusLinear.call, size: 20, color: T.primary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: T.onSurface(context),
              ),
              decoration: _fieldInputDecoration(context.l10n.phoneNumber),
              validator: (v) =>
                  (v == null || v.isEmpty) ? context.l10n.required : null,
            ),
          ),
          Container(width: 1, height: 26, color: T.outline(context)),
          CountryCodePicker(
            selectedCountry: _selectedCountry,
            onCountryChanged: (country) =>
                setState(() => _selectedCountry = country),
            borderColor: AppColors.transparent,
            width: 124,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: _fieldDecoration(),
      child: Row(
        children: [
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _obscurePassword
                    ? IconsaxPlusLinear.lock
                    : IconsaxPlusLinear.unlock,
                size: 20,
                color: T.primary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: T.onSurface(context),
              ),
              decoration: _fieldInputDecoration(context.l10n.password),
              validator: (v) => (v == null || v.length < 6)
                  ? context.l10n.passwordTooShort
                  : null,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildTrustRow() {
    final l10n = context.l10n;
    final separator = Container(
      width: 1,
      height: 40,
      color: T.outline(context),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _TrustBadge(
            icon: IconsaxPlusBold.medal_star,
            color: _trustedAccent,
            title: l10n.signInFeatureTrustedTitle,
            body: l10n.signInFeatureTrustedBody,
          ),
        ),
        separator,
        Expanded(
          child: _TrustBadge(
            icon: IconsaxPlusBold.flash_circle,
            color: _fastAccent,
            title: l10n.signInFeatureFastTitle,
            body: l10n.signInFeatureFastBody,
          ),
        ),
        separator,
        Expanded(
          child: _TrustBadge(
            icon: IconsaxPlusBold.shield_tick,
            color: T.primary(context),
            title: l10n.signInFeaturePrivacyTitle,
            body: l10n.signInFeaturePrivacyBody,
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: T.primary(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.signInNewUserQuestion,
            style: TextStyle(fontSize: 14, color: T.textSecondary(context)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(
              context,
              RouteNames.accountTypeSelection,
            ),
            child: Text(
              context.l10n.createNewAccount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: T.primary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the three accented badges above the sign-up bar.
class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: T.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 30, color: color),
      ],
    );
  }
}
