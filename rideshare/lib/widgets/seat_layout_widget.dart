import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../models/seat_data.dart';
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

  const SeatLayoutWidget({
    super.key,
    required this.trip,
    this.selectedSeat,
    this.selectedSeats = const [],
    this.userGender,
    this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Driver seat indicator
        Container(
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
        ),
        const SizedBox(height: 16),
        // Seat layout grid
        Builder(
          builder: (context) {
            final List<int> rowConfigs =
                SeatLayoutHelpers.effectiveRowSeatCountsForTrip(
              trip.seatLayout,
              trip.seats,
              trip.totalSeats,
            );

            var currentSeatCount = 0;

            return Column(
              children: rowConfigs.asMap().entries.map((entry) {
                final seatsInThisRow = entry.value;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(seatsInThisRow, (colIndex) {
                      currentSeatCount++;
                      final seatNumber = currentSeatCount;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _SeatWidget(
                          seatNumber: seatNumber,
                          seatData:
                              (seatNumber >= 1 &&
                                  seatNumber <= trip.seats.length)
                              ? trip.seats[seatNumber - 1]
                              : null,
                          isSelected:
                              selectedSeat == seatNumber ||
                              selectedSeats.contains(seatNumber),
                          status: userGender != null
                              ? SeatValidation.getSeatStatus(
                                  trip: trip,
                                  seatNumber: seatNumber,
                                  userGender: userGender,
                                )
                              : SeatStatus.available,
                          onTap: onSeatTap != null
                              ? () => onSeatTap!(seatNumber)
                              : null,
                        ),
                      );
                    }),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        // Legend
        _SeatLegend(),
      ],
    );
  }
}

class _SeatWidget extends StatelessWidget {
  final int seatNumber;
  final SeatData? seatData;
  final bool isSelected;
  final SeatStatus status;
  final VoidCallback? onTap;

  const _SeatWidget({
    required this.seatNumber,
    this.seatData,
    required this.isSelected,
    required this.status,
    this.onTap,
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
        onTap: onTap != null && status == SeatStatus.available ? onTap : null,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: T.success(context), width: 2)
                : Border.all(color: T.outlineVariant(context), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, size: 16, color: textColor)
              else
                const SizedBox(height: 4),
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
