import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/trip_model.dart';
import '../../../utils/seat_layout_helpers.dart';
import '../../../widgets/common/section_card.dart';
import '../../../l10n/l10n_extensions.dart';

class TripDetailsCard extends StatelessWidget {
  final TripModel trip;
  final DateFormat dateFormat;
  final DateFormat timeFormat;

  const TripDetailsCard({
    super.key,
    required this.trip,
    required this.dateFormat,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: context.l10n.tripDetails,
      icon: IconsaxPlusLinear.info_circle,
      iconColor: AppColors.teal600,
      children: [
        if (trip.distanceKm != null) ...[
          _DetailRow(
            icon: IconsaxPlusBold.routing_2,
            label: context.l10n.tripDistance,
            value: context.l10n.distanceInKm(
              trip.distanceKm!.toStringAsFixed(1),
            ),
            color: AppColors.teal600,
          ),
          const Divider(height: 32),
        ],
        _DetailRow(
          icon: IconsaxPlusBold.clock,
          label: context.l10n.departureTimeLabel,
          value:
              '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
          color: AppColors.warning,
        ),
        const Divider(height: 32),
        _DetailRow(
          icon: IconsaxPlusBold.dollar_circle,
          label: context.l10n.pricePerSeat,
          value: '${trip.price} ${trip.currency}',
          color: AppColors.success,
        ),
        const Divider(height: 32),
        _DetailRow(
          icon: IconsaxPlusBold.profile_2user,
          label: context.l10n.seatsLabel,
          value: context.l10n.availableOfTotalSeats(
            trip.availableSeats,
            trip.totalSeats,
          ),
          color: AppColors.teal600,
        ),
        const Divider(height: 32),
        _DetailRow(
          icon: IconsaxPlusLinear.grid_1,
          label: context.l10n.seatLayout,
          value: SeatLayoutHelpers.formatTripSeatLayoutPattern(
            trip.seatLayout,
            trip.seats,
            trip.totalSeats,
          ),
          color: AppColors.teal600,
        ),
        const Divider(height: 32),
        _DetailRow(
          icon: IconsaxPlusLinear.people,
          label: context.l10n.preventGenderMixing,
          value: trip.seatLayout.preventGenderMixing
              ? context.l10n.yes
              : context.l10n.no,
          color: trip.seatLayout.preventGenderMixing
              ? AppColors.error
              : AppColors.slate400,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 15,
              color: AppColors.slate500,
            ),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.slate800,
          ),
        ),
      ],
    );
  }
}
