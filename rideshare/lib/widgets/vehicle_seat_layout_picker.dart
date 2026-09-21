import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';
import '../l10n/l10n_extensions.dart';
import '../models/seat_layout_config.dart';
import '../models/vehicle_art.dart';
import '../utils/seat_layout_helpers.dart';
import 'expandable_cabin_view.dart';

/// Top-down cabin preview + stepper used when publishing a trip.
///
/// The layout *shape* is fixed by the driver's vehicle (or its type template);
/// only the number of published passenger seats can be changed here. The driver
/// placeholder drawn next to the first row is UI-only and is never counted.
class VehicleSeatLayoutPicker extends StatefulWidget {
  const VehicleSeatLayoutPicker({
    super.key,
    required this.layout,
    required this.availableSeatCount,
    required this.onAvailableSeatCountChanged,
    this.vehicleType,
  });

  final SeatLayoutConfig layout;

  /// Picks the cabin artwork. Null, unknown, or a type whose artwork does not
  /// match this layout's seat count falls back to the schematic cabin.
  final String? vehicleType;
  final int availableSeatCount;
  final ValueChanged<int> onAvailableSeatCountChanged;

  @override
  State<VehicleSeatLayoutPicker> createState() =>
      _VehicleSeatLayoutPickerState();
}

class _VehicleSeatLayoutPickerState extends State<VehicleSeatLayoutPicker> {
  static const double _stepperWidth = 116;
  static const double _columnGap = 10;

  /// Mirrors the published count so the expanded picker, which is pushed once
  /// and keeps its own element tree, can read the current value instead of the
  /// one captured when it opened.
  late int _count = widget.availableSeatCount;

  @override
  void didUpdateWidget(VehicleSeatLayoutPicker old) {
    super.didUpdateWidget(old);
    if (widget.availableSeatCount != old.availableSeatCount) {
      _count = widget.availableSeatCount;
    }
  }

  void _setCount(int value) {
    setState(() => _count = value);
    widget.onAvailableSeatCountChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final rowCounts = SeatLayoutHelpers.rowSeatCounts(widget.layout);
    final maxSeats = rowCounts.fold<int>(0, (sum, count) => sum + count);
    final selected = _clampInt(_count, 1, maxSeats);

    if (maxSeats <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final free = math.max(
          0.0,
          constraints.maxWidth - _stepperWidth - (_columnGap * 2),
        );
        final cabinCrossSize = _clampDouble(free * 0.58, 100, 170);
        final cabinRows = SeatLayoutHelpers.progressiveCabinRows(
          rowCounts: rowCounts,
          availableSeatCount: selected,
        );

        final art = vehicleArtFor(widget.vehicleType);
        final useArt = art != null && art.seatCount == maxSeats;

        // The cabin itself must not mirror — the driver sits on the left —
        // so this subtree opts out of RTL.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vehicle artwork is portrait and can run to 1:2, so at this size
              // a bus is only a thumbnail. Tapping it opens the full-screen
              // picker where the seats are big enough to read and choose.
              if (useArt)
                ExpandableCabinView(
                  art: art,
                  title: context.l10n.availableSeatsSection,
                  thumbnailWidth: cabinCrossSize,
                  // The count is the driver's only control here, so it travels
                  // into the expanded view with the cabin.
                  expandedBottomBarBuilder: (context, refresh) =>
                      Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        const Expanded(child: _SeatLegend()),
                        const SizedBox(width: _columnGap),
                        SizedBox(
                          width: _stepperWidth,
                          child: _buildStepper(maxSeats, refresh),
                        ),
                      ],
                    ),
                  ),
                  seatBuilder: (context, seatNumber, _) => _PublishedSeatMarker(
                    isPublished: seatNumber <= _clampInt(_count, 1, maxSeats),
                  ),
                )
              else
                _CarCabin(cabinRows: cabinRows, width: cabinCrossSize),
              const SizedBox(width: _columnGap),
              const Expanded(child: _SeatLegend()),
              const SizedBox(width: _columnGap),
              SizedBox(
                width: _stepperWidth,
                child: _buildStepper(maxSeats, null),
              ),
            ],
          ),
        );
      },
    );
  }

  /// [refresh] redraws the expanded picker when the change came from inside it,
  /// which the screen behind it cannot do for a route it does not own.
  Widget _buildStepper(int maxSeats, VoidCallback? refresh) {
    final value = _clampInt(_count, 1, maxSeats);
    void apply(int next) {
      _setCount(next);
      refresh?.call();
    }

    return _SeatCountStepper(
      value: value,
      onDecrease: value > 1 ? () => apply(value - 1) : null,
      onIncrease: value < maxSeats ? () => apply(value + 1) : null,
    );
  }
}

