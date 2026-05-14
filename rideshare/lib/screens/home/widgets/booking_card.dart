import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../models/booking_model.dart';
import '../../../models/trip_model.dart';
import '../../../utils/booking_seat_formatter.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final TripModel? trip;
  final bool isPastTrip;
  final VoidCallback? onTap;
  /// Called when the user taps the Chat button (only shown once settled).
  final VoidCallback? onChat;
  /// Called when the user taps the Call button (only shown once settled).
  final VoidCallback? onCall;
  /// Called when the user taps the Cancel booking button.
  final VoidCallback? onCancel;

  const BookingCard({
    super.key,
    required this.booking,
    this.trip,
    this.isPastTrip = false,
    this.onTap,
    this.onChat,
    this.onCall,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    final timeFormat = DateFormat('HH:mm', 'ar');
    final cardColor = isPastTrip
        ? T.surfaceVariant(context)
        : T.surface(context);
    final muted = isPastTrip
        ? T.onSurfaceVariant(context)
        : T.onSurface(context);
    final seatSummary = BookingSeatFormatter.summary(booking, trip);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isPastTrip
            ? Border.all(color: T.outlineVariant(context))
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: isPastTrip ? 0.03 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPastTrip)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          IconsaxPlusBold.clock,
                          size: 14,
                          color: T.onSurfaceVariant(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'رحلة منتهية',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: T.onSurfaceVariant(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (trip != null) ...[
                            Row(
                              children: [
                                Icon(
                                  IconsaxPlusBold.location,
                                  size: 16,
                                  color: isPastTrip
                                      ? AppColors.successDark.withValues(
                                          alpha: 0.7,
                                        )
                                      : AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trip!.from.name,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: muted,
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
                                  size: 16,
                                  color: isPastTrip
                                      ? T.error(context).withValues(alpha: 0.7)
                                      : T.error(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trip!.to.name,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: muted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              'رحلة غير متاحة',
                              style: GoogleFonts.tajawal(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: booking.isPending
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : booking.isConfirmed
                            ? AppColors.success.withValues(alpha: 0.1)
                            : T.error(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        booking.isPending
                            ? 'قيد الانتظار'
                            : booking.isConfirmed
                            ? 'مؤكد'
                            : 'ملغي',
                        style: TextStyle(
                          color: booking.isPending
                              ? AppColors.warningDark
                              : booking.isConfirmed
                              ? AppColors.successDark
                              : T.error(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _BookingInfoItem(
                        icon: IconsaxPlusBold.calendar,
                        label: 'التاريخ',
                        value: trip != null
                            ? dateFormat.format(trip!.departureTime)
                            : '-',
                        mutedStyle: isPastTrip,
                      ),
                    ),
                    Expanded(
                      child: _BookingInfoItem(
                        icon: IconsaxPlusBold.clock,
                        label: 'الوقت',
                        value: trip != null
                            ? timeFormat.format(trip!.departureTime)
                            : '-',
                        mutedStyle: isPastTrip,
                      ),
                    ),
                    Expanded(
                      child: _BookingInfoItem(
                        icon: IconsaxPlusBold.profile_2user,
                        label: 'المقعد',
                        value: seatSummary.isNotEmpty ? seatSummary : '-',
                        mutedStyle: isPastTrip,
                      ),
                    ),
                  ],
                ),
                // Cancel booking action — visible for cancellable bookings.
                if (booking.canBeCancelled && !isPastTrip && onCancel != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(IconsaxPlusBold.close_circle, size: 16),
                      label: const Text('إلغاء الحجز'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                if (booking.hasDriverPaidToContact && !isPastTrip) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SettlementActionButton(
                          icon: IconsaxPlusBold.message,
                          label: 'دردشة',
                          color: T.primary(context),
                          onTap: onChat,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SettlementActionButton(
                          icon: IconsaxPlusBold.call,
                          label: 'اتصال',
                          color: AppColors.success,
                          onTap: onCall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mutedStyle;

  const _BookingInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.mutedStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = mutedStyle
        ? T.onSurfaceVariant(context)
        : T.primary(context);
    final valueColor = mutedStyle
        ? T.onSurfaceVariant(context)
        : T.onSurface(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.tajawal(
            fontSize: 11,
            color: T.onSurfaceVariant(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.tajawal(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Compact action button shown in the settlement action row of [BookingCard].
class _SettlementActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SettlementActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
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
