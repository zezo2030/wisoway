import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/ui/error_surface.dart';
import '../../../core/api/api_client.dart';
import '../../l10n/l10n_extensions.dart';

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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.enterNewPassword;
    }
    if (value.length < 8) {
      return context.l10n.passwordTooShort;
    }
    final hasLetter = value.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = value.contains(RegExp(r'\d'));
    if (!hasLetter || !hasDigit) {
      return context.l10n.passwordPolicyError;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.confirmPasswordRequired;
    }
    if (value != _newPasswordController.text) {
      return context.l10n.passwordsDoNotMatch;
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
                  child: Text(ctx.l10n.passwordChangedTitle),
                ),
              ],
            ),
            content: Text(ctx.l10n.passwordChangedMessage),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    RouteNames.signIn,
                    (route) => false,
                  );
                },
                child: Text(ctx.l10n.ok),
              ),
            ],
          ),
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
      appBar: AppBar(
        title: Text(context.l10n.changePassword),
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
                  context.l10n.changePasswordSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: T.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 24),
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: context.l10n.currentPassword,
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
                  label: context.l10n.newPassword,
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
                  label: context.l10n.confirmNewPassword,
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
                            context.l10n.changePassword,
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
    final hasMinLength = password.length >= 8;
    final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    final strength = [hasMinLength, hasLetter, hasDigit].where((e) => e).length;

    final Color barColor;
    final String label;
    if (strength == 3) {
      barColor = T.success(context);
      label = context.l10n.passwordStrengthStrong;
    } else if (strength == 2) {
      barColor = AppColors.warning;
      label = context.l10n.passwordStrengthMedium;
    } else {
      barColor = T.error(context);
      label = context.l10n.passwordStrengthWeak;
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
          context.l10n.passwordPolicyHint,
          style: TextStyle(
            fontSize: 11,
            color: T.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
