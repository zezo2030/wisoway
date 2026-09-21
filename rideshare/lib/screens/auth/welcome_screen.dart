import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import '../../widgets/auth/auth_language_switcher.dart';
import '../../widgets/common/form_components.dart';
import '../settings/in_app_browser_screen.dart';

/// First screen an unauthenticated user sees.
///
/// Layout mirrors the VisionWay welcome mockup: language pill, brand lockup,
/// highlighted headline, the direct/shared trip-type card, three trust
/// features, the two entry buttons and the terms footer.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _termsUrl = 'https://rideshare.app/terms';
  static const String _privacyUrl = 'https://rideshare.app/privacy';

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    // The whole page scrolls as one: the wash, the halo and the cityscape live
    // inside the scroll view with the copy, so the artwork travels with the
    // content instead of staying pinned while the text slides over it.
    return Scaffold(
      backgroundColor: T.surface(context),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          // Keeps the backdrop covering the viewport when the copy is short.
          constraints: BoxConstraints(minHeight: screenHeight),
          child: Stack(
            children: [
              // Soft mint wash behind everything.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        T.primary(context).withValues(alpha: 0.04),
                        T.surface(context),
                        T.primary(context).withValues(alpha: 0.02),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Halo arc in the top corner, matching the mockup.
              Positioned(
                top: -120,
                right: -70,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: T.primary(context).withValues(alpha: 0.06),
                  ),
                ),
              ),

              // Cityscape + car band sits behind the hero copy.
              Positioned(
                top: screenHeight * 0.40,
                left: 0,
                right: 0,
                height: screenHeight * 0.17,
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    'assets/illustrations/auth/auth_welcome_cityscape.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),

              // The only unpositioned child, so it is what the Stack sizes to.
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: const AuthLanguageSwitcher(),
                        ),
                        const SizedBox(height: 12),
                        _buildBrandLockup(),
                        const SizedBox(height: 18),
                        _buildHeadline(),
                        const SizedBox(height: 12),
                        _buildSubtitle(),
                        const SizedBox(height: 64),
                        SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTripTypesCard(),
                              const SizedBox(height: 22),
                              _buildFeatureRow(),
                              const SizedBox(height: 20),
                              _buildActions(),
                              const SizedBox(height: 14),
                              _buildTermsFooter(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandLockup() {
    return Column(
      children: [
        Image.asset(
          'assets/illustrations/auth/auth_visionway_badge.png',
          height: 100,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        Text(
          'VisionWay',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          context.l10n.welcomeBrandTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: T.primary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    final base = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.35,
      letterSpacing: -0.3,
      color: T.onSurface(context),
    );

    return Text.rich(
      TextSpan(
        children: _highlightSpans(context.l10n.welcomeTitle, const [
          'VisionWay',
        ], TextStyle(color: T.primary(context))),
      ),
      textAlign: TextAlign.center,
      style: base,
    );
  }

  Widget _buildSubtitle() {
    final l10n = context.l10n;

    return Text.rich(
      TextSpan(
        children: _highlightSpans(l10n.welcomeSubtitle, [
          l10n.welcomeSubtitleHighlightDirect,
          l10n.welcomeSubtitleHighlightShared,
        ], TextStyle(color: T.primary(context), fontWeight: FontWeight.w700)),
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        height: 1.75,
        color: T.textSecondary(context),
      ),
    );
  }

  Widget _buildTripTypesCard() {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: T.outline(context)),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _TripTypeTile(
                icon: IconsaxPlusBold.car,
                title: l10n.welcomeDirectTitle,
                body: l10n.welcomeDirectBody,
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: T.outline(context),
            ),
            Expanded(
              child: _TripTypeTile(
                icon: IconsaxPlusBold.profile_2user,
                title: l10n.welcomeSharedTitle,
                body: l10n.welcomeSharedBody,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow() {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _FeatureTile(
            icon: IconsaxPlusBold.tag,
            title: l10n.welcomeFeaturePricingTitle,
            body: l10n.welcomeFeaturePricingBody,
          ),
        ),
        Expanded(
          child: _FeatureTile(
            icon: IconsaxPlusBold.flash,
            title: l10n.welcomeFeatureSpeedTitle,
            body: l10n.welcomeFeatureSpeedBody,
          ),
        ),
        Expanded(
          child: _FeatureTile(
            icon: IconsaxPlusBold.shield_tick,
            title: l10n.welcomeFeatureSafetyTitle,
            body: l10n.welcomeFeatureSafetyBody,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryGradientButton(
          onPressed: () => Navigator.pushNamed(context, RouteNames.signIn),
          text: context.l10n.signIn,
          trailingIcon: IconsaxPlusLinear.arrow_circle_left,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 58,
          child: OutlinedButton(
            onPressed: () =>
                Navigator.pushNamed(context, RouteNames.accountTypeSelection),
            style: OutlinedButton.styleFrom(
              backgroundColor: T.surface(context),
              foregroundColor: T.primary(context),
              side: BorderSide(
                color: T.primary(context).withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              context.l10n.createNewAccount,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsFooter() {
    final l10n = context.l10n;
    final labelStyle = TextStyle(
      fontSize: 12,
      color: T.textSecondary(context),
      height: 1.6,
    );

    return Column(
      children: [
        Text(
          l10n.welcomeTermsPrefix,
          textAlign: TextAlign.center,
          style: labelStyle,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          children: [
            _legalLink(l10n.welcomeTermsLink, _termsUrl),
            Text(l10n.welcomeTermsAnd, style: labelStyle),
            _legalLink(l10n.privacyPolicy, _privacyUrl),
          ],
        ),
      ],
    );
  }

  Widget _legalLink(String label, String url) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InAppBrowserScreen(title: label, url: url),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          height: 1.6,
          fontWeight: FontWeight.w600,
          color: T.primary(context),
          decoration: TextDecoration.underline,
          decorationColor: T.primary(context),
        ),
      ),
    );
  }

  /// Splits [text] so every occurrence of [words] renders with [highlight].
  List<TextSpan> _highlightSpans(
    String text,
    List<String> words,
    TextStyle highlight,
  ) {
    final terms = words.where((word) => word.trim().isNotEmpty).toList();
    if (terms.isEmpty) return [TextSpan(text: text)];

    final pattern = RegExp(terms.map(RegExp.escape).join('|'));
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: highlight));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}

/// One half of the direct/shared card: icon beside a title and one-line body.
class _TripTypeTile extends StatelessWidget {
  const _TripTypeTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: T.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: T.primary(context).withValues(alpha: 0.10),
          ),
          child: Icon(icon, size: 22, color: T.primary(context)),
        ),
      ],
    );
  }
}

/// One of the three trust badges under the trip-type card.
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: T.primary(context).withValues(alpha: 0.10),
          ),
          child: Icon(icon, size: 24, color: T.primary(context)),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            color: T.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
