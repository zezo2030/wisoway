import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';

/// Fare breakdown for the driver's pre-departure trip screen: the per-seat
/// fare, the total across booked seats, and the platform trip fee.
///
/// Takes plain values rather than a `TripModel` so it stays testable without
/// model fixtures.
///
/// [feePercent] and [feeAmount] come from `GET /trips/fee-quote`, never from a
/// literal — the two invoice dialogs deleted earlier both hardcoded `'5%'`
/// while the backend charged a different rate. When the quote is unavailable
/// the fee row renders a neutral placeholder instead of guessing.
class TripFareBreakdownCard extends StatelessWidget {
  const TripFareBreakdownCard({
    super.key,
    required this.seatPrice,
    required this.bookedSeats,
    required this.feeAmount,
    required this.feePercent,
    required this.currency,
  });

  final double seatPrice;
  final int bookedSeats;
  final double? feeAmount;
  final double? feePercent;
  final String currency;

  static String formatPercent(double percent) => percent == percent.roundToDouble()
      ? percent.toStringAsFixed(0)
      : percent.toStringAsFixed(1);

  String _money(double amount) => '${amount.toStringAsFixed(2)} $currency';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final percent = feePercent;
    final amount = feeAmount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _FareRow(
            label: l10n.passengerFareLabel,
            value: _money(seatPrice),
          ),
          _FareRow(
            label: l10n.passengersTotalLabel(bookedSeats),
            value: _money(seatPrice * bookedSeats),
          ),
          _FareRow(
            label: percent == null
                ? l10n.tripFeePercentLabel('—')
                : l10n.tripFeePercentLabel(formatPercent(percent)),
            value: amount == null ? '—' : _money(amount),
            valueColor: T.error(context),
          ),
        ],
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? T.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Info box telling the driver when the trip fee leaves their wallet.
///
/// The design mock reads «عند انتهاء الرحلة» (at trip *end*). That wording is
/// deliberately superseded here: the fee is charged at trip *start*, so the
/// mock's copy would be factually wrong.
class TripFeeNotice extends StatelessWidget {
  const TripFeeNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.primaryContainer(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            IconsaxPlusLinear.info_circle,
            size: 20,
            color: T.primary(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.tripFeeChargedAtStartNotice,
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onPrimaryContainer(context),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
