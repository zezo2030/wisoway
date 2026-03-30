import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/booking_model.dart';
import '../../../widgets/common/section_card.dart';

class PassengersCard extends StatelessWidget {
  final List<BookingModel> bookings;
  final Function(String)? onTap;

  const PassengersCard({super.key, required this.bookings, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'الركاب (${bookings.length})',
      icon: IconsaxPlusBold.profile_2user,
      iconColor: AppColors.teal600,
      children: bookings
          .map((booking) => _PassengerItem(booking: booking, onTap: onTap))
          .toList(),
    );
  }
}

class _PassengerItem extends StatelessWidget {
  final BookingModel booking;
  final Function(String)? onTap;

  const _PassengerItem({required this.booking, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMale = booking.userPopulated?.gender == 'male';

    return InkWell(
      onTap: () => onTap?.call(booking.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMale
                    ? AppColors.teal50
                    : AppColors.accentPink.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusBold.profile,
                color: isMale ? AppColors.teal600 : AppColors.accentPink,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.hasDriverPaidToContact
                        ? (booking.userPopulated?.name ?? 'راكب')
                        : 'راكب مجهول',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: booking.hasDriverPaidToContact
                          ? AppColors.slate800
                          : AppColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        IconsaxPlusLinear.profile_2user,
                        size: 14,
                        color: AppColors.slate400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'مقعد ${booking.seatNumber}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.slate400,
                        ),
                      ),
                      if (booking.hasDriverPaidToContact &&
                          booking.sharePhoneWithDriver) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          IconsaxPlusLinear.call,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.userPopulated?.phoneNumber ?? '',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.slate400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.teal50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.successLight.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'مؤكد',
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
