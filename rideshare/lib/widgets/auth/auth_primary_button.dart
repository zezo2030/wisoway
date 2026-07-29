import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// Full-width teal CTA used at the bottom of every auth step.
///
/// The trailing arrow always points in the reading direction, so it flips with
/// the locale (left in Arabic RTL, right in English).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;

  /// Replaces the directional arrow when set (e.g. a home icon).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final trailing =
        icon ?? (isRtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded);

    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null && !loading,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: T.primary(context),
            foregroundColor: T.onPrimary(context),
            disabledBackgroundColor: T.primary(context).withValues(alpha: 0.5),
            disabledForegroundColor: T.onPrimary(context),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      T.onPrimary(context),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showArrow || icon != null) ...[
                      const SizedBox(width: 10),
                      Icon(trailing, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
