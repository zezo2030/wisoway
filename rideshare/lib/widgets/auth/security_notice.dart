import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

/// Shield + privacy reassurance line shown under the auth headers.
class SecurityNotice extends StatelessWidget {
  const SecurityNotice({super.key, this.text, this.onDark = false});

  final String? text;

  /// True when rendered over the teal hero, where the copy must stay white.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark
        ? AppColors.white.withValues(alpha: 0.92)
        : T.onSurfaceVariant(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(IconsaxPlusBold.shield_tick, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text ?? context.l10n.authSecurityNotice,
            style: TextStyle(fontSize: 12, color: color, height: 1.4),
          ),
        ),
      ],
    );
  }
}
