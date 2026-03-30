import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Widget? trailing;
  final double internalGap;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor = AppColors.teal700,
    this.subtitle,
    required this.children,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderRadius = 20,
    this.trailing,
    this.internalGap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              AppSpacing.horizontalGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: T.onSurface(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      AppSpacing.verticalGapXs,
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: T.onSurfaceVariant(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: internalGap),
          ...children,
        ],
      ),
    );
  }
}
