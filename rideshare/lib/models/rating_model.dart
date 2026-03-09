class RatingModel {
  final String id;
  final String fromUserId; // Rater
  final String toUserId; // Rated user
  final String tripId;
  final int rating; // 1-5
  final String? comment; // Optional
  final String userRole; // Role of rater: 'passenger' | 'driver'
  final String ratedRole; // Role of rated: 'passenger' | 'driver'
  final DateTime createdAt;

  RatingModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.tripId,
    required this.rating,
    this.comment,
    required this.userRole,
    required this.ratedRole,
    required this.createdAt,
  });

  static String _str(dynamic v) =>
      v == null ? '' : (v is Map ? (v['_id'] ?? v['id'])?.toString() ?? '' : v.toString());

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    final pFromUserId = _str(json['fromUserId']);
    final pToUserId = _str(json['toUserId']);
    final pTripId = _str(json['tripId']);

    return RatingModel(
      id: _str(json['_id'] ?? json['id']),
      fromUserId: pFromUserId,
      toUserId: pToUserId,
      tripId: pTripId,
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      userRole: json['userRole'] ?? 'passenger',
      ratedRole: json['ratedRole'] ?? 'driver',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'tripId': tripId,
      'rating': rating,
      'comment': comment,
      'userRole': userRole,
      'ratedRole': ratedRole,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  RatingModel copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? tripId,
    int? rating,
    String? comment,
    String? userRole,
    String? ratedRole,
    DateTime? createdAt,
  }) {
    return RatingModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      tripId: tripId ?? this.tripId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      userRole: userRole ?? this.userRole,
      ratedRole: ratedRole ?? this.ratedRole,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isValid => rating >= 1 && rating <= 5;
  bool get hasComment => comment != null && comment!.trim().isNotEmpty;
}
