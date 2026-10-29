import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rideshare/utils/live_route_geometry.dart';

void main() {
  const road = [LatLng(0, 0), LatLng(0, .01), LatLng(.01, .01)];

  test('projects onto the road segment, not a distant route vertex', () {
    final snap = LiveRouteGeometry.project(road, const LatLng(.0001, .005))!;
    expect(snap.segment, 0);
    expect(snap.point.latitude, closeTo(0, 1e-8));
    expect(snap.point.longitude, closeTo(.005, 1e-8));
    expect(snap.offsetMeters, closeTo(11.1, .2));
  });

  test('trims the completed approach and keeps the road corner', () {
    final remaining = LiveRouteGeometry.remaining(road, const LatLng(0, .005));
    expect(remaining, [const LatLng(0, .005), road[1], road[2]]);
    expect(
      LiveRouteGeometry.length(remaining) / LiveRouteGeometry.length(road),
      closeTo(.75, .001),
    );
  });

  test('animates around a road corner instead of cutting through it', () {
    final movement = LiveRouteGeometry.movement(
      road,
      const LatLng(0, .005),
      const LatLng(.005, .01),
    );
    expect(movement, [const LatLng(0, .005), road[1], const LatLng(.005, .01)]);
    final middle = LiveRouteGeometry.sample(movement, .5).$1;
    expect(middle.latitude, closeTo(0, 1e-7));
    expect(middle.longitude, closeTo(.01, 1e-7));
    expect(LiveRouteGeometry.sample(movement, 1).$1, const LatLng(.005, .01));
  });

  test('does not snap a remote GPS fix across town onto the old route', () {
    expect(
      LiveRouteGeometry.movement(
        road,
        const LatLng(1, 1),
        const LatLng(1.01, 1.01),
      ),
      [const LatLng(1, 1), const LatLng(1.01, 1.01)],
    );
  });

  test('uses the direction of travel for the car heading', () {
    expect(
      LiveRouteGeometry.bearing(const LatLng(0, 0), const LatLng(.01, 0)),
      closeTo(0, .001),
    );
    expect(
      LiveRouteGeometry.bearing(const LatLng(0, 0), const LatLng(0, .01)),
      closeTo(90, .001),
    );
  });
}