/// A seat on the cabin artwork, filled when the driver is publishing it and
/// left as a faint outline when they are not.
class _PublishedSeatMarker extends StatelessWidget {
  const _PublishedSeatMarker({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    // A badge centred on the seat rather than a block covering it, so the
    // driver still sees which seat of their own car each marker belongs to.
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.58;
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: isPublished
                  ? T.primary(context)
                  : T.surface(context).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(side * 0.28),
              border: Border.all(
                color: isPublished
                    ? T.primary(context)
                    : T.outlineVariant(context).withValues(alpha: 0.9),
                width: isPublished ? 1.5 : 1,
              ),
            ),
            child: isPublished
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        IconsaxPlusBold.tick_circle,
                        size: 14,
                        color: T.onPrimary(context),
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

int _clampInt(int value, int min, int max) {
  if (max < min) return max;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

double _clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// `+` / `-` control clamped to `1..maxSeats` by the parent.
class _SeatCountStepper extends StatelessWidget {
  const _SeatCountStepper({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.availableSeatsCountTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              color: T.onSurfaceVariant(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // `+` leads and `-` trails, matching the mockup under the LTR
              // direction this subtree is pinned to.
              _StepperButton(
                icon: IconsaxPlusLinear.add,
                onTap: onIncrease,
                filled: true,
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: T.primary(context),
                  ),
                ),
              ),
              _StepperButton(
                icon: IconsaxPlusLinear.minus,
                onTap: onDecrease,
                filled: false,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.seatsUnitLabel,
            style: AppTextStyles.bodySmall.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mockup gives `+` a filled brand square and `-` a muted circle, so the
/// growing action reads as the primary one.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    final Color background;
    final Color foreground;
    if (filled) {
      background = enabled
          ? T.primary(context)
          : T.primary(context).withValues(alpha: 0.3);
      foreground = T.onPrimary(context);
    } else {
      background = T.surfaceVariant(context);
      foreground = enabled ? T.onSurface(context) : T.textDisabled(context);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(filled ? 10 : 16),
          ),
          child: Icon(icon, size: 18, color: foreground),
        ),
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendRow(
          color: T.primary(context),
          borderColor: T.primary(context),
          label: l10n.seatLegendAvailable,
        ),
        const SizedBox(height: 10),
        _LegendRow(
          color: T.onSurfaceVariant(context),
          borderColor: T.onSurfaceVariant(context),
          label: l10n.seatLegendDriver,
        ),
        const SizedBox(height: 10),
        _LegendRow(
          color: T.surface(context),
          borderColor: T.outlineVariant(context),
          label: l10n.seatLegendInactive,
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsetsDirectional.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 11,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Top-down cabin: one visual row per entry of [cabinRows], plus a UI-only
/// driver placeholder in the first row. Rows past the selected seat count are
/// not drawn at all, so the shell grows/shrinks with the stepper.
class _CarCabin extends StatelessWidget {
  const _CarCabin({required this.cabinRows, required this.width});

  final List<ProgressiveCabinRow> cabinRows;
  final double width;

  static const double _bodyInset = 9;

  @override
  Widget build(BuildContext context) {
    var maxSlots = 1;
    for (final row in cabinRows) {
      final slots = row.passengerSeats.length + (row.showDriver ? 1 : 0);
      maxSlots = math.max(maxSlots, slots);
    }

    final shellWidth = width - (_bodyInset * 2);
    final gap = _clampDouble(shellWidth * 0.05, 4, 9);
    // Keep tiles inside the painted flanks, not just inside the widget box.
    final sideInset = _bodyInset + (shellWidth * 0.15);
    final usableWidth = width - (sideInset * 2);
    final seatSize = _clampDouble(
      (usableWidth - (gap * (maxSlots - 1))) / maxSlots,
      18,
      44,
    );

    final rows = <Widget>[];
    for (var i = 0; i < cabinRows.length; i++) {
      final cabinRow = cabinRows[i];
      final slots = <Widget>[];
      if (cabinRow.showDriver) {
        slots.add(_DriverPlaceholder(size: seatSize));
      }
      for (final seat in cabinRow.passengerSeats) {
        slots.add(_SeatTile(size: seatSize, isAvailable: seat.isAvailable));
      }
      if (i > 0) {
        rows.add(SizedBox(height: gap * 1.6));
      }
      rows.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sideInset),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: slots,
          ),
        ),
      );
    }

    // Long hood and boot so the silhouette reads as a car, not a rounded box.
    final padTop = seatSize * 1.45;
    final padBottom = seatSize * 1.05;

    return SizedBox(
      width: width,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: CustomPaint(
          painter: _CarBodyPainter(padTop: padTop, padBottom: padBottom),
          child: Padding(
            padding: EdgeInsets.only(top: padTop, bottom: padBottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        ),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.size, required this.isAvailable});

  final double size;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      label: isAvailable ? l10n.seatLegendAvailable : l10n.seatLegendInactive,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isAvailable ? T.primary(context) : T.surface(context),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(
            color: isAvailable
                ? T.primary(context)
                : T.outlineVariant(context),
            width: 1.4,
          ),
        ),
        child: isAvailable
            ? Icon(
                IconsaxPlusBold.tick_circle,
                size: size * 0.5,
                color: T.onPrimary(context),
              )
            : null,
      ),
    );
  }
}

