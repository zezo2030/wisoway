import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/localization_service.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

/// Entry point of registration: pick passenger or driver.
///
/// Layout follows `docs/superpowers/assets/2026-07-28-auth-registration/
/// account-type-selection.png`: cityscape header, two accent-coloured hero
/// cards side by side, safety banner, sign-in link.
class AccountTypeSelectionScreen extends StatefulWidget {
  const AccountTypeSelectionScreen({super.key});

  @override
  State<AccountTypeSelectionScreen> createState() =>
      _AccountTypeSelectionScreenState();
}

/// Driver cards use a violet accent so the two roles read apart at a glance.
const Color _driverAccent = Color(0xFF7C3AED);

class _AccountTypeSelectionScreenState extends State<AccountTypeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: T.surface(context),
      body: Stack(
        children: [
          // Cityscape sits behind the header only; the cards cover the rest.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/illustrations/auth/auth_account_type_cityscape.png',
                height: 320,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    SlideTransition(
                      position: _slideAnimation,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _AccountTypeCard(
                                heroAsset:
                                    'assets/illustrations/auth/auth_passenger_card_hero.png',
                                badgeIcon: IconsaxPlusBold.profile_circle,
                                accent: T.primary(context),
                                title: l10n.accountTypePassenger,
                                tagline: l10n.accountTypePassengerTagline,
                                features: [
                                  _CardFeature(
                                    IconsaxPlusLinear.car,
                                    l10n
                                        .accountTypePassengerFeatureDirectTitle,
                                    l10n.accountTypePassengerFeatureDirectBody,
                                  ),
                                  _CardFeature(
                                    IconsaxPlusLinear.profile_2user,
                                    l10n
                                        .accountTypePassengerFeatureSharedTitle,
                                    l10n.accountTypePassengerFeatureSharedBody,
                                  ),
                                  _CardFeature(
                                    IconsaxPlusLinear.card,
                                    l10n
                                        .accountTypePassengerFeaturePaymentTitle,
                                    l10n.accountTypePassengerFeaturePaymentBody,
                                  ),
                                ],
                                onTap: () => Navigator.pushReplacementNamed(
                                  context,
                                  RouteNames.signUp,
                                  arguments: {
                                    'accountType': AppConstants.rolePassenger,
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AccountTypeCard(
                                heroAsset:
                                    'assets/illustrations/auth/auth_driver_card_hero.png',
                                badgeIcon: IconsaxPlusBold.car,
                                accent: _driverAccent,
                                title: l10n.accountTypeDriver,
                                tagline: l10n.accountTypeDriverTagline,
                                features: [
                                  _CardFeature(
                                    IconsaxPlusLinear.driving,
                                    l10n.accountTypeDriverFeatureTripsTitle,
                                    l10n.accountTypeDriverFeatureTripsBody,
                                  ),
                                  _CardFeature(
                                    IconsaxPlusLinear.profile_2user,
                                    l10n.accountTypeDriverFeatureBookingsTitle,
                                    l10n.accountTypeDriverFeatureBookingsBody,
                                  ),
                                  _CardFeature(
                                    IconsaxPlusLinear.wallet_money,
                                    l10n.accountTypeDriverFeatureIncomeTitle,
                                    l10n.accountTypeDriverFeatureIncomeBody,
                                  ),
                                ],
                                onTap: () => Navigator.pushReplacementNamed(
                                  context,
                                  RouteNames.driverSignUp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSafetyBanner(),
                    const SizedBox(height: 12),
                    _buildSignInRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Image.asset(
          'assets/illustrations/auth/auth_visionway_logo.png',
          height: 44,
          fit: BoxFit.contain,
        ),
        const _LanguageSwitcher(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: T.primary(context).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.primary(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconsaxPlusBold.profile_circle,
              size: 28,
              color: T.onPrimary(context),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.accountTypeTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.accountTypeSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: T.onSurfaceVariant(context)),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dash(T.primary(context)),
            const SizedBox(width: 4),
            _dash(_driverAccent),
          ],
        ),
      ],
    );
  }

  Widget _dash(Color color) => Container(
    width: 26,
    height: 3,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildSafetyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.outline(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              IconsaxPlusBold.shield_tick,
              color: T.primary(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.accountTypeSafetyTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.accountTypeSafetyBody,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.alreadyHaveAccount,
            style: TextStyle(fontSize: 13, color: T.onSurfaceVariant(context)),
          ),
          Semantics(
            button: true,
            label: context.l10n.signIn,
            child: TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, RouteNames.signIn),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.signIn,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: T.primary(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    size: 16,
                    color: T.primary(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();

    return Semantics(
      button: true,
      label: context.l10n.language,
      child: PopupMenuButton<String>(
        onSelected: (code) => localization.setLanguage(code),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => const [
          PopupMenuItem(value: AppConstants.langArabic, child: Text('العربية')),
          PopupMenuItem(value: AppConstants.langEnglish, child: Text('English')),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: T.outline(context)),
            boxShadow: [
              BoxShadow(
                color: T.shadow(context).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(IconsaxPlusLinear.global, size: 18, color: T.primary(context)),
              const SizedBox(width: 6),
              Text(
                localization.isArabic ? 'العربية' : 'English',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: T.onSurface(context),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: T.onSurfaceVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardFeature {
  const _CardFeature(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.heroAsset,
    required this.badgeIcon,
    required this.accent,
    required this.title,
    required this.tagline,
    required this.features,
    required this.onTap,
  });

  final String heroAsset;
  final IconData badgeIcon;
  final Color accent;
  final String title;
  final String tagline;
  final List<_CardFeature> features;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title - $tagline',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(context),
                const SizedBox(height: 26),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 14),
                for (final feature in features) ...[
                  _buildFeatureRow(context, feature),
                  const SizedBox(height: 10),
                ],
                const Spacer(),
                Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1.05,
            child: Image.asset(heroAsset, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          bottom: -20,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              border: Border.all(color: T.surface(context), width: 3),
            ),
            child: Icon(badgeIcon, size: 20, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(BuildContext context, _CardFeature feature) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(feature.icon, size: 15, color: accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: T.onSurface(context),
                ),
              ),
              Text(
                feature.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: T.onSurfaceVariant(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
