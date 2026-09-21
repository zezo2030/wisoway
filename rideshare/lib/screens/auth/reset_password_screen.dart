import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../l10n/l10n_extensions.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final PageController _pageController = PageController();
  final _passwordFormKey = GlobalKey<FormState>();
  final _otpControllers = List.generate(
    AppConstants.otpLength,
    (_) => TextEditingController(),
  );
  final _otpFocusNodes = List.generate(
    AppConstants.otpLength,
    (_) => FocusNode(),
  );
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _phoneNumber;
  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = AppConstants.otpResendTimeout;
  Timer? _timer;
  String? _resetToken;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNodes[0].requestFocus();
      _extractPhoneNumber();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _extractPhoneNumber() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _phoneNumber = args?['phoneNumber'] as String?;
    if (_phoneNumber == null) {
      // If no phone number provided, go back to forgot password
      Navigator.pushReplacementNamed(context, RouteNames.forgotPassword);
    }
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String) return message;
        if (message is List && message.isNotEmpty) {
          final first = message.first;
          if (first is String) return first;
        }
      }
    }
    final msg = error.toString();
    if (msg.contains('Exception: ')) {
      return msg.replaceFirst('Exception: ', '');
    }
    return msg;
  }

  void _startResendTimer() {
    _canResend = false;
    _resendTimer = AppConstants.otpResendTimeout;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _onOTPChanged(int index, String value) {
    if (value.length == 1) {
      if (index < AppConstants.otpLength - 1) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        _verifyOTP();
      }
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  String _getOTPCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOTP() async {
    final otpCode = _getOTPCode();
    if (otpCode.length != AppConstants.otpLength || _phoneNumber == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _resetToken = await authProvider.verifyResetOtp(_phoneNumber!, otpCode);

      if (mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = _extractErrorMessage(e).toLowerCase();
        if (errorMsg.contains('too many attempts') ||
            errorMsg.contains('locked')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.otpTooManyAttempts),
              backgroundColor: T.error(context),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: context.l10n.requestNewCode,
                textColor: T.onPrimary(context),
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    RouteNames.forgotPassword,
                  );
                },
              ),
            ),
          );
        } else if (errorMsg.contains('expired')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.otpExpired),
              backgroundColor: T.error(context),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: context.l10n.requestNewCode,
                textColor: T.onPrimary(context),
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    RouteNames.forgotPassword,
                  );
                },
              ),
            ),
          );
        } else {
          ErrorSurface.showFailure(context, ApiClient.mapError(e));
        }
        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend || _phoneNumber == null) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.forgotPassword(_phoneNumber!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.newOtpSent),
            backgroundColor: AppColors.success,
          ),
        );
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        final retryAfter = _extractRetryAfter(e);
        if (retryAfter != null) {
          setState(() {
            _canResend = false;
            _resendTimer = retryAfter;
          });
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) {
              setState(() {
                if (_resendTimer > 0) {
                  _resendTimer--;
                } else {
                  _canResend = true;
                  timer.cancel();
                }
              });
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.waitBeforeResend(_resendTimer)),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ErrorSurface.showFailure(context, ApiClient.mapError(e));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int? _extractRetryAfter(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final retryAfter = data['retryAfter'];
        if (retryAfter is int && retryAfter > 0) {
          return retryAfter;
        }
        if (retryAfter is double && retryAfter > 0) {
          return retryAfter.ceil();
        }
      }
    }
    final msg = error.toString().toLowerCase();
    if (msg.contains('429') ||
        msg.contains('too many requests') ||
        msg.contains('wait')) {
      final match = RegExp(r'retryafter["\s:]+(\d+)').firstMatch(msg);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  Future<void> _resetPassword() async {
    if (_resetToken == null) return;

    // Run the field validators (min length + letter/number policy + match)
    // so the user gets inline, localized errors before we hit the server.
    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.resetPassword(_resetToken!, _passwordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.passwordResetSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate to sign in screen
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.signIn,
          (route) => false,
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
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: T.onSurface(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [_buildOTPVerificationStep(), _buildPasswordResetStep()],
        ),
      ),
    );
  }

  Widget _buildOTPVerificationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: T.surface(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: T.primary(context).withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.sms, size: 64, color: T.primary(context)),
          ),
          const SizedBox(height: 32),

          Text(
            context.l10n.enterOTP,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: T.onSurface(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.otpSentToYourPhone,
            style: TextStyle(fontSize: 16, color: T.onSurfaceVariant(context)),
            textAlign: TextAlign.center,
          ),
          if (_phoneNumber != null) ...[
            const SizedBox(height: 8),
            Text(
              _phoneNumber!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: T.primary(context),
              ),
            ),
          ],
          const SizedBox(height: 40),

          // OTP Input Fields
          Row(
            // Keep the OTP digits ordered left-to-right even in RTL (Arabic)
            // so the code reads in entry order.
            textDirection: TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              AppConstants.otpLength,
              (index) => Expanded(
                child: Container(
                  height: 48,
                  constraints: const BoxConstraints(maxWidth: 48),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: T.surfaceVariant(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: T.primary(context),
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) => _onOTPChanged(index, value),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Resend Timer/Button
          if (_canResend)
            TextButton(
              onPressed: _isLoading ? null : _resendOTP,
              child: Text(
                context.l10n.resendCode,
                style: TextStyle(
                  color: T.primary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Text(
              context.l10n.resendCodeIn(_resendTimer),
              style: TextStyle(
                color: T.onSurfaceVariant(context),
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordResetStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: T.surface(context),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: T.primary(context).withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.lock_reset,
                size: 64,
                color: T.primary(context),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              context.l10n.resetPasswordTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: T.onSurface(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // New Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.newPassword,
                filled: true,
                fillColor: T.surfaceVariant(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: T.primary(context), width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.newPasswordRequired;
                }
                if (value.length < 8) {
                  return context.l10n.passwordTooShort;
                }
                final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
                final hasNumber = RegExp(r'[0-9]').hasMatch(value);
                if (!hasLetter || !hasNumber) {
                  return context.l10n.passwordPolicyError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Password Field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.confirmPassword,
                filled: true,
                fillColor: T.surfaceVariant(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: T.primary(context), width: 2),
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return context.l10n.passwordsDoNotMatch;
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Reset Password Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.primary(context),
                  foregroundColor: T.onPrimary(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: AppColors.transparent,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        context.l10n.resetPasswordButton,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
