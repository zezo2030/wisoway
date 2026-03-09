import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/route_names.dart';
import '../../widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    });
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read
    Provider.of<NotificationProvider>(
      context,
      listen: false,
    ).markAsRead(notification.id);

    // Navigate based on type
    final data = notification.data;
    final tripId = data?['tripId'] as String?;

    switch (notification.type) {
      case NotificationType.bookingCreated:
      case NotificationType.bookingConfirmed:
      case NotificationType.bookingCancelled:
        if (tripId != null) {
          Navigator.pushNamed(
            context,
            RouteNames.tripDetails,
            arguments: tripId,
          );
        }
        break;

      case NotificationType.paymentApproved:
      case NotificationType.paymentRejected:
        Navigator.pushNamed(context, RouteNames.paymentHistory);
        break;

      case NotificationType.tripReminder:
      case NotificationType.driverArrived:
        if (tripId != null) {
          Navigator.pushNamed(
            context,
            RouteNames.tripDetails,
            arguments: tripId,
          );
        }
        break;

      case NotificationType.communicationActivated:
        if (tripId != null) {
          Navigator.pushNamed(
            context,
            RouteNames.tripManagement,
            arguments: tripId,
          );
        }
        break;
    }
  }

  Future<void> _handleDelete(NotificationModel notification) async {
    try {
      await Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).deleteNotification(notification.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف الإشعار: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userModel?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const Center(child: Text('يجب تسجيل الدخول')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الإشعارات',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              final notifications = provider.notifications;
              final unreadCount = notifications.where((n) => !n.isRead).length;

              if (unreadCount == 0) {
                return const SizedBox.shrink();
              }

              return TextButton.icon(
                onPressed: () async {
                  await provider.markAllAsRead();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم قراءة جميع الإشعارات'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(IconsaxPlusBold.tick_circle, size: 18),
                label: Text('قراءة الكل ($unreadCount)'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final notifications = provider.notifications;

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchNotifications(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return NotificationCard(
                  notification: notification,
                  onTap: () => _handleNotificationTap(notification),
                  onDelete: () => _handleDelete(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconsaxPlusBold.notification,
              size: 80,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'لا توجد إشعارات',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ستظهر الإشعارات هنا عند وصولها',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
