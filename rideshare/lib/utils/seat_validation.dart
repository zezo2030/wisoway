import '../models/trip_model.dart';
import '../models/seat_data.dart';

class SeatValidation {
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
  }) {
    if (seatNumber < 1 || seatNumber > trip.totalSeats) {
      return false;
    }

    final seatData = _seatAt(trip, seatNumber);
    if (seatData == null || seatData.isBooked) {
      return false;
    }

    // If gender mixing is not prevented, allow selection
    if (!trip.seatLayout.preventGenderMixing) {
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
    final seatLayout = trip.seatLayout;
    final row = _getRow(seatNumber, seatLayout.seatsPerRow);
    final col = _getColumn(seatNumber, seatLayout.seatsPerRow);

    // Check left seat
    if (col > 1) {
      final leftSeatNumber = _getSeatNumber(row, col - 1, seatLayout.seatsPerRow);
      if (leftSeatNumber <= trip.totalSeats) {
        final leftSeat = _seatAt(trip, leftSeatNumber);
        if (leftSeat != null && leftSeat.isBooked) {
          final leftGender = leftSeat.gender;
          if (leftGender != null && leftGender != userGender) {
            return true; // Gender conflict
          }
        }
      }
    }

    // Check right seat
    if (col < seatLayout.seatsPerRow) {
      final rightSeatNumber = _getSeatNumber(row, col + 1, seatLayout.seatsPerRow);
      if (rightSeatNumber <= trip.totalSeats) {
        final rightSeat = _seatAt(trip, rightSeatNumber);
        if (rightSeat != null && rightSeat.isBooked) {
          final rightGender = rightSeat.gender;
          if (rightGender != null && rightGender != userGender) {
            return true; // Gender conflict
          }
        }
      }
    }

    // Check front seat (same column, previous row)
    if (row > 1) {
      final frontSeatNumber = _getSeatNumber(row - 1, col, seatLayout.seatsPerRow);
      if (frontSeatNumber <= trip.totalSeats) {
        final frontSeat = _seatAt(trip, frontSeatNumber);
        if (frontSeat != null && frontSeat.isBooked) {
          final frontGender = frontSeat.gender;
          if (frontGender != null && frontGender != userGender) {
            return true; // Gender conflict (if seats are very close)
          }
        }
      }
    }

    // Check back seat (same column, next row)
    if (row < seatLayout.rows) {
      final backSeatNumber = _getSeatNumber(row + 1, col, seatLayout.seatsPerRow);
      if (backSeatNumber <= trip.totalSeats) {
        final backSeat = _seatAt(trip, backSeatNumber);
        if (backSeat != null && backSeat.isBooked) {
          final backGender = backSeat.gender;
          if (backGender != null && backGender != userGender) {
            return true; // Gender conflict (if seats are very close)
          }
        }
      }
    }

    return false; // No gender conflict
  }

  // Get row number from seat number (1-based)
  static int _getRow(int seatNumber, int seatsPerRow) {
    return ((seatNumber - 1) ~/ seatsPerRow) + 1;
  }

  // Get column number from seat number (1-based)
  static int _getColumn(int seatNumber, int seatsPerRow) {
    return ((seatNumber - 1) % seatsPerRow) + 1;
  }

  // Get seat number from row and column (1-based)
  static int _getSeatNumber(int row, int col, int seatsPerRow) {
    return (row - 1) * seatsPerRow + col;
  }

  // Get available seats for a user based on gender
  static List<int> getAvailableSeats({
    required TripModel trip,
    required String userGender,
  }) {
    final availableSeats = <int>[];

    for (int i = 1; i <= trip.totalSeats; i++) {
      if (canSelectSeat(
        trip: trip,
        seatNumber: i,
        userGender: userGender,
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

    // Check if seat can be selected
    if (userGender != null) {
      if (canSelectSeat(
        trip: trip,
        seatNumber: seatNumber,
        userGender: userGender,
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
  available,    // Available for booking
  booked,       // Already booked
  unavailable,  // Not available (gender conflict or other reason)
  invalid,      // Invalid seat number
}

