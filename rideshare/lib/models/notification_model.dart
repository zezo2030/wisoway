/// Notification types
class NotificationType {
  static const String bookingCreated = 'booking_created';
  static const String bookingConfirmed = 'booking_confirmed';
  static const String bookingCancelled = 'booking_cancelled';
  static const String paymentApproved = 'payment_approved';
  static const String paymentRejected = 'payment_rejected';
  static const String tripReminder = 'trip_reminder';
  static const String driverArrived = 'driver_arrived';
  static const String tripCancelled = 'trip_cancelled';
  static const String communicationActivated = 'communication_activated';
  static const String chatMessage = 'chat_message';
  static const String walletCredited = 'wallet_credited';
}

class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final pUserId = json['userId'] is Map
        ? (json['userId']['_id'] ?? json['userId']['id'])?.toString() ?? ''
        : (json['userId'] ?? '').toString();
    final rawData = json['data'];

    return NotificationModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      userId: pUserId,
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map ? Map<String, dynamic>.from(rawData) : null),
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isBookingNotification =>
      type == NotificationType.bookingCreated ||
      type == NotificationType.bookingConfirmed ||
      type == NotificationType.bookingCancelled;

  bool get isPaymentNotification =>
      type == NotificationType.paymentApproved ||
      type == NotificationType.paymentRejected;

  bool get isTripNotification =>
      type == NotificationType.tripReminder ||
      type == NotificationType.driverArrived ||
      type == NotificationType.tripCancelled;

  String get displayTitle => titleForRole();

  String get displayBody => bodyForRole();

  String titleForRole({bool? isDriver}) => localizedTitleFor(
    type: type,
    data: data,
    fallbackTitle: title,
    isDriver: isDriver,
  );

  String bodyForRole({bool? isDriver}) => localizedBodyFor(
    type: type,
    data: data,
    fallbackBody: body,
    isDriver: isDriver,
  );

  static String localizedTitleFor({
    required String type,
    Map<String, dynamic>? data,
    String? fallbackTitle,
    bool? isDriver,
  }) {
    if (_isArabicText(fallbackTitle)) {
      return fallbackTitle!.trim();
    }

    switch (type) {
      case NotificationType.bookingCreated:
        return isDriver == true ? 'حجز جديد على رحلتك' : 'تم إنشاء حجز جديد';
      case NotificationType.bookingConfirmed:
        return isDriver == true ? 'تم تأكيد الحجز' : 'تم تأكيد حجزك';
      case NotificationType.bookingCancelled:
        return isDriver == true ? 'تم إلغاء أحد الحجوزات' : 'تم إلغاء حجزك';
      case NotificationType.paymentApproved:
        return 'تمت الموافقة على الدفعة';
      case NotificationType.paymentRejected:
        return 'تم رفض الدفعة';
      case NotificationType.tripReminder:
        return isDriver == true ? 'تذكير برحلتك كسائق' : 'تذكير بالرحلة';
      case NotificationType.driverArrived:
        return 'وصل السائق';
      case NotificationType.tripCancelled:
        return isDriver == true ? 'تم إلغاء رحلتك' : 'تم إلغاء الرحلة';
      case NotificationType.communicationActivated:
        return isDriver == true
            ? 'تم تفعيل التواصل مع الراكب'
            : 'تم تفعيل التواصل مع السائق';
      case NotificationType.chatMessage:
        return 'رسالة جديدة';
      case NotificationType.walletCredited:
        return 'تم إضافة رصيد إلى محفظتك';
      default:
        return _sanitizeFallback(fallbackTitle, defaultValue: 'إشعار جديد');
    }
  }

  static String localizedBodyFor({
    required String type,
    Map<String, dynamic>? data,
    String? fallbackBody,
    bool? isDriver,
  }) {
    if (_isArabicText(fallbackBody)) {
      return fallbackBody!.trim();
    }

    final driverName = _stringFromData(data, ['driverName', 'driver', 'name']);
    final passengerName = _stringFromData(data, [
      'passengerName',
      'passenger',
      'userName',
      'user',
    ]);
    final amount = _stringFromData(data, ['amount']);
    final currency = _stringFromData(data, ['currency']);

    switch (type) {
      case NotificationType.bookingCreated:
        if (isDriver == true) {
          return passengerName != null
              ? 'لديك حجز جديد من $passengerName على رحلتك.'
              : 'تم إنشاء حجز جديد على رحلتك.';
        }
        return 'تم إنشاء حجز جديد بنجاح.';
      case NotificationType.bookingConfirmed:
        return isDriver == true
            ? 'تم تأكيد الحجز على الرحلة بنجاح.'
            : 'تم تأكيد حجزك بنجاح.';
      case NotificationType.bookingCancelled:
        return isDriver == true
            ? 'تم إلغاء أحد الحجوزات على رحلتك.'
            : 'تم إلغاء حجزك.';
      case NotificationType.paymentApproved:
        if (amount != null && currency != null) {
          return 'تمت الموافقة على دفعة بقيمة $amount $currency.';
        }
        return isDriver == true
            ? 'تمت الموافقة على دفعة مرتبطة بإحدى رحلاتك.'
            : 'تمت الموافقة على الدفعة الخاصة بك.';
      case NotificationType.paymentRejected:
        if (amount != null && currency != null) {
          return 'تم رفض دفعة بقيمة $amount $currency.';
        }
        return isDriver == true
            ? 'تم رفض دفعة مرتبطة بإحدى رحلاتك.'
            : 'تم رفض الدفعة الخاصة بك.';
      case NotificationType.tripReminder:
        return isDriver == true
            ? 'تذكير بموعد رحلتك القادمة مع الركاب.'
            : 'تذكير بموعد رحلتك القادمة.';
      case NotificationType.driverArrived:
        return driverName != null
            ? 'السائق $driverName وصل إلى نقطة الانطلاق.'
            : 'وصل السائق إلى نقطة الانطلاق.';
      case NotificationType.tripCancelled:
        return isDriver == true
            ? 'تم إلغاء رحلتك. يرجى مراجعة تفاصيل الرحلة.'
            : 'تم إلغاء الرحلة. يرجى مراجعة التفاصيل.';
      case NotificationType.communicationActivated:
        if (isDriver == true) {
          return passengerName != null
              ? 'تم تفعيل التواصل بينك وبين الراكب $passengerName لهذه الرحلة.'
              : 'تم تفعيل التواصل بينك وبين الراكب لهذه الرحلة.';
        }
        return driverName != null
            ? 'تم تفعيل التواصل بينك وبين السائق $driverName لهذه الرحلة.'
            : 'تم تفعيل التواصل بينك وبين السائق لهذه الرحلة.';
      case NotificationType.chatMessage:
        final senderName = _stringFromData(data, ['senderName']);
        return senderName != null
            ? '$senderName أرسل لك رسالة جديدة.'
            : 'لديك رسالة جديدة في المحادثة.';
      case NotificationType.walletCredited:
        final amount = _stringFromData(data, ['amount']);
        final currency = _stringFromData(data, ['currency']);
        if (amount != null && currency != null) {
          return 'تمت إضافة $amount $currency إلى محفظتك بنجاح.';
        }
        return 'تمت إضافة رصيد جديد إلى محفظتك.';
      default:
        return _sanitizeFallback(
          fallbackBody,
          defaultValue: 'لديك إشعار جديد في التطبيق.',
        );
    }
  }

  static String _sanitizeFallback(
    String? text, {
    required String defaultValue,
  }) {
    final value = text?.trim();
    return value == null || value.isEmpty ? defaultValue : value;
  }

  static bool _isArabicText(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  static String? _stringFromData(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) return null;

    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }
}
