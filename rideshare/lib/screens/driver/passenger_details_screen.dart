import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../models/booking_model.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/booking_service.dart';

class PassengerDetailsScreen extends StatefulWidget {
  final BookingModel booking;

  const PassengerDetailsScreen({super.key, required this.booking});

  @override
  State<PassengerDetailsScreen> createState() => _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState extends State<PassengerDetailsScreen> {
  final _bookingService = BookingService();
  late BookingModel _booking;
  bool _markingPaid = false;

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

  Future<void> _onMarkPaid() async {
    setState(() => _markingPaid = true);
    try {
      final updated = await _bookingService.markPaid(_booking.id);
      if (mounted) {
        setState(() => _booking = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد استلام المبلغ بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _booking.userPopulated;
    // Post-settlement reveal: show full passenger details once booking is settled
    final hasData = _booking.isSettled && user != null;

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
                      'مقعد ${_booking.seatNumber ?? '-'}',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Mark-paid CTA (only when booking is confirmed and not yet settled) ──
            if (_booking.status == 'confirmed' && !_booking.isSettled) ...[
              _MarkPaidButton(
                loading: _markingPaid,
                onPressed: _onMarkPaid,
              ),
              const SizedBox(height: 16),
              // Hint about PII reveal
              Container(
                padding: const EdgeInsets.all(16),
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
                        'بيانات الراكب والمحادثة تظهر فقط بعد تأكيد استلام المبلغ',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.warningDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

class _MarkPaidButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _MarkPaidButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(IconsaxPlusBold.wallet_check),
        label: Text(
          loading ? 'جاري التأكيد...' : 'تأكيد استلام المبلغ',
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
