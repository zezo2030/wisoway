import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool _ar(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return _ar(context) ? 'يرجى إدخال كلمة المرور الجديدة' : 'Please enter new password';
    }
    if (value.length < 8) {
      return _ar(context)
          ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
          : 'Password must be at least 8 characters';
    }
    final hasLetter = value.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = value.contains(RegExp(r'\d'));
    if (!hasLetter || !hasDigit) {
      return _ar(context)
          ? 'كلمة المرور يجب أن تحتوي على حرف ورقم على الأقل'
          : 'Password must contain at least one letter and one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return _ar(context) ? 'يرجى تأكيد كلمة المرور' : 'Please confirm password';
    }
    if (value != _newPasswordController.text) {
      return _ar(context) ? 'كلمات المرور غير متطابقة' : 'Passwords do not match';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      await authService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (mounted) {
        final isArabic = _ar(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(IconsaxPlusBroken.tick_circle, color: T.success(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'تم تغيير كلمة المرور' : 'Password Changed',
                  ),
                ),
              ],
            ),
            content: Text(
              isArabic
                  ? 'تم تغيير كلمة المرور بنجاح. يرجى تسجيل الدخول مرة أخرى.'
                  : 'Your password has been changed successfully. Please sign in again.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    RouteNames.signIn,
                    (route) => false,
                  );
                },
                child: Text(isArabic ? 'حسناً' : 'OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isArabic = _ar(context);
        final message = _formatError(e, isArabic);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
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

  String _formatError(dynamic error, bool isArabic) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('social login') || msg.contains('social')) {
      return isArabic
          ? 'تغيير كلمة المرور غير متاح لحسابات تسجيل الدخول الاجتماعي'
          : 'Password change is not available for social login accounts';
    }
    if (msg.contains('current password') || msg.contains('incorrect')) {
      return isArabic
          ? 'كلمة المرور الحالية غير صحيحة'
          : 'Current password is incorrect';
    }
    if (msg.contains('different') || msg.contains('same')) {
      return isArabic
          ? 'كلمة المرور الجديدة يجب أن تكون مختلفة'
          : 'New password must be different from current password';
    }
    if (msg.contains('8 character') || msg.contains('weak') || msg.contains('letter')) {
      return isArabic
          ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل مع حرف ورقم'
          : 'Password must be at least 8 characters with one letter and one number';
    }
    return isArabic
        ? 'حدث خطأ. يرجى المحاولة مرة أخرى.'
        : 'An error occurred. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _ar(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'تغيير كلمة المرور' : 'Change Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isArabic
                      ? 'أدخل كلمة المرور الحالية وكلمة المرور الجديدة'
                      : 'Enter your current password and new password',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: T.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 24),
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: isArabic ? 'كلمة المرور الحالية' : 'Current Password',
                  obscureText: _obscureCurrentPassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: isArabic ? 'كلمة المرور الجديدة' : 'New Password',
                  obscureText: _obscureNewPassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                  validator: _validateNewPassword,
                  showStrengthIndicator: true,
                ),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: isArabic ? 'تأكيد كلمة المرور الجديدة' : 'Confirm New Password',
                  obscureText: _obscureConfirmPassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.primary(context),
                      foregroundColor: T.onPrimary(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                T.onPrimary(context),
                              ),
                            ),
                          )
                        : Text(
                            isArabic ? 'تغيير كلمة المرور' : 'Change Password',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
    bool showStrengthIndicator = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? IconsaxPlusBroken.eye_slash : IconsaxPlusBroken.eye,
                color: T.textSecondary(context),
              ),
              onPressed: onToggleVisibility,
            ),
          ),
          onChanged: showStrengthIndicator
              ? (value) => setState(() {})
              : null,
        ),
        if (showStrengthIndicator && controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildStrengthIndicator(controller.text),
          ),
      ],
    );
  }

  Widget _buildStrengthIndicator(String password) {
    final isArabic = _ar(context);
    final hasMinLength = password.length >= 8;
    final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    final strength = [hasMinLength, hasLetter, hasDigit].where((e) => e).length;

    final Color barColor;
    final String label;
    if (strength == 3) {
      barColor = T.success(context);
      label = isArabic ? 'قوية' : 'Strong';
    } else if (strength == 2) {
      barColor = AppColors.warning;
      label = isArabic ? 'متوسطة' : 'Medium';
    } else {
      barColor = T.error(context);
      label = isArabic ? 'ضعيفة' : 'Weak';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength / 3,
                backgroundColor: T.outlineVariant(context).withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isArabic
              ? 'يجب أن تكون 8 أحرف على الأقل مع حرف ورقم'
              : 'Must be at least 8 characters with one letter and one number',
          style: TextStyle(
            fontSize: 11,
            color: T.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
