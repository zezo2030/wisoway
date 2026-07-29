import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/constants/countries.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import '../country_code_picker.dart';

/// Phone row shared by both signup step-1 screens: dial-code chip (with the
/// Jordan flag asset for +962) plus the local number input.
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.helper,
    this.hint = '07 XXX XXXX',
  });

  final TextEditingController controller;
  final CountryData country;
  final ValueChanged<CountryData> onCountryChanged;

  /// Muted line under the field (e.g. "We'll contact you to confirm").
  final String? helper;

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: T.outline(context)),
            boxShadow: [
              BoxShadow(
                color: T.shadow(context).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconsaxPlusLinear.call,
                  size: 20,
                  color: T.primary(context),
                ),
              ),
              const SizedBox(width: 8),
              CountryCodePicker(
                selectedCountry: country,
                onCountryChanged: onCountryChanged,
                borderColor: T.outline(context),
                width: 116,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: context.l10n.phoneNumber,
                  textField: true,
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: T.onSurface(context),
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        letterSpacing: 1,
                        color: T
                            .onSurfaceVariant(context)
                            .withValues(alpha: 0.5),
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      errorStyle: TextStyle(
                        fontSize: 11,
                        color: T.error(context),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return context.l10n.phoneNumberRequired;
                      }
                      final digits = v.replaceAll(RegExp(r'\s+'), '');
                      if (!RegExp(r'^0?\d{7,15}$').hasMatch(digits)) {
                        return context.l10n.invalidPhoneNumber;
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
            child: Text(
              helper!,
              style: TextStyle(
                fontSize: 11,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ),
      ],
    );
  }

  /// E.164 number built from the picked dial code and the typed local number.
  static String composeE164(CountryData country, String raw) {
    var cleaned = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (!cleaned.startsWith('+') && cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return '${country.dialCode}$cleaned';
  }
}
