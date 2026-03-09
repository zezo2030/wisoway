import '../../models/notification_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class NotificationService {
  final ApiClient _api = ApiClient();

  // Get my notifications
  Future<List<NotificationModel>> getMyNotifications() async {
    try {
      final response = await _api.get(ApiEndpoints.notifications);
      final data = response['data'] as List? ?? [];
      return data.map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
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
