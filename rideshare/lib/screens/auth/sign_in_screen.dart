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
import '../../widgets/common/form_components.dart';
import '../../widgets/country_code_picker.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

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
        ErrorSurface.showSuccess(
          context,
          context.l10n.passwordResetLinkSent,
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
                    vertical: 10.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Compact Header
                        Center(
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: T.primary(context).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              IconsaxPlusBold.login,
                              size: 30,
                              color: T.primary(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.signIn,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: T.onSurface(context),
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.signInSubtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: T.textSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Phone Input
                        Container(
                          decoration: BoxDecoration(
                            color: T.surface(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: T.outline(context).withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CountryCodePicker(
                                selectedCountry: _selectedCountry,
                                onCountryChanged: (country) =>
                                    setState(() => _selectedCountry = country),
                                borderColor: Colors.transparent,
                                width: 100,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: T.onSurface(context),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.l10n.phoneNumber,
                                    hintStyle: TextStyle(
                                      color: T
                                          .onSurfaceVariant(context)
                                          .withValues(alpha: 0.4),
                                      fontSize: 14,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(
                                      IconsaxPlusLinear.call,
                                      color: T.primary(context),
                                      size: 18,
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? context.l10n.required : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        ModernInputField(
                          controller: _passwordController,
                          label: context.l10n.password,
                          hint: '••••••••',
                          icon: IconsaxPlusLinear.lock,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? IconsaxPlusLinear.eye_slash
                                  : IconsaxPlusLinear.eye,
                              size: 20,
                              color: T.onSurfaceVariant(context),
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? context.l10n.passwordTooShort
                              : null,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _handleForgotPassword,
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

                        const SizedBox(height: 16),

                        // Login Button
                        PrimaryGradientButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          text: context.l10n.signIn,
                          isLoading: _isLoading,
                        ),

                        const SizedBox(height: 24),

                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.noAccountQuestion,
                              style: TextStyle(
                                color: T.textSecondary(context),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                RouteNames.accountTypeSelection,
                              ),
                              child: Text(
                                context.l10n.createNewAccount,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: T.primary(context),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
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
