import '../../models/chat_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class ChatService {
  final ApiClient _api = ApiClient();

  // Get all chat rooms for current user
  Future<List<ChatModel>> getMyChatRooms() async {
    try {
      final response = await _api.get(ApiEndpoints.chatRooms);
      final data = response['data'] as List? ?? [];
      return data.map((json) => ChatModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error getting chat rooms: $e');
      return [];
    }
  }

  /// التحقق من إمكانية المحادثة (الغرفة متاحة عبر getOrCreateRoomForTrip).
  Future<bool> checkIfChatEnabled(String tripId) async {
    try {
      await getOrCreateRoomForTrip(tripId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// نفس getOrCreateRoomForTrip (للتوافق مع الشاشات).
  Future<ChatModel> getOrCreateChat(String tripId) =>
      getOrCreateRoomForTrip(tripId);

  // Get or Create a chat room for a specific trip (passenger: 1:1 with driver)
  Future<ChatModel> getOrCreateRoomForTrip(String tripId) async {
    try {
      final response = await _api.get(ApiEndpoints.chatRoomByTrip(tripId));
      final data = response['data'] ?? response;
      return ChatModel.fromJson(data);
    } catch (e) {
      print('❌ Error getting chat room: $e');
      rethrow;
    }
  }

  /// غرفة 1:1 بين السائق وراكب معين (من صفحة تفاصيل الراكب)
  Future<ChatModel> getOrCreateRoomForDriverPassenger(
    String tripId,
    String passengerId,
  ) async {
    try {
      final response = await _api.get(
        ApiEndpoints.chatRoomByTripAndPassenger(tripId, passengerId),
      );
      final data = response['data'] ?? response;
      return ChatModel.fromJson(data);
    } catch (e) {
      print('❌ Error getting driver-passenger chat room: $e');
      rethrow;
    }
  }

  // Get messages for a specific room
  Future<List<MessageModel>> getMessages(String roomId) async {
    try {
      final response = await _api.get(ApiEndpoints.chatMessages(roomId));
      final raw = response['data'];
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        final inner = raw['data'];
        list = inner is List ? inner : [];
      } else {
        list = [];
      }
      return list.map((json) => MessageModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }

  // Send a message via HTTP
  // (We can use WebSocket as well in Phase 5, but REST is good as fallback)
  Future<MessageModel> sendMessage({
    required String roomId,
    required String text,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.sendMessage(roomId),
        data: {'text': text},
      );
      final data = response['data'] ?? response;
      return MessageModel.fromJson(data);
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // Poll messages every 3 seconds (fallback for websockets)
  Stream<List<MessageModel>> getChatStream(String roomId) async* {
    while (true) {
      yield await getMessages(roomId);
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
