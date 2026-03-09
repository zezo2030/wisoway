import '../../models/notification_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  // Get my notifications
  Future<List<NotificationModel>> getMyNotifications() async {
    try {
      final response = await _api.get(ApiEndpoints.notifications);
      final rawList = _extractNotificationsList(response);
      final notifications = <NotificationModel>[];

      for (final raw in rawList) {
        try {
          if (raw is Map<String, dynamic>) {
            notifications.add(NotificationModel.fromJson(raw));
            continue;
          }

          if (raw is Map) {
            notifications.add(
              NotificationModel.fromJson(Map<String, dynamic>.from(raw)),
            );
          }
        } catch (_) {
          // Skip malformed notification item instead of failing whole list.
        }
      }

      return notifications;
    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
  }

  List<dynamic> _extractNotificationsList(dynamic response) {
    if (response is List) {
      return response;
    }

    if (response is! Map) {
      return const [];
    }

    // Some APIs may return a single notification object directly.
    if (_looksLikeNotificationObject(response)) {
      return [response];
    }

    final data = response['data'];
    if (data is List) {
      return data;
    }

    if (data is Map) {
      if (_looksLikeNotificationObject(data)) {
        return [data];
      }

      final nestedList =
          data['data'] ?? data['items'] ?? data['notifications'] ?? data['results'];
      if (nestedList is List) {
        return nestedList;
      }
      if (nestedList is Map && _looksLikeNotificationObject(nestedList)) {
        return [nestedList];
      }
    }

    final directList =
        response['items'] ?? response['notifications'] ?? response['results'];
    if (directList is List) {
      return directList;
    }

    return const [];
  }

  bool _looksLikeNotificationObject(Map map) {
    return map.containsKey('_id') ||
        map.containsKey('id') ||
        map.containsKey('title') ||
        map.containsKey('body') ||
        map.containsKey('type');
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    try {
      await _api.patch(ApiEndpoints.readAll);
    } catch (e) {
      print('❌ Error marking notifications as read: $e');
    }
  }

  // Mark single as read
  Future<void> markAsRead(String id) async {
    try {
      await _api.patch(ApiEndpoints.readNotification(id));
    } catch (e) {
      print('❌ Error marking notification $id as read: $e');
    }
  }
}
