import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_names.dart';
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

  bool _ar(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl;
  }

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
    final isAr = _ar(context);

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
                isAr ? 'اختر السمة' : 'Choose Theme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RadioListTile<ThemeMode>(
              title: Text(isAr ? 'النظام' : 'System'),
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
              title: Text(isAr ? 'فاتح' : 'Light'),
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
              title: Text(isAr ? 'داكن' : 'Dark'),
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
    final isAr = _ar(context);

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
                isAr ? 'اختر اللغة' : 'Choose Language',
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

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/+201234567890?text=${Uri.encodeComponent('مرحباً، أحتاج مساعدة في تطبيق VisionWay')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final isArabic = _ar(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف الحساب' : 'Delete Account'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من رغبتك في حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.'
              : 'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSecondConfirmationDialog(context);
            },
            style: TextButton.styleFrom(foregroundColor: T.error(context)),
            child: Text(isArabic ? 'نعم، حذف الحساب' : 'Yes, Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showSecondConfirmationDialog(BuildContext context) {
    final isArabic = _ar(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'تأكيد الحذف' : 'Confirm Deletion'),
        content: Text(
          isArabic
              ? 'تحذير أخير: سيتم حذف جميع بياناتك بشكل نهائي ولن تتمكن من استرجاعها.'
              : 'Final warning: All your data will be permanently deleted and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _attemptDeleteAccount(context);
            },
            style: TextButton.styleFrom(foregroundColor: T.error(context)),
            child: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _attemptDeleteAccount(BuildContext context) async {
    final isArabic = _ar(context);
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signOut();
    } catch (_) {
      _showContactSupportDialog(context);
    }
  }

  void _showContactSupportDialog(BuildContext context) {
    final isArabic = _ar(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'تواصل مع الدعم' : 'Contact Support'),
        content: Text(
          isArabic
              ? 'لا يمكن حذف الحساب حالياً. تواصل مع الدعم الفني عبر واتساب أو البريد الإلكتروني.'
              : 'Account deletion is currently unavailable. Please contact support by email.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, RouteNames.support);
            },
            child: Text(isArabic ? 'تواصل عبر واتساب' : 'WhatsApp'),
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
            child: Text(isArabic ? 'تواصل عبر البريد' : 'Email'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = context.watch<LocalizationService>();
    final themeService = context.watch<ThemeService>();
    final isArabic = localizationService.isArabic;

    return Scaffold(
      appBar: AppBar(title: Text(isArabic ? 'الإعدادات' : 'Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSection(
                  title: isArabic ? 'المظهر' : 'Appearance',
                  children: [
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.moon,
                      title: isArabic ? 'الوضع الداكن' : 'Dark Mode',
                      value: themeService.themeMode == ThemeMode.dark,
                      onChanged: (value) {
                        themeService.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                    SettingsTile(
                      icon: IconsaxPlusBroken.color_swatch,
                      title: isArabic ? 'سمة التطبيق' : 'App Theme',
                      subtitle: themeService.themeMode == ThemeMode.system
                          ? (isArabic ? 'النظام' : 'System')
                          : themeService.themeMode == ThemeMode.light
                          ? (isArabic ? 'فاتح' : 'Light')
                          : (isArabic ? 'داكن' : 'Dark'),
                      trailing: const Icon(IconsaxPlusBroken.arrow_down_1),
                      onTap: () => _showThemeBottomSheet(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: isArabic ? 'اللغة' : 'Language',
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.language_square,
                      title: isArabic ? 'اللغة' : 'Language',
                      subtitle: isArabic ? 'العربية' : 'English',
                      trailing: const Icon(IconsaxPlusBroken.arrow_down_1),
                      onTap: () => _showLanguageBottomSheet(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: isArabic ? 'الإشعارات' : 'Notifications',
                  children: [
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.notification,
                      title: isArabic ? 'الإشعارات' : 'Push Notifications',
                      value: _pushNotifications,
                      onChanged: (value) {
                        final settings = SettingsService();
                        settings.setPushNotificationsEnabled(value);
                        setState(() => _pushNotifications = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.volume_high,
                      title: isArabic ? 'الصوت' : 'Sound',
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
                      title: isArabic ? 'الاهتزاز' : 'Vibration',
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
                  title: isArabic ? 'الحساب والأمان' : 'Account & Security',
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.user,
                      title: isArabic ? 'معلومات الحساب' : 'Account Info',
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
                      title: isArabic ? 'تغيير كلمة المرور' : 'Change Password',
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
                    title: isArabic ? 'السائق' : 'Driver',
                    children: [
                      SettingsTile(
                        icon: IconsaxPlusBroken.car,
                        title: isArabic
                            ? 'إعدادات السيارة وتخطيط المقاعد'
                            : 'Vehicle & Seat Layout',
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
                  title: isArabic ? 'الدفع والمحفظة' : 'Payment & Wallet',
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.wallet,
                      title: isArabic ? 'المحفظة' : 'Wallet',
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
                  title: isArabic ? 'الدعم والمساعدة' : 'Support & Help',
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.message,
                      title: isArabic ? 'تواصل معنا' : 'Contact Us',
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.pushNamed(context, RouteNames.support);
                      },
                    ),
                    SettingsTile(
                      icon: IconsaxPlusBroken.document_text,
                      title: isArabic ? 'شروط الاستخدام' : 'Terms of Service',
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InAppBrowserScreen(
                              title: isArabic
                                  ? 'شروط الاستخدام'
                                  : 'Terms of Service',
                              url: 'https://rideshare.app/terms',
                            ),
                          ),
                        );
                      },
                    ),
                    SettingsTile(
                      icon: IconsaxPlusBroken.shield_security,
                      title: isArabic ? 'سياسة الخصوصية' : 'Privacy Policy',
                      trailing: const Icon(IconsaxPlusBroken.arrow_right_1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InAppBrowserScreen(
                              title: isArabic
                                  ? 'سياسة الخصوصية'
                                  : 'Privacy Policy',
                              url: 'https://rideshare.app/privacy',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SettingsSection(
                  title: isArabic ? 'حول التطبيق' : 'About',
                  children: [
                    SettingsTile(
                      icon: IconsaxPlusBroken.info_circle,
                      title: isArabic ? 'حول التطبيق' : 'About',
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
                        isArabic ? 'حذف الحساب' : 'Delete Account',
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
