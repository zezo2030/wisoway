import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/phone_text.dart';
import '../../models/booking_model.dart';
import '../../core/constants/route_names.dart';

class PassengerDetailsScreen extends StatefulWidget {
  final BookingModel booking;

  const PassengerDetailsScreen({super.key, required this.booking});

  @override
  State<PassengerDetailsScreen> createState() => _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  late BookingModel _booking;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

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
    final user = _booking.userPopulated;
    // Communication-fee reveal: once the driver pays the trip unlock fee,
    // passenger details and chat are available even while the booking is pending.
    final hasData = _booking.hasDriverPaidToContact && user != null;

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
                color: T.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: T.outline(context)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (user?.gender == 'male'
                          ? T.info(context).withValues(alpha: 0.1)
                          : T.accentPink(context).withValues(alpha: 0.1)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconsaxPlusBold.profile,
                      size: 48,
                      color: user?.gender == 'male'
                          ? T.info(context)
                          : T.accentPink(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasData ? user.name : '***',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 20,
                      color: hasData
                          ? T.onSurface(context).withValues(alpha: 0.87)
                          : T.textSecondary(context),
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
                      'مقعد ${_booking.seatSummary.isNotEmpty ? _booking.seatSummary : '-'}',
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
                isPhone: true,
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
                tripId: _booking.tripId,
                passengerId: _booking.userId,
                passengerName: user.name,
              ),
            ],
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
            color: T.primaryContainer(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: T.primary(context).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconsaxPlusLinear.message,
                  color: T.primary(context),
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
                        color: T.onSurface(context),
                      ),
                    ),
                    Text(
                      'مراسلة $passengerName',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                IconsaxPlusLinear.arrow_left_2,
                color: T.primary(context),
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
  final bool isPhone;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.isPhone = false,
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
            border: Border.all(color: T.outline(context)),
            boxShadow: [
              BoxShadow(
                color: T.shadow(context).withValues(alpha: 0.05),
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
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: T.primary(context), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isPhone && value.isNotEmpty)
                      PhoneText(
                        value,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: T.onSurface(context).withValues(alpha: 0.87),
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else
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
                  color: T.primary(context),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
