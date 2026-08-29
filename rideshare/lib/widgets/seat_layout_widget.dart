import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../models/seat_data.dart';
import '../models/vehicle_art.dart';
import 'expandable_cabin_view.dart';
import '../utils/seat_layout_helpers.dart';
import '../utils/seat_validation.dart';
import '../core/theme/colors.dart';
import '../l10n/l10n_extensions.dart';

class SeatLayoutWidget extends StatelessWidget {
  final TripModel trip;
  final int? selectedSeat;
  final List<int> selectedSeats;
  final String? userGender;
  final Function(int)? onSeatTap;

  /// Family bookings are exempt from the trip's gender-mixing rules, so seats
  /// are not greyed out for gender adjacency while this is on.
  final bool isFamilyBooking;

  const SeatLayoutWidget({
    super.key,
    required this.trip,
    this.selectedSeat,
    this.selectedSeats = const [],
    this.userGender,
    this.onSeatTap,
    this.isFamilyBooking = false,
  });

  @override
  Widget build(BuildContext context) {
    final art = vehicleArtFor(trip.vehicleType);
    // Artwork with fewer slots than the trip sells cannot show every seat, so
    // an unexpected layout falls back to the grid rather than hiding a seat.
    final useArt = art != null && art.seatCount >= trip.totalSeats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!useArt) ...[
          _DriverSeatBadge(),
          const SizedBox(height: 16),
        ],
        if (useArt)
          // Small in the page, full-screen to choose from: a bus at card size
          // is a thumbnail, not something a passenger can pick a seat on.
          ExpandableCabinView(
            art: art,
            title: context.l10n.seatLayoutLabel,
            expandedBottomBarBuilder: (context, _) => _SeatLegend(),
            seatBuilder: (context, seatNumber, refresh) =>
                seatNumber > trip.totalSeats
                    ? const _UnofferedSeat()
                    : _seatFor(context, seatNumber,
                        markerOnly: true, afterTap: refresh),
          )
        else
          _buildGrid(context),
        const SizedBox(height: 16),
        // Legend
        _SeatLegend(),
      ],
    );
  }

  /// One seat chip carrying the status this screen computed for it.
  ///
  /// [afterTap] lets the expanded picker redraw itself once the screen behind
  /// it has updated its selection — it owns a route this widget cannot rebuild.
  Widget _seatFor(BuildContext context, int seatNumber,
          {bool markerOnly = false, VoidCallback? afterTap}) =>
      _SeatWidget(
        markerOnly: markerOnly,
        seatNumber: seatNumber,
        seatData: (seatNumber >= 1 && seatNumber <= trip.seats.length)
            ? trip.seats[seatNumber - 1]
            : null,
        isSelected: selectedSeat == seatNumber ||
            selectedSeats.contains(seatNumber),
        status: userGender != null
            ? SeatValidation.getSeatStatus(
                trip: trip,
                seatNumber: seatNumber,
                userGender: userGender!,
                isFamilyBooking: isFamilyBooking,
              )
            : SeatStatus.available,
        onTap: onSeatTap != null
            ? () {
                onSeatTap!(seatNumber);
                afterTap?.call();
              }
            : null,
      );

  /// Plain row-and-column fallback for vehicle types that have no artwork.
  Widget _buildGrid(BuildContext context) {
    final List<int> rowConfigs = SeatLayoutHelpers.effectiveRowSeatCountsForTrip(
      trip.seatLayout,
      trip.seats,
      trip.totalSeats,
    );

    var currentSeatCount = 0;

    return Column(
      children: rowConfigs.map((seatsInThisRow) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(seatsInThisRow, (_) {
              currentSeatCount++;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: _seatFor(context, currentSeatCount),
                ),
              );
            }),
          ),
        );
      }).toList(),
    );
  }
}

/// Reminder of which seat the driver occupies, for the grid fallback only —
/// the artwork already draws it.
class _DriverSeatBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: T.primary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.drive_eta, size: 16, color: T.primary(context)),
          const SizedBox(width: 8),
          Text(
            context.l10n.seatDriverSeat,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: T.primary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A seat the vehicle has but the driver did not put up for sale. Drawn as a
/// hollow badge so the seat in the artwork still reads as a seat.
class _UnofferedSeat extends StatelessWidget {
  const _UnofferedSeat();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.58;
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: T.surface(context).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(side * 0.28),
              border: Border.all(
                color: T.outlineVariant(context).withValues(alpha: 0.9),
              ),
            ),
          ),
        );
      },
    );
  }
}
class _SeatWidget extends StatelessWidget {
  final int seatNumber;
  final SeatData? seatData;
  final bool isSelected;
  final SeatStatus status;
  final VoidCallback? onTap;

