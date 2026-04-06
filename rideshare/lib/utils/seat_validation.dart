import '../models/trip_model.dart';
import '../models/seat_data.dart';
import 'seat_layout_helpers.dart';

class SeatValidation {
  /// All seats must form one connected group (same adjacency as backend).
  static bool isContiguousSeatGroup(TripModel trip, Set<int> displayIndices) {
    if (displayIndices.length <= 1) return true;
    final layout = trip.seatLayout;
    final configs = SeatLayoutHelpers.rowSeatCounts(layout);
    final keys = <String>{};
    for (final idx in displayIndices) {
      final c = SeatLayoutHelpers.displayIndexToBackendCoords(idx, layout);
      if (c == null) return false;
      keys.add('${c.row},${c.col}');
    }
    if (keys.length != displayIndices.length) return false;

    Iterable<SeatLayoutCoords> neighbors(int row, int col) sync* {
      if (col > 0) yield SeatLayoutCoords(row, col - 1);
      if (col < configs[row] - 1) yield SeatLayoutCoords(row, col + 1);
      if (row > 0 && col < configs[row - 1]) {
        yield SeatLayoutCoords(row - 1, col);
      }
      if (row < configs.length - 1 && col < configs[row + 1]) {
        yield SeatLayoutCoords(row + 1, col);
      }
    }

    final sorted = displayIndices.toList()..sort();
    final start =
        SeatLayoutHelpers.displayIndexToBackendCoords(sorted.first, layout);
    if (start == null) return false;

    final visited = <String>{};
    final stack = <SeatLayoutCoords>[start];
    visited.add('${start.row},${start.col}');

    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final n in neighbors(cur.row, cur.col)) {
        final k = '${n.row},${n.col}';
        if (!keys.contains(k) || visited.contains(k)) continue;
        visited.add(k);
        stack.add(n);
      }
    }

    return visited.length == keys.length;
  }

  static SeatData? _seatAt(TripModel trip, int oneBasedSeatNumber) {
    if (oneBasedSeatNumber < 1 || oneBasedSeatNumber > trip.seats.length) {
      return null;
    }
    return trip.seats[oneBasedSeatNumber - 1];
  }

  // Check if a seat can be selected by a user
  // Returns true if seat can be selected, false otherwise
  static bool canSelectSeat({
    required TripModel trip,
    required int seatNumber,
    required String userGender,
    String? currentUserId,
  }) {
    if (seatNumber < 1 || seatNumber > trip.totalSeats) {
      return false;
    }

    final seatData = _seatAt(trip, seatNumber);
    if (seatData == null || seatData.isBooked || seatData.isLocked) {
      return false;
    }

    // If gender mixing is not prevented, allow selection
    if (!trip.seatLayout.preventGenderMixing) {
      return true;
    }

    // Check adjacent seats for gender mixing
    return !_hasGenderConflict(
      trip,
      seatNumber,
      userGender,
      currentUserId: currentUserId,
    );
  }

  // Check if selecting this seat would cause gender mixing
  static bool _hasGenderConflict(
    TripModel trip,
    int seatNumber,
    String userGender, {
    String? currentUserId,
  }) {
    final seatLayout = trip.seatLayout;
    final coords =
        SeatLayoutHelpers.displayIndexToBackendCoords(seatNumber, seatLayout);
    if (coords == null) return false;

    final configs = SeatLayoutHelpers.rowSeatCounts(seatLayout);
    final row = coords.row;
    final col = coords.col;

    bool bookedOpposite(int? idx) {
      if (idx == null || idx > trip.totalSeats) return false;
      final s = _seatAt(trip, idx);
      if (s == null || !s.isBooked) return false;
      // مقعد محجوز لنفس المستخدم: لا يُعتبر اختلاطاً (حجز مقاعد مجاورة إضافية)
      if (currentUserId != null &&
          s.userId != null &&
          s.userId == currentUserId) {
        return false;
      }
      final g = s.gender;
      return g != null && g != userGender;
    }

    // Left (same row)
    if (col > 0) {
      final leftIdx = SeatLayoutHelpers.backendCoordsToDisplayIndex(
        seatLayout,
        row,
        col - 1,
      );
      if (bookedOpposite(leftIdx)) return true;
    }

    // Right (same row)
    if (col < configs[row] - 1) {
      final rightIdx = SeatLayoutHelpers.backendCoordsToDisplayIndex(
        seatLayout,
        row,
        col + 1,
      );
      if (bookedOpposite(rightIdx)) return true;
    }

    // Front row, same column index when that seat exists
    if (row > 0) {
      final prevCount = configs[row - 1];
      if (col < prevCount) {
        final frontIdx = SeatLayoutHelpers.backendCoordsToDisplayIndex(
          seatLayout,
          row - 1,
          col,
        );
        if (bookedOpposite(frontIdx)) return true;
      }
    }

    // Back row, same column index when that seat exists
    if (row < configs.length - 1) {
      final nextCount = configs[row + 1];
      if (col < nextCount) {
        final backIdx = SeatLayoutHelpers.backendCoordsToDisplayIndex(
          seatLayout,
          row + 1,
          col,
        );
        if (bookedOpposite(backIdx)) return true;
      }
    }

    return false;
  }

  // Get available seats for a user based on gender
  static List<int> getAvailableSeats({
    required TripModel trip,
    required String userGender,
    String? currentUserId,
  }) {
    final availableSeats = <int>[];

    for (int i = 1; i <= trip.totalSeats; i++) {
      if (canSelectSeat(
        trip: trip,
        seatNumber: i,
        userGender: userGender,
        currentUserId: currentUserId,
      )) {
        availableSeats.add(i);
      }
    }

    return availableSeats;
  }

  // Get seat status for display
  static SeatStatus getSeatStatus({
    required TripModel trip,
    required int seatNumber,
    String? userGender,
    String? currentUserId,
  }) {
    if (seatNumber < 1 || seatNumber > trip.totalSeats) {
      return SeatStatus.invalid;
    }

    final seatData = _seatAt(trip, seatNumber);
    if (seatData == null) {
      return SeatStatus.invalid;
    }
    if (seatData.isBooked) {
      return SeatStatus.booked;
    }
    if (seatData.isLocked) {
      return SeatStatus.locked;
    }

    // Check if seat can be selected
    if (userGender != null) {
      if (canSelectSeat(
        trip: trip,
        seatNumber: seatNumber,
        userGender: userGender,
        currentUserId: currentUserId,
      )) {
        return SeatStatus.available;
      } else {
        return SeatStatus.unavailable; // Gender conflict
      }
    }

    return SeatStatus.available;
  }
}

enum SeatStatus {
  available, // Available for booking
  booked, // Already booked
  locked, // Blocked by driver (external sale)
  unavailable, // Not available (gender conflict or other reason)
  invalid, // Invalid seat number
}

