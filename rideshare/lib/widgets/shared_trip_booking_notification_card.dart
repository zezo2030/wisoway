import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../models/notification_model.dart';

/// Rich booking-created notification matching the VisionWay shared-trip design.
class SharedTripBookingNotificationCard extends StatelessWidget {
  const SharedTripBookingNotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  static const Color _bg = Color(0xFF1C1C1E);
  static const Color _purple = Color(0xFF7C6AF5);
  static const Color _label = Color(0xFFA1A1A1);
  static const Color _divider = Color(0xFF3A3A3C);

  @override
  Widget build(BuildContext context) {
    final data = notification.data ?? const <String, dynamic>{};
    final route = _text(data, [
      'route',
      'routeLabel',
    ], fallback: _buildRoute(data));
    final departure = _text(data, [
      'departureLabel',
      'departureTime',
    ], fallback: '—');
    final distance = _text(data, [
      'distanceLabel',
      'distanceKm',
    ], fallback: '—');
    final meetingPoint = _text(data, [
      'meetingPoint',
      'fromAddress',
      'fromName',
    ], fallback: '—');
    final seats = _text(data, [
      'seatsLabel',
      'availableSeats',
    ], fallback: '—');
    final title = notification.displayTitle.isNotEmpty
        ? notification.displayTitle
        : 'تم حجز مقعد في رحلتك المشتركة';
    final footerTitle = _text(
      data,
      ['footerTitle'],
      fallback: 'انضم راكب جديد إلى رحلتك المشتركة',
    );
    final footerSubtitle = _text(
      data,
      ['footerSubtitle'],
      fallback: 'سيتم إعلامك عند انضمام أي راكب آخر',
    );

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(IconsaxPlusBold.trash, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        onDelete?.call();
        return true;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.tajawal(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      route,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsRow(
                      departure: departure,
                      distance: distance,
                      meetingPoint: meetingPoint,
                      seats: seats,
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 1, color: _divider),
                    const SizedBox(height: 14),
                    _buildFooter(
                      title: footerTitle,
                      subtitle: footerSubtitle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                IconsaxPlusBold.people,
                size: 14,
                color: _purple,
              ),
              const SizedBox(width: 6),
              Text(
                'رحلة مشتركة جديدة',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC4B5FD),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'الآن',
          style: GoogleFonts.tajawal(
            fontSize: 12,
            color: _label,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'VisionWay',
          style: GoogleFonts.tajawal(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _label,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2A2A2C)),
          ),
          alignment: Alignment.center,
          child: const Text(
            'V',
            style: TextStyle(
              color: Color(0xFF2DD4BF),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow({
    required String departure,
    required String distance,
    required String meetingPoint,
    required String seats,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatCell(
            icon: IconsaxPlusLinear.clock,
            label: 'وقت الانطلاق',
            value: departure,
          ),
        ),
        _vDivider(),
        Expanded(
          child: _StatCell(
            icon: IconsaxPlusLinear.routing,
            label: 'المسافة المتبقية',
            value: distance.endsWith('كم') || distance == '—'
                ? distance
                : '$distance كم',
          ),
        ),
        _vDivider(),
        Expanded(
          child: _StatCell(
            icon: IconsaxPlusLinear.location,
            label: 'نقطة التجمع',
            value: meetingPoint,
          ),
        ),
        _vDivider(),
        Expanded(
          child: _StatCell(
            icon: null,
            label: 'عدد المقاعد المتاحة',
            value: seats.contains('مقعد') || seats == '—'
                ? seats
                : '$seats مقاعد',
          ),
        ),
      ],
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: _divider,
    );
  }

  Widget _buildFooter({required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: _purple,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            IconsaxPlusBold.user,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _purple,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.right,
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: _label,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _buildRoute(Map<String, dynamic> data) {
    final from = _text(data, ['fromName'], fallback: '');
    final to = _text(data, ['toName'], fallback: '');
    if (from.isEmpty && to.isEmpty) return '—';
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from - $to';
  }

  static String _text(
    Map<String, dynamic> data,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData? icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: SharedTripBookingNotificationCard._label),
          const SizedBox(height: 4),
        ] else
          const SizedBox(height: 20),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.tajawal(
            fontSize: 10,
            color: SharedTripBookingNotificationCard._label,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.tajawal(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
