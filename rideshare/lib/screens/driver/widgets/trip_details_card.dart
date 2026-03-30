import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/trip_model.dart';
import '../../../widgets/common/section_card.dart';

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
      title: 'تفاصيل الرحلة',
      icon: IconsaxPlusLinear.info_circle,
      iconColor: AppColors.teal600,
      children: [
        if (trip.distanceKm != null) ...[
          _DetailRow(
            icon: IconsaxPlusBold.routing_2,
            label: 'مسافة الرحلة',
            value: '${trip.distanceKm!.toStringAsFixed(1)} كم',
            color: AppColors.teal600,
          ),
          const Divider(height: 32),
        ],
        _DetailRow(
          icon: IconsaxPlusBold.clock,
          label: 'وقت الانطلاق',
          value:
              '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
          color: AppColors.warning,
        ),
        const Divider(height: 32),
        _DetailRow(
          icon: IconsaxPlusBold.dollar_circle,
          label: 'السعر لكل مقعد',
          value: '${trip.price} ${trip.currency}',
          color: AppColors.success,
        ),
        const Divider(height: 32),
        _DetailRow(
          icon: IconsaxPlusBold.profile_2user,
          label: 'المقاعد',
          value: '${trip.availableSeats} متاح / ${trip.totalSeats} إجمالي',
          color: AppColors.teal600,
        ),
        const Divider(height: 32),
        _DetailRow(
          icon: IconsaxPlusLinear.grid_1,
          label: 'تخطيط المقاعد',
          value:
              trip.seatLayout.seatsPerRowList != null &&
                  trip.seatLayout.seatsPerRowList!.isNotEmpty
              ? 'مخصص: ${trip.seatLayout.seatsPerRowList!.join('، ')}'
              : '${trip.seatLayout.rows} صف × ${trip.seatLayout.seatsPerRow} مقعد',
          color: AppColors.teal600,
        ),
        const Divider(height: 32),
        _DetailRow(
          icon: IconsaxPlusLinear.people,
          label: 'منع الاختلاط',
          value: trip.seatLayout.preventGenderMixing ? 'نعم' : 'لا',
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
