import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/trip_service.dart';
import '../../core/services/location_service.dart';
import '../../core/api/api_client.dart';
import 'trip_event.dart';
import 'trip_state.dart';

class TripBloc extends Bloc<TripEvent, TripState> {
  final TripService _tripService = TripService();
  final LocationService _locationService = LocationService();

  TripBloc() : super(const TripInitial()) {
    on<TripCreate>(_onCreate);
    on<TripGetById>(_onGetById);
    on<TripGetDriverTrips>(_onGetDriverTrips);
    on<TripHide>(_onHide);
    on<TripShow>(_onShow);
    on<TripDelete>(_onDelete);
    on<TripGetCurrentLocation>(_onGetCurrentLocation);
    on<TripGetAddressFromCoordinates>(_onGetAddressFromCoordinates);
    on<TripGetCoordinatesFromAddress>(_onGetCoordinatesFromAddress);
    on<TripClearError>(_onClearError);
  }

  Future<void> _onCreate(TripCreate event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final tripId = await _tripService.createTrip(
        from: event.from,
        to: event.to,
        departureTime: event.departureTime,
        price: event.price,
        currency: event.currency,
        carImageUrl: null,
      );
      emit(TripCreated(tripId));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onGetById(TripGetById event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final trip = await _tripService.getTrip(event.tripId);
      if (trip != null) {
        emit(TripLoaded(trip));
      } else {
        emit(const TripError('الرحلة غير موجودة'));
      }
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onGetDriverTrips(
    TripGetDriverTrips event,
    Emitter<TripState> emit,
  ) async {
    emit(const TripLoading());
    try {
      final trips = await _tripService.getDriverTrips(status: null);
      emit(TripDriverTripsLoaded(trips));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onHide(TripHide event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      await _tripService.hideTrip(event.tripId);
      emit(const TripHidden());
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onShow(TripShow event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      await _tripService.showTrip(event.tripId);
      emit(const TripShown());
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onDelete(TripDelete event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      await _tripService.cancelTrip(event.tripId);
      emit(const TripDeleted());
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onGetCurrentLocation(
    TripGetCurrentLocation event,
    Emitter<TripState> emit,
  ) async {
    emit(const TripLoading());
    try {
      final location = await _locationService.getCurrentLocation();
      emit(TripLocationLoaded(location));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onGetAddressFromCoordinates(
    TripGetAddressFromCoordinates event,
    Emitter<TripState> emit,
  ) async {
    try {
      final address = await _locationService.getAddressFromCoordinates(
        latitude: event.latitude,
        longitude: event.longitude,
      );
      emit(TripAddressLoaded(address));
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  Future<void> _onGetCoordinatesFromAddress(
    TripGetCoordinatesFromAddress event,
    Emitter<TripState> emit,
  ) async {
    emit(const TripLoading());
    try {
      final location = await _locationService.getCoordinatesFromAddress(
        event.address,
      );
      if (location != null) {
        emit(TripLocationLoaded(location));
      } else {
        emit(const TripError('فشل في الحصول على إحداثيات الموقع'));
      }
    } catch (e) {
      final failure = ApiClient.mapError(e);
      emit(TripError(failure.messageKey, failure: failure));
    }
  }

  void _onClearError(TripClearError event, Emitter<TripState> emit) {
    emit(const TripInitial());
  }
}
