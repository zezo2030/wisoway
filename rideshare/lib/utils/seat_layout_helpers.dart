import '../models/seat_layout_config.dart';

/// Maps between passenger UI order (1-based, same as [TripModel.seats] indices)
/// and backend seat ids (`row-col`, 0-based), including irregular `seatsPerRowList` layouts.
class SeatLayoutHelpers {
  SeatLayoutHelpers._();

  /// Seats per visual row: either [seatsPerRowList] or uniform [rows × seatsPerRow].
  static List<int> rowSeatCounts(SeatLayoutConfig layout) {
    final list = layout.seatsPerRowList;
    if (list != null && list.isNotEmpty) {
      return List<int>.from(list);
    }
    return List<int>.generate(layout.rows, (_) => layout.seatsPerRow);
  }

  /// 1-based display index → backend `row-col` (matches Nest `generateSeatsFromLayout` order).
  static String displayIndexToBackendSeatId(
    int oneBasedDisplayIndex,
    SeatLayoutConfig layout,
  ) {
    final c = displayIndexToBackendCoords(oneBasedDisplayIndex, layout);
    if (c == null) return '0-0';
    return '${c.row}-${c.col}';
  }

  /// 0-based row/col in API; null if index out of range.
  static SeatLayoutCoords? displayIndexToBackendCoords(
    int oneBasedDisplayIndex,
    SeatLayoutConfig layout,
  ) {
    if (oneBasedDisplayIndex < 1) return null;
    final configs = rowSeatCounts(layout);
    if (configs.isEmpty) return null;
    var remaining = oneBasedDisplayIndex - 1;
    for (var row = 0; row < configs.length; row++) {
      final count = configs[row];
      if (remaining < count) {
        return SeatLayoutCoords(row, remaining);
      }
      remaining -= count;
    }
    return null;
  }

  static int? backendCoordsToDisplayIndex(
    SeatLayoutConfig layout,
    int row,
    int col,
  ) {
    final configs = rowSeatCounts(layout);
    if (row < 0 || row >= configs.length) return null;
    if (col < 0 || col >= configs[row]) return null;
    var sum = 0;
    for (var i = 0; i < row; i++) {
      sum += configs[i];
    }
    return sum + col + 1;
  }

  /// Parse `row-col` from API; returns null if invalid.
  static SeatLayoutCoords? parseBackendSeatId(String id) {
    final parts = id.split('-');
    if (parts.length != 2) return null;
    final r = int.tryParse(parts[0]);
    final c = int.tryParse(parts[1]);
    if (r == null || c == null) return null;
    return SeatLayoutCoords(r, c);
  }
}

class SeatLayoutCoords {
  final int row;
  final int col;

  const SeatLayoutCoords(this.row, this.col);
}
