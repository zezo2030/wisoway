import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';

/// Five-column facts strip under the route card: day, time, meeting point,
/// distance and seats. Each column is an icon over a label over a value.
///
/// Takes plain values rather than a `TripModel` so it stays testable without
/// model fixtures.
///
/// The mock's «مكان التجمع» has no dedicated backing field. The caller passes
/// `trip.from.address` as [meetingPoint]; when that is null the strip falls
/// back to [originName] rather than rendering an empty cell.
class TripFactsStrip extends StatelessWidget {
  const TripFactsStrip({
    super.key,
    required this.departureTime,
    required this.meetingPoint,
    required this.originName,
    required this.distanceKm,
    required this.bookedSeats,
    required this.totalSeats,
  });

  final DateTime departureTime;
  final String? meetingPoint;
  final String originName;
  final double? distanceKm;
  final int bookedSeats;
  final int totalSeats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final isFull = totalSeats > 0 && bookedSeats >= totalSeats;

    final meeting = (meetingPoint != null && meetingPoint!.trim().isNotEmpty)
        ? meetingPoint!
        : originName;

    final km = distanceKm;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Fact(
            icon: IconsaxPlusLinear.calendar,
            label: l10n.tripDayLabel,
            value: DateFormat('EEEE\nd MMM', locale).format(departureTime),
          ),
          _Fact(
            icon: IconsaxPlusLinear.clock,
            label: l10n.tripTimeLabel,
            value: DateFormat.jm(locale).format(departureTime),
          ),
          _Fact(
            icon: IconsaxPlusLinear.location,
            label: l10n.tripMeetingPointLabel,
            value: meeting,
          ),
          _Fact(
            icon: IconsaxPlusLinear.routing,
            label: l10n.tripDistanceShortLabel,
            value: km == null ? '—' : l10n.distanceKmValue('${km.round()}'),
          ),
          _Fact(
            icon: IconsaxPlusLinear.profile_2user,
            label: l10n.tripSeatsLabel,
            value: l10n.tripSeatsBookedOf('$bookedSeats', '$totalSeats'),
            badge: isFull ? l10n.tripSeatsComplete : null,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Icon(icon, size: 18, color: T.primary(context)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: T.textSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: T.onSurface(context),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 2),
              Text(
                badge!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.success(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
