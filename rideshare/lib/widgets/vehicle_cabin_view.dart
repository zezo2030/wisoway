import 'package:flutter/material.dart';
import '../models/vehicle_art.dart';

/// Draws a vehicle's top-view artwork and places one caller-built widget over
/// each bookable seat.
///
/// This widget owns geometry only — where the seats are and how big the car is.
/// What a seat looks like (available, booked, selected, blocked) stays with the
/// screen that knows, so seat rules are never duplicated here.
///
/// The driver's seat is part of the artwork and gets no overlay: it is not
/// bookable, so it has no state to show.
class VehicleCabinView extends StatelessWidget {
  const VehicleCabinView({
    super.key,
    required this.art,
    required this.seatBuilder,
    this.maxWidth = 320,
    this.semanticsLabel,
  });

  final VehicleArt art;

  /// Called once per seat with its 1-based display number, which matches the
  /// index used by `TripModel.seats` and the seat-status helpers. Return
  /// [SizedBox.shrink] to leave a seat undrawn.
  final Widget Function(BuildContext context, int seatNumber) seatBuilder;

  /// Caps how wide the cabin is drawn. Tall vehicles (the large bus is roughly
  /// 1:2) would otherwise grow past the screen on wide layouts.
  final double maxWidth;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cabin = AspectRatio(
      aspectRatio: art.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // BoxFit.fill, not contain: the asset is cropped to the vehicle's
              // bounding box and the box is locked to its aspect ratio, so the
              // image exactly fills it and the seat fractions stay true.
              Positioned.fill(
                child: Image.asset(art.asset, fit: BoxFit.fill),
              ),
              for (var i = 0; i < art.seats.length; i++)
                Positioned(
                  left: art.seats[i].left * w,
                  top: art.seats[i].top * h,
                  width: art.seats[i].width * w,
                  height: art.seats[i].height * h,
                  child: seatBuilder(context, i + 1),
                ),
            ],
          );
        },
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: semanticsLabel == null
            ? cabin
            : Semantics(
                container: true,
                label: semanticsLabel,
                child: cabin,
              ),
      ),
    );
  }
}
