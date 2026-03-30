import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../models/booking_model.dart';
import '../../core/constants/route_names.dart';

class PassengerDetailsScreen extends StatelessWidget {
  final BookingModel booking;

  const PassengerDetailsScreen({super.key, required this.booking});

  Future<void> _launchCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty) return;
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = booking.userPopulated;
    final hasData = booking.hasDriverPaidToContact && user != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تفاصيل الراكب',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & Name
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (user?.gender == 'male'
                          ? AppColors.info.withValues(alpha: 0.1)
                          : Colors.pink.shade100),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconsaxPlusBold.profile,
                      size: 48,
                      color: user?.gender == 'male'
                          ? AppColors.infoDark
                          : Colors.pink.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasData ? user.name : 'راكب مجهول',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 20,
                      color: hasData
                          ? T.onSurface(context).withValues(alpha: 0.87)
                          : AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'مقعد ${booking.seatNumber}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (hasData) ...[
              _InfoCard(
                icon: IconsaxPlusLinear.call,
                label: 'رقم الهاتف',
                value: user.phoneNumber,
                onTap: user.phoneNumber.isNotEmpty
                    ? () => _launchCall(user.phoneNumber)
                    : null,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                icon: IconsaxPlusLinear.sms,
                label: 'البريد الإلكتروني',
                value: user.email,
                onTap: user.email.isNotEmpty
                    ? () => _launchEmail(user.email)
                    : null,
              ),
              const SizedBox(height: 16),
              _ChatButton(
                tripId: booking.tripId,
                passengerId: booking.userId,
                passengerName: user.name,
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      IconsaxPlusLinear.info_circle,
                      color: AppColors.warning,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'بيانات الراكب تظهر بعد تأكيد الحجز (رحلة مجانية أو خصم من المحفظة)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.warningDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatButton extends StatelessWidget {
  final String tripId;
  final String passengerId;
  final String passengerName;

  const _ChatButton({
    required this.tripId,
    required this.passengerId,
    required this.passengerName,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'محادثة خاصة مع $passengerName',
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          RouteNames.driverChat,
          arguments: {
            'tripId': tripId,
            'passengerId': passengerId,
            'passengerName': passengerName,
          },
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.teal50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.teal200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.teal100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconsaxPlusLinear.message,
                  color: AppColors.teal700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'محادثة خاصة',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: T.primary(context),
                      ),
                    ),
                    Text(
                      'مراسلة $passengerName',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.teal700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                IconsaxPlusLinear.arrow_left_2,
                color: AppColors.teal700,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTappable = onTap != null && value.isNotEmpty;

    return Semantics(
      button: isTappable,
      label: '$label: $value',
      child: InkWell(
        onTap: isTappable ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.teal50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.teal700, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.isNotEmpty ? value : '-',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: value.isNotEmpty
                            ? T.onSurface(context).withValues(alpha: 0.87)
                            : T.outlineVariant(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isTappable)
                Icon(
                  IconsaxPlusLinear.arrow_left_2,
                  color: AppColors.teal700,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
