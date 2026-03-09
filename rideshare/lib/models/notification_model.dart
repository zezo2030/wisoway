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
}
