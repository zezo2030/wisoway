import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/auth_error_formatter.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        final hasProfile = authProvider.hasProfile;
        final isPhoneVerified =
            authProvider.userModel?.isPhoneVerified ?? false;
        if (!hasProfile) {
          Navigator.pushReplacementNamed(context, RouteNames.profileSetup);
        } else if (!isPhoneVerified) {
          Navigator.pushReplacementNamed(
            context,
            RouteNames.phoneAuth,
            arguments: {'isLinkPhone': true},
          );
        } else {
          Navigator.pushReplacementNamed(context, RouteNames.home);
        }
      }
    } catch (e) {
      if (mounted) {
        if (AuthErrorFormatter.isPhoneVerificationRequired(e)) {
          Navigator.pushReplacementNamed(
            context,
            RouteNames.phoneAuth,
            arguments: {'isLinkPhone': true},
          );
          return;
        }

        final msg = AuthErrorFormatter.format(e, action: AuthAction.signIn);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: T.error(context),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: T.surface(context),
      body: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -size.width * 0.4,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    T.primary(context).withValues(alpha: 0.2),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    AppColors.teal700.withValues(alpha: 0.15),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo/Icon Section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: T.surface(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: T
                                    .primary(context)
                                    .withValues(alpha: 0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.directions_car_rounded,
                            size: 64,
                            color: T.primary(context),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'مرحباً بعودتك!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: T.onSurface(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سجل دخولك للاستمرار في رحلتك',
                          style: TextStyle(
                            fontSize: 16,
                            color: T.onSurfaceVariant(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Form Section
                        Container(
                          decoration: BoxDecoration(
                            color: T.surface(context),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                  label: 'البريد الإلكتروني',
                                  textField: true,
                                  child: TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: T.onSurfaceVariant(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'البريد الإلكتروني',
                                      labelStyle: TextStyle(
                                        color: T.outlineVariant(context),
                                      ),
                                      hintText: 'example@email.com',
                                      hintStyle: TextStyle(
                                        color: T.outlineVariant(context),
                                      ),
                                      filled: true,
                                      fillColor: T.surface(context),
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: T.primary(context),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: T.primary(context),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال البريد الإلكتروني';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Semantics(
                                  label: 'كلمة المرور',
                                  textField: true,
                                  child: TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: T.onSurfaceVariant(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'كلمة المرور',
                                      labelStyle: TextStyle(
                                        color: T.outlineVariant(context),
                                      ),
                                      filled: true,
                                      fillColor: T.surface(context),
                                      prefixIcon: Icon(
                                        Icons.lock_outline_rounded,
                                        color: T.primary(context),
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: 'إظهار/إخفاء كلمة المرور',
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: T.outlineVariant(context),
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          );
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: T.primary(context),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال كلمة المرور';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Forgot Password Link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        RouteNames.forgotPassword,
                                      );
                                    },
                                    child: Text(
                                      AppStrings.forgotPassword,
                                      style: TextStyle(
                                        color: T.textSecondary(context),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: [
                                        T.primary(context),
                                        T
                                            .primary(context)
                                            .withValues(alpha: 0.7),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: T
                                            .primary(context)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Semantics(
                                    button: true,
                                    label: 'تسجيل الدخول',
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _signInWithEmail,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.transparent,
                                        shadowColor: AppColors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(AppColors.white),
                                              ),
                                            )
                                          : Text(
                                              'تسجيل الدخول',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ليس لديك حساب؟ ',
                              style: TextStyle(
                                color: T.onSurfaceVariant(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'إنشاء حساب جديد',
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    RouteNames.accountTypeSelection,
                                  );
                                },
                                child: Text(
                                  'إنشاء حساب جديد',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: T.primary(context),
                                  ),
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
