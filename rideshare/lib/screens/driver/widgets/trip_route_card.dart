import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';

/// Origin → destination card for the driver's pre-departure trip screen.
///
/// Takes plain values rather than a `TripModel` so it stays testable without
/// model fixtures. `footer` is rendered inside the same card below a divider —
/// the pre-departure body passes [TripFactsStrip] there, matching the mock
/// where the route and the facts share one white surface.
///
/// Colours come from the app theme (`colorScheme.primary` — teal600), not from
/// the mock's forest green.
class TripRouteCard extends StatelessWidget {
  const TripRouteCard({
    super.key,
    required this.fromName,
    required this.toName,
    this.footer,
  });

  final String fromName;
  final String toName;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _Endpoint(
                    label: l10n.fromLabel,
                    name: fromName,
                    alignment: CrossAxisAlignment.start,
                    textAlign: TextAlign.start,
                    marker: _OriginDot(color: T.primary(context)),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: _Endpoint.markerHeight,
                    child: _RouteConnector(color: T.primary(context)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _Endpoint(
                    label: l10n.toLabel,
                    name: toName,
                    alignment: CrossAxisAlignment.end,
                    textAlign: TextAlign.end,
                    marker: const Icon(
                      IconsaxPlusBold.location,
                      size: _Endpoint.markerHeight,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (footer != null) ...[
            Divider(height: 1, thickness: 1, color: T.outlineVariant(context)),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.name,
    required this.alignment,
    required this.textAlign,
    required this.marker,
  });

  static const double markerHeight = 24;

  final String label;
  final String name;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;
  final Widget marker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        SizedBox(height: markerHeight, child: Center(child: marker)),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: textAlign,
          style: AppTextStyles.labelSmall.copyWith(
            color: T.textSecondary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          textAlign: textAlign,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: T.onSurface(context),
          ),
        ),
      ],
    );
  }
}

class _OriginDot extends StatelessWidget {
  const _OriginDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Dashed line with the car glyph in a filled circle at its centre.
class _RouteConnector extends StatelessWidget {
  const _RouteConnector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final dash = Expanded(
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: T.outlineVariant(context),
        ),
        child: const SizedBox(height: 2),
      ),
    );

    return Row(
      children: [
        dash,
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(
            IconsaxPlusBold.car,
            size: 16,
            color: T.onPrimary(context),
          ),
        ),
        dash,
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const gapWidth = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
