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
import '../../core/services/active_ride_navigator.dart';
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

  /// Opens whatever the notification is about. Notifications that point at
  /// nothing still openable (an expired ride offer, an announcement) show
  /// their full text instead, since the card cuts long messages off.
  Future<void> _handleNotificationTap(NotificationModel notification) async {
    Provider.of<NotificationProvider>(
      context,
      listen: false,
    ).markAsRead(notification.id);

    final isDriver =
        Provider.of<AuthProvider>(context, listen: false).userModel?.isDriver ??
        false;
    final data = notification.data ?? const <String, dynamic>{};
    final tripId = _idFrom(data, 'tripId') ?? _idFrom(data, 'entityId');
    final bookingId = _idFrom(data, 'bookingId');

    switch (notification.type) {
      case NotificationType.chatMessage:
        if (tripId == null) break;
        final senderId = data['senderId'] as String?;
        final senderName = data['senderName'] as String?;
        final chatRoomId = data['chatRoomId'] as String?;
        if (data['senderRole'] == 'driver') {
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
        return;

      case NotificationType.presencePrompt:
      case NotificationType.presenceMarkedAbsent:
        if (bookingId == null) break;
        Navigator.pushNamed(
          context,
          RouteNames.presenceConfirmation,
          arguments: {'bookingId': bookingId},
        );
        return;

      case NotificationType.paymentApproved:
      case NotificationType.paymentRejected:
        Navigator.pushNamed(context, RouteNames.paymentHistory);
        return;

      case NotificationType.walletCredited:
      case NotificationType.rideFareCredited:
      case NotificationType.tripFeeCharged:
      case NotificationType.tripPayment:
      case NotificationType.settlementMarkedPaid:
      case NotificationType.driverFineIssued:
        Navigator.pushNamed(
          context,
          isDriver ? RouteNames.driverWallet : RouteNames.passengerWallet,
        );
        return;

      case NotificationType.penaltyCharged:
        Navigator.pushNamed(context, RouteNames.pendingCharges);
        return;

      case NotificationType.driverApproved:
      case NotificationType.driverRejected:
        Navigator.pushNamed(context, RouteNames.driverPendingApproval);
        return;

      // A ride offer or search that has long since ended has no screen to
      // return to.
      case NotificationType.instantOffer:
      case NotificationType.instantOfferCancelled:
      case NotificationType.instantNoDrivers:
        break;

      // The fare of an instant ride: back to the payment screen while it is
      // still open, otherwise to the trip (the driver's summary lists every
      // passenger's payment).
      case NotificationType.ridePaymentDue:
      case NotificationType.ridePaymentRequested:
      case NotificationType.ridePaymentFailed:
      case NotificationType.ridePaymentCashSwitch:
        if (tripId == null) break;
        if (await ActiveRideNavigator.resumePaymentFor(tripId)) return;
        if (!mounted) return;
        _openTrip(tripId, isDriver: isDriver, finished: true);
        return;

      case NotificationType.tripCompleted:
      case NotificationType.tripAutoCompleted:
      case NotificationType.ridePaymentPaid:
      case NotificationType.ridePaymentDisputed:
        if (tripId == null) break;
        _openTrip(tripId, isDriver: isDriver, finished: true);
        return;

      default:
        // Bookings, reminders, trip started / cancelled, presence reports,
        // ratings, new trips nearby…: all about one trip.
        if (tripId == null) break;
        _openTrip(tripId, isDriver: isDriver);
        return;
    }

    _showFullText(notification, isDriver: isDriver);
  }

  /// The driver manages their trip (or reviews its summary once it is over);
  /// a passenger sees its details, which move on to the live screen while
  /// the trip is running.
  void _openTrip(
    String tripId, {
    required bool isDriver,
    bool finished = false,
  }) {
    if (isDriver && finished) {
      Navigator.pushNamed(
        context,
        RouteNames.tripSummary,
        arguments: {'tripId': tripId},
      );
    } else if (isDriver) {
      Navigator.pushNamed(
        context,
        RouteNames.tripManagement,
        arguments: tripId,
      );
    } else {
      Navigator.pushNamed(context, RouteNames.tripDetails, arguments: tripId);
    }
  }

  void _showFullText(NotificationModel notification, {required bool isDriver}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('notification-full-text'),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notification.titleForRole(isDriver: isDriver),
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                notification.bodyForRole(isDriver: isDriver),
                style: GoogleFonts.tajawal(fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _idFrom(Map<String, dynamic> data, String key) {
    final value = data[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
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
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.allNotificationsRead),
                        duration: const Duration(seconds: 2),
                      ),
                    );
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
