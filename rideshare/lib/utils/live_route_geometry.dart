import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteProjection {
  final LatLng point;
  final int segment;
  final double offsetMeters;
  const RouteProjection(this.point, this.segment, this.offsetMeters);
}

/// Project fixes onto road segments rather than jumping between route vertices.
class LiveRouteGeometry {
  static double distance(LatLng a, LatLng b) => Geolocator.distanceBetween(
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );

  static double length(List<LatLng> route) {
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += distance(route[i - 1], route[i]);
    }
    return total;
  }

  static RouteProjection? project(List<LatLng> route, LatLng point) {
    RouteProjection? best;
    final scale = math.cos(point.latitude * math.pi / 180);
    for (var i = 0; i + 1 < route.length; i++) {
      final a = route[i], b = route[i + 1];
      final dx = (b.longitude - a.longitude) * scale;
      final dy = b.latitude - a.latitude;
      final denominator = dx * dx + dy * dy;
      final t = denominator == 0
          ? 0.0
          : (((point.longitude - a.longitude) * scale * dx +
                        (point.latitude - a.latitude) * dy) /
                    denominator)
                .clamp(0.0, 1.0);
      final projected = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final meters = distance(point, projected);
      if (best == null || meters < best.offsetMeters) {
        best = RouteProjection(projected, i, meters);
      }
    }
    return best;
  }

  static List<LatLng> remaining(List<LatLng> route, LatLng position) {
    final snap = project(route, position);
    return snap == null ? [] : [snap.point, ...route.sublist(snap.segment + 1)];
  }

  static List<LatLng> movement(List<LatLng> route, LatLng from, LatLng to) {
    final a = project(route, from), b = project(route, to);
    if (a == null ||
        b == null ||
        a.offsetMeters > 60 ||
        b.offsetMeters > 60 ||
        b.segment < a.segment)
      return [from, to];
    return [from, ...route.sublist(a.segment + 1, b.segment + 1), to];
  }

  static (LatLng, double) sample(List<LatLng> route, double fraction) {
    var remaining = length(route) * fraction.clamp(0.0, 1.0);
    for (var i = 1; i < route.length; i++) {
      final a = route[i - 1], b = route[i];
      final meters = distance(a, b);
      if (meters < .01) continue;
      if (remaining <= meters || i == route.length - 1) {
        final t = meters == 0 ? 1.0 : (remaining / meters).clamp(0.0, 1.0);
        return (
          LatLng(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          ),
          bearing(a, b),
        );
      }
      remaining -= meters;
    }
    return (route.first, 0);
  }

  static double bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180,
        lat2 = to.latitude * math.pi / 180;
    final delta = (to.longitude - from.longitude) * math.pi / 180;
    return (math.atan2(
                  math.sin(delta) * math.cos(lat2),
                  math.cos(lat1) * math.sin(lat2) -
                      math.sin(lat1) * math.cos(lat2) * math.cos(delta),
                ) *
                180 /
                math.pi +
            360) %
        360;
  }
}
