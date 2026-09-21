import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import 'security_notice.dart';

/// Hero chrome shared by the registration entry screens.
///
/// Both screens used to stack their header over the illustration, which left
/// the subtitle and the privacy line sitting on the car and unreadable. Here
/// the header owns a flat band, the art is a ribbon below it, and the form
/// sheet rides over the ribbon's lower edge.
class AuthHero {
  const AuthHero._();

  /// The near-white the illustrations' skies fade into, so the band above the
  /// art and the sheet's corner notches read as one surface.
  static const Color backdrop = Color(0xFFF6FBFA);

  /// The band keeps this light palette in both themes, so its ink is pinned
  /// rather than read from the scheme: the dark scheme's near-white on-surface
  /// would leave the whole header invisible.
  static const Color ink = Color(0xFF10312E);
  static const Color inkMuted = Color(0xFF5C7F7A);
  static const Color chipFill = Color(0xFFE9F5F3);
  static const Color chipBorder = Color(0xFFCDE9E3);

  /// The illustrations are 3:2 with dead sky above the car and empty ground
  /// below it, so the ribbon is laid out wider than the source and cropped
  /// around a per-screen focus point.
  static const double artAspect = 2.15;

  /// How far the sheet rides over the ribbon, so the car tucks behind it.
  static const double artOverlap = 26;

  static double artHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).width / artAspect;
}

/// Badge, title, subtitle and — where the screen collects sensitive details —
/// the privacy line, laid out on the flat band above the art.
class AuthHeroTitle extends StatelessWidget {
  const AuthHeroTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showSecurityNotice = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showSecurityNotice;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AuthHero.backdrop,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: T.primary(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: T.primary(context).withValues(alpha: 0.26),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 27, color: AppColors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AuthHero.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AuthHero.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showSecurityNotice) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AuthHero.chipFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AuthHero.chipBorder),
                ),
                child: const SecurityNotice(color: AuthHero.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The illustration, cropped around [focus] so the car keeps the ribbon and the
/// dead bands above and below it are cut away.
class AuthHeroArt extends StatelessWidget {
  const AuthHeroArt({
    super.key,
    required this.asset,
    required this.focus,
    this.dark = false,
  });

  final String asset;

  /// Vertical crop anchor — see [AuthHero.artAspect]. Each illustration frames
  /// its subject differently, so the focus is passed in per screen.
  final Alignment focus;

  /// True for the illustrations painted on deep teal rather than a pale sky.
  /// Those cannot be washed into the band, so the ribbon is given its own
  /// rounded top edge and reads as a panel instead of a bleeding hero.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AuthHero.artHeight(context),
      width: double.infinity,
      child: ClipRRect(
        borderRadius: dark
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AuthHero.backdrop),
            Image.asset(asset, fit: BoxFit.cover, alignment: focus),
            // Washes the cropped top edge back into the band so it does not
            // read as a seam under the header.
            if (!dark)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AuthHero.backdrop, Color(0x00F6FBFA)],
                    stops: [0, 0.3],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lays the form sheet over the lower edge of [art], so the illustration is
/// clipped by the sheet's rounded lip instead of running behind the fields.
class AuthHeroSheet extends StatelessWidget {
  const AuthHeroSheet({super.key, required this.art, required this.child});

  final AuthHeroArt art;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, child: art),
        Padding(
          padding: EdgeInsets.only(
            top: AuthHero.artHeight(context) - AuthHero.artOverlap,
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: T.surface(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: T.shadow(context).withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
