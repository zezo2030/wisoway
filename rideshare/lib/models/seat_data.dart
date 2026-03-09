class SeatData {
  final String seatNumber;
  final String? userId;
  final String? userName;
  final String? gender; // 'male' or 'female'
  final DateTime? bookedAt;
  final String status; // 'available', 'booked', 'locked'

  SeatData({
    required this.seatNumber,
    this.userId,
    this.userName,
    this.gender,
    this.bookedAt,
    this.status = 'available',
  });

  // Check if seat is booked
  bool get isBooked => status == 'booked';

  // Check if seat is locked
  bool get isLocked => status == 'locked';

  // Check if seat is available
  bool get isAvailable => status == 'available';

  // Convert to Map
  Map<String, dynamic> toJson() {
    return {
      'seatNumber': seatNumber,
      'userId': userId,
      'userName': userName,
      'gender': gender,
      'bookedAt': bookedAt?.toIso8601String(),
      'status': status,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  // Create from Map
  factory SeatData.fromJson(Map<String, dynamic> json) {
    return SeatData(
      seatNumber: json['seatNumber'] ?? '',
      userId: json['userId'],
      userName: json['userName'],
      gender: json['gender'],
      status: json['status'] ?? 'available',
      bookedAt: json['bookedAt'] != null
          ? DateTime.parse(json['bookedAt'])
          : null,
    );
  }

  factory SeatData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return SeatData(seatNumber: '');
    return SeatData.fromJson(map);
  }

  // Create a copy with updated fields
  SeatData copyWith({
    String? seatNumber,
    String? userId,
    String? userName,
    String? gender,
    DateTime? bookedAt,
    String? status,
  }) {
    return SeatData(
      seatNumber: seatNumber ?? this.seatNumber,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      gender: gender ?? this.gender,
      bookedAt: bookedAt ?? this.bookedAt,
      status: status ?? this.status,
    );
  }

  // Create empty seat
  factory SeatData.empty(String seatNumber) {
    return SeatData(seatNumber: seatNumber);
  }
}
