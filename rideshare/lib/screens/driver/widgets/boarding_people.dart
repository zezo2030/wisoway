import '../../../models/booking_model.dart';

/// One person on the driver's boarding card: a seat of [booking], or the
/// whole booking when it has no seat rows (older bookings).
class BoardingPerson {
  const BoardingPerson({required this.booking, required this.seat});

  final BookingModel booking;
  final BookingSeatModel? seat;

  /// The name the seat was booked under, else the booker's, else [fallback].
  String name(String fallback) {
    final seatName = seat?.displayName.trim() ?? '';
    if (seatName.isNotEmpty) return seatName;
    final booker = booking.userPopulated?.name.trim() ?? '';
    return booker.isNotEmpty ? booker : fallback;
  }

  bool get hasBoarded => seat?.hasBoarded ?? booking.hasConfirmedBoarding;

  /// The booker answered «لن يستقل الرحلة» for them.
  bool get isNotRiding => seat?.isNotRiding ?? false;
}

/// Everyone booked onto the trip by [riders], one per seat: a booking of three
/// seats is three people, each boarding (or not) on their own.
List<BoardingPerson> boardingPeople(List<BookingModel> riders) => [
  for (final b in riders)
    if (b.seats.isEmpty)
      BoardingPerson(booking: b, seat: null)
    else
      for (final s in b.seats) BoardingPerson(booking: b, seat: s),
];
