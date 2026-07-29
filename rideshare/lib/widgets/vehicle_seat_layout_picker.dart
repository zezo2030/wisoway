import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';
import '../l10n/l10n_extensions.dart';
import '../models/seat_layout_config.dart';
import '../utils/seat_layout_helpers.dart';

/// Top-down cabin preview + stepper used when publishing a trip.
///
/// The layout *shape* is fixed by the driver's vehicle (or its type template);
/// only the number of published passenger seats can be changed here. The driver
/// placeholder drawn next to the first row is UI-only and is never counted.
class VehicleSeatLayoutPicker extends StatelessWidget {
  const VehicleSeatLayoutPicker({
    super.key,
    required this.layout,
    required this.availableSeatCount,
    required this.onAvailableSeatCountChanged,
  });

  final SeatLayoutConfig layout;
  final int availableSeatCount;
  final ValueChanged<int> onAvailableSeatCountChanged;

  static const double _stepperWidth = 116;
  static const double _columnGap = 10;

  @override
  Widget build(BuildContext context) {
    final rowCounts = SeatLayoutHelpers.rowSeatCounts(layout);
    final maxSeats = rowCounts.fold<int>(0, (sum, count) => sum + count);
    final selected = _clampInt(availableSeatCount, 1, maxSeats);

    if (maxSeats <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final free = math.max(
          0.0,
          constraints.maxWidth - _stepperWidth - (_columnGap * 2),
        );
        final cabinWidth = _clampDouble(free * 0.55, 96, 200);
        final cabinRows = SeatLayoutHelpers.progressiveCabinRows(
          rowCounts: rowCounts,
          availableSeatCount: selected,
        );

        // Visual order matches mockup: cabin → legend → stepper (RTL flips).
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CarCabin(cabinRows: cabinRows, width: cabinWidth),
            const SizedBox(width: _columnGap),
            const Expanded(child: _SeatLegend()),
            const SizedBox(width: _columnGap),
            SizedBox(
              width: _stepperWidth,
              child: _SeatCountStepper(
                value: selected,
                onDecrease: selected > 1
                    ? () => onAvailableSeatCountChanged(selected - 1)
                    : null,
                onIncrease: selected < maxSeats
                    ? () => onAvailableSeatCountChanged(selected + 1)
                    : null,
              ),
            ),
          ],
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
              _StepperButton(
                icon: IconsaxPlusLinear.minus,
                onTap: onDecrease,
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
              _StepperButton(icon: IconsaxPlusLinear.add, onTap: onIncrease),
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

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? T.surface(context) : T.surfaceVariant(context),
            shape: BoxShape.circle,
            border: Border.all(color: T.outlineVariant(context)),
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? T.onSurface(context) : T.textDisabled(context),
          ),
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

    final innerWidth = width - (_bodyInset * 2);
    final gap = _clampDouble(innerWidth * 0.05, 4, 9);
    final seatSize = _clampDouble(
      (innerWidth - (gap * (maxSlots + 1))) / maxSlots,
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
          padding: EdgeInsets.symmetric(horizontal: gap),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: slots,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: CustomPaint(
          painter: _CarBodyPainter(
            body: T.surfaceVariant(context),
            border: T.outlineVariant(context),
            glass: T.onSurfaceVariant(context).withValues(alpha: 0.18),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: seatSize * 0.85,
              bottom: seatSize * 0.7,
            ),
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

/// Stylised top-down car shell (nose pointing to the top of the widget).
class _CarBodyPainter extends CustomPainter {
  const _CarBodyPainter({
    required this.body,
    required this.border,
    required this.glass,
  });

  final Color body;
  final Color border;
  final Color glass;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _CarCabin._bodyInset,
      0,
      size.width - (_CarCabin._bodyInset * 2),
      size.height,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final shell = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(rect.width * 0.40),
      topRight: Radius.circular(rect.width * 0.40),
      bottomLeft: Radius.circular(rect.width * 0.26),
      bottomRight: Radius.circular(rect.width * 0.26),
    );

    // Wing mirrors first so the shell overlaps their inner edge.
    final mirrorTop = rect.top + (rect.height * 0.18);
    final mirrorHeight = math.min(14.0, rect.height * 0.12);
    final mirrorPaint = Paint()..color = border;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left - _CarCabin._bodyInset + 1,
          mirrorTop,
          _CarCabin._bodyInset + 2,
          mirrorHeight,
        ),
        const Radius.circular(4),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.right - 3,
          mirrorTop,
          _CarCabin._bodyInset + 2,
          mirrorHeight,
        ),
        const Radius.circular(4),
      ),
      mirrorPaint,
    );

    canvas.drawRRect(shell, Paint()..color = body);
    canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = border,
    );

    final glassPaint = Paint()..color = glass;
    canvas.drawPath(
      _window(rect, 0.14, 0.045, 0.095, true),
      glassPaint,
    );
    canvas.drawPath(
      _window(rect, 0.14, 0.045, 0.095, false),
      glassPaint,
    );
  }

  /// Lens-shaped windscreen band; [isFront] mirrors it to the rear of the shell.
  Path _window(
    Rect rect,
    double sideInsetRatio,
    double outerRatio,
    double innerRatio,
    bool isFront,
  ) {
    final sideInset = rect.width * sideInsetRatio;
    final left = rect.left + sideInset;
    final right = rect.right - sideInset;
    final baseline = isFront
        ? rect.top + (rect.height * 0.155)
        : rect.bottom - (rect.height * 0.155);
    final outer = isFront
        ? rect.top + (rect.height * outerRatio)
        : rect.bottom - (rect.height * outerRatio);
    final inner = isFront
        ? rect.top + (rect.height * innerRatio)
        : rect.bottom - (rect.height * innerRatio);

    return Path()
      ..moveTo(left, baseline)
      ..quadraticBezierTo(rect.center.dx, outer, right, baseline)
      ..quadraticBezierTo(rect.center.dx, inner, left, baseline)
      ..close();
  }

  @override
  bool shouldRepaint(_CarBodyPainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.border != border ||
      oldDelegate.glass != glass;
}
