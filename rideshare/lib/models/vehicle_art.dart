import 'vehicle_art_catalog.dart';

/// One bookable seat's footprint on a vehicle image, as a fraction of the
/// image's width and height so it survives any render size.
class SeatSlot {
  const SeatSlot({
    required this.row,
    required this.col,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Backend seat id coordinates (`row-col`). Kept alongside the geometry so a
  /// slot can be traced back to the seat the API booked.
  final int row;
  final int col;

  final double left;
  final double top;
  final double width;
  final double height;
}

/// The top-view artwork for a vehicle type plus where its seats sit on it.
class VehicleArt {
  const VehicleArt({
    required this.asset,
    required this.aspectRatio,
    required this.seats,
  });

  final String asset;

  /// Width / height of the artwork. The cabin view locks to this so seat
  /// rectangles never drift from the seats underneath them.
  final double aspectRatio;

  /// Ordered front-to-back, left-to-right — index `n - 1` is display seat `n`,
  /// matching the backend's `seatsPerRowList` flattening.
  final List<SeatSlot> seats;

  int get seatCount => seats.length;
}

/// Artwork for [vehicleType], or null when the type has none — callers must
/// fall back to the plain seat grid so retired types and older drivers still
/// render.
VehicleArt? vehicleArtFor(String? vehicleType) {
  if (vehicleType == null) return null;
  return kVehicleArtCatalog[vehicleType.toLowerCase().trim()];
}
