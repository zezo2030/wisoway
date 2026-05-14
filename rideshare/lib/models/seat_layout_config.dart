class SeatLayoutConfig {
  final int rows;
  final int seatsPerRow;
  final List<int>? seatsPerRowList; // Optional custom layout: e.g. [1, 3]
  final bool preventGenderMixing;

  SeatLayoutConfig({
    required this.rows,
    required this.seatsPerRow,
    this.seatsPerRowList,
    this.preventGenderMixing = false,
  });

  // Calculate total seats
  int get totalSeats {
    if (seatsPerRowList != null && seatsPerRowList!.isNotEmpty) {
      return seatsPerRowList!.reduce((a, b) => a + b);
    }
    return rows * seatsPerRow;
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'rows': rows,
      'seatsPerRow': seatsPerRow,
      'seatsPerRowList': seatsPerRowList,
      'preventGenderMixing': preventGenderMixing,
    };
  }

  // Create from Map
  factory SeatLayoutConfig.fromMap(Map<String, dynamic> map) {
    List<int>? customList;
    if (map['seatsPerRowList'] != null) {
      customList = List<int>.from(map['seatsPerRowList']);
    }
    
    return SeatLayoutConfig(
      rows: map['rows'] ?? 2,
      seatsPerRow: map['seatsPerRow'] ?? 2,
      seatsPerRowList: customList,
      preventGenderMixing: map['preventGenderMixing'] ?? false,
    );
  }

  // Create a copy with updated fields
  SeatLayoutConfig copyWith({
    int? rows,
    int? seatsPerRow,
    List<int>? seatsPerRowList,
    bool? preventGenderMixing,
  }) {
    return SeatLayoutConfig(
      rows: rows ?? this.rows,
      seatsPerRow: seatsPerRow ?? this.seatsPerRow,
      seatsPerRowList: seatsPerRowList ?? this.seatsPerRowList,
      preventGenderMixing: preventGenderMixing ?? this.preventGenderMixing,
    );
  }
}

