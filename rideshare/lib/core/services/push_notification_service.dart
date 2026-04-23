import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/notification_model.dart';
import 'notification_navigation_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'rideshare_notifications',
        'إشعارات VisionWay',
        description: 'إشعارات الحجوزات والرحلات والمدفوعات والمحادثات',
        importance: Importance.max,
      );

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
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

  static Future<void> showForegroundNotification(RemoteMessage message) async {
    if (!_isInitialized) {
      await initialize();
    }

    final notification = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final title = NotificationModel.localizedTitleFor(
      type: data['type']?.toString() ?? '',
      data: data,
      fallbackTitle: notification?.title,
    );
    final body = NotificationModel.localizedBodyFor(
      type: data['type']?.toString() ?? '',
      data: data,
      fallbackBody: notification?.body,
    );

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await _localNotifications.show(
      message.messageId?.hashCode ?? message.hashCode,
      title ?? 'VisionWay',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rideshare_notifications',
          'إشعارات VisionWay',
          channelDescription:
              'إشعارات الحجوزات والرحلات والمدفوعات والمحادثات',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
