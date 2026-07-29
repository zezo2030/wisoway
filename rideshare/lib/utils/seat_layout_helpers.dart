import '../models/seat_data.dart';
import '../models/seat_layout_config.dart';
import '../models/trip_model.dart';

/// Maps between passenger UI order (1-based, same as [TripModel.seats] indices)
/// and backend seat ids (`row-col`, 0-based), including irregular `seatsPerRowList` layouts.
class SeatLayoutHelpers {
  SeatLayoutHelpers._();

  /// Row seat counts inferred from API `seatNumber` values (`row-col`).
  static List<int>? inferRowCountsFromSeatNumbers(List<SeatData> seats) {
    if (seats.isEmpty) return null;
    final byRow = <int, int>{};
    for (final s in seats) {
      final c = parseBackendSeatId(s.seatNumber);
      if (c == null) continue;
      byRow[c.row] = (byRow[c.row] ?? 0) + 1;
    }
    if (byRow.isEmpty) return null;
    final sorted = byRow.keys.toList()..sort();
    return sorted.map((r) => byRow[r]!).toList();
  }

  /// Prefer layout from trip JSON when it matches [tripTotalSeats]; otherwise infer
  /// from [seats] so UI does not show stale `rows × seatsPerRow` from the vehicle.
  static List<int> effectiveRowSeatCountsForTrip(
    SeatLayoutConfig layout,
    List<SeatData> seats,
    int tripTotalSeats,
  ) {
    final fromConfig = rowSeatCounts(layout);
    final configSum = fromConfig.fold<int>(0, (a, b) => a + b);
    if (tripTotalSeats > 0 && configSum == tripTotalSeats) {
      return fromConfig;
    }
    final inferred = inferRowCountsFromSeatNumbers(seats);
    if (inferred != null && tripTotalSeats > 0) {
      final infSum = inferred.fold<int>(0, (a, b) => a + b);
      if (infSum == tripTotalSeats) {
        return inferred;
      }
    }
    return fromConfig;
  }

  /// Row pattern for UI: digits and `×` only (e.g. `1 × 3`, `1 × 3 × 3`).
  static String formatTripSeatLayoutPattern(
    SeatLayoutConfig layout,
    List<SeatData> seats,
    int tripTotalSeats,
  ) {
    final rows = effectiveRowSeatCountsForTrip(layout, seats, tripTotalSeats);
    final sum = rows.fold<int>(0, (a, b) => a + b);
    if (tripTotalSeats > 0 && sum != tripTotalSeats) {
      return '$tripTotalSeats';
    }
    if (sum == 0) {
      return tripTotalSeats > 0 ? '$tripTotalSeats' : '0';
    }
    return rows.join(' × ');
  }

  /// Layout JSON aligned with [TripModel.seats] / [TripModel.totalSeats] for mapping & validation.
  static SeatLayoutConfig effectiveSeatLayoutConfigForTrip(TripModel trip) {
    final counts = effectiveRowSeatCountsForTrip(
      trip.seatLayout,
      trip.seats,
      trip.totalSeats,
    );
    if (counts.isEmpty) {
      return trip.seatLayout;
    }
    final uniform = counts.every((e) => e == counts.first);
    if (uniform) {
      return SeatLayoutConfig(
        rows: counts.length,
        seatsPerRow: counts.first,
        seatsPerRowList: null,
        preventGenderMixing: trip.seatLayout.preventGenderMixing,
      );
    }
    return SeatLayoutConfig(
      rows: counts.length,
      seatsPerRow: 1,
      seatsPerRowList: List<int>.from(counts),
      preventGenderMixing: trip.seatLayout.preventGenderMixing,
    );
  }

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

  /// Visible cabin rows for [availableSeatCount], filling front → back.
  ///
  /// Rows after the last one holding a selected seat are omitted entirely, so
  /// the cabin preview grows/shrinks with the count. Unused slots inside the
  /// last visible row stay in the list flagged as unavailable.
  ///
  /// Clamps the count to `1..max`; returns an empty list when [rowCounts] is
  /// empty or holds no seats.
  static List<ProgressiveCabinRow> progressiveCabinRows({
    required List<int> rowCounts,
    required int availableSeatCount,
  }) {
    if (rowCounts.isEmpty) return const [];

    final maxSeats = rowCounts.fold<int>(0, (sum, n) => sum + n);
    if (maxSeats <= 0) return const [];

    var selected = availableSeatCount;
    if (selected < 1) selected = 1;
    if (selected > maxSeats) selected = maxSeats;

    // Last layout row index that contains a selected passenger seat.
    var covered = 0;
    var lastVisibleRow = 0;
    for (var i = 0; i < rowCounts.length; i++) {
      covered += rowCounts[i];
      lastVisibleRow = i;
      if (covered >= selected) break;
    }

    var seatIndex = 0;
    final rows = <ProgressiveCabinRow>[];
    for (var row = 0; row <= lastVisibleRow; row++) {
      final count = rowCounts[row];
      final passengers = <ProgressiveCabinSeat>[];
      for (var col = 0; col < count; col++) {
        passengers.add(ProgressiveCabinSeat(isAvailable: seatIndex < selected));
        seatIndex++;
      }
      rows.add(
        ProgressiveCabinRow(
          layoutRowIndex: row,
          showDriver: row == 0,
          passengerSeats: passengers,
        ),
      );
    }
    return rows;
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

/// One passenger slot in a visible cabin row.
class ProgressiveCabinSeat {
  const ProgressiveCabinSeat({required this.isAvailable});

  /// False for slots the driver did not publish (drawn as an inactive outline).
  final bool isAvailable;
}

/// A cabin row that should be drawn for the current seat count.
class ProgressiveCabinRow {
  const ProgressiveCabinRow({
    required this.layoutRowIndex,
    required this.showDriver,
    required this.passengerSeats,
  });

  /// Index into the full vehicle `rowCounts` list.
  final int layoutRowIndex;

  /// True only when [layoutRowIndex] == 0; the placeholder is never counted.
  final bool showDriver;

  /// Full width of this layout row, including inactive trailing slots.
  final List<ProgressiveCabinSeat> passengerSeats;
}
