import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/trip_model.dart';
import '../../../l10n/l10n_extensions.dart';

class StatisticsRow extends StatelessWidget {
  final TripModel trip;
  final int bookedSeats;
  final double totalRevenue;

  const StatisticsRow({
    super.key,
    required this.trip,
    required this.bookedSeats,
    required this.totalRevenue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: IconsaxPlusBold.profile_2user,
            label: context.l10n.bookedSeats,
            value: '$bookedSeats',
            subtitle: context.l10n.ofTotalSeats(trip.totalSeats),
            color: AppColors.teal600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: IconsaxPlusBold.dollar_circle,
            label: context.l10n.revenue,
            value: totalRevenue.toStringAsFixed(0),
            subtitle: trip.currency,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate400),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(color: color),
          ),
          Text(
            subtitle,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