/// Driver seat is never bookable and never counted — purely a visual anchor.
class _DriverPlaceholder extends StatelessWidget {
  const _DriverPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.seatLegendDriver,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: T.onSurfaceVariant(context),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: T.onSurfaceVariant(context), width: 1.4),
        ),
        child: Icon(
          IconsaxPlusBold.driving,
          size: size * 0.5,
          color: T.surface(context),
        ),
      ),
    );
  }
}

/// Realistic white top-down car shell (nose pointing to the top of the widget).
///
/// Painted to match the product mockup instead of a flat schematic: a white
/// body with lateral shading and a soft drop shadow, dark windscreen and rear
/// glass, a charcoal cabin panel the seat tiles sit on, body-coloured wing
/// mirrors and faint hood/trunk creases. Still fully painted (no image asset)
/// so it resizes with the seat count.
class _CarBodyPainter extends CustomPainter {
  const _CarBodyPainter({required this.padTop, required this.padBottom});

  /// Distance from the top of the canvas to the cabin (roof) panel.
  final double padTop;

  /// Distance from the bottom of the cabin panel to the canvas bottom.
  final double padBottom;

  static const Color _edge = Color(0xFFE1E4E9);
  static const Color _bodyLine = Color(0xFFC7CCD4);
  static const Color _crease = Color(0xFFD9DDE3);
  static const Color _glass = Color(0xFF3E454F);
  static const Color _glassLine = Color(0xFF2E343D);
  static const Color _cabinTop = Color(0xFF575E69);
  static const Color _cabinBottom = Color(0xFF434A54);
  static const Color _mirrorBody = Color(0xFFF5F6F8);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _CarCabin._bodyInset,
      0,
      size.width - (_CarCabin._bodyInset * 2),
      size.height,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final body = _bodyPath(rect);

    // Soft drop shadow under the shell.
    canvas.drawPath(
      body.shift(const Offset(0, 2.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // White body with darker flanks so the roofline reads as curved.
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            _edge,
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            _edge,
          ],
          stops: const [0, 0.22, 0.78, 1],
        ).createShader(rect),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _bodyLine,
    );

