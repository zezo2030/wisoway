import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

/// Shield + privacy reassurance line shown under the auth headers.
class SecurityNotice extends StatelessWidget {
  const SecurityNotice({super.key, this.text, this.onDark = false, this.color});

  final String? text;

  /// True when rendered over the teal hero, where the copy must stay white.
  final bool onDark;

  /// Pins the ink, for surfaces that keep their own palette across themes
  /// (the driver hero holds the illustration's light backdrop in dark mode).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink =
        color ??
        (onDark
            ? AppColors.white.withValues(alpha: 0.92)
            : T.onSurfaceVariant(context));

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(IconsaxPlusBold.shield_tick, size: 16, color: ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text ?? context.l10n.authSecurityNotice,
            style: TextStyle(fontSize: 12, color: ink, height: 1.4),
          ),
        ),
      ],
    );
  }
}
