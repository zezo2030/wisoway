import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_client.dart';
import '../../core/services/booking_service.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingService _bookingService = BookingService();

  BookingBloc() : super(const BookingInitial()) {
    on<BookingCreateMultiSeat>(_onCreateMultiSeat);
    on<BookingAutoPick>(_onAutoPick);
    on<BookingAccept>(_onAccept);
    on<BookingReject>(_onReject);
    on<BookingCancel>(_onCancel);
    on<BookingLoadById>(_onLoadById);
    on<BookingLoadMine>(_onLoadMine);
    on<BookingLoadByTrip>(_onLoadByTrip);
    on<BookingLoadPendingCharges>(_onLoadPendingCharges);
    on<BookingReset>(_onReset);
  }

  // ── v2 multi-seat ──────────────────────────────────────────────────────────

  Future<void> _onCreateMultiSeat(
    BookingCreateMultiSeat event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final booking = await _bookingService.createMultiSeat(
        tripId: event.tripId,
        seats: event.seats,
        sharePhoneWithDriver: event.sharePhoneWithDriver,
        isFamilyBooking: event.isFamilyBooking,
      );
      emit(BookingCreated(booking));
    } catch (e) {
      emit(_mapError(e));
    }
  }

  Future<void> _onAutoPick(
    BookingAutoPick event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final booking = await _bookingService.autoPick(
        tripId: event.tripId,
        seatCount: event.seatCount,
        passengers: event.passengers,
        sharePhoneWithDriver: event.sharePhoneWithDriver,
        isFamilyBooking: event.isFamilyBooking,
      );
      emit(BookingCreated(booking));
    } catch (e) {
      emit(_mapError(e));
    }
  }

  // ── Driver actions ─────────────────────────────────────────────────────────

  Future<void> _onAccept(
    BookingAccept event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final booking = await _bookingService.acceptBooking(event.bookingId);
      emit(BookingAccepted(booking));
    } catch (e) {
      emit(_mapError(e));
    }
  }

  Future<void> _onReject(
    BookingReject event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final booking = await _bookingService.rejectBooking(
        event.bookingId,
        reason: event.reason,
      );
      emit(BookingRejected(booking));
    } catch (e) {
      emit(_mapError(e));
    }
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  Future<void> _onCancel(
    BookingCancel event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      await _bookingService.cancelBooking(event.bookingId, reason: event.reason);
      emit(const BookingCancelled());
    } catch (e) {
      emit(_mapError(e, isCancellation: true));
    }
  }

  Future<void> _onLoadById(
    BookingLoadById event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final booking = await _bookingService.getBooking(event.bookingId);
      if (booking != null) {
        emit(BookingLoaded(booking));
      } else {
        emit(const BookingError('الحجز غير موجود'));
      }
    } catch (e) {
      emit(_mapError(e));
    }
  }

  Future<void> _onLoadMine(
    BookingLoadMine event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final bookings = await _bookingService.getMyBookings(status: event.status);
      emit(BookingListLoaded(bookings));
    } catch (e) {
      emit(_mapError(e));
    }
  }

  Future<void> _onLoadByTrip(
    BookingLoadByTrip event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final bookings = await _bookingService.getTripBookings(event.tripId);
      emit(BookingListLoaded(bookings));
    } catch (e) {
      emit(_mapError(e));
    }
  }

  Future<void> _onLoadPendingCharges(
    BookingLoadPendingCharges event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final charges = await _bookingService.getMyPendingCharges();
      emit(BookingPendingChargesLoaded(charges));
    } catch (e) {
      emit(_mapError(e));
    }
  }

  void _onReset(BookingReset event, Emitter<BookingState> emit) {
    emit(const BookingInitial());
  }

  // ── Error mapping ──────────────────────────────────────────────────────────

  /// Maps any thrown error to [BookingError], with special handling for the
  /// 403 cancellation-window payload: `{ windowSeconds: 3600 }`.
  BookingError _mapError(Object error, {bool isCancellation = false}) {
    if (isCancellation && error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      if (statusCode == 403 && data is Map) {
        final windowSeconds =
            data['windowSeconds'] as int? ??
            data['data']?['windowSeconds'] as int?;
        return BookingError(
          'لا يمكن الإلغاء في هذه المرحلة',
          failure: ApiClient.mapError(error),
          isCancellationWindowError: true,
          windowSeconds: windowSeconds,
        );
      }
    }
    final failure = ApiClient.mapError(error);
    return BookingError(failure.messageKey, failure: failure);
  }
}
