import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    AppConstants.otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    AppConstants.otpLength,
    (_) => FocusNode(),
  );
  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = AppConstants.otpResendTimeout;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
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
      // Move to next field
      if (index < AppConstants.otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last field filled, verify automatically
        _focusNodes[index].unfocus();
        _verifyOTP();
      }
    } else if (value.isEmpty && index > 0) {
      // Move to previous field on backspace
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getOTPCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOTP() async {
    final otpCode = _getOTPCode();
    if (otpCode.length != AppConstants.otpLength) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final isLinkPhone = args?['isLinkPhone'] == true;
      final isDriverRegistration = args?['role'] == AppConstants.roleDriver;
      final isDriverCompleteProfile = args?['isDriverCompleteProfile'] == true;

      if (isLinkPhone) {
        // Phone-linking flow for existing users
        await authProvider.linkPhone(
          phoneNumber: widget.phoneNumber,
          smsCode: otpCode,
        );
        if (mounted) {
          final afterVerifyRoute = args?['afterVerifyRoute'] as String?;
          if (afterVerifyRoute != null) {
            Navigator.pushReplacementNamed(context, afterVerifyRoute);
          } else {
            Navigator.pop(context);
          }
        }
        return;
      }

      // Registration flow (passenger or driver). Forward the profile fields
      // collected on the previous screen so the backend can provision the
      // account on first verify when no record exists yet.
      final firstName = (args?['firstName'] as String?)?.trim();
      final lastName = (args?['lastName'] as String?)?.trim();
      final composedName =
          (args?['name'] as String?)?.trim() ??
          ([
            firstName,
            lastName,
          ].where((p) => p != null && p.isNotEmpty).join(' ').trim());

      await authProvider.verifyOTP(
        phoneNumber: widget.phoneNumber,
        smsCode: otpCode,
        name: composedName.isEmpty ? null : composedName,
        gender: args?['gender'] as String?,
        role: args?['role'] as String?,
        password: args?['password'] as String?,
      );

      if (mounted) {
        if (isDriverCompleteProfile) {
          await _completeDriverProfileAfterOtp(authProvider, args);
          return;
        }
        final afterVerifyRoute = args?['afterVerifyRoute'] as String?;
        if (isDriverRegistration) {
          Navigator.pushReplacementNamed(
            context,
            afterVerifyRoute ?? RouteNames.driverCompleteProfile,
            arguments: {
              'firstName': args?['firstName'],
              'lastName': args?['lastName'],
              'email': args?['email'],
              'gender': args?['gender'],
            },
          );
        } else if (afterVerifyRoute != null) {
          Navigator.pushReplacementNamed(
            context,
            afterVerifyRoute,
            arguments: {
              'name': args?['name'],
              'email': args?['email'],
              'gender': args?['gender'],
              'role': args?['role'] ?? AppConstants.rolePassenger,
              'phoneNumber': widget.phoneNumber,
            },
          );
        } else {
          Navigator.pushReplacementNamed(context, RouteNames.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeDriverProfileAfterOtp(
    AuthProvider authProvider,
    Map<String, dynamic>? args,
  ) async {
    if (args == null) {
      throw Exception('بيانات السائق غير مكتملة');
    }

    final carImagePath = args['carImage'] as String?;
    if (carImagePath == null || carImagePath.isEmpty) {
      throw Exception('صورة السيارة مفقودة');
    }

    await authProvider.saveDriverProfile(
      firstName: (args['firstName'] as String?)?.trim() ?? '',
      lastName: (args['lastName'] as String?)?.trim() ?? '',
      phoneNumber: widget.phoneNumber,
      profileImage: File(args['profileImage'] as String),
      vehicleType: args['vehicleType'] as String,
      plateNumber: (args['plateNumber'] as String?)?.trim() ?? '',
      model: (args['model'] as String?)?.trim() ?? '',
      seats: args['seats'] as int,
      driverLicenseImage: File(args['driverLicenseImage'] as String),
      vehicleLicenseImage: File(args['vehicleLicenseImage'] as String),
      carImage: File(carImagePath),
      email: (args['email'] as String?)?.trim(),
      gender: args['gender'] as String?,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم رفع بياناتك بنجاح. طلبك قيد المراجعة من الإدارة.'),
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.driverPendingApproval,
      (route) => false,
    );
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
      _canResend = false;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendOTP(widget.phoneNumber);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز التحقق مرة أخرى'),
            backgroundColor: AppColors.success,
          ),
        );
        _startResendTimer();
        // Clear OTP fields
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
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

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    final start = phone.substring(0, 3);
    final end = phone.substring(phone.length - 3);
    return '$start*****$end';
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
            child: Column(
              children: [
                AppBar(
                  title: Text(
                    'التحقق من الرمز',
                    style: TextStyle(
                      color: T.onSurface(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  backgroundColor: AppColors.transparent,
                  elevation: 0,
                  iconTheme: IconThemeData(color: T.onSurface(context)),
                  centerTitle: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
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
                            Icons.mark_email_read_rounded,
                            size: 64,
                            color: T.primary(context),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'أدخل رمز التحقق',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: T.onSurface(context),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 15,
                              color: T.onSurfaceVariant(context),
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text: 'تم إرسال الرمز المكون من 6 أرقام إلى\n',
                              ),
                              TextSpan(
                                text: _maskPhone(widget.phoneNumber),
                                style: TextStyle(
                                  color: T.primary(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            AppConstants.otpLength,
                            (index) => Container(
                              width:
                                  (size.width -
                                      48 -
                                      (AppConstants.otpLength - 1) * 8) /
                                  AppConstants.otpLength,
                              height: 64,
                              decoration: BoxDecoration(
                                color: T.surface(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _controllers[index].text.isNotEmpty
                                      ? T.primary(context)
                                      : AppColors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.black.withValues(
                                      alpha: 0.04,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Semantics(
                                  label: 'رمز التحقق ${index + 1}',
                                  textField: true,
                                  child: TextField(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: T.onSurface(context),
                                    ),
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (value) {
                                      _onOTPChanged(index, value);
                                      setState(
                                        () {},
                                      ); // For rebuilding border color
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Container(
                          height: 56,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                T.primary(context),
                                T.primary(context).withValues(alpha: 0.7),
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
                            label: 'تحقق من الرمز',
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : (_getOTPCode().length ==
                                            AppConstants.otpLength
                                        ? _verifyOTP
                                        : null),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.transparent,
                                shadowColor: AppColors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'تحقق من الرمز',
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
                        const SizedBox(height: 24),
                        Semantics(
                          button: true,
                          label: _canResend
                              ? 'إعادة إرسال الرمز'
                              : 'إعادة إرسال الرمز خلال $_resendTimer ثانية',
                          enabled: _canResend && !_isLoading,
                          child: GestureDetector(
                            onTap: _canResend && !_isLoading
                                ? _resendOTP
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: _canResend
                                    ? T.primary(context).withValues(alpha: 0.1)
                                    : AppColors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _canResend
                                    ? 'إعادة إرسال الرمز'
                                    : 'إعادة إرسال الرمز خلال $_resendTimer ثانية',
                                style: TextStyle(
                                  color: _canResend
                                      ? T.primary(context)
                                      : T.outlineVariant(context),
                                  fontSize: 15,
                                  fontWeight: _canResend
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
