import '../models/trip_model.dart';
import '../models/seat_data.dart';
import 'seat_layout_helpers.dart';

class SeatValidation {
  static SeatData? _seatAt(TripModel trip, int oneBasedSeatNumber) {
    if (oneBasedSeatNumber < 1 || oneBasedSeatNumber > trip.seats.length) {
      return null;
    }
    return trip.seats[oneBasedSeatNumber - 1];
  }

  // Check if a seat can be selected by a user
  // Returns true if seat can be selected, false otherwise
  //
  // [isFamilyBooking] mirrors the API's family exemption: family bookings are
  // not subject to the trip's gender-mixing rules, so the client must not
  // pre-block those seats ahead of the API. Availability (booked / locked /
  // out of range) is still enforced.
  static bool canSelectSeat({
    required TripModel trip,
    required int seatNumber,
    required String userGender,
    bool isFamilyBooking = false,
  }) {
    if (seatNumber < 1 || seatNumber > trip.totalSeats) {
      return false;
    }

    final seatData = _seatAt(trip, seatNumber);
    if (seatData == null || seatData.isBooked || seatData.isLocked) {
      return false;
    }

    // If gender mixing is not prevented — or this is a family booking, which
    // is exempt from those rules — allow selection.
    if (!trip.seatLayout.preventGenderMixing || isFamilyBooking) {
      return true;
    }

    // Check adjacent seats for gender mixing
    return !_hasGenderConflict(trip, seatNumber, userGender);
  }

  // Check if selecting this seat would cause gender mixing
  static bool _hasGenderConflict(
    TripModel trip,
    int seatNumber,
    String userGender,
  ) {
    final seatLayout = SeatLayoutHelpers.effectiveSeatLayoutConfigForTrip(trip);
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
    bool isFamilyBooking = false,
  }) {
    final availableSeats = <int>[];

    for (int i = 1; i <= trip.totalSeats; i++) {
      if (canSelectSeat(
        trip: trip,
        seatNumber: i,
        userGender: userGender,
        isFamilyBooking: isFamilyBooking,
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
    bool isFamilyBooking = false,
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
        isFamilyBooking: isFamilyBooking,
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

