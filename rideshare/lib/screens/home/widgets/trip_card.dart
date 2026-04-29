import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../models/trip_model.dart';

class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;

  const TripCard({super.key, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE، d MMMM', 'ar');
    final timeFormat = DateFormat('hh:mm a', 'ar');
    final isPast = trip.departureTime.isBefore(DateTime.now());

    Color statusColor;
    String statusText;

    if (trip.status == 'active') {
      statusColor = AppColors.success;
      statusText = 'نشطة';
    } else if (trip.status == 'hidden') {
      statusColor = AppColors.warning;
      statusText = 'مخفية';
    } else {
      statusColor = T.primary(context);
      statusText = 'مكتملة';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.teal50,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: T.primary(context).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppColors.teal200, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 4,
                              backgroundColor: statusColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        dateFormat.format(trip.departureTime),
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: T.onSurfaceVariant(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.from.name,
                              style: GoogleFonts.tajawal(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: T.onSurface(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  IconsaxPlusLinear.arrow_right_3,
                                  size: 16,
                                  color: T.primary(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trip.to.name,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: T.onSurfaceVariant(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 70,
                        width: 1,
                        color: T
                            .outlineVariant(context)
                            .withValues(alpha: 0.15),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${trip.price}',
                            style: GoogleFonts.tajawal(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: T.primary(context),
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            trip.currency,
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: T.onSurfaceVariant(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoPill(
                        icon: IconsaxPlusLinear.clock,
                        text: timeFormat.format(trip.departureTime),
                        color: T.primary(context),
                      ),
                      _InfoPill(
                        icon: IconsaxPlusLinear.profile_2user,
                        text: '${trip.availableSeats} متاح',
                        color: AppColors.warning,
                      ),
                      _InfoPill(
                        icon: IconsaxPlusLinear.money_tick,
                        text: trip.communicationFeeStatus == 'paid'
                            ? 'مدفوعة'
                            : 'مستحقة',
                        color: trip.communicationFeeStatus == 'paid'
                            ? AppColors.success
                            : T.error(context),
                      ),
                    ],
                  ),
                ),
                if (isPast)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: T.error(context).withValues(alpha: 0.05),
                      border: Border(
                        top: BorderSide(
                          color: T.error(context).withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'انتهى وقت الرحلة',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: T.error(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
