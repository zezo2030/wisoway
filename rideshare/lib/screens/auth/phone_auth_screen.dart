import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../l10n/l10n_extensions.dart';

class PhoneAuthScreen extends StatefulWidget {
  /// When true, user is already logged in and we are linking/confirming phone (OTP will call linkPhone).
  final bool isLinkPhone;

  const PhoneAuthScreen({super.key, this.isLinkPhone = false});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final phoneNumber = _phoneController.text.trim();

      // Clean phone number
      String cleanedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+') && phoneNumber.startsWith('0')) {
        cleanedPhone = phoneNumber.substring(1);
      }

      final formattedPhone = cleanedPhone.startsWith('+')
          ? cleanedPhone
          : '${AppConstants.defaultCountryCode}$cleanedPhone';

      // In development mode with skipOTP, go directly to OTP screen
      // (backend will accept any code in dev mode, or code is shown in console)
      await authProvider.sendOTP(formattedPhone);

      if (mounted) {
        final routeArgs =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final otpArgs = <String, dynamic>{
          'phoneNumber': formattedPhone,
          'isSignIn': !widget.isLinkPhone,
          'isLinkPhone': widget.isLinkPhone,
        };
        if (routeArgs != null) {
          otpArgs.addAll({
            'afterVerifyRoute': routeArgs['afterVerifyRoute'],
            'firstName': routeArgs['firstName'],
            'lastName': routeArgs['lastName'],
            'email': routeArgs['email'],
            'gender': routeArgs['gender'],
          });
        }
        // الانتقال لصفحة إدخال OTP بعد إرسال رمز التحقق بنجاح
        Navigator.pushReplacementNamed(
          context,
          RouteNames.otpVerification,
          arguments: otpArgs,
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
        title: Text(
          widget.isLinkPhone ? context.l10n.linkPhoneTitle : context.l10n.signIn,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.phone_android,
                    size: 80,
                    color: T.primary(context),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    widget.isLinkPhone
                        ? context.l10n.enterPhoneToConfirm
                        : context.l10n.enterYourPhone,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isLinkPhone
                        ? context.l10n.linkPhoneSubtitle
                        : (AppConstants.skipOTP
                              ? context.l10n.devModeDirectLogin
                              : context.l10n.otpWillBeSentViaSms),
                    style: TextStyle(
                      fontSize: 16,
                      color: T.onSurfaceVariant(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    label: context.l10n.phoneNumber,
                    textField: true,
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.l10n.phoneNumber,
                        hintText: '+201234567890',
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.l10n.phoneNumberRequired;
                        }
                        final phone = value.trim();
                        final formattedPhone = phone.startsWith('+')
                            ? phone
                            : '${AppConstants.defaultCountryCode}$phone';
                        if (formattedPhone.length < 10) {
                          return context.l10n.invalidPhoneNumber;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    label: _isLoading
                        ? context.l10n.loading
                        : (AppConstants.skipOTP
                              ? context.l10n.enterAction
                              : context.l10n.sendOTP),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : Text(
                              AppConstants.skipOTP
                                  ? context.l10n.enterAction
                                  : context.l10n.sendOTP,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