  /// Draw a small badge centred on the seat instead of filling the whole slot,
  /// so the seat in the vehicle artwork stays visible underneath. The tap
  /// target is unaffected — it stays the full slot, which matters on a 22-seat
  /// bus where a badge-sized target would be too small to hit.
  final bool markerOnly;

  const _SeatWidget({
    required this.seatNumber,
    this.seatData,
    required this.isSelected,
    required this.status,
    this.onTap,
    this.markerOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData? icon;

    if (isSelected) {
      backgroundColor = T.success(context);
      textColor = T.onPrimary(context);
      icon = Icons.check;
    } else {
      switch (status) {
        case SeatStatus.available:
          backgroundColor = T.surfaceVariant(context);
          textColor = T.onSurface(context);
          break;
        case SeatStatus.booked:
          backgroundColor = T.error(context).withValues(alpha: 0.6);
          textColor = T.onError(context);
          icon = Icons.person;
          break;
        case SeatStatus.locked:
          backgroundColor = T.secondary(context).withValues(alpha: 0.2);
          textColor = T.secondary(context);
          icon = Icons.lock_outline;
          break;
        case SeatStatus.unavailable:
          backgroundColor = T.outlineVariant(context).withValues(alpha: 0.3);
          textColor = T.textDisabled(context);
          icon = Icons.block;
          break;
        case SeatStatus.invalid:
          backgroundColor = T.surfaceVariant(context);
          textColor = T.textDisabled(context);
          break;
      }
    }

    final seatStatusLabel = switch (status) {
      SeatStatus.available => context.l10n.seatStatusAvailable,
      SeatStatus.booked => context.l10n.seatStatusBooked,
      SeatStatus.locked => context.l10n.seatStatusLocked,
      SeatStatus.unavailable => context.l10n.seatStatusUnavailable,
      SeatStatus.invalid => context.l10n.seatStatusInvalid,
    };

    return Semantics(
      button: onTap != null && status == SeatStatus.available,
      label: isSelected
          ? context.l10n.seatLabelSelected(seatNumber, seatStatusLabel)
          : context.l10n.seatLabelNumbered(seatNumber, seatStatusLabel),
      child: GestureDetector(
        // Opaque so the whole slot answers a tap, not just the painted badge.
        behavior: HitTestBehavior.opaque,
        onTap: onTap != null && status == SeatStatus.available ? onTap : null,
        child: markerOnly
            ? _buildMarker(context, backgroundColor, textColor, icon)
            : _buildFilled(context, backgroundColor, textColor, icon),
      ),
    );
  }

  /// Grid fallback: the chip fills its 50x50 cell.
  Widget _buildFilled(
    BuildContext context,
    Color background,
    Color textColor,
    IconData? icon,
  ) {
    return Container(
      decoration: _decoration(context, background, radius: 8),
      child: _label(textColor, icon),
    );
  }

  /// Over the artwork: a square badge centred on the seat, scaled to the seat
  /// so a small bus seat gets a small badge.
  Widget _buildMarker(
    BuildContext context,
    Color background,
    Color textColor,
    IconData? icon,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.58;
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: _decoration(context, background, radius: side * 0.28),
            child: _label(textColor, icon),
          ),
        );
      },
    );
  }

  BoxDecoration _decoration(
    BuildContext context,
    Color background, {
    required double radius,
  }) {
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      border: isSelected
          ? Border.all(color: T.success(context), width: 2)
          : Border.all(color: T.outlineVariant(context), width: 1),
    );
  }

  Widget _label(Color textColor, IconData? icon) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, size: 16, color: textColor),
            Text(
              '$seatNumber',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _LegendItem(
            color: T.surfaceVariant(context),
            label: context.l10n.seatStatusAvailable,
          ),
          _LegendItem(
            color: T.success(context),
            label: context.l10n.seatLegendSelected,
          ),
          _LegendItem(
            color: T.error(context).withValues(alpha: 0.6),
            label: context.l10n.seatStatusBooked,
          ),
          _LegendItem(
            color: T.secondary(context).withValues(alpha: 0.2),
            label: context.l10n.seatLegendLockedExternal,
          ),
          _LegendItem(
            color: T.outlineVariant(context).withValues(alpha: 0.3),
            label: context.l10n.seatStatusUnavailable,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.seatColorGuide(label),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: T.outlineVariant(context)),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: T.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}
