import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants/route_names.dart';

/// Service to handle navigation when user taps on notifications
class NotificationNavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Handle navigation based on notification data
  static void handleNotificationNavigation(RemoteMessage message) {
    handleNotificationData(Map<String, dynamic>.from(message.data));
  }

  static void handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    if (type == null) {
      // Default: navigate to notifications screen
      _navigateToRoute(RouteNames.notifications);
      return;
    }

    switch (type) {
      case 'booking_created':
      case 'booking_confirmed':
      case 'booking_cancelled':
        _handleBookingNotification(data);
        break;

      case 'payment_approved':
      case 'payment_rejected':
        _handlePaymentNotification(data);
        break;

      case 'trip_reminder':
      case 'driver_arrived':
      case 'trip_cancelled':
        _handleTripNotification(data);
        break;

      case 'trip_started':
        _handleTripStartedNotification(data);
        break;

      case 'presence_prompt':
      case 'presence_marked_absent':
        _navigateToPresenceConfirmation(data);
        break;

      case 'presence_driver_prompt':
        _navigateToPresenceRoster(data);
        break;

      case 'communication_activated':
        _handleCommunicationNotification(data);
        break;

      case 'chat_message':
        _handleChatMessageNotification(data);
        break;

      default:
        // Navigate to notifications screen for unknown types
        _navigateToRoute(RouteNames.notifications);
    }
  }

  /// Handle booking-related notifications
  static void _handleBookingNotification(Map<String, dynamic> data) {
    final tripId = data['tripId'] as String?;

    if (tripId != null) {
      // Navigate to trip details or trip management based on user role
      // For now, navigate to trip details
      _navigateToRoute(RouteNames.tripDetails, arguments: tripId);
    } else {
      _navigateToRoute(RouteNames.notifications);
    }
  }

  /// Handle payment-related notifications
  static void _handlePaymentNotification(Map<String, dynamic> data) {
    final paymentId = data['paymentId'] as String?;

    if (paymentId != null) {
      // Navigate to payment history or manual payment screen
      _navigateToRoute(RouteNames.paymentHistory);
    } else {
      _navigateToRoute(RouteNames.notifications);
    }
  }

  /// Handle trip-related notifications (reminders, driver arrived)
  static void _handleTripNotification(Map<String, dynamic> data) {
    final tripId = data['tripId'] as String?;

    if (tripId != null) {
      // Navigate to trip details
      _navigateToRoute(RouteNames.tripDetails, arguments: tripId);
    } else {
      _navigateToRoute(RouteNames.notifications);
    }
  }

  /// Handle trip-started notification — opens live trip screen and prompts the user
  /// to share live trip tracking with someone.
  static void _handleTripStartedNotification(Map<String, dynamic> data) {
    final tripId = data['tripId'] as String?;

    if (tripId != null) {
      _navigateToRoute(
        RouteNames.tripInProgress,
        arguments: {'tripId': tripId, 'showTrackingShare': true},
      );
    } else {
      _navigateToRoute(RouteNames.notifications);
    }
  }

  static void _navigateToPresenceConfirmation(Map<String, dynamic> data) {
    final bookingId = data['bookingId'] as String?;
    if (bookingId == null) {
      _navigateToRoute(RouteNames.notifications);
      return;
    }
    _navigateToRoute(
      RouteNames.presenceConfirmation,
      arguments: {'bookingId': bookingId},
    );
  }

  static void _navigateToPresenceRoster(Map<String, dynamic> data) {
    final tripId = data['tripId'] as String?;
    if (tripId == null) {
      _navigateToRoute(RouteNames.notifications);
      return;
    }
    _navigateToRoute(RouteNames.tripManagement, arguments: tripId);
  }

  /// Handle communication activation notification
  static void _handleCommunicationNotification(Map<String, dynamic> data) {
    final tripId = data['tripId'] as String?;

    if (tripId != null) {
      // Navigate to trip details or chat (when implemented)
      _navigateToRoute(RouteNames.tripDetails, arguments: tripId);
    } else {
      _navigateToRoute(RouteNames.notifications);
    }
  }

  /// Handle incoming chat message notification — opens the correct chat screen
  /// based on the sender's role (driver → passenger chat; passenger → driver chat).
  static void _handleChatMessageNotification(Map<String, dynamic> data) {
    final tripId = data['tripId'] as String?;
    final senderId = data['senderId'] as String?;
    final senderName = data['senderName'] as String?;
    final chatRoomId = data['chatRoomId'] as String?;
    // senderRole: 'driver' | 'passenger' (set by backend)
    final senderRole = data['senderRole'] as String?;

    if (tripId == null) {
      _navigateToRoute(RouteNames.notifications);
      return;
    }

    if (senderRole == 'driver') {
      // Recipient is a passenger → open passenger chat screen
      _navigateToRoute(
        RouteNames.chat,
        arguments: {
          'tripId': tripId,
          'chatRoomId': chatRoomId,
          'driverId': senderId ?? '',
          'driverName': senderName ?? 'السائق',
        },
      );
    } else {
      // Recipient is a driver → open driver chat screen
      _navigateToRoute(
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

  /// Navigate to a specific route
  static Future<void> _navigateToRoute(
    String routeName, {
    Object? arguments,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Navigator is not available yet');
      return;
    }

    try {
      await navigator.pushNamed(routeName, arguments: arguments);
    } catch (error) {
      debugPrint('Navigation error: $error');
      try {
        await navigator.pushNamed(RouteNames.notifications);
      } catch (fallbackError) {
        debugPrint('Fallback navigation error: $fallbackError');
      }
    }
  }

  /// Handle notification tap from local notification
  static void handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) {
      _navigateToRoute(RouteNames.notifications);
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        handleNotificationData(decoded);
        return;
      }
      if (decoded is Map) {
        handleNotificationData(Map<String, dynamic>.from(decoded));
        return;
      }

      _navigateToRoute(RouteNames.notifications);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
      _navigateToRoute(RouteNames.notifications);
    }
  }
}
