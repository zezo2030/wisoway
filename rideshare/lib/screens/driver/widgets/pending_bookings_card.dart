import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/booking_model.dart';
import '../../../widgets/common/section_card.dart';

class PendingBookingsCard extends StatelessWidget {
  final List<BookingModel> bookings;
  final String? confirmingId;
  final Function(String)? onConfirm;

  const PendingBookingsCard({
    super.key,
    required this.bookings,
    this.confirmingId,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'حجوزات قيد التأكيد (${bookings.length})',
      icon: IconsaxPlusBold.clock,
      iconColor: AppColors.warning,
      children: [
        Text(
          'تأكيد الحجز يفتح بيانات الراكب (رحلة مجانية أو خصم من المحفظة مرة واحدة للرحلة)',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate400),
        ),
        const SizedBox(height: 16),
        ...bookings.map(
          (booking) => _PendingBookingItem(
            booking: booking,
            isConfirming: confirmingId == booking.id,
            onConfirm: () => onConfirm?.call(booking.id),
          ),
        ),
      ],
    );
  }
}

class _PendingBookingItem extends StatelessWidget {
  final BookingModel booking;
  final bool isConfirming;
  final VoidCallback? onConfirm;

  const _PendingBookingItem({
    required this.booking,
    required this.isConfirming,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final seatText = booking.seatSummary.isNotEmpty ? booking.seatSummary : '-';
    final titleText = booking.userPopulated?.name?.isNotEmpty == true
        ? booking.userPopulated!.name
        : 'مقعد $seatText';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  IconsaxPlusLinear.profile_2user,
                  color: AppColors.slate500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'المقاعد: $seatText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'قيد التأكيد',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.warningDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'بانتظار التأكيد',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate500),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isConfirming ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: isConfirming
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(IconsaxPlusBold.tick_circle, size: 16),
            label: Text(
              isConfirming ? 'جاري التأكيد...' : 'تأكيد الحجز',
              style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
