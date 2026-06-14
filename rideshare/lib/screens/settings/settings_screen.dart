import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/constants/social_constants.dart';
import '../../../core/constants/support_constants.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/localization_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/settings/settings_section.dart';
import '../../../widgets/settings/settings_tile.dart';
import '../../../widgets/settings/settings_switch_tile.dart';
import 'account_security_screen.dart';
import 'in_app_browser_screen.dart';
import '../../l10n/l10n_extensions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _pushNotifications = false;
  bool _notifSound = false;
  bool _notifVibration = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final settings = SettingsService();
    _pushNotifications = await settings.isPushNotificationsEnabled();
    _notifSound = await settings.isNotificationSoundEnabled();
    _notifVibration = await settings.isNotificationVibrationEnabled();
    setState(() => _isLoading = false);
  }

  void _showThemeBottomSheet(BuildContext context) {
    final themeService = context.read<ThemeService>();
    final currentMode = themeService.themeMode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.selectTheme,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RadioListTile<ThemeMode>(
              title: Text(context.l10n.themeSystem),
              value: ThemeMode.system,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text(context.l10n.themeLight),
              value: ThemeMode.light,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text(context.l10n.themeDark),
              value: ThemeMode.dark,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLanguageBottomSheet(BuildContext context) {
    final localizationService = context.read<LocalizationService>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
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
            RadioListTile<String>(
              title: const Text('العربية'),
              value: 'ar',
              groupValue: localizationService.locale.languageCode,
              onChanged: (value) {
                if (value != null) {
                  localizationService.setLanguage(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: localizationService.locale.languageCode,
              onChanged: (value) {
                if (value != null) {
                  localizationService.setLanguage(value);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteAccount),
        content: Text(ctx.l10n.deleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSecondConfirmationDialog(context);
            },
            style: TextButton.styleFrom(foregroundColor: T.error(context)),
            child: Text(ctx.l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
  }

  void _showSecondConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteAccountSecondTitle),
        content: Text(ctx.l10n.deleteAccountSecondWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _attemptDeleteAccount(context);
            },
            style: TextButton.styleFrom(foregroundColor: T.error(context)),
            child: Text(ctx.l10n.deleteAccountSecondConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _attemptDeleteAccount(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signOut();
    } catch (_) {
      _showContactSupportDialog(context);
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorWithMessage(url))),
      );
    }
  }

  void _showContactSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.contactSupportTitle),
        content: Text(ctx.l10n.contactSupportMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, RouteNames.support);
            },
            child: Text(ctx.l10n.contactWhatsApp),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri(
                scheme: 'mailto',
                path: SupportConstants.supportEmail,
                queryParameters: {'subject': 'Account Deletion Request'},
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Text(ctx.l10n.contactEmail),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSection(
                  title: context.l10n.appearance,
                  children: [
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.moon,
                      title: context.l10n.darkMode,
                      value: themeService.themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        themeService.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                    SettingsTile(
                      icon: IconsaxPlusBroken.color_swatch,
                      title: context.l10n.themeMode,
                      subtitle: themeService.themeMode == ThemeMode.system
                          ? context.l10n.themeSystem
                          : themeService.themeMode == ThemeMode.light
                          ? context.l10n.themeLight
                          : context.l10n.themeDark,
                      trailing: const Icon(IconsaxPlusBroken.arrow_down_1),
                      onTap: () => _showThemeBottomSheet(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: context.l10n.language,
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.language_square,
                      title: context.l10n.language,
                      subtitle: context.l10n.currentLanguageAr,
                      trailing: const Icon(IconsaxPlusBroken.arrow_down_1),
                      onTap: () => _showLanguageBottomSheet(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: context.l10n.notifications,
                  children: [
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.notification,
                      title: context.l10n.pushNotifications,
                      value: _pushNotifications,
                      onChanged: (value) {
                        final settings = SettingsService();
                        settings.setPushNotificationsEnabled(value);
                        setState(() => _pushNotifications = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.volume_high,
                      title: context.l10n.notificationSound,
                      value: _notifSound,
                      enabled: _pushNotifications,
                      onChanged: _pushNotifications
                          ? (value) {
                              final settings = SettingsService();
                              settings.setNotificationSoundEnabled(value);
                              setState(() => _notifSound = value);
                            }
                          : null,
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.mobile,
                      title: context.l10n.notificationVibration,
                      value: _notifVibration,
                      enabled: _pushNotifications,
                      onChanged: _pushNotifications
                          ? (value) {
                              final settings = SettingsService();
                              settings.setNotificationVibrationEnabled(value);
                              setState(() => _notifVibration = value);
                            }
                          : null,
                    ),
                  ],
                ),
                SettingsSection(
                  title: context.l10n.accountSecurity,
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.user,
                      title: context.l10n.accountInfo,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSecurityScreen(),
                          ),
                        );
                      },
                    ),
                    SettingsTile(
                      icon: IconsaxPlusBroken.lock,
                      title: context.l10n.changePassword,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.pushNamed(context, RouteNames.changePassword);
                      },
                    ),
                  ],
                ),
                if (context.watch<AuthProvider>().userModel?.role ==
                    AppConstants.roleDriver)
                  SettingsSection(
                    title: context.l10n.driverSection,
                    children: [
                      SettingsTile(
                        icon: IconsaxPlusBroken.car,
                        title: context.l10n.vehicleAndSeatLayout,
                        trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.vehicleSettings,
                          );
                        },
                      ),
                    ],
                  ),
                SettingsSection(
                  title: context.l10n.paymentAndWallet,
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.wallet,
                      title: context.l10n.wallet,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        final authProvider = context.read<AuthProvider>();
                        final isDriver =
                            authProvider.userModel?.role ==
                            AppConstants.roleDriver;
                        Navigator.pushNamed(
                          context,
                          isDriver
                              ? RouteNames.driverWallet
                              : RouteNames.passengerWallet,
                        );
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  title: context.l10n.supportAndHelp,
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.message,
                      title: context.l10n.contactUs,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.pushNamed(context, RouteNames.support);
                      },
                    ),
                    SettingsTile(
                      icon: IconsaxPlusBroken.document_text,
                      title: context.l10n.termsOfService,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InAppBrowserScreen(
                              title: context.l10n.termsOfService,
                              url: 'https://rideshare.app/terms',
                            ),
                          ),
                        );
                      },
                    ),
                    SettingsTile(
                      icon: IconsaxPlusBroken.shield_security,
                      title: context.l10n.privacyPolicy,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InAppBrowserScreen(
                              title: context.l10n.privacyPolicy,
                              url: 'https://rideshare.app/privacy',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  title: context.l10n.followUs,
                  children: [
                    SettingsTile(
                      icon: Icons.facebook,
                      iconColor: const Color(0xFF1877F2),
                      title: context.l10n.followOnFacebook,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () => _openExternalUrl(SocialConstants.facebookUrl),
                    ),
                    SettingsTile(
                      icon: Icons.business_center,
                      iconColor: const Color(0xFF0A66C2),
                      title: context.l10n.followOnLinkedIn,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () => _openExternalUrl(SocialConstants.linkedInUrl),
                    ),
                  ],
                ),
                SettingsSection(
                  title: context.l10n.aboutApp,
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.info_circle,
                      title: context.l10n.aboutApp,
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.pushNamed(context, RouteNames.about);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: T.error(context).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: T.error(context).withValues(alpha: 0.2),
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        IconsaxPlusBroken.trash,
                        color: T.error(context),
                      ),
                      title: Text(
                        context.l10n.deleteAccount,
                        style: TextStyle(
                          color: T.error(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
