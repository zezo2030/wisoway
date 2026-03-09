import 'package:equatable/equatable.dart';
import 'dart:io';
import '../../models/location_model.dart';
import '../../models/seat_layout_config.dart';

abstract class TripEvent extends Equatable {
  const TripEvent();

  @override
  List<Object?> get props => [];
}

// Create Trip
class TripCreate extends TripEvent {
  final String driverId;
  final String driverName;
  final String driverPhone;
  final LocationModel from;
  final LocationModel to;
  final DateTime departureTime;
  final double price;
  final String currency;
  final SeatLayoutConfig seatLayout;
  final File? carImage;

  const TripCreate({
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.from,
    required this.to,
    required this.departureTime,
    required this.price,
    required this.currency,
    required this.seatLayout,
    this.carImage,
  });

  @override
  List<Object?> get props => [
        driverId,
        driverName,
        driverPhone,
        from,
        to,
        departureTime,
        price,
        currency,
        seatLayout,
        carImage,
      ];
}

// Get Trip by ID
class TripGetById extends TripEvent {
  final String tripId;

  const TripGetById(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

// Get Driver Trips
class TripGetDriverTrips extends TripEvent {
  final String driverId;
  final String? status;

  const TripGetDriverTrips({
    required this.driverId,
    this.status,
  });

  @override
  List<Object?> get props => [driverId, status];
}

// Update Trip
class TripUpdate extends TripEvent {
  final String tripId;
  final Map<String, dynamic> updates;

  const TripUpdate({
    required this.tripId,
    required this.updates,
  });

  @override
  List<Object?> get props => [tripId, updates];
}

// Hide Trip
class TripHide extends TripEvent {
  final String tripId;

  const TripHide(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

// Show Trip
class TripShow extends TripEvent {
  final String tripId;

  const TripShow(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

// Delete Trip
class TripDelete extends TripEvent {
  final String tripId;

  const TripDelete(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

// Book Seat
class TripBookSeat extends TripEvent {
  final String tripId;
  final int seatNumber;
  final String userId;
  final String userName;
  final String gender;

  const TripBookSeat({
    required this.tripId,
    required this.seatNumber,
    required this.userId,
    required this.userName,
    required this.gender,
  });

  @override
  List<Object?> get props => [tripId, seatNumber, userId, userName, gender];
}

// Cancel Seat Booking
class TripCancelSeatBooking extends TripEvent {
  final String tripId;
  final int seatNumber;
  final String userId;

  const TripCancelSeatBooking({
    required this.tripId,
    required this.seatNumber,
    required this.userId,
  });

  @override
  List<Object?> get props => [tripId, seatNumber, userId];
}

// Get Current Location
class TripGetCurrentLocation extends TripEvent {
  const TripGetCurrentLocation();
}

// Get Address from Coordinates
class TripGetAddressFromCoordinates extends TripEvent {
  final double latitude;
  final double longitude;

  const TripGetAddressFromCoordinates({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];
}

// Get Coordinates from Address
class TripGetCoordinatesFromAddress extends TripEvent {
  final String address;

  const TripGetCoordinatesFromAddress(this.address);

  @override
  List<Object?> get props => [address];
}

// Clear Error
class TripClearError extends TripEvent {
  const TripClearError();
}

