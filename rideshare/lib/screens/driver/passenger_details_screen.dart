import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
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
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (user?.gender == 'male'
                              ? Colors.blue.shade100
                              : Colors.pink.shade100),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconsaxPlusBold.profile,
                      size: 48,
                      color: user?.gender == 'male'
                          ? Colors.blue.shade700
                          : Colors.pink.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasData ? user.name : 'راكب مجهول',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: hasData ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'مقعد ${booking.seatNumber}',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(IconsaxPlusLinear.info_circle,
                        color: Colors.orange.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'بيانات الراكب تظهر بعد تأكيد الحجز (رحلة مجانية أو خصم من المحفظة)',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.orange.shade900,
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
    return InkWell(
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
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                IconsaxPlusLinear.message,
                color: Colors.teal.shade700,
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
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                    ),
                  ),
                  Text(
                    'مراسلة $passengerName',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_left_2,
              color: Colors.teal.shade700,
              size: 20,
            ),
          ],
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

    return InkWell(
      onTap: isTappable ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
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
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.teal.shade700, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isNotEmpty ? value : '-',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: value.isNotEmpty ? Colors.black87 : Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isTappable)
              Icon(
                IconsaxPlusLinear.arrow_left_2,
                color: Colors.teal.shade700,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
