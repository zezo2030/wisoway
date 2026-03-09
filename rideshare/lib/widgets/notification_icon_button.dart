import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../providers/auth_provider.dart';
import '../core/theme/colors.dart';
import '../core/constants/route_names.dart';
import '../providers/notification_provider.dart';

/// Widget لإظهار أيقونة الإشعارات مع عداد
class NotificationIconButton extends StatelessWidget {
  final double? iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  const NotificationIconButton({
    super.key,
    this.iconSize,
    this.iconColor,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userModel?.id;

    if (userId == null) {
      return const SizedBox.shrink();
    }

    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;

        return GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, RouteNames.notifications);
              },
              child: SizedBox(
                width: 48,
                height: 48,
                child: Container(
                  padding: padding ?? const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backgroundColor ?? AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      IconsaxPlusLinear.notification,
                      color: iconColor ?? AppColors.primary,
                      size: iconSize ?? 24,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
      },
    );
  }
}
