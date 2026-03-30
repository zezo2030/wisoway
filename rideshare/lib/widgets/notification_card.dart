import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification_model.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/colors.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final color = _getNotificationColor(context, notification.type);
    final icon = _getNotificationIcon(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: T.error(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          IconsaxPlusBold.trash,
          color: AppColors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        if (onDelete != null) {
          onDelete!();
        }
        return true;
      },
      onDismissed: (direction) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف الإشعار'),
            duration: const Duration(seconds: 2),
            backgroundColor: T.error(context),
          ),
        );
      },
      child: Semantics(
        button: onTap != null,
        label: '${notification.title}. ${notification.body}',
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isUnread
                  ? color.withValues(alpha: 0.3)
                  : T.outline(context),
              width: isUnread ? 1.5 : 1,
            ),
          ),
          color: isUnread ? color.withValues(alpha: 0.05) : T.surface(context),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  AppSpacing.horizontalGapLg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: T.onSurface(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        AppSpacing.verticalGapSm,
                        Text(
                          notification.body,
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: T.onSurfaceVariant(context),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AppSpacing.verticalGapSm,
                        Row(
                          children: [
                            Icon(
                              IconsaxPlusLinear.clock,
                              size: 12,
                              color: T.onSurfaceVariant(context),
                            ),
                            AppSpacing.horizontalGapXs,
                            Text(
                              timeago.format(
                                notification.createdAt,
                                locale: 'ar',
                              ),
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                color: T.onSurfaceVariant(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(BuildContext context, String type) {
    if (notification.isBookingNotification) {
      return AppColors.success;
    } else if (notification.isPaymentNotification) {
      return AppColors.info;
    } else if (notification.isTripNotification) {
      return AppColors.warning;
    }
    return T.primary(context);
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case NotificationType.bookingCreated:
        return IconsaxPlusBold.bookmark;
      case NotificationType.bookingConfirmed:
        return IconsaxPlusBold.tick_circle;
      case NotificationType.bookingCancelled:
        return IconsaxPlusBold.close_circle;
      case NotificationType.paymentApproved:
        return IconsaxPlusBold.dollar_circle;
      case NotificationType.paymentRejected:
        return IconsaxPlusBold.danger;
      case NotificationType.tripReminder:
        return IconsaxPlusBold.clock;
      case NotificationType.driverArrived:
        return IconsaxPlusBold.location;
      case NotificationType.tripCancelled:
        return IconsaxPlusBold.close_circle;
      case NotificationType.communicationActivated:
        return IconsaxPlusBold.message;
      default:
        return IconsaxPlusBold.notification;
    }
  }
}
