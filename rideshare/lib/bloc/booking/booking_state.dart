import 'package:equatable/equatable.dart';
import '../../models/booking_model.dart';
import '../../core/errors/failure.dart';

abstract class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {
  const BookingInitial();
}

class BookingLoading extends BookingState {
  const BookingLoading();
}

// ── Success states ────────────────────────────────────────────────────────────

/// A new booking was created (v2 path).
class BookingCreated extends BookingState {
  final BookingModel booking;

  const BookingCreated(this.booking);

  @override
  List<Object?> get props => [booking];
}

/// A single booking was loaded.
class BookingLoaded extends BookingState {
  final BookingModel booking;

  const BookingLoaded(this.booking);

  @override
  List<Object?> get props => [booking];
}

/// A list of bookings was loaded (mine / by-trip).
class BookingListLoaded extends BookingState {
  final List<BookingModel> bookings;

  const BookingListLoaded(this.bookings);

  @override
  List<Object?> get props => [bookings];
}

/// Driver accepted a booking.
class BookingAccepted extends BookingState {
  final BookingModel booking;

  const BookingAccepted(this.booking);

  @override
  List<Object?> get props => [booking];
}

/// Driver rejected a booking.
class BookingRejected extends BookingState {
  final BookingModel booking;

  const BookingRejected(this.booking);

  @override
  List<Object?> get props => [booking];
}

/// A booking was cancelled.
class BookingCancelled extends BookingState {
  const BookingCancelled();
}

/// Outstanding pending charges loaded.
class BookingPendingChargesLoaded extends BookingState {
  final List<Map<String, dynamic>> charges;

  const BookingPendingChargesLoaded(this.charges);

  @override
  List<Object?> get props => [charges];
}

// ── Error ─────────────────────────────────────────────────────────────────────

class BookingError extends BookingState {
  final String message;
  final Failure? failure;

  /// True when the server returned a 403 with a cancellation-window payload.
  final bool isCancellationWindowError;

  /// Seconds remaining in the refund window (from 403 body).
  final int? windowSeconds;

  const BookingError(
    this.message, {
    this.failure,
    this.isCancellationWindowError = false,
    this.windowSeconds,
  });

  @override
  List<Object?> get props => [message, failure, isCancellationWindowError, windowSeconds];
}
