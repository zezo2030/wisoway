import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/api/websocket_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/notification_navigation_service.dart';
import '../core/services/push_notification_service.dart';
import '../models/notification_model.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final WebSocketService _socketService = WebSocketService();

  String? _fcmToken;
  bool _isInitialized = false;
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> fetchNotifications() async {
    try {
      _notifications = await _notificationService.getMyNotifications();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token
      _fcmToken = await FirebaseMessaging.instance.getToken();
      if (_fcmToken != null) {
        await PushNotificationService.registerDevice(
          token: _fcmToken!,
          platform: defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        );
        await _authService.updateFcmToken(_fcmToken!);
      }

      // Listen to token updates
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        await PushNotificationService.registerDevice(
          token: newToken,
          platform: defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        );
        await _authService.updateFcmToken(newToken);
        notifyListeners();
      });

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((message) async {
        await PushNotificationService.showForegroundNotification(message);
        await fetchNotifications();
      });

      // Check if app was opened from terminated state
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        NotificationNavigationService.handleNotificationNavigation(
          initialMessage,
        );
        await fetchNotifications();
      }

      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        NotificationNavigationService.handleNotificationNavigation(message);
        await fetchNotifications();
      });

      await _socketService.connect();
      _socketSubscription?.cancel();
      _socketSubscription = _socketService.onNotification.listen((_) {
        fetchNotifications();
      });

      await fetchNotifications();

      _isInitialized = true;
      notifyListeners();

      // Retry pending instant-offer action once auth/nav are ready.
      await PushNotificationService.consumePendingInstantOfferAction();
    } catch (e) {
      debugPrint('Error initializing NotificationProvider: $e');
    }
  }

  /// إلغاء التحديث الدوري (مثلاً عند تسجيل الخروج)
  void disposePolling() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    disposePolling();
    super.dispose();
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      // If there's an API, call it here. For now, remove locally.
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
}
