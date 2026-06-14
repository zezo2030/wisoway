import '../models/booking_model.dart';
import '../models/trip_model.dart';
import 'seat_layout_helpers.dart';

class BookingSeatFormatter {
  BookingSeatFormatter._();

  static String displaySeatNumber(String seatNumber, TripModel? trip) {
    if (trip == null) return seatNumber;

    final coords = SeatLayoutHelpers.parseBackendSeatId(seatNumber);
    if (coords == null) return seatNumber;

    final layout = SeatLayoutHelpers.effectiveSeatLayoutConfigForTrip(trip);
    final displayIndex = SeatLayoutHelpers.backendCoordsToDisplayIndex(
      layout,
      coords.row,
      coords.col,
    );
    return displayIndex?.toString() ?? seatNumber;
  }

  static String summary(BookingModel booking, TripModel? trip) {
    final rawSeatNumbers = booking.seats.isNotEmpty
        ? booking.seats.map((seat) => seat.seatNumber)
        : [
            if (booking.seatNumber != null && booking.seatNumber!.isNotEmpty)
              booking.seatNumber!,
          ];

    return rawSeatNumbers
        .map((seatNumber) => displaySeatNumber(seatNumber, trip))
        .join(', ');
  }

  static List<int> displaySeatIndexes(BookingModel booking, TripModel trip) {
    final rawSeatNumbers = booking.seats.isNotEmpty
        ? booking.seats.map((seat) => seat.seatNumber)
        : [
            if (booking.seatNumber != null && booking.seatNumber!.isNotEmpty)
              booking.seatNumber!,
          ];

    return rawSeatNumbers
        .map((seatNumber) {
          final coords = SeatLayoutHelpers.parseBackendSeatId(seatNumber);
          if (coords == null) return int.tryParse(seatNumber);
          final layout = SeatLayoutHelpers.effectiveSeatLayoutConfigForTrip(trip);
          return SeatLayoutHelpers.backendCoordsToDisplayIndex(
            layout,
            coords.row,
            coords.col,
          );
        })
        .whereType<int>()
        .toList();
  }
}
