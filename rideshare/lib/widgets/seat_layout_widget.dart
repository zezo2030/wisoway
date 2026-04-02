import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../models/seat_data.dart';
import '../utils/seat_validation.dart';
import '../core/theme/colors.dart';

class SeatLayoutWidget extends StatelessWidget {
  final TripModel trip;
  final int? selectedSeat;
  final String? userGender;
  final Function(int)? onSeatTap;

  const SeatLayoutWidget({
    super.key,
    required this.trip,
    this.selectedSeat,
    this.userGender,
    this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final seatLayout = trip.seatLayout;

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
                'مقعد السائق',
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
                seatLayout.seatsPerRowList ??
                List.generate(seatLayout.rows, (_) => seatLayout.seatsPerRow);

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
                          isSelected: selectedSeat == seatNumber,
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
      SeatStatus.available => 'متاح',
      SeatStatus.booked => 'محجوز',
      SeatStatus.locked => 'مقفل',
      SeatStatus.unavailable => 'غير متاح',
      SeatStatus.invalid => 'غير صالح',
    };

    return Semantics(
      button: onTap != null && status == SeatStatus.available,
      label: 'مقعد $seatNumber $seatStatusLabel${isSelected ? '، محدد' : ''}',
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
          _LegendItem(color: T.surfaceVariant(context), label: 'متاح'),
          _LegendItem(color: T.success(context), label: 'محدد'),
          _LegendItem(
            color: T.error(context).withValues(alpha: 0.6),
            label: 'محجوز',
          ),
          _LegendItem(
            color: T.secondary(context).withValues(alpha: 0.2),
            label: 'مقفل (خارج التطبيق)',
          ),
          _LegendItem(
            color: T.outlineVariant(context).withValues(alpha: 0.3),
            label: 'غير متاح',
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
      label: 'دليل الألوان: $label',
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
