import 'package:equatable/equatable.dart';
import '../../models/trip_model.dart';
import '../../models/location_model.dart';
import '../../core/errors/failure.dart';

abstract class TripState extends Equatable {
  const TripState();

  @override
  List<Object?> get props => [];
}

// Initial State
class TripInitial extends TripState {
  const TripInitial();
}

// Loading State
class TripLoading extends TripState {
  const TripLoading();
}

// Trip Created
class TripCreated extends TripState {
  final String tripId;

  const TripCreated(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

// Trip Loaded
class TripLoaded extends TripState {
  final TripModel trip;

  const TripLoaded(this.trip);

  @override
  List<Object?> get props => [trip];
}

// Driver Trips Loaded
class TripDriverTripsLoaded extends TripState {
  final List<TripModel> trips;

  const TripDriverTripsLoaded(this.trips);

  @override
  List<Object?> get props => [trips];
}

// Trip Updated
class TripUpdated extends TripState {
  final TripModel trip;

  const TripUpdated(this.trip);

  @override
  List<Object?> get props => [trip];
}

// Trip Hidden
class TripHidden extends TripState {
  const TripHidden();
}

// Trip Shown
class TripShown extends TripState {
  const TripShown();
}

// Trip Deleted
class TripDeleted extends TripState {
  const TripDeleted();
}

// Seat Booked
class TripSeatBooked extends TripState {
  const TripSeatBooked();
}

// Seat Booking Cancelled
class TripSeatBookingCancelled extends TripState {
  const TripSeatBookingCancelled();
}

// Location Loaded
class TripLocationLoaded extends TripState {
  final LocationModel location;

  const TripLocationLoaded(this.location);

  @override
  List<Object?> get props => [location];
}

// Address Loaded
class TripAddressLoaded extends TripState {
  final String address;

  const TripAddressLoaded(this.address);

  @override
  List<Object?> get props => [address];
}

// Error State
class TripError extends TripState {
  final String message;
  final Failure? failure;

  const TripError(this.message, {this.failure});

  @override
  List<Object?> get props => [message, failure];
}

