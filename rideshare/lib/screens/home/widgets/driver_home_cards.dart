import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';

/// The empty-state card keeps the illustration's own light palette in both
/// themes: the artwork is baked onto [_emptyFill] so its white surround becomes
/// exactly the card colour and the image edge disappears. Following the scheme
/// here would bring that edge straight back.
const Color _emptyFill = Color(0xFFF2F7F6);
const Color _emptyButtonFill = Color(0xFFDFEEEA);
const Color _emptyInk = Color(0xFF10312E);
const Color _emptyInkMuted = Color(0xFF5C7F7A);
const Color _emptyAccent = AppColors.teal700;

/// The surface every driver-home tile shares: white, softly outlined, with the
/// same corner radius and lift the dashboard mockup uses throughout.
class DriverHomeCard extends StatelessWidget {
  const DriverHomeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? T.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? T.outline(context)),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section caption — a tinted glyph, the title, and an optional trailing link.
class DriverHomeSectionHeader extends StatelessWidget {
  const DriverHomeSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: T.primary(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: T.onSurface(context),
            ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// The "view all" affordance next to a section caption.
class DriverHomeSectionLink extends StatelessWidget {
  const DriverHomeSectionLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: T.primary(context),
          ),
        ),
      ),
    );
  }
}

/// One of the three "today's summary" tiles: caption, count and a hint, with
/// the metric's glyph closing the tile.
class DriverHomeStatCard extends StatelessWidget {
  const DriverHomeStatCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.hint,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return DriverHomeCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: T.onSurfaceVariant(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: T.onSurfaceVariant(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
        ],
      ),
    );
  }
}

/// Small square action button — glyph over a two-line caption — as drawn beside
/// the location card in the mockup.
class DriverHomeMiniAction extends StatelessWidget {
  const DriverHomeMiniAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 62,
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: T.outline(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: T.onSurface(context)),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: T.onSurfaceVariant(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state for "your active trips": copy and a publish button beside the
/// parked-car illustration.
class DriverHomeNoTripsCard extends StatelessWidget {
  const DriverHomeNoTripsCard({super.key, required this.onPublish});

  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 16),
      decoration: BoxDecoration(
        color: _emptyFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.noPublishedTripsTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _emptyInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.noPublishedTripsSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: _emptyInkMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Material(
                    color: _emptyButtonFill,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onPublish,
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        child: _PublishNowLabel(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Contained, never cropped: the art carries the card colour out to
          // its own edges, so a crop would cut through the scene instead.
          Image.asset(
            'assets/illustrations/driver/driver_home_no_trips.webp',
            width: 132,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _PublishNowLabel extends StatelessWidget {
  const _PublishNowLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.publishTripNow,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _emptyAccent,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(IconsaxPlusLinear.add_circle, size: 18, color: _emptyAccent),
      ],
    );
  }
}

/// The faint road-and-pins doodle behind the publish-a-trip tile.
class RouteDoodlePainter extends CustomPainter {
  const RouteDoodlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.86,
        size.width * 0.30,
        size.height * 0.36,
        size.width * 0.58,
        size.height * 0.40,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.44,
        size.width * 0.72,
        size.height * 0.16,
        size.width * 0.92,
        size.height * 0.20,
      );

    // Dashed, the way a route preview reads on a map.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 9).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), stroke);
        distance = next + 7;
      }
    }

    _drawPin(canvas, Offset(size.width * 0.08, size.height * 0.78), fill);
    _drawPin(canvas, Offset(size.width * 0.92, size.height * 0.20), fill);
  }

  void _drawPin(Canvas canvas, Offset tip, Paint paint) {
    final center = tip.translate(0, -11);
    canvas.drawCircle(center, 7, paint);
    final tail = Path()
      ..moveTo(center.dx - 5, center.dy + 4)
      ..lineTo(center.dx + 5, center.dy + 4)
      ..lineTo(center.dx, center.dy + 13)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant RouteDoodlePainter oldDelegate) =>
      oldDelegate.color != color;
}
