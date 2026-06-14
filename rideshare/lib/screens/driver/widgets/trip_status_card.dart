import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/trip_model.dart';
import '../../../l10n/l10n_extensions.dart';

class TripStatusCard extends StatelessWidget {
  final TripModel trip;

  const TripStatusCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (trip.status) {
      case 'active':
        statusColor = AppColors.success;
        statusText = context.l10n.tripStatusActive;
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      case 'hidden':
        statusColor = AppColors.warning;
        statusText = context.l10n.tripStatusHidden;
        statusIcon = IconsaxPlusLinear.eye_slash;
        break;
      case 'completed':
        statusColor = AppColors.teal600;
        statusText = context.l10n.tripStatusCompleted;
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      default:
        statusColor = AppColors.slate400;
        statusText = context.l10n.tripStatusUnknown;
        statusIcon = IconsaxPlusLinear.info_circle;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.tripStatusTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slate400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: AppTextStyles.titleMedium.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
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
