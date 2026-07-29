import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// Boxed field used across the redesigned auth screens.
///
/// Matches the mockups: a rounded card holding the leading icon tile, a bold
/// label with an optional helper line, the input itself, and an optional
/// trailing action (password eye, dropdown chevron…).
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.helper,
    this.hint,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
    this.textDirection,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  /// Small muted line under the label (e.g. "Write your name as on your ID").
  final String? helper;

  final String? hint;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final bool enabled;
  final VoidCallback? onTap;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 10, end: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: enabled ? T.surface(context) : T.surfaceVariant(context),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: T.primary(context)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: T.onSurface(context),
                  ),
                ),
                if (helper != null)
                  Text(
                    helper!,
                    style: TextStyle(
                      fontSize: 11,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                Semantics(
                  label: label,
                  textField: true,
                  child: TextFormField(
                    controller: controller,
                    keyboardType: keyboardType,
                    obscureText: obscureText,
                    readOnly: readOnly,
                    enabled: enabled,
                    onTap: onTap,
                    textDirection: textDirection,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: T.onSurface(context),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: T.onSurfaceVariant(context).withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      errorStyle: TextStyle(
                        fontSize: 11,
                        color: T.error(context),
                      ),
                    ),
                    validator: validator,
                  ),
                ),
              ],
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}
