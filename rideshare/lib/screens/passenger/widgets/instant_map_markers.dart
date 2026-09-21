import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map marker sprites for the instant-ride map, drawn in code so they match
/// inDrive's look without shipping raster assets: dark top-down cars for the
/// online drivers around the rider, and ring pins for the two endpoints.
///
/// Everything is rendered once at [pixelRatio] and cached by the caller —
/// `BitmapDescriptor.bytes` with `imagePixelRatio` keeps the on-map size in
/// logical pixels regardless of the device.
class InstantMapMarkers {
  InstantMapMarkers._();

  /// Dark top-view car on a soft white halo, the way inDrive scatters nearby
  /// drivers on the request map. [size] is the logical square the halo fills.
  static Future<BitmapDescriptor> car({
    double size = 56,
    double pixelRatio = 3,
    Color body = const Color(0xFF334155),
    Color halo = const Color(0xFFFFFFFF),
  }) {
    return _render(size, size, pixelRatio, (canvas, w, h) {
      final c = Offset(w / 2, h / 2);
      // Halo — a translucent disc that lifts the car off the map tiles.
      canvas.drawCircle(
        c,
        w / 2,
        Paint()..color = halo.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        c,
        w / 2 - 1,
        Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      _paintCar(canvas, c, w * 0.62, body);
    });
  }

  /// Pickup marker: a filled green disc with a white ring and a short stem,
  /// pointing at the exact spot.
  static Future<BitmapDescriptor> pickup({
    Color color = const Color(0xFF16A34A),
    double pixelRatio = 3,
  }) => _ringPin(color, pixelRatio);

  /// Destination marker: same silhouette in red, so the two ends read as a
  /// pair on the map.
  static Future<BitmapDescriptor> destination({
    Color color = const Color(0xFFEF4444),
    double pixelRatio = 3,
  }) => _ringPin(color, pixelRatio);

  static Future<BitmapDescriptor> _ringPin(Color color, double pixelRatio) {
    const w = 30.0;
    const h = 42.0;
    return _render(w, h, pixelRatio, (canvas, width, height) {
      final head = Offset(width / 2, 14);
      final tip = Offset(width / 2, height - 2);

      // Ground shadow.
      canvas.drawOval(
        Rect.fromCenter(center: tip, width: 12, height: 5),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.18),
      );
      // Stem.
      canvas.drawLine(
        head,
        tip,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      // Head: white ring around the coloured core.
      canvas.drawCircle(head, 12, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(head, 9.5, Paint()..color = color);
      canvas.drawCircle(head, 3.5, Paint()..color = const Color(0xFFFFFFFF));
    });
  }

  /// Simplified sedan seen from above, nose pointing up. [length] is the
  /// body length; width follows at roughly half.
  static void _paintCar(
    Canvas canvas,
    Offset center,
    double length,
    Color body,
  ) {
    final width = length * 0.5;
    final rect = Rect.fromCenter(center: center, width: width, height: length);

    // Tyres peek out from the body on both sides.
    final tyre = Paint()..color = const Color(0xFF0F172A);
    for (final dy in [-length * 0.28, length * 0.3]) {
      for (final dx in [-width * 0.5, width * 0.5]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center.translate(dx, dy),
              width: width * 0.22,
              height: length * 0.18,
            ),
            const Radius.circular(2),
          ),
          tyre,
        );
      }
    }

    // Body.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(width * 0.45),
        topRight: Radius.circular(width * 0.45),
        bottomLeft: Radius.circular(width * 0.3),
        bottomRight: Radius.circular(width * 0.3),
      ),
      Paint()..color = body,
    );

    // Cabin glass — windscreen, roof and rear window in lighter tints.
    final glass = Paint()..color = const Color(0xFF94A3B8);
    final roof = Paint()..color = body.withValues(alpha: 0.7);
    final cabinWidth = width * 0.78;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, -length * 0.16),
          width: cabinWidth,
          height: length * 0.16,
        ),
        Radius.circular(width * 0.15),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, length * 0.06),
          width: cabinWidth,
          height: length * 0.3,
        ),
        Radius.circular(width * 0.12),
      ),
      roof,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, length * 0.3),
          width: cabinWidth * 0.9,
          height: length * 0.12,
        ),
        Radius.circular(width * 0.12),
      ),
      glass,
    );

    // Headlights and tail lights.
    final head = Paint()..color = const Color(0xFFFDE68A);
    final tail = Paint()..color = const Color(0xFFF87171);
    for (final sign in [-1, 1]) {
      canvas.drawCircle(
        center.translate(sign * width * 0.3, -length * 0.44),
        width * 0.07,
        head,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: center.translate(sign * width * 0.3, length * 0.45),
          width: width * 0.18,
          height: length * 0.04,
        ),
        tail,
      );
    }
  }

  static Future<BitmapDescriptor> _render(
    double width,
    double height,
    double pixelRatio,
    void Function(Canvas canvas, double width, double height) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    paint(canvas, width, height);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).round(),
      (height * pixelRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }
}

/// Deterministic pseudo-random heading for the i-th anonymous driver pin so
/// the cars read as live traffic rather than a grid, matching inDrive.
double instantCarHeading(int index) => (index * 67 + 23) % 360 * 1.0;

/// Radius in metres of the pulsing search ring around the pickup, grown from
/// a small disc to the dispatch radius as [t] runs 0 → 1.
double instantPulseRadiusMeters(double t, {double maxMeters = 900}) =>
    200 + (maxMeters - 200) * Curves.easeOut.transform(t);

/// Opacity of the pulsing ring at [t], fading out as it grows.
double instantPulseAlpha(double t) => 0.22 * (1 - t) + 0.04;

/// Convenience for the ring's stroke, kept faint so the route stays legible.
double instantPulseStrokeAlpha(double t) => math.max(0.0, 0.5 * (1 - t));
