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
    final showDeadlineBanner = trip.driverShowsStartDeadlinePassedBanner;

    Color statusColor;
    String statusText;

    if (trip.status == 'active' || trip.status == 'published') {
      statusColor = AppColors.success;
      statusText = 'نشطة';
    } else if (trip.status == 'fully_booked') {
      statusColor = AppColors.warning;
      statusText = 'مكتملة الحجز';
    } else if (trip.status == 'in_progress') {
      statusColor = T.primary(context);
      statusText = 'قيد التنفيذ';
    } else if (trip.status == 'hidden') {
      statusColor = AppColors.warning;
      statusText = 'مخفية';
    } else {
      statusColor = T.primary(context);
      statusText = trip.statusDisplayText;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: statusColor.withValues(alpha: 0.08),
            highlightColor: statusColor.withValues(alpha: 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: status + date
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: GoogleFonts.tajawal(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusLinear.clock,
                            color: T.onSurfaceVariant(context),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            dateFormat.format(trip.departureTime),
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w500,
                              color: T.onSurfaceVariant(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Route: vertical with timeline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline dots & line
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: T.primary(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 28,
                            color: T.primary(context).withValues(alpha: 0.25),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // From
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'من',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 11,
                                    color: T.onSurfaceVariant(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  trip.from.name,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: T.onSurface(context),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // To
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إلى',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 11,
                                    color: T.onSurfaceVariant(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  trip.to.name,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: T.onSurface(context),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Footer: price, seats, fee status
                Container(
                  decoration: BoxDecoration(
                    color: T.surfaceVariant(context).withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        IconsaxPlusLinear.clock,
                        color: T.primary(context),
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        timeFormat.format(trip.departureTime),
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: T.primary(context),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        IconsaxPlusLinear.profile_2user,
                        color: AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${trip.availableSeats} متاح',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        IconsaxPlusLinear.money_tick,
                        color: trip.communicationFeeStatus == 'paid'
                            ? AppColors.success
                            : T.error(context),
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        trip.communicationFeeStatus == 'paid'
                            ? 'مدفوعة'
                            : 'مستحقة',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: trip.communicationFeeStatus == 'paid'
                              ? AppColors.success
                              : T.error(context),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${trip.price} ${trip.currency}',
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: T.primary(context),
                        ),
                      ),
                    ],
                  ),
                ),

                if (showDeadlineBanner)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                        'انتهى وقت بدء الرحلة (لم يبدأ السائق ضمن المهلة)',
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
