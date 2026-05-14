class ChatParticipant {
  final String userId;
  final DateTime joinedAt;

  ChatParticipant({required this.userId, required this.joinedAt});

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    final uid = json['userId'];
    final userIdStr = uid == null
        ? ''
        : (uid is Map ? (uid['_id'] ?? uid['id'])?.toString() ?? '' : uid.toString());
    return ChatParticipant(
      userId: userIdStr,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'joinedAt': joinedAt.toIso8601String()};
  }
}

class ChatModel {
  final String id;
  final String tripId;
  final List<ChatParticipant> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final String? tripStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    required this.tripId,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.tripStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    List<ChatParticipant> pParticipants = [];
    if (json['participants'] != null && json['participants'] is List) {
      pParticipants = (json['participants'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => ChatParticipant.fromJson(e))
          .toList();
    }

    final rawId = json['_id'] ?? json['id'];
    final rawTripId = json['tripId'];
    final rawTrip = json['trip'];
    final idStr = rawId == null ? '' : (rawId is Map ? (rawId['_id'] ?? rawId['id'])?.toString() ?? '' : rawId.toString());
    final tripIdStr = rawTripId == null ? '' : (rawTripId is Map ? (rawTripId['_id'] ?? rawTripId['id'])?.toString() ?? '' : rawTripId.toString());
    final tripStatus = rawTrip is Map
        ? rawTrip['status']?.toString()
        : json['tripStatus']?.toString();

    return ChatModel(
      id: idStr,
      tripId: tripIdStr,
      participants: pParticipants,
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'])
          : null,
      lastMessageSenderId: json['lastMessageSenderId'],
      tripStatus: tripStatus,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'tripId': tripId,
      'participants': participants.map((e) => e.toJson()).toList(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastMessageSenderId': lastMessageSenderId,
      'tripStatus': tripStatus,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  ChatModel copyWith({
    String? id,
    String? tripId,
    List<ChatParticipant>? participants,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    String? tripStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      tripStatus: tripStatus ?? this.tripStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool hasParticipant(String userId) =>
      participants.any((p) => p.userId == userId);

  bool get isClosedForSending =>
      tripStatus == 'completed' || tripStatus == 'cancelled';
}

class MessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  /// للتوافق مع الويدجت (نفس createdAt).
  DateTime get timestamp => createdAt;

  MessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  static String _s(dynamic v) =>
      v == null ? '' : (v is Map ? (v['_id'] ?? v['id'])?.toString() ?? '' : v.toString());

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: _s(json['_id'] ?? json['id']),
      chatRoomId: _s(json['chatRoomId']),
      senderId: _s(json['senderId']),
      senderName: json['senderName'] ?? '',
      text: json['text'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  MessageModel copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? createdAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool isFromUser(String userId) => senderId == userId;
}
