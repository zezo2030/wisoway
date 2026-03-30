import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/wallet_model.dart';

class WalletCard extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback? onTap;

  const WalletCard({super.key, required this.wallet, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warningLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warningLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                IconsaxPlusBold.wallet_3,
                color: AppColors.warningDark,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رصيد المحفظة: ${wallet.balance.toStringAsFixed(0)} ${wallet.currency}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    wallet.hasUsedLifetimeFreeTrip
                        ? 'تم استخدام الرحلة المجانية'
                        : 'رحلة مجانية متاحة',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              IconsaxPlusLinear.arrow_left_2,
              color: AppColors.warningDark,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
