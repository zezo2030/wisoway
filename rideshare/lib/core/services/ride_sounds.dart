import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The sounds of a ride's milestones, played through notifications so they
/// ring whether the app is open or the driver is in Google Maps.
///
/// Android only for the custom sounds (res/raw); iOS plays its default.
class RideSounds {
  RideSounds._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// The driver arrived or the ride began — a soft chime. The server sends
  /// the passenger's «وصل السائق» and «بدأت الرحلة» on this channel too.
  static const AndroidNotificationChannel rideUpdates =
      AndroidNotificationChannel(
        'ride_updates',
        'تحديثات الرحلة',
        description: 'وصول السائق وبدء الرحلة',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('ride_chime'),
      );

  /// The driver left the pickup without starting the ride — loud on purpose.
  static const AndroidNotificationChannel forgotStart =
      AndroidNotificationChannel(
        'ride_forgot_start',
        'تذكير بدء الرحلة',
        description: 'تنبيه السائق إذا تحرّك دون بدء الرحلة',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('forgot_start_alarm'),
      );

  static const int _chimeId = 7301;
  static const int _forgotStartId = 7302;

  static Future<void> createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(rideUpdates);
    await android?.createNotificationChannel(forgotStart);
  }

  /// A short-lived notice with the chime, confirming the driver's tap.
  static Future<void> chime({
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        _chimeId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            rideUpdates.id,
            rideUpdates.name,
            channelDescription: rideUpdates.description,
            importance: Importance.high,
            priority: Priority.high,
            sound: rideUpdates.sound,
            timeoutAfter: 4000,
            onlyAlertOnce: false,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
      );
    } catch (_) {
      // A missing sound must never block the ride.
    }
  }

  /// «هل نسيت بدء الرحلة؟» — tapping it opens the trip.
  static Future<void> forgotToStart({
    required String tripId,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        _forgotStartId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            forgotStart.id,
            forgotStart.name,
            channelDescription: forgotStart.description,
            importance: Importance.max,
            priority: Priority.max,
            sound: forgotStart.sound,
            category: AndroidNotificationCategory.alarm,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: jsonEncode({'type': 'instant_forgot_start', 'tripId': tripId}),
      );
    } catch (_) {}
  }

  static Future<void> clearForgotToStart() async {
    try {
      await _plugin.cancel(_forgotStartId);
    } catch (_) {}
  }
}
