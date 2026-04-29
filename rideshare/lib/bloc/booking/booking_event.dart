import 'package:equatable/equatable.dart';
import '../../core/services/booking_service.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

// ── v2 multi-seat ────────────────────────────────────────────────────────────

/// Create a multi-seat booking with explicit companion data.
class BookingCreateMultiSeat extends BookingEvent {
  final String tripId;
  final List<BookingSeatRequest> seats;
  final bool sharePhoneWithDriver;

  const BookingCreateMultiSeat({
    required this.tripId,
    required this.seats,
    this.sharePhoneWithDriver = false,
  });

  @override
  List<Object?> get props => [tripId, seats, sharePhoneWithDriver];
}

/// Auto-pick seats on behalf of the user.
class BookingAutoPick extends BookingEvent {
  final String tripId;
  final int seatCount;
  final List<BookingSeatRequest> passengers;
  final bool sharePhoneWithDriver;

  const BookingAutoPick({
    required this.tripId,
    required this.seatCount,
    required this.passengers,
    this.sharePhoneWithDriver = false,
  });

  @override
  List<Object?> get props => [tripId, seatCount, passengers, sharePhoneWithDriver];
}

// ── Driver actions ────────────────────────────────────────────────────────────

/// Driver accepts a pending booking.
class BookingAccept extends BookingEvent {
  final String bookingId;

  const BookingAccept(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

/// Driver rejects a pending booking.
class BookingReject extends BookingEvent {
  final String bookingId;
  final String? reason;

  const BookingReject(this.bookingId, {this.reason});

  @override
  List<Object?> get props => [bookingId, reason];
}

// ── Shared ────────────────────────────────────────────────────────────────────

/// Passenger or driver cancels a booking.
class BookingCancel extends BookingEvent {
  final String bookingId;
  final String? reason;

  const BookingCancel(this.bookingId, {this.reason});

  @override
  List<Object?> get props => [bookingId, reason];
}

/// Load a single booking by ID.
class BookingLoadById extends BookingEvent {
  final String bookingId;

  const BookingLoadById(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

/// Load all bookings for the current user.
class BookingLoadMine extends BookingEvent {
  final String? status;

  const BookingLoadMine({this.status});

  @override
  List<Object?> get props => [status];
}

/// Load all bookings for a specific trip (driver view).
class BookingLoadByTrip extends BookingEvent {
  final String tripId;

  const BookingLoadByTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

/// Load outstanding pending charges for the current user.
class BookingLoadPendingCharges extends BookingEvent {
  const BookingLoadPendingCharges();
}

/// Reset state back to [BookingInitial].
class BookingReset extends BookingEvent {
  const BookingReset();
}