    _paintCreases(canvas, rect);
    _paintWindshield(canvas, rect);
    _paintCabin(canvas, rect);
    _paintRearGlass(canvas, rect);
    _paintMirrors(canvas, rect);
  }

  /// Symmetric silhouette: rounded nose, widest at the doors, tapered tail.
  Path _bodyPath(Rect rect) {
    final w = rect.width;
    final h = rect.height;
    final cx = rect.center.dx;

    return Path()
      ..moveTo(cx, rect.top)
      ..cubicTo(
        cx + w * 0.18,
        rect.top,
        cx + w * 0.34,
        rect.top + h * 0.05,
        rect.right - w * 0.06,
        rect.top + h * 0.14,
      )
      ..cubicTo(
        rect.right - w * 0.005,
        rect.top + h * 0.22,
        rect.right - w * 0.005,
        rect.top + h * 0.5,
        rect.right - w * 0.045,
        rect.bottom - h * 0.08,
      )
      ..cubicTo(
        rect.right - w * 0.10,
        rect.bottom - h * 0.015,
        cx + w * 0.16,
        rect.bottom,
        cx,
        rect.bottom,
      )
      ..cubicTo(
        cx - w * 0.16,
        rect.bottom,
        rect.left + w * 0.10,
        rect.bottom - h * 0.015,
        rect.left + w * 0.045,
        rect.bottom - h * 0.08,
      )
      ..cubicTo(
        rect.left + w * 0.005,
        rect.top + h * 0.5,
        rect.left + w * 0.005,
        rect.top + h * 0.22,
        rect.left + w * 0.06,
        rect.top + h * 0.14,
      )
      ..cubicTo(
        cx - w * 0.34,
        rect.top + h * 0.05,
        cx - w * 0.18,
        rect.top,
        cx,
        rect.top,
      )
      ..close();
  }

  void _paintCreases(Canvas canvas, Rect rect) {
    final cx = rect.center.dx;
    final w = rect.width;
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _crease;

    // Hood crease between the fenders.
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + w * 0.17, padTop * 0.22)
        ..quadraticBezierTo(cx, padTop * 0.06, rect.right - w * 0.17, padTop * 0.22),
      detail,
    );

    // Trunk crease.
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + w * 0.15, rect.bottom - padBottom * 0.28)
        ..quadraticBezierTo(
          cx,
          rect.bottom - padBottom * 0.08,
          rect.right - w * 0.15,
          rect.bottom - padBottom * 0.28,
        ),
      detail,
    );
  }

  void _paintWindshield(Canvas canvas, Rect rect) {
    if (padTop <= 6) return;
    final w = rect.width;
    final cx = rect.center.dx;
    final top = padTop * 0.66;
    final bottom = padTop - 1.5;
    if (bottom <= top) return;

    final path = Path()
      ..moveTo(rect.left + w * 0.24, top)
      ..quadraticBezierTo(cx, top - 2, rect.right - w * 0.24, top)
      ..lineTo(rect.right - w * 0.115, bottom)
      ..quadraticBezierTo(cx, bottom + 2.5, rect.left + w * 0.115, bottom)
      ..close();

    canvas.drawPath(path, Paint()..color = _glass);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _glassLine,
    );
  }

  void _paintCabin(Canvas canvas, Rect rect) {
    final bottom = rect.height - padBottom;
    if (bottom <= padTop) return;

    final inset = rect.width * 0.145;
    final cabinRect = Rect.fromLTRB(
      rect.left + inset,
      padTop - 1,
      rect.right - inset,
      bottom + 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cabinRect,
        Radius.circular(rect.width * 0.09),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cabinTop, _cabinBottom],
        ).createShader(cabinRect),
    );
  }

  void _paintRearGlass(Canvas canvas, Rect rect) {
    if (padBottom <= 6) return;
    final w = rect.width;
    final cx = rect.center.dx;
    final top = rect.height - padBottom + 1.5;
    final bottom = rect.bottom - padBottom * 0.60;
    if (bottom <= top) return;

    final path = Path()
      ..moveTo(rect.left + w * 0.115, top)
      ..quadraticBezierTo(cx, top - 2.5, rect.right - w * 0.115, top)
      ..lineTo(rect.right - w * 0.22, bottom)
      ..quadraticBezierTo(cx, bottom + 2, rect.left + w * 0.22, bottom)
      ..close();

    canvas.drawPath(path, Paint()..color = _glass);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _glassLine,
    );
  }

  void _paintMirrors(Canvas canvas, Rect rect) {
    final mirrorH = (rect.width * 0.085).clamp(5.0, 10.0);
    final mirrorW = _CarCabin._bodyInset * 0.85;
    final top = padTop - (mirrorH * 0.7);
    final fill = Paint()..color = _mirrorBody;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _bodyLine;
    final glass = Paint()..color = _glass;

    for (final left in <double>[
      rect.left - mirrorW + 2.5,
      rect.right - 2.5,
    ]) {
      final r = Rect.fromLTWH(left, top, mirrorW, mirrorH);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, stroke);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: r.center,
            width: mirrorW * 0.45,
            height: mirrorH * 0.5,
          ),
          const Radius.circular(2),
        ),
        glass,
      );
    }
  }

  @override
  bool shouldRepaint(_CarBodyPainter oldDelegate) =>
      oldDelegate.padTop != padTop || oldDelegate.padBottom != padBottom;
}
