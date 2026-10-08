import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppLifecycleState, Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/notification_model.dart';
import '../../widgets/instant_offer_dialog.dart';
import 'instant_offer_actions.dart';
import 'notification_navigation_service.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../constants/app_constants.dart';
import 'active_ride_navigator.dart';
import 'booking_request_actions.dart';

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

    _bookingNotificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'onInstantOfferAction') {
        final args = call.arguments;
        if (args is Map) {
          await InstantOfferActions.handle(Map<String, dynamic>.from(args));
        }
        return null;
      }
      if (call.method == 'onNotificationTap') {
        final args = call.arguments;
        if (args is Map) {
          NotificationNavigationService.handleNotificationData(
            Map<String, dynamic>.from(args),
          );
        }
        return null;
      }
      return null;
    });

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

    // Cold-start Accept/Reject — delay until navigator exists.
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      unawaited(_consumePendingInstantOfferAction());
      unawaited(_consumePendingNotificationTap());
    });
  }

  /// Cold start from a tap on one of our own rich notifications.
  static Future<void> _consumePendingNotificationTap() async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    try {
      final pending = await _bookingNotificationChannel.invokeMethod(
        'getPendingNotificationTap',
      );
      if (pending is Map) {
        NotificationNavigationService.handleNotificationData(
          Map<String, dynamic>.from(pending),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Failed to consume pending notification tap: $e');
    }
  }

  static Future<void> consumePendingInstantOfferAction() =>
      _consumePendingInstantOfferAction();

  static Future<void> _consumePendingInstantOfferAction() async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    try {
      final pending = await _bookingNotificationChannel.invokeMethod(
        'getPendingInstantOfferAction',
      );
      if (pending is Map) {
        await InstantOfferActions.handle(Map<String, dynamic>.from(pending));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to consume pending instant offer action: $e');
      }
    }
  }

  static Future<void> setupMessageHandlers() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      showForegroundNotification(message);
      // A matched ride takes over the screen on both phones, even when the
      // app is open somewhere else.
      final type = message.data['type']?.toString();
      if (type == 'instant_matched') {
        ActiveRideNavigator.resume();
      }
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

  /// The language the app is currently using ('ar' | 'en'), as persisted by
  /// LocalizationService. Sent with device registration so server-rendered
  /// pushes (instant offers, iOS alerts) follow the app language.
  static Future<String> appLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(AppConstants.keyLanguage);
      if (stored != null && stored.toLowerCase().startsWith('en')) {
        return AppConstants.langEnglish;
      }
    } catch (_) {
      // fall through to the default
    }
    return AppConstants.langArabic;
  }

  static Future<bool> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
    String? locale,
  }) async {
    try {
      final language = locale ?? await appLanguage();
      final response = await ApiClient().post(
        ApiEndpoints.notificationDevices,
        data: {
          'token': token,
          'platform': platform,
          'locale': language,
          if (appVersion != null) 'appVersion': appVersion,
        },
      );
      return response['registered'] == true;
    } catch (e) {
      if (kDebugMode) print('Failed to register device token: $e');
      return false;
    }
  }

  /// Re-register the current FCM token with a new app language. Best effort:
  /// silently does nothing when there is no token or the user is signed out.
  static Future<void> syncLanguage(String languageCode) async {
    try {
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _currentToken = token;
      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      await registerDevice(
        token: token,
        platform: platform,
        locale: languageCode,
      );
    } catch (e) {
      if (kDebugMode) print('Failed to sync device language: $e');
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

    if (type == NotificationType.bookingCreated) {
      // The app is open: put the request card up rather than a tray
      // notification the driver can swipe away unanswered. If the screen just
      // locked, the card would go unseen — pin the notification instead.
      final visible =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!visible && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _bookingNotificationChannel.invokeMethod(
            'showBookingNotification',
            data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
          );
        } catch (e) {
          if (kDebugMode) print('Failed to show booking notification: $e');
        }
        return;
      }
      unawaited(BookingRequestActions.showPending());
      return;
    }

    if (type == NotificationType.instantOffer && !kIsWeb) {
      // The app is open: put the ringing card up rather than a tray entry.
      final offerId = data['offerId']?.toString() ?? '';
      if (offerId.isEmpty) return;
      if (InstantOfferDialog.visibleOfferId == offerId) return;
      // "Foreground" to FCM can still mean the screen just locked; a card
      // nobody sees would swallow the offer, so ring in the tray instead.
      final visible =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!visible && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _bookingNotificationChannel.invokeMethod(
            'showInstantOfferNotification',
            data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
          );
        } catch (e) {
          if (kDebugMode) print('Failed to show instant offer notification: $e');
        }
        return;
      }
      unawaited(InstantOfferActions.openOfferDialog(offerId: offerId, seed: data));
      return;
    }

    if (type == NotificationType.instantOfferCancelled) {
      // The passenger cancelled: take the card and the ringing down now
      // instead of leaving the driver staring at a dead offer.
      final offerId = data['offerId']?.toString() ?? '';
      if (offerId.isNotEmpty) {
        InstantOfferDialog.dismissOffer(offerId);
        await cancelAndroidInstantOfferNotification(offerId);
      }
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

  /// Loops the new-ride chime while the in-app offer card is up. The native
  /// side stops it by itself at [until], so a card that never reports back
  /// can't leave the phone ringing.
  static Future<void> startInstantOfferRing(
    String offerId,
    DateTime until,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _bookingNotificationChannel.invokeMethod('startInstantOfferRing', {
        'offerId': offerId,
        'untilMs': until.millisecondsSinceEpoch,
      });
    } catch (e) {
      if (kDebugMode) print('Failed to start instant offer ring: $e');
    }
  }

  /// Takes down the pinned booking-request notification once it is answered.
  static Future<void> cancelBookingRequestNotification(String bookingId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (bookingId.isEmpty) return;
    try {
      await _bookingNotificationChannel.invokeMethod(
        'cancelBookingNotification',
        {'bookingId': bookingId},
      );
    } catch (e) {
      if (kDebugMode) print('Failed to cancel booking notification: $e');
    }
  }

  static Future<void> stopInstantOfferRing(String offerId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _bookingNotificationChannel.invokeMethod('stopInstantOfferRing', {
        'offerId': offerId,
      });
    } catch (e) {
      if (kDebugMode) print('Failed to stop instant offer ring: $e');
    }
  }

  static Future<void> cancelAndroidInstantOfferNotification(
    String offerId,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (offerId.isEmpty) return;
    try {
      await _bookingNotificationChannel.invokeMethod(
        'cancelInstantOfferNotification',
        {'offerId': offerId},
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to cancel instant offer notification: $e');
      }
    }
  }

  static String? _collapseKeyFor(String type, Map<String, dynamic> data) {
    if (type == 'chat_message') {
      final roomId = data['chatRoomId']?.toString();
      if (roomId != null && roomId.isNotEmpty) {
        return 'chat_$roomId';
      }
    }
    if (type == NotificationType.instantOffer) {
      final offerId = data['offerId']?.toString();
      if (offerId != null && offerId.isNotEmpty) {
        return 'instant_offer_$offerId';
      }
    }
    return null;
  }
}
