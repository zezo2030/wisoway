import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

import '../../models/notification_model.dart';
import 'notification_navigation_service.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _bookingNotificationChannel = MethodChannel(
    'com.abdelaziz.visionway/booking_notification',
  );

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'rideshare_notifications',
        'إشعارات VisionWay',
        description: 'إشعارات الحجوزات والرحلات والمدفوعات والمحادثات',
        importance: Importance.max,
      );

  static bool _isInitialized = false;
  static String? _currentToken;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('notification_icon');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        NotificationNavigationService.handleLocalNotificationTap(
          response.payload,
        );
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    _isInitialized = true;
  }

  static Future<void> setupMessageHandlers() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      showForegroundNotification(message);
    });

    await _messageOpenedSubscription?.cancel();
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      NotificationNavigationService.handleNotificationNavigation(message);
    });
  }

  static Future<String?> getToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      _currentToken = token;
      return token;
    } catch (e) {
      if (kDebugMode) print('Failed to get FCM token: $e');
      return null;
    }
  }

  static Future<void> onTokenRefresh(Function(String) onNewToken) async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) {
        _currentToken = token;
        onNewToken(token);
      },
    );
  }

  static Future<bool> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
  }) async {
    try {
      final response = await ApiClient().post(
        ApiEndpoints.notificationDevices,
        data: {
          'token': token,
          'platform': platform,
          if (appVersion != null) 'appVersion': appVersion,
        },
      );
      return response['registered'] == true;
    } catch (e) {
      if (kDebugMode) print('Failed to register device token: $e');
      return false;
    }
  }

  static Future<bool> deregisterDevice(String token) async {
    try {
      await ApiClient().delete(ApiEndpoints.notificationDevice(token));
      return true;
    } catch (e) {
      if (kDebugMode) print('Failed to deregister device token: $e');
      return false;
    }
  }

  static Future<void> showForegroundNotification(RemoteMessage message) async {
    if (!_isInitialized) {
      await initialize();
    }

    final notification = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final type = data['type']?.toString() ?? '';

    if (type == NotificationType.bookingCreated && !kIsWeb) {
      final shown = await _showAndroidBookingNotification(data);
      if (shown) return;
    }

    final title = NotificationModel.localizedTitleFor(
      type: type,
      data: data,
      fallbackTitle: notification?.title,
    );
    final body = NotificationModel.localizedBodyFor(
      type: type,
      data: data,
      fallbackBody: notification?.body,
    );

    if (title.isEmpty && body.isEmpty) {
      return;
    }

    final collapseKey = _collapseKeyFor(type, data);

    final int notificationId = collapseKey != null
        ? collapseKey.hashCode
        : (message.messageId?.hashCode ?? message.hashCode);

    final androidDetails = AndroidNotificationDetails(
      'rideshare_notifications',
      'إشعارات VisionWay',
      channelDescription: 'إشعارات الحجوزات والرحلات والمدفوعات والمحادثات',
      icon: 'notification_icon',
      color: const Color(0xFF7C6AF5),
      importance: Importance.max,
      priority: Priority.high,
      tag: collapseKey,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title.isEmpty ? 'VisionWay' : title,
      ),
    );

    final iosDetails = DarwinNotificationDetails(threadIdentifier: collapseKey);

    await _localNotifications.show(
      notificationId,
      title.isEmpty ? 'VisionWay' : title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<bool> _showAndroidBookingNotification(
    Map<String, dynamic> data,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      final payload = <String, String>{};
      data.forEach((key, value) {
        if (value != null) {
          payload[key] = value.toString();
        }
      });
      payload.putIfAbsent(
        'title',
        () =>
            NotificationModel.localizedTitleFor(
              type: NotificationType.bookingCreated,
              data: data,
              isDriver: true,
            ),
      );
      await _bookingNotificationChannel.invokeMethod(
        'showBookingNotification',
        payload,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to show custom booking notification: $e');
      }
      return false;
    }
  }

  static String? _collapseKeyFor(String type, Map<String, dynamic> data) {
    if (type == 'chat_message') {
      final roomId = data['chatRoomId']?.toString();
      if (roomId != null && roomId.isNotEmpty) {
        return 'chat_$roomId';
      }
    }
    return null;
  }
}
