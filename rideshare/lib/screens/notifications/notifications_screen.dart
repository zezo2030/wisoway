import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/route_names.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/notification_card.dart';
import '../../l10n/l10n_extensions.dart';

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
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
    });
  }

  void _handleNotificationTap(NotificationModel notification) {
    Provider.of<NotificationProvider>(
      context,
      listen: false,
    ).markAsRead(notification.id);

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

      case NotificationType.chatMessage:
        if (tripId != null) {
          final senderId = data?['senderId'] as String?;
          final senderName = data?['senderName'] as String?;
          final senderRole = data?['senderRole'] as String?;
          final chatRoomId = data?['chatRoomId'] as String?;

          if (senderRole == 'driver') {
            Navigator.pushNamed(
              context,
              RouteNames.chat,
              arguments: {
                'tripId': tripId,
                'chatRoomId': chatRoomId,
                'driverId': senderId ?? '',
                'driverName': senderName ?? 'السائق',
              },
            );
          } else {
            Navigator.pushNamed(
              context,
              RouteNames.driverChat,
              arguments: {
                'tripId': tripId,
                'chatRoomId': chatRoomId,
                'passengerId': senderId,
                'passengerName': senderName ?? 'الراكب',
              },
            );
          }
        }
        break;
      case NotificationType.walletCredited:
        // Navigate to the relevant wallet screen
        Navigator.pushNamed(context, RouteNames.passengerWallet);
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
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userModel?.id;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.notifications)),
        body: Center(child: Text(context.l10n.mustSignIn)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.notifications,
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

              return Semantics(
                button: true,
                label: context.l10n.markAllNotificationsRead(unreadCount),
                child: TextButton.icon(
                  onPressed: () async {
                    await provider.markAllAsRead();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.allNotificationsRead),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(IconsaxPlusBold.tick_circle, size: 18),
                  label: Text(context.l10n.markAllReadCount(unreadCount)),
                  style: TextButton.styleFrom(
                    foregroundColor: T.primary(context),
                  ),
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
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchNotifications(),
            color: T.primary(context),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Semantics(
                  button: true,
                  label: notification.displayTitle,
                  child: NotificationCard(
                    notification: notification,
                    onTap: () => _handleNotificationTap(notification),
                    onDelete: () => _handleDelete(notification),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: IconsaxPlusBold.notification,
      title: context.l10n.noNotifications,
      subtitle: context.l10n.notificationsWillAppearHere,
    );
  }
}
