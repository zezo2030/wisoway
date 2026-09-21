import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import 'ride_mode_artwork.dart';

/// The two ways a passenger can travel, as offered on the home screen.
enum RideMode {
  /// Join a driver's published trip and split the fare with other passengers.
  shared,

  /// Hail a driver who comes straight to you.
  private,
}

/// One of the two headline choices on the passenger home screen.
///
/// The whole card is tappable, not just the button, because the button is a
/// small target next to a card people naturally aim at.
class RideModeCard extends StatelessWidget {
  final RideMode mode;
  final VoidCallback onPressed;

  const RideModeCard({super.key, required this.mode, required this.onPressed});

  bool get _isShared => mode == RideMode.shared;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = _isShared ? T.primary(context) : T.info(context);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _badge(context, accent, l10n),
              ),
              const SizedBox(height: 6),
              _artwork(context, accent),
              const SizedBox(height: 10),
              Text(
                _isShared
                    ? l10n.rideModeSharedTitle
                    : l10n.rideModePrivateTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isShared
                    ? l10n.rideModeSharedSubtitle
                    : l10n.rideModePrivateSubtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: T.onSurfaceVariant(context),
                ),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: accent.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              _perks(context, accent, l10n),
              const SizedBox(height: 10),
              _cta(context, accent, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, Color accent, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isShared ? IconsaxPlusBold.tag : IconsaxPlusBold.flash_1,
            size: 12,
            color: accent,
          ),
          const SizedBox(width: 4),
          Text(
            _isShared ? l10n.rideModeSharedBadge : l10n.rideModePrivateBadge,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  /// The mockup's scene: our white sedan in front of a soft skyline, with
  /// riders queued along the route for the shared card and a lone pin for the
  /// private one.
  Widget _artwork(BuildContext context, Color accent) {
    return RideModeArtwork(accent: accent, shared: _isShared);
  }

  Widget _perks(BuildContext context, Color accent, AppLocalizations l10n) {
    final perks = _isShared
        ? <(IconData, String)>[
            (IconsaxPlusBold.profile_2user, l10n.rideModeSharedPerkSeats),
            (IconsaxPlusBold.tag, l10n.rideModeSharedPerkPrice),
            (IconsaxPlusBold.tree, l10n.rideModeSharedPerkEco),
          ]
        : <(IconData, String)>[
            (IconsaxPlusBold.flash_1, l10n.rideModePrivatePerkFast),
            (IconsaxPlusBold.shield_tick, l10n.rideModePrivatePerkPrivacy),
            (IconsaxPlusBold.profile_circle, l10n.rideModePrivatePerkDirect),
          ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < perks.length; index++) ...[
          if (index > 0)
            Container(
              width: 1,
              height: 26,
              color: accent.withValues(alpha: 0.16),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(perks[index].$1, size: 16, color: accent),
                const SizedBox(height: 4),
                Text(
                  perks[index].$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.25,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cta(BuildContext context, Color accent, AppLocalizations l10n) {
    final label = _isShared ? l10n.rideModeSharedCta : l10n.rideModePrivateCta;

    if (_isShared) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(IconsaxPlusLinear.search_normal, size: 16, color: accent),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
