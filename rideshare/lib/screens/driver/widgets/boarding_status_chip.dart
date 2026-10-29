import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';

/// «أكّد ركوبه ✓» / «لم يؤكد ركوبه بعد» under a passenger's name on the
/// driver's screens. A shared trip starts with the first confirmation, so the
/// driver can see who is in and who they are still waiting on.
class BoardingStatusChip extends StatelessWidget {
  const BoardingStatusChip({super.key, required this.boarded});

  final bool boarded;

  @override
  Widget build(BuildContext context) {
    final color = boarded ? AppColors.success : AppColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          boarded ? Icons.check_circle_rounded : Icons.schedule_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            boarded
                ? context.l10n.boardingConfirmed
                : context.l10n.boardingNotConfirmed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
