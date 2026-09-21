import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';
import '../models/payment_model.dart';

/// Communication Fee Dialog
///
/// Dialog يعرض رسوم فتح التواصل ويسمح للمستخدم باختيار طريقة الدفع
class CommunicationFeeDialog extends StatefulWidget {
  final double amount;
  final String currency;
  final String countryCode; // للتحقق من الرسوم
  final Function(PaymentMethod) onPaymentMethodSelected;

  const CommunicationFeeDialog({
    super.key,
    required this.amount,
    required this.currency,
    required this.countryCode,
    required this.onPaymentMethodSelected,
  });

  @override
  State<CommunicationFeeDialog> createState() => _CommunicationFeeDialogState();
}

class _CommunicationFeeDialogState extends State<CommunicationFeeDialog> {
  PaymentMethod? _selectedMethod;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    IconsaxPlusBold.dollar_circle,
                    color: AppColors.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رسوم فتح التواصل',
                        style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'لإتاحة التواصل مع الراكب',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Fee Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.warning.withValues(alpha: 0.1),
                    AppColors.warning.withValues(alpha: 0.18),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.amount.toStringAsFixed(2),
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.warningDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.currency,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Methods
            Text(
              'اختر طريقة الدفع',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Paymob
            _buildPaymentMethodCard(
              icon: IconsaxPlusBold.card,
              title: 'بطاقة ائتمان (Paymob)',
              subtitle: 'دفع آمن عبر Paymob',
              method: PaymentMethod.paymob,
              color: AppColors.success,
            ),
            const SizedBox(height: 12),

            // Manual wallets (offline)
            _buildPaymentMethodCard(
              icon: IconsaxPlusBold.wallet,
              title: 'محفظة إلكترونية',
              subtitle: 'Zain Cash, Orange Money, Cliq, Vodafone Cash',
              method: PaymentMethod.manual,
              color: AppColors.info,
            ),
            const SizedBox(height: 12),

            // CliQ A2A (online)
            _buildPaymentMethodCard(
              icon: IconsaxPlusBold.wallet,
              title: 'CliQ A2A',
              subtitle: 'دفع مباشر عبر نظام CliQ',
              method: PaymentMethod.cliq_a2a,
              color: AppColors.warning,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'إلغاء',
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Semantics(
                    button: true,
                    label:
                        'تأكيد ودفع ${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                    child: ElevatedButton(
                      onPressed: _selectedMethod == null
                          ? null
                          : () {
                              widget.onPaymentMethodSelected(_selectedMethod!);
                              Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.warning,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'تأكيد ودفع',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required PaymentMethod method,
    required Color color,
  }) {
    final isSelected = _selectedMethod == method;

    return Semantics(
      button: true,
      label: title,
      selected: isSelected,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : AppColors.slate50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : AppColors.slate300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : T.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
