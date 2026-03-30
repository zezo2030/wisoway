import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../models/trip_model.dart';

class NearbyTripCard extends StatelessWidget {
  final TripModel trip;
  final double distance;
  final VoidCallback onTap;

  const NearbyTripCard({
    super.key,
    required this.trip,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusBold.location,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trip.from.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusBold.location,
                            size: 14,
                            color: T.error(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trip.to.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusBold.clock,
                            size: 12,
                            color: T.onSurfaceVariant(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${dateFormat.format(trip.departureTime)} ${timeFormat.format(trip.departureTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: T.onSurfaceVariant(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            IconsaxPlusBold.dollar_circle,
                            size: 12,
                            color: T.onSurfaceVariant(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${trip.price} ${trip.currency}',
                            style: TextStyle(
                              fontSize: 12,
                              color: T.onSurfaceVariant(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: T.primary(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            IconsaxPlusBold.location,
                            size: 12,
                            color: T.primary(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} كم',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: T.primary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: trip.hasAvailableSeats
                            ? AppColors.success.withValues(alpha: 0.1)
                            : T.error(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${trip.availableSeats}/${trip.totalSeats}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: trip.hasAvailableSeats
                              ? AppColors.successDark
                              : T.error(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
