import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// The illustration on a home ride-mode card: the white sedan from our own
/// assets in front of a soft skyline, with a dashed route to a pin. The
/// shared variant queues three riders along that route.
///
/// Everything but the car is painted, so the scene follows the card's accent
/// and the theme instead of shipping one raster per colour.
class RideModeArtwork extends StatelessWidget {
  const RideModeArtwork({
    super.key,
    required this.accent,
    required this.shared,
    this.height = 118,
  });

  final Color accent;
  final bool shared;
  final double height;

  static const String carAsset = 'assets/images/presence_vehicle_fallback.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final carWidth = w * 0.86;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScenePainter(
                    accent: accent,
                    shared: shared,
                    surface: T.surface(context),
                  ),
                ),
              ),
              // Pin at the end of the route.
              PositionedDirectional(
                end: w * 0.06,
                top: shared ? 6 : 2,
                child: Icon(Icons.location_on, size: 24, color: accent),
              ),
              if (shared) ..._riders(context, w),
              Positioned(
                left: (w - carWidth) / 2,
                bottom: 0,
                width: carWidth,
                child: Image.asset(
                  carAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.directions_car,
                    size: height * 0.5,
                    color: accent,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Three riders on the route, in the mockup's pastel circles.
  List<Widget> _riders(BuildContext context, double width) {
    const colors = [Color(0xFFE0F2F1), Color(0xFFFFF3E0), Color(0xFFFCE4EC)];
    const tints = [Color(0xFF00897B), Color(0xFFEF6C00), Color(0xFFD81B60)];
    final positions = [0.18, 0.44, 0.68];
    return [
      for (var i = 0; i < 3; i++)
        Positioned(
          left: width * positions[i] - 14,
          top: i == 1 ? 0 : 8,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(Icons.person, size: 16, color: tints[i]),
          ),
        ),
    ];
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.accent,
    required this.shared,
    required this.surface,
  });

  final Color accent;
  final bool shared;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.78;

    // Skyline: a row of soft blocks in the accent tint.
    final sky = Paint()..color = accent.withValues(alpha: 0.10);
    final blocks = [
      (0.02, 0.36, 0.12),
      (0.16, 0.50, 0.10),
      (0.28, 0.30, 0.14),
      (0.44, 0.58, 0.12),
      (0.58, 0.40, 0.10),
      (0.70, 0.52, 0.14),
      (0.86, 0.34, 0.12),
    ];
    for (final (x, top, bw) in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * x, h * top, w * (x + bw), ground),
          const Radius.circular(2),
        ),
        sky,
      );
    }

    // Trees either side.
    final leaf = Paint()..color = accent.withValues(alpha: 0.22);
    final trunk = Paint()..color = accent.withValues(alpha: 0.35);
    for (final x in [w * 0.06, w * 0.94]) {
      canvas.drawRect(Rect.fromLTWH(x - 1.5, ground - 14, 3, 14), trunk);
      canvas.drawCircle(Offset(x, ground - 20), 9, leaf);
    }

    // Ground line.
    canvas.drawLine(
      Offset(0, ground),
      Offset(w, ground),
      Paint()
        ..color = accent.withValues(alpha: 0.18)
        ..strokeWidth = 1.5,
    );

    // Dashed route to the pin (right side, above the car).
    final route = Path();
    if (shared) {
      route.moveTo(w * 0.18, 22);
      route.quadraticBezierTo(w * 0.31, 8, w * 0.44, 14);
      route.quadraticBezierTo(w * 0.56, 20, w * 0.68, 22);
      route.quadraticBezierTo(w * 0.82, 24, w * 0.91, 26);
    } else {
      route.moveTo(w * 0.50, h * 0.55);
      route.quadraticBezierTo(w * 0.70, h * 0.50, w * 0.80, h * 0.34);
      route.quadraticBezierTo(w * 0.88, h * 0.24, w * 0.91, 24);
    }
    _drawDashed(
      canvas,
      route,
      Paint()
        ..color = accent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.accent != accent || old.shared != shared || old.surface != surface;
}
