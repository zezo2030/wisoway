class SeatLayoutConfig {
  final int rows;
  final int seatsPerRow;
  final bool preventGenderMixing;

  SeatLayoutConfig({
    required this.rows,
    required this.seatsPerRow,
    this.preventGenderMixing = true,
  });

  // Calculate total seats
  int get totalSeats => rows * seatsPerRow;

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'rows': rows,
      'seatsPerRow': seatsPerRow,
      'preventGenderMixing': preventGenderMixing,
    };
  }

  // Create from Map
  factory SeatLayoutConfig.fromMap(Map<String, dynamic> map) {
    return SeatLayoutConfig(
      rows: map['rows'] ?? 2,
      seatsPerRow: map['seatsPerRow'] ?? 2,
      preventGenderMixing: map['preventGenderMixing'] ?? true,
    );
  }

  // Create a copy with updated fields
  SeatLayoutConfig copyWith({
    int? rows,
    int? seatsPerRow,
    bool? preventGenderMixing,
  }) {
    return SeatLayoutConfig(
      rows: rows ?? this.rows,
      seatsPerRow: seatsPerRow ?? this.seatsPerRow,
      preventGenderMixing: preventGenderMixing ?? this.preventGenderMixing,
    );
  }
}

