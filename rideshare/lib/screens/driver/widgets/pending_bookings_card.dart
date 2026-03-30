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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          const Icon(
            IconsaxPlusLinear.profile_2user,
            color: AppColors.slate400,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مقعد ${booking.seatNumber}',
                  style: AppTextStyles.labelLarge,
                ),
                Text(
                  'بانتظار التأكيد',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isConfirming ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isConfirming
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    'تأكيد الحجز',
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }
}
