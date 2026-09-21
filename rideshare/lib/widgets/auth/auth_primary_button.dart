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
    this.pinnedArrow = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;

  /// Pins the arrow to the mockup's physical placement -- pointing right, drawn
  /// to the left of the label -- instead of mirroring with the locale.
  final bool pinnedArrow;

  /// Material's directional arrows carry `matchTextDirection: true`, so the
  /// glyph itself flips under an RTL [Directionality] no matter which IconData
  /// is chosen. Rendering it under an explicit LTR scope is what actually pins
  /// which way it points.
  Widget _arrow(IconData data) => pinnedArrow
      ? Directionality(
          textDirection: TextDirection.ltr,
          child: Icon(data, size: 20),
        )
      : Icon(data, size: 20);

  /// Replaces the directional arrow when set (e.g. a home icon).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final trailing =
        icon ??
        (isRtl && !pinnedArrow
            ? Icons.arrow_back_rounded
            : Icons.arrow_forward_rounded);

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
                  // An LTR row with the arrow first reproduces the mockup in
                  // both locales: arrow on the physical left, label to its
                  // right. Only the row's ordering is pinned -- the label still
                  // renders RTL in Arabic.
                  textDirection: pinnedArrow ? TextDirection.ltr : null,
                  children: [
                    if (pinnedArrow && (showArrow || icon != null)) ...[
                      _arrow(trailing),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!pinnedArrow && (showArrow || icon != null)) ...[
                      const SizedBox(width: 10),
                      _arrow(trailing),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
