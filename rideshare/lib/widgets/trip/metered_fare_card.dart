import 'package:flutter/material.dart';

import '../../core/theme/text_styles.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/trip_fare_breakdown.dart';

/// «تفصيل الأجرة»: how an instant ride's metered fare was reached — base,
/// distance driven, time, waiting, and the minimum fare when it applied — so
/// a fare like 12.30 for a ride that barely moved explains itself.
class MeteredFareCard extends StatelessWidget {
  final TripFareBreakdown breakdown;

  const MeteredFareCard({super.key, required this.breakdown});

  static const Color _border = Color(0xFFE8ECF0);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _ink = Color(0xFF111827);
  static const Color _brand = Color(0xFF0D5C4D);

  String _money(double amount) =>
      '${breakdown.currency} ${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = breakdown;
    final km = b.distanceKm.toStringAsFixed(b.distanceKm >= 10 ? 0 : 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.fareBreakdownTitle,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          _row(l10n.fareBreakdownBase, _money(b.base)),
          _row(l10n.fareBreakdownDistance(km), _money(b.distanceCharge)),
          _row(
            l10n.fareBreakdownTime(b.durationMin),
            _money(b.timeCharge),
          ),
          if (b.minimumApplied)
            _row(
              l10n.fareBreakdownMinimum,
              _money(b.minimum),
              note: l10n.fareBreakdownMinimumNote,
            ),
          if (b.waitingMin > 0 || b.waitingCharge > 0)
            _row(
              l10n.fareBreakdownWaiting(b.waitingMin, b.freeWaitMin),
              _money(b.waitingCharge),
            ),
          if (b.rounding > 0)
            _row(l10n.fareBreakdownRounding, _money(b.rounding)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: _border),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.fareBreakdownTotal,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                _money(b.total),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(color: _muted),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(
              note,
              style: AppTextStyles.labelSmall.copyWith(
                color: _muted,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
