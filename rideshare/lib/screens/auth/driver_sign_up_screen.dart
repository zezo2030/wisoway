import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/countries.dart';
import '../../core/theme/colors.dart';
import '../../widgets/country_code_picker.dart';
import '../../core/utils/auth_error_formatter.dart';
import '../../widgets/common/form_components.dart';

class DriverSignUpScreen extends StatefulWidget {
  const DriverSignUpScreen({super.key});

  @override
  State<DriverSignUpScreen> createState() => _DriverSignUpScreenState();
}

class _DriverSignUpScreenState extends State<DriverSignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
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
    _firstNameController.dispose();
    _lastNameController.dispose();
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

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      final phoneNumber =
          '${_selectedCountry.dialCode}${_phoneController.text.trim()}';

      // 1. Create pending registration with phone verification
      await authProvider.signUpWithEmailAndPassword(
        name: fullName,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        role: AppConstants.roleDriver,
        gender: _selectedGender,
      );

      if (mounted) {
        // Navigate to OTP verification
        Navigator.pushReplacementNamed(
          context,
          RouteNames.otpVerification,
          arguments: {
            'phoneNumber': phoneNumber,
            'isRegistration': true,
            'role': AppConstants.roleDriver,
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
    return Scaffold(
      backgroundColor: T.surface(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ModernInputField(
                              controller: _firstNameController,
                              label: 'الاسم الأول',
                              hint: 'أحمد',
                              icon: IconsaxPlusLinear.user,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ModernInputField(
                              controller: _lastNameController,
                              label: 'اسم العائلة',
                              hint: 'علي',
                              icon: IconsaxPlusLinear.user,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'مطلوب' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ModernInputField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        hint: 'example@email.com',
                        icon: IconsaxPlusLinear.sms,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'بريد غير صحيح'
                            : null,
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CountryCodePicker(
                            selectedCountry: _selectedCountry,
                            onCountryChanged: (country) =>
                                setState(() => _selectedCountry = country),
                            borderColor: T
                                .secondary(context)
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 24),
                      const SectionTitle(title: 'الجنس', isRequired: true),
                      const SizedBox(height: 12),
                      _buildGenderSelection(),
                      const SizedBox(height: 32),
                      PrimaryGradientButton(
                        onPressed: _isLoading ? null : _signUp,
                        text: 'التالي (معلومات السيارة)',
                        isLoading: _isLoading,
                        color: T.secondary(context),
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [T.secondary(context), AppColors.teal700],
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
          const Icon(IconsaxPlusBold.driver, size: 60, color: AppColors.white),
          const SizedBox(height: 16),
          const Text(
            'تسجيل سائق جديد',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'الخطوة 1 من 2: المعلومات الأساسية',
              style: TextStyle(color: AppColors.white, fontSize: 13),
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
            color: T.secondary(context),
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
                color: T.secondary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
