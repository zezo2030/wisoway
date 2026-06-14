import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/trip_model.dart';
import '../../../widgets/common/section_card.dart';
import '../../../l10n/l10n_extensions.dart';

class QuickActionsCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;

  const QuickActionsCard({
    super.key,
    required this.trip,
    this.onEdit,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: context.l10n.quickActions,
      icon: IconsaxPlusLinear.setting_2,
      iconColor: AppColors.teal600,
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: IconsaxPlusLinear.share,
                label: context.l10n.share,
                color: AppColors.teal600,
                onTap: onShare ?? () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: IconsaxPlusLinear.edit,
                label: context.l10n.edit,
                color: AppColors.warning,
                onTap: onEdit ?? () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
