import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../core/services/localization_service.dart';
import '../../core/theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/form_components.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _errorMessage(Object e, bool isArabic) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    if (!isArabic) return raw;
    if (raw.contains('Current password is incorrect')) {
      return 'كلمة المرور الحالية غير صحيحة.';
    }
    if (raw.contains('no password')) {
      return 'هذا الحساب لا يملك كلمة مرور. سجّل الدخول بالطريقة التي سجّلت بها.';
    }
    if (raw.contains('different from the current')) {
      return 'يجب أن تختلف كلمة المرور الجديدة عن الحالية.';
    }
    if (raw.contains('at least 8')) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
    }
    return raw;
  }

  Future<void> _submit(bool isArabic) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'تم تغيير كلمة المرور بنجاح' : 'Password updated',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(e, isArabic)),
          backgroundColor: T.error(context),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    final isArabic = localization.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'تغيير كلمة المرور' : 'Change Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ModernInputField(
                controller: _currentController,
                label: isArabic ? 'كلمة المرور الحالية' : 'Current password',
                hint: '••••••••',
                icon: IconsaxPlusBroken.lock,
                obscureText: _obscureCurrent,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent
                        ? IconsaxPlusBroken.eye_slash
                        : IconsaxPlusBroken.eye,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return isArabic
                        ? 'أدخل كلمة المرور الحالية'
                        : 'Enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ModernInputField(
                controller: _newController,
                label: isArabic ? 'كلمة المرور الجديدة' : 'New password',
                hint: '••••••••',
                icon: IconsaxPlusBroken.lock,
                obscureText: _obscureNew,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew
                        ? IconsaxPlusBroken.eye_slash
                        : IconsaxPlusBroken.eye,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return isArabic
                        ? '8 أحرف على الأقل'
                        : 'At least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ModernInputField(
                controller: _confirmController,
                label: isArabic ? 'تأكيد كلمة المرور' : 'Confirm new password',
                hint: '••••••••',
                icon: IconsaxPlusBroken.lock,
                obscureText: _obscureConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? IconsaxPlusBroken.eye_slash
                        : IconsaxPlusBroken.eye,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (v) {
                  if (v != _newController.text) {
                    return isArabic
                        ? 'غير متطابقة مع كلمة المرور الجديدة'
                        : 'Does not match new password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _submitting ? null : () => _submit(isArabic),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isArabic ? 'حفظ كلمة المرور' : 'Update password',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
