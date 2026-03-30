import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/colors.dart';

class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color? iconColor;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = enabled
        ? (iconColor ?? T.primary(context))
        : T.onSurfaceVariant(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: effectiveIconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? T.onSurface(context)
                        : T.onSurfaceVariant(context),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
                Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  activeColor: T.primary(context),
                  materialState: MaterialState.all<Color: AppColors.teal600),
                ),
              child: Icon(
                IconsaxPlusLinear.arrow_left_2,
                size: 16,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
}
