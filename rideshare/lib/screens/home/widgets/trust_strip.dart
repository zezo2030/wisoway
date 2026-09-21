import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';

/// The four promises that close the home screen: safety, support, payment
/// choice and punctuality.
class TrustStrip extends StatelessWidget {
  const TrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final pillars = <(IconData, String, String)>[
      (
        IconsaxPlusBold.shield_tick,
        l10n.trustSafeRideTitle,
        l10n.trustSafeRideSubtitle,
      ),
      (
        IconsaxPlusBold.headphone,
        l10n.trustSupportTitle,
        l10n.trustSupportSubtitle,
      ),
      (
        IconsaxPlusBold.wallet_3,
        l10n.trustPaymentsTitle,
        l10n.trustPaymentsSubtitle,
      ),
      (IconsaxPlusBold.clock, l10n.trustOnTimeTitle, l10n.trustOnTimeSubtitle),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final pillar in pillars)
            Expanded(child: _pillar(context, pillar)),
        ],
      ),
    );
  }

  Widget _pillar(BuildContext context, (IconData, String, String) pillar) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pillar.$1, size: 20, color: T.primary(context)),
          const SizedBox(height: 6),
          Text(
            pillar.$2,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            pillar.$3,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.3,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }
}
