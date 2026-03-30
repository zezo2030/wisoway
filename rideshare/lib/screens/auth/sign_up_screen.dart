import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/countries.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/auth_error_formatter.dart';
import '../../widgets/common/form_components.dart';
import '../../widgets/country_code_picker.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedGender;
  CountryData _selectedCountry = Countries.defaultCountry;
  bool _isLoading = false;
  bool _obscurePassword = true;

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
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      _showSnackBar('يرجى اختيار الجنس', T.error(context));
      return;
    }

    // Capture role from arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String role = args?['accountType'] ?? AppConstants.rolePassenger;

    // Build full phone number
    final phoneNumber =
        '${_selectedCountry.dialCode}${_phoneController.text.trim()}';

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // 1. Create pending registration with phone verification
      await authProvider.signUpWithEmailAndPassword(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: phoneNumber,
        role: role,
        gender: _selectedGender,
      );

      // 2. Navigate to OTP verification screen
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          RouteNames.otpVerification,
          arguments: {
            'phoneNumber': phoneNumber,
            'isRegistration': true,
            'role': role,
          },
        );
      }
    } catch (e) {
      _showSnackBar(
        AuthErrorFormatter.format(e, action: AuthAction.signUp),
        T.error(context),
      );
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
        ? 'سائق'
        : 'راكب';

    return Scaffold(
      backgroundColor: T.surface(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _buildHeader(roleTitle),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ModernInputField(
                          controller: _nameController,
                          label: 'الاسم الكامل',
                          hint: 'أدخل اسمك بالكامل',
                          icon: IconsaxPlusLinear.user,
                          validator: (v) => (v == null || v.length < 3)
                              ? 'يرجى إدخال اسم صحيح'
                              : null,
                      ),
                      const SizedBox(height: 16),
                      ModernInputField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        hint: 'example@email.com',
                        icon: IconsaxPlusLinear.sms,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'بريد إلكتروني غير صحيح'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CountryCodePicker(
                            selectedCountry: _selectedCountry,
                            onCountryChanged: (country) =>
                                setState(() => _selectedCountry = country),
                            borderColor: T
                                .primary(context)
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 12),
                          // Phone number input
                          Expanded(
                            child: ModernInputField(
                              controller: _phoneController,
                              label: 'رقم الهاتف',
                              hint: '1234567890',
                              icon: IconsaxPlusLinear.call,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'يرجى إدخال رقم الهاتف';
                                }
                                if (!RegExp(r'^\d{7,15}$').hasMatch(v)) {
                                  return 'رقم هاتف غير صحيح';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ModernInputField(
                        controller: _passwordController,
                        label: 'كلمة المرور',
                        hint: '********',
                        icon: IconsaxPlusLinear.lock,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? IconsaxPlusLinear.eye_slash
                                : IconsaxPlusLinear.eye,
                          ),
                          tooltip: 'إظهار/إخفاء كلمة المرور',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8)
                            ? '8 أحرف على الأقل'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      const SectionTitle(title: 'الجنس', isRequired: true),
                      const SizedBox(height: 12),
                      _buildGenderSelection(),
                      const SizedBox(height: 32),
                      PrimaryGradientButton(
                        onPressed: _isLoading ? null : _signUp,
                        text: 'إنشاء حساب $roleTitle',
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(),
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

  Widget _buildHeader(String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            T.primary(context),
            T.primary(context).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            IconsaxPlusBold.user_add,
            size: 60,
            color: AppColors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            'إنشاء حساب جديد',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'سجل الآن كـ $role وابدأ رحلتك',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.white.withValues(alpha: 0.2),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelection() {
    return Row(
      children: [
        Expanded(
          child: ModernSelectionCard(
            icon: IconsaxPlusLinear.man,
            title: 'ذكر',
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
            title: 'أنثى',
            isSelected: _selectedGender == AppConstants.genderFemale,
            onTap: () =>
                setState(() => _selectedGender = AppConstants.genderFemale),
            color: T.error(context),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'لديك حساب بالفعل؟ ',
          style: TextStyle(color: T.onSurfaceVariant(context)),
        ),
        Semantics(
          button: true,
          label: 'تسجيل الدخول',
          child: TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, RouteNames.signIn),
            child: Text(
              'تسجيل الدخول',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: T.primary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
