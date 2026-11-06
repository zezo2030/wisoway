import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The app's notification sounds. Each is a WAV in Android's res/raw and in
/// the iOS bundle under the same name, and rings on an Android channel whose
/// id is that name too (a channel's sound is fixed once created).
///
/// The server names the sound of every push in `data.sound`, so a push shown
/// by the app while it is open rings the same as one shown by the system.
enum NotificationSound {
  general('إشعارات عامة', 'الإشعارات التي ليس لها صوت خاص'),
  chatMessage('الرسائل', 'رسائل المحادثات الفردية والجماعية'),
  rideAccepted('قبول الرحلة', 'قبول الرحلة أو الحجز واعتماد الحساب'),
  driverArrived('وصول السائق', 'الوصول إلى نقطة الالتقاء وتأكيد الركوب'),
  rideStarted('بدء الرحلة', 'بدء الرحلة'),
  rideCompleted('انتهاء الرحلة', 'انتهاء الرحلة وطلب تحصيل الأجرة'),
  rideCancelled('إلغاء الرحلة', 'إلغاء الرحلة من الراكب أو السائق'),
  paymentSuccess('الدفع والمحفظة', 'نجاح الدفع وتأكيده وشحن المحفظة'),
  error('الأخطاء', 'فشل الدفع أو رفض طلب وما شابه');

  const NotificationSound(this.channelName, this.channelDescription);

  final String channelName;
  final String channelDescription;

  /// File name without extension; also the Android channel id.
  String get resource =>
      'sound_${name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')}';

  String get iosFile => '$resource.wav';

  AndroidNotificationChannel get channel => AndroidNotificationChannel(
    resource,
    channelName,
    description: channelDescription,
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound(resource),
  );

  /// The sound the server named, or [general] for none / one this build
  /// doesn't ship.
  static NotificationSound fromResource(String? resource) {
    for (final sound in values) {
      if (sound.resource == resource) return sound;
    }
    return general;
  }
}

/// The sounds of a ride's milestones, played through notifications so they
/// ring whether the app is open or the driver is in Google Maps.
class RideSounds {
  RideSounds._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Channels of older builds, replaced by the [NotificationSound] ones.
  static const List<String> _oldChannelIds = [
    'rideshare_notifications',
    'ride_updates',
  ];

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
    if (android == null) return;
    for (final sound in NotificationSound.values) {
      await android.createNotificationChannel(sound.channel);
    }
    await android.createNotificationChannel(forgotStart);
    for (final id in _oldChannelIds) {
      await android.deleteNotificationChannel(id);
    }
  }

  /// A short-lived notice with the milestone's sound, confirming the
  /// driver's tap.
  static Future<void> chime({
    required NotificationSound sound,
    required String title,
    required String body,
  }) async {
    final channel = sound.channel;
    try {
      await _plugin.show(
        _chimeId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            sound: channel.sound,
            timeoutAfter: 4000,
            onlyAlertOnce: false,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: true,
            sound: sound.iosFile,
          ),
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
            sound: 'forgot_start_alarm.wav',
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
