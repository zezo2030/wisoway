import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/colors.dart';

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusLg,
      child: Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: AppRadius.radiusLg,
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: (iconColor ?? T.primary(context)).withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(
                icon,
                color: iconColor ?? T.primary(context),
                size: 24,
              ),
            ),
            AppSpacing.horizontalGapLg,
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? T.onSurface(context),
                ),
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_left_2,
              size: 16,
              color: T.onSurfaceVariant(context),
            ),
          ],
        ),
      ),
    );
  }
}
