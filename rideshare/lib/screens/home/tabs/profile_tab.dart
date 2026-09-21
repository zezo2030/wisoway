import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/theme/colors.dart';
import '../../../models/user_model.dart';
import '../../../models/wallet_account_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/notification_icon_button.dart';
import '../../../widgets/common/logout_confirmation_dialog.dart';
import '../../../l10n/l10n_extensions.dart';

/// Luminance weights, so the header illustration reads as one pale silhouette.
const List<double> _greyscaleMatrix = <double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class ProfileTab extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onOpenBookings;

  const ProfileTab({super.key, this.user, this.onOpenBookings});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final PaymentService _paymentService = PaymentService();
  WalletAccountModel? _walletAccount;
  bool _refreshing = false;

  UserModel? get user => widget.user;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final account = await _paymentService.getWalletAccountMe();
      if (mounted) setState(() => _walletAccount = account);
    } catch (_) {
      if (mounted) setState(() => _walletAccount = null);
    }
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<AuthProvider>().loadUserProfile();
      await _loadWallet();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dataUpdated),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dataUpdateFailed(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.pushNamed(context, RouteNames.editProfile);
    if (mounted) context.read<AuthProvider>().loadUserProfile();
  }

  Future<void> _openWallet() async {
    final isDriver = user?.isDriver == true;
    await Navigator.pushNamed(
      context,
      isDriver ? RouteNames.driverWallet : RouteNames.passengerWallet,
    );
    if (mounted) _loadWallet();
  }

  Future<void> _openTopUp() async {
    final result = await Navigator.pushNamed(
      context,
      RouteNames.driverWalletTopup,
    );
    if (result == true && mounted) await _loadWallet();
  }

  void _openPhoneVerification() {
    Navigator.pushNamed(
      context,
      RouteNames.phoneAuth,
      arguments: {'isLinkPhone': true},
    ).then((_) {
      if (mounted) context.read<AuthProvider>().loadUserProfile();
    });
  }

  void _openBookings() {
    if (widget.onOpenBookings != null) {
      widget.onOpenBookings!();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.comingSoon)));
    }
  }

  void _showLanguageBottomSheet() {
    final localizationService = context.read<LocalizationService>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.selectLanguage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RadioGroup<String>(
              groupValue: localizationService.locale.languageCode,
              onChanged: (value) {
                if (value != null) {
                  localizationService.setLanguage(value);
                  Navigator.pop(sheetContext);
                }
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('العربية'),
                    value: 'ar',
                  ),
                  RadioListTile<String>(
                    title: const Text('English'),
                    value: 'en',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              T.primary(context).withValues(alpha: isDark ? 0.10 : 0.09),
              T.background(context),
              T.background(context),
            ],
            stops: const [0.0, 0.26, 1.0],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: T.primary(context),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  _buildHero(context, isDark),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (user != null &&
                            user!.isDriver &&
                            !user!.isDriverApproved)
                          _buildDriverReviewBanner(context),
                        _buildWalletCard(context),
                        const SizedBox(height: 20),
                        _buildSection(
                          context,
                          title: context.l10n.profileAccountSection,
                          rows: [
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.profile_add,
                              title: context.l10n.editProfileMenuItem,
                              subtitle: context.l10n.editProfileSubtitle,
                              onTap: _openEditProfile,
                            ),
                            _divider(context),
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.empty_wallet,
                              title: context.l10n.paymentMethods,
                              subtitle: context.l10n.paymentMethodsSubtitle,
                              onTap: _openWallet,
                            ),
                            _divider(context),
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.location,
                              title: context.l10n.savedAddresses,
                              subtitle: context.l10n.savedAddressesSubtitle,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.l10n.comingSoon),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          context,
                          title: context.l10n.myTripsTitle,
                          rows: [
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.clock,
                              title: context.l10n.pastTrips,
                              subtitle: context.l10n.pastTripsSubtitle,
                              onTap: _openBookings,
                            ),
                            _divider(context),
                            _buildMenuRow(
                              context,
                              icon: Icons.close_rounded,
                              title: context.l10n.cancelledTrips,
                              subtitle: context.l10n.cancelledTripsSubtitle,
                              onTap: _openBookings,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          context,
                          title: context.l10n.profileAppSection,
                          rows: [
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.setting_2,
                              title: context.l10n.settings,
                              subtitle: context.l10n.settingsSubtitle,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  RouteNames.settings,
                                );
                              },
                            ),
                            _divider(context),
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.notification,
                              title: context.l10n.notifications,
                              subtitle: context.l10n.notificationsSubtitle,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  RouteNames.notificationSettings,
                                );
                              },
                            ),
                            _divider(context),
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.global,
                              title: context.l10n.language,
                              subtitle: context.l10n.languageSubtitle,
                              onTap: _showLanguageBottomSheet,
                            ),
                            _divider(context),
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.moon,
                              title: context.l10n.darkMode,
                              subtitle: context.l10n.darkModeSubtitle,
                              trailing: Switch.adaptive(
                                value: themeService.themeMode == ThemeMode.dark,
                                activeTrackColor: T.primary(context),
                                onChanged: (value) {
                                  context.read<ThemeService>().setThemeMode(
                                    value ? ThemeMode.dark : ThemeMode.light,
                                  );
                                },
                              ),
                              onTap: () {
                                final dark =
                                    themeService.themeMode == ThemeMode.dark;
                                context.read<ThemeService>().setThemeMode(
                                  dark ? ThemeMode.light : ThemeMode.dark,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          context,
                          title: context.l10n.supportAndHelp,
                          rows: [
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.headphone,
                              title: context.l10n.helpAndSupport,
                              subtitle: context.l10n.helpSupportSubtitle,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  RouteNames.support,
                                );
                              },
                            ),
                            _divider(context),
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.message_text,
                              title: context.l10n.contactUs,
                              subtitle: context.l10n.contactUsSubtitle,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  RouteNames.support,
                                );
                              },
                            ),
                            _divider(context),
                            _buildMenuRow(
                              context,
                              icon: IconsaxPlusLinear.info_circle,
                              title: context.l10n.aboutApp,
                              subtitle: context.l10n.aboutAppSubtitle,
                              onTap: () {
                                Navigator.pushNamed(context, RouteNames.about);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildLogoutButton(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            Center(
              child: Text(
                context.l10n.profileTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
            ),
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.refreshData,
                    onPressed: _refreshing ? null : _onRefresh,
                    icon: _refreshing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                T.primary(context),
                              ),
                            ),
                          )
                        : Icon(
                            IconsaxPlusLinear.refresh,
                            size: 22,
                            color: T.onSurface(context),
                          ),
                  ),
                  const NotificationIconButton(
                    backgroundColor: AppColors.transparent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thin trailing chevron. The Material glyph mirrors itself under RTL, so
  /// this reads as "<" in Arabic and ">" in English on its own.
  IconData get _chevronIcon => Icons.chevron_right_rounded;

  Widget _buildHero(BuildContext context, bool isDark) {
    final name = user?.name ?? context.l10n.userFallback;

    return Stack(
      children: [
        PositionedDirectional(
          end: 0,
          bottom: 0,
          child: _buildHeroIllustration(isDark),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 20,
            end: 20,
            top: 12,
            bottom: 16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: T.onSurface(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildRoleBadge(context),
                    const SizedBox(height: 6),
                    _buildTrustBadge(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroIllustration(bool isDark) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.white, Colors.white],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            isDark ? const Color(0xFF134E4A) : const Color(0xFFF2FAF8),
            BlendMode.multiply,
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
            child: Image.asset(
              'assets/illustrations/auth/auth_welcome_cityscape.png',
              width: 250,
              height: 158,
              fit: BoxFit.cover,
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final photoUrl = user?.photoUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: T.primary(context),
            border: Border.all(
              color: T.primary(context).withValues(alpha: 0.3),
              width: 3,
            ),
          ),
          child: ClipOval(
            child: photoUrl != null && photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    width: 110,
                    height: 110,
                    errorWidget: (context, url, error) => Icon(
                      IconsaxPlusBold.profile,
                      size: 52,
                      color: T.onPrimary(context),
                    ),
                  )
                : Icon(
                    IconsaxPlusBold.profile,
                    size: 58,
                    color: T.onPrimary(context),
                  ),
          ),
        ),
        PositionedDirectional(
          end: -2,
          bottom: -2,
          child: Material(
            color: T.surface(context),
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openEditProfile,
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Semantics(
                  label: context.l10n.editProfilePhoto,
                  button: true,
                  child: Icon(
                    IconsaxPlusBold.camera,
                    size: 16,
                    color: T.primary(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(BuildContext context) {
    final isDriver = user?.isDriver == true;
    final color = isDriver ? T.secondary(context) : T.primary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDriver ? IconsaxPlusLinear.car : IconsaxPlusLinear.profile,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isDriver ? context.l10n.driver : context.l10n.passenger,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(BuildContext context) {
    final verified = user?.isPhoneVerified ?? false;
    final color = verified ? T.success(context) : AppColors.warning;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: verified ? null : _openPhoneVerification,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified
                  ? IconsaxPlusLinear.verify
                  : IconsaxPlusLinear.info_circle,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              verified
                  ? context.l10n.profileTrustedAccount
                  : context.l10n.profileUntrustedAccount,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverReviewBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            IconsaxPlusBold.timer,
            color: AppColors.warningDark,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.driverAccountUnderReview,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.warningDark,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, RouteNames.driverPendingApproval);
            },
            child: Text(context.l10n.checkVerificationStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    final balance = _walletAccount?.balance;
    final currency = _walletAccount?.currency ?? 'JOD';
    final currencyLabel = currency.toUpperCase() == 'JOD'
        ? context.l10n.currencyJodShort
        : currency;

    return InkWell(
      onTap: _openWallet,
      borderRadius: AppRadius.radiusXl,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            T.primary(context).withValues(alpha: 0.05),
            T.surface(context),
          ),
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: T.primary(context).withValues(alpha: 0.18)),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(
                IconsaxPlusLinear.empty_wallet,
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
                    context.l10n.walletBalanceLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    balance != null
                        ? '${balance.toStringAsFixed(2)} $currencyLabel'
                        : '—',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: T.primary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.walletTrialBalanceHint,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: T.onSurfaceVariant(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _openTopUp,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: T.primary(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      IconsaxPlusBold.add,
                      size: 14,
                      color: T.onPrimary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.walletTopUpBalance,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: T.onPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(_chevronIcon, size: 22, color: T.onSurfaceVariant(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: T.primary(context),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: AppRadius.radiusXl,
            border: Border.all(color: T.outline(context)),
            boxShadow: AppShadows.card,
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: T.outline(context).withValues(alpha: 0.5),
    );
  }

  Widget _buildMenuRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.08),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(icon, size: 20, color: T.primary(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: T.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: T.onSurfaceVariant(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  _chevronIcon,
                  size: 22,
                  color: T.onSurfaceVariant(context),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      onTap: () => handleLogout(context),
      borderRadius: AppRadius.radiusLg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: T.error(context).withValues(alpha: 0.06),
          borderRadius: AppRadius.radiusLg,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(IconsaxPlusLinear.logout, size: 20, color: T.error(context)),
            const SizedBox(width: 8),
            Text(
              context.l10n.logout,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: T.error(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
